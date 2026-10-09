"""Blender + MPFB2: build ASHLINE soldier characters with baked third-person animation.

blender -b --python tools/build_soldiers.py -- [aegis] [ember] [--preview] [--analyze] [--no-export]

Body: MakeHuman base mesh via MPFB2 (CC0), cmu_mb rig (same joint layout as CMU mocap BVH).
Clothing (MakeHuman community asset packs):
  shirt  elvs_male_shirt_untucked_bd1 (CC-BY Elvaerwyn)  -> camo combat shirt
  pants  cortu_cargo_pants (CC0 Cortu)                     -> camo trousers
  vest   mindfront_tactical_vest_male (CC-BY Mindfront)    -> plate carrier
  helmet mindfront_helmet_kz45 (CC-BY 4.0 Mindfront)  (Aegis)
  mask   gredal_gas_mask (CC0), hooded, replaces the helmet  (Ember)
  boots  toigo_ankle_boots_male (CC0 MargaretToigo), gloves toigo_gloves_short (CC0)
Motion: CMU Graphics Lab Motion Capture Database (BVH conversion by B. Hahne, free to use),
  retargeted onto the rig; the upper body is replaced by a shouldered-rifle stance and arm IK.
  Idle, crouch, jump, reload and death are authored procedurally here.
Camouflage textures come from tools/camo.py. Output: assets/characters/soldier_<team>.glb
The world weapon (assets/viewmodels/world_*.glb) is attached at runtime to the WeaponSocket node.
Install MPFB2 into ~/.config/blender/4.3/extensions/user_default/mpfb, copy the asset packs into
its user data folder and fetch the BVH clips into $ASHLINE_BVH (see DEVELOPMENT_PROGRESS.md).
"""
import bpy, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, 'assets', 'textures')
OUT = os.path.join(ROOT, 'assets', 'characters')
BVH = os.environ.get('ASHLINE_BVH', '/tmp/claude-0/bvh')
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
FPS = 30
CMU_BASE = 'https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/'

bpy.ops.preferences.addon_enable(module='bl_ext.user_default.mpfb')
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.locationservice import LocationService

DATA = LocationService.get_user_data()

TEAMS = {
    'aegis': {'camo': 'ocp', 'camo_gain': 0.95, 'vest_tint': (0.50, 0.43, 0.31), 'helmet': 'mindfront_helmet_kz45',
              'helmet_tint': (0.40, 0.36, 0.27), 'mask': None, 'skin': 'young_caucasian_male',
              'macro': {'gender': 1.0, 'age': 0.45, 'muscle': 0.7, 'weight': 0.55, 'height': 0.6, 'proportions': 0.6}},
    'ember': {'camo': 'emr', 'camo_gain': 0.9, 'vest_tint': (0.30, 0.34, 0.25), 'helmet': None,
              'helmet_tint': (0.28, 0.32, 0.24), 'mask': 'gredal_gas_mask', 'skin': 'young_caucasian_male',
              'macro': {'gender': 1.0, 'age': 0.5, 'muscle': 0.65, 'weight': 0.6, 'height': 0.55, 'proportions': 0.55}},
}
# Godot-side contract (scripts/character_motion.gd, character_aim.gd).
RENAME = {'Spine1': 'Chest', 'LeftArm': 'UpperArm.L', 'LeftForeArm': 'Forearm.L', 'LeftHand': 'Hand.L',
          'RightArm': 'UpperArm.R', 'RightForeArm': 'Forearm.R', 'RightHand': 'Hand.R'}
def T(name):
    return RENAME.get(name, name)

