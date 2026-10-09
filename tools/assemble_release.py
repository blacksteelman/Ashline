"""Reassemble verified distribution files without GitHub's per-git-file limit.
Used locally for reverse-download verification and by the release workflow.
"""
from pathlib import Path
import argparse,hashlib,json,zipfile

def assemble(payload: Path,destination: Path):
 manifest=json.loads((payload/'ASSEMBLY.json').read_text())
 destination.mkdir(parents=True,exist_ok=True)
 for name,entry in manifest.items():
  if Path(name).name!=name:raise ValueError('Invalid archive name')
  digest=hashlib.sha256();count=0;outpath=destination/name
  with outpath.open('wb') as out:
   for part in entry['parts']:
    relative=Path(part)
    if relative.is_absolute() or '..' in relative.parts:raise ValueError('Invalid part path')
    with (payload/relative).open('rb') as source:
     while chunk:=source.read(1024*1024):out.write(chunk);digest.update(chunk);count+=len(chunk)
  if count!=entry['bytes'] or digest.hexdigest()!=entry['sha256']:
   outpath.unlink();raise ValueError('Archive checksum mismatch: '+name)
  with zipfile.ZipFile(outpath) as archive:
   bad=archive.testzip()
   if bad:raise ValueError('Archive CRC mismatch: '+name+'/'+bad)
  print('ASSEMBLED',name,count,flush=True)
 return manifest

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('payload',type=Path);parser.add_argument('destination',type=Path)
 args=parser.parse_args();assemble(args.payload,args.destination)
