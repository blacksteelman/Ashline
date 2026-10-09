#!/usr/bin/env python3
"""Download CC-BY Sketchfab models used by ASHLINE (glTF archives) into assets/thirdparty/sketchfab/<key>/.

python3 tools/fetch_sketchfab.py [key ...]
Needs a Sketchfab API token: env SKETCHFAB_TOKEN or the file ~/.sketchfab_token (never commit it).
Sources are not stored in git; processed game assets are. Credits: LICENSES.md and SOURCES below.
"""
import json, os, sys, urllib.request, zipfile, io

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'assets', 'thirdparty', 'sketchfab')
SOURCES = {
    # First-person weapon sets (rig + animations by ccransh; arms "FP Arms" by DJMaesen / bumstrum).
    'fp_acr': ('5f2d0ed780a94724b36ab505f7564057', 'Animated FPS hands (rifle animation pack) - ccransh; Adaptive Combat Rifle by doomsentinel'),
    'fp_ak74m': ('94be8385c402474cacd39bc096c6ca14', 'FPS AK-74m animations - ccransh; AK-74m by creationwasteland'),
    'fp_smg': ('ca37ea9148dc4fcc9cc632175d311b23', 'SMG FPS Animations - ccransh; Masterpiece Arms 30 SST by eNse7en'),
    'fp_sniper': ('c15ae8393d824f5b929e3f69691cdd31', 'FPS animations sniper rifle - ccransh; sniper rifle by Oleg Anufriev (olgnchsart)'),
    'fp_pistol': ('0d7a343dcb6f401197a73c91aee93f6d', 'FPS pistol animations - ccransh; Springfield XD Mod.2 by raimeiyonke'),
    'fp_pm': ('d02ebd58e3cf44acb7af73e3f156be28', 'Makarov PM FPS animations - ccransh'),
    # Soldiers (jeandiz, assembled from CC-BY clothing by ErhanMatur, Bzovius, SrGeneroso, shedmon, Albin, Mayess).
    'swat_operator': ('9e82fabf26194896b5ad4a364d864eab', 'S.W.A.T. Operator - jeandiz'),
    'fsb_operator': ('43a561e941704eefb1ab0614be4f0049', 'FSB Operator - jeandiz'),
}


def token():
    t = os.environ.get('SKETCHFAB_TOKEN', '').strip()
    path = os.path.expanduser('~/.sketchfab_token')
    if not t and os.path.exists(path):
        t = open(path).read().strip()
    if not t:
        sys.exit('No Sketchfab token (SKETCHFAB_TOKEN or ~/.sketchfab_token)')
    return t


def api(path, t):
    req = urllib.request.Request('https://api.sketchfab.com/v3/' + path, headers={'Authorization': 'Token ' + t})
    return json.load(urllib.request.urlopen(req, timeout=60))


def fetch(key, t):
    uid, credit = SOURCES[key]
    out = os.path.join(DEST, key)
    if os.path.exists(os.path.join(out, 'scene.gltf')):
        print('have', key); return
    info = api(f'models/{uid}', t)
    lic = info['license']['label']
    if 'NonCommercial' in lic or 'NoDerivs' in lic:
        sys.exit(f'{key}: license {lic} not allowed')
    links = api(f'models/{uid}/download', t)
    url = links['gltf']['url']
    data = urllib.request.urlopen(url, timeout=600).read()
    os.makedirs(out, exist_ok=True)
    zipfile.ZipFile(io.BytesIO(data)).extractall(out)
    json.dump({'uid': uid, 'name': info['name'], 'author': info['user']['username'], 'license': lic,
               'url': info['viewerUrl'], 'credit': credit}, open(os.path.join(out, 'source.json'), 'w'), indent=1)
    print('fetched', key, len(data) // 1024, 'KB', lic)


if __name__ == '__main__':
    t = token()
    for key in (sys.argv[1:] or SOURCES):
        fetch(key, t)
