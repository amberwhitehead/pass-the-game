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

### `31b544d` — UTF-8 file handling in the Python tools

Python defaults to the locale encoding (cp1252 on Windows), which failed to read
the card progression report template. All 22 `read_text`/`write_text` calls in
`tools/*.py` now pass `encoding="utf-8"`.

After both commits, all 23 headless Godot suites and 24 Python tests pass on
Windows. `cards_transition_render_test` needs a graphical renderer and was not
run headless.

### `f655096` — Changes.md

This file, recording each contribution grouped by contributor and day.

### `90d2771` — Optics handles no longer raise a script error

Pressing a prism's TURN or LIFT / PLACE control in the hall raised "Trying to get
a return value of a method that returns void" from `optics_device.gd`. The
handle chose between two signal emits with a one-line `if`/`else` expression,
which uses `emit()`'s missing return value. The signal still fired, so exported
builds kept working, but the editor's debugger stopped the game there and it
looked like a crash. The callback now uses an ordinary `if`/`else` statement.
The hall tests drive the optics controller directly, which is why they never
pressed a real handle and missed it.

### `70c3680` — Saved games

Progress now survives quitting and reloading, the handoff's planned "persistent
saves".

- **What is saved.** Everything in `Game`'s flags, completed minigames and found
  cards: wins and trophies, the prism rewards, the optics layout, the carried
  item, Door 2, found cards and which NPCs you've talked to. The player starts
  at the hall entrance as before.
- **When.** Autosave half a second after changes settle (so turning a prism
  wheel is one write), and when the window closes or loses focus. The file is
  `user://savegame.cfg`, stored in the browser on the Web. A new
  `autoload/save_game.gd` owns the versioned file format.
- **Intro.** With a save, "Skip intro" becomes **Continue** and a **New game**
  button appears; it asks for a second press before erasing progress. Skipping
  or finishing the story continues the save.
- **Tests stay isolated.** Autosave turns on only when the intro starts or
  continues a game, so tests and F6 scene runs never touch the real save. The
  new `save_game_test` (15 checks) covers the file format, version mismatch,
  autosave gating and batching, and Continue / New game.

### `415fb4d` — Title screen with three save slots

The game now opens on a title screen instead of the intro story.

- **Continue** resumes the most recently saved slot and goes straight to the
  hall. It appears only when a save exists.
- **New game** takes the first empty slot and plays the intro. If all three
  slots are full, it lists them so you can choose one to replace; replacing a
  slot takes a second press.
