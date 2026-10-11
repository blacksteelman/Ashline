"""Blender: turn downloaded CC0 Poly Haven sources into ASHLINE game-ready kit GLBs.

blender -b --python tools/build_kit.py [-- name ...]

Each kit prop is joined, recentred on its footprint (origin at floor centre),
decimated to a triangle budget, and exported to assets/kit/<name>.glb with its
PBR textures. assets/kit/kit.json records world-space AABBs (Godot Y-up) that
the map uses for collision and cover. The modular facade set is exported with
every module at its authored local origin to assets/kit/facade.glb.
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'thirdparty', 'polyhaven')
OUT = os.path.join(ROOT, 'assets', 'kit')

# name: (source asset, object selector, triangle budget, extra scale, texture max px)
# selector: None = all meshes, list = exact names, str 'has:x' = names containing x,
# 'not:x' = names not containing x.
KIT = {
    'worn_chair': ('painted_wooden_chair_02', None, 5000, 1, 1024),
    'worn_bookshelf': ('wooden_bookshelf_worn', None, 5000, 1, 1024),
    'cassette_player': ('portable_cassette_player', None, 4000, 1, 1024),
    'bench_vice': ('bench_vice_01', None, 4000, 1, 1024),
    'worn_sofa': ('sofa_02', None, 12000, 1, 1024),
    'coffee_table': ('modern_coffee_table_01', None, 5000, 1, 1024),
    'barrel_red': ('Barrel_01', None, 3000, 1, 1024),
    'barrel_blue': ('Barrel_02', None, 3000, 1, 1024),
    'barrel_steel': ('barrel_03', None, 3000, 1, 1024),
    'ammo_box': ('ammo_box', None, 2500, 1, 512),
    'cardboard_box': ('cardboard_box_01', None, 2500, 1, 1024),
    'cement_bag': ('cement_bag', None, 1000, 1, 512),
    'jersey_barrier': ('concrete_road_barrier', None, 5000, 1, 1024),
    'jersey_barrier_plain': ('concrete_road_barrier_02', None, 4000, 1, 1024),
    'covered_car': ('covered_car', None, 12000, 1, 1024),
    'aircon': ('exterior_aircon_unit', 'has:rusted', 4000, 1, 1024),
    'hydrant': ('fire_hydrant', 'has:aged', 4000, 1, 512),
    'hand_truck': ('hand_truck', None, 4000, 1, 512),
    'lamp_hanging': ('hanging_industrial_lamp', None, 3000, 1, 512),
    'lamp_wall': ('industrial_wall_lamp', None, 2000, 1, 512),
    'extinguisher': ('korean_fire_extinguisher_01', None, 2500, 1, 512),
    'jerrycan': ('metal_jerrycan_green', None, 3000, 1, 512),
    'desk': ('metal_office_desk', None, 6000, 1, 1024),
    'tool_chest': ('metal_tool_chest', None, 4000, 1, 512),
    'trash_can': ('metal_trash_can', 'has:rust', 4000, 1, 1024),
    'trash_can_clean': ('metal_trash_can', 'not:rust', 4000, 1, 1024),
    'duct_round': ('modular_airduct_circular_01', ['modular_airduct_circular_triple'], 2000, 1, 512),
    'duct_round_bend': ('modular_airduct_circular_01', ['modular_airduct_circular_bend_quater'], 1500, 1, 512),
    'duct_fan': ('modular_airduct_circular_01', ['modular_airduct_circular_fan'], 2000, 1, 512),
    'duct_square': ('modular_airduct_rectangular_01', ['modular_airduct_rectangular_01_tripple_01'], 3000, 1, 512),
    'duct_square_corner': ('modular_airduct_rectangular_01', ['modular_airduct_rectangular_01_corner_02'], 3000, 1, 512),
    'duct_vent': ('modular_airduct_rectangular_01', ['modular_airduct_rectangular_01_vent_01'], 1500, 1, 512),
    'fence_double': ('modular_chainlink_fence', ['modular_chainlink_fence_double'], 6000, 1, 512),
    'fence_single': ('modular_chainlink_fence', ['modular_chainlink_fence'], 4000, 1, 512),
    'fence_post': ('modular_chainlink_fence', ['modular_chainlink_fence_post'], 600, 1, 512),
    'fence_gate': ('modular_chainlink_fence', ['modular_chainlink_fence_door_frame', 'modular_chainlink_fence_door_gate', 'modular_chainlink_fence_door_latch'], 8000, 1, 512),
    'power_pole': ('modular_electricity_poles', 'has:preset_01_', 9000, 1, 512),
    'power_pole_b': ('modular_electricity_poles', 'has:preset_03_', 9000, 1, 512),
    'fire_escape': ('modular_fire_escape', None, 12000, 1, 1024),
    'pipe_straight': ('modular_industrial_pipes_01', ['modular_industrial_pipes_01_pipe02'], 1500, 1, 512),
    'pipe_valve': ('modular_industrial_pipes_01', ['modular_industrial_pipes_01_pipe03'], 2500, 1, 512),
    'pipe_bend': ('modular_industrial_pipes_01', ['modular_industrial_pipes_01_pipe07'], 1500, 1, 512),
    'gutter_pipe': ('modular_metal_gutter', ['modular_metal_gutter_section'], 600, 1, 512),
    'fluorescent': ('mounted_fluorescent_lights', ['mounted_fluorescent_lights_a'], 1500, 1, 512),
    'compressor': ('old_military_compressor', None, 9000, 1, 1024),
    'military_crate': ('old_military_crate', 'has:_a', 4000, 1, 1024),
    'military_crate_open': ('old_military_crate', 'has:_b', 4000, 1, 1024),
    'tyre': ('old_tyre', None, 2000, 1, 512),
    'crane': ('overhead_crane', None, 16000, 1, 1024),
    'plastic_crate': ('plastic_crate_03', None, 2500, 1, 512),
    'generator': ('portable_generator', None, 6000, 1, 1024),
    'welding_cart': ('portable_welding_cart', None, 6000, 1, 1024),
    'power_box': ('power_box_01', None, 4000, 1, 512),
    'propane': ('propane_tank', None, 2500, 1, 512),
    'wheel_rim': ('rusted_wheel_rim_01', None, 2500, 1, 512),
    'shutter_door': ('rollershutter_door', ['rollershutter_door'], 1200, 1, 1024),
    'shutter_door_graffiti': ('rollershutter_door', ['rollershutter_door_graffiti'], 1200, 1, 1024),
    'shutter_window': ('rollershutter_window_01', ['rollershutter_window_01'], 1200, 1, 1024),
    'shutter_window_graffiti': ('rollershutter_window_01', ['rollershutter_window_01_graffiti'], 1200, 1, 1024),
    'shutter_window_small': ('rollershutter_window_02', 'not:graffiti', 1200, 1, 1024),
    'security_light': ('security_light', None, 2500, 1, 512),
    'lpg_tank': ('small_lpg_tank', None, 3000, 1, 512),
    'shelves': ('steel_frame_shelves_01', None, 3000, 0.0843, 512),
    'tool_cart': ('tool_cart', None, 6000, 1, 1024),
    'trashbag': ('trashbag', None, 2000, 1, 512),
    'utility_box': ('utility_box_01', None, 3000, 1, 512),
    'utility_box_wide': ('utility_box_02', None, 3500, 1, 512),
    'manhole': ('water_manhole_cover', None, 2500, 1, 512),
    'crate_wood': ('wooden_crate_01', None, 3000, 1, 512),
    'crate_wood_long': ('wooden_crate_02', None, 3000, 1, 512),
    'crate_military': ('wooden_military_crate', None, 5000, 1, 1024),
    'metal_rack': ('worn_metal_rack', None, 3000, 1, 512),
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_asset(asset):
    path = os.path.join(SRC, asset, asset + '.gltf')
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def select(objs, selector):
    if selector is None:
        return objs
    if isinstance(selector, list):
        return [o for o in objs if o.name in selector]
    kind, _, text = selector.partition(':')
    if kind == 'has':
        return [o for o in objs if text in o.name]
    return [o for o in objs if text not in o.name]


def tris(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def limit_textures(max_px):
    for img in bpy.data.images:
        if img.size[0] > max_px:
            img.scale(max_px, max_px * img.size[1] // img.size[0])


def build_prop(name, spec, meta):
    asset, selector, budget, scale, tex = spec
    clear()
    objs = select(import_asset(asset), selector)
    if not objs:
        raise RuntimeError(f'{name}: selector matched nothing')
    for o in list(bpy.context.scene.objects):
        if o not in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    # Clear parenting so world transforms bake into the mesh.
    for o in objs:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.scale = obj.scale * scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Origin at the floor centre of the footprint.
    mn = Vector((min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    mx = Vector((max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    origin = obj.matrix_world @ Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    if name in ('lamp_hanging',):  # hangs from its top
        origin = obj.matrix_world @ Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mx.z))
    if name.startswith('duct') or name.startswith('pipe') or name in ('gutter_pipe', 'fluorescent', 'lamp_wall', 'crane'):
        origin = obj.matrix_world @ ((mn + mx) / 2)
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    obj.location = (0, 0, 0)
    if obj.data.shape_keys:
        obj.shape_key_clear()
    before = tris(obj)
    if before > budget:
        mod = obj.modifiers.new('decimate', 'DECIMATE')
        mod.ratio = budget / before
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    after = tris(obj)
    limit_textures(tex)
    bb = [Vector(c) for c in obj.bound_box]
    lo = Vector((min(v[i] for v in bb) for i in range(3)))
    hi = Vector((max(v[i] for v in bb) for i in range(3)))
    # Blender Z-up -> Godot Y-up: (x, y, z) -> (x, z, -y)
    meta[name] = {
        'source': asset, 'tris': after, 'source_tris': before,
        'aabb_min': [round(lo.x, 4), round(lo.z, 4), round(-hi.y, 4)],
        'aabb_max': [round(hi.x, 4), round(hi.z, 4), round(-lo.y, 4)],
    }
    path = os.path.join(OUT, name + '.glb')
    # Cut-out materials (chain-link) need PNG to keep their alpha channel.
    fmt = 'AUTO' if any(m and m.blend_method != 'OPAQUE' for m in obj.data.materials) or 'fence' in name else 'JPEG'
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False,
                              export_image_format=fmt, export_jpeg_quality=88,
                              export_apply=True, export_animations=False)
    print(f'kit {name}: {before} -> {after} tris')


def build_facade(meta):
    clear()
    objs = import_asset('modular_urban_apartments_facade')
    for o in objs:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
        o.location = (0, 0, 0)
    limit_textures(1024)
    for o in objs:
        n = tris(o)
        if n > 2000:
            mod = o.modifiers.new('decimate', 'DECIMATE'); mod.ratio = .45; mod.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    pieces = {}
    for o in objs:
        bb = [Vector(c) for c in o.bound_box]
        lo = Vector((min(v[i] for v in bb) for i in range(3)))
        hi = Vector((max(v[i] for v in bb) for i in range(3)))
        pieces[o.name] = {'aabb_min': [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
                          'aabb_max': [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)]}
    meta['facade'] = {'source': 'modular_urban_apartments_facade', 'pieces': pieces}
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'facade.glb'), export_format='GLB',
                              export_image_format='JPEG', export_jpeg_quality=88)
    print('kit facade:', len(objs), 'modules')


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    path = os.path.join(OUT, 'kit.json')
    meta = json.load(open(path)) if os.path.exists(path) else {}
    for name, spec in KIT.items():
        if args and name not in args:
            continue
        try:
            build_prop(name, spec, meta)
        except Exception as exc:
            print('KIT FAILED', name, exc)
    if not args or 'facade' in args:
        build_facade(meta)
    with open(path, 'w') as f:
        json.dump(meta, f, indent=1, sort_keys=True)


main()
