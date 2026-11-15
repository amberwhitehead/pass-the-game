"""Render front/side/back/3-quarter turnaround of a .blend.  
blender -b <file.blend> -P blends/preview/render.py -- <out_prefix>"""
import math, os, sys
import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
ob = next(o for o in sc.objects if o.type == "MESH")
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_specular_highlight = True
sc.render.resolution_x = 500; sc.render.resolution_y = 800
sc.render.film_transparent = False
w = bpy.data.worlds.new("w"); w.color = (0.55, 0.6, 0.65); sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = "ORTHO"; cam.data.ortho_scale = float(os.environ.get("SCALE", 2.0)); sc.camera = cam
target = Vector((0, 0, float(os.environ.get("TZ_", 0.9))))
for name, ang in (("front", 0), ("q", 35), ("side", 90), ("back", 180)):
    a = math.radians(ang)
    cam.location = target + Vector((math.sin(a) * 5, -math.cos(a) * 5, 0))
    cam.rotation_euler = (math.radians(90), 0, a)
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
