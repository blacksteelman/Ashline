from PIL import Image
import numpy as np
from pathlib import Path
p=Path(__file__).parent;rng=np.random.default_rng(303)
y,x=np.mgrid[-1:1:128j,-1:1:128j];r=np.sqrt(x*x+y*y);angle=np.arctan2(y,x)
for name in ['smoke','muzzle']:
 if name=='smoke':
  alpha=np.clip(1-r,0,1)**2*np.clip(1+.25*np.sin(x*12)*np.cos(y*10)+rng.normal(0,.025,r.shape),.6,1);rgb=np.full((128,128,3),220)
 else:
  star=.28+.3*np.maximum(0,np.cos(angle*5))**7
  alpha=np.clip((star-r)*5,0,1)+np.exp(-r*r*60)
  rgb=np.stack([np.full(r.shape,255),np.clip(220-r*145,0,255),np.clip(160-r*170,0,255)],axis=-1)
 data=np.concatenate([rgb,np.clip(alpha*255,0,255)[:,:,None]],axis=-1).astype(np.uint8);Image.fromarray(data).save(p/(name+'.png'))
