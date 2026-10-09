#!/usr/bin/env python3
"""Download CC0 ambientCG PBR sets and convert them to ASHLINE's texture layout.

assets/textures/<key>_albedo.jpg   colour (alpha from Opacity when present -> .png)
assets/textures/<key>_normal.jpg   OpenGL normal
assets/textures/<key>_orm.jpg      R=AO G=roughness B=metalness (glTF/Godot ORM)
Provenance is written to assets/textures/SOURCES_AMBIENTCG.json.
"""
import hashlib, io, json, os, subprocess, sys, time, zipfile
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'textures')

# key: (ambientCG id, albedo/normal size, orm size)
SETS = {
    'road': ('Asphalt026C', 2048, 1024),
    'asphalt_patch': ('Asphalt025C', 1024, 512),
    'concrete_floor': ('Concrete044D', 2048, 1024),
    'concrete_panel': ('Concrete031', 2048, 1024),
    'concrete_smooth': ('Concrete042A', 1024, 512),
    'brick_red': ('Bricks085', 2048, 1024),
    'brick_block': ('Bricks066', 1024, 512),
    'plaster_peel': ('PaintedPlaster016', 2048, 1024),
    'plaster_clean': ('PaintedPlaster017', 1024, 512),
    'gravel': ('Gravel023', 1024, 512),
    'dirt': ('Ground037', 1024, 512),
    'corrugated': ('CorrugatedSteel007A', 1024, 512),
    'corrugated_green': ('CorrugatedSteel006A', 1024, 512),
    'painted_metal': ('PaintedMetal006', 1024, 512),
    'hazard': ('PaintedMetal016', 1024, 512),
    'metal_plates': ('MetalPlates013', 1024, 512),
    'rust': ('Rust009', 1024, 512),
    'walkway': ('MetalWalkway014', 1024, 512),
    'planks': ('Planks037A', 1024, 512),
    'facade_windows': ('Facade018A', 1024, 512),
    'tiles_floor': ('Tiles107', 1024, 512),
    'paving': ('PavingStones136', 1024, 512),
}


def download(asset):
    url = f'https://ambientcg.com/get?file={asset}_2K-JPG.zip'
    for attempt in range(5):
        r = subprocess.run(['curl', '-sSL', '--fail', '--retry', '3', url], capture_output=True)
        if r.returncode == 0:
            return r.stdout
        time.sleep(2 ** attempt)
    raise RuntimeError(f'download failed: {asset}')


def find(z, suffix):
    for n in z.namelist():
        if n.endswith(suffix):
            return Image.open(io.BytesIO(z.read(n)))
    return None


def main():
    os.makedirs(OUT, exist_ok=True)
    src = os.path.join(OUT, 'SOURCES_AMBIENTCG.json')
    record = json.load(open(src)) if os.path.exists(src) else {}
    wanted = sys.argv[1:] or list(SETS)
    for key in wanted:
        asset, size, orm_size = SETS[key]
        data = download(asset)
        z = zipfile.ZipFile(io.BytesIO(data))
        color = find(z, '_Color.jpg').convert('RGB').resize((size, size), Image.LANCZOS)
        opacity = find(z, '_Opacity.jpg')
        files = {}
        if opacity is not None:
            rgba = color.copy(); rgba.putalpha(opacity.convert('L').resize((size, size), Image.LANCZOS))
            path = os.path.join(OUT, f'{key}_albedo.png'); rgba.save(path, optimize=True)
        else:
            path = os.path.join(OUT, f'{key}_albedo.jpg'); color.save(path, quality=90)
        files[os.path.basename(path)] = path
        normal = find(z, '_NormalGL.jpg').convert('RGB').resize((size, size), Image.LANCZOS)
        path = os.path.join(OUT, f'{key}_normal.jpg'); normal.save(path, quality=92); files[os.path.basename(path)] = path
        rough = find(z, '_Roughness.jpg')
        ao = find(z, '_AmbientOcclusion.jpg')
        metal = find(z, '_Metalness.jpg')
        def chan(img, default):
            if img is None:
                return np.full((orm_size, orm_size), default, np.uint8)
            return np.asarray(img.convert('L').resize((orm_size, orm_size), Image.LANCZOS))
        orm = np.dstack([chan(ao, 255), chan(rough, 200), chan(metal, 0)])
        path = os.path.join(OUT, f'{key}_orm.jpg'); Image.fromarray(orm).save(path, quality=92); files[os.path.basename(path)] = path
        record[key] = {
            'asset': asset, 'author': 'ambientCG / Lennart Demes', 'license': 'CC0-1.0',
            'source': f'https://ambientcg.com/view?id={asset}',
            'archive_sha256': hashlib.sha256(data).hexdigest(),
            'modifications': f'Resized to {size}px colour/normal and {orm_size}px ORM (AO, roughness, metalness packed).',
            'files': {k: hashlib.sha256(open(v, 'rb').read()).hexdigest() for k, v in files.items()},
        }
        print('ok', key, asset)
    with open(src, 'w') as f:
        json.dump(record, f, indent=1, sort_keys=True)


if __name__ == '__main__':
    main()
