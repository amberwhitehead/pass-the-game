"""Turing Table platform: a round Roman machine-house (two-tier arcade, brick and travertine) carrying the table.

    blender -b -P blends/props/turing_platform.py
Output: blends/props/turing_platform.blend and godot/assets/props/turing_platform.glb

Same conventions as newton_platform.py (game scale, display disc r=2.2 with its surface at z=0, game angles as in
turing.gd, shared palette, blocks library). Exported nodes (one shared palette material):
  Platform          static body: arcade with eight machines behind the arches, entablature, deck, trays, collars
  DisplaySurface    flat disc r=2.2 just below z=0 for the reaction-diffusion material
  roller_0..3       feed, kill, Du, Dv. Origin = roller centre, axis = local +X pointing OUTWARD (as in turing.gd)
  reset_button, viz_button   plungers (origin on the deck; press = move down ~0.05)
  tray_anchor_0/1   empties at the cylinder trays (amber, teal); the stacks of glass cylinders stand here
  inscription_anchor  empty at the middle of the smooth porphyry track for the inscription text
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

# ---------------------------------------------------------------- game-side layout (turing.gd)
R_DISPLAY = 2.2
ROLLER_ANGLES = [PI / 2, PI / 4, 0.0, -PI / 4]          # feed, kill, du, dv
ROLLER_R, ROLLER_LEN, ROLLER_C, ROLLER_Z = 0.30, 0.30, 2.85, -0.24
BUTTONS = {"reset": (-PI / 2, 2.55), "viz": (-3 * PI / 4, 2.55)}
TRAYS = [(PI, 2.7), (3 * PI / 4, 2.7)]                  # amber, teal
INSCRIPTION_ANGLE, INSCRIPTION_R = 0.4, 2.42
RIM_ANGLES = [PI / 2 - i * PI / 4 for i in range(8)]

# ---------------------------------------------------------------- vertical layout
Z_DECK1 = (-0.34, 0.0)
Z_DECK2 = (-0.66, -0.34)
Z_FLOOR = -2.30                      # arcade floor (top of the podium)
Z_TIER = -1.05                       # top of the arcade
R_WALL = 3.55
R_BACK = 3.0                         # inner face of the wall blocks (behind the arches)
NB = 16                              # bays
AR = 0.37                            # arch intrados radius
ZS = -1.675                          # springing line
VOUS = 0.12                          # voussoir depth
COURSE_H = 0.125

W_BRICK = [("brick_red", 40), ("brick_light", 24), ("brick_dark", 26), ("brick_red", 10)]
W_PAVE = [("marble_cream", 1), ("travertine", 1)]


def bay_angle(k):
    return (k + 0.5) * TAU / NB


# ---------------------------------------------------------------- body
def build_core(b):
    cylinder(b, "concrete_dark", R_BACK, Z_FLOOR - 0.25, -0.70)
    cylinder(b, "concrete_dark", 3.40, -1.20, -0.66)
    cylinder(b, "concrete_dark", 2.30, -0.70, -0.05)


def build_podium(b):
    rng = random.Random(5)
    for z0, z1, ro, off in ((-2.60, -2.45, 3.98, 0.0), (-2.45, -2.30, 3.80, 0.5)):
        n = 40
        for i in range(n):
            a0, a1 = (i + off) * TAU / n, (i + 1 + off) * TAU / n
            cell = ("travertine", "travertine_dark", "marble_cream")[(i * 7 + (1 if off else 0)) % 3]
            pblock(b, rng, cell, 2.85, ro, a0, a1, z0, z1, jit=0.0, jz=0.0, bevel=0.01, gap=0.004, hollow=True)


def window_half(z_lo):
    """Opening half-width (metres) the wall courses must leave open at height z_lo (course bottom)."""
    if z_lo < ZS + 1e-6:
        return AR
    d = z_lo - ZS
    return math.sqrt(AR * AR - d * d) if d < AR else 0.0


def build_arcade(b):
    rng = random.Random(17)
    n_courses = int(round((Z_TIER - Z_FLOOR) / COURSE_H))
    for i in range(n_courses):
        z0 = Z_FLOOR + i * COURSE_H
        z1 = z0 + COURSE_H
        hw = window_half(z0)
        wins = [(bay_angle(k) - hw / 3.45, bay_angle(k) + hw / 3.45) for k in range(NB)] if hw > 0.02 else []
        start = 0.0 if i % 2 == 0 else 0.07
        bonding = i in (0, 5, n_courses - 1)
        for a0, a1, kind in spans(rng, start, wins, 0.21, 0.0):
            if kind == "win":
                continue
            cell = "travertine" if bonding else pick(rng, W_BRICK)
            pblock(b, rng, cell, R_BACK, R_WALL, a0, a1, z0, z1, jit=0.0, jz=0.0, bevel=0.0, gap=0.005, hollow=True)
    # voussoir arches with keystones, impost blocks, back slabs
    for k in range(NB):
        a = bay_angle(k)
        M = frame(a, 3.30)
        yb, yf = -0.30, 0.30                         # wall thickness band; the face sits slightly proud
        n = 9
        for j in range(n):
            t0, t1 = j * PI / n, (j + 1) * PI / n
            key = j == n // 2
            ri, ro = AR, AR + VOUS + (0.05 if key else 0.0)
            if key:
                t0, t1 = t0 - 0.03, t1 + 0.03

            def pt(r, t, y):
                return M @ Vector((r * math.cos(t), y, ZS + r * math.sin(t)))
            cs = [pt(ri, t0, yb), pt(ro, t0, yb), pt(ro, t1, yb), pt(ri, t1, yb),
                  pt(ri, t0, yf), pt(ro, t0, yf), pt(ro, t1, yf), pt(ri, t1, yf)]
            cell = "marble" if key else ("travertine" if j % 2 == 0 else "brick_light")
            solid(b, cs, cell, 0.0)
        for sx in (-1, 1):                           # imposts
            lbox(b, "travertine", M, (sx * (AR + 0.01), 0.0, ZS - 0.035), (0.2, 0.62, 0.07))
        lbox(b, "travertine_dark", M, (0, -0.02, (Z_FLOOR + ZS) / 2 + 0.05), (2 * R_BACK * math.sin(0.115) + 0.1, 0.1, 1.1))
        BAY_FN[k % 2](b, k, M)
    # engaged Tuscan half-columns on every pier
    for k in range(NB):
        a = k * TAU / NB
        M = frame(a, R_WALL + 0.02)
        cells = ["marble", "travertine"]
        prism(b, "travertine", M, 8, 0.19, 0.19, Z_FLOOR, Z_FLOOR + 0.06, off=TAU / 16)
        prism(b, "marble", M, 12, 0.13, 0.11, Z_FLOOR + 0.06, Z_TIER - 0.11, off=TAU / 24, cells=cells)
        prism(b, "travertine", M, 12, 0.11, 0.175, Z_TIER - 0.11, Z_TIER - 0.05, off=TAU / 24)
        lbox(b, "marble", M, (0, 0, Z_TIER - 0.025), (0.38, 0.38, 0.05))


def build_entablature(b):
    rng = random.Random(29)
    ring = [  # z0, z1, r_out, cell group
        (Z_TIER, -0.92, 3.60, "travertine"),
        (-0.92, -0.74, 3.57, "brick"),
        (-0.74, -0.66, 3.64, "travertine_dark"),
    ]
    n = 32
    for z0, z1, ro, kind in ring:
        for i in range(n):
            a0, a1 = (i + 0.25) * TAU / n, (i + 1.25) * TAU / n
            cell = pick(rng, W_BRICK) if kind == "brick" else kind
            pblock(b, rng, cell, R_BACK, ro, a0, a1, z0, z1, jit=0.0, jz=0.0, bevel=0.0, gap=0.004, hollow=True)
    # Doric frieze: a triglyph over every pier and every arch
    for i in range(32):
        a = i * TAU / 32
        M = frame(a, 3.58)
        for sx in (-1, 1):
            lbox(b, "travertine", M, (sx * 0.04, 0.02, -0.83), (0.06, 0.045, 0.16))
    # dentils under the corona
    for i in range(64):
        a = (i + 0.5) * TAU / 64
        lbox(b, "marble", frame(a, 3.65), (0, 0.025, -0.70), (0.085, 0.07, 0.08))


# ---------------------------------------------------------------- machines in the arches
def bay_grille(b, k, M):
    """Plain bays: a bronze grille over a small glowing oil lamp."""
    for i in range(-2, 3):
        rod(b, "bronze", M, (i * 0.14, 0.42, Z_FLOOR), (i * 0.14, 0.42, ZS - 0.02), 0.025, 0.025)
    for z in (-2.20, -1.95, ZS - 0.06):
        lbox(b, "bronze", M, (0, 0.42, z), (0.74, 0.03, 0.03))
    lbox(b, "bronze_dark", M, (0, 0.18, Z_FLOOR + 0.04), (0.16, 0.12, 0.08), bevel=0.008)
    lbox(b, "glow_amber", M, (0, 0.18, Z_FLOOR + 0.10), (0.04, 0.04, 0.07), top=(0.4, 0.4))


def m_wheel(b, k, M):
    y0, z0, R = 0.22, -1.97, 0.28
    for sx in (-1, 1):
        lbox(b, "wood_dark", M, (sx * 0.16, y0, (z0 + Z_FLOOR) / 2), (0.05, 0.07, z0 - Z_FLOOR), bevel=0.004)
    lbox(b, "bronze", M, (0, y0, z0), (0.36, 0.05, 0.05))
    for i in range(4):
        ang = math.radians(i * 45)
        for sx in (-0.07, 0.07):
            lbox(b, "wood_light", M, (sx, y0, z0), (0.03, 2 * R - 0.06, 0.03), R=Matrix.Rotation(ang, 4, "X"))
    for i in range(8):
        ang = math.radians(i * 45 + 22.5)
        c = (0.0, y0 + (R - 0.01) * math.cos(ang), z0 + (R - 0.01) * math.sin(ang))
        lbox(b, "wood_dark", M, c, (0.2, 0.11, 0.025), R=Matrix.Rotation(ang, 4, "X"))
    lbox(b, "gold", M, (0, y0, z0), (0.1, 0.06, 0.06))
    rod(b, "lead", M, (0.0, 0.02, -1.62), (0.0, y0 + 0.05, z0 + R + 0.1), 0.06)                      # lead flume
    lbox(b, "water", M, (0, y0 + 0.02, Z_FLOOR + 0.03), (0.4, 0.34, 0.025))


def m_gears(b, k, M):
    m = 0.022
    lbox(b, "wood_dark", M, (0, 0.012, (Z_FLOOR + ZS) / 2 + 0.1), (0.58, 0.02, 0.8))   # darker board behind the gears
    c1 = Vector((0.04, -2.03)); p1 = 14 * m / 2
    c2 = c1 + Vector((0.0, 1.0)) * (p1 + 10 * m / 2)
    c3 = c1 + Vector((math.cos(math.radians(190)), math.sin(math.radians(190)))) * (p1 + 8 * m / 2)
    gear(b, M, c1, 14, p1, m, 0.05, "bronze", 0.0, 0.10)
    gear(b, M, c2, 10, 10 * m / 2, m, 0.05, "bronze_dark", PI / 10, 0.10)
    gear(b, M, c3, 8, 8 * m / 2, m, 0.05, "bronze", PI / 8 + 0.15, 0.10)
    for c in (c1, c2, c3):
        lbox(b, "wood_dark", M, (c.x, 0.07, c.y), (0.035, 0.12, 0.035))
        lbox(b, "gold", M, (c.x, 0.14, c.y), (0.05, 0.03, 0.05), bevel=0.005)
    # hodometer-style counting dial above the train
    prism(b, "bronze", M @ Matrix.Rotation(-PI / 2, 4, "X"), 12, 0.1, 0.1, -0.15, -0.12, c=(c2.x, -c2.y - 0.3 + 0.0))
    for i in range(12):
        ang = i * TAU / 12
        lbox(b, "gold" if i % 3 == 0 else "bronze_dark", M, (c2.x + 0.075 * math.cos(ang), 0.156, c2.y + 0.30 + 0.075 * math.sin(ang)),
             (0.014, 0.012, 0.014))


def m_screw(b, k, M):
    p0, p1 = Vector((-0.17, 0.22, -2.20)), Vector((0.17, 0.22, -1.50))
    d = (p1 - p0).normalized()
    rod(b, "wood_dark", M, p0, p1, 0.07, 0.07)
    for i in range(14):
        t = 0.04 + i * 0.065
        pc = p0 + (p1 - p0) * t
        rod(b, "wood_light", M, pc, pc + d * 0.035, 0.22, 0.022, roll=i * 38)
    for t in (0.0, 0.5, 1.0):
        pc = p0 + (p1 - p0) * t
        rod(b, "bronze", M, pc - d * 0.02, pc + d * 0.02, 0.13, 0.13)
    lbox(b, "wood_dark", M, (0.19, 0.22, -1.40), (0.04, 0.16, 0.04))                            # crank
    lbox(b, "wood_light", M, (0.19, 0.30, -1.40), (0.04, 0.04, 0.10))
    lbox(b, "water", M, (-0.1, 0.22, Z_FLOOR + 0.03), (0.4, 0.34, 0.025))
    lbox(b, "travertine_dark", M, (-0.2, 0.22, Z_FLOOR + 0.05), (0.12, 0.3, 0.1))


def m_aeolipile(b, k, M):
    c = (0.0, 0.2)
    Mz = M
    prism(b, "marble", Mz, 8, 0.15, 0.09, Z_FLOOR, Z_FLOOR + 0.28, off=TAU / 16, c=c)
    prism(b, "bronze_dark", Mz, 8, 0.13, 0.13, Z_FLOOR + 0.28, Z_FLOOR + 0.31, off=TAU / 16, c=c)
    zc = Z_FLOOR + 0.31
    prism(b, "bronze", Mz, 8, 0.08, 0.15, zc, zc + 0.08, off=TAU / 16, c=c)
    prism(b, "bronze", Mz, 8, 0.15, 0.15, zc + 0.08, zc + 0.22, off=TAU / 16, c=c)
    prism(b, "bronze", Mz, 8, 0.15, 0.08, zc + 0.22, zc + 0.30, off=TAU / 16, c=c)
    lbox(b, "gold", M, (0.0, 0.2, zc + 0.32), (0.06, 0.06, 0.04), bevel=0.006)
    zj = zc + 0.15
    for sx in (-1, 1):                                  # the two bent steam jets
        rod(b, "bronze_dark", M, (sx * 0.14, 0.2, zj), (sx * 0.21, 0.2, zj), 0.04)
        rod(b, "bronze_dark", M, (sx * 0.21, 0.2, zj), (sx * 0.21, 0.2 + sx * 0.08, zj), 0.04)
        lbox(b, "bronze", M, (sx * 0.21, 0.2, zj - 0.01), (0.05, 0.05, 0.05))
    lbox(b, "bronze", M, (0.0, 0.2, Z_FLOOR + 0.31), (0.30, 0.04, 0.04))
    lbox(b, "bronze_dark", M, (0.0, 0.2, Z_FLOOR + 0.31), (0.04, 0.30, 0.04))


def m_ballista(b, k, M):
    """Torsion-spring bolt thrower on a marble plinth: rope-sinew bundles, two arms, drawn string, loaded bolt."""
    zb = Z_FLOOR + 0.30
    lbox(b, "marble", M, (0, 0.24, Z_FLOOR + 0.15), (0.50, 0.46, 0.30), bevel=0.01)
    z = zb + 0.17
    rod(b, "wood_dark", M, (0, 0.02, zb + 0.06), (0, 0.46, zb + 0.06), 0.07, 0.05)
    for sx in (-1, 1):
        lbox(b, "wood_dark", M, (sx * 0.19, 0.27, zb + 0.14), (0.12, 0.14, 0.30), bevel=0.005)
        prism(b, "rope", M, 8, 0.065, 0.065, zb + 0.06, zb + 0.30, off=TAU / 16, c=(sx * 0.19, 0.27))
        rod(b, "bronze", M, (sx * 0.19, 0.27, zb + 0.31), (sx * 0.19, 0.27, zb + 0.34), 0.1, 0.1)
        rod(b, "wood_light", M, (sx * 0.19, 0.27, z), (sx * 0.30, 0.06, z), 0.045, 0.04)
    rod(b, "rope_dark", M, (-0.30, 0.06, z), (0.30, 0.06, z), 0.014)
    rod(b, "bronze_dark", M, (0, 0.06, z), (0, 0.50, z), 0.026, 0.026)
    lbox(b, "bronze", M, (0, 0.50, z), (0.05, 0.07, 0.05), top=(0.3, 1))
    lbox(b, "bronze", M, (0, 0.09, z), (0.08, 0.06, 0.06))


def m_crane(b, k, M):
    post = (-0.2, 0.2)
    rod(b, "wood_dark", M, (post[0], post[1], Z_FLOOR), (post[0], post[1], -1.50), 0.08, 0.08)
    rod(b, "wood_light", M, (post[0], post[1], -1.58), (0.2, post[1], -1.46), 0.05, 0.05)       # jib
    rod(b, "wood_dark", M, (post[0], post[1], Z_FLOOR + 0.15), (0.0, post[1], -1.57), 0.035, 0.035)
    lbox(b, "bronze", M, (0.2, post[1], -1.50), (0.04, 0.09, 0.09))
    prism(b, "bronze_dark", M @ Matrix.Rotation(-PI / 2, 4, "X"), 8, 0.065, 0.065, -0.265, -0.235, c=(0.2, 1.50))
    rod(b, "rope", M, (0.2, post[1], -1.52), (0.2, post[1], -2.0), 0.018)
    lbox(b, "bronze", M, (0.2, post[1], -2.03), (0.05, 0.05, 0.05))
    lbox(b, "travertine", M, (0.2, post[1], -2.16), (0.15, 0.15, 0.13), bevel=0.01)
    lbox(b, "wood_dark", M, (-0.2, 0.2, Z_FLOOR + 0.05), (0.2, 0.2, 0.1))                          # base


def m_reel(b, k, M):
    """Variant gear bay: a big wheel with a pin-drum and a pawl."""
    y0, z0 = 0.16, -1.95
    gear(b, M, (0.0, z0), 18, 0.2, 0.022, 0.05, "bronze_dark", 0.0, y0)
    for i in range(6):
        ang = i * TAU / 6
        rod(b, "wood_light", M, (0.0, y0, z0), (0.17 * math.cos(ang), y0, z0 + 0.17 * math.sin(ang)), 0.03, 0.04)
    lbox(b, "gold", M, (0, y0 + 0.04, z0), (0.07, 0.03, 0.07), bevel=0.006)
    rod(b, "bronze", M, (0.27, y0, z0 + 0.22), (0.08, y0, z0 + 0.19), 0.03, 0.04)
    lbox(b, "wood_dark", M, (0.3, y0, z0 + 0.23), (0.06, 0.06, 0.06))
    lbox(b, "wood_dark", M, (0, 0.02, Z_FLOOR + 0.06), (0.5, 0.05, 0.09))


MACHINES = [m_wheel, m_gears, m_screw, m_aeolipile, m_ballista, m_crane, m_reel, m_wheel]


def bay_machine(b, k, M):
    MACHINES[(k // 2) % len(MACHINES)](b, k, M)


BAY_FN = [bay_machine, bay_grille]


# ---------------------------------------------------------------- the deck
def build_deck(b):
    rng = random.Random(23)
    wells1 = [(a - 0.126, a + 0.126) for a in ROLLER_ANGLES]
    wells2 = [(a - 0.053, a + 0.163) for a in ROLLER_ANGLES]
    for ci, (z0, z1) in enumerate((Z_DECK2, Z_DECK1)):
        top = ci == 1
        rings = [  # r0, r1, windows, target, kind
            (2.28, 2.55, [], 0.26, "track"),
            (2.55, 2.66, [], 0.39, "pave"),
            (2.66, 3.04, wells1, 0.39, "pave"),
            (3.04, 3.10, [], 0.39, "pave"),
            (3.10, 3.30, wells2, 0.39, "pave"),
            (3.30, 3.52, [], 0.39, "pave"),
            (3.52, 3.75 if top else 3.80, [], 0.39, "kerb"),
        ]
        for ri, (r0, r1, w, tgt, kind) in enumerate(rings):
            if kind == "pave" and top is False and r0 >= 3.30:
                pass
            idx = 0
            for a0, a1, k in spans(rng, 0.3927 + (0.1 if ri % 2 else 0.0), w, tgt, 0.0):
                idx += 1
                if k == "win":
                    continue
                if top and kind == "track":
                    cell = "porphyry"
                elif kind == "kerb":
                    cell = pick(rng, W_BRICK) if top else "travertine_dark"   # red attic band (garlands read on it)
                elif not top and r0 >= 3.52:
                    cell = "travertine_dark"                       # corona
                else:
                    cell = W_PAVE[(idx + ri) % 2][0]
                zt = 0.035 if (top and kind == "kerb") else z1
                pblock(b, rng, cell, r0, r1, a0, a1, z0, zt, jit=0.0, jz=0.0, bevel=0.008 if top else 0.0, gap=0.004, hollow=True)
    # bronze bezel ring round the display
    n = 24
    for i in range(n):
        pblock(b, rng, "bronze", 2.20, 2.28, i * TAU / n, (i + 1) * TAU / n, Z_DECK1[0], 0.022, jit=0.0, jz=0.0,
               bevel=0.005, gap=0.003)
    # mosaic border (ring D): black/white tesserae with red accents, two rows
    for row, (r0, r1) in enumerate(((3.30, 3.41), (3.41, 3.52))):
        n = 60
        for i in range(n):
            major = (i % 6 == 0)
            cell = "tessera_red" if major else ("tessera_white" if (i + row) % 2 == 0 else "tessera_black")
            pblock(b, rng, cell, r0, r1, i * TAU / n, (i + 1) * TAU / n, 0.0, 0.012, jit=0.0, jz=0.0, bevel=0.0, gap=0.004, hollow=True)


def numeral(b, M, text):
    """Roman numeral in bronze, read from outside the table (up = towards the centre)."""
    adv = {"I": 0.045, "V": 0.095}
    total = sum(adv[c] for c in text)
    x = total / 2                                  # reading left to right = decreasing u
    h = 0.12
    for c in text:
        if c == "I":
            lbox(b, "bronze", M, (x - 0.0225, 0, 0.0), (0.022, h, 0.014))
        else:
            for sgn in (-1, 1):
                lbox(b, "bronze", M, (x - 0.0475 + sgn * 0.0165, 0, 0.0), (0.022, h * 1.02, 0.014), rot=sgn * 16.7)
        x -= adv[c]


def build_deck_furniture(b):
    rng = random.Random(31)
    for i, a in enumerate(RIM_ANGLES):
        numeral(b, frame(a, 3.63, 0.035 + 0.007), ("I", "II", "III", "IV", "V", "VI", "VII", "VIII")[i])
    # roller wells: bronze frame strips, cradle plates, bearings, an idler gear meshed with the roller's pinion
    for a in ROLLER_ANGLES:
        M = frame(a, 0.0)
        lbox(b, "bronze", M, (0, 2.66 + 0.008, ROLLER_Z), (0.17, 0.016, 0.17))
        lbox(b, "bronze", M, (0, 3.04 - 0.008, ROLLER_Z), (0.15, 0.016, 0.15))
        lbox(b, "lead", M, (0, 2.85, -0.62), (0.58, 0.34, 0.03))                       # lead-lined cradle floor
        for sx in (-1, 1):
            lbox(b, "bronze", M, (sx * 0.33, 2.85, -0.50), (0.025, 0.36, 0.22))
            lbox(b, "bronze", M, (sx * 0.355, 2.85, 0.005), (0.02, 0.38, 0.012))       # flush edge strips
        W = frame(a, 3.19)
        m = 0.022
        gear(b, W, (0.308, ROLLER_Z), 16, 16 * m / 2, m, 0.05, "bronze_dark", PI / 16, 0.0)
        lbox(b, "gold", W, (0.308, 0.0, ROLLER_Z), (0.05, 0.07, 0.05), bevel=0.005)
        lbox(b, "bronze", W, (0.308, 0.0, ROLLER_Z - 0.11), (0.03, 0.03, 0.2))        # idler bracket to the slot floor
    # buttons: marble collars of twelve blocks, bronze studs
    for name, (a, r) in BUTTONS.items():
        M = frame(a, r, 0.0)
        for i in range(12):
            ang = i * TAU / 12 + TAU / 24
            c = (0.335 * math.cos(ang), 0.335 * math.sin(ang), 0.04)
            lbox(b, "marble" if i % 2 else "travertine", M, c, (0.18, 0.08, 0.08), rot=math.degrees(ang) + 90, bevel=0.008)
        for i in range(4):
            ang = i * PI / 2
            lbox(b, "bronze", M, (0.40 * math.cos(ang), 0.40 * math.sin(ang), 0.02), (0.045, 0.045, 0.04))
    # trays: marble basin, red felt floor, bronze rim, key-colour inlay (amber / teal)
    for i, (a, r) in enumerate(TRAYS):
        M = frame(a, r, 0.0)
        for j in range(12):
            ang = j * TAU / 12 + TAU / 24
            c = (0.375 * math.cos(ang), 0.375 * math.sin(ang), 0.03)
            lbox(b, "marble" if j % 2 else "marble_cream", M, c, (0.20, 0.09, 0.06), rot=math.degrees(ang) + 90, bevel=0.007)
        prism(b, "paint_red", M, 12, 0.34, 0.34, 0.0, 0.03, off=TAU / 24)
        prism(b, "bronze", M, 12, 0.335, 0.335, 0.03, 0.036, off=TAU / 24, caps=("bronze", "paint_red"))
        for sy in (-1, 1):
            lbox(b, ("gold", "turquoise")[i], M, (0, sy * 0.44, 0.035), (0.10, 0.025, 0.055), bevel=0.004)
    # groma (surveyor's cross) on the rim
    groma(b, frame(PI / 8, 3.62, 0.04))


def groma(b, M):
    """Surveyor's groma: staff, short offset bracket, rotating cross with four plumb lines."""
    lbox(b, "marble", M, (0, 0, 0.04), (0.26, 0.26, 0.08), bevel=0.01)
    rod(b, "wood_dark", M, (0, 0, 0.08), (0, 0, 0.42), 0.06, 0.06)
    lbox(b, "bronze", M, (0, 0, 0.43), (0.11, 0.07, 0.04))
    c = Vector((0.06, 0.0, 0.47))
    lbox(b, "bronze_dark", M, c, (0.05, 0.05, 0.05))
    rod(b, "wood_light", M, c + Vector((-0.2, 0, 0.02)), c + Vector((0.2, 0, 0.02)), 0.035, 0.03)
    rod(b, "wood_light", M, c + Vector((0, -0.2, 0.02)), c + Vector((0, 0.2, 0.02)), 0.035, 0.03)
    for dx, dy in ((0.2, 0), (-0.2, 0), (0, 0.2), (0, -0.2)):                              # four plumb lines
        p = c + Vector((dx, dy, 0.0))
        rod(b, "rope", M, p, p + Vector((0, 0, -0.30)), 0.008, 0.008)
        prism(b, "bronze", M, 6, 0.0001, 0.022, p.z - 0.37, p.z - 0.30, c=(p.x, p.y))