# Character faces -Y in Blender (+Z in glTF/Godot; the game turns the model around).
FWD = Vector((0, -1, 0)); RIGHT = Vector((-1, 0, 0)); UP = Vector((0, 0, 1))
LEGS = ['LHipJoint', 'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'LeftToeBase', 'RHipJoint', 'RightUpLeg', 'RightLeg', 'RightFoot', 'RightToeBase']
SPINE = ['LowerBack', 'Spine', 'Spine1', 'Neck', 'Neck1', 'Head']
MAPPED = ['Hips'] + LEGS + SPINE + ['LeftShoulder', 'RightShoulder']
MIRROR = {'Left': 'Right', 'Right': 'Left', 'LHip': 'RHip', 'RHip': 'LHip'}

# Weapon space: +Y muzzle, +Z up, origin at the top of the pistol grip (as tools/build_viewmodels.py).
# (wrist position, finger direction, palm normal) for the M4A1 world model.
GRIP = (Vector((0.014, -0.045, -0.075)), Vector((-0.15, 0.7, -0.7)), Vector((-1, 0, 0)))
SUPPORT = (Vector((0.0, 0.20, -0.045)), Vector((0.72, 0.66, 0.1)), Vector((0, 0, 1)))
MAGWELL = (Vector((-0.01, 0.045, -0.13)), Vector((0.55, 0.3, 0.75)), Vector((0.9, 0.0, -0.4)))

# Clips: role -> source and treatment. 'speed' is the game speed the clip plays at with
# TimeScale 1 (character_motion.gd); 'period' overrides the loop period in seconds.
CLIPS = {
    'Forward': {'bvh': '09_06', 'speed': 5.1},
    'Backward': {'bvh': '143_39', 'period': 0.62},
    'Left': {'bvh': '09_06', 'speed': 5.1, 'yaw': 62},
    'Right': {'bvh': '09_06', 'speed': 5.1, 'yaw': -62},
    'Sprint': {'bvh': '16_46', 'speed': 7.8, 'sprint': True},
    'CrouchWalk': {'bvh': '143_32', 'speed': 2.5, 'crouch': 0.42},
}
# Playing a clip faster than it was captured: cadence rises with this power of the speed ratio,
# the rest is stride (a little foot slide reads better than a frantic cadence).
CADENCE = 0.6


def fetch_bvh(name):
    path = os.path.join(BVH, name + '.bvh')
    if not os.path.exists(path):
        os.makedirs(BVH, exist_ok=True)
        subject = name.split('_')[0].zfill(3)
        os.system(f'curl -sS --retry 3 -o "{path}" {CMU_BASE}{subject}/{name}.bvh')
    return path


def clothes_file(name):
    return os.path.join(DATA, 'clothes', name, name + '.mhclo')


def shrink_image(img, limit=1024):
    if img and img.size[0] > limit:
        img.scale(limit, int(img.size[1] * limit / img.size[0]))


def retexture(obj, albedo_path=None, tint=None, roughness=None, tiles=1.0, gain=1.0):
    """Swap the albedo image of every material on obj (tiled camo) or recolour it with a tint."""
    for slot in obj.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        m = m.copy(); slot.material = m
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        for n in nt.nodes:
            if n.type == 'TEX_IMAGE':
                shrink_image(n.image)
        if albedo_path:
            img = bpy.data.images.load(albedo_path, check_existing=True)
            if gain != 1.0:
                img = img.copy(); img.name = os.path.basename(albedo_path).replace('.jpg', '_%s' % obj.name.split('.')[-1])
                px = np.empty(img.size[0] * img.size[1] * 4, np.float32); img.pixels.foreach_get(px)
                px = px.reshape(-1, 4)
                lum = px[:, :3] @ np.array([0.3, 0.59, 0.11], np.float32)
                px[:, :3] = np.clip((lum[:, None] + (px[:, :3] - lum[:, None]) * 1.18) * gain, 0, 1)
                img.pixels.foreach_set(px.ravel()); img.pack()
            tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
            mapping = nt.nodes.new('ShaderNodeMapping'); mapping.inputs['Scale'].default_value = (tiles, tiles, 1)
            coord = nt.nodes.new('ShaderNodeTexCoord')
            nt.links.new(coord.outputs['UV'], mapping.inputs['Vector']); nt.links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
            for link in list(bsdf.inputs['Base Color'].links):
                nt.links.remove(link)
            nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        elif tint is not None:
            # MakeHuman routes the albedo through a MixRGB 'diffuseIntensity' node: use the image directly.
            src = nt.nodes.get('diffuseTexture')
            if src is None and bsdf.inputs['Base Color'].links:
                src = bsdf.inputs['Base Color'].links[0].from_node
            if src is not None and src.type == 'TEX_IMAGE' and src.image is not None:
                img = src.image.copy(); img.name = obj.name + '_tinted'
                px = np.empty(img.size[0] * img.size[1] * 4, np.float32); img.pixels.foreach_get(px)
                px = px.reshape(-1, 4)
                lum = px[:, :3] @ np.array([0.3, 0.59, 0.11], np.float32)
                lum = lum / max(1e-3, float(np.median(lum)))  # keep detail, normalise brightness
                px[:, :3] = np.clip(lum[:, None] * np.array(tint, np.float32)[None, :], 0, 1)
                img.pixels.foreach_set(px.ravel()); img.pack(); src.image = img
                for link in list(bsdf.inputs['Base Color'].links):
                    nt.links.remove(link)
                nt.links.new(src.outputs['Color'], bsdf.inputs['Base Color'])
            else:
                for link in list(bsdf.inputs['Base Color'].links):
                    nt.links.remove(link)
                bsdf.inputs['Base Color'].default_value = (*tint, 1)
        if roughness is not None:
            for link in list(bsdf.inputs['Roughness'].links):
                nt.links.remove(link)
            bsdf.inputs['Roughness'].default_value = roughness


def bake_shape_keys(obj):
    if obj.type == 'MESH' and obj.data.shape_keys:
        bpy.context.view_layer.objects.active = obj
        obj.shape_key_add(name='mix', from_mix=True)
        for k in list(obj.data.shape_keys.key_blocks):
            if k.name != 'mix':
                obj.shape_key_remove(k)
        obj.shape_key_remove(obj.data.shape_keys.key_blocks['mix'])


def decimate_first(obj, ratio):
    mod = obj.modifiers.new('Decimate', 'DECIMATE'); mod.ratio = ratio; mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)


