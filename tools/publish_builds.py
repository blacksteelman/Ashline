from pathlib import Path
import subprocess,os
r=Path.cwd();b=r/'build';branch='builds/v0.7.0-alpha'
files={p.name:p for p in b.glob('ASHLINE-0.7-*') if p.is_file()}
for name in ['RELEASE.json']:files[name]=b/name
for name in ['LICENSES.md','README.md']:files[name]=r/name
files['verification_v7.json']=r/'tests/verification_v7.json'
files['ASSET-SOURCES.json']=r/'assets/thirdparty/SOURCES.json'
for name in ['native-combat','rifle-ads','workshop-interior']:files[name+'.png']=b/('screenshots-v7/'+name+'.png')
index=r/'.runtime/build-v7.index'
index.parent.mkdir(parents=True,exist_ok=True)
if index.exists():index.unlink()
env=os.environ.copy();env['GIT_INDEX_FILE']=str(index)
subprocess.run(['git','read-tree','--empty'],check=True,env=env)
for name,path in sorted(files.items()):
 oid=subprocess.check_output(['git','hash-object','-w',str(path)],text=True).strip()
 subprocess.run(['git','update-index','--add','--cacheinfo','100644',oid,name],check=True,env=env)
tree=subprocess.check_output(['git','write-tree'],env=env,text=True).strip()
commit=subprocess.check_output(['git','commit-tree',tree,'-m','Publish verified ASHLINE 0.7 native binaries and actual screenshots'],text=True).strip()
subprocess.run(['git','update-ref','refs/heads/'+branch,commit,'0'*40],check=True)
subprocess.run(['git','push','origin',branch],check=True)
print('Build branch published:',branch,commit)
