"""Rig conventions shared by every character. Run inside Blender.

Skeleton (L = wearer's left = +X, R = -X). Rotations are authored in CHARACTER axes, so
every character animates the same way regardless of bone orientation:
  pitch: + swings the bone's far end FORWARD (-Y)    yaw: + turns toward wearer's left
  roll:  + tips the far end toward wearer's left

  root
   |- torso ---- head
   |        |--- upper_arm.L/R -- lower_arm.L/R   (lower_arm includes the hand)
   |- upper_leg.L/R -- lower_leg.L/R -- foot.L/R

Mesh: one object, every part rigidly weighted 100% to one bone (see bl.auto_bone).
Shape keys:  mouth_open, blink
Animations (NLA tracks; Godot recognises the "-loop" suffix and sets loop mode on import):
  idle-loop, walk-loop, talk-loop (mouth_open), blink, head_turn
"""
import math

import bpy
from mathutils import Matrix, Vector

FPS = 30

# name: (head, tail, parent) for the LEFT side or centre; ".R" copies are mirrored in x.
BONES = {
    "root":        ((0, 0, 0),         (0, 0, 0.15),         None),
    "torso":       ((0, 0, 0.95),      (0, 0, 1.45),         "root"),
    "head":        ((0, 0, 1.54),      (0, 0, 1.80),         "torso"),
    "upper_arm.L": ((0.225, 0, 1.46),  (0.25, 0, 1.18),      "torso"),
    "lower_arm.L": ((0.25, 0, 1.18),   (0.25, -0.03, 0.74),  "upper_arm.L"),
    "upper_leg.L": ((0.09, 0, 0.92),   (0.09, 0, 0.49),      "root"),
    "lower_leg.L": ((0.09, 0, 0.49),   (0.09, 0, 0.09),      "upper_leg.L"),
    "foot.L":      ((0.09, 0, 0.09),   (0.09, -0.16, 0.02),  "lower_leg.L"),
}


def _mirror(v):
    return (-v[0], v[1], v[2])


def attach(builder, ob, joints=None):
    bones = dict(BONES)
    if joints:
        bones.update(joints)
    full = {}
    for n, (h, t, p) in bones.items():
        full[n] = (h, t, p)
        if n.endswith(".L"):
            full[n[:-2] + ".R"] = (_mirror(h), _mirror(t), p[:-2] + ".R" if p and p.endswith(".L") else p)

    arm = _armature(full)
    # vertex groups: each part rigidly on one bone
    for n in full:
        ob.vertex_groups.new(name=n)
    for bone, tag, a, b, c in builder.ranges:
        ob.vertex_groups[bone].add(list(range(a, b)), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    _shape_keys(builder, ob)
    _actions(arm, ob)
    return arm


def _armature(full):
    a = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", a)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for n, (h, t, p) in full.items():
        e = a.edit_bones.new(n)
        e.head, e.tail = h, t
    for n, (h, t, p) in full.items():
        if p:
            a.edit_bones[n].parent = a.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _shape_keys(builder, ob):
    if not getattr(builder, "shapes", None):
        return
    ob.shape_key_add(name="Basis", from_mix=False)
    basis = [v.co.copy() for v in ob.data.vertices]
    for name, fns in builder.shapes:
        sk = ob.shape_key_add(name=name, from_mix=False)
        for bone, tag, a, b, c in builder.ranges:
            fn = fns.get(tag)
            if fn:
                for i in range(a, b):
                    sk.data[i].co = fn(basis[i], c)


# ---------------------------------------------------------------- animation
def _rest3(arm, name):
    return arm.data.bones[name].matrix_local.to_3x3()


def pose(arm, name, pitch=0.0, yaw=0.0, roll=0.0, loc=(0, 0, 0)):
    """Set pose bone `name` using character-axis rotation (degrees) and world-axis offset (m)."""
    pb = arm.pose.bones[name]
    m = _rest3(arm, name)
    r = (Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(roll), 3, "Y")
         @ Matrix.Rotation(math.radians(-pitch), 3, "X"))
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (m.inverted() @ r @ m).to_quaternion()
    pb.location = m.inverted() @ Vector(loc)


