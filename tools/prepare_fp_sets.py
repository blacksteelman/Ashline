#!/usr/bin/env python3
"""Copy the ccransh first-person sets (CC-BY) into the game with lighter textures.

python3 tools/prepare_fp_sets.py [key ...]
assets/thirdparty/sketchfab/<key>/scene.gltf -> assets/viewmodels/<key>/scene.gltf (+ .bin),
textures <= 2048 px re-encoded as JPEG (RGB) or PNG (when alpha is used). The rig, skinning and
animations are untouched; scripts/first_person_rig.gd aligns the Head_Cam bone with the camera.
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'thirdparty', 'sketchfab')
OUT = os.path.join(ROOT, 'assets', 'viewmodels')
KEYS = ['fp_acr', 'fp_ak74m', 'fp_smg', 'fp_sniper', 'fp_pistol']
LIMIT = 2048


def prepare(key):
    src = os.path.join(SRC, key); dst = os.path.join(OUT, key)
    shutil.rmtree(dst, ignore_errors=True); os.makedirs(dst)
    gltf = json.load(open(os.path.join(src, 'scene.gltf')))
    for buf in gltf.get('buffers', []):
        shutil.copy(os.path.join(src, buf['uri']), os.path.join(dst, buf['uri']))
    for i, image in enumerate(gltf.get('images', [])):
        im = Image.open(os.path.join(src, image['uri']))
        if max(im.size) > LIMIT:
            s = LIMIT / max(im.size)
            im = im.resize((int(im.size[0] * s), int(im.size[1] * s)), Image.LANCZOS)
        alpha = im.mode in ('RGBA', 'LA') and np.asarray(im.convert('RGBA'))[..., 3].min() < 250
        base = os.path.splitext(os.path.basename(image['uri']))[0]
        if alpha:
            name = base + '.png'; im.convert('RGBA').save(os.path.join(dst, name), optimize=True)
            image['mimeType'] = 'image/png'
        else:
            name = base + '.jpg'; im.convert('RGB').save(os.path.join(dst, name), quality=90)
            image['mimeType'] = 'image/jpeg'
        image['uri'] = name
    json.dump(gltf, open(os.path.join(dst, 'scene.gltf'), 'w'))
    shutil.copy(os.path.join(src, 'source.json'), os.path.join(dst, 'source.json'))
    size = sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst))
    print('prepared', key, size // 1024, 'KB')


if __name__ == '__main__':
    for key in sys.argv[1:] or KEYS:
        prepare(key)
