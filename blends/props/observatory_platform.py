"""Observatory platform: the Aetheric Engine, an integrated brass-and-stone instrument.

    blender -b -P blends/props/observatory_platform.py
Output: blends/props/observatory_platform.blend and godot/assets/props/observatory_platform.glb

Units: metres, GAME SCALE (table radius 2.4, deck at z = 0). Blender Z is up.
Game angles: point at game angle a is at (cos a, sin a) in Godot (x, z) =
Blender (cos a, -sin a).

The machine is one chassis: stone plinth, mahogany deck, brass gantry, copper
aether duct, press frame and front console. Controls sit in functional groups.

Exported objects:
  Platform          plinth + deck + gantry + press frame + console + duct
  VoidWindow        brass frame + glass pane (north)
  TelescopeMount    equatorial mount, tube, lens (rear)
  AzimuthKnob       large graduated wheel (left of pillar)
  ElevationKnob     graduated wheel (right of pillar)
  FocusRing         focus drum with scale (under tube)
  SigilSelector     enamel dial with detents (top of pillar)
  ValveA, ValveB    wheel valves with tell-tales (left manifold)
  FlowGauge         pressure gauge (left manifold)
  Mold              plate cradle / press bed (right)
  InscriptionPlate  brass blank in the cradle
  Crank             flywheel with wooden handle (front-right)
  InscribeLever     long lever with mahogany grip (front-left)
  ResetButton       guarded red plunger (front-centre)
"""
import math
import os
import sys

import bpy
from mathutils import Vector, Euler, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "lib"))
import bl
from blocks import P, cylinder, rod, prism

pal = bl.pal
TAU = 2 * math.pi
PI = math.pi

TABLE_R = 2.4
VOID_Z = -4.0


def finish(b, name):
    """Build the object with palette UVs and a material."""
    return b.finish(name)


