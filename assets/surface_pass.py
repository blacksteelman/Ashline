"""Original deterministic weathered surface maps. No external image inputs."""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import numpy as np, random
P=Path(__file__).parent
rng=np.random.default_rng(316);random.seed(316);N=1024

def noise(size):
 return np.asarray(Image.fromarray(rng.integers(0,256,(size,size),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC),float)/255

def save(name,base,height,rough):
 Image.fromarray(np.uint8(np.clip(base,0,255))).save(P/(name+'.png'))
 h=np.asarray(Image.fromarray(np.uint8(np.clip(height,0,255))).filter(ImageFilter.GaussianBlur(.7)),float)
 dx=(np.roll(h,1,1)-np.roll(h,-1,1))*.035;dy=(np.roll(h,1,0)-np.roll(h,-1,0))*.035
 normal=np.stack([dx,dy,np.ones_like(dx)],-1);normal/=np.linalg.norm(normal,axis=2)[...,None]
 Image.fromarray(np.uint8((normal*.5+.5)*255)).save(P/(name+'_normal.png'))
 Image.fromarray(np.uint8(np.clip(rough,0,255))).save(P/(name+'_roughness.png'))

low=noise(8);mid=noise(48);grain=noise(1024)
for name,color in [('concrete',(104,107,98)),('plaster',(146,141,123)),('asphalt',(43,47,45)),('metal',(89,103,99))]:
 variation=(low-.5)*24+(mid-.5)*13+(grain-.5)*12
 base=np.array(color)[None,None,:]+variation[...,None]
 h=140+(grain-.5)*35+(mid-.5)*20
 if name=='asphalt':
  flecks=grain>.91;base[flecks]+=18;h[flecks]+=22
 if name=='metal':
  rust=(low*mid)>.40;base[rust]=base[rust]*.45+np.array([83,47,23]);h[rust]-=12
 canvas=Image.fromarray(np.uint8(np.clip(base,0,255)));d=ImageDraw.Draw(canvas)
 for i in range(15 if name!='asphalt' else 5):
  x,y=random.randrange(N),random.randrange(N);points=[(x,y)]
  for j in range(random.randrange(3,9)):
   x+=random.randrange(-16,18);y+=random.randrange(5,28);points.append((x,y))
  d.line(points,fill=tuple(int(c*.63) for c in color),width=1)
 save(name,np.asarray(canvas),h,205+(mid-.5)*45 if name!='metal' else 135+mid*70)
# Fired brick: irregular courses, chipped mortar, individual colour, fine grain.
base=np.zeros((N,N,3))+np.array([63,65,57]);height=np.ones((N,N))*75
for row,y in enumerate(range(-64,N,64)):
 for x in range(-160,N,160):
  xx=x+(80 if row%2 else 0);y0=max(0,y+5);y1=min(N,y+61);x0=max(0,xx+4);x1=min(N,xx+156)
  if y1<=y0 or x1<=x0:continue
  patch=(slice(y0,y1),slice(x0,x1));col=np.array([119,83,60])*random.uniform(.78,1.12)
  shade=(mid[patch]-.5)*30+(grain[patch]-.5)*14
  base[patch]=col+shade[...,None];height[patch]=155+(grain[patch]-.5)*22
  base[y0:y0+2,x0:x1]*=1.15;base[y1-3:y1,x0:x1]*=.73
save('brick',base,height,195+mid*40)
# Tiling gun microfinish kept neutral so each component can use its own tint.
gun=195+(grain-.5)*24+(mid-.5)*12
im=Image.fromarray(np.uint8(np.clip(gun,0,255))).convert('RGB');d=ImageDraw.Draw(im)
for i in range(130):
 x,y=random.randrange(N),random.randrange(N);d.line((x,y,x+random.randrange(2,15),y+random.randrange(-1,2)),fill=(219,220,214),width=1)
save('gunfinish',np.asarray(im),135+(grain-.5)*18,135+(mid-.5)*60)
# Soft, uneven dirt stains for the lower edge of walls, stored as a transparent decal.
a=np.clip((np.arange(N)[:,None]/N)**1.65*(.35+low*.55)*225,0,210)
rgba=np.zeros((N,N,4),dtype=np.uint8);rgba[:,:,:3]=(29,30,24);rgba[:,:,3]=a.astype(np.uint8)
Image.fromarray(rgba).save(P/'wall_grime.png')
print('Weathered PBR maps generated')
