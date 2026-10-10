#!/usr/bin/env python3
"""Repaint the first-person arms (FP Arms, CC-BY DJMaesen/bumstrum) to match each team's soldier.

godot --headless --path . --script tests/export_arms_uv.gd   # -> build/arms_uv.json (UVs + glove weight per triangle)
python3 tools/paint_fp_arms.py                               # -> assets/viewmodels/arms_<team>_albedo.jpg

UV islands are glove or sleeve by the majority of their triangles' skin weights (hand/finger bones = glove), so
the split follows the texture's own cuff. The original texture supplies the folds, seams and shading (its
luminance relative to a blurred copy); the colour comes from the team's soldier: Aegis = OCP sleeve, coyote
gloves; Ember = the FSB uniform's leaf pattern (a patch of its own texture), dark gloves. The OCP tile is matched to
the soldier's real uniform pixels channel by channel.
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'viewmodels', 'fp_acr', 'arms_baseColor.jpg')
OUT = os.path.join(ROOT, 'assets', 'viewmodels')
CHAR = os.path.join(ROOT, 'assets', 'characters')
TEX = os.path.join(ROOT, 'assets', 'textures')
S = 2048
CONTRAST = {'aegis': 1.35, 'ember': 1.1}

TEAMS = {
    # camo tile, soldier uniform texture (colour reference), soldier glove texture, camo tiles per UV unit
    'aegis': ('camo_ocp_albedo.jpg', 'soldier_aegis_uniform_recolor.jpg', 'soldier_aegis_gloves_recolor.jpg', 1.6),
    # Ember: the FSB uniform has no clean tile, so its leaf pattern is regenerated in the uniform's colours.
    'ember': ('leaf', 'soldier_ember_uniform_baseColor_jpeg.jpg', 'soldier_ember_gloves_baseColor_jpeg.jpg', 2.0),
}


def islands(tris):
    """Union-find over triangles sharing a UV vertex -> island id per triangle."""
    parent = list(range(len(tris)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    owner = {}
    for t, tri in enumerate(tris):
        for u, v in tri[:3]:
            key = (round(u * 8192), round(v * 8192))
            if key in owner:
                a, b = find(owner[key]), find(t)
                if a != b:
                    parent[a] = b
            else:
                owner[key] = t
    return [find(t) for t in range(len(tris))]


def region_map(tris):
    """2048^2 map: 0 empty, 1 glove, 2 sleeve (islands by majority vote, grown into the gutters)."""
    ids = islands(tris)
    votes = {}
    for tri, i in zip(tris, ids):
        g = votes.setdefault(i, [0, 0])
        g[0 if tri[3] > 0.5 else 1] += 1
    img = Image.new('L', (S, S), 0)
    draw = ImageDraw.Draw(img)
    for tri, i in zip(tris, ids):
        value = 1 if votes[i][0] >= votes[i][1] else 2
        draw.polygon([(u * S, v * S) for u, v in tri[:3]], fill=value)
    rid = np.asarray(img)
    for _ in range(4):
        grown = np.asarray(Image.fromarray(rid).filter(ImageFilter.MaxFilter(9)))
        rid = np.where(rid > 0, rid, grown)
    return rid


def tile(path, reps):
    im = Image.open(path).convert('RGB')
    size = int(S / reps)
    t = np.asarray(im.resize((size, size), Image.LANCZOS), np.float32)
    n = int(np.ceil(reps)) + 1
    return np.tile(t, (n, n, 1))[:S, :S]


def noise(rng, size, cells):
    """Seamless smooth noise: a random grid tiled 3x3, upsampled, centre cut out."""
    g = rng.random((cells, cells)).astype(np.float32)
    big = np.asarray(Image.fromarray(np.tile(g, (3, 3)) * 255).convert('L').resize((size * 3, size * 3), Image.BICUBIC), np.float32) / 255
    return big[size:2 * size, size:2 * size]


def leaf_tile(reps, seed=7):
    """Partizan-style leaf camo (FSB uniform): grey-green ground, darker leaf clusters, tan and near-black specks."""
    size = 1024; rng = np.random.default_rng(seed)
    palette = {'ground': (70, 84, 64), 'dark': (50, 66, 48), 'shadow': (34, 40, 33), 'tan': (176, 162, 118)}
    out = np.empty((size, size, 3), np.float32); out[:] = palette['ground']
    def blobs(cells, fine, frac):
        n = noise(rng, size, cells) * 0.65 + noise(rng, size, fine) * 0.35
        return n > np.quantile(n, 1 - frac)
    out[blobs(10, 48, 0.45)] = palette['dark']
    out[blobs(16, 90, 0.16)] = palette['shadow']
    out[blobs(18, 150, 0.17)] = palette['tan']
    t = np.asarray(Image.fromarray(out.astype(np.uint8)).resize((int(S / reps),) * 2, Image.LANCZOS), np.float32)
    n = int(np.ceil(reps)) + 1
    return np.tile(t, (n, n, 1))[:S, :S]


def match(src, ref):
    """Per-channel mean/std transfer of src onto the statistics of ref pixels."""
    out = np.empty_like(src)
    for c in range(3):
        s, r = src[..., c], ref[:, c]
        out[..., c] = (s - s.mean()) / (s.std() + 1e-6) * r.std() + r.mean()
    return out


def cloth_pixels(path):
    """Reference colours: drop near-black gutters and stretched-edge noise."""
    px = np.asarray(Image.open(path).convert('RGB').resize((256, 256)), np.float32).reshape(-1, 3)
    return px[px.sum(1) > 60]


def main():
    tris = json.load(open(os.path.join(ROOT, 'build', 'arms_uv.json')))
    rid = region_map(tris)
    src = np.asarray(Image.open(SRC).convert('RGB'), np.float32)
    lum = src @ np.array([0.299, 0.587, 0.114], np.float32)
    blur = np.asarray(Image.fromarray(np.clip(lum, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)), np.float32)
    detail = np.clip((lum + 4) / (blur + 4), 0.45, 1.8)  # folds, seams, stitching
    glove, sleeve = rid == 1, rid == 2
    print('regions: glove', int(glove.sum()), 'sleeve', int(sleeve.sum()))
    for team, (camo, uniform, gloves, reps) in TEAMS.items():
        if camo == 'leaf':
            cloth = leaf_tile(reps)
        else:
            cloth = match(tile(os.path.join(TEX, camo), reps), cloth_pixels(os.path.join(CHAR, uniform)))
        out = src.copy()
        # Sleeve: camo modulated by the original fold detail and by its broad light/dark (worn, shaded areas).
        broad = np.clip(blur / max(blur[sleeve].mean(), 1), 0.6, 1.35)
        # The viewmodel is lit closer and brighter than the soldiers: a darker, punchier cloth reads the same.
        cloth = (cloth - cloth.mean((0, 1))) * CONTRAST[team] + cloth.mean((0, 1)) * 0.8
        out[sleeve] = (cloth * (detail * (0.55 + 0.45 * broad))[..., None])[sleeve]
        # Gloves: the soldier's glove colour carried by the original glove's luminance.
        ref = cloth_pixels(os.path.join(CHAR, gloves))
        color = np.median(ref, 0)
        shade = lum / max(lum[glove].mean(), 1)
        out[glove] = (color[None, :] * np.clip(shade, 0.25, 2.2)[glove][:, None])
        path = os.path.join(OUT, f'arms_{team}_albedo.jpg')
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path, quality=90)
        print('painted', path, 'glove colour', color.round())


if __name__ == '__main__':
    main()