def main():
    bl.reset_scene()

    # =====================================================================
    # 1. PLATFORM: stone plinth, mahogany deck, brass gantry, press frame
    # =====================================================================
    b = bl.Builder()
    # stone plinth
    b.part("stone_deep", (0, 0, -0.30), (6.4, 6.4, 0.50))
    b.part("stone_mid", (0, 0, -0.04), (5.4, 5.4, 0.08))
    # mahogany deck
    b.part("wood", (0, 0, 0.04), (4.9, 4.9, 0.10))
    b.part("wood_dark", (0, 0, 0.09), (4.7, 4.7, 0.02))
    # brass edge trim
    for sx in (1, -1):
        b.part("brass", (sx * 2.42, 0, 0.08), (0.10, 4.9, 0.14))
    for sy in (1, -1):
        b.part("brass", (0, sy * 2.42, 0.08), (4.9, 0.10, 0.14))

    # rear pillar (observation aperture)
    b.part("brass", (0, 1.5, 0.45), (0.34, 0.34, 1.2))
    b.part("bronze_dark", (0, 1.5, 1.02), (0.5, 0.5, 0.10))
    # gantry: two posts + a beam spanning to the press side
    b.part("brass", (-1.9, 0.2, 1.55), (0.18, 0.18, 3.0))
    b.part("brass", (1.9, 0.2, 1.55), (0.18, 0.18, 3.0))
    b.part("brass", (0, 0.2, 3.0), (4.0, 0.22, 0.22))
    # gantry cross braces
    b.part("bronze_dark", (-1.9, 0.2, 2.7), (1.6, 0.10, 0.10))
    b.part("bronze_dark", (1.9, 0.2, 2.7), (1.6, 0.10, 0.10))

    # press frame (right side)
    b.part("brass", (1.3, -1.0, 0.7), (0.10, 0.10, 1.4))
    b.part("brass", (1.3, -0.2, 0.7), (0.10, 0.10, 1.4))
    b.part("brass", (1.3, -0.6, 1.4), (0.10, 0.9, 0.10))
    b.part("brass", (1.3, -0.6, 1.45), (0.5, 0.5, 0.12))  # press head

    # console fascia (front)
    b.part("wood_dark", (0, -2.3, 0.55), (3.6, 0.10, 0.9))
    b.part("brass", (0, -2.25, 0.95), (3.6, 0.06, 0.08))
    # nameplate
    b.part("enamel_cream", (0, -2.2, 0.72), (1.4, 0.04, 0.18))

    platform = b.finish("Platform")

    # =====================================================================
    # 2. VOID WINDOW (north): brass frame + glass pane
    # =====================================================================
    b = bl.Builder()
    b.part("brass", (0, 1.62, VOID_Z - 0.08), (3.9, 0.16, 2.9))
    b.part("bronze_dark", (0, 1.62, VOID_Z - 0.02), (3.5, 0.10, 2.5))
    b.part("enamel_cream", (0, 1.6, VOID_Z), (3.4, 0.06, 2.4))
    # frame bolts
    for sx in (1, -1):
        for sz in (1, -1):
            b.part("brass", (sx * 1.7, 1.55, VOID_Z + 0.9 * sz), (0.12, 0.12, 0.12))
    voidw = b.finish("VoidWindow")

    # =====================================================================
    # 3. TELESCOPE MOUNT (rear): pedestal, fork, tube, lens
    # =====================================================================
    b = bl.Builder()
    # pedestal
    b.part("brass", (0, 1.5, 0.55), (0.5, 0.5, 0.9))
    b.part("bronze_dark", (0, 1.5, 1.0), (0.7, 0.7, 0.10))
    # azimuth ring
    cylinder(b, "brass", 0.36, 1.05, 1.10, n=24)
    # fork arms
    b.part("brass", (-0.28, 1.5, 1.25), (0.08, 0.08, 0.5))
    b.part("brass", (0.28, 1.5, 1.25), (0.08, 0.08, 0.5))
    # tube (pointing north/up)
    b.part("bronze_dark", (0, 1.15, 1.45), (0.20, 0.20, 1.0))
    b.part("brass", (0, 0.85, 1.45), (0.24, 0.24, 0.12))
    # lens
    b.part("enamel_cream", (0, 0.70, 1.45), (0.22, 0.08, 0.22))
    # counterweight
    b.part("bronze_dark", (0, 1.9, 1.2), (0.3, 0.3, 0.3))
    telescope = b.finish("TelescopeMount")

    # =====================================================================
    # 4. AZIMUTH / ELEVATION WHEELS, FOCUS DRUM, SIGIL DIAL
    # =====================================================================
    # Azimuth wheel (large graduated wheel)
    b = bl.Builder()
    cylinder(b, "brass", 0.14, -0.04, 0.04, n=24)  # boss
    cylinder(b, "bronze_dark", 0.18, -0.05, 0.05, n=24)  # rim
    for k in range(12):
        a = k * TAU / 12
        b.part("brass", (0.15 * math.cos(a), 0.15 * math.sin(a), 0), (0.06, 0.02, 0.02))
    b.part("enamel_cream", (0, 0.17, 0.05), (0.02, 0.06, 0.02))  # index pointer
    az = b.finish("AzimuthKnob")
    az.location = P(TABLE_R, 4.6, 0.55)
    az.rotation_euler = (0, 0, -4.6)

    # Elevation wheel
    b = bl.Builder()
    cylinder(b, "brass", 0.12, -0.04, 0.04, n=24)
    cylinder(b, "bronze_dark", 0.15, -0.05, 0.05, n=24)
    for k in range(10):
        a = k * TAU / 10
        b.part("brass", (0.13 * math.cos(a), 0.13 * math.sin(a), 0), (0.05, 0.02, 0.02))
    el = b.finish("ElevationKnob")
    el.location = P(TABLE_R, 3.9, 0.7)
    el.rotation_euler = (0, 0, -3.9)

    # Focus drum
    b = bl.Builder()
    cylinder(b, "brass", 0.14, -0.06, 0.06, n=20)
    for k in range(10):
        a = k * TAU / 10
        b.part("bronze_dark", (0.15 * math.cos(a), 0.15 * math.sin(a), 0), (0.03, 0.02, 0.03))
    b.part("enamel_cream", (0, 0, 0.07), (0.06, 0.03, 0.02))  # diopter dot
    focus = b.finish("FocusRing")
    focus.location = P(TABLE_R, 3.2, 0.75)
    focus.rotation_euler = (0, 0, -3.2)

    # Sigil selector dial (enamel with detents)
    b = bl.Builder()
    b.part("enamel_teal", (0, 0, 0), (0.40, 0.40, 0.10))
    for k in range(5):
        a = k * TAU / 5
        b.part("brass", (0.28 * math.cos(a), 0.28 * math.sin(a), 0.06), (0.05, 0.05, 0.05))
    b.part("brass", (0.24, 0, 0.07), (0.04, 0.04, 0.06))  # pointer
    sig = b.finish("SigilSelector")
    sig.location = P(TABLE_R, 5.6, 0.55)
    sig.rotation_euler = (0, 0, -5.6)

    # =====================================================================
    # 5. VALVES + GAUGE (left manifold)
    # =====================================================================
    for name, angle in (("ValveA", 2.4), ("ValveB", 1.7)):
        b = bl.Builder()
        # hub + threaded stem
        cylinder(b, "brass", 0.09, -0.08, 0.08, n=12)
        cylinder(b, "bronze_dark", 0.04, 0.08, 0.16, n=8)
        # wheel rim + spokes
        cylinder(b, "brass", 0.22, -0.02, 0.02, n=20)
        for k in range(6):
            a = k * PI / 3
            b.part("brass", (0.13 * math.cos(a), 0.13 * math.sin(a), 0), (0.18, 0.025, 0.03))
        # tell-tale disc (red/green)
        b.part("enamel_red", (0, 0, 0.10), (0.10, 0.10, 0.02))
        # travel indicator
        b.part("enamel_cream", (0.20, 0, 0.04), (0.02, 0.05, 0.02))
        v = b.finish(name)
        v.location = P(TABLE_R, angle, 0.55)
        v.rotation_euler = (0, 0, -angle)

    # Flow gauge (pressure gauge)
    b = bl.Builder()
    cylinder(b, "brass", 0.20, -0.03, 0.03, n=24)
    b.part("enamel_cream", (0, 0, 0.04), (0.30, 0.30, 0.02))
    b.part("enamel_teal", (0.08, 0, 0.05), (0.10, 0.03, 0.02))  # green (laminar) arc
    b.part("enamel_red", (-0.10, 0, 0.05), (0.08, 0.03, 0.02))
    b.part("bronze_dark", (0.06, 0.08, 0.06), (0.02, 0.02, 0.14))  # needle
    gauge = b.finish("FlowGauge")
    gauge.location = P(TABLE_R, 2.05, 0.75)
    gauge.rotation_euler = (0, 0, -2.05)

    # separate needle (pivot at gauge centre so it can swing)
    b = bl.Builder()
    b.part("enamel_red", (0, 0.10, 0), (0.02, 0.20, 0.02))
    b.part("brass", (0, 0, 0), (0.05, 0.05, 0.03))
    needle = b.finish("GaugeNeedle")
    needle.location = P(TABLE_R, 2.05, 0.80)
    needle.rotation_euler = (0, 0, -2.05)

    # =====================================================================
    # 6. MOLD / PRESS BED + PLATE
    # =====================================================================
    b = bl.Builder()
    b.part("stone_mid", (0, 0, 0.08), (1.2, 1.2, 0.16))
    b.part("stone_deep", (0, 0, 0.17), (1.05, 1.05, 0.06))
    b.part("brass", (0, 0, 0.21), (0.95, 0.95, 0.03))  # cradle rim
    # corner clamps
    for sx in (1, -1):
        for sz in (1, -1):
            b.part("bronze_dark", (sx * 0.45, 0, 0.24 + 0.45 * sz), (0.08, 0.08, 0.10))
    mold = b.finish("Mold")
    mold.location = (1.2, -0.6, 0.0)

    b = bl.Builder()
    b.part("brass", (0, 0, 0), (0.85, 0.85, 0.05))
    b.part("glow_amber", (0, 0, 0.035), (0.6, 0.6, 0.015))  # sigil etch
    plate = b.finish("InscriptionPlate")
    plate.location = (1.2, -0.6, 0.22)

    # =====================================================================
    # 7. FLYWHEEL CRANK (front-right)
    # =====================================================================
    b = bl.Builder()
    cylinder(b, "brass", 0.28, -0.04, 0.04, n=24)  # flywheel
    cylinder(b, "bronze_dark", 0.31, -0.05, 0.05, n=24)
    # spokes
    for k in range(6):
        a = k * PI / 3
        b.part("brass", (0.16 * math.cos(a), 0.16 * math.sin(a), 0), (0.22, 0.03, 0.03))
    # wooden ball handle
    b.part("wood", (0.36, 0, 0.04), (0.10, 0.10, 0.10))
    # direction arrow
    b.part("enamel_yellow", (0.10, 0.26, 0.06), (0.04, 0.04, 0.02))
    crank = b.finish("Crank")
    crank.location = P(TABLE_R, 1.0, 0.7)
    crank.rotation_euler = (0, 0, -1.0)

    # =====================================================================
    # 8. INSCRIBE LEVER (front-left)
    # =====================================================================
    b = bl.Builder()
    b.part("brass", (0, 0, 0.35), (0.08, 0.08, 0.7))       # arm
    b.part("wood", (0, 0, 0.70), (0.12, 0.12, 0.14))        # grip
    b.part("bronze_dark", (0, 0, 0.0), (0.22, 0.22, 0.10))   # pivot base
    lever = b.finish("InscribeLever")
    lever.location = P(TABLE_R, 0.35, 0.30)
    lever.rotation_euler = (0, 0, -0.35)

    # =====================================================================
    # 9. RESET PLUNGER (guarded)
    # =====================================================================
    b = bl.Builder()
    cylinder(b, "bronze_dark", 0.16, -0.02, 0.02, n=16)      # guard ring
    cylinder(b, "brass", 0.10, 0.02, 0.08, n=12)            # plunger
    b.part("enamel_red", (0, 0, 0.10), (0.14, 0.14, 0.04))  # red cap
    resetb = b.finish("ResetButton")
    resetb.location = P(TABLE_R, 0.0, 0.12)
    resetb.rotation_euler = (0, 0, 0)

    # =====================================================================
    # 9b. LAYER DRUM + LAMPS + COUNTERS
    # =====================================================================
    # indexing layer drum (4 engraved segments)
    b = bl.Builder()
    cylinder(b, "brass", 0.14, -0.06, 0.06, n=24)
    cylinder(b, "bronze_dark", 0.16, -0.07, 0.07, n=24)
    for k in range(4):
        a = k * TAU / 4
        b.part("enamel_cream", (0.12 * math.cos(a), 0.12 * math.sin(a), 0.08), (0.04, 0.04, 0.02))
    b.part("glow_amber", (0.17, 0, 0.06), (0.03, 0.03, 0.03))  # active segment marker
    drum = b.finish("LayerDrum")
    drum.location = (1.75, -0.6, 0.35)

    # aether lamp (glass globe on console)
    b = bl.Builder()
    cylinder(b, "brass", 0.10, -0.02, 0.02, n=16)
    b.part("enamel_cream", (0, 0, 0.10), (0.16, 0.16, 0.16))
    lamp = b.finish("AetherLamp")
    lamp.location = (0, -2.2, 1.05)

    # aether reservoir: glass bulb + inner liquid
    b = bl.Builder()
    cylinder(b, "brass", 0.14, 0.0, 0.06, n=16)
    b.part("enamel_cream", (0, 0, 0.18), (0.28, 0.28, 0.30))
    res = b.finish("AetherReservoir")
    res.location = (-0.9, -2.0, 1.0)
    b = bl.Builder()
    b.part("glow_cyan", (0, 0, 0.10), (0.20, 0.20, 0.20))
    liquid = b.finish("AetherLiquid")
    liquid.location = (-0.9, -2.0, 1.0)

    # ready / warning lamps
    b = bl.Builder()
    b.part("bronze_dark", (0, 0, 0), (0.10, 0.10, 0.06))
    b.part("enamel_teal", (0, 0, 0.05), (0.06, 0.06, 0.04))
    ready = b.finish("ReadyLamp")
    ready.location = (1.2, -1.0, 1.55)

    b = bl.Builder()
    b.part("bronze_dark", (0, 0, 0), (0.10, 0.10, 0.06))
    b.part("enamel_red", (0, 0, 0.05), (0.06, 0.06, 0.04))
    warn = b.finish("WarningLamp")
    warn.location = (-1.7, -0.2, 0.95)

    # =====================================================================
    # 10. AETHER DUCT + SIGHT GLASSES (continuous path)
    # =====================================================================
    b = bl.Builder()
    # main duct from aperture pillar to press, via the left manifold
    path = [
        Vector((0, 1.5, 1.0)),
        Vector((-1.2, 1.0, 0.8)),
        Vector((-1.7, 0.3, 0.7)),
        Vector((-1.4, -0.6, 0.7)),
        Vector((0.2, -0.9, 0.7)),
        Vector((1.2, -0.9, 0.7)),
    ]
    for i in range(len(path) - 1):
        rod(b, "enamel_teal", Matrix.Identity(4), path[i], path[i + 1], 0.07, 0.07)
    # sight-glass collars at two points
    for p in (path[1], path[3]):
        b.part("brass", (p.x, p.y, p.z), (0.18, 0.08, 0.08))
    duct = b.finish("Pipes")

    # glowing aether sight-glasses (driven by flow state)
    for i, p in enumerate((path[1], path[3])):
        b = bl.Builder()
        b.part("glow_cyan", (0, 0, 0), (0.22, 0.10, 0.10))
        core = b.finish("SightGlass" + ("A" if i == 0 else "B"))
        core.location = p

    # =====================================================================
    # Export
    # =====================================================================
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
