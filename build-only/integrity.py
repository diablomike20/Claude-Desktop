"""Verify the pinned checkout and create a byte-exact original source archive."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

COMMIT='85cb591eae2d4330198957ada16545621973581b'

def verify(source,output,stage):
    def git(*args):return subprocess.check_output(['git','-C',str(source),*args])
    assert git('rev-parse','HEAD').decode().strip()==COMMIT
    entries=[]
    for line in git('ls-tree','-rz','HEAD').split(b'\0'):
        if not line:continue
        meta,name=line.split(b'\t',1);mode,kind,sha=meta.split()
        if kind!=b'blob':continue
        path=name.decode('utf-8');body=(source/path).read_bytes()
        actual=hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()
        assert actual==sha.decode(),f'Source bytes changed: {path}'
        entries.append({'path':path,'git_blob':actual,'sha256':hashlib.sha256(body).hexdigest(),'bytes':len(body)})
    result={'ok':True,'commit':COMMIT,'stage':stage,'tracked_files':len(entries),'files':entries}
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'source_integrity':True,'stage':stage,'tracked_files':len(entries),'commit':COMMIT}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--stage',required=True)
    a=p.parse_args();verify(a.source.resolve(),a.output,a.stage)
