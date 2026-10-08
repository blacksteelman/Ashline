from pathlib import Path
import numpy as np,wave
p=Path(__file__).parent;rng=np.random.default_rng(461)
for name,duration,body_freq,decay in [('rifle',.32,115,26),('smg',.25,155,35),('marksman',.42,85,20),('pistol',.30,142,29),('step_concrete',.15,90,36),('step_metal',.21,250,23)]:
 rate=44100;t=np.arange(int(rate*duration))/rate;noise=rng.normal(0,1,len(t));noise=np.clip(noise,-2,2)*.5
 high=noise-np.roll(noise,1)*.65
 crack=high*np.exp(-t*160)*np.minimum(t*7000,1)
 body=(np.sin(2*np.pi*body_freq*t)+np.sin(2*np.pi*body_freq*1.31*t)*.3)*np.exp(-t*decay)
 tail=noise*np.exp(-t*18)*.10
 if name.startswith('step'):signal=body*.20+crack*.3+tail*.7
 else:
  signal=crack*.8+body*.47+tail
  for delay,gain in [(.019,.12),(.038,.085),(.071,.045),(.125,.018)]:
   shift=int(delay*rate);signal[shift:]+=crack[:-shift]*gain
 signal=np.clip(signal,-.92,.92)
 with wave.open(str(p/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((signal*30000).astype('<i2').tobytes())

# Distinct dry mechanism and cloth/armor impact, no concrete sound on a body hit.
for name,duration in [('dryfire',.09),('impact_body',.13)]:
 t=np.arange(int(44100*duration))/44100
 noise=rng.normal(0,.35,len(t))
 signal=(noise*.22+np.sin(2*np.pi*880*t)*.17)*np.exp(-t*85) if name=='dryfire' else (noise*.27+np.sin(2*np.pi*95*t)*.38)*np.exp(-t*43)
 with wave.open(str(p/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(44100);f.writeframes((np.clip(signal,-.9,.9)*30000).astype('<i2').tobytes())
