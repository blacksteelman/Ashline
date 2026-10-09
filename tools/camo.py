#!/usr/bin/env python3
"""Generate ASHLINE camouflage textures (original procedural patterns).

Styles follow the look and palettes of well-known field patterns:
  ocp       - OCP / Scorpion W2 (US Army pattern, public domain), palette from the official swatch
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


def save(name, rgb, weave=1.0):
    f = fabric(N)
    rgb = rgb * (1 + (f - 1) * 0.12 * weave)[..., None]
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(TEX, f'camo_{name}_albedo.jpg'), quality=92)
    print('camo', name)


def soft_mask(field, threshold, blur):
    m = (field > threshold).astype(np.uint8) * 255
    return np.asarray(Image.fromarray(m).filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255.0


def lay(img, mask, color, strength=1.0):
    m = mask[..., None] * strength
    return img * (1 - m) + hexrgb(color) * m


OCP_SWATCH = os.path.join(ROOT, 'assets', 'thirdparty', 'camo', 'scorpion_w2_swatch.png')
OCP_URL = 'https://commons.wikimedia.org/wiki/Special:FilePath/Scorpion_W2,_Operational_Camouflage_Pattern_(OCP)_swatch.png'


def seamless(rgb):
    """Make an image tile: blend it with a half-offset copy under a feathered cross mask."""
    n = rgb.shape[0]
    shifted = np.roll(np.roll(rgb, n // 2, 0), n // 2, 1)
    t = np.abs(np.linspace(-1, 1, n))
    edge = np.clip((np.maximum(t[:, None], t[None, :]) - 0.55) / 0.4, 0, 1)
    edge = edge * edge * (3 - 2 * edge)
    return rgb * (1 - edge[..., None]) + shifted * edge[..., None]


def ocp():
    """OCP / Scorpion W2 from the US Army swatch (public domain, PD-USGov-Military-Army),
    upscaled and made seamless; the swatch is fetched once into assets/thirdparty/camo."""
    if not os.path.exists(OCP_SWATCH):
        os.makedirs(os.path.dirname(OCP_SWATCH), exist_ok=True)
        os.system(f'curl -sSL -A "AshlineAssetFetch/0.8" -o "{OCP_SWATCH}" "{OCP_URL}"')
    src = Image.open(OCP_SWATCH).convert('RGB')
    src = src.crop((4, 4, src.size[0] - 4, src.size[1] - 4))  # the scan has a light border
    side = min(src.size)
    sq = src.crop(((src.size[0] - side) // 2, (src.size[1] - side) // 2, (src.size[0] + side) // 2, (src.size[1] + side) // 2))
    big = np.asarray(sq.resize((N, N), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 60, 2)), np.float32)
    rgb = seamless(big)
    # The photo is slightly washed out: restore some saturation and contrast.
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    rgb = lum[..., None] + (rgb - lum[..., None]) * 1.25
    rgb = (rgb - 118) * 1.1 + 118
    save('ocp', rgb, weave=0.25)


def pixelate(classes, cell):
    small = classes[::cell, ::cell]
    return np.kron(small, np.ones((cell, cell), dtype=classes.dtype))[:N, :N]


def emr():
    """Russian digital 'Tsifra' summer look: light grey-green field, green, brown and black pixels
    grouped into blotches (original generation, approximate palette)."""
    palette = [hexrgb(c) for c in ('#8e9878', '#5d7046', '#4b4232', '#22231d')]
    a = tile_noise(N, 5, 31, (1.0, 1.3), base=18); b = tile_noise(N, 5, 32, (1.0, 1.3), base=22); c = tile_noise(N, 6, 33, base=28)
    cls = np.zeros((N, N), np.int32)
    cls[a > 0.53] = 1
    cls[(b > 0.60) & (a > 0.45)] = 2
    cls[(c > 0.70) & (b > 0.5)] = 3
    cls = pixelate(cls, 4)
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


def glove():
    """Tactical glove: coyote synthetic weave, tiled 4x so it reads at hand scale."""
    src = Image.open(os.path.join(TEX, 'fabric_canvas_albedo.jpg')).convert('L').resize((256, 256))
    lum = np.tile(np.asarray(src, np.float32) / 255.0, (4, 4))
    lum = lum / lum.mean()
    wear = tile_noise(1024, 4, 71, base=3)  # darker, worn patches
    rgb = hexrgb('#6f604a')[None, None, :] * (0.78 + 0.22 * lum[..., None]) * (0.86 + 0.14 * wear[..., None])
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(TEX, 'glove_tactical_albedo.jpg'), quality=92)
    nrm = Image.open(os.path.join(TEX, 'fabric_canvas_normal.jpg')).resize((256, 256))
    Image.fromarray(np.tile(np.asarray(nrm), (4, 4, 1))).save(os.path.join(TEX, 'glove_tactical_normal.jpg'), quality=92)
    print('glove')


if __name__ == '__main__':
    ocp(); emr(); mm14(); glove()
