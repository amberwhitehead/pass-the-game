"""1950s mainframe platform: a round "computer room in a drum" (enamel cabinets, chrome, bakelite, tubes, tape).

    blender -b -P blends/props/mainframe_platform.py
Output: blends/props/mainframe_platform.blend and godot/assets/props/mainframe_platform.glb

For a minigame that does not exist yet. Same conventions as the other two platforms (game scale, display disc r=2.2
with its surface at z=0, game angles: a point at angle a is (cos a, sin a) in Godot (x, z), shared palette, blocks lib).

The top deck carries an EXAMPLE CONTROL KIT, eight clusters, one per 45 degrees, for the game designer to pick from
and move around. Each moving part is its own node (origin = its pivot, on the plate surface, z=0.02):
  knob_big_0/1, knob_small_0..2   rotate about local Z          toggle_0..7        flip about local X
  btn_red/green/amber/white_*      press = move down 0.03       mushroom           press = move down 0.05
  slider_0..2                      slide along local Y +-0.22   needle_0..2        rotate about local Z (gauge dials)
  selector                         12-position rotary, about Z  key                key switch, about Z
The static parts (plates, bezels, dial scales, nixie tubes, lamps, card slot, cage) are in `Platform`.
Other nodes: DisplaySurface (disc r=2.2, just below z=0), inscription_anchor (empty on the black track).
Lamps and tube glows use the palette's emission cells.

Everything is generated; the .blend is output (see blends/README.md about hand edits).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)               # blends/
sys.path.insert(0, os.path.join(ROOT, "lib"))
import bl  # noqa: E402
from blocks import *  # noqa: E402,F401,F403

R_DISPLAY = 2.2
Z_FLOOR, Z_BODY1, Z_BELT = -2.60, -2.35, -0.45
R_BODY = 3.5
R_FACE = R_BODY * math.cos(PI / 16)        # distance of a flat cabinet door plane
NB = 16
R_IN = 2.9
PZ = 0.02                                   # control plate surface height
CLUSTER_ANGLES = [k * PI / 4 for k in range(8)]
CLUSTER_R = 3.0


def ar(a):
    return (a + 360) % 360


# ---------------------------------------------------------------- body
def build_core(b):
    cylinder(b, "enamel_charcoal", R_IN, Z_FLOOR, -0.45)
    cylinder(b, "enamel_charcoal", 3.4, -1.2, -0.34)
    cylinder(b, "enamel_charcoal", 2.30, -0.45, -0.05)


def build_body(b):
    rng = random.Random(3)
    # recessed toe-kick plinth and chrome foot ring
    for i in range(32):
        a0, a1 = i * TAU / 32, (i + 1) * TAU / 32
        pblock(b, rng, "enamel_charcoal", R_IN, 3.25, a0, a1, Z_FLOOR, Z_BODY1, jit=0, jz=0, bevel=0, gap=0.004, hollow=True)
        pblock(b, rng, "chrome", R_IN, 3.36, a0, a1, Z_BODY1 - 0.05, Z_BODY1 + 0.0, jit=0, jz=0, bevel=0.004, gap=0.003, hollow=True)
    # cabinet shells: one tall panel per bay, mint enamel
    for k in range(NB):
        a0, a1 = k * TAU / NB, (k + 1) * TAU / NB
        pblock(b, rng, "enamel_mint" if k % 2 == 0 else "enamel_mint_dark", R_IN, R_BODY, a0, a1, Z_BODY1, Z_BELT,
               jit=0, jz=0, bevel=0.01, gap=0.008, hollow=True)
    # red belt stripe, charcoal cornice with chrome lip
    for i in range(32):
        a0, a1 = i * TAU / 32, (i + 1) * TAU / 32
        pblock(b, rng, "enamel_red", R_IN, R_BODY + 0.02, a0, a1, -0.72, -0.62, jit=0, jz=0, bevel=0, gap=0.003, hollow=True)
        pblock(b, rng, "enamel_charcoal", R_IN, 3.62, a0, a1, Z_BELT, -0.36, jit=0, jz=0, bevel=0.006, gap=0.003, hollow=True)
        pblock(b, rng, "chrome", R_IN, 3.66, a0, a1, -0.36, -0.33, jit=0, jz=0, bevel=0.003, gap=0.003, hollow=True)
    # pier trims
    for k in range(NB):
        M = frame(k * TAU / NB, R_FACE + 0.015)
        lbox(b, "chrome", M, (0, 0, (Z_BODY1 + Z_BELT) / 2), (0.07, 0.04, Z_BELT - Z_BODY1 - 0.02))
        for z in (-2.2, -1.5, -0.8):
            lbox(b, "steel", M, (0, 0.022, z), (0.035, 0.012, 0.035))                      # rivet heads
    # four rocket fins
    for k in range(4):
        a = k * PI / 2
        M = frame(a, 0.0)
        t = 0.06
        prof = [(3.40, -2.60), (4.25, -2.60), (3.58, -1.25), (3.40, -1.25)]
        cs = [M @ Vector((-t, y, z)) for y, z in prof] + [M @ Vector((t, y, z)) for y, z in prof]
        solid(b, cs, "chrome", 0.0, hollow=False)
        lbox(b, "enamel_red", M, (0, 3.80, -2.37), (0.14, 0.78, 0.30), top=(1, 0.2))
        lbox(b, "lamp_red", M, (0, 3.55, -1.22), (0.1, 0.1, 0.06))


def bay_frame(k):
    return frame((k + 0.5) * TAU / NB, R_FACE)


def door(b, M, name):
    """Door leaf with a chrome pull and a header strip with three jewel lamps."""
    lbox(b, "enamel_cream", M, (0, 0.012, -1.48), (1.12, 0.024, 1.50), bevel=0.006)
    lbox(b, "panel_black", M, (0, 0.026, -1.48), (1.0, 0.012, 1.38))
    lbox(b, "chrome", M, (0.56, 0.035, -1.48), (0.035, 0.06, 0.36), bevel=0.004)
    lbox(b, "chrome", M, (0, 0.016, -0.74), (0.9, 0.032, 0.07), bevel=0.004)             # nameplate
    for i, c in enumerate(random.Random(sum(map(ord, name))).sample(["lamp_red", "led_green", "glow_amber", "lamp_white", "glow_cyan"], 3)):
        lbox(b, c, M, (-0.25 + i * 0.25, 0.04, -0.74), (0.07, 0.03, 0.035), bevel=0.004)


def bay_tape(b, k, M):
    door(b, M, f"t{k}")
    zr = -1.12
    for sx in (-1, 1):
        Mr = M @ Matrix.Translation((sx * 0.30, 0.04, zr)) @ Matrix.Rotation(-PI / 2, 4, "X")
        prism(b, "chrome", Mr, 12, 0.25, 0.25, 0.0, 0.018, off=TAU / 24)
        prism(b, "tape_brown", Mr, 12, 0.19, 0.19, 0.018, 0.058, off=TAU / 24)
        prism(b, "chrome", Mr, 12, 0.25, 0.25, 0.058, 0.076, off=TAU / 24)
        prism(b, "enamel_teal" if sx < 0 else "enamel_red", Mr, 12, 0.07, 0.07, 0.076, 0.09, off=TAU / 24)
        for j in range(3):
            ang = j * TAU / 3 + PI / 2
            prism(b, "panel_black", Mr, 6, 0.045, 0.045, 0.075, 0.079, c=(0.145 * math.cos(ang), 0.145 * math.sin(ang)))
    for sx in (-1, 1):                                   # vacuum columns with tape loops
        lbox(b, "lens", M, (sx * 0.14, 0.05, -1.80), (0.10, 0.03, 0.55))
        lbox(b, "tape_brown", M, (sx * 0.14, 0.07, -1.95 if sx < 0 else -1.7), (0.07, 0.012, 0.22 if sx > 0 else 0.12))
        lbox(b, "glow_amber", M, (sx * 0.14, 0.06, -1.50), (0.05, 0.02, 0.025))
    lbox(b, "chrome", M, (0, 0.06, -1.5), (0.14, 0.05, 0.10), bevel=0.005)             # read/write head
    for sx in (-0.42, 0.42):
        prism(b, "chrome", M @ Matrix.Rotation(-PI / 2, 4, "X"), 8, 0.025, 0.025, 0.03, 0.09, c=(sx, 1.68))


def bay_tubes(b, k, M):
    door(b, M, f"u{k}")
    lbox(b, "enamel_charcoal", M, (0, 0.04, -1.48), (0.94, 0.05, 1.28))
    for r in range(4):
        z = -2.00 + r * 0.30
        lbox(b, "steel", M, (0, 0.075, z - 0.02), (0.88, 0.03, 0.03))                       # chassis rail
        for c in range(4):
            u = -0.33 + c * 0.22
            Mt = M @ Matrix.Translation((u, 0.12, z))
            prism(b, "lens", Mt, 6, 0.055, 0.03, 0.0, 0.2, off=TAU / 12)
            lbox(b, "glow_amber" if (r + c + k) % 3 else "lamp_red", Mt, (0, 0, 0.04), (0.035, 0.035, 0.07))
            lbox(b, "steel", Mt, (0, 0, -0.01), (0.09, 0.09, 0.02))


def bay_lamps(b, k, M):
    door(b, M, f"l{k}")
    rng = random.Random(100 + k)
    cols = ["lamp_red", "led_green", "glow_amber", "lamp_white", "glow_cyan", "enamel_charcoal", "enamel_charcoal"]
    for r in range(6):
        for c in range(8):
            cell = rng.choice(cols)
            lbox(b, cell, M, (-0.38 + c * 0.108, 0.05, -2.10 + r * 0.12), (0.06, 0.03, 0.06), bevel=0.004)
    for c in range(8):                                    # toggle row
        lbox(b, "chrome", M, (-0.38 + c * 0.108, 0.05, -1.30), (0.03, 0.04, 0.03))
        rod(b, "chrome", M, (-0.38 + c * 0.108, 0.05, -1.30), (-0.38 + c * 0.108, 0.075, -1.20), 0.016, 0.016)
        lbox(b, "bakelite", M, (-0.38 + c * 0.108, 0.078, -1.19), (0.03, 0.03, 0.03))
    lbox(b, "enamel_red", M, (0, 0.04, -2.2), (0.9, 0.02, 0.04))


def bay_patch(b, k, M):
    door(b, M, f"p{k}")
    lbox(b, "enamel_gray", M, (0, 0.04, -1.5), (0.94, 0.04, 1.2))
    pts = {}
    for r in range(5):
        for c in range(6):
            p = (-0.4 + c * 0.16, 0.065, -2.0 + r * 0.22)
            pts[(r, c)] = p
            prism(b, "chrome", M @ Matrix.Rotation(-PI / 2, 4, "X"), 6, 0.035, 0.035, 0.05, 0.075, c=(p[0], -p[2]))
            lbox(b, "panel_black", M, (p[0], 0.077, p[2]), (0.03, 0.01, 0.03))
    cols = ["enamel_red", "enamel_teal", "enamel_yellow", "dial_white", "enamel_red"]
    rng = random.Random(7 + k)
    for i in range(7):
        r0, c0 = rng.randrange(5), rng.randrange(6)
        r1, c1 = rng.randrange(5), rng.randrange(6)
        if (r0, c0) == (r1, c1):
            continue
        p0, p1 = Vector(pts[(r0, c0)]), Vector(pts[(r1, c1)])
        mid = (p0 + p1) / 2 + Vector((0, 0.07 + 0.02 * (i % 3), 0))
        rod(b, cols[i % 5], M, p0 + Vector((0, 0.02, 0)), mid, 0.022, 0.022)
        rod(b, cols[i % 5], M, mid, p1 + Vector((0, 0.02, 0)), 0.022, 0.022)


def bay_gauges(b, k, M):
    door(b, M, f"g{k}")
    for i, (u, z, R) in enumerate(((-0.25, -1.0 - 0.2, 0.2), (0.25, -1.2, 0.2), (0.0, -1.75, 0.28))):
        Mg = M @ Matrix.Translation((u, 0.04, z)) @ Matrix.Rotation(-PI / 2, 4, "X")
        prism(b, "chrome", Mg, 12, R + 0.03, R + 0.03, 0.0, 0.03, off=TAU / 24)
        prism(b, "dial_white", Mg, 12, R, R, 0.03, 0.036, off=TAU / 24)
        for t in range(9):
            ang = math.radians(-215 + t * 30)
            lbox(b, "enamel_red" if t >= 7 else "panel_black", M, (u + (R - 0.05) * math.cos(ang + PI / 2) * 0 + (R - 0.04) * math.cos(ang),
                 0.078, z + (R - 0.04) * math.sin(ang)), (0.012, 0.004, 0.05), R=Matrix.Rotation(ang - PI / 2, 4, "Y"))
        ang = math.radians(-215 + (3 + i) * 30)
        rod(b, "enamel_red", M, (u, 0.082, z), (u + R * 0.8 * math.cos(ang), 0.082, z + R * 0.8 * math.sin(ang)), 0.012, 0.006)
        prism(b, "chrome", Mg, 6, 0.025, 0.025, 0.036, 0.05)
    lbox(b, "enamel_teal", M, (0, 0.04, -2.2), (0.9, 0.02, 0.05))


def bay_cards(b, k, M):
    door(b, M, f"c{k}")
    lbox(b, "enamel_gray", M, (0, 0.05, -1.25), (0.9, 0.06, 0.6), bevel=0.006)                # card reader body
    lbox(b, "panel_black", M, (0, 0.085, -1.12), (0.7, 0.02, 0.08))                           # card slot
    lbox(b, "enamel_cream", M, (0, 0.10, -1.05), (0.56, 0.012, 0.16), R=Matrix.Rotation(-0.25, 4, "X"))   # card in the slot
    # hopper with a stack of cards
    lbox(b, "chrome", M, (-0.3, 0.09, -1.55), (0.26, 0.1, 0.18), top=(1.3, 1.0))
    for i in range(6):
        lbox(b, "enamel_cream" if i % 2 else "enamel_yellow", M, (-0.3, 0.1, -1.60 + i * 0.026), (0.22, 0.07, 0.022))
    lbox(b, "bakelite", M, (0.25, 0.07, -1.55), (0.36, 0.05, 0.16), bevel=0.006)            # output chute
    for i in range(3):
        lbox(b, "led_green" if i == 0 else "lamp_red" if i == 1 else "glow_amber", M, (-0.28 + i * 0.1, 0.085, -2.0), (0.06, 0.03, 0.06), bevel=0.004)
    lbox(b, "chrome", M, (0.1, 0.07, -2.0), (0.28, 0.04, 0.10))


def bay_drum(b, k, M):
    door(b, M, f"d{k}")
    lbox(b, "enamel_charcoal", M, (0, 0.04, -1.5), (0.94, 0.05, 1.3))
    Md = M @ Matrix.Translation((0, 0.20, -1.35)) @ Matrix.Rotation(PI / 2, 4, "Y")        # magnetic drum, axis along u
    prism(b, "chrome", Md, 12, 0.2, 0.2, -0.42, 0.42, off=TAU / 24)
    for i in range(6):
        prism(b, "enamel_charcoal", Md, 12, 0.204, 0.204, -0.36 + i * 0.145, -0.34 + i * 0.145, off=TAU / 24)
    for sx in (-1, 1):
        lbox(b, "steel", M, (sx * 0.44, 0.15, -1.35), (0.05, 0.28, 0.46))
    for i in range(6):                                                                       # read heads
        lbox(b, "bronze", M, (-0.36 + i * 0.145 + 0.0, 0.40, -1.35), (0.05, 0.05, 0.06))
    lbox(b, "lamp_red", M, (0.3, 0.06, -2.1), (0.1, 0.03, 0.1), bevel=0.005)
    lbox(b, "dial_white", M, (-0.1, 0.06, -2.1), (0.5, 0.01, 0.05))


def bay_emblem(b, k, M):
    door(b, M, f"e{k}")
    for i in range(10):                                   # louvres
        lbox(b, "chrome", M, (0, 0.05, -2.06 + i * 0.045), (0.8, 0.05, 0.02), R=Matrix.Rotation(0.5, 4, "X"))
    # rocket emblem, standing, with an atomic starburst behind it
    for i in range(8):
        ang = i * PI / 4
        lbox(b, "brass", M, (0.0, 0.045, -1.15), (0.02, 0.012, 0.55 if i % 2 == 0 else 0.34), R=Matrix.Rotation(ang, 4, "Y"))
    Mr = M @ Matrix.Translation((0, 0.06, -1.15))
    prism(b, "chrome", Mr, 8, 0.07, 0.07, -0.16, 0.10, off=TAU / 16)
    prism(b, "enamel_red", Mr, 8, 0.07, 0.01, 0.10, 0.24, off=TAU / 16)
    for sx in (-1, 1):
        lbox(b, "enamel_red", Mr, (sx * 0.085, 0, -0.12), (0.04, 0.03, 0.12), top=(1, 1), R=Matrix.Rotation(sx * 0.3, 4, "Y"))
    lbox(b, "glow_amber", Mr, (0, 0, -0.2), (0.07, 0.03, 0.07), top=(0.2, 0.2))
    lbox(b, "enamel_teal", Mr, (0, 0.04, 0.0), (0.04, 0.012, 0.04))


BAYS = [bay_tape, bay_tubes, bay_lamps, bay_patch, bay_gauges, bay_cards, bay_drum, bay_emblem]


def build_bays(b):
    for k in range(NB):
        M = bay_frame(k)
        BAYS[k % 8](b, k, M)


# ---------------------------------------------------------------- deck
def build_deck(b):
    rng = random.Random(23)
    z0, z1 = -0.34, 0.0
    for i in range(48):                                   # bezel
        pblock(b, rng, "chrome", 2.20, 2.30, i * TAU / 48, (i + 1) * TAU / 48, z0, 0.03, jit=0, jz=0, bevel=0.005, gap=0.003, hollow=True)
    for i in range(48):                                   # black track (inscription, glossy)
        pblock(b, rng, "panel_black", 2.30, 2.52, i * TAU / 48, (i + 1) * TAU / 48, z0, z1, jit=0, jz=0, bevel=0, gap=0.003, hollow=True)
    for i in range(8):                                    # mint console panels, one per cluster, plus charcoal gaps
        a = CLUSTER_ANGLES[i]
        pblock(b, rng, "enamel_mint" if i % 2 == 0 else "enamel_mint_dark", 2.52, 3.45, a - PI / 8, a + PI / 8, z0, z1,
               jit=0, jz=0, bevel=0.006, gap=0.008, hollow=True)
    for i in range(32):                                   # chrome outer trim with a ring of lamps
        pblock(b, rng, "enamel_charcoal", 3.45, 3.75, i * TAU / 32, (i + 1) * TAU / 32, z0, -0.07, jit=0, jz=0, bevel=0, gap=0.003, hollow=True)
        pblock(b, rng, "chrome", 3.45, 3.76, i * TAU / 32, (i + 1) * TAU / 32, -0.07, 0.035, jit=0, jz=0, bevel=0.006, gap=0.003, hollow=True)
    for i in range(32):
        lbox(b, ("lamp_white", "glow_amber", "led_green", "lamp_red")[i % 4], frame((i + 0.5) * TAU / 32, 3.60), (0, 0, 0.04),
             (0.05, 0.05, 0.02), bevel=0.003)


def plate(b, M, w=1.9, d=0.78):
    lbox(b, "enamel_charcoal", M, (0, 0, 0.01), (w, d, 0.02), bevel=0.004)
    for sx in (-1, 1):
        lbox(b, "chrome", M, (sx * (w / 2 - 0.012), 0, 0.012), (0.024, d, 0.024))
    for sy in (-1, 1):
        lbox(b, "chrome", M, (0, sy * (d / 2 - 0.012), 0.012), (w, 0.024, 0.024))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lbox(b, "steel", M, (sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), 0.024), (0.03, 0.03, 0.01))


def ticks(b, M, cu, cy, r, n, a0, a1, major=5, length=0.035):
    """Dial scale of n+1 ticks on the plate, angles in degrees measured in the (u, y) plane."""
    for i in range(n + 1):
        ang = math.radians(a0 + (a1 - a0) * i / n)
        L = length * (1.8 if i % major == 0 else 1.0)
        rc = r + L / 2
        lbox(b, "dial_white", M, (cu + rc * math.cos(ang), cy + rc * math.sin(ang), PZ + 0.002),
             (0.009 if i % major else 0.014, L, 0.004), rot=math.degrees(ang) - 90)


def label_bar(b, M, u, y, w, cell="dial_white"):
    lbox(b, cell, M, (u, y, PZ + 0.002), (w, 0.012, 0.004))


def cluster_frame(i):
    return frame(CLUSTER_ANGLES[i], CLUSTER_R, 0.0)


# placements of the movable control nodes: (name, source, matrix, extra yaw)
PLACEMENTS = []


def put(name, src, M, u, y, yaw=0.0, z=PZ):
    PLACEMENTS.append((name, src, M @ Matrix.Translation((u, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")))


def build_clusters(b):
    # 0: toggle bank with indicator lamps
    M = cluster_frame(0); plate(b, M)
    for i in range(8):
        u = -0.76 + i * 0.217
        prism(b, "chrome", M, 6, 0.06, 0.06, PZ, PZ + 0.02, c=(u, 0.08))
        lbox(b, ("lamp_red", "led_green", "glow_amber", "lamp_white")[i % 4], M, (u, -0.17, PZ + 0.015), (0.08, 0.08, 0.03), bevel=0.006)
        label_bar(b, M, u, 0.28, 0.12)
        put(f"toggle_{i}", "toggle", M, u, 0.08)
    # 1: two big knobs with dial scales, three small knobs below... (scales on plate)
    M = cluster_frame(1); plate(b, M)
    for j, u in enumerate((-0.45, 0.45)):
        ticks(b, M, u, 0.0, 0.25, 20, -225, 45, 5)
        put(f"knob_big_{j}", "knob_big", M, u, 0.0)
        lbox(b, "lamp_white" if j else "glow_amber", M, (u, -0.33, PZ + 0.012), (0.05, 0.05, 0.02), bevel=0.003)
    # 2: push-button grid
    M = cluster_frame(2); plate(b, M)
    cols = ["red", "green", "amber", "white"]
    for r in range(2):
        for c in range(4):
            u, y = -0.6 + c * 0.4, -0.15 + r * 0.30
            lbox(b, "chrome", M, (u, y, PZ + 0.018), (0.15, 0.15, 0.036), bevel=0.004)
            put(f"btn_{cols[(c + r) % 4]}_{r * 4 + c}", f"btn_{cols[(c + r) % 4]}", M, u, y, z=PZ + 0.036)
    for c in range(4):
        label_bar(b, M, -0.6 + c * 0.4, 0.34, 0.12)
    # 3: three round gauges
    M = cluster_frame(3); plate(b, M)
    for j, u in enumerate((-0.62, 0.0, 0.62)):
        prism(b, "chrome", M, 12, 0.235, 0.235, PZ, PZ + 0.03, off=TAU / 24, c=(u, 0.0))
        prism(b, "dial_white", M, 12, 0.205, 0.205, PZ + 0.03, PZ + 0.034, off=TAU / 24, c=(u, 0.0))
        for t in range(9):
            ang = math.radians(-225 + t * 33.75)
            lbox(b, "enamel_red" if t >= 7 else "panel_black", M, (u + 0.17 * math.cos(ang), 0.17 * math.sin(ang), PZ + 0.036),
                 (0.012, 0.05, 0.004), rot=math.degrees(ang) - 90)
        put(f"needle_{j}", "needle", M, u, 0.0, yaw=(-20 + j * 35), z=PZ + 0.036)
    # 4: three slide faders
    M = cluster_frame(4); plate(b, M)
    for j, u in enumerate((-0.55, 0.0, 0.55)):
        lbox(b, "panel_black", M, (u, 0.0, PZ + 0.002), (0.05, 0.56, 0.006))
        for t in range(9):
            lbox(b, "dial_white", M, (u + 0.09, -0.27 + t * 0.0675, PZ + 0.002), (0.05 if t % 4 == 0 else 0.03, 0.008, 0.004))
        put(f"slider_{j}", "slider", M, u, -0.2 + j * 0.2)
    # 5: rotary selector (12 positions) with three small knobs
    M = cluster_frame(5); plate(b, M)
    prism(b, "chrome", M, 12, 0.2, 0.2, PZ, PZ + 0.024, off=TAU / 24, c=(0.5, 0.0))
    ticks(b, M, 0.5, 0.0, 0.215, 11, -270, 0, 1, 0.04)
    for t in range(12):
        ang = math.radians(t * 30)
        lbox(b, "dial_white", M, (0.5 + 0.275 * math.cos(ang), 0.275 * math.sin(ang), PZ + 0.002), (0.025, 0.025, 0.004))
    put("selector", "selector", M, 0.5, 0.0, z=PZ + 0.024)
    for j, u in enumerate((-0.75, -0.4, -0.05)):
        ticks(b, M, u, 0.0, 0.13, 10, -225, 45, 5, 0.025)
        put(f"knob_small_{j}", "knob_small", M, u, 0.0)
    # 6: nixie tubes + key switch
    M = cluster_frame(6); plate(b, M)
    segs = {0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg", 5: "acdfg", 6: "acdefg", 7: "abc", 8: "abcdefg", 9: "abcdfg"}
    seg_pos = {"a": (0, 0.1, 0.1, 0.02), "b": (0.05, 0.05, 0.02, 0.1), "c": (0.05, -0.05, 0.02, 0.1), "d": (0, -0.1, 0.1, 0.02),
               "e": (-0.05, -0.05, 0.02, 0.1), "f": (-0.05, 0.05, 0.02, 0.1), "g": (0, 0.0, 0.1, 0.02)}
    for j in range(6):
        u = -0.78 + j * 0.2
        Mt = M @ Matrix.Translation((u, 0.0, PZ))
        prism(b, "enamel_charcoal", Mt, 8, 0.075, 0.075, 0.0, 0.02, off=TAU / 16)
        prism(b, "lens_dark", Mt, 8, 0.065, 0.055, 0.02, 0.27, off=TAU / 16)
        for s in segs[(j * 3 + 2) % 10]:
            x, z, w, h = seg_pos[s]
            lbox(b, "glow_amber", Mt, (x * 0.6, 0.062, 0.145 + z * 1.0), (w * 0.6, 0.012, h * 0.8))
    prism(b, "chrome", M, 8, 0.07, 0.07, PZ, PZ + 0.02, off=TAU / 16, c=(0.78, 0.0))
    lbox(b, "lamp_red", M, (0.78, -0.2, PZ + 0.012), (0.05, 0.05, 0.02), bevel=0.003)
    put("key", "key", M, 0.78, 0.0, z=PZ + 0.02)
    # 7: mushroom emergency stop in a guard cage, plus a card slot
    M = cluster_frame(7); plate(b, M)
    prism(b, "enamel_yellow", M, 12, 0.19, 0.19, PZ, PZ + 0.045, off=TAU / 24, c=(-0.45, 0.0))
    for j in range(4):
        ang = j * PI / 2 + PI / 4
        p = (-0.45 + 0.18 * math.cos(ang), 0.18 * math.sin(ang))
        rod(b, "chrome", M, (p[0], p[1], PZ + 0.04), (p[0] * 0.7 - 0.45 * 0.3, p[1] * 0.7, PZ + 0.20), 0.02, 0.02)
        rod(b, "chrome", M, (p[0] * 0.7 - 0.45 * 0.3, p[1] * 0.7, PZ + 0.20), (-0.45, 0.0, PZ + 0.22), 0.016, 0.016)
    put("mushroom", "mushroom", M, -0.45, 0.0, z=PZ + 0.045)
    lbox(b, "panel_black", M, (0.4, 0.0, PZ + 0.004), (0.6, 0.06, 0.008))
    for i in range(3):
        lbox(b, "enamel_cream" if i != 1 else "enamel_yellow", M, (0.25 + i * 0.16, 0.14 + 0.0, PZ + 0.012 + i * 0.0), (0.13, 0.17, 0.008), rot=0)
    lbox(b, "dial_white", M, (0.4, -0.25, PZ + 0.002), (0.6, 0.012, 0.004))


# ---------------------------------------------------------------- control kit meshes (origin at their pivot)
def mk_knob(b, s):
    I = Matrix.Identity(4)
    prism(b, "bakelite", I, 12, 0.17 * s, 0.15 * s, 0.0, 0.04 * s, off=TAU / 24)
    prism(b, "bakelite", I, 12, 0.15 * s, 0.12 * s, 0.04 * s, 0.11 * s, off=TAU / 24)
    prism(b, "chrome", I, 12, 0.09 * s, 0.085 * s, 0.11 * s, 0.125 * s, off=TAU / 24)
    lbox(b, "dial_white", I, (0, 0.085 * s, 0.126 * s), (0.018 * s, 0.1 * s, 0.006))
    lbox(b, "dial_white", I, (0, 0.165 * s, 0.02 * s), (0.02 * s, 0.03 * s, 0.03 * s))


def mk_toggle(b):
    I = Matrix.Identity(4)
    prism(b, "chrome", I, 8, 0.03, 0.03, 0.0, 0.02, off=TAU / 16)
    rod(b, "chrome", I, (0, 0, 0.02), (0, 0, 0.17), 0.028, 0.028, w1=0.016, h1=0.016)
    prism(b, "bakelite", I, 8, 0.024, 0.024, 0.17, 0.2, off=TAU / 16)


def mk_btn(b, cell):
    lbox(b, cell, Matrix.Identity(4), (0, 0, 0.02), (0.105, 0.105, 0.04), top=(0.9, 0.9), bevel=0.006)


def mk_mushroom(b):
    I = Matrix.Identity(4)
    prism(b, "enamel_red", I, 12, 0.13, 0.13, 0.0, 0.03, off=TAU / 24)
    prism(b, "enamel_red", I, 12, 0.13, 0.08, 0.03, 0.075, off=TAU / 24)
    prism(b, "lamp_red", I, 12, 0.08, 0.05, 0.075, 0.09, off=TAU / 24)


def mk_slider(b):
    I = Matrix.Identity(4)
    lbox(b, "bakelite", I, (0, 0, 0.035), (0.1, 0.07, 0.07), top=(0.9, 0.9), bevel=0.005)
    lbox(b, "dial_white", I, (0, 0, 0.072), (0.09, 0.008, 0.004))
    lbox(b, "chrome", I, (0, 0, 0.0), (0.03, 0.06, 0.012))


def mk_needle(b):
    I = Matrix.Identity(4)
    lbox(b, "enamel_red", I, (0, 0.085, 0.004), (0.014, 0.19, 0.008), top=(0.2, 1))
    lbox(b, "enamel_red", I, (0, -0.04, 0.004), (0.03, 0.05, 0.008))
    prism(b, "chrome", I, 8, 0.028, 0.02, 0.0, 0.025, off=TAU / 16)


def mk_selector(b):
    I = Matrix.Identity(4)
    prism(b, "bakelite", I, 12, 0.07, 0.06, 0.0, 0.07, off=TAU / 24)
    lbox(b, "bakelite", I, (0, 0.11, 0.03), (0.09, 0.3, 0.06), top=(0.8, 0.5), bevel=0.006)
    prism(b, "chrome", I, 12, 0.05, 0.045, 0.07, 0.085, off=TAU / 24)
    lbox(b, "dial_white", I, (0, 0.2, 0.062), (0.016, 0.07, 0.006))


def mk_key(b):
    I = Matrix.Identity(4)
    prism(b, "chrome", I, 8, 0.045, 0.045, 0.0, 0.015, off=TAU / 16)
    lbox(b, "bronze", I, (0, 0.09, 0.03), (0.07, 0.14, 0.012), top=(1, 0.7))
    lbox(b, "bronze", I, (0, 0.0, 0.015), (0.025, 0.12, 0.012))
    lbox(b, "bakelite", I, (0, -0.06, 0.04), (0.04, 0.05, 0.05))


# ---------------------------------------------------------------- assembly
def finish(b, name, mat):
    ob = b.finish(name)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


def main():
    bl.reset_scene()
    mat = bl.make_material()
    plat = bl.Builder()
    last = [0]

    def stage(fn, *a):
        fn(plat, *a)
        t = sum(len(f.verts) - 2 for f in plat.bm.faces)
        print(f"  {fn.__name__:18s} +{t - last[0]:6d} tris")
        last[0] = t
    for fn in (build_core, build_body, build_bays, build_deck, build_clusters):
        stage(fn)
    platform = finish(plat, "Platform", mat)

    d = bl.Builder()
    prism(d, "enamel_gray", Matrix.Identity(4), 64, R_DISPLAY, R_DISPLAY, -0.02, 0.0)
    finish(d, "DisplaySurface", mat)

    kit = {}

    def mesh(name, fn, *a):
        bb = bl.Builder()
        fn(bb, *a)
        ob = finish(bb, f"_kit_{name}", mat)
        ob.hide_viewport = False
        kit[name] = ob
    mesh("knob_big", mk_knob, 1.0)
    mesh("knob_small", mk_knob, 0.5)
    mesh("toggle", mk_toggle)
    for c, cell in (("red", "lamp_red"), ("green", "led_green"), ("amber", "glow_amber"), ("white", "lamp_white")):
        mesh(f"btn_{c}", mk_btn, cell)
    mesh("mushroom", mk_mushroom)
    mesh("slider", mk_slider)
    mesh("needle", mk_needle)
    mesh("selector", mk_selector)
    mesh("key", mk_key)
    used = set()
    for name, src, M in PLACEMENTS:
        s = kit[src]
        ob = s if src not in used else bpy.data.objects.new(name, s.data)
        if ob is not s:
            bpy.context.scene.collection.objects.link(ob)
        else:
            used.add(src)
            ob.name = name
        ob.matrix_world = M
    # kit meshes never placed (should not happen) stay at the origin under their _kit_ names

    e = bpy.data.objects.new("inscription_anchor", None)
    e.location = P(2.42, 3 * PI / 2, 0.0)
    bpy.context.scene.collection.objects.link(e)

    out_blend = os.path.join(HERE, "mainframe_platform.blend")
    out_glb = os.path.join(os.path.dirname(ROOT), "godot", "assets", "props", "mainframe_platform.glb")
    os.makedirs(os.path.dirname(out_glb), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True,
                              export_image_format="AUTO", export_cameras=False, export_lights=False, export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=True)
    print(f"platform tris={bl.tri_count(platform)} kit nodes={len(PLACEMENTS)}")


main()
