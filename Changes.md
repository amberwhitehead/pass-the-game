# Changes

A record of each contribution to Pass The Game, oldest first. Each day is a
different contributor's turn, so commits are grouped by contributor and day.
Each turn's [handoff notes](docs/HANDOFF.md) describe the current state in more
depth; this file keeps the history of who added what.

## Amber Whitehead — November 15, 2026

### `dea8946` — Repository created

A one-line `README.md` started the project.

## rmurrish — November 15, 2026

### `dea473d` — Godot Web/mobile project with an intro, a first-person room and two puzzles

Built with Claude Sonnet 5.5; the commit squashes about seventeen smaller steps.

- **Framework.** A 2D story intro with shader backgrounds and procedural art; a
  first-person 3D hex-tile room with double doors, NPCs and interactable props;
  drag-to-look plus keyboard, gamepad and multi-touch on-screen controls that
  fade when other input is used; a minigame registry and launcher; a Web export
  preset and serve script.
- **Characters.** A Blender pipeline (`blends/`) with a shared append-only
  palette, box-part builder, standard rig and face module. Nine rigged
  characters with idle, blink, talk and head-turn animations: the Major and
  Colonel officers, the 50s Engineer, two Metric agents, the Posthuman
  (augmented), and Roman, Egyptian and Mayan figures. NPCs face the player
  while speaking.
- **Egypt Fractal** (Newton's Table). Park three pyramids on different colors of
  a Newton fractal to light three crystals. A shader draws the fractal and
  `newton_math.gd` checks basins on the CPU. Winning joins the pyramid tips with
  glowing ribbons.
- **Roman Flow** (Turing Table). A Gray–Scott reaction-diffusion simulation on
  the GPU, with rollers for its parameters and placeable glass pins. A
  worker-thread flood fill checks the maze goal; winning raises an aqueduct with
  running water.
- **Room.** Six stations in a larger hall, each with its character beside it;
  three placeholder stations after the example games were removed; round
  Egyptian, Roman and mainframe platforms; an industrial west door; instanced
  wall greebles; won games leave a trophy on their platform.
- **Fixes and tools.** NPC dialogue now survives Web exports (every NPC had said
  "Hello there."). Room benchmark, minigame screenshot and fake-result dev tools.

## cee.wtf — November 16, 2026

### `82d6510` — Refraction Hall, the prism connector, the Brothers' card game, sound and tests

Committed by Amber Whitehead. The commit message is brief;
[the handoff](docs/HANDOFF.md) written in this turn describes it in full.

- **Refraction Hall.** The room became a main hall with six square side
  chambers. Egypt Fractal and Roman Flow keep their rooms; rooms 04–06
  (Workshop, Calendar, Observatory) are furnished placeholders.
- **Prism connector.** Egypt's first win reveals two portable prisms with a
  camera reveal. The player carries one prism or lens at a time and routes a
  beam through yellow and blue lenses (making green) to unlock Roman Flow.
- **The Brothers' card game** (room 03). Little Brother teaches a three-lane
  creature/spell game; Older Brother plays four lanes with interception,
  diagonal attacks, lane swaps and finite reserves. Cards, score and turn bell
  sit on a physical 3D table reached by a live camera move from the hall. Five
  cards hidden around the hall join Older Brother's deck when found.
- **Balance laboratory.** Headless bots play the real card rules; Python tools
  produce HTML reports on pacing, card use and progression.
- **Sound.** A CC0 Kenney sound pass for cards, hall ambience, footsteps, optics
  and mechanisms, with a persistent mixer and a browser audition page.
- **Presentation and process.** A shared ivory/enamel/brass UI style; about
  twenty-four headless test suites; module guides; `docs/HANDOFF.md` and
  `AGENTS.md`.

## tesseract — November 17, 2026

### `bda8047` — Test fixes found by running the suite on Windows

On a clean checkout with Godot 4.7.2, three suites failed and one silently
skipped checks.

- `cards_motion_test`: wait out the slow first frames before timing the
  intercept animation. A timer created during a long startup frame expired
  before the animation moved.
- `cards_scene_test`: check the card stand that replaced Challenge 3's orb
  marker, which the station hides on purpose.
- `cards_transition_test`: expect the table FOV refitted to the resized window
  rather than the pre-resize 44°.
- `sim_runner_test`: write fixtures to Godot's user data folder instead of the
  macOS-only `/private/tmp`. On Windows the error skipped nine checks while the
  suite still reported no failures (68 → 77 checks).

### `61fb59d` — UTF-8 file handling in the Python tools

Python defaults to the locale encoding (cp1252 on Windows), which failed to read
the card progression report template. All 22 `read_text`/`write_text` calls in
`tools/*.py` now pass `encoding="utf-8"`.

After both commits, all 23 headless Godot suites and 24 Python tests pass on
Windows. `cards_transition_render_test` needs a graphical renderer and was not
run headless.

### `a50ee6f` — Changes.md

This file, recording each contribution grouped by contributor and day.
