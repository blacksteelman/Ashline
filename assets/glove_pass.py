"""Derive a dark field-glove finish from the CC0 arm UV texture.
The texture preserves crease shading; authored grain changes the surface to fabric.
"""
from pathlib import Path
from PIL import Image
import numpy as np
p=Path(__file__).resolve().parent
source=np.asarray(Image.open(p/'thirdparty/viewmodel/arms/new_diff.png').convert('RGB'),dtype=float)/255
luma=source@np.array([.2126,.7152,.0722])
rng=np.random.default_rng(707)
grain=rng.normal(0,.025,luma.shape)
finish=np.clip((.65+luma*.65+grain)[...,None]*np.array([.20,.215,.185]),0,1)
Image.fromarray((finish*255).astype('uint8')).save(p/'field_glove.png')
