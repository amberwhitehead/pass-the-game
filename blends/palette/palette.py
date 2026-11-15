"""Shared character palette. Pure Python (no Blender needed).

A 16x16 grid of 8px cells -> 128x128 textures (256 cells). Every face in a character mesh has all of
its UVs at the centre of one cell, so a face is a single flat colour.

Three textures share the same layout:
  palette_albedo.png  base colour (sRGB)
  palette_mr.png      glTF metallic-roughness: G = roughness, B = metallic
  palette_emit.png    emission colour (black = no glow)

APPEND-ONLY: a cell's index is its position in ENTRIES. Never reorder or delete, or
existing characters change colour. Add new colours at the end.

Run directly to (re)write the PNGs:  python3 blends/palette/palette.py
"""
import os
import struct
import zlib

GRID = 16
CELL = 8
SIZE = GRID * CELL

# name: (hex colour, roughness, metallic, glow)
# Metals stay below metallic=1.0: fully metallic cells depend entirely on the scene's reflections
# and render muddy/dark in a plain environment.   glow 0..1 multiplies colour into emission
ENTRIES = [
    # --- skin / hair / face ---
    ("skin",          "#e0a98a", 0.8, 0.0, 0.0),
    ("skin_shade",    "#c98c6e", 0.8, 0.0, 0.0),
    ("hair_brown",    "#4a3020", 0.9, 0.0, 0.0),
    ("eye",           "#241810", 0.5, 0.0, 0.0),
    ("mouth",         "#a85c52", 0.8, 0.0, 0.0),
    # --- cloth ---
    ("shirt_white",   "#f2f0ea", 0.9, 0.0, 0.0),
    ("shirt_shade",   "#d4d2cc", 0.9, 0.0, 0.0),
    ("tie_black",     "#1c1c20", 0.8, 0.0, 0.0),
    ("trousers",      "#2e3036", 0.9, 0.0, 0.0),
    ("belt",          "#1a1512", 0.6, 0.0, 0.0),
    ("shoe",          "#15110f", 0.4, 0.0, 0.0),
    ("sole",          "#3a2e26", 0.9, 0.0, 0.0),
    # --- accessories ---
    ("frame_black",   "#111114", 0.4, 0.0, 0.0),
    ("lens",          "#a9c4d4", 0.1, 0.0, 0.0),
    ("protector",     "#c8d0d6", 0.4, 0.0, 0.0),
    ("pen_black",     "#202024", 0.5, 0.0, 0.0),
    ("pen_red",       "#b8322c", 0.5, 0.0, 0.0),
    ("pen_blue",      "#2f55a8", 0.5, 0.0, 0.0),
    ("strap_leather", "#6b4527", 0.7, 0.0, 0.0),
    # --- metal / glow ---
    ("metal_silver",  "#c9ccd2", 0.3, 0.75, 0.0),
    ("lume_green",    "#9dff8a", 0.5, 0.0, 1.0),
    # --- army officer ---
    ("hair_dark",     "#2b211c", 0.9, 0.0, 0.0),
    ("army_green",    "#4e5a3a", 0.9, 0.0, 0.0),
    ("army_green_shade", "#3f4a2f", 0.9, 0.0, 0.0),
    ("army_trousers", "#59653f", 0.9, 0.0, 0.0),
    ("shirt_khaki",   "#bba77c", 0.9, 0.0, 0.0),
    ("visor_black",   "#0c0c0e", 0.15, 0.0, 0.0),
    ("brass",         "#d1a93a", 0.3, 0.75, 0.0),
    ("ribbon_red",    "#b32b2b", 0.8, 0.0, 0.0),
    ("ribbon_blue",   "#2b4aa8", 0.8, 0.0, 0.0),
    ("ribbon_green",  "#2e7d3e", 0.8, 0.0, 0.0),
    ("ribbon_yellow", "#d9b92e", 0.8, 0.0, 0.0),
    # --- officer variations / rig details ---
    ("mouth_dark",    "#3a1410", 0.8, 0.0, 0.0),
    ("hair_gray",     "#8f8f90", 0.9, 0.0, 0.0),
    ("army_pinks",    "#b39a8a", 0.9, 0.0, 0.0),
    ("skin_brown",    "#a97650", 0.8, 0.0, 0.0),
    ("skin_brown_shade", "#8e5f3e", 0.8, 0.0, 0.0),
    # --- Metric (black leather) ---
    ("leather_black", "#17171a", 0.28, 0.0, 0.0),
    ("leather_trim",  "#2a2a2f", 0.45, 0.0, 0.0),
    ("shirt_black",   "#26262a", 0.8, 0.0, 0.0),
    ("pants_black",   "#1d1d21", 0.5, 0.0, 0.0),
    ("lens_dark",     "#06060a", 0.08, 0.4, 0.0),
    ("hair_black",    "#121012", 0.6, 0.0, 0.0),
    ("skin_deep",     "#6a4430", 0.8, 0.0, 0.0),
    ("skin_deep_shade", "#553525", 0.8, 0.0, 0.0),
    ("led_green",     "#37ff6a", 0.4, 0.0, 1.0),
    # --- augmented person ---
    ("ceramic_white", "#e6eaee", 0.35, 0.1, 0.0),
    ("chrome",        "#d6dbe2", 0.22, 0.7, 0.0),
    ("gunmetal",      "#4a505a", 0.35, 0.55, 0.0),
    ("suit_dark",     "#20242b", 0.6, 0.0, 0.0),
    ("glow_cyan",     "#5ee8ff", 0.3, 0.0, 1.0),
    ("glow_amber",    "#ffb347", 0.3, 0.0, 1.0),
    # --- ancient cultures: Roman / Egyptian / Mayan ---
    ("roman_red",     "#a2221e", 0.9, 0.0, 0.0),
    ("steel",         "#aab0b9", 0.3, 0.7, 0.0),
    ("bronze",        "#b4803c", 0.35, 0.75, 0.0),
    ("skin_tan",      "#bb8355", 0.8, 0.0, 0.0),
    ("skin_tan_shade", "#a06c45", 0.8, 0.0, 0.0),
    ("linen",         "#ece5d2", 0.9, 0.0, 0.0),
    ("linen_shade",   "#cfc7b0", 0.9, 0.0, 0.0),
    ("gold",          "#e0b73c", 0.25, 0.75, 0.0),
    ("lapis",         "#2a4fa8", 0.4, 0.0, 0.0),
    ("turquoise",     "#2fb5b0", 0.4, 0.0, 0.0),
    ("wood",          "#7a5230", 0.85, 0.0, 0.0),
    ("kohl",          "#0f0e10", 0.5, 0.0, 0.0),
    ("jade",          "#3fae86", 0.3, 0.0, 0.0),
    ("jaguar",        "#d49a2c", 0.8, 0.0, 0.0),
    ("feather_green", "#1fa05a", 0.8, 0.0, 0.0),
    ("feather_blue",  "#2c78d6", 0.8, 0.0, 0.0),
    ("feather_red",   "#d03a2a", 0.8, 0.0, 0.0),
    ("maya_blue",     "#3a9bb5", 0.8, 0.0, 0.0),
    ("paint_red",     "#b3261e", 0.8, 0.0, 0.0),
    ("obsidian",      "#0d0d12", 0.1, 0.3, 0.0),
    ("bone_white",    "#efe6cf", 0.6, 0.0, 0.0),
    # --- Egyptian stonework / machinery (platform props) ---
    ("stone_mid",     "#b89a6c", 0.95, 0.0, 0.0),
    ("stone_warm",    "#c4a273", 0.95, 0.0, 0.0),
    ("stone_light",   "#d2b98d", 0.95, 0.0, 0.0),
    ("stone_pale",    "#e0cfa8", 0.95, 0.0, 0.0),
    ("stone_dark",    "#957a54", 0.95, 0.0, 0.0),
    ("stone_deep",    "#6e5a3f", 0.95, 0.0, 0.0),
    ("stone_red",     "#b27d55", 0.95, 0.0, 0.0),
    ("basalt",        "#3f3b38", 0.6, 0.0, 0.0),
    ("rope",          "#c9ab6e", 0.95, 0.0, 0.0),
    ("rope_dark",     "#9a7c46", 0.95, 0.0, 0.0),
    ("wood_dark",     "#573a22", 0.85, 0.0, 0.0),
    ("wood_light",    "#9a7345", 0.85, 0.0, 0.0),
    ("bronze_dark",   "#8c6030", 0.4, 0.7, 0.0),
    ("verdigris",     "#4f8f72", 0.6, 0.2, 0.0),
    ("water",         "#3fb6c9", 0.2, 0.0, 0.0),
    ("sand",          "#dcc48f", 0.95, 0.0, 0.0),
    # weathered painted accents (muted, so they sit in the stone)
    ("paint_ochre",   "#b0623f", 0.95, 0.0, 0.0),
    ("paint_blue",    "#3f6f9e", 0.95, 0.0, 0.0),
    ("paint_green",   "#4e9275", 0.95, 0.0, 0.0),
    # --- Roman engineering: brick, travertine, marble, lead, porphyry, mosaic ---
    ("brick_red",     "#b4583b", 0.9, 0.0, 0.0),
    ("brick_dark",    "#97472f", 0.9, 0.0, 0.0),
    ("brick_light",   "#c8704d", 0.9, 0.0, 0.0),
    ("travertine",    "#d8ccae", 0.85, 0.0, 0.0),
    ("travertine_dark", "#bdb190", 0.85, 0.0, 0.0),
    ("marble",        "#eeeadf", 0.45, 0.0, 0.0),
    ("marble_cream",  "#e3d9bf", 0.5, 0.0, 0.0),
    ("marble_grey",   "#b9b8b2", 0.5, 0.0, 0.0),
    ("porphyry",      "#5a2f3c", 0.4, 0.0, 0.0),
    ("concrete_dark", "#4d4a45", 0.95, 0.0, 0.0),
    ("lead",          "#6f747b", 0.55, 0.45, 0.0),
    ("laurel",        "#4f7f3c", 0.9, 0.0, 0.0),
    ("laurel_dark",   "#3a5f2d", 0.9, 0.0, 0.0),
    ("tessera_black", "#1d1d20", 0.6, 0.0, 0.0),
    ("tessera_white", "#efece0", 0.6, 0.0, 0.0),
    ("tessera_red",   "#a6382c", 0.6, 0.0, 0.0),
    # --- 1950s computer room: enamel cabinets, chrome, bakelite, tubes, lamps ---
    ("enamel_mint",   "#9ccbb5", 0.35, 0.0, 0.0),
    ("enamel_mint_dark", "#78ad97", 0.35, 0.0, 0.0),
    ("enamel_cream",  "#eae2c8", 0.4, 0.0, 0.0),
    ("enamel_gray",   "#8a9498", 0.4, 0.0, 0.0),
    ("enamel_charcoal", "#363b40", 0.45, 0.0, 0.0),
    ("enamel_red",    "#c23a2b", 0.35, 0.0, 0.0),
    ("enamel_teal",   "#2c8c8e", 0.35, 0.0, 0.0),
    ("enamel_yellow", "#e8b92e", 0.4, 0.0, 0.0),
    ("bakelite",      "#1d1a18", 0.25, 0.0, 0.0),
    ("panel_black",   "#17191c", 0.5, 0.0, 0.0),
    ("dial_white",    "#f1eee2", 0.6, 0.0, 0.0),
    ("tape_brown",    "#6b4a33", 0.7, 0.0, 0.0),
    ("lamp_red",      "#ff4b3a", 0.3, 0.0, 1.0),
    ("lamp_white",    "#fff1cf", 0.3, 0.0, 1.0),
]
assert len(ENTRIES) <= GRID * GRID

