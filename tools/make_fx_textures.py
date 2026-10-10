#!/usr/bin/env python3
"""Procedural combat FX textures (original, CC0): muzzle flash (front + side), bullet hole decal, spark.

python3 tools/make_fx_textures.py  ->  assets/fx/*.png
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'fx')
rng = np.random.default_rng(11)


def noise(size, cells, seed):
    r = np.random.default_rng(seed).random((cells, cells)).astype(np.float32)
    return np.asarray(Image.fromarray((r * 255).astype(np.uint8)).resize(size, Image.BICUBIC), np.float32) / 255


def fbm(size, seed, octaves=(4, 8, 16, 32)):
    out = np.zeros(size[::-1], np.float32); w = 1.0; total = 0
    for i, c in enumerate(octaves):
        out += noise(size, c, seed + i) * w; total += w; w *= .55
    return out / total


def flame_color(t):
    """0..1 heat -> colour: deep orange edge, yellow body, white core."""
    stops = np.array([[0.0, .55, .16, .02], [.45, 1.0, .55, .12], [.75, 1.0, .86, .45], [1.0, 1.0, 1.0, .95]])
    rgb = np.stack([np.interp(t, stops[:, 0], stops[:, k]) for k in (1, 2, 3)], -1)
    return rgb


def save(name, rgb, alpha):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name))


def muzzle_front(seed):
    s = 256; y, x = np.mgrid[0:s, 0:s].astype(np.float32); x = (x - s / 2) / (s / 2); y = (y - s / 2) / (s / 2)
    r = np.hypot(x, y); a = np.arctan2(y, x)
    petals = 4 + seed % 3
    lobes = (0.6 + 0.4 * np.cos(petals * a + seed)) ** 1.6
    turb = fbm((s, s), seed)
    reach = 0.3 + 0.62 * lobes * (0.55 + 0.7 * turb)
    heat = np.clip(1 - r / reach, 0, 1) ** 1.4
    core = np.exp(-(r / 0.22) ** 2)
    heat = np.clip(heat * (0.75 + 0.5 * turb) + core, 0, 1)
    save(f'muzzle_front_{seed}.png', flame_color(heat), np.clip(heat * 1.6, 0, 1))


def muzzle_side(seed):
    w, h = 256, 128; y, x = np.mgrid[0:h, 0:w].astype(np.float32); u = x / w; v = (y - h / 2) / (h / 2)
    turb = fbm((w, h), seed + 20, (6, 12, 24, 48))
    width = 0.12 + 0.75 * u ** 0.6 * (0.7 + 0.5 * turb)          # cone opening along the barrel axis
    body = np.clip(1 - np.abs(v) / width, 0, 1) ** 1.2
    length = np.clip(1 - u / (0.78 + 0.2 * turb), 0, 1)
    heat = body * length ** 0.8 * (0.8 + 0.7 * turb) * 1.35
    heat += np.exp(-(v / (0.1 + 0.25 * u)) ** 2) * length * 0.6       # hot jet along the axis
    heat += np.exp(-((u - .02) / .06) ** 2 - (v / .25) ** 2) * .8      # bright base at the muzzle
    heat = np.clip(heat, 0, 1)
    save(f'muzzle_side_{seed}.png', flame_color(heat), np.clip(heat * 1.5, 0, 1))


def bullet_hole():
    s = 128; y, x = np.mgrid[0:s, 0:s].astype(np.float32); x = (x - s / 2) / (s / 2); y = (y - s / 2) / (s / 2)
    r = np.hypot(x, y); a = np.arctan2(y, x)
    jag = 1 + 0.25 * fbm((s, s), 5) + 0.12 * np.cos(7 * a)
    hole = np.clip(1 - r / (0.24 * jag), 0, 1) ** 0.6
    chip = np.clip(1 - r / (0.62 * jag), 0, 1)
    cracks = np.zeros((s, s), np.float32)
    for k in range(6):
        ang = rng.uniform(0, 2 * np.pi); width = 0.035
        d = np.abs(np.sin(a - ang)) * r
        cracks = np.maximum(cracks, np.clip(1 - d / width, 0, 1) * (np.cos(a - ang) > 0) * np.clip(1 - r / rng.uniform(.5, .9), 0, 1))
    shade = 0.16 + 0.22 * fbm((s, s), 9)
    rgb = np.dstack([shade] * 3) * (1 - 0.85 * hole[..., None])
    alpha = np.clip(np.maximum(hole * 1.0, chip ** 0.5 * 0.9) + cracks * 0.5, 0, 1)
    alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    save('bullet_hole.png', rgb, alpha)


def spark():
    w, h = 64, 16; y, x = np.mgrid[0:h, 0:w].astype(np.float32); u = x / w; v = (y - h / 2) / (h / 2)
    heat = np.exp(-(v / .35) ** 2) * (1 - u) ** .7
    save('spark.png', flame_color(np.clip(heat * 1.2, 0, 1)), heat)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for i in range(3):
        muzzle_front(i); muzzle_side(i)
    bullet_hole(); spark()
    print('fx textures in', OUT)
