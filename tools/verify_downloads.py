from pathlib import Path
import subprocess,json,urllib.request,hashlib,zipfile
r=Path.cwd();manifest=json.loads((r/'build/ASHLINE-0.7-SHA256.json').read_text());results={}
for name,expected in manifest.items():
 meta=json.loads(subprocess.check_output(['gh','api','repos/blacksteelman/Ashline/contents/'+name+'?ref=builds/v0.7.0-alpha'],text=True))
 # Private download URL contains a short-lived credential. Never log it.
 req=urllib.request.Request(meta['download_url'])
 dest=r/'build'/('download-verified-'+name)
 with urllib.request.urlopen(req,timeout=120) as response,dest.open('wb') as out:
  while chunk:=response.read(1024*1024):out.write(chunk)
 actual=hashlib.sha256(dest.read_bytes()).hexdigest()
 assert actual==expected['sha256'] and dest.stat().st_size==expected['bytes'],name
 with zipfile.ZipFile(dest) as z:assert z.testzip() is None,name
 results[name]={'downloaded':True,'sha256_matches':True,'zip_valid':True,'bytes':dest.stat().st_size}
 print('Verified GitHub download:',name,flush=True)
(r/'build/GITHUB-DOWNLOAD-VERIFICATION.json').write_text(json.dumps(results,indent=2)+'\n')

# Append the proof to the build branch without switching the source worktree.
import os
branch='builds/v0.7.0-alpha'
parent=subprocess.check_output(['git','rev-parse',branch],text=True).strip()
index=r/'.runtime/download-proof-v7.index';index.parent.mkdir(parents=True,exist_ok=True)
if index.exists():index.unlink()
env=os.environ.copy();env['GIT_INDEX_FILE']=str(index)
subprocess.run(['git','read-tree',parent],check=True,env=env)
proof=r/'build/GITHUB-DOWNLOAD-VERIFICATION.json'
oid=subprocess.check_output(['git','hash-object','-w',str(proof)],text=True).strip()
subprocess.run(['git','update-index','--add','--cacheinfo','100644',oid,proof.name],check=True,env=env)
tree=subprocess.check_output(['git','write-tree'],text=True,env=env).strip()
commit=subprocess.check_output(['git','commit-tree',tree,'-p',parent,'-m','Record successful reverse downloads of all ASHLINE 0.7 archives'],text=True).strip()
subprocess.run(['git','update-ref','refs/heads/'+branch,commit,parent],check=True)
subprocess.run(['git','push','origin',branch],check=True)
print('Download proof published:',commit)
