from pathlib import Path
import subprocess,json,hashlib,zipfile,shutil
r=Path.cwd();b=r/'build';commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
release={'version':'0.7','commit':commit,'tag':'v0.7.0-alpha','engine':'Godot 4.6.3','verification':'verification_v7.json','windows_runtime_tested':False,'gpu_hardware_tested':False,'audio_output_tested':False,'assets':'Pinned CC0 PBR rifle/arms/industrial equipment, ambientCG surfaces and Free Firearm Sound Library recordings; see ASSET-SOURCES.json and LICENSES.md.'}
(b/'RELEASE.json').write_text(json.dumps(release,indent=2)+'\n')
for folder in ['linux','windows']:
 dest=b/folder
 if folder=='linux':
  launcher=dest/'Launch-OpenGL.sh'
  launcher.write_text('#!/bin/sh\ncd "$(dirname "$0")" || exit 1\nexec ./ASHLINE.x86_64 --rendering-method gl_compatibility "$@"\n')
  launcher.chmod(0o755)
 else:
  (dest/'Launch-OpenGL.bat').write_text('@echo off\ncd /d "%~dp0"\nASHLINE.exe --rendering-method gl_compatibility %*\n')
 for old in dest.glob('verification_v*.json'):old.unlink()
 for file in ['README.md','LICENSES.md','FONT-LICENSE.txt','SESSION_HANDOFF.md']:shutil.copy2(r/file,dest/file)
 shutil.copy2(b/'RELEASE.json',dest/'RELEASE.json')
 shutil.copy2(r/'tests/verification_v7.json',dest/'verification_v7.json')
 shutil.copy2(r/'assets/thirdparty/SOURCES.json',dest/'ASSET-SOURCES.json')
 name='Linux' if folder=='linux' else 'Windows'
 with zipfile.ZipFile(b/f'ASHLINE-0.7-{name}-x64.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for file in sorted(dest.iterdir()):
   if file.is_file():z.write(file,arcname='ASHLINE/'+file.name)
# Keep the playable source bundle below GitHub's file limit. Native runtime GLBs
# are included; the large offline Blender/FBX inputs live in a second archive.
paths=subprocess.check_output(['git','ls-files','-z'],text=True).split('\0')
vendor_prefixes=('assets/thirdparty/viewmodel/','assets/thirdparty/industrial/')
for name,vendor in [('Source',False),('Asset-Sources',True)]:
 with zipfile.ZipFile(b/f'ASHLINE-0.7-{name}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(p for p in paths if p):
   if path.startswith(vendor_prefixes)==vendor:z.write(r/path,'ASHLINE/'+path)
  if vendor:z.writestr('ASHLINE/ASSET-SOURCES-README.txt','For full Blender rebuilding, extract this alongside ASHLINE-0.7-Source.zip so both archives share the same ASHLINE directory. The Source archive already contains the runtime GLBs required to play. Source licenses and hashes: assets/thirdparty/SOURCES.json.\n')
notes='Actual Godot screenshots, without retouching. native-combat/native-opengl are from the exported Linux executable. Other screenshots use reproducible controlled states with frozen actors and player protection. Software llvmpipe renderer; audio driver Dummy. This alpha has not reached the requested COD4 visual target.\n'
with zipfile.ZipFile(b/'ASHLINE-0.7-Screenshots.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 z.writestr('SCREENSHOTS.txt',notes)
 for file in sorted((b/'screenshots-v7').glob('*.png')):z.write(file,'Screenshots/'+file.name)
 for file in ['verification_v7.json','performance_v7_report.json','art_v7_report.json']:z.write(r/'tests'/file,'Verification/'+file)
 for name in ['art-v7-final','functional-v7','regression_v3-v7','regression_art_v4-v7','character_v5-v7','regression_v6-v7','playthrough-v7','stairs-v7','native-vulkan-v7','native-opengl-v7','network-v7','bots-v7-707','bots-v7-708','visual-vulkan-v7-final','performance-v7','weapon-art-v7-final5']:
  z.write(b/(name+'.log'),'Verification/'+name+'.txt')
hashes={}
for file in sorted(b.glob('ASHLINE-0.7-*.zip')):
 if file.stat().st_size>=100*1024*1024:raise RuntimeError('GitHub file limit exceeded: '+file.name)
 hashes[file.name]={'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bytes':file.stat().st_size}
 with zipfile.ZipFile(file) as z:assert z.testzip() is None
 print(file.name,round(file.stat().st_size/1024/1024,2),'MiB',flush=True)
(b/'ASHLINE-0.7-SHA256.json').write_text(json.dumps(hashes,indent=2)+'\n')