def build_body(team, spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.preferences.addon_enable(module='bl_ext.user_default.mpfb')
    macro = dict(spec['macro']); macro['cupsize'] = 0.5; macro['firmness'] = 0.5
    macro['race'] = {'asian': 0.0, 'caucasian': 1.0, 'african': 0.0}
    body = HumanService.create_human(mask_helpers=True, detailed_helpers=False, extra_vertex_groups=True,
                                     feet_on_ground=False, scale=0.1, macro_detail_dict=macro)
    rig = HumanService.add_builtin_rig(body, 'cmu_mb', import_weights=True)
    skin = os.path.join(DATA, 'skins', spec['skin'], spec['skin'] + '.mhmat')
    if os.path.exists(skin):
        HumanService.set_character_skin(skin, body, skin_type='GAMEENGINE')
    items = [('elvs_male_shirt_untucked_bd1', ('camo', 3.4)), ('cortu_cargo_pants', ('camo', 3.0)),
             ('mindfront_tactical_vest_male', ('tint', spec['vest_tint'], 0.35)),
             ('toigo_ankle_boots_male', ('tint', (0.075, 0.072, 0.065), None)), ('toigo_gloves_short', ('tint', (0.085, 0.085, 0.08), None))]
    if spec['helmet']:
        items.append((spec['helmet'], ('tint', spec['helmet_tint'], 0.45)))
    if spec['mask']:
        # The hood of the gas mask covers the head; dark olive rubber.
        items.append((spec['mask'], ('tint', (0.16, 0.18, 0.14), 0.5)))
    for name, look in items:
        path = clothes_file(name)
        if not os.path.exists(path):
            print('MISSING CLOTHES', name); continue
        obj = HumanService.add_mhclo_asset(path, body, asset_type='Clothes', subdiv_levels=0, material_type='MAKESKIN')
        if obj is None:
            continue
        if look[0] == 'camo':
            retexture(obj, os.path.join(TEX, 'camo_%s_albedo.jpg' % spec['camo']), roughness=0.92, tiles=look[1], gain=spec['camo_gain'])
        elif look[0] == 'tint':
            retexture(obj, tint=look[1], roughness=0.72)
        else:
            retexture(obj)
        if look[-1]:
            decimate_first(obj, look[-1])
        print('CLOTHES', name, len(obj.data.vertices))
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            bake_shape_keys(o)
    for img in bpy.data.images:
        shrink_image(img)
    # MPFB's feet_on_ground offsets the mesh but not a rig added afterwards: lift the rig instead
    # so mesh and bones share one space (boot soles on z=0).
    soles = [o for o in bpy.data.objects if o.type == 'MESH' and 'boots' in o.name] or [body]
    rig.location.z = -min(v.co.z for o in soles for v in o.data.vertices)
    bpy.context.view_layer.update()
    # Godot contract names.
    for b in rig.data.bones:
        if b.name in RENAME:
            b.name = RENAME[b.name]
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for g in o.vertex_groups:
                if g.name in RENAME:
                    g.name = RENAME[g.name]
    return body, rig


# ------------------------------------------------------------------ rig helpers

def arm_rest(rig, name):
    return rig.matrix_world @ rig.data.bones[T(name)].matrix_local


def rest_quat(rig, name):
    return arm_rest(rig, name).to_quaternion()


def set_pose(rig, deltas, hips_pos):
    """Pose from world-space rotation deltas (relative to rest) and the hips head position."""
    world = {}
    rw = rig.matrix_world.to_quaternion()
    for pb in rig.pose.bones:
        b = pb.bone
        src = next((k for k in deltas if T(k) == b.name), None)
        q_rest = rw @ b.matrix_local.to_quaternion()
        if src is not None:
            q = deltas[src] @ q_rest
        elif b.parent is not None:
            # Unmapped bones keep their rest orientation relative to the parent.
            qp_rest = rw @ b.parent.matrix_local.to_quaternion()
            q = world[b.parent.name] @ qp_rest.inverted() @ q_rest
        else:
            q = q_rest
        world[b.name] = q
        if b.parent is not None:
            qp_rest = rw @ b.parent.matrix_local.to_quaternion()
            local = (qp_rest.inverted() @ q_rest).inverted() @ (world[b.parent.name].inverted() @ q)
        else:
            local = q_rest.inverted() @ q
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = local
        if b.parent is None:
            head = rig.matrix_world @ b.head_local
            pb.location = q_rest.to_matrix().inverted() @ (hips_pos - head)
    return world


def key_pose(rig, frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('location', frame=frame)


def empty(name, size=0.04):
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e); e.empty_display_size = size
    return e


def parent_to_bone(obj, rig, bone, world):
    obj.parent = rig; obj.parent_type = 'BONE'; obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = world


# ------------------------------------------------------------------ mocap

def load_bvh(rig, name):
    """Import a CMU BVH; return per-frame world deltas, hips positions and ankle heights."""
    before = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=fetch_bvh(name), global_scale=0.056444, rotate_mode='NATIVE',
                            axis_forward='-Z', axis_up='Y', update_scene_fps=False, update_scene_duration=True)
    src = (set(bpy.data.objects) - before).pop()
    act = src.animation_data.action
    f0, f1 = (int(v) for v in act.frame_range)
    rest = {b.name: (src.matrix_world @ b.matrix_local).to_quaternion() for b in src.data.bones}
    frames = []
    scn = bpy.context.scene
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        d = {}
        for n in MAPPED:
            pb = src.pose.bones[n]
            d[n] = (src.matrix_world @ pb.matrix).to_quaternion() @ rest[n].inverted()
        hips = (src.matrix_world @ src.pose.bones['Hips'].matrix).translation.copy()
        ank = min((src.matrix_world @ src.pose.bones[s].head).z for s in ('LeftFoot', 'RightFoot'))
        frames.append((d, hips, ank))
    lo = lambda a, b: (src.matrix_world @ src.data.bones[a].head_local - src.matrix_world @ src.data.bones[b].head_local).length
    src_leg = lo('LeftUpLeg', 'LeftLeg') + lo('LeftLeg', 'LeftFoot')
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.actions.remove(act)
    tl = lambda a, b: (arm_rest(rig, a).translation - arm_rest(rig, b).translation).length
    tgt_leg = tl('LeftUpLeg', 'LeftLeg') + tl('LeftLeg', 'LeftFoot')
    # Subject 143 was captured at 60 fps although its BVH header says 120.
    return frames, tgt_leg / src_leg, 60.0 if name.startswith('143_') else 120.0


def qdist(a, b):
    return 1.0 - abs(a.dot(b))


def find_cycle(frames, fps, pmin=0.5, pmax=1.5):
    n = len(frames); best = (1e9, 0, 0)
    keys = ['LeftUpLeg', 'LeftLeg', 'RightUpLeg', 'RightLeg', 'Hips']
    rel = []
    for d, _, _ in frames:
        h = d['Hips']
        rel.append([h.inverted() @ d[k] if k != 'Hips' else Quaternion() for k in keys] + [d['Hips']])
    def flat(v):
        return Vector((v.x, v.y, 0))
    win = int(0.5 * fps)
    pace = [flat(frames[min(n - 1, i + win)][1] - frames[i][1]).length for i in range(n)]
    fast = max(pace) * 0.75
    for i in range(int(n * 0.1), int(n * 0.8), 2):
        for p in range(int(pmin * fps), int(pmax * fps)):
            j = i + p
            if j + 2 >= n:
                break
            if min(pace[i], pace[min(n - 1, j - win)]) < fast:
                continue
            # Travel must follow the hips heading (no turning segments).
            fwd = frames[i][0]['Hips'] @ FWD
            fwd2 = frames[j][0]['Hips'] @ FWD
            if flat(fwd).normalized().dot(flat(fwd2).normalized()) < 0.97:
                continue
            e = sum(qdist(rel[i][k], rel[j][k]) + qdist(rel[i + 2][k], rel[j + 2][k]) for k in range(len(keys) - 1))
            if e < best[0]:
                best = (e, i, p)
    return best


def mirror_q(q):
    m = q.to_matrix(); s = Matrix.Diagonal((-1, 1, 1))
    return (s @ m @ s).to_quaternion()


def mirror_name(n):
    for a, b in MIRROR.items():
        if n.startswith(a):
            return b + n[len(a):]
    return n


