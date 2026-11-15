"""The Metric pair: black-leather agents in sunglasses with a glowing earpiece LED.
Run:  blender -b -P blends/characters/metric.py            (builds both)
  metric_a: tall, long leather coat (skirt split into per-leg panels so the legs don't clip), goatee
  metric_b: fitted leather jacket, gloves, boots, ponytail
Rigged to the standard skeleton (see blends/lib/rig.py). Facing -Y, left = +X.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
import bl  # noqa: E402
import face  # noqa: E402

HZ = face.HZ


def sunglasses(P, w=0.064, h=0.036):
    for sx in (0.047, -0.047):
        P("lens_dark", (sx, -0.1135, HZ + 0.01), (w, 0.006, h), bevel=0.002)
        P("frame_black", (sx, -0.1165, HZ + 0.01 + h / 2), (w + 0.008, 0.010, 0.006))        # top rim
        P("frame_black", (sx, -0.1165, HZ + 0.01 - h / 2), (w + 0.008, 0.010, 0.005))        # bottom rim
    P("frame_black", (0.0, -0.1165, HZ + 0.02), (0.022, 0.010, 0.008))                        # bridge
    P("frame_black", (0.1045, -0.055, HZ + 0.026), (0.008, 0.125, 0.010), mirror=True)       # temple arms


def earpiece(P):
    """Small earpiece on the wearer's left with a glowing LED."""
    P("frame_black", (0.108, -0.012, HZ - 0.012), (0.012, 0.03, 0.04))
    P("frame_black", (0.108, -0.032, HZ - 0.03), (0.008, 0.02, 0.012))                        # boom toward the mouth
    P("led_green", (0.1155, -0.012, HZ - 0.002), (0.004, 0.012, 0.012))                       # glow


def boots(P, pants, k=1.0):
    P("shoe",   (0.09, -0.035, 0.05), (0.11, 0.28, 0.07), top=(0.9, 0.8), bevel=0.008, mirror=True)
    P("sole",   (0.09, -0.035, 0.008), (0.117, 0.29, 0.016), mirror=True)
    P(pants, (0.09, 0.0, 0.29), (0.125, 0.14, 0.40), top=(1.1, 1.05), bottom=(0.95, 0.95), bevel=0.004, mirror=True)
    P("shoe", (0.09, -0.008, 0.19), (0.135, 0.165, 0.27), bevel=0.006, mirror=True)           # boot shaft
    P("metal_silver", (0.09, -0.092, 0.265), (0.05, 0.006, 0.02), mirror=True)               # boot buckle
    P(pants, (0.09, 0.0, 0.70), (0.155, 0.175, 0.42), top=(1.1, 1.1), bottom=(0.9, 0.9), bevel=0.004, mirror=True)


