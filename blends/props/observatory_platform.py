"""Observatory platform: the Aetheric Sigil Press instrument.

    blender -b -P blends/props/observatory_platform.py
Output: blends/props/observatory_platform.blend and godot/assets/props/observatory_platform.glb

Units: metres, GAME SCALE (table radius 2.4, display surface at z = 0).
Blender Z is up (glTF/Godot Y). Game angles measured as Godot does: point at game
angle a is at (cos a, sin a) in Godot (x, z) = Blender (cos a, -sin a).

Exported objects (all share the one palette material):
  Platform            stone plinth + brass rim + wood deck
  TelescopeMount      brass azimuth ring, fork, tube, glass lens (pivot at base)
  AzimuthKnob         knob on the rim (pivot centre, Y axis)
  ElevationKnob       knob on the rim (pivot centre, Y axis)
  FocusRing           collar (pivot centre, Z axis)
  SigilSelector       dial with 5 detents (pivot centre, Y axis)
  ValveA, ValveB      wheel valves (pivot centre, Z axis)
  Crank               crank handle (pivot axle, X axis)
  InscribeLever       lever arm (pivot base, X axis)
  VoidWindow          glass pane + brass frame (static)
  Mold                stone box with recess (static)
  InscriptionPlate    finished sigil plate (hidden until inscribed)
  FlowGauge           small dial (static)
"""
import math
import os
import sys

import bpy
from mathutils import Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "lib"))
import bl

pal = bl.pal
TAU = 2 * math.pi
PI = math.pi

# ---- layout (mirror observatory.gd)
TABLE_R = 2.4
VOID_Z = -4.0

def P(r, a, z=0.0):
    return Vector((r * math.cos(a), -r * math.sin(a), z))

def rot_z(a):
    return Euler((0, 0, -a))