def mocap_cycle(rig, role, clip):
    frames, scale, fps = load_bvh(rig, clip['bvh'])
    err, i0, p = find_cycle(frames, fps, *clip.get('cycle', (0.5, 1.5)))
    dt = p / fps
    # Facing over the cycle (hips forward axis) -> align to FWD.
    fwd = Vector()
    for k in range(p):
        fwd += frames[i0 + k][0]['Hips'] @ FWD
    fwd.z = 0; fwd.normalize()
    yaw = math.atan2(fwd.x, -fwd.y)  # angle from FWD
    align = Quaternion(UP, -yaw)
    travel = (frames[i0 + p][1] - frames[i0][1]); travel.z = 0
    travel = align @ travel
    speed = travel.length * scale / dt
    print('CLIP', role, clip['bvh'], 'cycle', i0, p, 'err %.3f' % err, 'period %.3f' % dt, 'speed %.2f' % speed,
          'travel', tuple(round(v, 2) for v in (travel.normalized())))
    if clip.get('yaw'):
        align = Quaternion(UP, math.radians(clip['yaw'])) @ align
    # Output period at the game's reference speed (stride length preserved).
    period = clip.get('period') or dt * (speed / clip['speed']) ** CADENCE
    n = max(8, int(round(period * FPS)))
    hips_rest = arm_rest(rig, 'Hips').translation
    ank_rest = min(arm_rest(rig, s).translation.z for s in ('LeftFoot', 'RightFoot'))
    ank_floor = min(f[2] for f in frames[i0:i0 + p + 1])
    # Seam: residual rotation per bone distributed over the cycle.
    first, last = frames[i0][0], frames[i0 + p][0]
    out = []
    for k in range(n + 1):
        x = k / n * p
        a = int(math.floor(x)); w = x - a
        fa, fb = frames[i0 + a], frames[i0 + min(p, a + 1)]
        d = {}
        for name in MAPPED:
            q = fa[0][name].slerp(fb[0][name], w)
            res = last[name] @ first[name].inverted()  # last = res @ first
            q = Quaternion().slerp(res.inverted(), x / p) @ q
            d[name] = align @ q
        hips = fa[1].lerp(fb[1], w)
        start, end = frames[i0][1], frames[i0 + p][1]
        hips = hips - start - (end - start) * (x / p)
        hips = align @ hips
        z = (fa[1].z * (1 - w) + fb[1].z * w - ank_floor) * scale
        pos = Vector((hips_rest.x + hips.x * scale * 0.6, hips_rest.y + hips.y * scale * 0.6, ank_rest + z))
        out.append((d, pos))
    if clip.get('mirror'):
        out = [({mirror_name(k): mirror_q(v) for k, v in d.items()}, Vector((2 * hips_rest.x - pos.x, pos.y, pos.z))) for d, pos in out]
    return out


# ------------------------------------------------------------------ stance and weapon

def rot(axis, deg):
    return Quaternion(axis, math.radians(deg))


def stance_deltas(lean=10.0, blade=22.0, head_pitch=4.0):
    """World deltas for the shouldered-rifle upper body: torso bladed (left shoulder forward), slight lean."""
    d = {}
    for name, share in (('LowerBack', 0.3), ('Spine', 0.65), ('Spine1', 1.0)):
        d[name] = rot(UP, -blade * share) @ rot(RIGHT, -lean * share)
    d['Neck'] = rot(UP, -blade * 0.6) @ rot(RIGHT, -lean * 0.5)
    d['Neck1'] = rot(UP, -blade * 0.3) @ rot(RIGHT, -lean * 0.2)
    d['Head'] = rot(UP, -6) @ rot(RIGHT, -head_pitch) @ rot(FWD, 6)
    d['LeftShoulder'] = d['Spine1'] @ rot(UP, -16)
    d['RightShoulder'] = d['Spine1'] @ rot(UP, 4)
    return d


def neutral_deltas():
    return {n: Quaternion() for n in MAPPED}


def blend_upper(d, stance, k=1.0):
    weights = {'LowerBack': 0.55, 'Spine': 0.8, 'Spine1': 0.95, 'Neck': 0.95, 'Neck1': 0.97, 'Head': 0.98,
               'LeftShoulder': 1.0, 'RightShoulder': 1.0}
    out = dict(d)
    for n, w in weights.items():
        out[n] = d.get(n, Quaternion()).slerp(stance[n], min(1.0, w * k))
    return out


def weapon_matrix(rig, sprint=False):
    """Armature-space weapon frame for the stance pose (computed after the stance is applied)."""
    pocket = arm_rest(rig, 'RightArm').translation.copy()
    chest = rig.pose.bones[T('Spine1')]
    cm = rig.matrix_world @ chest.matrix
    # Shoulder pocket: inboard of the right shoulder joint and slightly forward.
    sh = rig.matrix_world @ rig.pose.bones[T('RightArm')].matrix
    pocket = sh.translation + RIGHT * -0.06 + FWD * 0.05 + UP * 0.02
    face = Quaternion(UP, math.pi)  # weapon +Y -> FWD
    if not sprint:
        r = face @ rot(Vector((1, 0, 0)), 1.5)
        butt = Vector((0, -0.27, -0.025))
        return Matrix.Translation(pocket - (r @ butt)) @ r.to_matrix().to_4x4()
    # Sprint: rifle canted across the chest, muzzle up and to the left.
    r = rot(UP, -28) @ rot(RIGHT, -32) @ face @ rot(Vector((0, 1, 0)), -55)
    origin = cm.translation + RIGHT * 0.05 + FWD * 0.28 + UP * -0.22
    return Matrix.Translation(origin) @ r.to_matrix().to_4x4()


def hand_basis(rig, side):
    """(finger, thumb-side, palm-normal) of the hand in bone-local coordinates, plus the palm sign."""
    s = 'Left' if side == 'L' else 'Right'
    hb = rig.data.bones[T(s + 'Hand')]
    head = hb.head_local
    f = (rig.data.bones[s + 'FingerBase'].tail_local - head).normalized()
    th = rig.data.bones[('LThumb' if side == 'L' else 'RThumb')].head_local - head
    t = (th - f * th.dot(f)).normalized()
    n = f.cross(t)
    medial = Vector((-1 if side == 'L' else 1, 0, 0))
    sign = 1.0 if n.dot(medial) > 0 else -1.0
    n = n * sign
    inv = hb.matrix_local.to_3x3().inverted()
    return inv @ f, inv @ t, inv @ n, sign


