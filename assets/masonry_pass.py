"""Original deterministic surface treatment with individual brick wear and soot."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,random
P=Path(__file__).parent;N=1024;rng=np.random.default_rng(4004);random.seed(4004)
def noise(n):
 return np.asarray(Image.fromarray(rng.integers(0,256,(n,n),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC),float)/255
broad=noise(10);medium=noise(80);fine=noise(512)
base=np.full((N,N,3),(98,95,81),float);height=85+fine*10
for row,y in enumerate(range(-60,N,74)):
 for x in range(-200,N,186):
  xx=x+(93 if row%2 else 0)
  mask=Image.new('L',(N,N));d=ImageDraw.Draw(mask)
  left=xx+random.randrange(3,7);top=y+random.randrange(3,6);right=xx+178;bottom=y+68
  d.rounded_rectangle((left,top,right,bottom),radius=random.randrange(3,7),fill=255)
  a=np.asarray(mask.filter(ImageFilter.GaussianBlur(1.0)),float)/255
  col=np.array(random.choice([(112,83,65),(125,91,69),(96,79,66),(136,104,83),(103,87,76)]),float)
  wear=(broad-.5)*20+(medium-.5)*16+(fine-.5)*16
  shade=col[None,None,:]+wear[...,None]
  # Flaking and pitting are embedded inside each course, not uniformly noisy mortar.
  chips=(fine>.85)&(medium>.54);shade[chips]*=.75
  base=base*(1-a[...,None])+shade*a[...,None]
  height=height*(1-a)+(143+(fine-.5)*12)*a
soot=np.clip((broad-.56)*1.2,0,.35);base*=1-soot[...,None]
Image.fromarray(np.uint8(np.clip(base,0,255))).save(P/'brick.png')
h=np.asarray(Image.fromarray(np.uint8(height)).filter(ImageFilter.GaussianBlur(.7)),float)
dx=(np.roll(h,1,1)-np.roll(h,-1,1))*.055;dy=(np.roll(h,1,0)-np.roll(h,-1,0))*.055
normal=np.stack([dx,dy,np.ones_like(dx)],-1);normal/=np.linalg.norm(normal,axis=2)[...,None]
Image.fromarray(np.uint8((normal*.5+.5)*255)).save(P/'brick_normal.png')
Image.fromarray(np.uint8(np.clip(205+(medium-.5)*25,0,255))).save(P/'brick_roughness.png')
# A road aggregate texture with restrained contrast, avoiding giant cloudy stains.
asphalt=np.array([48,49,45])[None,None,:]+((medium-.5)*8+(fine-.5)*17)[...,None]
pebbles=(fine>.86)&(medium>.5);asphalt[pebbles]+=9
Image.fromarray(np.uint8(np.clip(asphalt,0,255))).save(P/'asphalt.png')
print('Original weathered masonry and restrained road albedo authored')
