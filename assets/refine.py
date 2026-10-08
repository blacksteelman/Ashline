from PIL import Image,ImageDraw,ImageFilter
from pathlib import Path
import numpy as np,random,math,wave,struct
p=Path(__file__).parent;random.seed(1047);rng=np.random.default_rng(1047)
for name,base in [('concrete',(103,109,105)),('asphalt',(43,49,51)),('brick',(101,79,66)),('metal',(65,80,78)),('plaster',(126,130,117)),('cloth',(95,107,88))]:
 detail=rng.normal(0,1.3,(512,512))
 variation=np.asarray(Image.fromarray(rng.integers(0,255,(64,64),dtype=np.uint8)).resize((512,512),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(15)),float)-128
 a=np.clip(np.array(base)[None,None,:]+detail[:,:,None]+variation[:,:,None]*.17,0,255).astype(np.uint8)
 im=Image.fromarray(a);d=ImageDraw.Draw(im)
 if name=='brick':
  for y in range(0,512,40):
   d.line((0,y,512,y),fill=(59,63,57),width=3)
   for x in range(-80,512,96):
    k=x+(48 if y%80 else 0);d.line((k,y,k,y+40),fill=(58,61,55),width=3)
    if random.random()<.45:d.line((k+4,y+6,k+82,y+5),fill=(117,95,79),width=1)
 if name=='cloth':
  for x in range(0,512,3):d.line((x,0,x,512),fill=(82,95,78),width=1)
  for y in range(0,512,3):d.line((0,y,512,y),fill=(107,119,96),width=1)
 else:
  for i in range(12):
   x,y=random.randrange(512),random.randrange(512);pts=[(x,y)]
   for j in range(random.randint(3,9)):x+=random.randint(-13,13);y+=random.randint(6,19);pts.append((x,y))
   d.line(pts,fill=tuple(int(c*.69) for c in base),width=1)
 im=im.filter(ImageFilter.GaussianBlur(.25));im.save(p/(name+'.png'))
 h=np.asarray(im.convert('L').filter(ImageFilter.GaussianBlur(1.3)),dtype=float)
 dx=np.roll(h,1,axis=1)-np.roll(h,-1,axis=1);dy=np.roll(h,1,axis=0)-np.roll(h,-1,axis=0)
 nm=np.stack([np.clip(128+dx*.8,0,255),np.clip(128+dy*.8,0,255),np.full((512,512),250)],axis=-1).astype(np.uint8);Image.fromarray(nm).save(p/(name+'_normal.png'))
 Image.fromarray(np.clip(210+variation*.2,0,255).astype(np.uint8)).save(p/(name+'_roughness.png'))
for name,dur in [('mag_out',.20),('mag_in',.22),('bolt',.24),('impact_metal',.19),('impact_concrete',.17),('ricochet',.25)]:
 data=[]
 for i in range(int(44100*dur)):
  t=i/44100;n=random.uniform(-1,1)
  if name=='mag_out':v=n*.25*math.exp(-t*50)+math.sin(t*math.tau*170)*.12*math.exp(-t*45)
  elif name=='mag_in':v=(n*.4+math.sin(t*math.tau*125)*.3)*math.exp(-t*48)
  elif name=='bolt':v=n*.26*(math.exp(-t*65)+math.exp(-abs(t-.095)*140))
  elif name=='impact_metal':v=(math.sin(t*math.tau*1600)+math.sin(t*math.tau*2353))*.18*math.exp(-t*22)+n*.15*math.exp(-t*70)
  elif name=='ricochet':v=math.sin(t*math.tau*(2000-1300*t))*.22*math.exp(-t*18)
  else:v=n*.42*math.exp(-t*45)
  data.append(struct.pack('<h',int(max(-1,min(1,v))*24000)))
 with wave.open(str(p/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(b''.join(data))
