"""3000s augmented person: a heavily upgraded human (NOT a robot), so human face and proportions.
Run:  blender -b -P blends/characters/augmented.py
Asymmetric: wearer's LEFT (+X) arm is fully cybernetic chrome; RIGHT (-X) is a suit sleeve with a
ceramic gauntlet. Real left eye, glowing cyan implant over the right eye, chrome skull plate + antenna
on the right. Glow: eye, chest core, neck ring, elbow ring, forearm seam, wrist band, vents, sole line.
Rigged to the standard skeleton (blends/lib/rig.py). Facing -Y, left = +X.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import bl  # noqa: E402
import face  # noqa: E402

HZ = face.HZ


def build():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part

    # ---------- legs: dark suit, ceramic thigh plates, chrome knee/shin, gunmetal boots ----------
    P("gunmetal", (0.09, -0.035, 0.055), (0.115, 0.285, 0.08), top=(0.92, 0.8), bevel=0.008, mirror=True)   # boot
    P("ceramic_white", (0.09, -0.12, 0.062), (0.1, 0.07, 0.06), bevel=0.006, mirror=True)                  # toe cap
    P("suit_dark", (0.09, -0.035, 0.008), (0.122, 0.295, 0.016), mirror=True)                              # sole
    P("glow_cyan", (0.09, -0.035, 0.019), (0.124, 0.297, 0.005), mirror=True)                              # glowing sole line
    P("suit_dark", (0.09, 0.0, 0.29), (0.125, 0.14, 0.40), top=(1.1, 1.05), bottom=(0.95, 0.95), bevel=0.004, mirror=True)
    P("gunmetal", (0.09, -0.008, 0.19), (0.138, 0.165, 0.24), bevel=0.006, mirror=True)                    # boot shaft
    P("chrome", (0.09, -0.0805, 0.34), (0.105, 0.022, 0.2), bevel=0.004, mirror=True)                      # shin guard
    P("suit_dark", (0.09, 0.0, 0.70), (0.155, 0.175, 0.42), top=(1.1, 1.1), bottom=(0.9, 0.9), bevel=0.004, mirror=True)
    P("ceramic_white", (0.09, -0.098, 0.74), (0.12, 0.026, 0.28), bevel=0.005, mirror=True)                # thigh plate
    P("chrome", (0.09, -0.092, 0.495), (0.115, 0.04, 0.07), bevel=0.005, mirror=True)                      # knee cap
    P("glow_cyan", (0.09, -0.113, 0.495), (0.03, 0.006, 0.03), mirror=True)                                # knee light

    # ---------- torso ----------
    P("suit_dark", (0.0, 0.0, 1.20), (0.37, 0.215, 0.50), top=(1.12, 1.06), bevel=0.006)                   # z 0.95..1.45
    P("suit_dark", (0.0, 0.0, 0.99), (0.355, 0.205, 0.14), bevel=0.005)                                    # hips
    P("gunmetal", (0.0, 0.0, 1.03), (0.38, 0.23, 0.04))                                                    # belt
    P("glow_cyan", (0.0, -0.1175, 1.03), (0.05, 0.006, 0.02))                                              # belt light
    P("ceramic_white", (0.0, -0.1225, 1.30), (0.33, 0.03, 0.30), top=(1.0, 1.0), bottom=(0.5, 1.0), bevel=0.005)  # chest plate (V)
    P("gunmetal", (0.0, -0.1385, 1.31), (0.085, 0.01, 0.085), bevel=0.003)                                 # core housing
    P("glow_cyan", (0.0, -0.1445, 1.31), (0.05, 0.006, 0.05))                                              # core
    P("glow_cyan", (0.0, -0.1405, 1.19), (0.008, 0.006, 0.12))                                             # line from the core
    for z in (1.12, 1.08):
        P("gunmetal", (0.0, -0.111, z), (0.22, 0.008, 0.014))                                              # abdomen ribs
    P("ceramic_white", (0.0, 0.0, 1.455), (0.45, 0.225, 0.08), top=(0.78, 0.85), bevel=0.006)              # yoke
    P("ceramic_white", (0.0, 0.0, 1.515), (0.17, 0.17, 0.05), bevel=0.004)                                 # high collar
    P("glow_cyan", (0.0, 0.0, 1.492), (0.187, 0.187, 0.01))                                                # neck ring
    P("skin", (0.0, 0.0, 1.565), (0.09, 0.095, 0.07))                                                      # neck
    # backpack module with glowing vents
    P("gunmetal", (0.0, 0.14, 1.27), (0.22, 0.09, 0.27), bevel=0.006)
    P("chrome", (0.0, 0.175, 1.27), (0.16, 0.012, 0.2), bevel=0.003)
    for z in (1.34, 1.27, 1.20):
        P("glow_cyan", (0.0, 0.1825, z), (0.12, 0.004, 0.018))
    P("gunmetal", (0.07, 0.15, 1.45), (0.025, 0.025, 0.12), rot=(0, 0, 0), mirror=True)                    # spine cables up into the collar

    # ---------- RIGHT arm (-X): suit sleeve + ceramic gauntlet, ceramic pauldron ----------
    rx = -0.245
    P("ceramic_white", (rx + 0.0, 0.0, 1.5), (0.15, 0.17, 0.07), bevel=0.01)                                # pauldron
    P("suit_dark", (rx, 0.0, 1.33), (0.115, 0.125, 0.29), bottom=(0.9, 0.9), bevel=0.005)
    P("suit_dark", (rx, -0.014, 1.04), (0.1, 0.108, 0.30), top=(1.05, 1.05), bottom=(0.88, 0.88), rot=(-5, 0, 0), bevel=0.004)
    P("ceramic_white", (rx, -0.016, 1.02), (0.115, 0.122, 0.2), bottom=(0.9, 0.9), rot=(-5, 0, 0), bevel=0.005)   # gauntlet
    P("glow_cyan", (rx, -0.0255, 0.90), (0.1, 0.108, 0.012), rot=(-5, 0, 0))                               # wrist band
    P("suit_dark", (rx, -0.028, 0.80), (0.062, 0.095, 0.13), bevel=0.006)                                  # gloved hand
    P("gunmetal", (rx, -0.074, 0.79), (0.06, 0.006, 0.05))                                                 # knuckle plate
    P("suit_dark", (rx + 0.036, -0.06, 0.82), (0.022, 0.04, 0.05))                                         # thumb

    # ---------- LEFT arm (+X): full cybernetic limb ----------
    lx = 0.245
    P("chrome", (lx - 0.005, 0.0, 1.50), (0.12, 0.15, 0.06), bevel=0.01)                                    # small shoulder cap
    P("gunmetal", (lx, 0.0, 1.33), (0.095, 0.105, 0.28), bevel=0.005)                                      # upper-arm core
    P("chrome", (lx + 0.04, 0.0, 1.34), (0.026, 0.1, 0.22), bevel=0.004)                                   # outer plate
    P("chrome", (lx - 0.0, -0.045, 1.34), (0.08, 0.02, 0.22), bevel=0.004)                                 # front plate
    P("gunmetal", (lx, 0.0, 1.18), (0.108, 0.115, 0.07), bevel=0.006)                                      # elbow joint
    P("glow_cyan", (lx, 0.0, 1.18), (0.114, 0.12, 0.01))                                                   # elbow ring
    P("chrome", (lx, -0.014, 1.02), (0.098, 0.108, 0.26), top=(1.05, 1.05), bottom=(0.85, 0.85), rot=(-5, 0, 0), bevel=0.004)  # forearm
    P("glow_cyan", (lx, -0.0715, 1.03), (0.012, 0.004, 0.18), rot=(-5, 0, 0))                              # forearm seam
    P("gunmetal", (lx, -0.025, 0.885), (0.09, 0.098, 0.03), rot=(-5, 0, 0))                                # wrist
    P("gunmetal", (lx, -0.028, 0.835), (0.062, 0.095, 0.07), bevel=0.004)                                  # palm
    P("chrome", (lx, -0.03, 0.765), (0.06, 0.095, 0.07), bevel=0.004)                                      # fingers
    for z in (0.78, 0.76, 0.74):
        P("gunmetal", (lx, -0.03, z), (0.062, 0.097, 0.004))                                               # finger grooves
    P("chrome", (lx - 0.036, -0.06, 0.83), (0.022, 0.04, 0.05))                                            # thumb

    # ---------- head: human face, real left eye, cyber right eye, skull plate ----------
    face.add_face(P, "skin", "skin_shade", None)
    # (no brows/hair: shaved scalp)
    P("ceramic_white", (-0.05, 0.0, HZ + 0.121), (0.115, 0.215, 0.026), bevel=0.006)                        # cranial cap plate (right half)
    P("chrome", (-0.1085, 0.03, HZ + 0.04), (0.013, 0.15, 0.17), bevel=0.003)                               # side plate over the right ear
    P("glow_cyan", (-0.1165, 0.03, HZ + 0.06), (0.004, 0.05, 0.012))                                        # plate light
    P("gunmetal", (-0.045, -0.1135, HZ + 0.012), (0.058, 0.008, 0.042), bevel=0.003)                       # implant housing
    P("glow_cyan", (-0.045, -0.1185, HZ + 0.012), (0.044, 0.006, 0.03))                                    # glowing cyber eye
    P("gunmetal", (-0.085, -0.108, HZ + 0.012), (0.03, 0.01, 0.006))                                       # housing to plate link
    P("chrome", (-0.095, 0.055, HZ + 0.17), (0.006, 0.006, 0.09))                                           # antenna
    P("glow_amber", (-0.095, 0.055, HZ + 0.221), (0.012, 0.012, 0.012))                                    # antenna beacon
    for z in (HZ + 0.03, HZ + 0.005):                                                                      # temple ports, left
        P("gunmetal", (0.1055, -0.03, z), (0.006, 0.024, 0.016))
        P("glow_cyan", (0.1085, -0.03, z), (0.003, 0.012, 0.008))
    P("chrome", (0.1045, -0.04, HZ - 0.075), (0.005, 0.07, 0.014))                                          # jaw implant strip

    face.add_shapes(b)
    ob = b.finish("augmented", rig=True)
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    bl.export(ob, os.path.join(HERE, "augmented.blend"),
              os.path.join(root, "godot", "assets", "characters", "augmented.glb"))
    return ob


if __name__ == "__main__":
    build()