def hand_target(rig, side, wm, contact):
    wrist, fdir, pnorm = contact
    f_l, t_l, n_l, sign = hand_basis(rig, side)
    r3 = wm.to_3x3().normalized()
    f = (r3 @ fdir).normalized(); n = r3 @ pnorm; n = (n - f * n.dot(f)).normalized()
    t = n.cross(f) * sign
    A = Matrix((f, t, n)).transposed(); L = Matrix((f_l, t_l, n_l)).transposed()
    R = A @ L.inverted()
    return Matrix.Translation(wm @ wrist) @ R.to_4x4()


def curl_fingers(rig, side, base, tip, thumb):
    s = 'Left' if side == 'L' else 'Right'
    f_l, t_l, n_l, _ = hand_basis(rig, side)
    hb = rig.data.bones[T(s + 'Hand')].matrix_local.to_3x3()
    axis = hb @ n_l.cross(f_l)  # curls the fingers toward the palm
    for name, deg in ((s + 'FingerBase', base), (s + 'HandFinger1', tip), (('LThumb' if side == 'L' else 'RThumb'), thumb)):
        b = rig.data.bones.get(name)
        if not b:
            continue
        a = b.matrix_local.to_3x3().inverted() @ axis
        if name.endswith('Thumb'):
            a = b.matrix_local.to_3x3().inverted() @ (hb @ f_l)
        pb = rig.pose.bones[name]; pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion(a.normalized(), math.radians(deg))


class Setup:
    """Weapon bone, IK targets, poles and leg IK on the character rig."""
    def __init__(self, rig):
        self.rig = rig
        scn = bpy.context.scene
        bpy.context.view_layer.objects.active = rig
        # Stance pose to measure the weapon frame.
        set_pose(rig, {**neutral_deltas(), **stance_deltas()}, arm_rest(rig, 'Hips').translation)
        bpy.context.view_layer.update()
        chest = rig.pose.bones[T('Spine1')]
        self.chest_stance = rig.matrix_world @ chest.matrix
        self.chest_rest = arm_rest(rig, 'Spine1')
        w_stance = weapon_matrix(rig)
        self.w_sprint = weapon_matrix(rig, sprint=True)
        self.w_stance = w_stance
        # Weapon bone rest = stance weapon frame carried back to the rest chest.
        mw0 = self.chest_rest @ self.chest_stance.inverted() @ w_stance
        self.mw0 = mw0
        bpy.ops.object.mode_set(mode='EDIT')
        eb = rig.data.edit_bones.new('Weapon')
        eb.head = (0, 0, 0); eb.tail = (0, 0.15, 0)
        eb.matrix = rig.matrix_world.inverted() @ mw0
        eb.parent = rig.data.edit_bones[T('Spine1')]; eb.use_deform = False
        bpy.ops.object.mode_set(mode='OBJECT')
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
        self.socket = empty('WeaponSocket', 0.05)
        bpy.context.view_layer.update()
        parent_to_bone(self.socket, rig, 'Weapon', self.weapon_world())
        # Arm IK.
        self.ik = {}
        for side in ('R', 'L'):
            s = 'Left' if side == 'L' else 'Right'
            tgt = empty('IK.' + side); parent_to_bone(tgt, rig, 'Weapon', self.weapon_world())
            pole = empty('Pole.' + side)
            elbow = Vector((-0.55, 0.25, -0.45)) if side == 'R' else Vector((0.45, -0.1, -0.6))
            parent_to_bone(pole, rig, T('Spine1'), Matrix.Translation(self.chest_rest.translation + elbow))
            fore = rig.pose.bones[T(s + 'ForeArm')]
            ik = fore.constraints.new('IK'); ik.target = tgt; ik.chain_count = 2
            ik.pole_target = pole; ik.pole_angle = 0
            hand = rig.pose.bones[T(s + 'Hand')]
            cr = hand.constraints.new('COPY_ROTATION'); cr.target = tgt
            # The IK goal is the wrist: hand head == forearm tail.
            self.ik[side] = (tgt, pole, ik, cr)
        # Leg IK (used by idle/crouch/jump clips).
        self.leg = {}
        for side in ('L', 'R'):
            s = 'Left' if side == 'L' else 'Right'
            tgt = empty('Foot.' + side); knee = empty('Knee.' + side)
            shin = rig.pose.bones[s + 'Leg']
            ik = shin.constraints.new('IK'); ik.target = tgt; ik.chain_count = 2; ik.pole_target = knee; ik.pole_angle = 0
            cr = rig.pose.bones[s + 'Foot'].constraints.new('COPY_ROTATION'); cr.target = tgt
            self.leg[side] = (tgt, knee, ik, cr)
        self.calibrate_poles()

    def weapon_world(self, basis=Matrix.Identity(4)):
        rig = self.rig
        bpy.context.view_layer.update()
        chest = rig.matrix_world @ rig.pose.bones[T('Spine1')].matrix
        return chest @ self.chest_rest.inverted() @ self.mw0 @ basis

    def weapon_basis(self, target_world_at_stance):
        return self.mw0.inverted() @ self.chest_rest @ self.chest_stance.inverted() @ target_world_at_stance

    def legs(self, on):
        for tgt, knee, ik, cr in self.leg.values():
            ik.influence = 1.0 if on else 0.0; cr.influence = 1.0 if on else 0.0

    def calibrate_poles(self):
        rig = self.rig
        set_pose(rig, {**neutral_deltas(), **stance_deltas()}, arm_rest(rig, 'Hips').translation)
        self.place_hands(Matrix.Identity(4))
        for side, (tgt, pole, ik, cr) in self.ik.items():
            s = 'Left' if side == 'L' else 'Right'
            best = None
            for deg in range(-180, 180, 15):
                ik.pole_angle = math.radians(deg); bpy.context.view_layer.update()
                elbow = (rig.matrix_world @ rig.pose.bones[T(s + 'ForeArm')].head)
                d = (elbow - pole.matrix_world.translation).length
                if best is None or d < best[0]:
                    best = (d, deg)
            ik.pole_angle = math.radians(best[1]); print('POLE', side, best[1])
        # Knees forward.
        self.legs(True)
        rest_hips = arm_rest(rig, 'Hips').translation
        for side, (tgt, knee, ik, cr) in self.leg.items():
            s = 'Left' if side == 'L' else 'Right'
            foot = arm_rest(rig, s + 'Foot')
            tgt.matrix_world = foot
            knee.location = arm_rest(rig, s + 'Leg').translation + FWD * 0.6
        set_pose(rig, neutral_deltas(), rest_hips + UP * -0.12)
        for side, (tgt, knee, ik, cr) in self.leg.items():
            s = 'Left' if side == 'L' else 'Right'
            best = None
            for deg in range(-180, 180, 15):
                ik.pole_angle = math.radians(deg); bpy.context.view_layer.update()
                k = rig.matrix_world @ rig.pose.bones[s + 'Leg'].head
                d = (k - knee.location).length
                if best is None or d < best[0]:
                    best = (d, deg)
            ik.pole_angle = math.radians(best[1]); print('KNEE POLE', side, best[1])
        self.legs(False)

    def place_hands(self, weapon_basis, left=None):
        """Key-free placement of IK targets in Weapon-bone space (left may override the support grip)."""
        rig = self.rig
        bpy.context.view_layer.update()
        wm = self.weapon_world()  # weapon frame without the per-frame basis (targets are children of the bone)
        for side, contact in (('R', GRIP), ('L', left or SUPPORT)):
            tgt = self.ik[side][0]
            tgt.matrix_world = hand_target(rig, side, self.weapon_world(weapon_basis), contact)
        bpy.context.view_layer.update()


