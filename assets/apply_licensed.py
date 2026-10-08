"""Restore licensed surface/audio resources after original asset generators.
All inputs are pinned, included locally; rebuilding needs no network.
"""
from pathlib import Path
from PIL import Image
import hashlib,json,shutil
P=Path(__file__).parent
manifest=json.loads((P/'thirdparty/SOURCES.json').read_text())
def verify(source, expected):
 if hashlib.sha256(source.read_bytes()).hexdigest()!=expected:
  raise SystemExit('Licensed input checksum mismatch: '+str(source))
for material,record in manifest['surfaces'].items():
 for suffix in ['', '_normal','_roughness','_ao']:
  source=P/'thirdparty/surfaces'/(material+suffix+'.jpg')
  verify(source,record['files'][source.name]['sha256'])
  Image.open(source).save(P/(material+suffix+'.png'))
for output,record in manifest['audio'].items():
 verify(P/'thirdparty/audio'/output,record['sha256'])
 shutil.copy2(P/'thirdparty/audio'/output,P/output)
print('Pinned CC0 materials and field recordings restored')
