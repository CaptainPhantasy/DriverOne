#!/usr/bin/env python3
"""Harness-neutral, local ZCode GUI control. Uses argv, never a shell."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import struct
import sys
import urllib.parse

BUNDLE_ID = 'dev.zcode.app'
INSPECTED_VERSION = '3.7.5'
INSPECTED_BUILD = '3.7.5.4641'
PACKAGE = Path(__file__).resolve().parents[1]
READ_ONLY_STEER = {'see','ocr','focus','find','screens','wait','help'}
STEER_COMMANDS = READ_ONLY_STEER | {'window'}

class ControlError(Exception):
    pass

def emit(value):
    print(json.dumps(value,ensure_ascii=False,indent=2))

def execute(argv, *, text=None, timeout=30):
    try:
        result = subprocess.run(argv,input=text,text=True,capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise ControlError('Operation timed out; its result is uncertain. Observe the app before retrying.') from error
    except OSError as error:
        raise ControlError(str(error)) from error
    try:
        data=json.loads(result.stdout) if result.stdout.strip() else None
    except json.JSONDecodeError:
        data={'output':result.stdout}
    if result.returncode:
        # Do not echo argv: it may contain private text.
        error=data if data is not None else {'error':result.stderr.strip(),'exit_code':result.returncode}
        emit({'ok':False,'backend_result':error})
        raise SystemExit(result.returncode if 0<result.returncode<126 else 1)
    return data

def native_binary():
    custom=os.environ.get('ZCODE_GUI_NATIVE')
    candidate=Path(custom).expanduser() if custom else PACKAGE/'scripts'/'zcode-macos'
    if not candidate.is_file() or not os.access(candidate,os.X_OK):
        raise ControlError('Native helper missing or not executable. Build it with python3 -B scripts/build_native.py as documented.')
    return str(candidate)

def steer_binary():
    custom=os.environ.get('ZCODE_GUI_STEER')
    candidates=[custom,shutil.which('steer'),str(Path.home()/'.local/bin/steer')]
    for raw in candidates:
        if raw:
            candidate=Path(raw).expanduser()
            if candidate.is_file() and os.access(candidate,os.X_OK):return str(candidate)
    raise ControlError('Optional Steer tool is not installed. Use native snapshot, press, and set-value, or install Steer through your approved process.')

def workspace_url(raw):
    p=Path(raw).expanduser()
    if not p.is_absolute():
        raise ControlError('Workspace path must be absolute.')
    if not p.is_dir():
        raise ControlError('Workspace directory does not exist.')
    return 'zcode://workspace/open?'+urllib.parse.urlencode({'path':str(p.resolve())})

def native_info():
    return execute([native_binary(),'info'])

def ensure_frontmost(info):
    # The native helper supplies an explicit frontmost bundle identifier.
    front=info.get('frontmost_bundle_id') or info.get('frontmostBundleId')
    if front != BUNDLE_ID:
        raise ControlError('ZCode is not the foreground app. Activate it, then observe again. No pointer or keyboard action was sent.')

def safe_steer_args(command, args):
    if command not in STEER_COMMANDS:
        raise ControlError('Unsupported Steer command.')
    selectors=[(index,token) for index,token in enumerate(args) if token=='--app' or token.startswith('--app=')]
    if len(selectors)>1:raise ControlError('Duplicate app selectors are not allowed.')
    if selectors:
        at,token=selectors[0]
        value=token.split('=',1)[1] if '=' in token else args[at+1] if at+1<len(args) else None
        if value!='ZCode':raise ControlError('This driver targets ZCode only.')
    if command=='window':
        if len(args)<2 or args[1]!='ZCode':
            raise ControlError('Window commands require the ZCode app name.')
        if args[0]!='list':
            raise ControlError('Steer window mutations can select a small overlay. Use a current native window element and its supported action instead.')
    result=list(args)
    if '--json' not in result: result.append('--json')
    return result

def parser():
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest='command',required=True)
    sub.add_parser('doctor',help='Report app/helper prerequisites without changing anything')
    sub.add_parser('info',help='Read running app and permission state')
    activation=sub.add_parser('activate',help='Activate and raise ZCode without submitting anything')
    activation.add_argument('--window-id',type=int)
    snap=sub.add_parser('snapshot',help='Save a current main-window tree and optional screenshot')
    snap.add_argument('--output-dir',default='/tmp/zcode-gui-control')
    snap.add_argument('--max-depth',type=int,default=50)
    snap.add_argument('--max-nodes',type=int,default=4000)
    snap.add_argument('--max-value-chars',type=int,default=160)
    snap.add_argument('--enhance',action='store_true',help='Ask ZCode to expose its accessibility tree; no permission grant')
    snap.add_argument('--screenshot',action='store_true')
    snap.add_argument('--window-id',type=int,help='Select an observed ZCode-owned window or native dialog')
    press=sub.add_parser('press',help='Perform a supported action on an observed element')
    press.add_argument('--snapshot',required=True)
    press.add_argument('--id',required=True)
    press.add_argument('--action',default='AXPress')
    value=sub.add_parser('set-value',help='Set an observed editable field from standard input')
    value.add_argument('--snapshot',required=True)
    value.add_argument('--id',required=True)
    value.add_argument('--value-stdin',action='store_true',required=True)
    typing=sub.add_parser('type',help='Insert text from standard input into the currently focused observed field')
    typing.add_argument('--snapshot',required=True)
    typing.add_argument('--id',required=True)
    typing.add_argument('--value-stdin',action='store_true',required=True)
    for name in ('click','hotkey','scroll','drag'):
        control=sub.add_parser(name,help='Send one guarded native input action to foreground ZCode')
        control.add_argument('--snapshot',required=True)
        if name=='click':
            control.add_argument('--x',type=float,required=True)
            control.add_argument('--y',type=float,required=True)
            control.add_argument('--button',choices=['left','right'],default='left')
            control.add_argument('--count',type=int,choices=[1,2],default=1)
        elif name=='hotkey':control.add_argument('--keys',required=True)
        elif name=='scroll':
            control.add_argument('--direction',choices=['up','down','left','right'],required=True)
            control.add_argument('--lines',type=int,default=3)
            control.add_argument('--x',type=float)
            control.add_argument('--y',type=float)
        else:
            for key in ('from-x','from-y','to-x','to-y'):control.add_argument('--'+key,type=float,required=True)
    for name in ('workspace-url','open-workspace'):
        c=sub.add_parser(name,help='Construct or open the inspected workspace deep link')
        c.add_argument('path')
    sub.add_parser('interfaces',help='Read the inspected protocol inventory; does not connect to private endpoints')
    steer=sub.add_parser('steer',help='Use optional read-only Steer diagnostics; native input commands handle changes')
    steer.add_argument('operation',choices=sorted(STEER_COMMANDS))
    steer.add_argument('arguments',nargs=argparse.REMAINDER)
    return p

def main(argv=None):
    args=parser().parse_args(argv)
    if args.command=='interfaces':
        emit(json.loads((PACKAGE/'references/interfaces.json').read_text()));return
    if args.command in ('workspace-url','open-workspace'):
        url=workspace_url(args.path)
        if args.command=='workspace-url': emit({'url':url,'performed':False});return
        if platform.system()!='Darwin': raise ControlError('The installed application control route requires macOS.')
        try:
            result=subprocess.run(['/usr/bin/open',url],capture_output=True,text=True,timeout=15)
        except subprocess.TimeoutExpired as error:
            raise ControlError('Workspace request timed out; its result is uncertain. Observe ZCode before retrying.') from error
        if result.returncode: raise ControlError(result.stderr.strip() or 'Workspace open request failed.')
        emit({'ok':True,'requested_workspace':str(Path(args.path).expanduser().resolve()),'verification_required':True,'note':'Inspect and handle the native workspace confirmation; exit zero does not prove the workspace opened.'});return
    if args.command=='doctor':
        app=Path(os.environ.get('ZCODE_GUI_APP','/Applications/ZCode.app'))
        plist=app/'Contents/Info.plist'
        data=plistlib.loads(plist.read_bytes()) if plist.is_file() else {}
        details={'platform':platform.system(),'architecture':platform.machine(),'app_path':str(app),'bundle_id':data.get('CFBundleIdentifier'),'version':data.get('CFBundleShortVersionString'),'build':data.get('CFBundleVersion'),'inspected_version':INSPECTED_VERSION,'same_inspected_version':data.get('CFBundleShortVersionString')==INSPECTED_VERSION,'same_inspected_build':data.get('CFBundleVersion')==INSPECTED_BUILD,'native_helper_present':(PACKAGE/'scripts/zcode-macos').is_file(),'steer_optional_present':bool(shutil.which('steer')),'prerequisite_note':'The shell must have desktop access. Native info reports existing macOS permissions; this script never grants them.'}
        emit(details);return
    if platform.system()!='Darwin': raise ControlError('GUI control requires the macOS desktop where ZCode runs. This is harness-neutral, not a cross-platform remote service.')
    if args.command=='info': emit(native_info());return
    if args.command=='steer':
        raw=args.arguments[1:] if args.arguments[:1]==['--'] else args.arguments
        flags=safe_steer_args(args.operation,raw)
        if args.operation not in READ_ONLY_STEER and not (args.operation=='window' and flags[0]=='list'):
            ensure_frontmost(native_info())
        emit(execute([steer_binary(),args.operation,*flags]));return
    cmd=[native_binary(),args.command]
    text=None
    if args.command=='activate' and args.window_id is not None:
        if not 1<=args.window_id<=4294967295:raise ControlError('Window ID must be a positive native window number.')
        cmd += ['--window-id',str(args.window_id)]
    if args.command=='snapshot':
        if not Path(args.output_dir).expanduser().is_absolute(): raise ControlError('Snapshot output directory must be absolute.')
        if not 1<=args.max_depth<=80 or not 1<=args.max_nodes<=20000 or not 0<=args.max_value_chars<=4096:
            raise ControlError('Snapshot limits outside supported bounds.')
        cmd += ['--output-dir',str(Path(args.output_dir).expanduser()),'--max-depth',str(args.max_depth),'--max-nodes',str(args.max_nodes),'--max-value-chars',str(args.max_value_chars)]
        if args.window_id is not None:
            if not 1<=args.window_id<=4294967295:raise ControlError('Window ID must be a positive native window number.')
            cmd += ['--window-id',str(args.window_id)]
        if args.enhance: cmd.append('--enhance')
        if args.screenshot: cmd.append('--screenshot')
    elif args.command in ('press','set-value','type','click','hotkey','scroll','drag'):
        path=Path(args.snapshot).expanduser()
        if not path.is_absolute() or not path.is_file(): raise ControlError('Use the absolute path to an existing snapshot file.')
        cmd += ['--snapshot',str(path)]
        if args.command in ('press','set-value','type'):cmd += ['--id',args.id]
        if args.command=='press': cmd += ['--action',args.action]
        elif args.command in ('set-value','type'):
            text=sys.stdin.read(1048577)
            limit=65536 if args.command=='type' else 1048576
            if len(text.encode('utf-8'))>limit: raise ControlError('Input exceeds the supported byte limit for this text operation.')
            cmd.append('--value-stdin')
        elif args.command=='click':
            cmd += ['--x',str(args.x),'--y',str(args.y),'--button',args.button,'--count',str(args.count)]
        elif args.command=='hotkey':cmd += ['--keys',args.keys]
        elif args.command=='scroll':
            if not 1<=args.lines<=100:raise ControlError('Scroll lines must be from 1 to 100.')
            if (args.x is None)!=(args.y is None):raise ControlError('Scroll position requires both x and y.')
            cmd += ['--direction',args.direction,'--lines',str(args.lines)]
            if args.x is not None:cmd += ['--x',str(args.x),'--y',str(args.y)]
        elif args.command=='drag':
            for key in ('from-x','from-y','to-x','to-y'):cmd += ['--'+key,str(getattr(args,key.replace('-','_')))]
    result=execute(cmd,text=text)
    if args.command=='snapshot' and isinstance(result,dict) and result.get('screenshot_file'):
        header=Path(result['screenshot_file']).read_bytes()[:24]
        if header[:8]!=b'\x89PNG\r\n\x1a\n' or len(header)!=24:raise ControlError('Native screenshot is not a valid PNG header.')
        width,height=struct.unpack('>II',header[16:24])
        result['screenshot_pixel_width']=width;result['screenshot_pixel_height']=height
    emit(result)

if __name__=='__main__':
    try: main()
    except (ControlError,OSError,ValueError) as error:
        emit({'ok':False,'error':str(error)});sys.exit(1)