# ------------------------------------------------------------------ clip authoring

class Clip:
    def __init__(self, name, frames):
        self.name = name; self.frames = frames; self.keys = []  # per frame: dict

def author_frame(setup, d, hips, weapon=Matrix.Identity(4), left=None, feet=None, frame=0):
    rig = setup.rig
    set_pose(rig, d, hips)
    wb = rig.pose.bones['Weapon']; wb.rotation_mode = 'QUATERNION'
    loc, q, _ = weapon.decompose(); wb.location = loc; wb.rotation_quaternion = q
    curl_fingers(rig, 'R', 40, 50, 10); curl_fingers(rig, 'L', 34, 44, 8)
    # Key before evaluating: the depsgraph re-applies the action and would discard unkeyed edits.
    key_pose(rig, frame)
    bpy.context.scene.frame_set(frame)
    # IK targets live under the weapon bone: express them for this frame and key their local transform.
    for side, contact in (('R', GRIP), ('L', left or SUPPORT)):
        tgt = setup.ik[side][0]
        tgt.matrix_world = hand_target(rig, side, rig.matrix_world @ rig.pose.bones['Weapon'].matrix, contact)
        tgt.keyframe_insert('location', frame=frame); tgt.keyframe_insert('rotation_euler', frame=frame)
    if feet:
        for side, m in feet.items():
            tgt = setup.leg[side][0]; tgt.matrix_world = m
            tgt.keyframe_insert('location', frame=frame); tgt.keyframe_insert('rotation_euler', frame=frame)


def stance_feet(rig, spread=0.06, stagger=0.12, toe_out=10):
    out = {}
    for side, sx, sy in (('L', 1, -1), ('R', -1, 1)):
        s = 'Left' if side == 'L' else 'Right'
        m = arm_rest(rig, s + 'Foot')
        p = m.translation + Vector((sx * spread * -RIGHT.x, 0, 0)) + FWD * (stagger * 0.5 * -sy if side == 'L' else -stagger * 0.5)
        r = rot(UP, toe_out * sx * -1) @ m.to_quaternion()
        out[side] = Matrix.Translation(p) @ r.to_matrix().to_4x4()
    return out


def clip_stance_loop(setup, name, seconds, hips_drop, feet, lean=10, breathe=1.0, kneel=None):
    rig = setup.rig
    n = int(seconds * FPS)
    rest = arm_rest(rig, 'Hips').translation
    for f in range(n + 1):
        ph = 2 * math.pi * f / n
        st = stance_deltas(lean=lean + math.sin(ph) * 1.2 * breathe)
        d = {**neutral_deltas(), **st}
        d['Hips'] = rot(UP, -8) @ rot(RIGHT, -lean * 0.3)
        hips = rest + UP * (-hips_drop + math.sin(ph * 2) * 0.004 * breathe) + FWD * (-0.02 - hips_drop * 0.25)
        author_frame(setup, d, hips, feet=feet, frame=f)
    return n


def clip_from_mocap(setup, role, clip):
    rig = setup.rig
    cyc = mocap_cycle(rig, role, clip)
    n = len(cyc) - 1
    sprint = clip.get('sprint')
    st = stance_deltas(lean=18 if sprint else 9, blade=8 if sprint else 22)
    wb = setup.weapon_basis(setup.w_sprint) if sprint else Matrix.Identity(4)
    crouch = clip.get('crouch')
    feet_track = None
    if crouch:
        # First pass: foot frames of the upright walk, then lower the hips and solve the legs by IK.
        setup.legs(False); feet_track = []
        for d, pos in cyc:
            set_pose(rig, {**neutral_deltas(), **d}, pos); bpy.context.view_layer.update()
            fm = {}
            for side in ('L', 'R'):
                s = 'Left' if side == 'L' else 'Right'
                m = rig.matrix_world @ rig.pose.bones[s + 'Foot'].matrix
                lateral = Vector((0.05 if side == 'L' else -0.05, 0, 0))
                fm[side] = Matrix.Translation(m.translation + lateral) @ m.to_quaternion().to_matrix().to_4x4()
            feet_track.append(fm)
        setup.legs(True)
    for f, (d, pos) in enumerate(cyc):
        dd = blend_upper(d, st, 0.85 if sprint else 1.0)
        if crouch:
            dd['Hips'] = rot(RIGHT, -16) @ dd['Hips']
            pos = pos + UP * -crouch + FWD * 0.05
            dd = blend_upper(dd, stance_deltas(lean=24, blade=20), 1.0)
        author_frame(setup, dd, pos, weapon=wb, feet=feet_track[f] if crouch else None, frame=f)
    setup.legs(False)
    return n


