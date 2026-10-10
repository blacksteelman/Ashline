#!/usr/bin/env python3
"""Shrink the exported game: exclude images and models the game never opens.

S=$(mktemp -d)
strace -f -e trace=openat -o $S/a.log godot --headless --path . --script tests/touch_assets.gd
strace -f -e trace=openat -o $S/b.log godot --headless --path . -- --bot-test --seed=801 --matches=1
python3 tools/export_filter.py $S/a.log $S/b.log     # rewrites exclude_filter in export_presets.cfg

Only images (.png/.jpg/.hdr/.exr) and models (.glb/.gltf) are candidates; audio, fonts, shaders, scripts and
data always ship. A source counts as used when any of its imported files (or the file itself) was opened.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANDIDATES = ('.png', '.jpg', '.jpeg', '.hdr', '.exr', '.glb', '.gltf')
BASE_EXCLUDE = ['tests/*', 'build/*', 'tools/*', 'assets/*.py', 'assets/thirdparty/*', '.runtime/*', '.git/*', '.github/*']


def opened(logs):
    seen = set()
    for log in logs:
        for path in re.findall(r'openat\([^"]*"([^"]+)"', open(log, errors='replace').read()):
            if path.startswith(ROOT + '/'):
                seen.add(os.path.relpath(path, ROOT))
    return seen


def main():
    seen = opened(sys.argv[1:])
    unused = []
    for root, dirs, files in os.walk(os.path.join(ROOT, 'assets')):
        rel_root = os.path.relpath(root, ROOT)
        if rel_root.startswith('assets/thirdparty'):
            continue
        for f in files:
            if not f.lower().endswith(CANDIDATES):
                continue
            rel = os.path.join(rel_root, f)
            used = rel in seen
            imp = os.path.join(ROOT, rel + '.import')
            if not used and os.path.exists(imp):
                dests = re.findall(r'"res://(\.godot/imported/[^"]+)"', open(imp).read())
                used = any(d in seen for d in dests)
            if not used:
                unused.append(rel)
    unused.sort()
    patterns = BASE_EXCLUDE + unused
    cfg_path = os.path.join(ROOT, 'export_presets.cfg')
    cfg = open(cfg_path).read()
    cfg = re.sub(r'exclude_filter="[^"]*"', 'exclude_filter="' + ','.join(patterns) + '"', cfg)
    open(cfg_path, 'w').write(cfg)
    size = sum(os.path.getsize(os.path.join(ROOT, u)) for u in unused)
    print(f'excluded {len(unused)} unused images/models ({size / 1e6:.0f} MB of sources)')


if __name__ == '__main__':
    main()
