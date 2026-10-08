from PIL import Image,ImageDraw,ImageFilter
import random,math,wave,struct
from pathlib import Path
random.seed(447)
p=Path(__file__).parent
for name,base in [('concrete',(119,115,105)),('asphalt',(53,57,59)),('brick',(114,70,52)),('metal',(78,89,87)),('plaster',(157,151,130))]:
 im=Image.new('RGB',(512,512)); pix=im.load()
 for y in range(512):
  for x in range(512):
   n=random.gauss(0,7)+5*math.sin(x*.035)*math.sin(y*.019)
   pix[x,y]=tuple(int(max(0,min(255,c+n))) for c in base)
 d=ImageDraw.Draw(im)
 if name=='brick':
  for y in range(0,512,32):
   d.line((0,y,512,y),fill=(64,63,54),width=3)
   for x in range(-64,512,96): d.line((x+(48 if y%64 else 0),y,x+(48 if y%64 else 0),y+32),fill=(64,63,54),width=3)
 for i in range(45):
  x,y=random.randrange(512),random.randrange(512)
  pts=[(x,y)]
  for j in range(random.randint(2,7)): x+=random.randint(-12,12);y+=random.randint(5,20);pts.append((x,y))
  d.line(pts,fill=tuple(int(c*.55) for c in base),width=1)
 im.save(p/(name+'.png'))
 # Original height-derived normal map
 gray=im.convert('L').filter(ImageFilter.GaussianBlur(1)); nm=Image.new('RGB',im.size);np=nm.load();gp=gray.load()
 for y in range(512):
  for x in range(512): np[x,y]=(int(128+(gp[(x-1)%512,y]-gp[(x+1)%512,y])*.5),int(128+(gp[x,(y-1)%512]-gp[x,(y+1)%512])*.5),250)
 nm.save(p/(name+'_normal.png'))
for name,duration in [('rifle',.22),('smg',.17),('marksman',.35),('pistol',.18),('reload',.8),('step',.12),('hit',.07),('kill',.25),('explosion',1.1),('ambient',8)]:
 data=[]
 for i in range(int(22050*duration)):
  t=i/22050;n=random.uniform(-1,1)
  if name in ['rifle','smg','marksman','pistol']: v=(n*.65+math.sin(t*math.tau*(95 if name=='marksman' else 155))*.4)*math.exp(-t*27)*(min(t*1200,1))
  elif name=='explosion': v=(n*.6+math.sin(t*math.tau*43)*.4)*math.exp(-t*4)
  elif name=='ambient':v=n*.035+math.sin(t*math.tau*57)*.016
  elif name=='step':v=n*.35*math.exp(-t*40)
  elif name=='reload':v=n*.25*sum(math.exp(-abs(t-k)*130) for k in [.02,.29,.67])
  else:v=math.sin(t*math.tau*(1800 if name=='hit' else 900))*math.exp(-t*24)*.22
  data.append(struct.pack('<h',int(max(-1,min(1,v)) * 26000)))
 with wave.open(str(p/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050);w.writeframes(b''.join(data))