def build_deck_edge(b):
    # phalerae with laurel swags on the attic band of the deck
    for k in range(NB):
        a = k * TAU / NB
        Mp = frame(a, 3.755, -0.17) @ Matrix.Rotation(-PI / 2, 4, "X")
        prism(b, "bronze", Mp, 8, 0.115, 0.115, -0.012, 0.016, off=TAU / 16)
        prism(b, "gold", Mp, 8, 0.05, 0.05, 0.016, 0.03, off=TAU / 16)
        Ms = frame(a + TAU / NB / 2, 3.755, -0.17)
        pts = []
        for i in range(6):
            u = (i - 2.5) * 0.24
            pts.append((u, 0.012, 0.09 - 0.17 * (1 - (u / 0.6) ** 2)))
        for i in range(5):
            rod(b, "laurel" if i % 2 == 0 else "laurel_dark", Ms, pts[i], pts[i + 1], 0.05, 0.045)
        for i in (0, 5):
            lbox(b, "paint_red", Ms, (pts[i][0] * 1.0, 0.02, pts[i][2] - 0.01), (0.04, 0.03, 0.06))


# ---------------------------------------------------------------- controls
def build_roller(b):
    ax = Matrix.Rotation(PI / 2, 4, "Y")
    cells = ["marble", "marble_grey"] * 6
    cells[5] = "paint_red"
    r = ROLLER_R / math.cos(PI / 12) * 0.98
    prism(b, "marble", ax, 12, r, r, -0.15, 0.15, off=TAU / 24, cells=cells)
    for sgn in (-1, 1):                               # bronze flanges with a gold boss
        z0, z1 = (0.15, 0.178) if sgn > 0 else (-0.178, -0.15)
        prism(b, "bronze", ax, 12, 0.335, 0.335, z0, z1, off=TAU / 24)
        prism(b, "gold", ax, 12, 0.09, 0.09, z1 if sgn > 0 else z0 - 0.012, (z1 + 0.012) if sgn > 0 else z0, off=TAU / 24)
    for x in (-0.05, 0.05):                            # bronze bands
        prism(b, "bronze_dark", ax, 12, r + 0.006, r + 0.006, x - 0.012, x + 0.012, off=TAU / 24)
    M = Matrix.Identity(4)
    lbox(b, "bronze_dark", M, (0.12, 0, 0), (0.54, 0.07, 0.07))
    Mw = Matrix(((0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    gear(b, Mw, (0, 0), 12, 12 * 0.022 / 2, 0.022, 0.05, "bronze", 0.0, 0.34)
    lbox(b, "gold", M, (0.34, 0, 0), (0.06, 0.08, 0.08), bevel=0.006)


def build_button(b, cap, boss):
    I = Matrix.Identity(4)
    prism(b, "bronze_dark", I, 12, 0.27, 0.25, 0.0, 0.07, off=TAU / 24)
    prism(b, "bronze", I, 12, 0.25, 0.21, 0.07, 0.13, off=TAU / 24)
    for i in range(12):                                # laurel ring
        ang = i * TAU / 12
        lbox(b, "laurel" if i % 2 else "laurel_dark", Matrix.Rotation(ang, 4, "Z"), (0, 0.205, 0.095), (0.07, 0.03, 0.04), top=(0.7, 1))
    prism(b, cap, I, 12, 0.16, 0.14, 0.13, 0.16, off=TAU / 24)
    prism(b, boss, I, 12, 0.07, 0.05, 0.16, 0.18, off=TAU / 24)


# ---------------------------------------------------------------- assembly + export
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
        print(f"  {fn.__name__:22s} +{t - last[0]:6d} tris")
        last[0] = t
    for fn in (build_core, build_podium, build_arcade, build_entablature, build_deck, build_deck_furniture, build_deck_edge):
        stage(fn)
    platform = finish(plat, "Platform", mat)

    d = bl.Builder()
    prism(d, "concrete_dark", Matrix.Identity(4), 64, R_DISPLAY, R_DISPLAY, -0.02, 0.0)
    finish(d, "DisplaySurface", mat)

    rb = bl.Builder()
    build_roller(rb)
    roller = finish(rb, "roller_0", mat)
    for i, a in enumerate(ROLLER_ANGLES):
        ob = roller if i == 0 else bpy.data.objects.new(f"roller_{i}", roller.data)
        if i:
            bpy.context.scene.collection.objects.link(ob)
        ob.location = P(ROLLER_C, a, ROLLER_Z)
        ob.rotation_euler = (0, 0, -a)

    for name, (cap, boss) in (("reset", ("paint_red", "gold")), ("viz", ("turquoise", "gold"))):
        bb = bl.Builder()
        build_button(bb, cap, boss)
        ob = finish(bb, f"{name}_button", mat)
        a, r = BUTTONS[name]
        ob.location = P(r, a, 0.01)

    def empty(name, loc):
        e = bpy.data.objects.new(name, None)
        e.location = loc
        bpy.context.scene.collection.objects.link(e)
    for i, (a, r) in enumerate(TRAYS):
        empty(f"tray_anchor_{i}", P(r, a, 0.036))
    empty("inscription_anchor", P(INSCRIPTION_R, INSCRIPTION_ANGLE, 0.0))

    out_blend = os.path.join(HERE, "turing_platform.blend")
    out_glb = os.path.join(os.path.dirname(ROOT), "godot", "assets", "props", "turing_platform.glb")
    os.makedirs(os.path.dirname(out_glb), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True,
                              export_image_format="AUTO", export_cameras=False, export_lights=False, export_apply=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=True)
    print(f"platform tris={bl.tri_count(platform)} roller={bl.tri_count(roller)}")


main()
