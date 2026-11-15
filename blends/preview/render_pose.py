"""Render rig checks: walk frames (side), head turn, mouth open, blink.
blender -b <file.blend> -P blends/preview/render_pose.py -- <out_prefix>"""
import math, os, sys
import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
ob = next(o for o in sc.objects if o.type == "MESH"); arm = ob.parent
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading; sh.light = "STUDIO"; sh.color_type = "TEXTURE"
w = bpy.data.worlds.new("w"); w.color = (0.55, 0.6, 0.65); sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = "ORTHO"; sc.camera = cam

def shot(name, ang, scale, target, res=(500, 800)):
    scale = float(os.environ.get("SCALE", scale)); target = (target[0], target[1], float(os.environ.get("TZ_", target[2])))
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.data.ortho_scale = scale
    a = math.radians(ang)
    cam.location = Vector(target) + Vector((math.sin(a) * 5, -math.cos(a) * 5, 0))
    cam.rotation_euler = (math.radians(90), 0, a)
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)

def setact(n):
    for t in arm.animation_data.nla_tracks:
        t.mute = (t.name != n)

setact("walk-loop")
for f in (1, 4, 8, 12):   # start, ~1/4 .. contact poses
    sc.frame_set(f); shot(f"walk{f}", 90, 2.0, (0, 0, 0.95))
setact("head_turn")
sc.frame_set(20); shot("turnL", 0, 0.7, (0, 0, 1.65), (500, 500))
sc.frame_set(1)
keys = ob.data.shape_keys.key_blocks
keys["mouth_open"].value = 1.0; shot("mouth", 0, 0.45, (0, 0, 1.64), (500, 500)); keys["mouth_open"].value = 0
keys["blink"].value = 1.0; shot("blink", 0, 0.45, (0, 0, 1.64), (500, 500))
