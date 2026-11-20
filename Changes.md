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

### `4e7deea` — Unlimited save slots

Saves are no longer limited to three. **New game** always starts a new slot (the
next number, never reusing one), so it no longer asks which save to replace.
**Load game** lists every save newest first in a scrolling list, each with its
progress, when it was last played, and its own **Delete**, which takes a second
press. Slots are found by listing `user://save_slot_<n>.json` files.

### `01fe673` — Save editor

A developer tool for reaching any point in the game quickly and for inspecting
saves. In developer mode (running from the Godot editor, `?dev=1` on the Web
build, or a `--dev` launch option) the title screen shows **Save editor**; with
its scene open in the editor, F6 opens it directly. Normal players never see it.

- Open any save, or start from a blank one.
- Controls for wins, Egypt's revealed prisms, the reward cradles, the carried
  item, Door 2, found cards, and clearing a minigame's unfinished progress.
- The whole save as raw JSON, editable, for everything else (the optics layout,
  NPC flags, future contributors' flags). Values it has no control for are kept.
- Warnings when hall items no longer add up (2 prisms, 1 yellow lens, 1 blue lens
  across cradles, hand and optics mounts) or progress skips a step.
- **Save**, **Save as new slot**, and **Play (unsaved)**, which tries the state in
  the hall without writing any save.
- A win ticked here records only that it was won, so the Egypt and Roman Flow
  trophies, which are built from a real win's details, show nothing for it.

### `abd5163` — Save editor's Back button at the top

**‹ Back** now sits at the top left of the save editor rather than in the bottom
row of actions.

### `7cf1e9f` — Sound from the menus instead of a floating button

The floating **Sound** button, which sat over every screen, is gone. The mixer
opens from the title screen's new **Sound** item and from the pause menu, as
before; the mixer panel itself is unchanged.

### `7b65be3` — Handoff for this turn

`docs/HANDOFF.md` now describes the game at the end of this turn, including a
"What changed for you" section for each returning contributor. cee.wtf's handoff
is kept in `docs/handoffs/2026-11-16-cee.wtf.md`.

## Steve Likes Robots — November 18, 2026

Built using Codex (GPT 6.2 Sol Light) as orchestrator and Claude Opus 5.5 as builder,
on Windows with Godot 4.7.2.

### `2668650` — Keyboard and mouse movement inspired by Minecraft

- **Mouse look without holding a button.** In the hall the game captures the cursor
  (`scenes/room/mouse_capture.gd`); menus, Sound settings and minigames get it back.
  Browsers only lock the pointer after a real click or key press, and drop it on
  Escape or when the window loses focus, so while keyboard/mouse play is waiting for
  it a **Click to look around** card shows and the player doesn't move.
- **W/S walk, A/D strafe, Space jumps.** Walking follows the horizontal facing, so
  looking up or down never tilts or slows it, and diagonals are no faster. Jumping has
  gravity, collision and landing, and a press in the air does nothing. Space no
  longer interacts; E, Enter and F still do. The arrow keys still turn; gamepad and
  touch controls are unchanged.
- **Resuming is clean.** Keys held through a menu, dialogue or the click-to-look card
  do nothing until released, the view comes back exactly as it was, and pausing
  mid-jump continues the same jump.
- A/D still turn the prism wheel and steer in Egypt Fractal and Roman Flow. The wheel
  and the reward camera now stop only horizontal motion, so a player who grabs the
  wheel mid-jump still lands.
- `player_movement_test` covers facing, both pitch limits, speed, jumps, walls,
  falling, a low ceiling, pause, the key changes and the capture gate.

### `6fdd5dc` — Controls menu for changing keys

**Controls** in the pause menu (hall or minigame) lists every keyboard key, extra
keys included, each with a **Change** button.

- Change waits for one key. Escape cancels; the Back / pause row has **Use Escape** so
  Escape itself can still be chosen. A key another action uses is refused with a
  message naming that action. Nothing is swapped or unbound.
- Changes wait for **Apply**; **Back** asks before discarding them; **Restore
  defaults** asks first. The menu works with the mouse or the arrow keys, Enter and
  Escape, whatever the game keys are.
- `autoload/key_bindings.gd` holds the defaults, key names and saving. Choices are
  saved in `user://controls.cfg`, separate from saves and sound settings, and replace
  only keyboard events, so gamepad and touch stay as they were. A missing, damaged or
  invalid file falls back to the defaults and is left untouched; a failed save says
  so.
- `controls_menu_test` drives the real menu with real key and mouse events.

### `d5a4dd3` — Key prompts follow your keys

The interact prompt, dialogue, prism-wheel hint, click-to-look card, Egypt and Roman
Flow hints, card table rules and the puzzle close button all show the current keys,
named the way the player's keyboard layout prints them. Puzzle hints update when the
pause menu closes. On the Web, Godot cannot read the keyboard layout, so key names
fall back to the key's own name instead of logging an error on every refresh.

### `dae13d0` — More movement checks

The movement test also walks off a ledge (a real fall that keeps its momentum and
lands) and, in the real hall, checks that Space beside an NPC jumps without starting
the conversation while E still starts it.

### `ed029d5` — Credits screen

**Credits** on the title screen and in the pause menu: one scrolling page of who made
what, plus the Kenney sounds, both fonts and Godot. Back or Escape returns to the menu
that opened it, and the game stays paused. Entries live in `ui/credits.gd`, with a
note asking future contributors and AI agents to agree each entry with the person it
credits rather than guessing. `credits_test` covers both menus.

### `0c5364a` — Open credit questions

`ui/credits.gd` lists three attribution questions for the next contributor to
settle: who "the owner" was in cee.wtf's November 16 playtest, whether "tesseract" or
the fork account "tessprime" is the right name, and whether the other turns used AI
tools worth crediting.

### `8952b15`, `be0e801` and `28086b4` — An Easter egg

A small secret room is hidden in the hall for players to find; how to reach it is
described in the spoiler section of `godot/scenes/escape/README.md`. It holds two signs
and a decorative travellers' board whose pieces (one per stage, plus a phone for the
21st-century player) appear as stages are won. The room is left empty on purpose for
future developers to build on, and the board's Workshop, Calendar and Observatory
pieces wait for those stages: see `STAGES` in `godot/scenes/escape/egg_board.gd`.
Nothing about the room is saved and no progress depends on it. `secret_room_test` and
`egg_board_test` cover it.

