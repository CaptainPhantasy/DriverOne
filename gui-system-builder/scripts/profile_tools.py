#!/usr/bin/env python3
"""Validate the suite's data records. This never launches apps or sends input."""
import argparse, hashlib, json, re, sys
from pathlib import Path, PureWindowsPath
from urllib.parse import urlsplit

class RecordError(ValueError): pass

def require(ok,message):
    if not ok: raise RecordError(message)

def object_fields(value,allowed,required,where):
    require(isinstance(value,dict),where+' must be an object')
    require(not set(value)-set(allowed),where+' has unsupported fields: '+', '.join(sorted(set(value)-set(allowed))))
    require(set(required)<=set(value),where+' is missing required fields')

def string(value,where,maximum=4096):
    require(isinstance(value,str) and 0<len(value)<=maximum and '\x00' not in value,where+' must be nonempty bounded text')

def strings(value,where):
    require(isinstance(value,list) and 0<len(value)<=100,where+' must be a nonempty list')
    for v in value:string(v,where+' entry')

def absolute_path(value,platform,where):
    string(value,where)
    require(PureWindowsPath(value).is_absolute() if platform=='windows' else Path(value).is_absolute(),where+' must be absolute')

def validate_profile(p):
    object_fields(p,{'schema_version','name','platform','identity','expected_version','capabilities','limits'},{'schema_version','name','platform','identity'},'profile')
    require(type(p['schema_version']) is int and p['schema_version']==1,'Unsupported profile schema version')
    require(isinstance(p['name'],str) and re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}',p['name']) is not None,'Invalid profile name')
    require(p['platform'] in ('macos','windows','linux','web'),'Unsupported profile platform')
    platform=p['platform'];identity=p['identity']
    allowed={'macos':{'bundle_id','app_path'},'windows':{'executable_path'},'linux':{'executable_path'},'web':{'url_origin'}}[platform]
    required={'macos':{'bundle_id'},'windows':{'executable_path'},'linux':{'executable_path'},'web':{'url_origin'}}[platform]
    object_fields(identity,allowed,required,'identity')
    if platform=='macos':
        bundle=identity['bundle_id']
        require(isinstance(bundle,str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]{0,254}',bundle) is not None and '..' not in bundle and not bundle.endswith('.'),'Invalid application bundle identifier')
    for key in ('app_path','executable_path'):
        if key in identity:absolute_path(identity[key],platform,'identity.'+key)
    if platform=='web':
        string(identity['url_origin'],'url_origin');u=urlsplit(identity['url_origin'])
        require(u.scheme in ('http','https') and bool(u.hostname) and u.username is None and u.password is None and u.path in ('','/') and not u.query and not u.fragment,'Use an HTTP origin without credentials, path, query, or fragment')
        try:u.port
        except ValueError:raise RecordError('Invalid origin port')
    if 'expected_version' in p:
        object_fields(p['expected_version'],{'version','build'},{'version'},'expected_version')
        for k,v in p['expected_version'].items():string(v,'expected_version.'+k,256)
    if 'capabilities' in p:
        c=p['capabilities'];object_fields(c,{'electron_accessibility','routes'},set(),'capabilities')
        if 'electron_accessibility' in c:require(type(c['electron_accessibility']) is bool,'electron_accessibility must be boolean')
        if 'routes' in c:
            require(isinstance(c['routes'],list) and len(c['routes'])<=50,'routes must be a bounded list')
            for route in c['routes']:
                object_fields(route,{'kind','state','evidence'},{'kind','state','evidence'},'route')
                require(route['kind'] in ('native','documented_api','browser','image'),'Invalid route kind')
                require(route['state'] in ('discovered','inspected','exercised','unsupported'),'Invalid route evidence state')
                string(route['evidence'],'route evidence')
    if 'limits' in p:strings(p['limits'],'limits')
    return p

ACTIONS={'observe','activate','press','set-value','type','hotkey','scroll','drag','wait','verify','save','submit'}
REPETITION={'safe-after-check','inspect-before-repeat','never-automatic'}

def validate_workflow(w,profile=None):
    object_fields(w,{'schema_version','id','profile_name','goal','preconditions','steps','completion','restoration'},{'schema_version','id','profile_name','goal','preconditions','steps','completion','restoration'},'workflow')
    require(type(w['schema_version']) is int and w['schema_version']==1,'Unsupported workflow schema version')
    for k in ('id','profile_name'):require(isinstance(w[k],str) and re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}',w[k]) is not None,'Invalid workflow '+k)
    string(w['goal'],'goal')
    for k in ('preconditions','completion','restoration'):strings(w[k],k)
    require(isinstance(w['steps'],list) and 0<len(w['steps'])<=100,'steps must be a nonempty bounded list')
    ids=set()
    for s in w['steps']:
        object_fields(s,{'id','intent','selector','action','expected','repetition'},{'id','intent','action','expected','repetition'},'step')
        string(s['id'],'step id',64);require(s['id'] not in ids,'Duplicate step id');ids.add(s['id'])
        string(s['intent'],'step intent');require(isinstance(s['action'],str) and s['action'] in ACTIONS,'Unknown semantic action')
        strings(s['expected'],'step expected');require(isinstance(s['repetition'],str) and s['repetition'] in REPETITION,'Unknown repetition policy')
        if 'selector' in s:
            selector=s['selector'];object_fields(selector,{'role','label','identifier','value','context','window_title'},set(),'selector');require(bool(selector),'Empty selector')
            for k,v in selector.items():strings(v,'selector context') if k=='context' else string(v,'selector '+k)
        if s['action'] in ('submit','save'):require(s['repetition']!='safe-after-check','Saved or submitted state must be inspected before repetition')
    if profile is not None:require(w['profile_name']==profile['name'],'Workflow targets a different profile')
    return w

def duplicate_keys(pairs):
    result={}
    for k,v in pairs:
        if k in result:raise RecordError('Duplicate JSON key: '+k)
        result[k]=v
    return result

def load_record(path):
    p=Path(path).expanduser();require(p.is_absolute() and p.is_file(),'Use an absolute existing record file')
    with p.open('rb') as handle:raw=handle.read(1048577)
    require(len(raw)<=1048576,'Record exceeds one MiB')
    try:return json.loads(raw.decode('utf-8'),object_pairs_hook=duplicate_keys,parse_constant=lambda value:(_ for _ in ()).throw(RecordError('Non-finite JSON value')))
    except (UnicodeError,json.JSONDecodeError) as e:raise RecordError('Record is not valid UTF-8 JSON') from e

def fingerprint(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode('utf-8')).hexdigest()

def load_profile(path):return validate_profile(load_record(path))

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('profile');p.add_argument('path')
    w=sub.add_parser('workflow');w.add_argument('path');w.add_argument('--profile')
    a=parser.parse_args()
    if a.command=='profile':record=load_profile(a.path)
    else:record=validate_workflow(load_record(a.path),load_profile(a.profile) if a.profile else None)
    print(json.dumps({'ok':True,'kind':a.command,'sha256':fingerprint(record),'note':'Valid record data; this does not grant authority or execute a workflow.'},indent=2))

if __name__=='__main__':
    try:main()
    except (RecordError,OSError,ValueError) as e:print(json.dumps({'ok':False,'error':str(e)}));sys.exit(1)
