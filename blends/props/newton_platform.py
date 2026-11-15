"""Newton's Table platform: a round, block-built Egyptian machine that carries the table.

    blender -b -P blends/props/newton_platform.py
Output: blends/props/newton_platform.blend and godot/assets/props/newton_platform.glb

Units: metres, GAME SCALE (the minigame's own: display disc r = 2.2, display surface at z = 0).
Scale the whole thing down uniformly when placing it in the room. Blender Z is up (glTF/Godot Y).
Game angles (the `angle` of newton.gd controls) are measured the way Godot does it: a point at
game angle a is at (cos a, sin a) in Godot (x, z) = Blender (cos a, -sin a).

Exported nodes (all share the one palette material):
  Platform         static stone/bronze/wood/rope body (display hole in the middle)
  DisplaySurface   flat disc r=2.2 just below z=0: put the fractal material on it
  roller_0..3      rotating controls (re, im, a, rot), origin at the roller centre, axis = local +X
                   which points OUTWARD from the table (the same convention as newton.gd)
  reset_button     plunger (origin on the deck, press = move down ~0.06)
  crystal_socket_0..2  empties at the deck where the key-colour crystals stand (cyan, yellow, magenta)
  inscription_anchor   empty at the middle of the smooth basalt track meant for the inscription text

Everything is generated; the .blend is output (see blends/README.md about hand edits).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)               # blends/
sys.path.insert(0, os.path.join(ROOT, "lib"))
import bl  # noqa: E402

pal = bl.pal
TAU = 2 * math.pi
PI = math.pi

# ---------------------------------------------------------------- game-side layout (newton.gd)
R_DISPLAY = 2.2
ROLLER_ANGLES = [4.45, 3.75, 2.53, 1.83]        # re, im, a, rot
ROLLER_R = 0.30
ROLLER_LEN = 0.30
ROLLER_C = 2.85                                  # radial centre of a roller
ROLLER_Z = -0.24                                 # axis height
BUTTON_ANGLE, BUTTON_R = 0.0, 2.55
CRYSTAL_ANGLES, CRYSTAL_R = [PI / 3, PI, 5 * PI / 3], 2.75
INSCRIPTION_ANGLE, INSCRIPTION_R = 5.35, 2.42

# ---------------------------------------------------------------- vertical layout
Z_DECK1 = (-0.34, 0.0)
Z_DECK2 = (-0.66, -0.34)
WALL = [  # z0, z1, r_out bottom, r_out top
    (-2.30, -1.97, 3.45, 3.40),
    (-1.97, -1.64, 3.40, 3.35),
    (-1.64, -1.31, 3.35, 3.30),
]
CAVETTO = [(-1.15, -1.00, 3.32), (-1.00, -0.85, 3.43), (-0.85, -0.66, 3.55)]
FOOT = [(-2.45, -2.30, 3.72), (-2.60, -2.45, 3.98)]
R_IN = 2.85                                       # inner radius of every wall block (hidden by the core)
NICHES = [PI / 4 + k * PI / 2 for k in range(4)]
PILASTERS = [k * PI / 2 for k in range(4)]
NICHE_HW = 0.147                                  # half width, radians
NICHE_DEPTH = 0.28


def rw(z):
    """Outer wall radius at height z (battered wall)."""
    return 3.45 + (z + 2.30) * (3.30 - 3.45) / 0.99


from blocks import *  # noqa: E402,F401,F403

W_WALL = [("stone_mid", 38), ("stone_warm", 24), ("stone_light", 12), ("stone_dark", 16),
          ("stone_red", 6), ("stone_pale", 4)]
W_DECK = [("stone_warm", 30), ("stone_light", 28), ("stone_mid", 24), ("stone_pale", 12), ("stone_dark", 6)]


# ---------------------------------------------------------------- the platform body
def build_core(b):
    cylinder(b, "stone_deep", 2.95, -2.55, -0.70)
    cylinder(b, "stone_deep", 3.40, -1.20, -0.66)         # pocket floors live at z=-0.66
    cylinder(b, "stone_deep", 2.30, -0.70, -0.05)         # under the display


def build_footing_and_walls(b):
    rng = random.Random(11)
    for z0, z1, ro in FOOT:                               # stepped footing, big rough slabs
        for a0, a1, k in spans(rng, 0.1, [], 0.30, 0.3):
            pblock(b, rng, pick(rng, W_WALL), R_IN, ro, a0, a1, z0, z1, jit=0.02, jz=0.012, bevel=0.016)
    wins = [(a - NICHE_HW, a + NICHE_HW) for a in NICHES]
    for ci, (z0, z1, rb, rt) in enumerate(WALL):          # battered ashlar courses
        w = wins if ci < 2 else []
        for a0, a1, k in spans(rng, 0.1, w, 0.21, 0.22):
            if k == "blk":
                pblock(b, rng, pick(rng, W_WALL), R_IN, rb, a0, a1, z0, z1, r1t=rt, jit=0.014, jz=0.006, bevel=0.014)
    for z0, z1, ro in CAVETTO:                            # cavetto: three corbelled steps
        for a0, a1, k in spans(rng, 0.3, [], 0.22, 0.2):
            pblock(b, rng, pick(rng, W_WALL), R_IN, ro, a0, a1, z0, z1, jit=0.012, bevel=0.014)


def build_deck(b):
    """Two courses of ring blocks with the roller wells cut out. Returns joint angles of ring D."""
    rng = random.Random(23)
    wells1 = [(a - 0.126, a + 0.126) for a in ROLLER_ANGLES]
    wells2 = [(a - 0.062, a + 0.062) for a in ROLLER_ANGLES]
    d_joints = []
    for ci, (z0, z1) in enumerate((Z_DECK2, Z_DECK1)):
        top = ci == 1
        rings = [  # r0, r1, windows, target length, kind
            (2.32, 2.55, [], 0.26, "basalt"),
            (2.55, 2.66, [], 0.30, "deck"),
            (2.66, 3.04, wells1, 0.24, "deck"),
            (3.04, 3.10, [], 0.40, "deck"),
            (3.10, 3.28, wells2, 0.26, "deck"),
            (3.28, 3.52, [], 0.25, "deck"),
            (3.52, 3.72 if top else 3.66, [], 0.22, "kerb"),
        ]
        for r0, r1, w, tgt, kind in rings:
            for a0, a1, k in spans(rng, 0.6, w, tgt, 0.25):
                if k == "win":
                    continue
                cell = "basalt" if kind == "basalt" and top else pick(rng, W_DECK)
                ztop = z1
                if top and kind == "kerb":
                    ztop = 0.04
                if top and kind == "basalt":
                    cell = "basalt"
                pblock(b, rng, cell, r0, r1, a0, a1, z0, ztop, jit=0.005, jz=0.0015 if top else 0.01,
                       bevel=0.01 if top else 0.0, gap=0.005)
                if top and r0 == 3.28:
                    d_joints.append(a1)
    # bronze bezel around the display, with gold index studs at the four cardinals
    n = 48
    for i in range(n):
        a0, a1 = i * TAU / n, (i + 1) * TAU / n
        cell = "bronze" if i % 2 == 0 else "bronze_dark"
        pblock(b, rng, cell, 2.20, 2.32, a0, a1, Z_DECK1[0], 0.035, jit=0.002, jz=0.002, bevel=0.008, gap=0.004)
    for k in range(4):
        M = frame(k * PI / 2 + PI / 4, 2.26, 0.0)
        lbox(b, "gold", M, (0, 0, 0.035), (0.05, 0.05, 0.012), bevel=0.003)
    return d_joints


def build_deck_furniture(b, d_joints):
    rng = random.Random(31)
    # --- degree scale: studs on ring D every 10 deg, gold at 30
    for i in range(36):
        a = i * TAU / 36
        major = i % 3 == 0
        M = frame(a, 3.40, 0.0)
        if major:
            lbox(b, "gold", M, (0, 0, 0.006), (0.035, 0.16, 0.014))
        else:
            lbox(b, "bronze_dark", M, (0, 0, 0.005), (0.02, 0.08, 0.012))
    # --- bronze butterfly clamps across joints of ring D
    joints = sorted(d_joints)
    for a in joints[::3]:
        M = frame(a, 3.40, 0.0)               # tangent across the joint
        trap(b, "bronze", M, -0.12, -0.012, 0.075, 0.03, 0.0, 0.016)
        trap(b, "bronze", M, 0.012, 0.12, 0.03, 0.075, 0.0, 0.016)
        lbox(b, "bronze_dark", M, (0, 0, 0.0), (0.03, 0.04, 0.02))
    # --- roller wells: bearing plates, axle collars, ratchet pawls
    for a in ROLLER_ANGLES:
        M = frame(a, 0.0)                      # y = radius
        lbox(b, "bronze", M, (0, 2.66 + 0.008, ROLLER_Z), (0.16, 0.016, 0.16))
        lbox(b, "basalt", M, (0, 2.66 + 0.012, ROLLER_Z), (0.07, 0.02, 0.07))
        lbox(b, "bronze", M, (0, 3.04 - 0.008, ROLLER_Z), (0.14, 0.016, 0.14))
        lbox(b, "basalt", M, (0, 3.04 - 0.012, ROLLER_Z), (0.07, 0.02, 0.07))
        # pawl pivoting on a pin set in the slot wall, tip resting on the ratchet teeth
        Wm = frame(a, 3.19)                     # local x tangent, y radial (0 = wheel plane)
        pv = (0.15, 0.0, ROLLER_Z + 0.185)
        tip = (0.058, 0.0, ROLLER_Z + 0.138)
        rod(b, "bronze_dark", Wm, pv, tip, 0.032, 0.04)
        rod(b, "bronze", Wm, pv, (0.15, 0.0, ROLLER_Z + 0.255), 0.016, 0.02)       # leaf spring
        lbox(b, "gold", Wm, (0.15, 0.0, ROLLER_Z + 0.185), (0.05, 0.07, 0.05))      # pivot pin
        lbox(b, "bronze_dark", Wm, (0.172, 0.0, ROLLER_Z + 0.0), (0.03, 0.06, 0.18))  # pin carrier on the wall
        # a hammered wooden wedge keying the cheek
        lbox(b, "wood_dark", frame(a, 3.07), (0.13, 0, 0.0), (0.05, 0.05, 0.02))
    # --- crystal sockets
    for k, a in enumerate(CRYSTAL_ANGLES):
        inlay = ("turquoise", "gold", "paint_red")[k]
        M = frame(a, CRYSTAL_R, 0.0)
        for i in range(8):
            ang = i * TAU / 8 + TAU / 16
            c = (0.30 * math.cos(ang), 0.30 * math.sin(ang), 0.05)
            lbox(b, "stone_pale" if i % 2 else "stone_light", M, c, (0.24, 0.09, 0.10),
                 rot=math.degrees(ang) + 90, bevel=0.01)
        for sy in (-1, 1):                                                      # key-colour inlays, inner and outer face
            lbox(b, inlay, M, (0, sy * 0.355, 0.06), (0.09, 0.02, 0.07), bevel=0.004)
        for i in range(4):                                                        # bronze claws
            ang = i * PI / 2 + PI / 4
            p0 = (0.33 * math.cos(ang), 0.33 * math.sin(ang), 0.02)
            p1 = (0.27 * math.cos(ang), 0.27 * math.sin(ang), 0.34)
            rod(b, "bronze", M, p0, p1, 0.04, 0.03, w1=0.02, h1=0.02)
        for i in range(8):                                                       # rope binding the claws
            ang = i * TAU / 8 + TAU / 16
            lbox(b, "rope" if i % 2 else "rope_dark", M, (0.275 * math.cos(ang), 0.275 * math.sin(ang), 0.21),
                 (0.23, 0.045, 0.045), rot=math.degrees(ang) + 90)
    # --- reset button collar
    M = frame(BUTTON_ANGLE, BUTTON_R, 0.0)
    for i in range(8):
        ang = i * TAU / 8 + TAU / 16
        c = (0.34 * math.cos(ang), 0.34 * math.sin(ang), 0.04)
        lbox(b, "stone_pale" if i % 2 else "stone_light", M, c, (0.28, 0.1, 0.08), rot=math.degrees(ang) + 90, bevel=0.01)
    for i in range(8):
        ang = i * TAU / 8
        M2 = M @ Matrix.Rotation(ang, 4, "Z")
        lbox(b, "gold" if i % 2 == 0 else "bronze_dark", M2, (0, 0.42, 0.02), (0.05, 0.04, 0.03))
    # --- carved sun rays on the deck around the collar are left to the glyph pass


def build_deck_edge(b):
    """Khekher (reed) frieze on the lower deck course, sunk-relief glyphs on the upper course."""
    # khekher: a row of painted reed heads (ochre / blue / green) just under the deck overhang
    n = 48
    for i in range(n):
        a = (i + 0.5) * TAU / n
        M = frame(a, 3.66, 0.0)
        cell = ("paint_ochre", "paint_blue", "paint_green")[i % 3]
        lbox(b, cell, M, (0, 0.012, -0.50), (0.12, 0.04, 0.16))
    # glyph frieze on the upper course face
    seq = ["ankh", "water", "eye", "was", "djed", "water"]
    cnt = 30
    for i in range(cnt):
        a = (i + 0.5) * TAU / cnt
        if abs(((a - BUTTON_ANGLE + PI) % TAU) - PI) < 0.0:   # nothing special near the button
            continue
        glyph(b, seq[i % len(seq)], frame(a, 3.715, -0.17), "stone_deep")
    # A-frame level with plumb line on the kerb (the engineer's toy)
    a_frame_level(b, frame(2.18, 3.62, 0.04))


def glyph(b, name, M, cell, s=1.0):
    """Tiny relief glyphs from thin plates, local x = along the frieze, local z = up, y = out."""
    def pl(x, z, w, h, c=cell):
        lbox(b, c, M, (x * s, 0.0, z * s), (w * s, 0.03, h * s))
    if name == "ankh":
        pl(0, -0.02, 0.026, 0.19); pl(0, 0.015, 0.1, 0.026)
        pl(-0.03, 0.075, 0.022, 0.07); pl(0.03, 0.075, 0.022, 0.07); pl(0, 0.105, 0.08, 0.022); pl(0, 0.045, 0.08, 0.022)
    elif name == "water":
        for row in (-0.05, 0.03):
            for k in range(3):
                x = -0.09 + k * 0.09
                lbox(b, cell, M, (x * s, 0, row * s), (0.05 * s, 0.03, 0.018 * s), rot=0, R=Matrix.Rotation(0.6, 4, "Y"))
                lbox(b, cell, M, ((x + 0.045) * s, 0, row * s), (0.05 * s, 0.03, 0.018 * s), R=Matrix.Rotation(-0.6, 4, "Y"))
    elif name == "eye":
        pl(0, 0.0, 0.2, 0.025); pl(-0.07, 0.025, 0.07, 0.022); pl(0.07, 0.025, 0.07, 0.022)
        pl(0, 0.0, 0.05, 0.05, "lapis"); pl(0, 0.07, 0.2, 0.02); pl(0.03, -0.065, 0.026, 0.07); pl(0.075, -0.1, 0.07, 0.02)
    elif name == "was":
        pl(0, 0.0, 0.026, 0.2); pl(-0.04, 0.095, 0.07, 0.03); pl(-0.03, -0.1, 0.026, 0.05); pl(0.03, -0.1, 0.026, 0.05)
    elif name == "djed":
        pl(0, -0.02, 0.04, 0.18)
        for z in (0.0, 0.04, 0.08):
            pl(0, z, 0.12, 0.02)
        pl(0, 0.115, 0.04, 0.03)


def a_frame_level(b, M):
    """A-frame plumb level: two wooden legs, a cross-bar with a bronze scale, a hanging plumb bob."""
    lbox(b, "stone_pale", M, (0, 0, 0.03), (0.52, 0.2, 0.06), bevel=0.01)
    rod(b, "wood_dark", M, (-0.2, 0, 0.06), (-0.01, 0, 0.62), 0.045, 0.05)
    rod(b, "wood_dark", M, (0.2, 0, 0.06), (0.01, 0, 0.62), 0.045, 0.05)
    lbox(b, "wood_light", M, (0, 0, 0.26), (0.30, 0.05, 0.04))
    for i in range(-5, 6):
        lbox(b, "bronze" if i else "gold", M, (i * 0.024, -0.03, 0.26), (0.01, 0.01, 0.04 if i % 5 == 0 else 0.025))
    lbox(b, "bronze", M, (0, 0, 0.64), (0.07, 0.07, 0.04))
    rod(b, "rope", M, (0, -0.05, 0.62), (0, -0.05, 0.19), 0.014, 0.014)
    prism(b, "bronze", M, 6, 0.0001, 0.035, 0.07, 0.19, c=(0, -0.05))                 # plumb bob, tip down


# ---------------------------------------------------------------- the wall: rope, pilasters, niches
def build_wall_details(b):
    rng = random.Random(41)
    # torus-roll rope round the top of the wall, with a hanging tail
    N = 64
    for i in range(N):
        a = (i + 0.5) * TAU / N
        M = frame(a, 3.33, -1.23)
        chord = 2 * 3.33 * math.sin(PI / N) * 1.18
        lbox(b, "rope" if i % 2 == 0 else "rope_dark", M, (0, 0, 0), (chord, 0.15, 0.15),
             R=Matrix.Rotation(math.radians(45 * (i % 2)), 4, "X"))
    ta = 3 * PI / 2 + 0.35
    lbox(b, "rope_dark", frame(ta, 3.42, -1.30), (0, 0, 0), (0.2, 0.13, 0.2), bevel=0.02)       # knot
    for j in range(5):
        lbox(b, "rope" if j % 2 == 0 else "rope_dark", frame(ta + 0.01 * j, 3.38 + 0.01 * j, -1.46 - j * 0.1), (0.0, 0.0, 0.0),
             (0.07, 0.07, 0.115), R=Matrix.Rotation(math.radians(40 * j), 4, "Z"))
    # lifting bosses with rope loops on the first footing step
    for k in range(6):
        a = 0.35 + k * TAU / 6
        M = frame(a, 3.70, -2.375)
        lbox(b, "stone_warm", M, (0, 0.04, 0), (0.34, 0.14, 0.11), bevel=0.012)
        for sx in (-1, 1):
            lbox(b, "rope" if sx > 0 else "rope_dark", M, (sx * 0.075, 0.12, -0.02), (0.035, 0.035, 0.15))
        lbox(b, "rope_dark", M, (0, 0.12, -0.095), (0.18, 0.035, 0.035))
    # papyrus-bundle pilasters
    for a in PILASTERS:
        M = frame(a, rw(-1.8) - 0.04)
        lbox(b, "stone_light", M, (0, 0.04, -2.23), (0.56, 0.26, 0.14), top=(0.92, 0.9), bevel=0.012)         # plinth
        for sx, wd in ((-1, 0.15), (0, 0.18), (1, 0.15)):
            lbox(b, "stone_warm" if sx == 0 else "stone_mid", M, (sx * 0.15, 0.05, -1.80), (wd, 0.2, 0.62),
                 top=(0.9, 0.9), bevel=0.01)
        for z in (-2.0, -1.62):
            lbox(b, "rope", M, (0, 0.05, z), (0.50, 0.25, 0.05), bevel=0.006)
            lbox(b, "rope_dark", M, (0, 0.05, z + 0.025), (0.52, 0.26, 0.012))
        lbox(b, "stone_light", M, (0, 0.05, -1.44), (0.50, 0.24, 0.10), top=(1.0, 1.0), bevel=0.01)        # bud neck
        lbox(b, "stone_warm", M, (0, 0.05, -1.37), (0.46, 0.22, 0.10), top=(0.75, 0.8), bevel=0.01)        # bud
        lbox(b, "lapis", M, (0, 0.05, -1.50), (0.51, 0.255, 0.018))
        lbox(b, "turquoise", M, (0, 0.05, -1.47), (0.505, 0.25, 0.012))
    for i, a in enumerate(NICHES):
        niche(b, i, a)


def niche(b, i, a):
    r_back = rw(-1.97) - NICHE_DEPTH
    r0 = r_back * math.cos(NICHE_HW)
    M = frame(a, r0)                                   # y=0 on the back wall, z absolute
    half = r_back * math.sin(NICHE_HW)
    lbox(b, "stone_dark", M, (0, -0.1, -1.97), (2 * half + 0.05, 0.22, 0.66))        # back wall slab
    lbox(b, "stone_pale", M, (0, NICHE_DEPTH + 0.0, -1.58), (2 * half + 0.34, 0.1, 0.1), bevel=0.01)   # architrave
    lbox(b, "stone_light", M, (0, NICHE_DEPTH - 0.02, -1.505), (2 * half + 0.46, 0.14, 0.06), top=(0.97, 0.9), bevel=0.01)
    NICHE_FN[i](b, M, half)


def n_gears(b, M, half):
    lbox(b, "wood_dark", M, (0, 0.012, -1.97), (2 * half - 0.06, 0.02, 0.6))
    m = 0.028
    p1, p2, p3 = 12 * m / 2, 16 * m / 2, 8 * m / 2
    c1 = Vector((-0.30, -2.07))
    c2 = c1 + Vector((math.cos(0.52), math.sin(0.52))) * (p1 + p2)
    c3 = c2 + Vector((math.cos(-0.62), math.sin(-0.62))) * (p2 + p3)
    gear(b, M, c1, 12, p1, m, 0.05, "bronze", 0.0, 0.10)
    gear(b, M, c2, 16, p2, m, 0.05, "bronze_dark", PI / 16, 0.10)
    gear(b, M, c3, 8, p3, m, 0.05, "bronze", PI / 8, 0.10)
    for c, rr in ((c1, 0.04), (c2, 0.05), (c3, 0.035)):
        lbox(b, "wood_dark", M, (c.x, 0.07, c.y), (0.04, 0.12, 0.04))
        lbox(b, "gold", M, (c.x, 0.145, c.y), (rr * 1.2, 0.03, rr * 1.2), bevel=0.006)
    # a bronze rack with a hand-lever driving the big gear
    lbox(b, "bronze_dark", M, (c2.x + 0.0, 0.10, c2.y + 0.30), (0.34, 0.04, 0.03))
    lbox(b, "wood_light", M, (c3.x + 0.12, 0.10, c3.y - 0.02), (0.04, 0.04, 0.26), R=Matrix.Rotation(0.3, 4, "Y"))
    lbox(b, "turquoise", M, (c1.x - 0.02, 0.15, c1.y), (0.03, 0.02, 0.03))


def n_clock(b, M, half):
    lbox(b, "stone_pale", M, (-0.1, 0.12, -1.995), (0.62, 0.22, 0.05), bevel=0.008)               # shelf
    prism(b, "stone_warm", M, 8, 0.15, 0.21, -1.97, -1.69, off=TAU / 16, c=(-0.1, 0.12), caps=("stone_warm", "water"))
    lbox(b, "bronze", M, (-0.1, 0.12 + 0.20, -1.93), (0.05, 0.08, 0.04))                           # spigot
    for j, (dz, s) in enumerate(((0.07, 0.022), (0.14, 0.018), (0.2, 0.014))):
        lbox(b, "water", M, (-0.1, 0.12 + 0.235, -1.93 - dz), (s, s, s * 1.4))
    prism(b, "stone_warm", M, 8, 0.2, 0.17, -2.30, -2.15, off=TAU / 16, c=(-0.1, 0.12 + 0.235), caps=("stone_warm", "water"))
    # float gauge: post with tick marks, wooden float, bronze pointer
    lbox(b, "wood_dark", M, (0.30, 0.12, -2.05), (0.05, 0.05, 0.5), top=(0.8, 0.8))
    for k in range(7):
        lbox(b, "bronze" if k % 3 else "gold", M, (0.30, 0.12 + 0.03, -2.27 + k * 0.055), (0.07 if k % 3 == 0 else 0.045, 0.012, 0.012))
    lbox(b, "wood_light", M, (0.30, 0.12 + 0.045, -2.08), (0.09, 0.05, 0.05))
    lbox(b, "bronze", M, (0.34, 0.12 + 0.07, -2.08), (0.07, 0.02, 0.02))
    lbox(b, "stone_dark", M, (-0.36, 0.1, -2.255), (0.14, 0.14, 0.09), top=(0.8, 0.8))             # counter-weight


def n_door(b, M, half):
    for k in range(5):
        lbox(b, "wood_light" if k % 2 == 0 else "wood_dark", M, (-0.38 + k * 0.19, 0.075, -1.97), (0.185, 0.07, 0.62), bevel=0.006)
    for z in (-1.80, -2.14):
        lbox(b, "bronze_dark", M, (0, 0.118, z), (0.96, 0.02, 0.07))
        for sx in (-1, 0, 1):
            lbox(b, "gold", M, (sx * 0.4, 0.13, z), (0.04, 0.02, 0.04))
    # sliding wooden bolt through bronze staples, with peg holes
    lbox(b, "wood_dark", M, (0.1, 0.16, -1.97), (0.56, 0.04, 0.05))
    for sx in (-0.12, 0.32):
        lbox(b, "bronze", M, (sx, 0.14, -1.97), (0.06, 0.06, 0.09))
    for k in range(3):
        lbox(b, "stone_deep", M, (-0.04 + k * 0.1, 0.182, -1.97), (0.018, 0.01, 0.018))
    # ring pull on a rosette
    lbox(b, "bronze_dark", M, (-0.2, 0.14, -1.97), (0.12, 0.025, 0.12), R=Matrix.Rotation(PI / 4, 4, "Y"))
    for q in range(4):
        R = Matrix.Rotation(math.radians(45 + q * 90), 4, "Y")
        lbox(b, "bronze", M, (-0.2 + 0.05 * math.cos(math.radians(q * 90 + 45)), 0.17, -1.97 + 0.05 * math.sin(math.radians(q * 90 + 45))),
             (0.07, 0.025, 0.025), R=R)
    lbox(b, "rope", M, (-0.2, 0.19, -2.04), (0.03, 0.03, 0.09))
    lbox(b, "rope_dark", M, (-0.2, 0.19, -2.10), (0.05, 0.05, 0.05))


def n_windlass(b, M, half):
    for sx in (-1, 1):                                  # A-frame posts
        rod(b, "wood_dark", M, (sx * 0.42, 0.04, -2.28), (sx * 0.38, 0.14, -1.94), 0.07, 0.07)
        rod(b, "wood_dark", M, (sx * 0.42, 0.24, -2.28), (sx * 0.38, 0.14, -1.94), 0.07, 0.07)
        lbox(b, "bronze", M, (sx * 0.385, 0.14, -1.94), (0.09, 0.09, 0.07), bevel=0.006)
    ax = Matrix.Rotation(PI / 2, 4, "Y")               # local Z -> world X: spool axis along the tangent
    Ms = M @ Matrix.Translation((0, 0.14, -1.94)) @ ax
    prism(b, "wood_light", Ms, 8, 0.12, 0.12, -0.34, 0.34, off=TAU / 16)
    for k in range(9):                                  # rope wound on the spool
        prism(b, "rope" if k % 2 == 0 else "rope_dark", Ms, 8, 0.145, 0.145, -0.20 + k * 0.045, -0.20 + k * 0.045 + 0.04, off=TAU / 16)
    lbox(b, "wood_dark", M, (0.46, 0.14, -2.02), (0.05, 0.05, 0.19))                              # crank arm
    lbox(b, "wood_light", M, (0.46, 0.14 + 0.09, -2.11), (0.05, 0.14, 0.05))                       # handle
    lbox(b, "bronze", M, (-0.46, 0.14, -1.94), (0.04, 0.05, 0.05))
    for j in range(4):                                  # rope hanging to a lifted block
        lbox(b, "rope" if j % 2 == 0 else "rope_dark", M, (0.0, 0.24, -2.02 - j * 0.045), (0.06, 0.06, 0.047))
    lbox(b, "stone_dark", M, (0.0, 0.24, -2.245), (0.17, 0.17, 0.11), bevel=0.01)
    lbox(b, "stone_pale", M, (-0.28, 0.2, -2.26), (0.2, 0.2, 0.04), bevel=0.008)                  # chock / tool slab


NICHE_FN = [n_gears, n_clock, n_door, n_windlass]


# ---------------------------------------------------------------- controls (separate meshes)
def build_roller(b):
    """Local +X = the roller's axis (outward), origin = centre of the roller."""
    ax = Matrix.Rotation(PI / 2, 4, "Y")              # prism Z -> X
    facets = ["wood_light", "wood_dark"]
    prism(b, "wood_light", ax, 8, ROLLER_R / math.cos(PI / 8) * 0.97, ROLLER_R / math.cos(PI / 8) * 0.97, -0.15, 0.15,
          off=TAU / 16, cells=facets)
    for sgn in (-1, 1):                               # bronze end caps
        z0, z1 = (0.15, 0.18) if sgn > 0 else (-0.18, -0.15)
        prism(b, "bronze", ax, 8, 0.325, 0.325, z0, z1, off=TAU / 16)
        prism(b, "gold", ax, 8, 0.10, 0.10, z1 if sgn > 0 else z0 - 0.0, z1 + 0.012 if sgn > 0 else z0 - 0.012, off=TAU / 16)
    for x in (-0.11, 0.11):                           # rope lashings
        prism(b, "rope", ax, 8, 0.318, 0.318, x - 0.022, x + 0.022, off=TAU / 16)
        prism(b, "rope_dark", ax, 8, 0.322, 0.322, x - 0.008, x + 0.008, off=TAU / 16)
    M = Matrix.Identity(4)
    lbox(b, "gold", M, (0, 0, 0.292), (0.15, 0.10, 0.02), bevel=0.004)            # marker inlay on the top facet
    # axle through the cheeks and a ratchet wheel outside the outer cheek
    lbox(b, "bronze_dark", M, (0.12, 0, 0), (0.54, 0.07, 0.07))
    Mw = Matrix(((0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))  # swap x/y: the wheel's axis (local y) lies along the roller axis (x)
    gear(b, Mw, (0, 0), 12, 0.115, 0.03, 0.05, "bronze", 0.0, 0.34)
    lbox(b, "gold", M, (0.34, 0, 0), (0.07, 0.09, 0.09), bevel=0.008)


def build_button(b):
    prism(b, "bronze_dark", Matrix.Identity(4), 8, 0.27, 0.25, 0.0, 0.08, off=TAU / 16)
    prism(b, "bronze", Matrix.Identity(4), 8, 0.25, 0.20, 0.08, 0.16, off=TAU / 16)
    prism(b, "gold", Matrix.Identity(4), 8, 0.14, 0.12, 0.16, 0.18, off=TAU / 16)
    for k in range(8):
        a = k * TAU / 8
        lbox(b, "paint_red", Matrix.Rotation(a, 4, "Z"), (0, 0.19, 0.09), (0.03, 0.02, 0.05), top=(0.6, 1))


# ---------------------------------------------------------------- scene assembly + export
def finish(b, name, mat):
    ob = b.finish(name)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


def main():
    bl.reset_scene()
    mat = bl.make_material()

    plat = bl.Builder()

    def tris():
        return sum(len(f.verts) - 2 for f in plat.bm.faces)
    last = [0]

    def stage(name, *a):
        r = globals()["build_" + name](plat, *a)
        print(f"  {name:22s} +{tris() - last[0]:6d} tris")
        last[0] = tris()
        return r
    stage("core")
    stage("footing_and_walls")
    joints = stage("deck")
    stage("deck_furniture", joints)
    stage("deck_edge")
    stage("wall_details")
    platform = finish(plat, "Platform", mat)

    disc = bl.Builder()
    prism(disc, "basalt", Matrix.Identity(4), 64, R_DISPLAY, R_DISPLAY, -0.02, 0.0)
    display = finish(disc, "DisplaySurface", mat)

    rb = bl.Builder()
    build_roller(rb)
    roller = finish(rb, "roller_0", mat)
    roller.location = P(ROLLER_C, ROLLER_ANGLES[0], ROLLER_Z)
    roller.rotation_euler = (0, 0, -ROLLER_ANGLES[0])
    for i in (1, 2, 3):
        ob = bpy.data.objects.new(f"roller_{i}", roller.data)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = P(ROLLER_C, ROLLER_ANGLES[i], ROLLER_Z)
        ob.rotation_euler = (0, 0, -ROLLER_ANGLES[i])

    bb = bl.Builder()
    build_button(bb)
    button = finish(bb, "reset_button", mat)
    button.location = P(BUTTON_R, BUTTON_ANGLE, 0.01)

    def empty(name, loc):
        e = bpy.data.objects.new(name, None)
        e.location = loc
        e.empty_display_type = "PLAIN_AXES"
        bpy.context.scene.collection.objects.link(e)
        return e
    for k, a in enumerate(CRYSTAL_ANGLES):
        empty(f"crystal_socket_{k}", P(CRYSTAL_R, a, 0.0))
    empty("inscription_anchor", P(INSCRIPTION_R, INSCRIPTION_ANGLE, 0.0))

    out_blend = os.path.join(HERE, "newton_platform.blend")
    out_glb = os.path.join(os.path.dirname(ROOT), "godot", "assets", "props", "newton_platform.glb")
    os.makedirs(os.path.dirname(out_glb), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True,
                              export_image_format="AUTO", export_cameras=False, export_lights=False,
                              export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=True)
    print(f"platform tris={bl.tri_count(platform)} roller={bl.tri_count(roller)} button={bl.tri_count(button)}")


main()
