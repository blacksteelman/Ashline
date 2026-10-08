"""Original neutral woven albedo; material tint supplies the uniform/gear color."""
from pathlib import Path
from PIL import Image
import numpy as np
p=Path(__file__).parent
cloth=np.asarray(Image.open(p/'cloth.png').convert('RGB'),dtype=np.float32)
weave=cloth.mean(axis=2);weave=np.clip(weave/weave.mean()*210,175,238).astype(np.uint8)
Image.fromarray(np.repeat(weave[:,:,None],3,axis=2)).save(p/'cloth_weave.png')
