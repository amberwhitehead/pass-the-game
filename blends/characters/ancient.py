"""Ancient warriors: Roman legionary (centurion helmet), Egyptian guard, Mayan warrior.
Run:  blender -b -P blends/characters/ancient.py [-- roman egyptian mayan]
Rigged to the standard skeleton (blends/lib/rig.py). Facing -Y, wearer's left = +X.
Skirts/kilts are split into per-leg panels on the thigh bones so the legs never clip them.
Held items (spears, shield, club) are pinned to a hand bone with bone= so they never tear apart.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import bl  # noqa: E402
import face  # noqa: E402

HZ = face.HZ


# ------------------------------------------------------------------ shared pieces
def bare_legs(P, skin, sole="strap_leather", strap="strap_leather"):
    """Bare thighs/shins with simple strap sandals."""
    P(sole, (0.09, -0.035, 0.012), (0.112, 0.29, 0.024), mirror=True)                                    # sole
    P(skin, (0.09, -0.04, 0.046), (0.095, 0.23, 0.04), top=(0.95, 0.85), bevel=0.006, mirror=True)       # foot
    P(strap, (0.09, -0.06, 0.056), (0.1, 0.03, 0.045), mirror=True)                                      # instep strap
    P(strap, (0.09, -0.0, 0.075), (0.1, 0.03, 0.03), mirror=True)
    P(skin, (0.09, 0.0, 0.29), (0.12, 0.135, 0.40), top=(1.1, 1.05), bottom=(0.95, 0.95), bevel=0.004, mirror=True)   # shin
    P(strap, (0.09, 0.0, 0.12), (0.128, 0.143, 0.02), mirror=True)                                       # ankle strap
    P(skin, (0.09, 0.0, 0.70), (0.15, 0.17, 0.42), top=(1.1, 1.1), bottom=(0.9, 0.9), bevel=0.004, mirror=True)       # thigh


def hands(P, skin, x, mirror=True, forearm=True):
    if forearm:
        P(skin, (x, -0.014, 1.0), (0.088, 0.095, 0.27), top=(1.05, 1.05), bottom=(0.85, 0.85), rot=(-5, 0, 0), bevel=0.004, mirror=mirror)
    P(skin, (x, -0.028, 0.80), (0.06, 0.095, 0.13), bevel=0.006, mirror=mirror)
    P(skin, (x - 0.036, -0.06, 0.82), (0.022, 0.04, 0.05), mirror=mirror)


def fan(P, cells, base, length, width, angles, tilt=14):
    """Fan of tall thin plumes rooted at `base`, each rotated about Y (spread) and tilted back."""
    for cell, a in zip(cells, angles):
        ra, rt = math.radians(a), math.radians(tilt)
        c = (base[0] + math.sin(ra) * length / 2, base[1] + math.sin(rt) * length / 2, base[2] + math.cos(ra) * length / 2)
        P(cell, c, (width, 0.012, length), top=(0.9, 1), rot=(-tilt, a, 0), bone="head")


def spear(P, bone, x, shaft="wood", tip="steel", head_z=2.1, shaft_len=1.7):
    """Upright spear held in a fist at (x, y=-0.028, z~0.8). All parts pinned to `bone`."""
    y = -0.028
    z0 = 0.8 - 0.4
    P(shaft, (x, y, z0 + shaft_len / 2), (0.03, 0.03, shaft_len), bone=bone)
    P(tip, (x, y, head_z + 0.11), (0.05, 0.014, 0.22), top=(0.05, 1), bone=bone)                         # leaf blade
    P("bronze", (x, y, head_z - 0.005), (0.042, 0.042, 0.03), bone=bone)                                 # socket


# ------------------------------------------------------------------ Roman
def roman():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, shade = "skin", "skin_shade"
    bare_legs(P, skin, sole="strap_leather", strap="strap_leather")
    for z in (0.17, 0.22):                                                                               # caligae shin laces
        P("strap_leather", (0.09, 0.0, z), (0.126, 0.14, 0.012), mirror=True)
    # tunic skirt: one panel per leg + leather pteruges strips front and back
    P("roman_red", (0.105, 0.0, 0.84), (0.21, 0.25, 0.28), top=(1.0, 0.95), bottom=(1.05, 1.1), bevel=0.005, mirror=True)
    for i, x in enumerate((0.04, 0.105, 0.17)):
        for yy in (-0.1335, 0.1335):
            P("strap_leather", (x, yy, 0.77), (0.058, 0.012, 0.16), mirror=True)
    # torso: red tunic under lorica segmentata (steel bands), straps, shoulder guards
    P("roman_red", (0.0, 0.0, 1.20), (0.36, 0.215, 0.50), top=(1.12, 1.06), bevel=0.006)
    P("roman_red", (0.0, 0.0, 1.455), (0.44, 0.225, 0.08), top=(0.78, 0.85), bevel=0.006)
    for i in range(5):
        P("steel", (0.0, 0.0, 1.07 + i * 0.075), (0.39 + i * 0.006, 0.228 + i * 0.002, 0.052), bevel=0.004, bone="torso")
    P("strap_leather", (0.0, -0.1185, 1.24), (0.04, 0.008, 0.38))
    for z in (1.12, 1.24, 1.36):
        P("bronze", (0.0, -0.1235, z), (0.045, 0.01, 0.035))
    for z, w in ((1.495, 0.19), (1.468, 0.20), (1.44, 0.21)):                                            # layered shoulder guards
        P("steel", (0.2, 0.0, z), (w, 0.2, 0.03), bevel=0.004, mirror=True)
    P("steel", (0.0, 0.0, 1.51), (0.2, 0.19, 0.04), bevel=0.004, bone="torso")                          # gorget
    P(skin, (0.0, 0.0, 1.565), (0.095, 0.10, 0.07))
    P("strap_leather", (0.0, 0.0, 1.0), (0.385, 0.232, 0.04))                                            # cingulum
    for x in (0.04, 0.11, 0.16):
        P("bronze", (x, -0.1175, 1.0), (0.03, 0.008, 0.03), mirror=True)
    P("roman_red", (0.0, 0.126, 1.28), (0.41, 0.03, 0.42), bone="torso")                                 # cloak
    P("bronze", (-0.12, -0.1, 1.47), (0.035, 0.012, 0.035), bone="torso")                                # clasp
    # arms: short tunic sleeves, bare forearms
    P("roman_red", (0.245, 0.0, 1.385), (0.125, 0.13, 0.19), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P(skin, (0.245, 0.0, 1.20), (0.085, 0.095, 0.17), top=(0.95, 0.95), bevel=0.004, mirror=True)
    hands(P, skin, 0.245)
    P("bronze", (0.245, -0.012, 0.93), (0.095, 0.105, 0.05), rot=(-5, 0, 0), mirror=True)                # bracers
    # left: scutum (red shield with bronze boss + rim), right: pilum
    sx, sy = 0.30, -0.145
    P("roman_red", (sx, sy, 1.10), (0.40, 0.04, 0.70), bevel=0.008, bone="lower_arm.L")
    for dz in (0.34, -0.34):
        P("bronze", (sx, sy - 0.002, 1.10 + dz), (0.42, 0.044, 0.03), bone="lower_arm.L")
    for dx in (0.2, -0.2):
        P("bronze", (sx + dx, sy - 0.002, 1.10), (0.03, 0.044, 0.7), bone="lower_arm.L")
    P("bronze", (sx, sy - 0.03, 1.10), (0.11, 0.03, 0.11), bevel=0.006, bone="lower_arm.L")              # boss
    P("gold", (sx, sy - 0.0225, 1.10), (0.3, 0.006, 0.028), bone="lower_arm.L")                          # wing motif
    spear(P, "lower_arm.R", -0.245, shaft="wood", tip="steel", head_z=2.05)
    # head
    face.add_face(P, skin, shade, "hair_brown")
    P("hair_brown", (0.0, 0.039, HZ + 0.03), (0.2, 0.1619, 0.12), bevel=0.008)                          # hair under helmet
    P("steel", (0.0, 0.0, HZ + 0.12), (0.23, 0.25, 0.12), top=(0.92, 0.92), bevel=0.01)                  # galea bowl
    P("bronze", (0.0, -0.0, HZ + 0.072), (0.238, 0.258, 0.022))                                          # brow band
    P("steel", (0.112, -0.02, HZ - 0.0), (0.014, 0.09, 0.15), bevel=0.003, mirror=True)                  # cheek guards
    P("steel", (0.0, 0.13, HZ + 0.03), (0.22, 0.06, 0.075), bevel=0.004)                                 # neck guard
    P("bronze", (0.0, 0.0, HZ + 0.192), (0.07, 0.09, 0.025))                                              # crest mount
    P("roman_red", (0.0, 0.0, HZ + 0.245), (0.30, 0.04, 0.085), bottom=(0.5, 1.0), bevel=0.004)          # centurion transverse crest
    face.add_shapes(b)
    return b.finish("roman", rig=True)


# ------------------------------------------------------------------ Egyptian
def egyptian():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, shade = "skin_tan", "skin_tan_shade"
    bare_legs(P, skin, sole="strap_leather", strap="gold")
    P("gold", (0.09, 0.0, 0.105), (0.13, 0.145, 0.018), mirror=True)                                     # anklets
    # shendyt kilt: linen panel per leg, gold hem, pleat lines
    P("linen", (0.105, 0.0, 0.84), (0.21, 0.26, 0.30), top=(1.0, 0.95), bottom=(1.08, 1.12), bevel=0.005, mirror=True)
    P("gold", (0.105, 0.0, 0.705), (0.235, 0.298, 0.016), mirror=True)
    for x in (0.04, 0.105, 0.17):
        P("linen_shade", (x, -0.1365, 0.84), (0.012, 0.006, 0.27), mirror=True)
    # bare torso with pecs/abs, gold belt, wide usekh collar
    P(skin, (0.0, 0.0, 1.20), (0.36, 0.215, 0.50), top=(1.12, 1.06), bevel=0.006)
    P(skin, (0.0, 0.0, 1.455), (0.44, 0.225, 0.08), top=(0.78, 0.85), bevel=0.006)
    P(shade, (0.075, -0.1125, 1.33), (0.12, 0.012, 0.075), mirror=True)                                   # pecs
    for z in (1.19, 1.12):
        P(shade, (0.0, -0.1105, z), (0.2, 0.006, 0.01))
    P(shade, (0.0, -0.1105, 1.155), (0.01, 0.006, 0.14))
    P("gold", (0.0, 0.0, 1.00), (0.385, 0.232, 0.04))
    P("lapis", (0.0, -0.1175, 1.00), (0.06, 0.008, 0.032))
    for z, w, c in ((1.50, 0.40, "gold"), (1.52, 0.33, "turquoise"), (1.54, 0.26, "lapis")):             # stepped collar
        P(c, (0.0, 0.0, z), (w, 0.2 + (w - 0.26) * 0.3, 0.02), bone="torso")
    for z, w, c in ((1.43, 0.30, "turquoise"), (1.395, 0.24, "lapis"), (1.36, 0.17, "gold")):           # collar hanging on chest
        P(c, (0.0, -0.1185, z), (w, 0.012, 0.034), bone="torso")
    P(skin, (0.0, 0.0, 1.565), (0.095, 0.10, 0.07))
    # arms: bare, gold armlets and cuffs
    hands(P, skin, 0.245)
    P(skin, (0.245, 0.0, 1.33), (0.095, 0.105, 0.29), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P("gold", (0.245, 0.0, 1.26), (0.105, 0.115, 0.035), mirror=True)
    P("gold", (0.245, -0.0265, 0.895), (0.1, 0.108, 0.04), rot=(-5, 0, 0), mirror=True)
    spear(P, "lower_arm.R", -0.245, shaft="wood", tip="bronze", head_z=2.1)
    P("gold", (-0.245, -0.028, 1.05), (0.036, 0.036, 0.04), bone="lower_arm.R")                         # spear collar
    # head: kohl-lined eyes, nemes headdress with stripes, uraeus, ceremonial beard
    face.add_face(P, skin, shade, "kohl")
    for sx in (0.07, -0.07):
        P("kohl", (sx, -0.1115, HZ + 0.012), (0.03, 0.004, 0.011))
    for i in range(-3, 4):                                                                                # striped top of the nemes
        P("gold" if i % 2 == 0 else "lapis", (i * 0.0295, 0.008, HZ + 0.1255), (0.0295, 0.24, 0.036), bevel=0.002)
    P("lapis", (0.0, 0.005, HZ + 0.075), (0.215, 0.235, 0.03))                                           # brow band behind
    P("gold", (0.0, -0.1185, HZ + 0.075), (0.213, 0.008, 0.016))                                          # gold headband
    for sx in (0.109, -0.109):
        P("lapis", (sx, 0.03, HZ + 0.0), (0.012, 0.2, 0.15), bone="head")                                 # side plates
    for sx in (0.115, -0.115):
        P("lapis", (sx, -0.005, 1.52), (0.05, 0.075, 0.2), bone="head")                                   # lappets
        for z in (1.45, 1.50, 1.55):
            P("gold", (sx, -0.005, z), (0.052, 0.077, 0.014), bone="head")
    P("lapis", (0.0, 0.14, 1.52), (0.09, 0.05, 0.30), bone="head")                                        # tail
    P("gold", (0.0, 0.14, 1.52), (0.092, 0.052, 0.02), bone="head")
    P("gold", (0.0, -0.1185, HZ + 0.095), (0.016, 0.012, 0.05))                                           # uraeus
    P("paint_red", (0.0, -0.1195, HZ + 0.105), (0.01, 0.01, 0.015))
    P("lapis", (0.0, -0.115, HZ - 0.158), (0.03, 0.03, 0.09), bevel=0.003)                                # ceremonial beard
    P("gold", (0.0, -0.115, HZ - 0.12), (0.034, 0.034, 0.016))
    face.add_shapes(b)
    return b.finish("egyptian", rig=True)


# ------------------------------------------------------------------ Mayan
def mayan():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, shade = "skin_tan", "skin_tan_shade"
    bare_legs(P, skin, sole="strap_leather", strap="paint_red")
    # maxtli loincloth: front + back flaps per leg, jade hem, gold centre stripe
    for yy, base, trim in ((-0.113, "paint_red", "jaguar"), (0.113, "bone_white", "maya_blue")):
        P(base, (0.075, yy, 0.78), (0.12, 0.03, 0.38), bevel=0.003, mirror=True)
        P("jade", (0.075, yy, 0.60), (0.124, 0.034, 0.024), mirror=True)
        P(trim, (0.075, yy + (-0.002 if yy < 0 else 0.002), 0.80), (0.03, 0.034, 0.30), mirror=True)
    # torso: bare, body paint, jade collar/pectoral, jaguar pelt cape
    P(skin, (0.0, 0.0, 1.20), (0.36, 0.215, 0.50), top=(1.12, 1.06), bevel=0.006)
    P(skin, (0.0, 0.0, 1.455), (0.44, 0.225, 0.08), top=(0.78, 0.85), bevel=0.006)
    P(skin, (0.0, 0.0, 1.0), (0.355, 0.205, 0.12))
    P("maya_blue", (-0.1, -0.1115, 1.27), (0.045, 0.006, 0.28))                                           # chest paint
    P("maya_blue", (-0.04, -0.1115, 1.25), (0.02, 0.006, 0.24))
    P("paint_red", (0.1, -0.1115, 1.2), (0.12, 0.006, 0.02))
    P("paint_red", (0.1, -0.1115, 1.14), (0.12, 0.006, 0.02))
    P("paint_red", (0.0, 0.0, 1.0), (0.385, 0.232, 0.05))                                                 # woven belt
    P("jade", (0.0, -0.1185, 1.0), (0.06, 0.008, 0.036))
    P("jade", (0.0, 0.0, 1.505), (0.30, 0.23, 0.035), bevel=0.004, bone="torso")                          # collar of jade beads
    P("jade", (0.0, -0.1185, 1.38), (0.13, 0.012, 0.10), bevel=0.004, bone="torso")                       # pectoral
    P("gold", (0.0, -0.1265, 1.38), (0.05, 0.008, 0.05), bone="torso")
    P(skin, (0.0, 0.0, 1.565), (0.095, 0.10, 0.07))
    P("jaguar", (0.0, 0.126, 1.26), (0.40, 0.03, 0.44), bone="torso")                                     # pelt cape
    for x, z in ((-0.12, 1.40), (0.0, 1.36), (0.11, 1.41), (-0.07, 1.27), (0.08, 1.25), (-0.13, 1.16), (0.02, 1.15), (0.13, 1.10), (-0.05, 1.06)):
        P("hair_black", (x, 0.1425, z), (0.034, 0.004, 0.034), bone="torso")
    # arms: bare, jade armbands, white wrist wraps; macuahuitl in the right hand
    hands(P, skin, 0.245)
    P(skin, (0.245, 0.0, 1.33), (0.095, 0.105, 0.29), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P("jade", (0.245, 0.0, 1.27), (0.105, 0.115, 0.04), mirror=True)
    P("bone_white", (0.245, -0.0245, 0.93), (0.096, 0.104, 0.09), rot=(-5, 0, 0), mirror=True)
    hx, py = -0.245, -0.085                                                                               # club is held out in front of the forearm
    P("wood", (hx, -0.05, 0.78), (0.03, 0.03, 0.30), bone="lower_arm.R")                                  # handle (through the fist)
    P("wood", (hx, -0.07, 0.915), (0.05, 0.06, 0.05), bone="lower_arm.R")                                 # grip block
    P("wood", (hx, py, 1.22), (0.08, 0.022, 0.62), bevel=0.003, bone="lower_arm.R")                       # paddle
    for i in range(8):                                                                                    # obsidian teeth on both edges
        z = 0.94 + i * 0.072
        for dx in (0.047, -0.047):
            P("obsidian", (hx + dx, py, z), (0.02, 0.026, 0.04), top=(0.6, 1), bone="lower_arm.R")
    # head: braided hair, face paint, earspools, jaguar-head headdress with quetzal plumes
    face.add_face(P, skin, shade, "hair_black")
    P("hair_black", (0.0, 0.05, HZ + 0.03), (0.21, 0.19, 0.13), bevel=0.008)
    P("hair_black", (0.0, 0.11, HZ - 0.08), (0.12, 0.05, 0.2), bevel=0.005)                              # braid down the back
    for sx in (0.072, -0.072):
        P("paint_red", (sx, -0.1115, HZ - 0.045), (0.014, 0.004, 0.065))                                  # cheek stripes
        P("kohl", (sx, -0.1115, HZ - 0.005), (0.05, 0.004, 0.008))
    P("jade", (0.0, -0.1275, HZ - 0.065), (0.016, 0.012, 0.016))                                          # nose bead
    P("jade", (0.116, 0.0, HZ - 0.01), (0.026, 0.045, 0.05), mirror=True)                                 # earspools
    P("jaguar", (0.0, 0.0, HZ + 0.115), (0.235, 0.26, 0.1), bevel=0.008)                                  # jaguar head helm
    P("jaguar", (0.0, -0.138, HZ + 0.1), (0.21, 0.05, 0.075), bevel=0.005)                                # snout/brow
    for x in (-0.06, -0.02, 0.02, 0.06):
        P("bone_white", (x, -0.158, HZ + 0.06), (0.018, 0.012, 0.035))                                    # fangs
    P("jaguar", (0.075, -0.06, HZ + 0.19), (0.045, 0.04, 0.05), mirror=True)                              # ears
    P("hair_black", (0.075, -0.0605, HZ + 0.19), (0.025, 0.04, 0.03), mirror=True)
    for x, y in ((-0.07, -0.07), (0.05, -0.08), (0.0, 0.0), (-0.05, 0.07), (0.07, 0.04), (-0.08, 0.0), (0.09, -0.01)):
        P("hair_black", (x, y, HZ + 0.1655), (0.032, 0.032, 0.004))                                       # spots
    fan(P, ["feather_green", "feather_blue", "feather_green", "feather_red", "feather_green", "feather_blue", "feather_green"],
        (0.0, 0.07, HZ + 0.15), 0.36, 0.05, (-30, -20, -10, 0, 10, 20, 30))
    face.add_shapes(b)
    return b.finish("mayan", rig=True)


if __name__ == "__main__":
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["roman", "egyptian", "mayan"]
    for w in which:
        ob = {"roman": roman, "egyptian": egyptian, "mayan": mayan}[w]()
        bl.export(ob, os.path.join(HERE, ob.data.name + ".blend"),
                  os.path.join(root, "godot", "assets", "characters", ob.data.name + ".glb"))
