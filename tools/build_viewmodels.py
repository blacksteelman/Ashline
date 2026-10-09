"""Blender: author ASHLINE first-person viewmodels (arms + weapon) with baked animation.

blender -b --python tools/build_viewmodels.py -- [weapon ...] [--preview]

Sources (CC0): MakeHuman/para FPS arm rig (hands), M4A1 by nisu (AR-41 and the
derived KITE-9 carbine), Poly Haven bolt_action_rifle_7_62 (MR-62) and
service_pistol (P-12). Sleeves, camo, poses and every animation are authored here.

Everything is built in camera space: Blender +Y forward, +Z up, eye at origin
(Godot: -Z forward). The exported scene root sits on the player camera.
Animations: idle, draw, sprint, reload, reload_empty, plus cycle (bolt rifle).
Godot reads empties Sight, Muzzle and Ejector for ADS alignment and effects.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Quaternion, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TP = os.path.join(ROOT, 'assets', 'thirdparty')
TEX = os.path.join(ROOT, 'assets', 'textures')
OUT = os.path.join(ROOT, 'assets', 'viewmodels')
FPS = 60
CURL_SIGN = -1.0 if '--curl-neg' in sys.argv else 1.0
POLE = {'L': -90.0, 'R': -90.0}
for _a in sys.argv:
    if _a.startswith('--pole='):
        POLE['L'], POLE['R'] = [float(x) for x in _a[7:].split(',')]
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PREVIEW = '--preview' in ARGS
ONLY = [a for a in ARGS if not a.startswith('--')]

SHOULDER = Vector((0.0, 0.0, -0.25))   # midpoint between the clavicle heads
SHOULDER_OFFSET = {'R': Vector((0.05, -0.08, -0.03)), 'L': Vector((-0.02, 0.06, -0.04))}


def D(*v):
    return Vector(v)


def euler(x=0, y=0, z=0):
    return Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ').to_matrix().to_4x4()


# ------------------------------------------------------------------ weapons
# hip: weapon root in camera space (location, euler degrees). Weapon space:
# +Y muzzle, +Z up, origin at the top of the pistol grip.
# grip/support: (wrist position, finger direction, palm normal) in weapon space.
WEAPONS = {
    # Hand tuples: (palm contact point on the weapon surface, knuckle direction, palm normal).
    'ar': {
        'hip': (D(0.165, 0.26, -0.118), (1.5, -4.0, 5.5)),
        'grip': (D(0.014, -0.035, -0.07), D(-0.15, 0.77, -0.6), D(-1, 0.0, 0.0)),
        'support': (D(0.0, 0.17, -0.03), D(0.75, 0.62, 0.05), D(0.0, 0.0, 1.0)),
        'mag_hold': (D(-0.013, 0.09, -0.13), D(0.15, 0.2, 0.97), D(1.0, 0.0, 0.0)),
        'import': lambda: import_ar(),
        'tracks': [lambda sp: rifle_tracks(sp), lambda sp: rifle_tracks(sp, True)],
    },
    'carbine': {
        'hip': (D(0.16, 0.25, -0.12), (1.5, -5.0, 5.5)),
        'grip': (D(0.014, -0.035, -0.07), D(-0.15, 0.77, -0.6), D(-1, 0.0, 0.0)),
        'support': (D(-0.017, 0.30, -0.075), D(0.35, 0.94, 0.0), D(1.0, 0.0, 0.0)),
        'mag_hold': (D(-0.013, 0.08, -0.11), D(0.15, 0.2, 0.97), D(1.0, 0.0, 0.0)),
        'import': lambda: import_carbine(),
        'tracks': [lambda sp: rifle_tracks(sp), lambda sp: rifle_tracks(sp, True)],
    },
    'sniper': {
        'hip': (D(0.175, 0.23, -0.112), (1.0, -3.0, 6.5)),
        'grip': (D(0.022, -0.12, -0.045), D(-0.1, 0.85, -0.5), D(-1, 0.0, 0.0)),
        'support': (D(0.0, 0.31, -0.03), D(0.75, 0.62, 0.05), D(0.0, 0.0, 1.0)),
        'mag_hold': (D(0.0, 0.31, -0.03), D(0.75, 0.62, 0.05), D(0.0, 0.0, 1.0)),
        'bolt_axis': D(0.0, 0.0, 0.046),
        'bolt_knob': (D(0.06, 0.125, 0.015), D(-0.1, 0.55, -0.83), D(-1.0, 0.0, 0.0)),
        'import': lambda: import_sniper(),
        'tracks': [lambda sp: sniper_tracks(sp)],
    },
    'pistol': {
        'hip': (D(0.10, 0.31, -0.088), (3.0, -2.0, 4.0)),
        'grip': (D(0.018, -0.002, -0.05), D(-0.15, 0.95, -0.2), D(-1, 0.0, 0.0)),
        'support': (D(-0.036, 0.008, -0.07), D(0.1, 0.75, -0.65), D(1.0, 0.0, 0.2)),
        'mag_hold': (D(0.0, 0.0, -0.096), D(0.2, 0.95, 0.1), D(0.0, 0.0, 1.0)),
        'import': lambda: import_pistol(),
        'tracks': [lambda sp: pistol_tracks(sp), lambda sp: pistol_tracks(sp, True)],
    },
}


# ------------------------------------------------------------------ helpers
def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def apply_matrix_to_object(obj, m):
    if obj.type == 'MESH':
        obj.data.transform(m @ obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)


def load_arms():
    # Open the source file itself: appending breaks its parent-inverse chain
    # and the skin no longer matches the bones.
    bpy.ops.wm.open_mainfile(filepath=os.path.join(TP, 'viewmodel', 'arms', 'FPS ARMS RIG 1.blend'))
    rig = bpy.data.objects['caucasian_male_1']
    body = bpy.data.objects['caucasian_male_1:Body']
    for o in list(bpy.data.objects):
        if o not in (rig, body):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    bpy.context.scene.render.fps = FPS
    bpy.context.view_layer.update()
    rig.animation_data_clear()
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        pb.matrix_basis = Matrix.Identity(4)
        pb.rotation_mode = 'QUATERNION'
    # Source units are decimetres facing -Y: scale, turn to +Y and move the
    # shoulders under the camera.
    T = Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Diagonal((0.105, 0.105, 0.105, 1))
    if body.data.shape_keys:
        body.shape_key_clear()
    bw = body.matrix_world.copy(); rw = rig.matrix_world.copy()
    body.parent = None
    body.data.transform(T @ bw); body.matrix_world = Matrix.Identity(4)
    rig.data.transform(T @ rw); rig.matrix_world = Matrix.Identity(4)
    # Verify the result instead of trusting the source orientation: the right
    # hand must end up on +X and the hands in front (+Y) of the shoulders.
    bones = rig.data.bones
    if bones['hand.R'].head_local.x < bones['hand.L'].head_local.x:
        flip = Matrix.Rotation(math.pi, 4, 'Z')
        rig.data.transform(flip); body.data.transform(flip)
    if bones['hand.R'].head_local.y < bones['clavicle.R'].head_local.y:
        raise RuntimeError('arm rig faces backwards after orientation fix')
    mid = (rig.data.bones['clavicle.L'].head_local + rig.data.bones['clavicle.R'].head_local) / 2
    shift = Matrix.Translation(SHOULDER - mid)
    rig.data.transform(shift); body.data.transform(shift)
    # The source hands hang from free "hand.X.control" bones; chain them to the
    # forearms so IK solves shoulder -> elbow -> wrist.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    for side in 'LR':
        eb['hand.' + side].parent = eb['forearm.' + side]
        eb.remove(eb['hand.%s.control' % side])
    bpy.ops.object.mode_set(mode='OBJECT')
    # Independent shoulder placement: the trigger arm sits back and out so the
    # elbow drops naturally; the support shoulder stays forward to reach the handguard.
    offsets = {'R': SHOULDER_OFFSET['R'], 'L': SHOULDER_OFFSET['L']}
    bpy.ops.object.mode_set(mode='EDIT')
    for b in rig.data.edit_bones:
        b.use_connect = False  # connected heads would drag parent tails twice
    for b in rig.data.edit_bones:
        side = 'R' if b.name.endswith('.R') else ('L' if b.name.endswith('.L') else None)
        if side:
            b.head += offsets[side]; b.tail += offsets[side]
    bpy.ops.object.mode_set(mode='OBJECT')
    # Side of each vertex from its skin weights, never from its position.
    names = {g.index: g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        wr = sum(g.weight for g in v.groups if names[g.group].endswith('.R'))
        wl = sum(g.weight for g in v.groups if names[g.group].endswith('.L'))
        v.co += offsets['R'] if wr >= wl else offsets['L']
    rig.name = 'Arms'; body.name = 'Hands'
    body.parent = rig
    mod = body.modifiers.get('Armature') or body.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig
    bpy.context.view_layer.update()
    return rig, body


def cut_forearms(rig, body):
    """Keep only the hands; sleeves replace the bare source forearms."""
    remove = set()
    names = {g.index: g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        wr = sum(g.weight for g in v.groups if names[g.group].endswith('.R'))
        wl = sum(g.weight for g in v.groups if names[g.group].endswith('.L'))
        side = 'R' if wr >= wl else 'L'
        head = rig.data.bones['hand.' + side].head_local
        fwd = (rig.data.bones['f_middle.01.' + side].head_local - head).normalized()
        if (v.co - head).dot(fwd) < -0.014 or (v.co - head).length > 0.24:
            remove.add(v.index)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index in remove], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    for p in body.data.polygons:
        p.use_smooth = True
    # The kept mesh is hands only: arm-bone weights would stretch the wrist
    # across the screen when the hand twists, so fold them into the hand bone.
    names = {g.index: g.name for g in body.vertex_groups}
    for side in 'LR':
        hand = body.vertex_groups['hand.' + side]
        for v in body.data.vertices:
            moved = 0.0
            for g in list(v.groups):
                n = names[g.group]
                if n.endswith('.' + side) and n.split('.')[0] in ('forearm', 'upper_arm', 'deltoid', 'clavicle'):
                    moved += g.weight; g.weight = 0.0
            if moved > 0:
                hand.add([v.index], moved, 'ADD')


def image_material(name, color_path, normal_path=None, roughness=0.8, orm_path=None, normal_strength=0.6):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    nt = mat.node_tree; bsdf = nt.nodes['Principled BSDF']
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(color_path)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = roughness
    if normal_path:
        n = nt.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(normal_path)
        n.image.colorspace_settings.name = 'Non-Color'
        nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = normal_strength
        nt.links.new(n.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    return mat


def sleeve(rig, side, part, r0, r1, cuff=False):
    """Fabric tube skinned to one arm bone, with folds and an optional cuff."""
    bone = rig.data.bones[f'{part}.{side}']
    basis = bone.matrix_local.to_3x3()
    rings, seg = 22, 24
    mesh = bpy.data.meshes.new(f'Sleeve_{part}_{side}')
    verts, faces, uvs = [], [], []
    over = 0.035 if part == 'forearm' else 0.03
    for i in range(rings):
        t = i / (rings - 1)
        along = -over + t * (bone.length + over * (1.6 if part == 'forearm' else 1.0))
        r = r0 * (1 - t) + r1 * t
        r *= 1 + 0.035 * math.sin(t * math.pi * 9 + (1 if side == 'L' else 0))
        if cuff and t > 0.86:
            r *= 1.12
        for j in range(seg):
            a = j * math.tau / seg
            wob = 1 + 0.03 * math.sin(a * 3 + t * 7)
            verts.append(bone.head_local + basis @ D(math.cos(a) * r * wob, along, math.sin(a) * r * wob * 0.92))
    for i in range(rings - 1):
        for j in range(seg):
            a = i * seg + j; b = i * seg + (j + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    # Closed ends: no see-through openings where sleeves meet at the elbow.
    for ring in (0, rings - 1):
        centre = sum((Vector(verts[ring * seg + j]) for j in range(seg)), Vector()) / seg
        verts.append(centre); c = len(verts) - 1
        for j in range(seg):
            a = ring * seg + j; b = ring * seg + (j + 1) % seg
            faces.append((a, b, c) if ring == rings - 1 else (b, a, c))
    mesh.from_pydata(verts, [], faces)
    uv = mesh.uv_layers.new()
    for poly in mesh.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            i, j = divmod(min(vi, rings * seg - 1), seg)
            u = j / seg
            if poly.vertices[0] % seg == seg - 1 and j == 0:
                u = 1.0
            uv.data[li].uv = (u * 1.5, i / (rings - 1) * (bone.length * 4))
        poly.use_smooth = True
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = rig
    vg = obj.vertex_groups.new(name=bone.name)
    vg.add(list(range(len(verts))), 1.0, 'REPLACE')
    if part == 'forearm':
        # Wrist end follows the hand slightly so twisting reads as cloth, not a hinge.
        hand = obj.vertex_groups.new(name=f'hand.{side}')
        for i in range(rings):
            w = max(0.0, (i / (rings - 1) - 0.8) / 0.2) * 0.35
            if w > 0:
                ids = list(range(i * seg, (i + 1) * seg))
                hand.add(ids, w, 'REPLACE'); vg.add(ids, 1 - w, 'REPLACE')
    obj.modifiers.new('Armature', 'ARMATURE').object = rig
    return obj


def add_weapon_bones(rig, hip_matrix, bolt_axis=Vector((0, 0, 0))):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    for name, parent in [('weapon', None), ('bolt', 'weapon'), ('magazine', None), ('aux', None)]:
        b = eb.new(name)
        base = bolt_axis if name == 'bolt' else D(0, 0, 0)
        b.head = hip_matrix @ base; b.tail = hip_matrix @ (base + D(0, 0.08, 0))
        b.align_roll(hip_matrix.to_3x3() @ D(0, 0, 1))
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode='OBJECT')


def hand_frame(rig, side):
    """Columns: finger direction, across (towards the thumb for R / pinky for L), palm normal."""
    bones = rig.data.bones
    head = bones['hand.' + side].head_local
    f = (bones['f_middle.01.' + side].head_local - head).normalized()
    across = bones['palm_index.' + side].head_local - bones['palm_pinky.' + side].head_local
    if side == 'L':
        across = -across
    across = (across - f * across.dot(f)).normalized()
    palm = f.cross(across).normalized()
    # The rest fingers already curl towards the real palm: let them decide the sign.
    tip = bones['f_middle.03.' + side].tail_local - bones['f_middle.01.' + side].head_local
    if tip.dot(palm) < 0:
        palm = -palm
    across = palm.cross(f).normalized()
    return Matrix((f, across, palm)).transposed()


def palm_offset(rig, side):
    """Rest-pose vector from the wrist (hand head) to the centre of the palm skin."""
    b = rig.data.bones
    centre = (b['palm_middle.' + side].head_local + b['f_middle.01.' + side].head_local) * 0.5
    return centre + hand_frame(rig, side).col[2] * 0.016 - b['hand.' + side].head_local


def target_matrix(rig, side, contact, finger_dir, palm_normal):
    """IK target that lays the palm centre on `contact` with the palm facing
    `palm_normal` and the knuckles pointing along `finger_dir` (armature space)."""
    rest = hand_frame(rig, side)
    f = finger_dir.normalized()
    p = (palm_normal - f * palm_normal.dot(f)).normalized()
    a = p.cross(f).normalized()  # same handedness as hand_frame
    want = Matrix((f, a, p)).transposed()
    rot = want @ rest.inverted()
    hand_rest = rig.data.bones['hand.' + side].matrix_local.to_3x3()
    m = (rot @ hand_rest).to_4x4()
    m.translation = contact - rot @ palm_offset(rig, side)
    return m


def setup_ik(rig):
    targets = {}
    for side in 'LR':
        t = bpy.data.objects.new('IK.' + side, None); bpy.context.scene.collection.objects.link(t)
        pole = bpy.data.objects.new('Pole.' + side, None); bpy.context.scene.collection.objects.link(pole)
        pole.location = D(-0.5, 0.25, -0.75) if side == 'L' else D(0.55, -0.05, -0.7)
        c = rig.pose.bones['hand.' + side].constraints.new('IK')
        c.target = t; c.pole_target = pole; c.chain_count = 2; c.use_rotation = False; c.use_tail = False
        c.pole_angle = math.radians(POLE[side])
        r = rig.pose.bones['hand.' + side].constraints.new('COPY_ROTATION')
        r.target = t; r.target_space = 'WORLD'; r.owner_space = 'WORLD'
        targets[side] = t
    return targets


FINGERS = ['f_index', 'f_middle', 'f_ring', 'f_pinky']
CURL_AXES = {}


def curl_axes(rig):
    """Flexion axis per finger: normal of the plane its rest segments already
    bend in (segment 1 x segment 3). Rotating about it only deepens that curl."""
    for side in 'LR':
        for f in FINGERS + ['thumb']:
            names = [f'{f}.0{k}.{side}' for k in (1, 2, 3)]
            bones = [rig.data.bones[n] for n in names]
            d1 = (bones[0].tail_local - bones[0].head_local).normalized()
            d3 = (bones[2].tail_local - bones[2].head_local).normalized()
            axis = d1.cross(d3)
            if axis.length < 1e-4:
                palm = hand_frame(rig, side).col[2]
                axis = d1.cross(palm)
            axis.normalize()
            for b, n in zip(bones, names):
                CURL_AXES[n] = (b.matrix_local.to_3x3().inverted() @ axis).normalized()


def curl(rig, side, amount, index=None, thumb=0.5):
    """amount: float for all fingers, or dict finger->amount (keys incl. 'thumb')."""
    if not CURL_AXES:
        curl_axes(rig)
    if isinstance(amount, dict):
        values = amount
    else:
        values = {f: amount for f in FINGERS}
        if index is not None:
            values['f_index'] = index
        values['thumb'] = thumb
    for f in FINGERS:
        for k, deg in ((1, 32), (2, 42), (3, 26)):
            name = f'{f}.0{k}.{side}'
            rig.pose.bones[name].rotation_quaternion = Quaternion(CURL_AXES[name], math.radians(deg * values.get(f, 0.4)))
    for k, deg in ((1, 8), (2, 18), (3, 18)):
        name = f'thumb.0{k}.{side}'
        rig.pose.bones[name].rotation_quaternion = Quaternion(CURL_AXES[name], math.radians(deg * values.get('thumb', 0.4)))


RELAX = {'f_index': 0.45, 'f_middle': 0.5, 'f_ring': 0.55, 'f_pinky': 0.6, 'thumb': 0.4}


def gun_bvh(objs):
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [[base + i for i in p.vertices] for p in me.polygons]
        o.evaluated_get(dg).to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


def solve_curl(rig, side, target_obj, target_m, bvh, fixed=None):
    """Close each finger until a segment touches the weapon surface (6 mm)."""
    target_obj.matrix_world = target_m
    fixed = fixed or {}
    values = dict(RELAX)
    for f in fixed:
        values[f] = fixed[f]
    curl(rig, side, values)
    bpy.context.view_layer.update()
    for f in FINGERS + ['thumb']:
        if f in fixed:
            continue
        chain = [f'{f}.0{k}.{side}' for k in (1, 2, 3)] if f != 'thumb' else [f'thumb.0{k}.{side}' for k in (1, 2, 3)]
        best = 1.3
        for step in range(0, 33):
            c = -0.2 + step * 0.05
            values[f] = c
            curl(rig, side, values)
            bpy.context.view_layer.update()
            pts = []
            for name in chain[1:]:
                pb = rig.pose.bones[name]
                pts += [pb.head, (pb.head + pb.tail) / 2, pb.tail]
            hit = False
            for a_, b_ in zip(pts, pts[1:]):
                d = b_ - a_
                if bvh.ray_cast(a_, d.normalized(), d.length)[0] is not None:
                    hit = True; break
            if not hit:
                for q in pts[3:]:
                    loc, nrm, idx, dist = bvh.find_nearest(q)
                    if loc is not None and dist < 0.006:
                        hit = True; break
            if hit:
                best = c; break
        values[f] = best
        curl(rig, side, values)
    return dict(values)


# ------------------------------------------------------------------ guns
def import_ar():
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, 'assets', 'weapon_0.glb'))
    keep = {}
    for o in list(bpy.context.selected_objects):
        if o.type == 'MESH' and o.name in ('Barrel', 'Bolt carrier', 'Adjustable stock', 'Magazine'):
            mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
            keep[o.name] = o
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('ViewmodelRig', 'Operator', 'ViewmodelArms', 'Icosphere', 'MagazineRig', 'weapon_0')) and o not in keep.values():
            bpy.data.objects.remove(o, do_unlink=True)
    parts = {'body': [keep['Barrel'], keep['Adjustable stock']], 'bolt': [keep['Bolt carrier']], 'magazine': [keep['Magazine']]}
    empties = {'Sight': D(0, -0.02, 0.073), 'Muzzle': D(0, 0.57, 0.021), 'Ejector': D(0.018, 0.075, 0.016)}
    return parts, empties


def gltf_parts(asset, pick, fix):
    """Import a Poly Haven model; pick maps object name -> group; fix moves it into weapon space."""
    bpy.ops.import_scene.gltf(filepath=os.path.join(TP, 'polyhaven', asset, asset + '.gltf'))
    parts = {}
    for o in list(bpy.context.selected_objects):
        if o.type != 'MESH':
            continue
        group = pick.get(o.name)
        if group is None:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = fix @ mw
        parts.setdefault(group, []).append(o)
    for o in list(bpy.context.scene.objects):
        if o.type == 'EMPTY' and not o.children:
            bpy.data.objects.remove(o, do_unlink=True)
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024 * img.size[1] // img.size[0])
    return parts


def import_carbine():
    """KITE-9: CQB carbine derived from the CC0 M4A1 - short barrel, brake, collapsed stock, 20-round magazine, foregrip."""
    parts, empties = import_ar()
    body = parts['body'][0]
    bm = bmesh.new(); bm.from_mesh(body.data)
    cut = [v for v in bm.verts if (body.matrix_world @ v.co).y > 0.47]
    bmesh.ops.delete(bm, geom=cut, context='VERTS')
    bm.to_mesh(body.data); bm.free()
    finish = body.data.materials[0].copy(); finish.name = 'KITE-9 desert finish'
    bsdf = finish.node_tree.nodes.get('Principled BSDF')
    tex = bsdf.inputs['Base Color'].links[0].from_node
    # Desert Cerakote: recolour the albedo itself (glTF has no multiply node).
    img = tex.image.copy(); img.name = 'KITE9_desert'
    px = list(img.pixels); tint = (2.4, 2.05, 1.5)
    for i in range(0, len(px), 4):
        lum = px[i] * 0.3 + px[i + 1] * 0.59 + px[i + 2] * 0.11
        for c in range(3):
            px[i + c] = min(1.0, lum * tint[c] * 0.55 + px[i + c] * 0.25)
    img.pixels = px; img.pack()
    tex.image = img
    body.data.materials[0] = finish
    polymer = bpy.data.materials.new('KITE-9 polymer'); polymer.use_nodes = True
    pb = polymer.node_tree.nodes['Principled BSDF']; pb.inputs['Base Color'].default_value = (0.03, 0.032, 0.03, 1); pb.inputs['Roughness'].default_value = 0.55
    def tube(name, r, depth, loc, rot=(math.pi / 2, 0, 0), segments=20):
        bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=r, depth=depth, location=loc, rotation=rot)
        o = bpy.context.active_object; o.name = name; o.data.materials.append(polymer)
        bpy.ops.object.shade_smooth()
        return o
    brake = tube('Brake', 0.0115, 0.055, (0, 0.495, 0.021))
    for i in range(3):
        slot = tube('BrakeRing%d' % i, 0.0125, 0.004, (0, 0.478 + i * 0.016, 0.021))
        parts['body'].append(slot)
    grip = tube('Foregrip', 0.0145, 0.10, (0, 0.30, -0.065), rot=(0.12, 0, 0))
    cap = tube('ForegripCap', 0.0165, 0.012, (0, 0.297, -0.112), rot=(0.12, 0, 0))
    parts['body'] += [brake, grip, cap]
    stock = parts['body'][1]
    stock.location.y += 0.055
    mag = parts['magazine'][0]
    top = max((mag.matrix_world @ v.co).z for v in mag.data.vertices)
    for v in mag.data.vertices:
        w = mag.matrix_world @ v.co
        w.z = top - (top - w.z) * 0.72
        v.co = mag.matrix_world.inverted() @ w
    empties['Muzzle'] = D(0, 0.525, 0.021)
    return parts, empties


def import_sniper():
    """MR-62: Poly Haven bolt-action 7.62 rifle with its PU-style scope."""
    grip = D(-0.36, 0.0, -0.005)
    fix = Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Translation(-grip)
    pick = {'bolt_action_rifle_7_62': 'body', 'bolt_action_rifle_7_62_scope': 'body', 'bolt_action_rifle_7_62_wrap': 'body',
            'bolt_action_rifle_7_62_trigger': 'body', 'bolt_action_rifle_7_62_bolt_a': 'bolt', 'bolt_action_rifle_7_62_bolt_b': 'bolt',
            'bolt_action_rifle_7_62_bullet_54mm': 'aux'}
    parts = gltf_parts('bolt_action_rifle_7_62', pick, fix)
    sight_y = -0.261 - grip.x
    empties = {'Sight': D(-0.007, sight_y, 0.071 - grip.z), 'Muzzle': D(0, 0.596 - grip.x, 0.045 - grip.z),
               'Ejector': D(0.02, -0.20 - grip.x, 0.05 - grip.z)}
    parts.setdefault('magazine', [])
    return parts, empties


def import_pistol():
    """P-12: Poly Haven service pistol, magazine seated in the grip."""
    grip = D(-0.02, 0.0, 0.032)
    fix = Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Translation(-grip)
    pick = {'service_pistol_pistol_a': 'body', 'service_pistol_hammer_a': 'body', 'service_pistol_trigger_a': 'body',
            'service_pistol_slide_a': 'bolt', 'service_pistol_magazine_loaded': 'magazine'}
    parts = gltf_parts('service_pistol', pick, fix)
    for o in parts['magazine']:
        o.matrix_world = fix @ Matrix.Translation(D(0.088, 0, 0)) @ fix.inverted() @ o.matrix_world
    empties = {'Sight': D(0, -0.03, 0.079 - grip.z + 0.004), 'Muzzle': D(0, 0.174 - grip.x, 0.062 - grip.z),
               'Ejector': D(0.012, 0.05, 0.07 - grip.z)}
    return parts, empties


def export_world_model(name, parts, empties):
    """Third-person weapon: gun meshes only, weapon space, Muzzle marker."""
    bpy.ops.object.select_all(action='DESELECT')
    objs = [o for group in parts.values() for o in group]
    for o in objs:
        o.select_set(True)
    m = bpy.data.objects.new('Muzzle', None); bpy.context.scene.collection.objects.link(m)
    m.location = empties['Muzzle']; m.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f'world_{name}.glb'), export_format='GLB', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=85, export_animations=False)
    bpy.data.objects.remove(m, do_unlink=True)


def place_weapon(rig, parts, empties, hip_matrix):
    for group, objs in parts.items():
        bone = 'weapon' if group == 'body' else group
        for o in objs:
            o.matrix_world = hip_matrix @ o.matrix_world
            mw = o.matrix_world.copy()
            o.parent = rig; o.parent_type = 'BONE'; o.parent_bone = bone
            o.matrix_world = mw
    for name, local in empties.items():
        e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e)
        e.empty_display_size = 0.01
        e.matrix_world = hip_matrix @ Matrix.Translation(local)
        mw = e.matrix_world.copy(); e.parent = rig; e.parent_type = 'BONE'; e.parent_bone = 'weapon'; e.matrix_world = mw


def render_preview(path, frame=0, side=False):
    scn = bpy.context.scene
    cam = bpy.data.objects.get('PreviewCam')
    if not cam:
        cam = bpy.data.objects.new('PreviewCam', bpy.data.cameras.new('PreviewCam'))
        scn.collection.objects.link(cam)
        cam.rotation_euler = (math.radians(90), 0, 0)
        cam.data.sensor_fit = 'VERTICAL'; cam.data.angle = math.radians(52); cam.data.clip_start = 0.01
        sun = bpy.data.objects.new('PreviewSun', bpy.data.lights.new('PreviewSun', 'SUN'))
        sun.data.energy = 3.5; sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(-30))
        scn.collection.objects.link(sun)
        w = bpy.data.worlds.new('W'); w.use_nodes = True
        w.node_tree.nodes['Background'].inputs[0].default_value = (0.42, 0.47, 0.52, 1)
        scn.world = w
    if side:
        cam.location = D(-0.95, 0.25, 0.05); cam.rotation_euler = (math.radians(95), 0, math.radians(-70)); cam.data.angle = math.radians(60)
    else:
        cam.location = D(0, 0, 0); cam.rotation_euler = (math.radians(90), 0, 0); cam.data.angle = math.radians(52)
    scn.camera = cam; scn.frame_set(frame)
    scn.render.engine = 'CYCLES'; scn.cycles.samples = 12; scn.cycles.device = 'CPU'
    scn.render.resolution_x = 960; scn.render.resolution_y = 540; scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ animation
def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


class Track:
    """Keys per channel; values interpolate with smoothstep between the keys that set them."""
    def __init__(self, keys):
        self.keys = sorted(keys, key=lambda k: k['t'])
        self.length = self.keys[-1]['t']

    def sample(self, channel, t, default=None):
        ks = [k for k in self.keys if channel in k]
        if not ks:
            return default, default, 0.0
        if t <= ks[0]['t']:
            return ks[0][channel], ks[0][channel], 0.0
        for a, b in zip(ks, ks[1:]):
            if a['t'] <= t <= b['t']:
                ease = b.get('ease', 'smooth')
                x = (t - a['t']) / max(1e-6, b['t'] - a['t'])
                x = smooth(x) if ease == 'smooth' else (x if ease == 'linear' else (1 - (1 - x) ** 3 if ease == 'out' else x ** 3))
                return a[channel], b[channel], x
        return ks[-1][channel], ks[-1][channel], 0.0


def blend_matrix(m0, m1, x):
    l = m0.translation.lerp(m1.translation, x)
    q = m0.to_quaternion().slerp(m1.to_quaternion(), x)
    m = q.to_matrix().to_4x4(); m.translation = l
    return m


class Poser:
    def __init__(self, rig, spec, hip):
        self.rig, self.spec, self.hip = rig, spec, hip
        self.hand_local = {}
        self.curls = {}
        hold = spec['mag_hold']
        self.hold_inv = (Matrix.Translation(hold[0]) @ target_matrix(rig, 'L', D(0, 0, 0), hold[1], hold[2])).inverted()

    def weapon(self, value):
        loc, rot = value
        return self.hip @ Matrix.Translation(loc) @ euler(*rot)

    def hand(self, side, value, weapon_m, mag_m):
        space, wrist, f, p = value[:4]
        local = Matrix.Translation(wrist) @ target_matrix(self.rig, side, D(0, 0, 0), f, p)
        if space == 'weapon':
            return weapon_m @ local
        if space == 'mag':
            return mag_m @ local
        return local  # camera space

    def evaluate(self, track, t, rest_mag):
        w0, w1, x = track.sample('w', t, (D(0, 0, 0), D(0, 0, 0)))
        weapon_m = blend_matrix(self.weapon(w0), self.weapon(w1), x)
        out = {'weapon': weapon_m}
        # Magazine before hands so a hand can be keyed relative to it.
        m0, m1, x = track.sample('mag', t, ('weapon', D(0, 0, 0), D(0, 0, 0)))
        def mag_world(v, hands):
            space, loc, rot = v
            if space == 'L' and loc == 'hold':
                return hands['L'] @ self.hold_inv
            local = Matrix.Translation(loc) @ euler(*rot)
            if space == 'weapon':
                return weapon_m @ rest_mag @ local
            if space == 'L':
                return hands['L'] @ local
            return local
        # Hands first need a magazine estimate for 'mag' space: use the weapon-space mag.
        provisional = weapon_m @ rest_mag
        hands = {}
        curls = {}
        for side, default_key in (('R', 'grip'), ('L', 'support')):
            v0, v1, xh = track.sample(side, t, ('weapon',) + self.spec[default_key] + (default_key,))
            hands[side] = blend_matrix(self.hand(side, v0, weapon_m, provisional), self.hand(side, v1, weapon_m, provisional), xh)
            c0 = self.curls.get((side, v0[4] if len(v0) > 4 else 'relax'), RELAX)
            c1 = self.curls.get((side, v1[4] if len(v1) > 4 else 'relax'), RELAX)
            curls[side] = {k: c0.get(k, 0.4) + (c1.get(k, 0.4) - c0.get(k, 0.4)) * xh for k in RELAX}
        out['curl'] = curls
        out['mag'] = blend_matrix(mag_world(m0, hands), mag_world(m1, hands), x)
        out['hands'] = hands
        b0, b1, x = track.sample('bolt', t, 0.0)
        out['bolt'] = b0 + (b1 - b0) * x
        r0, r1, x = track.sample('boltrot', t, 0.0)
        out['boltrot'] = r0 + (r1 - r0) * x
        a0, a1, x = track.sample('aux', t, ('hidden', None, None))
        def aux_world(v):
            if v[0] == 'L':
                return hands['L'] @ Matrix.Translation(v[1]) @ euler(*v[2])
            if v[0] == 'weapon':
                return weapon_m @ Matrix.Translation(v[1]) @ euler(*v[2])
            return Matrix.Translation(D(0, -2, -2))
        out['aux_m'] = blend_matrix(aux_world(a0), aux_world(a1), x) if a0[0] != 'hidden' or a1[0] != 'hidden' else aux_world(a0)
        return out


def rifle_tracks(spec, empty_reload=False):
    W0 = (D(0, 0, 0), D(0, 0, 0))
    G = ('weapon',) + spec['grip'] + ('grip',); S = ('weapon',) + spec['support'] + ('support',)
    mag_hold = ('mag', D(-0.005, 0.02, -0.12), D(0.2, 0.75, 0.35), D(0.95, 0.0, 0.3))
    tracks = {}
    tracks['idle'] = Track([{'t': 0, 'w': W0}, {'t': 1.0, 'w': W0}])
    tracks['draw'] = Track([
        {'t': 0.0, 'w': (D(0.02, -0.06, -0.2), D(-40, 0, 18)), 'cL': 0.4},
        {'t': 0.38, 'w': (D(0, 0.004, 0.004), D(3, 0, -1.5)), 'ease': 'out'},
        {'t': 0.55, 'w': W0, 'cL': 0.7}])
    SP = (D(-0.035, -0.02, 0.005), D(-12, -28, 22))
    tracks['sprint'] = Track([{'t': 0, 'w': SP, 'cL': 0.75}, {'t': 1.0, 'w': SP, 'cL': 0.75}])
    tilt = (D(-0.02, 0.0, 0.02), D(6, 22, -10))
    hw, hf, hp = spec['mag_hold']
    def held(dz=0.0, dy=0.0):
        return ('weapon', hw + D(0, dy, dz), hf, hp, 'mag')
    HOLD = ('L', 'hold', None)
    REST = ('weapon', D(0, 0, 0), D(0, 0, 0))
    out_low = ('cam', D(-0.2, 0.15, -0.62), D(0.3, 0.6, 0.5), D(0.9, 0, 0.3))
    keys = [
        {'t': 0.0, 'w': W0, 'L': S, 'mag': REST, 'cL': 0.7, 'bolt': 1.0 if empty_reload else 0.0},
        {'t': 0.22, 'w': tilt, 'L': held(-0.07, -0.02), 'cL': 0.3, 'mag': REST},
        {'t': 0.36, 'L': held(), 'cL': 0.85, 'mag': REST},
        {'t': 0.38, 'mag': HOLD},
        {'t': 0.52, 'L': held(-0.07), 'ease': 'in'},
        {'t': 0.80, 'L': out_low, 'ease': 'in'},
        {'t': 1.02, 'L': out_low},
        {'t': 1.28, 'L': held(-0.06, 0.004), 'ease': 'out'},
        {'t': 1.40, 'L': held(), 'w': (D(-0.02, 0.0, 0.026), D(7, 22, -10))},
        {'t': 1.42, 'mag': HOLD},
        {'t': 1.44, 'mag': REST},
        {'t': 1.50, 'L': held(0.004), 'w': (D(-0.02, 0.0, 0.03), D(8, 22, -10)), 'cL': 0.5},
        {'t': 1.58, 'L': held(-0.02), 'w': tilt},
    ]
    end = 2.2
    if empty_reload:
        keys += [
            {'t': 1.72, 'L': ('weapon', D(-0.045, 0.02, -0.01), D(0.1, 0.9, -0.2), D(0.98, 0, 0.1)), 'cL': 0.2},
            {'t': 1.82, 'L': ('weapon', D(-0.04, 0.02, -0.005), D(0.1, 0.9, -0.2), D(0.98, 0, 0.1)), 'bolt': 1.0},
            {'t': 1.88, 'bolt': 0.0, 'ease': 'linear', 'w': (D(-0.02, 0.008, 0.02), D(8, 20, -9))},
        ]
        end = 2.55
    keys += [
        {'t': end - 0.4, 'L': S, 'cL': 0.7, 'w': (D(0, 0, -0.005), D(-2, 4, -2))},
        {'t': end, 'w': W0, 'L': S},
    ]
    tracks['reload_empty' if empty_reload else 'reload'] = Track(keys)
    return tracks


def common_tracks(spec, sprint, draw_from):
    W0 = (D(0, 0, 0), D(0, 0, 0))
    return {
        'idle': Track([{'t': 0, 'w': W0}, {'t': 1.0, 'w': W0}]),
        'draw': Track([{'t': 0.0, 'w': draw_from, 'cL': 0.4}, {'t': 0.36, 'w': (D(0, 0.004, 0.004), D(3, 0, -1.5)), 'ease': 'out'}, {'t': 0.52, 'w': W0, 'cL': spec.get('curl_L', 0.7)}]),
        'sprint': Track([{'t': 0, 'w': sprint, 'cL': 0.75}, {'t': 1.0, 'w': sprint, 'cL': 0.75}]),
    }


def pistol_tracks(spec, empty_reload=False):
    W0 = (D(0, 0, 0), D(0, 0, 0))
    G = ('weapon',) + spec['grip'] + ('grip',); S = ('weapon',) + spec['support'] + ('support',)
    tracks = common_tracks(spec, (D(-0.02, -0.05, -0.05), D(-30, -8, 16)), (D(0.0, -0.05, -0.22), D(-50, 0, 10)))
    hw, hf, hp = spec['mag_hold']
    def held(dz=0.0):
        return ('weapon', hw + D(0, 0, dz), hf, hp, 'mag')
    out_low = ('cam', D(-0.16, 0.18, -0.55), D(0.3, 0.6, 0.5), D(0.9, 0, 0.3))
    REST = ('weapon', D(0, 0, 0), D(0, 0, 0)); HOLD = ('L', 'hold', None)
    tilt = (D(-0.03, 0.0, 0.03), D(10, 25, -12))
    keys = [
        {'t': 0.0, 'w': W0, 'L': S, 'mag': REST, 'bolt': 1.0 if empty_reload else 0.0},
        {'t': 0.18, 'w': tilt, 'L': out_low, 'mag': REST},
        # The spent magazine drops free under gravity.
        {'t': 0.22, 'mag': REST},
        {'t': 0.45, 'mag': ('weapon', D(0.0, -0.02, -0.5), D(-30, 0, 20)), 'ease': 'in'},
        {'t': 0.62, 'L': held(-0.09), 'mag': HOLD, 'ease': 'out'},
        {'t': 0.80, 'L': held(), 'w': (D(-0.03, 0.0, 0.034), D(11, 25, -12))},
        {'t': 0.82, 'mag': HOLD},
        {'t': 0.84, 'mag': REST, 'w': tilt},
    ]
    end = 1.25
    if empty_reload:
        keys += [{'t': 0.98, 'w': (D(-0.03, 0.0, 0.02), D(6, 25, -12))}, {'t': 1.02, 'bolt': 1.0}, {'t': 1.06, 'bolt': 0.0, 'ease': 'linear', 'w': (D(-0.03, 0.006, 0.02), D(4, 22, -12))}]
        end = 1.45
    keys += [{'t': end - 0.25, 'L': S, 'w': (D(0, 0, -0.004), D(-2, 3, -2))}, {'t': end, 'w': W0, 'L': S}]
    tracks['reload_empty' if empty_reload else 'reload'] = Track(keys)
    return tracks


def sniper_tracks(spec, empty_reload=False):
    W0 = (D(0, 0, 0), D(0, 0, 0))
    G = ('weapon',) + spec['grip'] + ('grip',); S = ('weapon',) + spec['support'] + ('support',)
    tracks = common_tracks(spec, (D(-0.04, -0.03, 0.0), D(-12, -26, 22)), (D(0.02, -0.08, -0.2), D(-40, 0, 18)))
    knob = spec['bolt_knob']
    handle = ('weapon', knob[0], knob[1], knob[2], 'knob')
    def at_knob(dy=0.0, dz=0.0):
        return ('weapon', knob[0] + D(0, dy, dz), knob[1], knob[2], 'knob')
    # Bolt cycle: lift, draw back, drive forward, lock down, back to the wrist.
    tracks['cycle'] = Track([
        {'t': 0.0, 'w': W0, 'R': G, 'cR': 0.85, 'iR': 0.25, 'bolt': 0.0, 'boltrot': 0.0},
        {'t': 0.14, 'R': handle, 'w': (D(0.01, -0.01, -0.012), D(-3, 14, 4))},
        {'t': 0.24, 'R': at_knob(0, 0.02), 'boltrot': 62.0},
        {'t': 0.40, 'R': at_knob(-0.09, 0.02), 'bolt': 2.0, 'ease': 'out'},
        {'t': 0.54, 'R': at_knob(0, 0.02), 'bolt': 0.0, 'ease': 'in'},
        {'t': 0.64, 'R': handle, 'boltrot': 0.0},
        {'t': 0.82, 'R': G, 'cR': 0.85, 'iR': 0.25, 'w': W0},
        {'t': 0.9, 'w': W0}])
    clip_at_port = ('weapon', D(0.0, -0.17, 0.12), D(0, 0, 0))
    port = ('weapon', D(-0.02, -0.25, 0.08), D(0.6, 0.4, -0.7), D(0.6, -0.1, -0.8))
    out_low = ('cam', D(-0.16, 0.15, -0.6), D(0.3, 0.6, 0.5), D(0.9, 0, 0.3))
    tilt = (D(-0.02, 0.0, 0.02), D(4, -18, -8))
    keys = [
        {'t': 0.0, 'w': W0, 'R': G, 'L': S, 'bolt': 0.0, 'boltrot': 0.0, 'aux': ('hidden', None, None)},
        {'t': 0.25, 'w': tilt, 'R': at_knob(0, 0.02), 'boltrot': 62.0, 'cR': 0.55},
        {'t': 0.42, 'R': at_knob(-0.09, 0.02), 'bolt': 2.0},
        {'t': 0.50, 'L': out_low},
        {'t': 0.80, 'L': out_low, 'aux': ('L', D(0.02, 0.08, 0.03), D(0, 0, 90))},
        {'t': 1.05, 'L': port, 'aux': ('L', D(0.02, 0.08, 0.03), D(0, 0, 90))},
        {'t': 1.35, 'L': ('weapon', D(-0.02, -0.25, 0.04), D(0.6, 0.4, -0.7), D(0.6, -0.1, -0.8)), 'w': (D(-0.02, 0.0, 0.012), D(5, -18, -8))},
        {'t': 1.40, 'aux': ('hidden', None, None)},
        {'t': 1.55, 'L': S, 'w': tilt},
        {'t': 1.70, 'R': at_knob(0, 0.02), 'bolt': 0.0, 'ease': 'in'},
        {'t': 1.82, 'R': handle, 'boltrot': 0.0},
        {'t': 2.05, 'R': G, 'cR': 0.85, 'w': (D(0, 0, -0.004), D(-2, 3, -2))},
        {'t': 2.35, 'w': W0}]
    tracks['reload'] = Track(keys)
    return tracks


def apply_frame(rig, targets, state):
    pb = rig.pose.bones
    pb['weapon'].matrix = state['weapon']
    pb['magazine'].matrix = state['mag']
    bpy.context.view_layer.update()
    pb['bolt'].location = D(0, -0.045 * state['bolt'], 0)
    pb['bolt'].rotation_quaternion = Quaternion(D(0, 1, 0), math.radians(state['boltrot']))
    pb['aux'].matrix = state['aux_m']
    for side in 'LR':
        targets[side].matrix_world = state['hands'][side]
    curl(rig, 'R', state['curl']['R'])
    curl(rig, 'L', state['curl']['L'])


def key_all(rig, targets, frame):
    for name in ('weapon', 'magazine', 'bolt', 'aux'):
        b = rig.pose.bones[name]
        b.keyframe_insert('location', frame=frame); b.keyframe_insert('rotation_quaternion', frame=frame)
    for b in rig.pose.bones:
        if b.name.startswith(('f_', 'thumb')):
            b.keyframe_insert('rotation_quaternion', frame=frame)
    for t in targets.values():
        t.keyframe_insert('location', frame=frame); t.keyframe_insert('rotation_euler', frame=frame)


def build(name, spec):
    clear_scene()
    CURL_AXES.clear()
    rig, body = load_arms()
    scn = bpy.context.scene; scn.render.fps = FPS
    cut_forearms(rig, body)
    glove = image_material('Gloves', os.path.join(TEX, 'glove_tactical_albedo.jpg'), os.path.join(TEX, 'glove_tactical_normal.jpg'), 0.82, normal_strength=0.8)
    body.data.materials.clear(); body.data.materials.append(glove)
    camo = image_material('Sleeves', os.path.join(TEX, 'sleeve_camo_albedo.jpg'), os.path.join(TEX, 'fabric_canvas_normal.jpg'), 0.9)
    for side in 'LR':
        sleeve(rig, side, 'forearm', 0.047, 0.036, cuff=True).data.materials.append(camo)
        sleeve(rig, side, 'upper_arm', 0.055, 0.05).data.materials.append(camo)
    loc, rot = spec['hip']
    hip = Matrix.Translation(loc) @ euler(*rot)
    add_weapon_bones(rig, hip, spec.get('bolt_axis', D(0, 0, 0)))
    parts, empties = spec['import']()
    os.makedirs(OUT, exist_ok=True)
    export_world_model(name, parts, empties)
    place_weapon(rig, parts, empties, hip)
    targets = setup_ik(rig)
    for pbone in rig.pose.bones:
        pbone.rotation_mode = 'QUATERNION'
    for t in targets.values():
        t.rotation_mode = 'XYZ'
    poser = Poser(rig, spec, hip)
    # Grip solve: every finger closes until it meets the weapon surface.
    bvh = gun_bvh([o for group in parts.values() for o in group])
    contexts = [('R', 'grip', spec['grip'], {'f_index': 0.3}), ('L', 'support', spec['support'], None), ('L', 'mag', spec['mag_hold'], None)]
    if 'bolt_knob' in spec:
        contexts.append(('R', 'knob', spec['bolt_knob'], None))
    seated = {}
    for side, key, (contact, fdir, pnorm), fixed in contexts:
        # Seat the palm on the real surface: cast from outside along the palm normal.
        pn = (hip.to_3x3() @ pnorm).normalized()
        start = hip @ contact - pn * 0.12
        loc, nrm, idx, dist = bvh.ray_cast(start, pn, 0.25)
        if loc is not None:
            local = hip.inverted() @ (loc - pn * 0.002)
            print('SEAT', name, side, key, 'moved', round((local - contact).length * 1000), 'mm')
            contact = local
        else:
            print('SEAT', name, side, key, 'NO SURFACE')
        seated[(side, key)] = (contact, fdir, pnorm)
        m = hip @ target_matrix(rig, side, contact, fdir, pnorm)
        poser.curls[(side, key)] = solve_curl(rig, side, targets[side], m, bvh, fixed)
        hb = rig.pose.bones['hand.' + side]
        shoulder = rig.pose.bones['upper_arm.' + side].head
        reach = rig.data.bones['upper_arm.' + side].length + rig.data.bones['forearm.' + side].length
        bpy.context.view_layer.update()
        fb = rig.pose.bones['f_middle.01.' + side].head - hb.head
        want_f = (hip.to_3x3() @ fdir).normalized()
        palm_now = hb.head + (hb.matrix.to_3x3() @ rig.data.bones['hand.' + side].matrix_local.to_3x3().inverted()) @ palm_offset(rig, side)
        print('AXES', name, side, key, 'finger dir error', round(math.degrees(fb.angle(want_f)), 1), 'palm centre error', round((palm_now - hip @ contact).length * 1000), 'mm')
        print('REACH', name, side, key, 'wrist error', round((hb.head - m.translation).length * 1000), 'mm',
              'shoulder->target', round((m.translation - shoulder).length, 3), 'arm', round(reach, 3),
              'hand rot error', round(math.degrees((hb.matrix.to_3x3().to_quaternion().rotation_difference(m.to_3x3().to_quaternion())).angle), 1))
        print('GRIP', name, side, key, {k: round(v, 2) for k, v in poser.curls[(side, key)].items()})
    spec = dict(spec)
    spec['grip'] = seated[('R', 'grip')]; spec['support'] = seated[('L', 'support')]; spec['mag_hold'] = seated[('L', 'mag')]
    if ('R', 'knob') in seated:
        spec['bolt_knob'] = seated[('R', 'knob')]
    poser.spec = spec
    hold = spec['mag_hold']
    poser.hold_inv = (Matrix.Translation(hold[0]) @ target_matrix(rig, 'L', D(0, 0, 0), hold[1], hold[2])).inverted()
    if '--solve-only' in ARGS:
        targets['R'].matrix_world = hip @ target_matrix(rig, 'R', *spec['grip']); curl(rig, 'R', poser.curls[('R', 'grip')])
        targets['L'].matrix_world = hip @ target_matrix(rig, 'L', *spec['support']); curl(rig, 'L', poser.curls[('L', 'support')])
        bpy.context.view_layer.update()
        return
    if '--grips' in ARGS:
        for side, key, _unused, fixed in contexts:
            contact, fdir, pnorm = seated[(side, key)]
            other = 'L' if side == 'R' else 'R'
            targets[side].matrix_world = hip @ target_matrix(rig, side, contact, fdir, pnorm)
            curl(rig, side, poser.curls[(side, key)])
            okey = 'support' if other == 'L' else 'grip'
            targets[other].matrix_world = hip @ target_matrix(rig, other, *spec[okey])
            curl(rig, other, poser.curls[(other, okey)])
            if key == 'mag':
                pass
            bpy.context.view_layer.update()
            world_contact = hip @ contact
            for view, offset in (('eye', D(0, 0, 0)), ('left', D(-0.2, 0.02, -0.06)), ('right', D(0.2, 0.02, -0.08))):
                cam = bpy.data.objects.get('GripCam')
                if not cam:
                    cam = bpy.data.objects.new('GripCam', bpy.data.cameras.new('GripCam')); bpy.context.scene.collection.objects.link(cam)
                cam.location = offset if view == 'eye' else world_contact + offset
                cam.rotation_euler = (world_contact - cam.location).to_track_quat('-Z', 'Y').to_euler()
                cam.data.angle = math.radians(22 if view == 'eye' else 45); cam.data.clip_start = 0.005
                render_preview(f'/tmp/grip_{name}_{side}{key}_{view}.png')
                bpy.context.scene.camera = cam
                bpy.ops.render.render(write_still=True)
        if '--grips-only' in ARGS:
            return
    rest_mag = Matrix.Identity(4)
    tracks = {}
    for builder in spec['tracks']:
        tracks.update(builder(spec))
    rig.animation_data_create()
    baked = []
    for anim, track in tracks.items():
        for t in targets.values():
            t.animation_data_clear()
        action = bpy.data.actions.new(anim + '_src'); rig.animation_data.action = action
        frames = max(1, int(round(track.length * FPS)))
        for f in range(frames + 1):
            scn.frame_set(f)
            state = poser.evaluate(track, f / FPS, rest_mag)
            apply_frame(rig, targets, state)
            bpy.context.view_layer.update()
            key_all(rig, targets, f)
        # Bake IK into plain bone keys for export.
        bpy.context.view_layer.objects.active = rig
        for o in bpy.context.selected_objects:
            o.select_set(False)
        rig.select_set(True)
        bpy.ops.object.mode_set(mode='POSE')
        bpy.ops.pose.select_all(action='SELECT')
        bpy.ops.nla.bake(frame_start=0, frame_end=frames, only_selected=False, visual_keying=True,
                         clear_constraints=False, use_current_action=False, bake_types={'POSE'})
        bpy.ops.object.mode_set(mode='OBJECT')
        out_action = rig.animation_data.action
        out_action.name = anim
        out_action.use_fake_user = True
        baked.append(out_action)
        bpy.data.actions.remove(action)
        if PREVIEW and anim in ('idle', 'reload', 'reload_empty', 'cycle', 'sprint'):
            for frac in ((0.0,) if anim in ('idle', 'sprint') else (0.1, 0.25, 0.4, 0.55, 0.7, 0.85)):
                render_preview(f'/tmp/vm_{name}_{anim}_{int(frac*100)}.png', int(frames * frac))
                if '--side' in ARGS:
                    render_preview(f'/tmp/vm_{name}_{anim}_{int(frac*100)}_side.png', int(frames * frac), True)
    # Export: constraints and helper empties are not part of the runtime asset.
    for pbone in rig.pose.bones:
        for c in list(pbone.constraints):
            pbone.constraints.remove(c)
    for o in list(bpy.data.objects):
        if o.name.startswith(('IK.', 'Pole.', 'Preview')):
            bpy.data.objects.remove(o, do_unlink=True)
    rig.animation_data.action = bpy.data.actions['idle']
    for a in baked:
        track = rig.animation_data.nla_tracks.new(); track.name = a.name
        track.strips.new(a.name, 0, a); track.mute = True
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f'vm_{name}.glb'), export_format='GLB',
                              export_animations=True, export_animation_mode='NLA_TRACKS',
                              export_image_format='JPEG', export_jpeg_quality=90, export_def_bones=False,
                              export_optimize_animation_size=True)
    print('VIEWMODEL', name, 'animations', [a.name for a in baked])


for weapon, spec in WEAPONS.items():
    if ONLY and weapon not in ONLY:
        continue
    build(weapon, spec)