## Patrick Doane — November 19, 2026

Built with Claude Opus 5.5 in Claude Code on macOS with Godot 4.7.2: Claude wrote the
code, drew the art in code and composed the music; Patrick designed with it, directed
and playtested. Subagents built CHRONO RAIDER, the music system and the radio's songs.

### `4563499`, `1db4f1f`, `514b724`, `8190cdc`, `ed2a0ea`, `8d75ed1`, `0f41f13`, `857acaf`, `541b233`, `3939fed` — 04 Workshop: the Engineer's time loop

Room 04 is now a hand-drawn 2D point-and-click story in the spirit of *Lost in Play*,
entered through a brass portal ring on the Workshop's wall: the Engineer's 1955 garage
lab, which "looks a bit hand-drawn from here. Nobody knows why." Everything is drawn
from code (`ink.gd`: wobbly boiling outlines, soft light and shade); there are no image
assets. The story (spoilers in `godot/minigames/workshop/README.md`):

- The Engineer walks in a moment after you, every visit, mourning his **Futurescope**,
  a TV that shows the future. The radio, opened up close (three stations, four screws
  on its back), gives up its tube.
- The Futurescope shows his cat Fuse, in red yarn with a sardine-tin lid on one ear,
  leaping on the Chrono-Oscillator's lever and vanishing into its portal. Then the
  portal opens by itself and that very cat walks out. Two cats; the clock stops; the
  Officer from the intro arrives to scoff and schedule the timeline for deletion.
