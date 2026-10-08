"""Rebuild original assets using Python/Pillow/NumPy and Blender."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parent
for name in ['generate.py','refine.py','effects.py','gun_audio.py']:
 subprocess.run([sys.executable,str(root/name)],check=True)
for name in ['model.py','environment.py']:
 subprocess.run(['blender','-b','--python-exit-code','1','--python',str(root/name)],check=True)
print('Original resources rebuilt; import with Godot editor before exporting.')
