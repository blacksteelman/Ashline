#!/usr/bin/env python3
"""Generate ASHLINE camouflage textures (original procedural patterns).

Styles follow the look and palettes of well-known field patterns:
  multicam  - soft organic blotches over a tan-to-olive gradient with thin dark branches
  emr       - Russian digital "flora": square pixels, grey-green base, greens and dark brown
  mm14      - Ukrainian pixel pattern: small pixels in slanted streaks, khaki/olive/brown/dark green
The patterns are generated here; no third-party camo artwork is copied.
Output: assets/textures/camo_<style>_albedo.jpg (tileable, woven fabric detail baked in).
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, 'assets', 'textures')
N = 1024


def hexrgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def tile_noise(res, octaves, seed, stretch=(1.0, 1.0), base=4):
    """Tileable fractal noise in [0,1]: periodic lattice, bicubic upsampling."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((res, res), np.float32); amp = 1.0; total = 0.0
    for o in range(octaves):
        cells = base * 2 ** o
        cy, cx = max(2, int(cells * stretch[1])), max(2, int(cells * stretch[0]))
        g = rng.standard_normal((cy, cx)).astype(np.float32)
        g = np.tile(g, (3, 3))
        img = Image.fromarray(g).resize((res * 3, res * 3), Image.BICUBIC)
        acc += amp * np.asarray(img)[res:2 * res, res:2 * res]
        total += amp; amp *= 0.5
    acc /= total
    acc -= acc.min(); acc /= max(1e-6, acc.max())
    return acc


def fabric(res):
    path = os.path.join(TEX, 'fabric_canvas_albedo.jpg')
    if not os.path.exists(path):
        return np.ones((res, res), np.float32)
    lum = np.asarray(Image.open(path).convert('L').resize((res, res)), np.float32) / 255.0
    return lum / lum.mean()


def save(name, rgb):
    rgb = rgb * (0.92 + 0.08 * fabric(N))[..., None] * fabric(N)[..., None] ** 0.35
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(TEX, f'camo_{name}_albedo.jpg'), quality=92)
    print('camo', name)


def multicam():
    y = np.linspace(0, 1, N)[:, None] * np.ones((1, N))
    wave = 0.5 + 0.5 * np.sin(y * np.pi * 2)  # tileable vertical drift
    base = hexrgb('#b8a77d') * (1 - wave[..., None]) + hexrgb('#8f9466') * wave[..., None]
    img = base.copy()
    layers = [('#8a8a5c', 0.58, 11), ('#a6906a', 0.60, 12), ('#66713f', 0.68, 13), ('#6b5038', 0.72, 14), ('#d4c6a0', 0.75, 15)]
    for color, threshold, seed in layers:
        field = tile_noise(N, 5, seed, (1.0, 1.4), base=7)
        mask = np.asarray(Image.fromarray((field > threshold).astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(1.6)), np.float32) / 255.0
        img = img * (1 - mask[..., None]) + hexrgb(color) * mask[..., None]
    # thin dark-brown branches
    ridge = 1 - np.abs(tile_noise(N, 4, 21, (1.0, 2.2), base=6) - 0.5) * 2
    branch = np.clip((ridge - 0.955) / 0.03, 0, 1) * (tile_noise(N, 3, 22, base=6) > 0.5)
    img = img * (1 - branch[..., None] * 0.85) + hexrgb('#3e2f22') * branch[..., None] * 0.85
    save('multicam', img)


def pixelate(classes, cell):
    small = classes[::cell, ::cell]
    return np.kron(small, np.ones((cell, cell), dtype=classes.dtype))[:N, :N]


def emr():
    palette = [hexrgb(c) for c in ('#9aa084', '#717e57', '#4a5639', '#2f2a22')]
    a = tile_noise(N, 5, 31, base=9); b = tile_noise(N, 5, 32, base=9); c = tile_noise(N, 6, 33, base=12)
    cls = np.zeros((N, N), np.int32)
    cls[a > 0.55] = 1
    cls[b > 0.62] = 2
    cls[(c > 0.66) & (a > 0.4)] = 3
    cls = pixelate(cls, 8)
    save('emr', np.stack([palette[k] for k in range(4)])[cls])


def mm14():
    palette = [hexrgb(c) for c in ('#8e8a68', '#5f6a44', '#5b4835', '#2f3626')]
    # Slanted streak shapes: noise sampled on a sheared grid.
    yy, xx = np.mgrid[0:N, 0:N]
    a = tile_noise(N, 5, 41, (1.0, 2.0), base=8); b = tile_noise(N, 5, 42, (1.0, 2.0), base=8); c = tile_noise(N, 6, 43, (1.0, 2.0), base=10)
    shift = (yy * 0.6).astype(np.int32) % N
    sheared = lambda f: f[yy, (xx + shift) % N]
    a, b, c = sheared(a), sheared(b), sheared(c)
    cls = np.zeros((N, N), np.int32)
    cls[a > 0.56] = 1
    cls[b > 0.6] = 2
    cls[c > 0.68] = 3
    cls = pixelate(cls, 6)
    save('mm14', np.stack([palette[k] for k in range(4)])[cls])


if __name__ == '__main__':
    multicam(); emr(); mm14()
