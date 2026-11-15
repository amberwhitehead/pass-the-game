# Pass The Game (Godot 4.7, GL Compatibility, Web/mobile first)

Flow: `intro` (2D story) → `room` (3D hub) → mini-games (overlay scenes).

## Layout
- `autoload/` — `Game` (flags, input map), `SceneManager` (fade scene change),
  `TouchControls` (on-screen D-pad left quarter / A+B right quarter, lower third),
  `Dialogue` (`await Dialogue.say(name, lines)`), `MiniGames` (registry + launcher).
- `scenes/intro/` — story pages; edit `PAGES` in `intro.gd`.
- `scenes/room/` — `room.tscn` instances `player`, `npc`, `prop`, `door` (x2) and a `HexFloor` (7x10 tiles, 2 m each, ~15 x 18 m, long axis along x). Walls, pillars and lamps are built in `room.gd` from the floor size. Six stations (a `Prop` plus the `NPC` standing beside it) sit in a 3x2 grid. Two are real 3D mini-games, Egypt Fractal (`newton`: park three pyramids on three different fractal colours; `newton_math.gd` is the CPU twin of the shader and must stay in sync) and Roman Flow (`turing`); the other four (`Challenge1`, `2`, `3`, `6`) are placeholders (a `Prop` with no `minigame_id` says it isn't ready). Each station has one NPC standing beside it (placed in `room.tscn`): 50s Engineer–Challenge 1 (the mainframe platform), Mayan–Challenge 2, Posthuman–Challenge 3 (the z = +3.6 row), Egyptian–Egypt Fractal, Roman–Roman Flow, Metric A–Challenge 6 (the z = −3.6 row). **Trophies:** when a mini-game with a `"trophy"` entry in `MiniGames.REGISTRY` is won, the room's `Prop` hides its floating shape and its platform shows what the game built (`Prop._refresh_completed`): `newton_trophy.gd` (the three pyramids joined by glowing ribbons) and `turing/aqueduct.gd` (an aqueduct over the winning path with water running through it). The same classes play the win animation inside the games. The wall detail between the pillars on the north and south walls is `greebles.gd` (about 1,600 instanced rectangles in two draw calls). `DoorWest` is the industrial double door (`door_industrial.tscn`: push bar, wire-glass window, swinging leaves; `DoorEast` keeps the sliding sci-fi one). Two officers stand either side of the west door facing into the room, and Metric B stands against the east wall (`room.gd` positions these from the door/wall positions).
- `assets/characters/` — rigged character `.glb`s from `blends/` (see `blends/README.md`). An `NPC` takes one as its `model`: it plays `idle`, blinks at random, and plays `talk` while speaking (face animations run on a second `AnimationPlayer` so they layer over the body one). `post_import.gd` must be the Import Script of each rigged `.glb`.
- `minigames/<id>/` — one folder per mini-game; root script `extends MiniGame`.
- `assets/fonts/` — DejaVu Sans, the project default font and `ThemeDB.fallback_font` (set in `Game._ready`); the built-in font lacks arrows/superscripts/✕ and web builds have no system fallback.
- Newton shader note: with `discrete_colors` off (`DISCRETE_COLORS = false` in `newton.gd`) the fractal colours each root by a continuous hue around the cyan/yellow/magenta wheel; at high Re(p) this gives a rainbow of many basins and looks great. Worth reusing for another puzzle. The game itself needs exactly three colours, so it is on by default.
- `turing` (Turing Table) is a separate, self-contained 3D orbit-camera game: Gray-Scott reaction-diffusion on the table, run on the GPU as a ring of float SubViewports (`shaders/turing_step.gdshader`, drawn by `turing_surface.gdshader`). Rollers set feed/kill/Du/Dv; placed glass cylinders pin the colour under them. It shares no code with `newton`. Goal: a maze. Connect the teal start/end points with teal, and each amber flanking pair with amber; a flood-fill solver runs on a worker thread against snapshots of the state, and the Viz rim button toggles drawing the routes it found (off by default).
- `assets/props/` — platform `.glb`s from `blends/props/` (see `blends/README.md`): `newton_platform` and `turing_platform` are the tables in those two mini-games (`DisplaySurface` carries the shader, `roller_n` / `*_button` are the controls, highlighted with an additive `material_overlay` because the whole platform shares one material), and all three are also the decorative stations in the room (`scenes/room/platform.tscn`, scaled 0.3 with a collider; `mainframe_platform` has no mini-game yet).
- `tools/` — dev tools: `bench.tscn` (room frame-time/draw-call benchmark; options `--won`, `--hide-platforms`, `--hide-greebles`, `--door-open`, `--shots=`) and `minigame_shot.tscn` (screenshots + smoke test of an orbiting-table mini-game; `--win` fakes solving it to watch the win animation), `fake_results.gd` (fake won results). Usage in each script's header.
- `shaders/` — hologram, glow_floor, crystal, newton_fractal (3D), story_bg, vignette (2D).

## Add a mini-game
1. `minigames/foo/foo.tscn` + `foo.gd` (`extends MiniGame`, call `finish({"won": true})`).
2. Add `"foo": {"title": ..., "scene": ...}` to `REGISTRY` in `autoload/minigames.gd`.
3. Set `minigame_id = "foo"` on a Prop in `room.tscn` (replace a `ChallengeN` placeholder's empty `minigame_id`).

## Input (first person)
- **Touch:** on-screen pad (▲▼ walk, ◀▶ turn, A interact, B back) + drag anywhere else to look.
- **Mouse:** click-drag to look (touch emulation), pad buttons clickable.
- **Keyboard:** W/S or ↑/↓ walk, A/D or ←/→ turn, E/Space/Enter/F interact, Esc/Backspace back.
- **Gamepad:** left stick walk/strafe, right stick look, D-pad walk/turn, A interact, B back.
- The on-screen pad fades out when a key/gamepad is used and returns on the next touch.
- Actions are registered in `autoload/game.gd`. On-screen buttons send real `InputEventAction`s
  (not just `Input.action_press`) so event handlers fire.

## Web
Install export templates, then `./serve_web.sh` (single-threaded build, so no COOP/COEP headers needed).