- To close the loop, make the footage come true: sardines for the lid, the red yarn
  unwound from the cat from the future (nobody ever made it), the pegboard's copper
  wire for the blown fuse, the destination counter set to the footage's time, and a
  flashlight to make Fuse pounce on the lever. Anything different and the timeline is
  deleted, as the Officer promised: a glitch, a stamp and a harmless rewind to just
  before the lever, after which what differs flickers.
- To break it, lure the remaining cat away from the lever with a box in the sunbeam;
  the Engineer points out that the wire is all that keeps the portal open. Pull it.

The Engineer minds his things, gets put out as you rummage (his milk above all) and
only nudges when you're close. The flashlight makes Fuse pounce at almost anything.
Order is enforced: Fuse sleeps until the twin arrives. Playtest fixes along the way:
hover brightens instead of outlining, speech bubbles wrap their own lines, the footage
showed the wrong time (`8d75ed1`), shapes blinked when their wobbled outline folded
(`0f41f13`, `857acaf`). `workshop_story_test` plays it through (107 checks);
`tools/workshop_shot.tscn` renders scripted screenshots. A Workshop win places its
piece on the secret room's board.

### `14b289d`, `2ffecc8`, `c7c57f1` — Workshop odds and ends

Save slots list a Workshop win. The developer save editor gains Workshop jump points
(from the start, twin arrived, ready to send Fuse, loop closed) from
`godot/minigames/workshop/dev_stages.gd`. A trophy added in `14b289d` was removed after
playtesting.

### `fa3fea9`, `bb84be3` — CHRONO RAIDER, in the secret room

A 1985 arcade cabinet, contraband from across the 1963 line, stands in the secret room
running its attract mode. CHRONO RAIDER is the foundation of a horizontal shooter in
the spirit of ThunderForce and R-Type: three switchable weapons with levels, four speed
gears, cycling weapon capsules, a one-stage timeline and the CHRONARCH clock boss, title
and game-over screens and a local high score. It never reports a win, so saves and the
board are unaffected. `godot/minigames/arcade/README.md` lists what a design pass could
add. `arcade_test` covers it.

### `f1b7d8d`, `1b71add` — Procedural music

`godot/audio/music/` synthesizes chiptune music live from songs written in a small MML
dialect: pulse, triangle and noise voices, envelopes, vibrato, arpeggios, echo and
crossfades, on a new Music bus with its own Sound-panel slider. CHRONO RAIDER has a
title tune, a stage theme, a boss theme and jingles; the Workshop's radio has three
1950s stations (easy listening, a Bach-style minuet, a cha-cha-chá). `music_test` and
`radio_songs_test` check them by measurement; listen in the game.

### `aa6783d`, `ec77ed7`, `e2c9875` — Room revisits

A structure for rooms to affect each other, described in `docs/INTERCONNECTION.md` with
a recipe for adding more: `autoload/time_link.gd` (cross-room problems set off by wins,
and a tray where things sent from 1955 arrive in the hall), Futurescope channels that
show other rooms' futures, and bonus cards that join Older Brother's deck without
counting among the hall's five. After the Workshop is won:

- Fuse wanders into the hall and naps behind the optical relay cabinet; petting him
  finds the **Fuse** card.
- Egypt's room goes dark. The flashlight, sent through the Workshop's portal, fits a
  new lamp socket in the hall optics; through the yellow lens its beam goes through
  Egypt's doorway to a new sun disc and lights the room. The Egyptian's thanks is the
  **Sun Scarab** card. The lamp never opens Door 2.

Small changes to other areas: `room.gd` adds the revisits module, the optics gain the
second light, and the hub test's "optics stay east" rule exempts the lamp's two fittings.
`revisits_test` covers the chain, including reaching Fuse the way a player does.

### This entry and the credits

Patrick Doane asked that Claude take most of the credit; `ui/credits.gd` says so.
