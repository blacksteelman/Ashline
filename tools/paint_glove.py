#!/usr/bin/env python3
"""Paint the first-person tactical glove in the arm mesh's UV space.

python3 tools/paint_glove.py
1. Blender (tools/build_viewmodels.py helpers) exports every arm polygon with its dominant bone,
   UVs, palm-side factor and distance along the hand -> build/glove_uv.json
2. Regions are painted: black nylon back, TPR knuckle guard and finger pads, coyote synthetic
   suede palm, reinforced fingertips and thumb crotch, elastic cuff with a hook-and-loop tab.
   Region borders get seams and stitching. Output: assets/textures/glove_tactical_{albedo,normal}.jpg
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, 'assets', 'textures')
DATA = os.path.join(ROOT, 'build', 'glove_uv.json')
S = 2048

EXPORT = r'''
import bpy, sys, json
sys.argv = ['blender', '--', 'ar', '--solve-only']
__file__ = %r
exec(open(__file__).read().split("\nfor weapon, spec in WEAPONS.items():")[0])
clear_scene()
rig, body = load_arms()
me = body.data; uv = me.uv_layers.active.data
groups = {g.index: g.name for g in body.vertex_groups}
frames = {sd: hand_frame(rig, sd) for sd in 'LR'}
heads = {sd: rig.data.bones['hand.' + sd].head_local for sd in 'LR'}
out = []
for poly in me.polygons:
    weights = {}
    for vi in poly.vertices:
        for g in me.vertices[vi].groups:
            weights[g.group] = weights.get(g.group, 0) + g.weight
    name = groups[max(weights, key=weights.get)] if weights else '-'
    sd = name[-1] if name[-2:] in ('.L', '.R') else 'R'
    fr = frames[sd]
    n = (body.matrix_world.to_3x3() @ poly.normal).normalized()
    c = body.matrix_world @ poly.center
    out.append([name, [list(uv[li].uv) for li in poly.loop_indices], n.dot(fr.col[2]), (c - heads[sd]).dot(fr.col[0])])
json.dump(out, open(%r, 'w'))
print('GLOVE_UV', len(out))
'''


def export():
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    script = os.path.join(ROOT, 'build', 'glove_uv_export.py')
    open(script, 'w').write(EXPORT % (os.path.join(ROOT, 'tools', 'build_viewmodels.py'), DATA))
    subprocess.run(['blender', '-b', '--python', script], check=True, stdout=subprocess.DEVNULL)


def hexrgb(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


# Region id -> (colour, roughness-ish weave strength)
REGIONS = {
    1: ('#1d1e1c', 1.0),   # black nylon back / finger backs
    2: ('#30322e', 0.25),  # TPR knuckle guard and finger pads
    3: ('#77684f', 0.7),   # coyote synthetic suede palm
    4: ('#5b4f3d', 0.5),   # reinforced fingertips / thumb crotch
    5: ('#151614', 0.9),   # elastic cuff
    6: ('#2a2b28', 1.2),   # hook-and-loop tab
}


def region(name, palm, along):
    base = name.split('.')[0]
    if base in ('upper_arm',):
        return 5
    if base == 'forearm':
        return 6 if along > -0.055 and palm < -0.4 else 5
    finger = base.startswith('f_') or base == 'thumb'
    segment = name.split('.')[1] if '.' in name else ''
    if palm > 0.2:  # palm side
        if (finger and segment == '03') or base == 'thumb' and segment == '01':
            return 4
        return 3
    if finger and segment == '02' and base != 'thumb':
        return 2
    if base.startswith('palm') and along > 0.06:
        return 2
    return 1


def main():
    if not os.path.exists(DATA) or '--export' in sys.argv:
        export()
    polys = json.load(open(DATA))
    ids = Image.new('L', (S, S), 0)
    draw = ImageDraw.Draw(ids)
    for name, uv, palm, along in polys:
        pts = [(u * S, (1 - v) * S) for u, v in uv]
        draw.polygon(pts, fill=region(name, palm, along))
    # Grow islands a little so mip-mapping does not pull in the background.
    rid = np.asarray(ids)
    grown = np.asarray(ids.filter(ImageFilter.MaxFilter(9)))
    rid = np.where(rid > 0, rid, grown)
    weave_src = Image.open(os.path.join(TEX, 'fabric_canvas_albedo.jpg')).convert('L').resize((256, 256))
    weave = np.tile(np.asarray(weave_src, np.float32) / 255.0, (S // 256, S // 256))
    weave = weave / weave.mean()
    rng = np.random.default_rng(5)
    grain = np.asarray(Image.fromarray((rng.random((S // 4, S // 4)) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), np.float32) / 255.0
    rgb = np.zeros((S, S, 3), np.float32)
    for k, (color, strength) in REGIONS.items():
        m = rid == k
        tone = 1 + (weave - 1) * 0.35 * strength + (grain - 0.5) * 0.08
        rgb[m] = hexrgb(color)[None, :] * tone[m][:, None]
    # Seams: darken region borders, add a light stitch line beside them.
    edge = np.asarray(Image.fromarray(rid).filter(ImageFilter.FIND_EDGES), np.float32) > 0
    edge_img = Image.fromarray((edge * 255).astype(np.uint8))
    seam = np.asarray(edge_img.filter(ImageFilter.MaxFilter(5)), np.float32) / 255.0
    stitch_band = np.asarray(edge_img.filter(ImageFilter.MaxFilter(11)), np.float32) / 255.0 - seam
    dashes = ((np.arange(S)[:, None] + np.arange(S)[None, :]) // 7) % 2
    stitch = np.clip(stitch_band, 0, 1) * dashes * 0.5
    rgb *= (1 - 0.45 * seam)[..., None]
    rgb += stitch[..., None] * 38
    # Grime on palms and fingertips.
    wear = np.asarray(Image.fromarray((rng.random((256, 256)) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), np.float32) / 255.0
    worn = np.isin(rid, [3, 4]) * (wear > 0.6)
    rgb[worn] *= 0.94
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS).save(os.path.join(TEX, 'glove_tactical_albedo.jpg'), quality=92)
    # Normal: fabric weave plus raised TPR pads and recessed seams (height -> normal).
    height = (weave - 1) * 0.6 * np.isin(rid, [1, 3, 5, 6]) + np.isin(rid, [2]).astype(np.float32) * 1.2 - seam * 1.5
    height = np.asarray(Image.fromarray(((height - height.min()) / (np.ptp(height) + 1e-6) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    gy, gx = np.gradient(height * 6.0)
    nrm = np.stack([-gx, gy, np.ones_like(gx)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS).save(os.path.join(TEX, 'glove_tactical_normal.jpg'), quality=92)
    print('glove painted', {k: int((rid == k).sum()) for k in REGIONS})


if __name__ == '__main__':
    main()