def _make_action(arm, name, frames):
    """frames: {frame: {bone: dict(pitch=,yaw=,roll=,loc=)}}. Unlisted bones rest at identity."""
    used = sorted({b for f in frames.values() for b in f})
    arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for f in sorted(frames):
        for b in arm.pose.bones:
            pose(arm, b.name)
        for b, kw in frames[f].items():
            pose(arm, b, **kw)
        for b in used:
            pb = arm.pose.bones[b]
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    for b in arm.pose.bones:
        pose(arm, b.name)
    _push(arm.animation_data, act, name)
    return act


def _push(ad, act, name):
    """One NLA track per animation, named after it. The glTF exporter merges same-named
    tracks from the skeleton and the shape keys into a single animation."""
    track = ad.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    ad.action = None


def _key_action(ob, name, frames):
    """frames: {frame: {shape_key: value}} on the mesh's shape keys."""
    key = ob.data.shape_keys
    key.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    key.animation_data.action = act
    for f in sorted(frames):
        for k, v in frames[f].items():
            key.key_blocks[k].value = v
            key.key_blocks[k].keyframe_insert("value", frame=f)
    for kb in key.key_blocks:
        kb.value = 0.0
    _push(key.animation_data, act, name)
    return act


def _actions(arm, ob):
    bpy.context.scene.render.fps = FPS
    S = math.sin
    # ---- walk: 1 s cycle, 2 steps. Legs/arms swing opposite, knees bend on the forward swing.
    walk = {}
    N = 30
    for f in range(0, N + 1, 3):
        ph = 2 * math.pi * f / N
        A, K, B = 26, 38, 20
        legL, legR = A * S(ph), -A * S(ph)
        kneeL = K * max(0.0, math.cos(ph)) ** 1.5
        kneeR = K * max(0.0, -math.cos(ph)) ** 1.5
        armL, armR = -B * S(ph), B * S(ph)
        walk[f + 1] = {
            "torso":       dict(yaw=5 * S(ph), loc=(0, 0, 0.012 * (1 - math.cos(2 * ph)) / 2 - 0.006)),
            "head":        dict(yaw=-4 * S(ph)),
            "upper_leg.L": dict(pitch=legL),  "upper_leg.R": dict(pitch=legR),
            "lower_leg.L": dict(pitch=-kneeL), "lower_leg.R": dict(pitch=-kneeR),
            "foot.L":      dict(pitch=-0.3 * legL + 0.4 * kneeL), "foot.R": dict(pitch=-0.3 * legR + 0.4 * kneeR),
            "upper_arm.L": dict(pitch=armL),  "upper_arm.R": dict(pitch=armR),
            "lower_arm.L": dict(pitch=14 + 8 * max(0, S(ph + math.pi))), "lower_arm.R": dict(pitch=14 + 8 * max(0, S(ph))),
        }
    _make_action(arm, "walk-loop", walk)

    # ---- idle: 2 s breathing sway
    idle = {}
    for f in range(0, 61, 10):
        ph = 2 * math.pi * f / 60
        idle[f + 1] = {
            "torso": dict(loc=(0, 0, 0.004 * S(ph)), pitch=0.6 * S(ph)),
            "head": dict(pitch=-0.8 * S(ph), yaw=1.0 * S(ph * 0.5)),
            "upper_arm.L": dict(roll=1.0 * S(ph)), "upper_arm.R": dict(roll=-1.0 * S(ph)),
        }
    _make_action(arm, "idle-loop", idle)

    # ---- head turn: look left, back through centre, look right, return (3 s)
    turn = {1: 0, 20: 40, 40: 0, 55: -40, 75: 0, 90: 0}
    _make_action(arm, "head_turn", {f: {"head": dict(yaw=y * 0.9, pitch=0), "torso": dict(yaw=y * 0.1)}
                                    for f, y in turn.items()})

    # ---- shape-key actions
    if ob.data.shape_keys:
        names = [k.name for k in ob.data.shape_keys.key_blocks]
        if "mouth_open" in names:
            talk = {1: 0, 4: 1.0, 8: 0.2, 11: 0.8, 15: 0.0, 18: 0.6, 21: 0.1, 24: 0.9, 28: 0.0, 31: 0.0}
            _key_action(ob, "talk-loop", {f: {"mouth_open": v} for f, v in talk.items()})
        if "blink" in names:
            _key_action(ob, "blink", {1: {"blink": 0}, 3: {"blink": 1.0}, 5: {"blink": 1.0}, 8: {"blink": 0}})
