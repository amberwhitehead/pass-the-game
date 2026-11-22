"""Observatory platform: the Aetheric Sigil Press instrument.

    blender -b -P blends/props/observatory_platform.py
Output: blends/props/observatory_platform.blend and godot/assets/props/observatory_platform.glb

Units: metres, GAME SCALE (table radius 2.4, display surface at z = 0).
Blender Z is up (glTF/Godot Y). Game angles measured as Godot does.

Exported objects (all share the one palette material, per-face cell indices):
  Platform            stone plinth + brass rim + wood deck + brass frame
  TelescopeMount      brass azimuth ring, fork, tube, glass lens (pivot at base)
  AzimuthKnob         large brass cylinder knob with knurled edge
  ElevationKnob       brass knob
  FocusRing           brass ring with glass lens centre
  SigilSelector       enamel dial with 5 detent notches + pointer
  ValveA, ValveB      brass wheel valves with spokes (copper accents)
  Crank               brass axle + arm + wooden ball handle
  InscribeLever       brass arm + wooden grip (pivot at base)
  VoidWindow          brass frame + glass pane (north)
  Mold                stone box with brass recess
  InscriptionPlate    brass plate (hidden until inscribed)
  FlowGauge           brass bezel + enamel face + needle
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
from blocks import (P, cylinder, rod, gear, prism)

pal = bl.pal
TAU = 2 * math.pi
PI = math.pi

TABLE_R = 2.4
VOID_Z = -4.0


def finish_builder(b, name):
    mesh = bpy.data.meshes.new(name)
    b.bm.to_mesh(mesh)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(bl.make_material())
    b.bm.free()
    return ob


def main():
    bl.reset_scene()

    # ---- Platform: stone plinth + brass frame + wood deck ----
    b = bl.Builder()
    # plinth
    b.part("stone_deep", (0, 0, -0.22), (6.0, 6.0, 0.44))
    b.part("stone_mid", (0, 0, 0.0), (5.0, 5.0, 0.14))
    # wood deck disc (octagonal-ish via box)
    b.part("wood", (0, 0, 0.07), (4.6, 4.6, 0.06))
    # brass rim strip (4 sides)
    b.part("brass", (0, 2.35, 0.09), (4.7, 0.18, 0.12))
    b.part("brass", (0, -2.35, 0.09), (4.7, 0.18, 0.12))
    b.part("brass", (2.35, 0, 0.09), (0.18, 4.7, 0.12))
    b.part("brass", (-2.35, 0, 0.09), (0.18, 4.7, 0.12))
    platform = finish_builder(b, "Platform")

    # ---- Void window (north): brass frame + glass pane ----
    b = bl.Builder()
    b.part("brass", (0, 1.6, VOID_Z - 0.08), (3.9, 0.16, 2.9))   # frame outer
    b.part("brass", (0, 1.6, VOID_Z - 0.08), (3.5, 0.2, 2.5))    # frame inner (cutout feel)
    b.part("enamel_cream", (0, 1.6, VOID_Z), (3.4, 0.06, 2.4))    # glass pane
    voidw = finish_builder(b, "VoidWindow")
    voidw.location = (0, 0, 0)

    # ---- Telescope mount (center, pointing north) ----
    b = bl.Builder()
    b.part("brass", (0, 0, 0.06), (0.9, 0.9, 0.14))              # base
    b.part("brass", (0, 0, 0.2), (0.12, 0.9, 0.08))               # fork left
    b.part("brass", (0, 0, 0.2), (0.12, 0.9, 0.08))               # fork right (will offset via second part)
    # fork arms offset manually as separate boxes
    b.part("brass", (-0.22, 0, 0.35), (0.08, 0.08, 0.6))
    b.part("brass", (0.22, 0, 0.35), (0.08, 0.08, 0.6))
    b.part("gunmetal", (0, 0, 0.7), (0.16, 0.16, 1.0))            # tube
    b.part("enamel_cream", (0, 0, 1.25), (0.2, 0.06, 0.2))        # lens
    # azimuth ring (cylinder)
    cylinder(b, "brass", 0.5, 0.16, 0.2, n=16)
    telescope = finish_builder(b, "TelescopeMount")

    # ---- Mold (south side) ----
    b = bl.Builder()
    b.part("stone_mid", (0, 0, 0.06), (1.1, 1.1, 0.14))
    b.part("stone_deep", (0, 0, 0.14), (0.95, 0.95, 0.08))
    b.part("brass", (0, 0, 0.18), (0.9, 0.9, 0.04))               # recess rim
    mold = finish_builder(b, "Mold")
    mold.location = (0, 1.4, 0)

    # ---- InscriptionPlate ----
    b = bl.Builder()
    b.part("brass", (0, 0, 0), (0.85, 0.85, 0.06))
    b.part("glow_amber", (0, 0, 0.04), (0.6, 0.6, 0.02))          # sigil etch
    plate = finish_builder(b, "InscriptionPlate")
    plate.location = (0, 1.4, 0.16)

    # ---- FlowGauge ----
    b = bl.Builder()
    b.part("brass", (0, 0, 0), (0.36, 0.06, 0.36))
    b.part("enamel_cream", (0, 0, 0.03), (0.3, 0.02, 0.3))
    b.part("enamel_red", (0.1, 0, 0.05), (0.02, 0.02, 0.2))       # needle
    gauge = finish_builder(b, "FlowGauge")
    gauge.location = (0.9, 1.6, 0.12)
    gauge.rotation_euler = (PI / 2, 0, 0)

    # ---- rim controls ----
    rim_items = [
        ("SigilSelector", 5.6, "dial"),
        ("AzimuthKnob", 4.6, "knob"),
        ("ElevationKnob", 3.9, "knob"),
        ("FocusRing", 3.2, "ring"),
        ("ValveA", 2.4, "valve"),
        ("ValveB", 1.7, "valve"),
        ("Crank", 1.0, "crank"),
        ("InscribeLever", 0.3, "lever"),
    ]
    for name, angle, kind in rim_items:
        b = bl.Builder()
        if kind == "valve":
            # hub
            b.part("brass", (0, 0, 0), (0.12, 0.12, 0.2))
            # wheel rim (torus via cylinder hollow? use 4 box spokes + outer ring boxes)
            for k in range(6):
                a = k * PI / 3.0
                b.part("brass", (0.22 * math.cos(a), 0.22 * math.sin(a), 0), (0.08, 0.04, 0.04))
            # outer ring
            cylinder(b, "brass", 0.26, -0.02, 0.02, n=12)
            # copper accent
            b.part("enamel_teal", (0, 0, 0.06), (0.08, 0.08, 0.04))
        elif kind == "crank":
            b.part("brass", (0, 0, 0), (0.1, 0.1, 0.4))             # axle
            b.part("brass", (0.22, 0, 0.18), (0.06, 0.06, 0.28))   # arm
            b.part("wood", (0.38, 0, 0.18), (0.1, 0.1, 0.1))        # ball handle
            b.part("enamel_yellow", (0.12, 0, 0.32), (0.04, 0.04, 0.04))  # direction arrow
        elif kind == "lever":
            b.part("brass", (0, 0, 0), (0.06, 0.4, 0.06))           # arm
            b.part("wood", (0, 0.22, 0), (0.08, 0.08, 0.08))        # grip
            b.part("stone_mid", (0, -0.05, -0.02), (0.14, 0.14, 0.1))  # base
        elif kind == "ring":
            cylinder(b, "brass", 0.28, -0.04, 0.04, n=16)
            b.part("enamel_cream", (0, 0, 0.05), (0.18, 0.18, 0.04))  # glass centre
            b.part("glow_cyan", (0.18, 0, 0.06), (0.03, 0.03, 0.03))  # focus dot
        elif kind == "dial":
            b.part("enamel_teal", (0, 0, 0), (0.34, 0.34, 0.1))
            for k in range(5):
                a = k * TAU / 5.0
                b.part("brass", (0.3 * math.cos(a), 0.3 * math.sin(a), 0.06), (0.04, 0.04, 0.04))
            b.part("brass", (0.26, 0, 0.06), (0.04, 0.04, 0.06))    # pointer
        else:  # knob
            cylinder(b, "brass", 0.18, -0.1, 0.1, n=12)
            # knurling (grip ridges)
            for k in range(8):
                a = k * TAU / 8.0
                b.part("brass", (0.19 * math.cos(a), 0.19 * math.sin(a), 0), (0.02, 0.02, 0.18))
            b.part("brass", (0, 0, 0.12), (0.04, 0.16, 0.04))        # pointer mark
            b.part("enamel_cream", (0.18, 0, 0.1), (0.02, 0.02, 0.04))  # direction arrow
        ob = finish_builder(b, name)
        ob.location = P(TABLE_R, angle, 0.12)
        ob.rotation_euler = (0, 0, -angle)

    # ---- Reset button ----
    b = bl.Builder()
    b.part("brass", (0, 0, 0), (0.22, 0.22, 0.12))
    b.part("enamel_red", (0, 0, 0.08), (0.16, 0.16, 0.08))
    resetb = finish_builder(b, "ResetButton")
    resetb.location = P(TABLE_R, 0.0, 0.06)
    resetb.rotation_euler = (0, 0, 0)

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
