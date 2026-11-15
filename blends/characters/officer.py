"""1950s US Army officer, Army Green dress uniform with service cap.
Run:  blender -b -P blends/characters/officer.py          (Major)
Variants live in their own files (officer_colonel.py) and call build() with overrides.
Output: blends/characters/<name>.blend and godot/assets/characters/<name>.glb
Rigged: see blends/lib/rig.py for skeleton, shape keys (mouth_open, blink) and actions.
Facing -Y. Wearer's left = +X. ~1.86 m with cap.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import bl  # noqa: E402
import face  # noqa: E402

MAJOR = dict(name="officer", skin="skin", skin_shade="skin_shade", hair="hair_dark", trousers="army_trousers",
             rank="oak", bulk=1.0, mustache=False, braid=False)


def cf(z):
    """Front surface y of the coat body at height z (coat tapers wider toward the chest)."""
    return -0.1125 * (1 + 0.08 * (z - 0.79) / 0.66)


def build(cfg):
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, skin_shade, hair, tr = cfg["skin"], cfg["skin_shade"], cfg["hair"], cfg["trousers"]
    k = cfg["bulk"]  # stockiness of the coat (x only)

    # ---------- legs ----------
    P("shoe",   (0.09, -0.035, 0.05), (0.11, 0.28, 0.07), top=(0.9, 0.8), bevel=0.008, mirror=True)
    P("sole",   (0.09, -0.035, 0.008), (0.117, 0.29, 0.016), mirror=True)
    P(tr, (0.09, 0.0, 0.29), (0.13, 0.145, 0.40), top=(1.1, 1.05), bottom=(0.95, 0.95), bevel=0.004, mirror=True)
    P(tr, (0.09, 0.0, 0.70), (0.155, 0.175, 0.42), top=(1.1, 1.1), bottom=(0.9, 0.9), bevel=0.004, mirror=True)

    # ---------- coat ----------
    P("army_green", (0.0, 0.0, 1.12), (0.37 * k, 0.225, 0.66), top=(1.17, 1.08), bevel=0.006)      # body, z 0.79..1.45
    P("army_green", (0.0, 0.0, 1.455), (0.45 * k, 0.235, 0.08), top=(0.78, 0.85), bevel=0.006)     # shoulders
    P("army_green_shade", (0.0, 0.0, 1.045), (0.385 * k, 0.238, 0.04))                             # self belt
    P("brass", (0.0, cf(1.045) - 0.006, 1.045), (0.045, 0.012, 0.032))                             # buckle
    # collar, shirt, tie
    P("army_green", (0.0, 0.0, 1.50), (0.19, 0.19, 0.035), bevel=0.004)
    P("shirt_khaki", (0.0, 0.0, 1.527), (0.15, 0.16, 0.035), bevel=0.003)
    P(skin, (0.0, 0.0, 1.565), (0.095, 0.10, 0.07))
    P("shirt_khaki", (0.0, cf(1.36) - 0.0035, 1.37), (0.13, 0.006, 0.20), top=(1.0, 1.0), bottom=(0.5, 1.0))  # shirt V
    P("tie_black", (0.0, cf(1.46) - 0.011, 1.455), (0.05, 0.02, 0.04), bevel=0.004)                 # knot
    P("tie_black", (0.0, cf(1.3) - 0.0115, 1.30), (0.042, 0.011, 0.32), bottom=(1.15, 1))           # blade
    # notched lapels, angled in a V
    P("army_green", (0.085, cf(1.33) - 0.007, 1.335), (0.075, 0.012, 0.23), rot=(0, 18, 0), bevel=0.003, mirror=True)
    P("brass", (0.115, cf(1.40) - 0.016, 1.395), (0.022, 0.006, 0.022), mirror=True)                # U.S. collar discs
    # pockets (flap + button), 4-pocket coat
    for z, w, h in ((1.255, 0.085, 0.075), (0.97, 0.105, 0.09)):
        P("army_green", (0.115, cf(z) - 0.0065, z), (w, 0.013, h), bevel=0.003, mirror=True)
        P("army_green_shade", (0.115, cf(z) - 0.0075, z + h / 2 - 0.009), (w + 0.004, 0.014, 0.018), mirror=True)
        P("brass", (0.115, cf(z) - 0.0145, z + h / 2 - 0.009), (0.012, 0.005, 0.012), mirror=True)
    # coat buttons on the centreline
    for z in (1.22, 1.13, 0.95):
        P("brass", (0.0, cf(z) - 0.007, z), (0.014, 0.008, 0.014))
    # ribbons, wearer's left chest (3 across x 3 up)
    rib = [("ribbon_red", "ribbon_yellow", "ribbon_blue"),
           ("ribbon_green", "shirt_white", "ribbon_red"),
           ("ribbon_blue", "ribbon_red", "ribbon_green")]
    for r, row in enumerate(rib):
        for c, col in enumerate(row):
            P(col, (0.082 + c * 0.019, cf(1.37) - 0.0035, 1.36 + r * 0.013), (0.0185, 0.006, 0.0125))
    # shoulder loops with rank: gold oak leaf (Major) or silver eagle (Colonel)
    P("army_green_shade", (0.165, 0.0, 1.5), (0.07, 0.13, 0.012), mirror=True)
    if cfg["rank"] == "oak":
        P("brass", (0.165, -0.015, 1.507), (0.03, 0.04, 0.006), mirror=True)
    else:
        P("metal_silver", (0.165, -0.015, 1.507), (0.018, 0.04, 0.006), mirror=True)   # eagle body
        P("metal_silver", (0.165, -0.012, 1.507), (0.05, 0.016, 0.006), mirror=True)   # wings

    # ---------- arms (long coat sleeves, khaki cuffs peeking out) ----------
    ax = 0.25 + (k - 1) * 0.2
    P("army_green", (ax, 0.0, 1.33), (0.125, 0.135, 0.29), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P("army_green", (ax, -0.014, 1.04), (0.108, 0.115, 0.30), top=(1.05, 1.05), bottom=(0.88, 0.88), rot=(-5, 0, 0), bevel=0.004, mirror=True)
    P("shirt_khaki", (ax, -0.026, 0.885), (0.088, 0.098, 0.018), rot=(-5, 0, 0), mirror=True)
    P(skin, (ax, -0.028, 0.80), (0.06, 0.095, 0.13), bevel=0.006, mirror=True)                     # hand
    P(skin, (ax - 0.036, -0.06, 0.82), (0.022, 0.04, 0.05), mirror=True)                           # thumb

    # ---------- head ----------
    HZ = face.HZ
    face.add_face(P, skin, skin_shade, hair, nose=(0.03, 0.03, 0.05))
    if cfg["mustache"]:
        P(hair, (0.0, -0.1135, HZ - 0.058), (0.062, 0.012, 0.014), bevel=0.002)
    # hair: short back and sides under the cap, sideburns
    P(hair, (0.0, 0.039, HZ + 0.03), (0.2, 0.1619, 0.12), bevel=0.008)
    P(hair, (0.0, 0.04, HZ + 0.08), (0.222, 0.2, 0.055), bevel=0.006)                              # wider, shows under the cap

    # ---------- service cap (peaked) ----------
    P("tie_black", (0.0, 0.002, HZ + 0.107), (0.235, 0.252, 0.036), bevel=0.003)                   # band
    P("army_green", (0.0, 0.0, HZ + 0.158), (0.245, 0.262, 0.066), top=(1.16, 1.12), bottom=(1.0, 1.0), bevel=0.006)  # crown
    P("visor_black", (0.0, -0.165, HZ + 0.098), (0.21, 0.105, 0.008), rot=(12, 0, 0), bevel=0.003)  # visor
    P("brass", (0.0, -0.139, HZ + 0.108), (0.036, 0.010, 0.036))                                   # cap eagle
    if cfg["braid"]:  # field-grade "scrambled eggs" on the visor
        P("brass", (0.0, -0.2135, HZ + 0.104), (0.21, 0.012, 0.010), rot=(12, 0, 0))
        P("brass", (0.0, -0.168, HZ + 0.1035), (0.16, 0.045, 0.004), rot=(12, 0, 0))

    face.add_shapes(b)

    ob = b.finish(cfg["name"], rig=True)
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    bl.export(ob, os.path.join(HERE, cfg["name"] + ".blend"),
              os.path.join(root, "godot", "assets", "characters", cfg["name"] + ".glb"))
    return ob


if __name__ == "__main__":
    build(MAJOR)