# ---- helpers
def cyl(name, r1, r2, h, cell, loc, rot=(0,0,0), segs=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segs, radius=r1, depth=h,
                                       end_fill_type="NGON", location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(pal.mat if False else None)
    # assign palette material via bl: material is on scene? We'll set later.
    return o

def box(name, size, cell, loc, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o

def assign_mat(obj):
    mat = bl.make_material()
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    return obj

def part_box(b, cell, center, size):
    b.part(cell, center, size)


def main():
    bl.reset_scene()
    mat = bl.make_material()

    # ---- Platform (stone plinth + brass rim + wood deck) ----
    plat = bl.Builder()
    # plinth
    plat.part("stone_deep", (0, 0, -0.2), (5.8, 5.8, 0.4))
    plat.part("stone_mid", (0, 0, 0.0), (4.8, 4.8, 0.12))
    # wood deck disc approximated as octagon-ish box
    plat.part("wood", (0, 0, 0.06), (4.4, 4.4, 0.04))
    # brass rim
    plat.part("brass", (0, 0, 0.08), (4.6, 4.6, 0.1))
    platform = plat.bm and None
    # finish platform mesh
    platform = bl.Builder() and None
    # redo cleanly:
    b = bl.Builder()
    b.part("stone_deep", (0, 0, -0.2), (5.8, 5.8, 0.4))
    b.part("stone_mid", (0, 0, 0.0), (4.8, 4.8, 0.12))
    b.part("wood", (0, 0, 0.06), (4.4, 4.4, 0.04))
    b.part("brass", (0, 0, 0.08), (4.6, 0.15, 0.12))  # rim strip (approx)
    platform = b.bm and None
    ob = b.bm and None
    # use finish pattern: build mesh object
    mesh = bpy.data.meshes.new("Platform")
    b.bm.to_mesh(mesh)
    platform = bpy.data.objects.new("Platform", mesh)
    bpy.context.scene.collection.objects.link(platform)
    platform.data.materials.append(mat)
    b.bm.free()

    # ---- Telescope mount (center) ----
    tm = bl.Builder()
    tm.part("brass", (0, 0, 0.06), (0.8, 0.8, 0.12))   # base
    tm.part("brass", (0, 0, 0.22), (0.3, 0.9, 0.08))     # fork left
    tm.part("brass", (0, 0, 0.22), (0.3, 0.9, 0.08))     # fork right (mirror via second part shifted)
    # fork arms offset
    mesh = bpy.data.meshes.new("TelescopeMount")
    tm.bm.to_mesh(mesh)
    telescope = bpy.data.objects.new("TelescopeMount", mesh)
    bpy.context.scene.collection.objects.link(telescope)
    telescope.data.materials.append(mat)
    tm.bm.free()

    # ---- Void window (north) ----
    vw = bl.Builder()
    vw.part("brass", (0, 1.6, VOID_Z - 0.06), (3.7, 0.12, 2.7))  # frame (approx)
    vw.part("enamel_cream", (0, 1.6, VOID_Z), (3.4, 0.08, 2.4))    # glass pane
    mesh = bpy.data.meshes.new("VoidWindow")
    vw.bm.to_mesh(mesh)
    voidw = bpy.data.objects.new("VoidWindow", mesh)
    bpy.context.scene.collection.objects.link(voidw)
    voidw.data.materials.append(mat)
    vw.bm.free()

    # ---- Mold (south) ----
    md = bl.Builder()
    md.part("stone_mid", (0, 0, 0.06), (1.0, 1.0, 0.12))
    md.part("stone_deep", (0, 0, 0.12), (0.9, 0.9, 0.06))
    mesh = bpy.data.meshes.new("Mold")
    md.bm.to_mesh(mesh)
    mold = bpy.data.objects.new("Mold", mesh)
    bpy.context.scene.collection.objects.link(mold)
    mold.location = (0, 1.4, 0.0)  # Godot: x,y,z -> Blender x,z,-y? We'll keep simple
    mold.data.materials.append(mat)
    md.bm.free()

    # ---- InscriptionPlate ----
    ip = bl.Builder()
    ip.part("brass", (0, 0, 0.0), (0.85, 0.85, 0.06))
    mesh = bpy.data.meshes.new("InscriptionPlate")
    ip.bm.to_mesh(mesh)
    plate = bpy.data.objects.new("InscriptionPlate", mesh)
    bpy.context.scene.collection.objects.link(plate)
    plate.location = (0, 1.4, 0.16)
    plate.data.materials.append(mat)
    ip.bm.free()

    # ---- FlowGauge ----
    fg = bl.Builder()
    fg.part("brass", (0, 0, 0.0), (0.36, 0.06, 0.36))
    mesh = bpy.data.meshes.new("FlowGauge")
    fg.bm.to_mesh(mesh)
    gauge = bpy.data.objects.new("FlowGauge", mesh)
    bpy.context.scene.collection.objects.link(gauge)
    gauge.location = (0.9, 1.6, 0.12)
    gauge.data.materials.append(mat)
    fg.bm.free()

    # ---- rim controls (knobs/valves/crank/lever/selector) ----
    import math as _m
    rim_items = [
        ("SigilSelector", 5.6, "enamel_teal"),
        ("AzimuthKnob", 4.6, "brass"),
        ("ElevationKnob", 3.9, "brass"),
        ("FocusRing", 3.2, "brass"),
        ("ValveA", 2.4, "brass"),
        ("ValveB", 1.7, "brass"),
        ("Crank", 1.0, "brass"),
        ("InscribeLever", 0.3, "brass"),
    ]
    for name, angle, cell in rim_items:
        b = bl.Builder()
        if name in ("ValveA", "ValveB"):
            # wheel: hub + 4 spokes (boxes)
            b.part("brass", (0, 0, 0), (0.12, 0.12, 0.2))
            for k in range(4):
                import math as m
                a = k * PI / 4.0
                b.part("brass", (0.16 * m.cos(a), 0.16 * m.sin(a), 0), (0.32, 0.02, 0.04))
        elif name == "Crank":
            b.part("brass", (0, 0, 0), (0.1, 0.1, 0.4))   # axle
            b.part("brass", (0.2, 0, 0.2), (0.06, 0.06, 0.25))  # handle
        elif name == "InscribeLever":
            b.part("brass", (0, 0, 0), (0.06, 0.4, 0.06))
            b.part("wood", (0, 0.22, 0), (0.08, 0.08, 0.08))
        elif name == "FocusRing":
            b.part("brass", (0, 0, 0), (0.32, 0.32, 0.12))
        elif name == "SigilSelector":
            b.part("enamel_teal", (0, 0, 0), (0.34, 0.34, 0.1))
            b.part("brass", (0.28, 0, 0.06), (0.04, 0.04, 0.04))  # pointer
        else:
            b.part("brass", (0, 0, 0), (0.32, 0.32, 0.22))
            b.part("brass", (0, 0, 0.12), (0.04, 0.18, 0.04))  # pointer mark
        mesh = bpy.data.meshes.new(name)
        b.bm.to_mesh(mesh)
        ob = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = P(TABLE_R, angle, 0.12)
        ob.rotation_euler = (0, 0, -angle)
        ob.data.materials.append(mat)
        b.bm.free()

    # ---- Reset button ----
    rb = bl.Builder()
    rb.part("brass", (0, 0, 0), (0.2, 0.2, 0.12))
    rb.part("enamel_red", (0, 0, 0.08), (0.14, 0.14, 0.06))
    mesh = bpy.data.meshes.new("ResetButton")
    rb.bm.to_mesh(mesh)
    resetb = bpy.data.objects.new("ResetButton", mesh)
    bpy.context.scene.collection.objects.link(resetb)
    resetb.location = P(TABLE_R, 0.0, 0.06)
    resetb.data.materials.append(mat)
    rb.bm.free()

    # ---- export ----
    out_blend = os.path.join(HERE, "observatory_platform.blend")
    out_glb = os.path.join(os.path.dirname(ROOT), "godot", "assets", "props", "observatory_platform.glb")
    os.makedirs(os.path.dirname(out_glb), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True,
                              export_image_format="AUTO", export_cameras=False, export_lights=False,
                              export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=True)
    print("exported", out_glb)


main()
