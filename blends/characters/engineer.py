"""1950s NASA-style engineer. Run:  blender -b -P blends/characters/engineer.py
Output: blends/characters/engineer.blend and godot/assets/characters/engineer.glb
Facing -Y. Wearer's left = +X. ~1.82 m tall. Rigged to the standard skeleton (blends/lib/rig.py).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import bl  # noqa: E402
import face  # noqa: E402

bl.reset_scene()
b = bl.Builder()
P = b.part

# ---------- legs (mirrored: x given for wearer's left) ----------
P("shoe",   (0.085, -0.035, 0.05), (0.105, 0.27, 0.07), top=(0.9, 0.8), bevel=0.008, mirror=True)
P("sole",   (0.085, -0.035, 0.008), (0.112, 0.28, 0.016), mirror=True)
P("trousers", (0.085, 0.0, 0.29), (0.125, 0.14, 0.40), top=(1.1, 1.05), bottom=(0.95, 0.95), bevel=0.004, mirror=True)   # shin
P("trousers", (0.085, 0.0, 0.70), (0.15, 0.17, 0.42), top=(1.1, 1.1), bottom=(0.9, 0.9), bevel=0.004, mirror=True)       # thigh
P("trousers", (0.0, 0.0, 0.96), (0.35, 0.20, 0.16), top=(1.0, 1.0), bevel=0.006)                                        # hips
P("belt", (0.0, 0.0, 1.015), (0.355, 0.208, 0.035))
P("metal_silver", (0.0, -0.106, 1.015), (0.04, 0.012, 0.03))                                                              # buckle

# ---------- torso ----------
P("shirt_white", (0.0, 0.0, 1.22), (0.34, 0.20, 0.40), top=(1.18, 1.1), bevel=0.006)
P("shirt_white", (0.0, 0.0, 1.455), (0.43, 0.22, 0.08), top=(0.78, 0.85), bottom=(1.0, 1.0), bevel=0.006)                  # shoulders
P("shirt_shade", (0.0, 0.0, 1.505), (0.17, 0.17, 0.04), bevel=0.004)                                                      # collar
P("skin", (0.0, 0.0, 1.545), (0.095, 0.10, 0.08))                                                                         # neck

# tie, knot, clip   (chest front is at about y = -0.105..-0.11)
P("tie_black", (0.0, -0.117, 1.485), (0.05, 0.03, 0.04), bevel=0.004)                                                     # knot
P("tie_black", (0.0, -0.1105, 1.25), (0.04, 0.012, 0.46), bottom=(1.1, 1))                                                # blade
P("metal_silver", (0.0, -0.118, 1.30), (0.052, 0.006, 0.012))                                                             # tie clip
# pocket protector + pens, wearer's left chest
P("protector", (0.105, -0.1135, 1.33), (0.075, 0.012, 0.09))
P("pen_black", (0.088, -0.1135, 1.385), (0.010, 0.010, 0.04))
P("pen_red",   (0.105, -0.1135, 1.39), (0.010, 0.010, 0.05))
P("pen_blue",  (0.122, -0.1135, 1.385), (0.010, 0.010, 0.04))

# ---------- arms (short sleeve) ----------
ax = 0.245
P("shirt_white", (ax, 0.0, 1.385), (0.12, 0.13, 0.19), top=(1.0, 1.0), bottom=(0.88, 0.88), bevel=0.005, mirror=True)    # sleeve
P("skin", (ax, 0.0, 1.20), (0.085, 0.095, 0.17), top=(0.95, 0.95), bevel=0.004, mirror=True)                              # upper arm
P("skin", (ax, -0.012, 0.99), (0.08, 0.09, 0.26), top=(1.05, 1.05), bottom=(0.8, 0.8), rot=(-6, 0, 0), bevel=0.004, mirror=True)   # forearm
P("skin", (ax, -0.028, 0.82), (0.06, 0.095, 0.12), bevel=0.006, mirror=True)                                              # hand
P("skin", (ax - 0.036, -0.06, 0.835), (0.022, 0.04, 0.05), mirror=True)                                                   # thumb (inner side)
# wristwatch on wearer's left (+X): leather strap, steel case, glowing lume dial
P("strap_leather", (ax, -0.020, 0.90), (0.088, 0.098, 0.03))
P("metal_silver", (ax, -0.056, 0.90), (0.052, 0.018, 0.045))
P("lume_green", (ax, -0.0675, 0.90), (0.034, 0.005, 0.03))

# ---------- head ----------
HZ = 1.67  # head centre
P("skin", (0.0, 0.0, HZ), (0.205, 0.225, 0.255), bottom=(0.82, 0.85), bevel=0.012)
P("skin", (0.0, -0.118, HZ - 0.03), (0.028, 0.03, 0.045), bevel=0.003)                                                    # nose
P("skin_shade", (0.101, 0.0, HZ - 0.005), (0.016, 0.03, 0.05), mirror=True)                                               # ears
P("mouth", (0.0, -0.1085, HZ - 0.075), (0.05, 0.006, 0.010), tag="mouth")
P("mouth_dark", (0.0, -0.1088, HZ - 0.075), (0.036, 0.004, 0.0004), tag="mouth_in")                                         # mouth interior, hidden until open
P("skin_shade", (0.0, -0.1085, HZ - 0.092), (0.06, 0.006, 0.012), tag="chin")                                                         # chin shadow
for sx in (0.045, -0.045):
    P("eye", (sx, -0.1095, HZ + 0.012), (0.022, 0.006, 0.018), tag="eye")
    P("hair_brown", (sx, -0.1105, HZ + 0.045), (0.05, 0.008, 0.01))                                                       # brow
# glasses: thick black frames, tinted lenses, temples to the ears
for sx in (0.047, -0.047):
    P("lens", (sx, -0.113, HZ + 0.012), (0.062, 0.004, 0.040))
    P("frame_black", (sx, -0.1165, HZ + 0.0335), (0.072, 0.012, 0.008))           # top rim
    P("frame_black", (sx, -0.1165, HZ - 0.0095), (0.072, 0.012, 0.006))           # bottom rim
    P("frame_black", (sx + (0.033 if sx > 0 else -0.033), -0.1165, HZ + 0.012), (0.006, 0.012, 0.04))  # outer rim
    P("frame_black", (sx + (-0.033 if sx > 0 else 0.033), -0.1165, HZ + 0.012), (0.006, 0.012, 0.04))  # inner rim
    P("frame_black", (sx * 2.1, -0.055, HZ + 0.032), (0.008, 0.12, 0.012))        # temple arm
P("frame_black", (0.0, -0.1165, HZ + 0.026), (0.02, 0.012, 0.008))                # bridge
# hair: short, combed back/up, with a little front pompadour.
# (Values measured from the hand-edited engineer.blend.)
P("hair_brown", (0.0, 0.012, HZ + 0.095), (0.22, 0.235, 0.07), bevel=0.01)                  # top
P("hair_brown", (0.0, 0.03905, HZ + 0.03), (0.2, 0.1619, 0.12), bevel=0.008)                 # sides/back, front pushed forward = sideburns
P("hair_brown", (0.0, -0.085, HZ + 0.135), (0.19, 0.07, 0.04), bevel=0.008)                 # front quiff
P("hair_brown", (0.0, -0.05, HZ + 0.1), (0.205, 0.10, 0.03), bevel=0.006)                   # front band

face.add_shapes(b)
ob = b.finish("engineer", rig=True)   # rigged: standard skeleton, blink/mouth_open, walk/idle/head_turn/talk
root = os.path.abspath(os.path.join(HERE, "..", ".."))
bl.export(ob, os.path.join(HERE, "engineer.blend"),
          os.path.join(root, "godot", "assets", "characters", "engineer.glb"))