def clip_jump(setup):
    rig = setup.rig
    n = int(0.8 * FPS)
    rest = arm_rest(rig, 'Hips').translation
    for f in range(n + 1):
        x = f / n
        tuck = math.sin(min(1.0, x * 1.6) * math.pi * 0.5)
        d = {**neutral_deltas(), **stance_deltas(lean=12)}
        for side, k in (('Left', 1.0), ('Right', 0.7)):
            d[side + 'UpLeg'] = rot(RIGHT, 38 * tuck * k)
            d[side + 'Leg'] = rot(RIGHT, (38 - 75) * tuck * k)
            d[side + 'Foot'] = rot(RIGHT, (38 - 75 + 20) * tuck * k)
        author_frame(setup, d, rest + UP * (0.04 * tuck), frame=f)
    return n


def clip_reload(setup, feet):
    """2.0 s: left hand strips the magazine, stows it on the vest, seats a new one, returns to the handguard."""
    rig = setup.rig
    n = int(2.0 * FPS)
    rest = arm_rest(rig, 'Hips').translation
    pouch = (Vector((-0.055, -0.02, -0.30)), Vector((0.1, 0.2, -1.0)), Vector((0.95, 0.2, 0.1)))
    keys = [(0.0, SUPPORT), (0.25, MAGWELL), (0.42, MAGWELL), (0.75, pouch), (0.95, pouch), (1.30, MAGWELL), (1.45, MAGWELL), (1.78, SUPPORT), (2.0, SUPPORT)]
    def lerp_contact(t):
        for (t0, c0), (t1, c1) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                x = (t - t0) / max(1e-6, t1 - t0); x = x * x * (3 - 2 * x)
                return tuple(a.lerp(b, x) for a, b in zip(c0, c1))
        return SUPPORT
    for f in range(n + 1):
        t = f / FPS
        d = {**neutral_deltas(), **stance_deltas()}
        d['Hips'] = rot(UP, -8)
        tilt = math.sin(min(1.0, t / 1.8) * math.pi) * 1.0
        wb = setup.weapon_basis(setup.w_stance @ Matrix.Rotation(math.radians(-24 * tilt), 4, 'Y') @ Matrix.Rotation(math.radians(8 * tilt), 4, 'X'))
        author_frame(setup, d, rest + UP * -0.03 + FWD * -0.02, weapon=wb, left=lerp_contact(t), feet=feet, frame=f)
    return n


def clip_death(setup):
    """1.0 s: knees give, the body pitches forward onto the ground."""
    rig = setup.rig
    n = int(1.0 * FPS)
    rest = arm_rest(rig, 'Hips').translation
    hip_h = rest.z
    for f in range(n + 1):
        x = f / n
        k = min(1.0, x / 0.45); k = k * k * (3 - 2 * k)  # knees buckle
        g = max(0.0, (x - 0.35) / 0.65); g = g * g  # fall forward
        d = {**neutral_deltas(), **stance_deltas(lean=10 + 25 * k)}
        for side, a in (('Left', 1.0), ('Right', 0.85)):
            d[side + 'UpLeg'] = rot(RIGHT, (70 * k - 60 * g) * a)
            d[side + 'Leg'] = rot(RIGHT, (70 * k - 60 * g) * a - 110 * k * a + 80 * g)
            d[side + 'Foot'] = rot(RIGHT, -50 * k + 30 * g)
        fall = rot(RIGHT, -82 * g) @ rot(FWD, 10 * g)
        for b in list(d):
            d[b] = fall @ d[b]
        drop = (hip_h - 0.55) * k + (0.55 - 0.16) * g
        hips = rest + UP * -drop + FWD * (0.2 * k + 0.55 * g)
        author_frame(setup, d, hips, frame=f)
    return n


# ------------------------------------------------------------------ bake / export

def bake(setup, name, n):
    rig = setup.rig
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.select_all(action='SELECT')
    src = rig.animation_data.action
    bpy.ops.nla.bake(frame_start=0, frame_end=n, only_selected=False, visual_keying=True,
                     clear_constraints=False, use_current_action=False, bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')
    out = rig.animation_data.action; out.name = name; out.use_fake_user = True
    bpy.data.actions.remove(src)
    return out


def preview(path, frame, angle=25, dist=3.4, z=1.1):
    scn = bpy.context.scene
    cam = bpy.data.objects.get('PreviewCam')
    if not cam:
        cam = bpy.data.objects.new('PreviewCam', bpy.data.cameras.new('PreviewCam')); scn.collection.objects.link(cam)
        sun = bpy.data.objects.new('PreviewSun', bpy.data.lights.new('PreviewSun', 'SUN')); sun.data.energy = 3.2
        sun.rotation_euler = (0.9, 0.2, 0.6); scn.collection.objects.link(sun)
        w = bpy.data.worlds.new('w'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.5, 0.53, 0.57, 1); scn.world = w
        floor = bpy.data.objects.new('PreviewFloor', bpy.data.meshes.new('PreviewFloor'))
        floor.data.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)]); scn.collection.objects.link(floor)
    a = math.radians(angle)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, z); cam.rotation_euler = (math.radians(84 if z < 1.2 else 80), 0, a); cam.data.lens = 42
    scn.camera = cam; scn.frame_set(frame)
    scn.render.engine = 'CYCLES'; scn.cycles.samples = 10; scn.cycles.device = 'CPU'
    scn.render.resolution_x = 520; scn.render.resolution_y = 640; scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def opaque_materials():
    """Game materials: opaque, no clearcoat (MakeHuman wires texture alpha into every BSDF)."""
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type != 'BSDF_PRINCIPLED':
                continue
            for name in ('Alpha', 'Coat Weight', 'Transmission Weight', 'Subsurface Weight'):
                sock = n.inputs.get(name)
                if sock is None:
                    continue
                for link in list(sock.links):
                    m.node_tree.links.remove(link)
                sock.default_value = 1.0 if name == 'Alpha' else 0.0
        m.blend_method = 'OPAQUE'


