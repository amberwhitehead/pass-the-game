# Character pipeline

Low-poly blocky characters, flat-coloured from a tiny shared palette texture.

    blender -b -P blends/characters/engineer.py        # -> .blend + godot/assets/characters/engineer.glb
    blender -b -P blends/characters/officer.py         # Major, rigged
    blender -b -P blends/characters/officer_colonel.py # variation, rigged
    blender -b -P blends/characters/metric.py          # metric_a (long coat) + metric_b (jacket), rigged
    blender -b -P blends/characters/augmented.py       # augmented person, rigged
    blender -b -P blends/characters/ancient.py         # roman, egyptian, mayan, rigged
    blender -b -P blends/props/newton_platform.py      # Newton's Table platform + controls (Egyptian machine) -> godot/assets/props/
    blender -b -P blends/props/turing_platform.py      # Turing Table platform + controls (Roman machine-house) -> godot/assets/props/
    blender -b -P blends/props/mainframe_platform.py   # 1950s mainframe platform + example control kit (no minigame yet)

- `palette/palette.py` — 16x16 cell palette (128x128 px): albedo, metal/rough, emission PNGs.
  **Append-only**: never reorder/delete entries. Every face's UVs sit on one cell centre.
- `lib/bl.py` — box-part builder (`part()`), palette UVs, material, glTF export.
- `lib/face.py` — shared head/face parts and the blink/mouth_open shape keys.
- `lib/rig.py` — skeleton, shape keys and animations (conventions below).
- `characters/*.py` — one generator per character; the `.blend` is generated output.
  If you hand-edit a `.blend`, tell the generator owner so the script can be updated to
  match (don't re-run a generator over hand edits).
- `preview/render.py`, `preview/render_pose.py` — turnaround / pose renders for review (Blender).
- `preview/lineup.gd` — Godot lineup of every character under neutral lighting (see header for the command).

Held items (spears, shield, club) must be pinned with `part(..., bone='lower_arm.R')` or they tear apart
when the arm moves. Skirts/kilts/coats are per-leg panels on the thigh bones so legs never clip them.

Units are metres, feet at z=0, character faces **-Y** in Blender (+Z in Godot). Wearer's
left is +X. One mesh, one material, ~1.5-2k triangles.

## Rig conventions (all rigged NPCs)
Bones: `root`, `torso`, `head`, `upper_arm.L/R`, `lower_arm.L/R` (includes hand),
`upper_leg.L/R`, `lower_leg.L/R`, `foot.L/R`. Every part is rigidly weighted to one bone,
chosen automatically from where it sits (`bl.auto_bone`) or via `part(..., bone=)`.

Shape keys: `mouth_open`, `blink` (tag the parts `tag="mouth"`, `"mouth_in"`, `"chin"`, `"eye"`).

Animations (names ending `-loop` become looping in Godot): `idle`, `walk`, `head_turn`
(bones) and `talk`, `blink` (blend shapes only — layer over body animations).
Saved `.blend` files have all NLA tracks muted (rest pose); unmute one to preview it.

## Godot side
`godot/assets/characters/post_import.gd` strips the exporter's constant padding tracks from
face animations. Set it as the Import Script of each rigged `.glb`
(`import_script/path="res://assets/characters/post_import.gd"` in its `.glb.import`).
Textures use nearest filtering (with mipmaps). Metal cells are kept below metallic=1.0 (~0.55-0.75): fully
metallic surfaces go muddy unless the scene has good reflections.

## Props
`lib/blocks.py` holds the shared block/prism/gear/polar-course helpers both platforms use.

`props/newton_platform.py` builds the round, block-built Egyptian platform for Newton's Table (stone, bronze, wood, rope),
in **game scale** (display disc r=2.2, display surface at z=0; scale it down uniformly for the room). The module docstring lists
the exported nodes (`Platform`, `DisplaySurface`, `roller_0..3`, `reset_button`, `crystal_socket_*`, `inscription_anchor`) and the
angle convention. Layout constants at the top mirror `newton.gd`; if those move, change them there too. It reuses the character
palette (cells appended at the end: stone, rope, wood, bronze_dark, weathered paints). Review renders:

    blender -b blends/props/newton_platform.blend -P blends/preview/render_platform.py -- out/prefix game_250 room_20 top close_45_3.4_-2.0_1.4_0.5

`props/turing_platform.py` is the Roman counterpart for the Turing Table: a two-tier brick-and-travertine arcade (voussoir arches,
engaged Tuscan columns, Doric frieze, dentils) with eight machines or lamp grilles behind the arches (waterwheel, gear train,
Archimedes screw, aeolipile, ballista, crane, reel), a red attic band with laurel swags, and a marble deck with a porphyry
inscription track, mosaic border, Roman-numeral rim marks, two cylinder trays, a groma, and wells for the four rollers
(fluted marble drums with pinions meshing idler gears). Layout constants mirror `turing.gd`; nodes are listed in its docstring.

`props/mainframe_platform.py` is the 1950s mainframe cabinet for a minigame that is not built yet: a 16-door drum in mint enamel and
chrome (tape drives, tube racks, lamp panels, patch panels, gauges, card reader, magnetic drum, rocket emblem), rocket-style
fins, and on the deck an example control kit for the game designer: eight clusters (toggle bank, knobs with dial scales,
illuminated push buttons, gauges with needles, slide faders, 12-way selector and small knobs, nixie tubes and key switch, a
guarded mushroom button and card slot). Every moving control is its own node with its pivot as origin (names and axes in the
script's docstring); static plates, scales and lamps are in `Platform`. Lamps and tube glows use the palette emission cells.
