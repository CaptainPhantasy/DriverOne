#!/usr/bin/env python3
"""Explicit-profile GUI controls. Uses a real macOS adapter; never invokes a shell."""
import argparse,json,os,platform,struct,subprocess,sys
from pathlib import Path
from profile_tools import load_profile,fingerprint,RecordError

class ControlError(ValueError):pass
NATIVE=Path(__file__).resolve().parent/'gui-macos'

class ExplicitParser(argparse.ArgumentParser):
    def __init__(self,*args,**kwargs):
        kwargs['allow_abbrev']=False
        super().__init__(*args,**kwargs)
    def parse_args(self,args=None,namespace=None):
        values=list(sys.argv[1:] if args is None else args)
        for selector in ('--profile','--pid'):
            if sum(v==selector or v.startswith(selector+'=') for v in values)>1:
                self.error('Duplicate target selector: '+selector)
        return super().parse_args(values,namespace)


def execute(argv,text=None,timeout=30):
    try:r=subprocess.run(argv,input=text,text=True,capture_output=True,timeout=timeout)
    except subprocess.TimeoutExpired as e:raise ControlError('Outcome unknown: command timed out. Inspect current app state before retrying.') from e
    except OSError as e:raise ControlError(str(e)) from e
    try:data=json.loads(r.stdout)
    except json.JSONDecodeError:raise ControlError('Adapter returned an invalid response. Outcome is unknown; inspect before retrying.')
    if r.returncode:
        print(json.dumps({'ok':False,'backend_result':data},ensure_ascii=False));raise SystemExit(r.returncode if 0<r.returncode<126 else 1)
    if not isinstance(data,dict) or data.get('ok') is not True:raise ControlError('Adapter did not report a valid result; no completion is inferred.')
    return data

def native_arguments(profile,command,pid=None):
    if profile['platform']!='macos' or platform.system()!='Darwin':raise ControlError('This included adapter runs on macOS. Build and test the platform adapter described in the guide for this profile.')
    if not NATIVE.is_file() or not os.access(NATIVE,os.X_OK):raise ControlError('Packaged native helper is missing or not executable.')
    args=[str(NATIVE),command,'--bundle-id',profile['identity']['bundle_id'],'--profile-sha256',fingerprint(profile)]
    if pid is not None:
        if not 1<=pid<=2147483647:raise ControlError('Process identifier must be a positive signed 32-bit value.')
        args+=['--pid',str(pid)]
    if 'app_path' in profile['identity']:args+=['--expected-app-path',str(Path(profile['identity']['app_path']).resolve())]
    return args

def verify_info(profile,info):
    if info.get('bundle_id')!=profile['identity']['bundle_id']:raise ControlError('Running app does not match the profile.')
    desired=profile.get('identity',{}).get('app_path')
    if desired and Path(info.get('app_path','')).resolve()!=Path(desired).resolve():raise ControlError('Running app path differs from the profile.')
    expected=profile.get('expected_version',{})
    for key in ('version','build'):
        if key in expected and info.get(key)!=expected[key]:raise ControlError('App '+key+' differs from the inspected profile. Reinspect the app; do not silently change the pin.')

def parser():
    p=ExplicitParser(description=__doc__);p.add_argument('--profile',required=True);p.add_argument('--pid',type=int)
    sub=p.add_subparsers(dest='command',required=True)
    for name in ('doctor','info'):sub.add_parser(name)
    a=sub.add_parser('activate');a.add_argument('--window-id',type=int)
    s=sub.add_parser('snapshot');s.add_argument('--output-dir',default='/tmp/gui-operation-suite');s.add_argument('--window-id',type=int);s.add_argument('--screenshot',action='store_true');s.add_argument('--enhance',action='store_true');s.add_argument('--max-depth',type=int,default=50);s.add_argument('--max-nodes',type=int,default=4000);s.add_argument('--max-value-chars',type=int,default=160)
    for name in ('press','set-value','type','click','hotkey','scroll','drag'):
        a=sub.add_parser(name);a.add_argument('--snapshot',required=True)
        if name in ('press','set-value','type'):a.add_argument('--id',required=True)
        if name=='press':a.add_argument('--action',default='AXPress')
        elif name in ('set-value','type'):a.add_argument('--value-stdin',action='store_true',required=True)
        elif name=='click':a.add_argument('--x',type=float,required=True);a.add_argument('--y',type=float,required=True);a.add_argument('--button',choices=['left','right'],default='left');a.add_argument('--count',type=int,choices=[1,2],default=1)
        elif name=='hotkey':a.add_argument('--keys',required=True)
        elif name=='scroll':a.add_argument('--direction',choices=['up','down','left','right'],required=True);a.add_argument('--lines',type=int,default=3);a.add_argument('--x',type=float);a.add_argument('--y',type=float)
        else:
            for key in ('from-x','from-y','to-x','to-y'):a.add_argument('--'+key,type=float,required=True)
    return p