def metric_a():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, shade = "skin_deep", "skin_deep_shade"
    boots(P, "pants_black")
    # --- long coat: torso + collar + sleeves; skirt is split into per-leg panels on the thigh bones
    P("leather_black", (0.0, 0.0, 1.20), (0.40, 0.225, 0.50), top=(1.12, 1.06), bevel=0.006)          # body 0.95..1.45
    P("leather_black", (0.0, 0.0, 1.455), (0.47, 0.235, 0.08), top=(0.78, 0.85), bevel=0.006)         # shoulders
    P("shirt_black", (0.0, -0.1175, 1.28), (0.12, 0.006, 0.34), bottom=(0.7, 1.0))                    # shirt/vest strip at the open front
    P("leather_black", (0.0, 0.0, 1.00), (0.40, 0.235, 0.10), bevel=0.004)                            # hip band under the belt
    P("leather_trim", (0.0, 0.0, 1.02), (0.405, 0.24, 0.04))                                          # belt
    P("metal_silver", (0.0, -0.121, 1.02), (0.05, 0.010, 0.034))
    P("leather_black", (0.0, 0.0, 1.512), (0.23, 0.21, 0.07), top=(1.06, 1.0), bevel=0.006)           # high stand collar (top just under the jaw)
    P(skin, (0.0, 0.0, 1.565), (0.095, 0.10, 0.07))                                                   # neck (shows above collar front? hidden)
    # skirt panels, one per leg, on the thigh bones
    P("leather_black", (0.105, 0.0, 0.70), (0.21, 0.27, 0.56), top=(1.0, 0.95), bottom=(1.05, 1.1), bevel=0.006, mirror=True)
    P("leather_trim", (0.0, -0.1355, 0.62), (0.40, 0.006, 0.012))                                     # hem-ish stitch strip (front)
    ax = 0.27
    P("leather_black", (ax, 0.0, 1.33), (0.14, 0.145, 0.29), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P("leather_black", (ax, -0.014, 1.04), (0.118, 0.125, 0.30), top=(1.05, 1.05), bottom=(0.88, 0.88),
      rot=(-5, 0, 0), bevel=0.004, mirror=True)
    P("leather_trim", (ax, -0.026, 0.90), (0.126, 0.136, 0.03), rot=(-5, 0, 0), mirror=True)          # cuff strap
    P("metal_silver", (ax, -0.092, 0.90), (0.02, 0.006, 0.026), rot=(-5, 0, 0), mirror=True)
    P(skin, (ax, -0.028, 0.80), (0.062, 0.095, 0.13), bevel=0.006, mirror=True)                       # hands
    P(skin, (ax - 0.036, -0.06, 0.82), (0.022, 0.04, 0.05), mirror=True)
    # --- head: bald, goatee, sunglasses, earpiece
    face.add_face(P, skin, shade, "hair_black", jaw=(0.9, 0.88))
    P("hair_black", (0.0, -0.1135, HZ - 0.098), (0.045, 0.014, 0.05), bevel=0.003)                    # goatee
    P("hair_black", (0.0, -0.1135, HZ - 0.057), (0.058, 0.012, 0.010))                                # thin moustache
    sunglasses(P)
    earpiece(P)
    face.add_shapes(b)
    return b.finish("metric_a", rig=True)


def metric_b():
    bl.reset_scene()
    b = bl.Builder()
    P = b.part
    skin, shade = "skin", "skin_shade"
    boots(P, "pants_black")
    P("leather_trim", (0.115, -0.01, 0.62), (0.03, 0.17, 0.04), mirror=True)                          # thigh strap...
    P("metal_silver", (0.115, -0.096, 0.62), (0.025, 0.005, 0.03), mirror=True)                       # ...and buckle
    # --- fitted jacket
    P("leather_black", (0.0, 0.0, 1.17), (0.34, 0.20, 0.56), top=(1.22, 1.08), bottom=(0.9, 1.0), bevel=0.006)   # z 0.89..1.45, waist narrower than chest
    P("leather_black", (0.0, 0.0, 1.455), (0.41, 0.215, 0.08), top=(0.78, 0.85), bevel=0.006)         # shoulders
    P("leather_trim", (0.0, -0.1085, 1.17), (0.012, 0.006, 0.52))                                     # centre seam
    P("metal_silver", (0.0, -0.1115, 1.17), (0.008, 0.004, 0.50))                                     # zipper
    P("leather_trim", (0.0, 0.0, 1.015), (0.35, 0.215, 0.04))                                         # belt
    P("metal_silver", (0.0, -0.111, 1.015), (0.04, 0.010, 0.030))
    P("leather_black", (0.0, 0.0, 1.512), (0.20, 0.19, 0.07), top=(1.06, 1.0), bevel=0.006)           # collar
    P(skin, (0.0, 0.0, 1.565), (0.085, 0.09, 0.07))
    P("leather_trim", (0.1, -0.1, 1.40), (0.1, 0.012, 0.014), rot=(0, -15, 0), mirror=True)           # chest straps
    ax = 0.23
    P("leather_black", (ax, 0.0, 1.33), (0.11, 0.12, 0.29), bottom=(0.9, 0.9), bevel=0.005, mirror=True)
    P("leather_black", (ax, -0.014, 1.04), (0.094, 0.10, 0.30), top=(1.05, 1.05), bottom=(0.88, 0.88),
      rot=(-5, 0, 0), bevel=0.004, mirror=True)
    P("leather_trim", (ax, -0.026, 0.90), (0.10, 0.108, 0.026), rot=(-5, 0, 0), mirror=True)
    P("leather_black", (ax, -0.028, 0.80), (0.058, 0.09, 0.13), bevel=0.006, mirror=True)             # gloves
    P("leather_black", (ax - 0.034, -0.06, 0.82), (0.02, 0.038, 0.05), mirror=True)
    P("metal_silver", (ax, -0.02, 0.855), (0.058, 0.09, 0.008), mirror=True)                          # glove wrist clasp
    # --- head: slimmer, hair slicked back with a ponytail
    face.add_face(P, skin, shade, "hair_black", width=0.195, jaw=(0.86, 0.85), nose=(0.026, 0.028, 0.045))
    P("hair_black", (0.0, 0.0065, HZ + 0.09), (0.212, 0.247, 0.075), bevel=0.01)                     # top, front ahead of the forehead
    P("hair_black", (0.0, 0.039, HZ + 0.035), (0.198, 0.1619, 0.11), bevel=0.008)                     # sides/back
    P("hair_black", (0.0, 0.135, HZ + 0.02), (0.05, 0.06, 0.13), bevel=0.006)                         # ponytail root
    P("hair_black", (0.0, 0.16, HZ - 0.085), (0.045, 0.045, 0.20), bottom=(0.7, 0.7), bevel=0.006)    # ponytail
    sunglasses(P, w=0.060, h=0.032)
    earpiece(P)
    face.add_shapes(b)
    return b.finish("metric_b", rig=True)


if __name__ == "__main__":
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["a", "b"]
    for w in which:
        ob = {"a": metric_a, "b": metric_b}[w]()
        bl.export(ob, os.path.join(HERE, ob.data.name + ".blend"),
                  os.path.join(root, "godot", "assets", "characters", ob.data.name + ".glb"))
