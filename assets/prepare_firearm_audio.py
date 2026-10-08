"""Optional preparation from the CC0 original library; final inputs are vendored.
Usage: python assets/prepare_firearm_audio.py /path/to/Prepared-SFX-Library
Requires ffmpeg and NumPy. Normal rebuilds use apply_licensed.py offline.
"""
from pathlib import Path
import subprocess,numpy as np,hashlib,json,wave,sys
P=Path(__file__).resolve().parent/'thirdparty'
if len(sys.argv)!=2:raise SystemExit('Usage: prepare_firearm_audio.py /path/to/Prepared-SFX-Library')
source=Path(sys.argv[1])
manifest=json.loads((P/'SOURCES.json').read_text())
selection={'rifle':['AR-15/D_32P.wav','AR-15/D_24P.wav'],'smg':['Carl Gustav M45/G_31P.wav','Carl Gustav M45/G_20P.wav'],'marksman':['Savage 10 .300 Blackout/T_27P.wav','Savage 10 .300 Blackout/T_17P.wav'],'pistol':['Walther PPQ/X_39P.wav','Walther PPQ/X_31P.wav']}
for key,files in selection.items():
 for n,file in enumerate(files):
  path=source/file
  decoded=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-af','highpass=f=65','-f','f32le','-ac','1','-ar','44100','pipe:1'])
  data=np.frombuffer(decoded,dtype='<f4')
  peak=int(np.argmax(np.abs(data)))
  # Locate the sharp onset before the strongest impulse, retaining 2ms attack padding.
  onset=max(0,peak-int(.12*44100))
  threshold=np.max(np.abs(data))*.075
  candidates=np.where(np.abs(data[onset:peak+1])>threshold)[0]
  if len(candidates):onset=max(0,onset+int(candidates[0])-88)
  length=int((.70 if key=='marksman' else .52)*44100)
  clip=np.array(data[onset:onset+length],copy=True)
  clip-=clip.mean();clip*=.82/max(.0001,float(np.max(np.abs(clip))))
  fade=min(int(.10*44100),len(clip));clip[-fade:]*=np.linspace(1,0,fade)
  out=P/'audio'/(key+('' if n==0 else '_alt')+'.wav')
  with wave.open(str(out),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(np.int16(np.clip(clip,-1,1)*32767).tobytes())
  manifest['audio'][out.name]={'author':'Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney','source':'https://opengameart.org/content/the-free-firearm-sound-library','license':'CC0-1.0','source_file':file,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'modifications':'Mono 44.1 kHz PCM16; 65 Hz high-pass; attack extracted with padding; peak normalized to 0.82; tail faded.','duration':len(clip)/44100}
(P/'SOURCES.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Imported 8 CC0 field recordings')