def main(argv=None):
    a=parser().parse_args(argv);profile=load_profile(a.profile)
    if a.command=='doctor':
        ready=profile['platform']=='macos' and platform.system()=='Darwin' and NATIVE.is_file() and os.access(NATIVE,os.X_OK)
        print(json.dumps({'ok':True,'profile_name':profile['name'],'profile_sha256':fingerprint(profile),'host_platform':platform.system(),'host_architecture':platform.machine(),'profile_platform':profile['platform'],'included_backend':'macos','backend_available':ready,'note':'Presence is not a live workflow check. Existing desktop permissions are checked by native info.'},indent=2));return
    info=execute(native_arguments(profile,'info',a.pid));verify_info(profile,info)
    if a.command=='info':print(json.dumps(info,ensure_ascii=False,indent=2));return
    checked_pid=info.get('pid')
    if type(checked_pid) is not int or not 1<=checked_pid<=2147483647:raise ControlError('Adapter did not return a valid checked process identifier.')
    args=native_arguments(profile,a.command,checked_pid);text=None
    if a.command in ('activate','snapshot') and a.window_id is not None:
        if not 1<=a.window_id<=4294967295:raise ControlError('Window identifier must be a positive native window number.')
        args+=['--window-id',str(a.window_id)]
    if a.command=='snapshot':
        out=Path(a.output_dir).expanduser()
        if not out.is_absolute():raise ControlError('Snapshot directory must be absolute.')
        if not 1<=a.max_depth<=80 or not 1<=a.max_nodes<=20000 or not 0<=a.max_value_chars<=4096:raise ControlError('Snapshot limits are outside supported bounds.')
        if a.enhance and not profile.get('capabilities',{}).get('electron_accessibility',False):raise ControlError('Electron accessibility exposure is not enabled in this app profile.')
        args+=['--output-dir',str(out),'--max-depth',str(a.max_depth),'--max-nodes',str(a.max_nodes),'--max-value-chars',str(a.max_value_chars)]
        if a.enhance:args.append('--enhance')
        if a.screenshot:args.append('--screenshot')
    elif a.command in ('press','set-value','type','click','hotkey','scroll','drag'):
        path=Path(a.snapshot).expanduser()
        if not path.is_absolute() or not path.is_file():raise ControlError('Use an absolute existing snapshot file.')
        args+=['--snapshot',str(path)]
        if a.command in ('press','set-value','type'):args+=['--id',a.id]
        if a.command=='press':args+=['--action',a.action]
        elif a.command in ('set-value','type'):
            text=sys.stdin.read(1048577);limit=65536 if a.command=='type' else 1048576
            if len(text.encode('utf-8'))>limit:raise ControlError('Input exceeds the supported byte limit.')
            args.append('--value-stdin')
        elif a.command=='click':args+=['--x',str(a.x),'--y',str(a.y),'--button',a.button,'--count',str(a.count)]
        elif a.command=='hotkey':args+=['--keys',a.keys]
        elif a.command=='scroll':
            if not 1<=a.lines<=100 or (a.x is None)!=(a.y is None):raise ControlError('Scroll needs 1 to 100 lines and either both coordinates or neither.')
            args+=['--direction',a.direction,'--lines',str(a.lines)]
            if a.x is not None:args+=['--x',str(a.x),'--y',str(a.y)]
        else:
            for key in ('from-x','from-y','to-x','to-y'):args+=['--'+key,str(getattr(a,key.replace('-','_')))]
    result=execute(args,text=text)
    if a.command=='snapshot' and result.get('screenshot_file'):
        header=Path(result['screenshot_file']).read_bytes()[:24]
        if len(header)!=24 or header[:8]!=b'\x89PNG\r\n\x1a\n':raise ControlError('Screenshot header is not valid PNG.')
        result['screenshot_pixel_width'],result['screenshot_pixel_height']=struct.unpack('>II',header[16:24])
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    try:main()
    except (ControlError,RecordError,OSError,ValueError) as e:print(json.dumps({'ok':False,'error':str(e)},ensure_ascii=False));sys.exit(1)
