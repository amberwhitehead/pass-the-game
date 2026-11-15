"""Review renders of the Newton platform from the game camera and the room camera.
blender -b blends/props/newton_platform.blend -P blends/preview/render_platform.py -- <out_prefix> [views...]
views: game_<deg> (minigame camera: r=5.4 h=3.8, fov 58, deg = game angle), room_<deg> (eye height, platform
scaled x0.4 as in the room), top, side, close_<deg>_<r>_<z> (zoom on a spot).  Default: game_250 game_60 room_20 room_200 top"""
import math, sys
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, views = args[0], (args[1:] or ["game_250", "game_60", "room_20", "room_200", "top"])
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE" if "--eevee" in sys.argv else "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_specular_highlight = True
sh.show_backface_culling = True   # catches faces with flipped normals
sh.show_cavity = True; sh.cavity_type = "BOTH"
sc.render.resolution_x, sc.render.resolution_y = 1280, 800
w = bpy.data.worlds.new("w"); w.color = (0.5, 0.55, 0.6); sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam


def look(pos, tgt, fov=58.0):
    cam.data.type = "PERSP"; cam.data.angle = math.radians(fov)
    cam.location = pos
    cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()


def P(r, a, z): return Vector((r * math.cos(a), -r * math.sin(a), z))


for v in views:
    p = v.split("_")
    if p[0] == "game":
        look(P(5.4, math.radians(float(p[1])), 3.8), (0, 0, -0.3))
    elif p[0] == "room":   # player ~2.6 m from the platform edge at 1.7 m eye height, platform scale 0.4
        s = 1 / 0.4
        look(P(3.9 + 2.6 * s, math.radians(float(p[1])), 1.7 * s - 1.0 * s), (0, 0, -1.0), 70)
    elif p[0] == "top":
        look((0, 0, 11), (0, 0, 0), 40); cam.rotation_euler = (0, 0, 0)
    elif p[0] == "side":
        look((0, -14, -1.2), (0, 0, -1.2), 30)
    elif p[0] == "close":
        a, r, z = math.radians(float(p[1])), float(p[2]), float(p[3])
        t = P(r, a, z)
        d, h = (float(p[4]), float(p[5])) if len(p) > 5 else (1.4, 0.8)   # optional: distance outward, height
        look(t + P(d, a, h), t, float(p[6]) if len(p) > 6 else 50)
    sc.render.filepath = f"{out}_{v}.png"
    bpy.ops.render.render(write_still=True)
