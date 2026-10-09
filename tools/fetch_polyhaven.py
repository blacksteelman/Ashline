#!/usr/bin/env python3
"""Download CC0 Poly Haven models / HDRIs into assets/thirdparty/polyhaven and record provenance.

Usage: python3 tools/fetch_polyhaven.py [asset_id[:res] ...]
Without arguments the curated ASHLINE list is fetched. Re-running skips files
whose md5 already matches. Provenance goes to assets/thirdparty/polyhaven/SOURCES_POLYHAVEN.json.
"""
import hashlib, json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'thirdparty', 'polyhaven')
API = 'https://api.polyhaven.com'

# id: texture resolution. Large hero structures get 2k, small clutter 1k.
CURATED = {
    'concrete_road_barrier': '2k', 'concrete_road_barrier_02': '2k',
    'modular_chainlink_fence': '1k', 'modular_electricity_poles': '1k',
    'modular_fire_escape': '2k', 'modular_metal_gutter': '1k',
    'modular_airduct_rectangular_01': '1k', 'modular_airduct_circular_01': '1k',
    'modular_industrial_pipes_01': '1k', 'modular_electric_cables': '1k',
    'modular_urban_apartments_facade': '2k', 'rollershutter_door': '2k',
    'rollershutter_window_01': '1k', 'rollershutter_window_02': '1k',
    'utility_box_01': '1k', 'utility_box_02': '1k', 'exterior_aircon_unit': '1k',
    'fire_hydrant': '1k', 'water_manhole_cover': '1k', 'metal_trash_can': '1k',
    'old_tyre': '1k', 'covered_car': '2k', 'security_light': '1k',
    'hanging_industrial_lamp': '1k', 'industrial_wall_lamp': '1k',
    'mounted_fluorescent_lights': '1k', 'Barrel_01': '1k', 'Barrel_02': '1k',
    'barrel_03': '1k', 'cardboard_box_01': '1k', 'wooden_crate_01': '1k',
    'wooden_crate_02': '1k', 'old_military_crate': '1k', 'wooden_military_crate': '1k',
    'ammo_box': '1k', 'metal_jerrycan_green': '1k', 'propane_tank': '1k',
    'portable_generator': '1k', 'hand_truck': '1k', 'tool_cart': '1k',
    'steel_frame_shelves_01': '1k', 'worn_metal_rack': '1k', 'metal_office_desk': '1k',
    'metal_tool_chest': '1k', 'old_military_compressor': '1k',
    'portable_welding_cart': '1k', 'plastic_crate_03': '1k', 'trashbag': '1k',
    'cement_bag': '1k', 'power_box_01': '1k', 'korean_fire_extinguisher_01': '1k',
    'rusted_wheel_rim_01': '1k', 'small_lpg_tank': '1k', 'overhead_crane': '1k',
}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'ASHLINE-asset-fetch'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()


def fetch_model(asset, res, record):
    info = json.loads(get(f'{API}/info/{asset}'))
    files = json.loads(get(f'{API}/files/{asset}'))
    entry = files['gltf'][res]['gltf']
    folder = os.path.join(OUT, asset)
    os.makedirs(folder, exist_ok=True)
    targets = {os.path.basename(entry['url']).replace(f'_{res}.gltf', '.gltf'): entry}
    for rel, inc in entry['include'].items():
        targets[rel] = inc
    hashes = {}
    for rel, item in targets.items():
        dest = os.path.join(folder, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if not (os.path.exists(dest) and md5(dest) == item['md5']):
            data = get(item['url'])
            if rel.endswith('.gltf'):
                # Point the glTF at the stable local file names.
                text = data.decode('utf-8')
                data = text.encode('utf-8')
            with open(dest, 'wb') as f:
                f.write(data)
        hashes[rel] = hashlib.sha256(open(dest, 'rb').read()).hexdigest()
    record[asset] = {
        'name': info.get('name', asset),
        'authors': info.get('authors', {}),
        'source': f'https://polyhaven.com/a/{asset}',
        'license': 'CC0-1.0',
        'resolution': res,
        'files': hashes,
    }
    print('ok', asset, res, sum(os.path.getsize(os.path.join(folder, r)) for r in hashes) // 1024, 'KiB')


def main():
    os.makedirs(OUT, exist_ok=True)
    src = os.path.join(OUT, 'SOURCES_POLYHAVEN.json')
    record = json.load(open(src)) if os.path.exists(src) else {}
    wanted = {}
    for arg in sys.argv[1:]:
        name, _, res = arg.partition(':')
        wanted[name] = res or '1k'
    for asset, res in (wanted or CURATED).items():
        try:
            fetch_model(asset, res, record)
        except Exception as exc:  # keep going; report at the end
            print('FAILED', asset, exc)
    with open(src, 'w') as f:
        json.dump(record, f, indent=1, sort_keys=True)


if __name__ == '__main__':
    main()