- **Load game** lists every slot with its progress (for example "Egypt ✓ · Door
  2 open · 3/5 cards") and when it was last played. Empty slots can't be loaded.
  Escape or gamepad B returns to the menu.
- Saves are now `user://save_slot_1.cfg` to `_3.cfg`. A save from the previous
  commit's single file moves into an empty slot 1 the first time the title
  screen opens.
- The intro returns to its original version with only "Skip intro"; the
  Continue / New game buttons from the previous commit moved to the title
  screen.
- `save_game_test` now has 32 checks, covering slots and the title screen with
  its own test slot files.

### `1d2455b` — Escape pause menu

Escape (or gamepad/touch B) opens a pause menu whenever it has nothing else to
do. Before this, Escape did nothing in the hall and left minigames immediately.

- **In the hall** the menu pauses the game and offers Resume, Sound and Quit to
  title. Quitting saves first.
- **In a minigame** it freezes the game and offers Resume, Leave *(minigame)*
  and Sound.
- Escape again resumes. The touch pad hides while the menu is open.
- **Existing Escape actions come first:** releasing a prism wheel, skipping the
  reward reveal, closing card dialogs, cancelling a swap and closing the Sound
  panel. Escape still leaves directly where the game already says it does: a
  solved Egypt or Roman puzzle, a decided card match, and the card table's
  entrance. The card rules text now mentions the menu.
- A new `PauseMenu` autoload holds the menu; minigames can override
  `_back_leaves()` to keep leaving directly. `pause_menu_test` (21 checks) drives
  real Escape presses through the hall, Egypt Fractal and Roman Flow.

### `357935e` — Resume minigames, Quit to title from them, and a real Roman Flow pause

Leaving a minigame unsolved now keeps your progress for the next visit, including
across quitting and reloading. Winning clears it, so a solved puzzle starts fresh.

- **Egypt Fractal** keeps its roller values and your angle around the table.
- **Roman Flow** keeps its rollers, placed pins, view mode and position. The
  pattern regrows from them; a pin you were carrying goes back to its tray.
- **Card duels** keep the match's seed, starting deck and every action, and
  replay them through the rules on return, so the match comes back exactly. Cards
  found in the meantime join the next match, not the saved one. If the replay no
  longer reproduces the saved state (say, after card stats change), a fresh match
  is dealt rather than a wrong one. A resumed match skips the rules introduction.
- **Quit to title** is now in the minigame menu too. It leaves the minigame
  (keeping its progress), saves, and opens the title screen. Closing the game
  mid-minigame also keeps its progress.
- **Roman Flow really pauses.** Its simulation runs on the GPU independently of
  scripts, so the pattern kept changing behind the menu; it now stops and
  restarts with the menu.
- Minigames opt in with `save_state()` and `resume_state`; the guide for adding a
  minigame explains how. `minigame_resume_test` (27 checks) covers all three
  games through the real menu and a reload from disk.

### `a0c4c25` — Texture imports no longer change when the editor opens

Opening the project in the Godot editor rewrote texture `.import` files, so every
contributor would see unexplained diffs. Godot's "Detect 3D" option switches a
lossless texture to lossy GPU compression the first time the editor sees it on a
3D model. For the characters' and props' flat-colored palette images that risks
shifted or bleeding colors, and it made committed settings depend on which scenes
someone happened to open.

- "Detect 3D" is now off in all 37 committed texture imports (27 character
  palettes, 9 prop palettes, the icon). They stay lossless, exactly as committed.
- `project.godot` sets the same default for textures added later.
- The setup guide explains that `.import` files are committed source (settings and
  stable asset IDs) while `.godot/` is the cache, and to revert any further
  editor rewrites rather than commit them.

### `4f54893` — Ignore Python bytecode

A root `.gitignore` keeps `tools/__pycache__/` and `*.pyc` out of the repository.
Compiled caches from running the tool tests had been committed by accident in
`31b544d`; they were removed from every commit of this turn before the pull request.

### `0c4ce0f` — Cross-platform Web build script

`python3 tools/build_web.py --serve` (`py -3` on Windows) builds and serves the
browser playtest on Windows, macOS or Linux, doing what `build_web.sh` and
`serve_web.sh` do on macOS/Linux. Those Bash scripts remain.

- It finds Godot from `--godot`, `GODOT`, PATH or `/Applications`, and stops
  with a clear message unless that Godot is 4.7.2, since an older Godot on PATH
  is easy to pick up by accident. On Windows it uses the `_console.exe` beside
  the windowed one so build output shows in the terminal.
- It creates `godot/build/.gdignore`, which the README's old PowerShell steps
  left out. Without it, Godot imported 95 exported and sound-audition files as
  project assets and packed them into the game: the Web build grew from 5.7 MB
  to 7.8 MB. Builds are back to 5.7 MB.
- Options: `--output`, `--port`, `--serve-only`. `tools/test_build_web.py` covers
  version matching, the Windows console executable and the search order.
- The READMEs and `AGENTS.md` now use the script; the PowerShell steps are gone.

### `245b2af` — One command for every check

`python3 tools/run_tests.py` (`py -3` on Windows) imports the project, runs every
Godot suite headless and muted, then the Python tool tests, and prints one
PASS/FAIL line per suite, the error lines of any failure, and a total. Before,
each of the 27 suites was a separate command spread through the test guide.
Logs go to `godot/build/test-logs/`. It accepts part of a suite name to run only
some, `--no-import`, `--godot`, and `--graphical` for the one window-only suite,
which is otherwise skipped with the reason shown.

### `7ce84bf` — Getting-started guide

`docs/GETTING_STARTED.md` is for someone new or a previous contributor coming
back: setup, checking everything works, the traps hit on a new machine, a quick
route through the game, what is open to work on (gathered from the handoff and
design notebook), and how earlier turns reached the repository, described as
history rather than rules. The README's "Start here" now leads with it and with
this file.

### `933ade5` — A script error fails a test suite

Godot exits normally after a GDScript error, quietly skipping the rest of that
suite while still reporting no failures (the same way `sim_runner_test` had hidden
nine checks). `tools/run_tests.py` now marks such a suite failed and shows the
error.

### `12b41f1` — Saves are readable JSON

Saves were Godot `ConfigFile` text, which can build objects and load resources
while a file is read; that matters once save files are committed as test data or
sent to someone. They are now ordinary JSON (save format version 2), e.g.
`user://save_slot_1.json`:

- Plain objects, arrays, strings, numbers and booleans. Godot value types are
  one-key tags such as `{"Vector2": [0.72, 1.44]}` and come back exactly; vector
  and color components are written as their shortest exact decimal. Nothing else
  can be saved or loaded.
- Code that restores state already reads plain dictionaries and converts numbers
  with `int()`/`float()`. Numbers can come back as decimals (`2` as `2.0`), so the
  card replay check now compares with `SaveGame.same_data()` instead of `==`. The
  guide for adding a minigame says the same.
- Old `.cfg` saves convert once when the title screen opens, keeping their save
  time. A file containing object or resource syntax is refused before it is read.

### `6fc70da` — Damaged save tags load as plain data

A hand-edited or damaged tag such as `{"Vector2": ["a", 1]}` stopped the save
loader with a script error. Now a tag only becomes its Godot type when every value
is a number of the right count; anything else loads as a plain dictionary.

### `d33b722` — All test suites in one Godot process

A full run started Godot 26 times, and a hang or compile error could stall it for
many minutes. Now:

- Every suite runs in **one Godot process**. Each suite extends
  `tests/test_suite.gd`, which supplies the few `SceneTree` members suites use,
  so only each suite's first line changed. `tests/run_suites.gd` runs them in
  turn, resetting the engine and autoloads between them.
- **A full run takes about 30 s with import; `--quick` (logic suites only) about
  2.5 s.** Before: about 45 s, and no quick option.
- **Failures are fast and specific.** A compile error anywhere stops the run in
  about 2 s, naming the file and line. A script error fails its suite at once
  and the rest continue in a fresh process. A suite running past 20 s is killed
  along with its whole Godot process tree (on Windows, killing only Godot's
  console wrapper had left the real process running).
- `--shuffle` and `--isolated` check that suites don't depend on each other. The
  docs now run single suites through the host.
