#!/usr/bin/env python3
"""Cap imported world textures at 1024 px (map kit, surfaces, soldiers): seen from metres away, half the size
on disk and in VRAM is invisible. First-person sets (assets/viewmodels) and the sky keep their resolution.

python3 tools/cap_textures.py && godot --headless --editor --path . --import
Many of these .import files are generated on import (textures extracted from GLBs), so run it after a first
import, then import again (the build workflow does this).
"""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEEP = ('assets/thirdparty', 'assets/viewmodels', 'assets/sky')
LIMIT = 1024


def main():
    changed = 0
    for root, dirs, files in os.walk(os.path.join(ROOT, 'assets')):
        rel = os.path.relpath(root, ROOT)
        if rel.startswith(KEEP):
            continue
        for f in files:
            if not f.endswith('.import'):
                continue
            p = os.path.join(root, f)
            text = open(p).read()
            if 'importer="texture"' not in text or f'process/size_limit={LIMIT}' in text:
                continue
            text = re.sub(r'process/size_limit=\d+', f'process/size_limit={LIMIT}', text)
            open(p, 'w').write(text)
            # Drop the import hash so the next --import redoes this texture.
            for dest in re.findall(r'path(?:\.\w+)?="res://(\.godot/imported/[^"]+)\.ctex"', text):
                md5 = os.path.join(ROOT, dest + '.md5')
                if os.path.exists(md5):
                    os.remove(md5)
            changed += 1
    print('capped', changed, 'textures at', LIMIT)


if __name__ == '__main__':
    main()