def export_textures(team, limit=1024):
    """Re-encode every material image at <= limit px: JPEG, or PNG where alpha is really used."""
    tmp = os.path.join('/tmp/claude-0/soldier_tex', team); os.makedirs(tmp, exist_ok=True)
    for img in list(bpy.data.images):
        if img.users == 0 or img.size[0] == 0 or img.type != 'IMAGE':
            continue
        if img.size[0] > limit:
            img.scale(limit, max(1, int(img.size[1] * limit / img.size[0])))
        px = np.empty(img.size[0] * img.size[1] * 4, np.float32); img.pixels.foreach_get(px)
        alpha = False  # materials are opaque (opaque_materials)
        name = ''.join(c if c.isalnum() else '_' for c in img.name)
        path = os.path.join(tmp, name + ('.png' if alpha else '.jpg'))
        out = bpy.data.images.new(name, img.size[0], img.size[1], alpha=alpha)
        out.pixels.foreach_set(px)
        out.filepath_raw = path; out.file_format = 'PNG' if alpha else 'JPEG'
        out.save(filepath=path, quality=88)
        fresh = bpy.data.images.load(path); fresh.colorspace_settings.name = img.colorspace_settings.name
        img.user_remap(fresh)
        bpy.data.images.remove(out)


def build(team, spec):
    body, rig = build_body(team, spec)
    scn = bpy.context.scene; scn.render.fps = FPS
    rig.animation_data_create()
    setup = Setup(rig)
    gun = None
    if '--preview' in ARGS:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, 'assets', 'viewmodels', 'world_ar.glb'))
        gun = [o for o in set(bpy.data.objects) - before]
        holder = empty('PreviewGun'); parent_to_bone(holder, rig, 'Weapon', setup.weapon_world())
        for o in gun:
            if o.parent is None:
                o.parent = holder
    feet_idle = stance_feet(rig)
    feet_crouch = stance_feet(rig, spread=0.1, stagger=0.3, toe_out=14)
    plan = [('Idle', lambda: clip_stance_loop(setup, 'Idle', 3.0, 0.035, feet_idle)),
            ('CrouchIdle', lambda: clip_stance_loop(setup, 'CrouchIdle', 3.0, 0.44, feet_crouch, lean=22, breathe=0.6)),
            ('Reload', lambda: clip_reload(setup, feet_idle)),
            ('Jump', lambda: clip_jump(setup)),
            ('Death', lambda: clip_death(setup))]
    plan += [(role, (lambda r=role, c=clip: clip_from_mocap(setup, r, c))) for role, clip in CLIPS.items()]
    if '--analyze' in ARGS:
        extra = [a[6:] for a in ARGS if a.startswith('--bvh=')]
        for role, clip in ([(e, {'bvh': e, 'speed': 5.1}) for e in extra] or CLIPS.items()):
            try:
                mocap_cycle(rig, role, clip)
            except Exception as ex:
                print('CLIP', role, 'failed', ex)
        return
    only = [a[7:] for a in ARGS if a.startswith('--clip=')]
    baked = []
    for role, fn in plan:
        if only and role not in only:
            continue
        rig.animation_data.action = bpy.data.actions.new(role + '_src')
        for side in ('R', 'L'):
            t = setup.ik[side][0]; t.animation_data_clear(); t.animation_data_create()
            t.animation_data.action = bpy.data.actions.new(f'IK{side}_{role}')
        for side in ('R', 'L'):
            t = setup.leg[side][0]; t.animation_data_clear(); t.animation_data_create()
            t.animation_data.action = bpy.data.actions.new(f'Foot{side}_{role}')
        setup.legs(role in ('Idle', 'CrouchIdle', 'Reload', 'CrouchWalk'))
        n = clip_from_mocap(setup, role, CLIPS[role]) if role in CLIPS else fn()
        setup.legs(role in ('Idle', 'CrouchIdle', 'Reload', 'CrouchWalk'))
        a = bake(setup, role, n)
        baked.append(a)
        print('BAKED', role, n)
        if '--preview' in ARGS:
            for frac in (0.0, 0.5) if role not in ('Death', 'Reload') else (0.0, 0.4, 0.75, 1.0):
                preview(f'/tmp/claude-0/soldier/{team}_{role}_{int(frac * 100)}.png', int(n * frac))
            if role == 'Idle':
                preview(f'/tmp/claude-0/soldier/{team}_{role}_hands.png', 0, angle=40, dist=1.0, z=1.3)
                preview(f'/tmp/claude-0/soldier/{team}_{role}_side.png', 0, angle=95)
                preview(f'/tmp/claude-0/soldier/{team}_{role}_front.png', 0, angle=0, dist=2.6)
    if '--no-export' in ARGS or only:
        return
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    for o in list(bpy.data.objects):
        if o.name.startswith(('IK.', 'Pole.', 'Foot.', 'Knee.', 'Preview')) or (gun and o in gun):
            bpy.data.objects.remove(o, do_unlink=True)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion(); pb.location = Vector()
    for a in baked:
        track = rig.animation_data.nla_tracks.new(); track.name = a.name
        track.strips.new(a.name, 0, a); track.mute = True
    os.makedirs(OUT, exist_ok=True)
    opaque_materials()
    export_textures(team)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f'soldier_{team}.glb'), export_format='GLB',
                              export_animations=True, export_animation_mode='NLA_TRACKS', export_apply=True,
                              export_image_format='JPEG', export_jpeg_quality=88, export_def_bones=False,
                              export_optimize_animation_size=True, export_skins=True)
    print('SOLDIER', team, [a.name for a in baked])


os.makedirs('/tmp/claude-0/soldier', exist_ok=True)
for team, spec in TEAMS.items():
    if [a for a in ARGS if not a.startswith('--')] and team not in ARGS:
        continue
    build(team, spec)