INDEX = {e[0]: i for i, e in enumerate(ENTRIES)}


def idx(name):
    return INDEX[name]


def cell_uv(i):
    """UV (u, v) of the centre of cell i. Cell 0 is top-left; v is up (Blender/glTF-flip safe)."""
    col, row = i % GRID, i // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _png(path, pixels):
    """pixels: SIZE x SIZE list of rows of (r,g,b)."""
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)


def write_pngs(out_dir):
    albedo, mr, emit = [], [], []
    for y in range(SIZE):
        ra, rm, re = [], [], []
        for x in range(SIZE):
            i = (y // CELL) * GRID + (x // CELL)
            if i < len(ENTRIES):
                _, hx, rough, metal, glow = ENTRIES[i]
                c = _rgb(hx)
            else:  # unused cells: magenta so mistakes are obvious
                c, rough, metal, glow = (255, 0, 255), 1.0, 0.0, 0.0
            ra.append(c)
            rm.append((255, round(rough * 255), round(metal * 255)))
            re.append(tuple(round(v * glow) for v in c))
        albedo.append(ra); mr.append(rm); emit.append(re)
    _png(os.path.join(out_dir, "palette_albedo.png"), albedo)
    _png(os.path.join(out_dir, "palette_mr.png"), mr)
    _png(os.path.join(out_dir, "palette_emit.png"), emit)


if __name__ == "__main__":
    write_pngs(os.path.dirname(os.path.abspath(__file__)))
    print("wrote palette PNGs,", len(ENTRIES), "of", GRID * GRID, "cells used")
