# Setup and project guide

The game runs on **Godot 4.7.2**, GDScript, and the **GL Compatibility** renderer.
The handoff was built with `4.7.2.stable.official.ed1daf0bf`. Use matching export
templates; `project.godot` declares the 4.7 feature level. Web is the default
playtest target. All terminal commands below run from the **repository root**,
the directory containing this `godot/` folder.

For current scope, unfinished plans, and known limitations, start with the
[handoff notes](../docs/HANDOFF.md).

## Fresh checkout and editor

1. Install Godot 4.7.2. No .NET SDK is needed for this GDScript project.
2. Clone the repository and open `godot/project.godot` using Godot's Import
   Project action. Wait for the initial asset import to finish.
3. Press **F5** to run the whole game, or **F6** to run the selected scene.
   The CC0 audio and runtime models are included in the checkout and imported
   automatically. Blender and audio-processing packages are not needed for setup.
   See the [audio guide](audio/README.md) to audition or replace sound choices.

Generated `.godot/` data and `godot/build/` exports are ignored. The sound files
in `assets/audio/cc0/`, their source records, and CC0 notices are tracked with the
project. A clean checkout does not contain local exports or simulator reports.

## Local Web playtest — Windows, macOS or Linux

Install the **4.7.2 export templates** through **Editor → Manage Export
Templates**. Install Python 3 for the build script, audition page and local HTTP
server; no Node, npm or Python packages are needed. From the repository root:

```sh
python3 tools/build_web.py --serve
```

On Windows, use `py -3` in place of `python3`. The script finds Godot from
`--godot PATH`, then `GODOT`, then `godot` on PATH, then `/Applications/Godot.app`,
and stops if that executable is not 4.7.2 (an older Godot on PATH is a common
trap). On Windows it uses the `_console.exe` beside the windowed `.exe`, so build
output appears in the terminal. For example:

```powershell
py -3 tools/build_web.py --serve --godot "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
```

Open **[http://localhost:8060/](http://localhost:8060/)**. The script imports
assets, exports the named `Web` preset into `godot/build/web/`, builds the
[audition page](http://localhost:8060/audio/), and serves both on this computer.
Keep that terminal running; **Ctrl-C** stops the server. The Web
preset is single-threaded and needs no COOP/COEP headers. Serve the export over
HTTP rather than opening `index.html` as a `file://` URL.

After edits, leave the existing server running and rebuild in a second terminal:

```sh
python3 tools/build_web.py
```

Then refresh the browser. Saved progress survives rebuilds; choose **New game**
on the title screen to start fresh. The script imports and exports headlessly
with Dummy audio, so it does not open a game window. It also creates
`godot/build/.gdignore`; without it, Godot imports the exported files and the
audition page's sound copies as project assets and packs them into the next build.

Other options: `--output DIR` exports elsewhere, `--port 8061` serves on another
port, and `--serve-only` serves an existing build without rebuilding. The server
binds to `127.0.0.1`; these commands do not publish a hosted game. If port 8060 is
already in use by this project's healthy server, rebuild only. Otherwise stop the
old server or use another port.

On macOS or Linux the original Bash wrappers do the same and remain available:
`./godot/serve_web.sh [PORT] [OUTPUT]` and `GODOT=/path/to/Godot ./godot/build_web.sh [OUTPUT]`.
The handoff's visual QA was performed on macOS; the Python script was added and
verified on Windows.

## Audio and common setup issues

- **No sound:** check the Sound panel and remove `?muted=1` from the URL for
  listening. The sound files are included in Git; let Godot import them, restart
  the game, and rebuild/refresh Web after changes. See [audio checks](audio/README.md#verify).
- **Missing export template:** install templates matching the actual executable's
  `--version`, then retry. The editor and export templates are separate installs.
- **Stale browser build:** import/export again, then refresh. Editing source files
  alone does not update a previously exported Web build.
- **Fresh-clone script/type errors:** allow the initial editor import to complete,
  or run `godot --headless --audio-driver Dummy --path godot --import` before
  standalone test scripts. The first cache-free import can initially report a
  missing imported default font; the import generates that resource. If it is
  still missing on the next launch, investigate the import log.
- **Unexpected `.import` changes:** `.import` files are committed source (per-asset
  settings and stable `uid://` IDs); the generated cache is the ignored `.godot/`.
  Godot's "Detect 3D" option rewrites a texture's `.import` to GPU compression the
  first time the editor sees it in 3D, which is lossy for the character and prop
  palettes. It is off for every committed texture and, through `importer_defaults`
  in `project.godot`, for new ones. If an editor version still rewrites `.import`
  files, revert them rather than committing them.
- **Saved progress:** wins, puzzle state, the carried item and found cards save
  automatically to numbered slots, `user://save_slot_<n>.json`, with no limit
  (browser storage on the Web). Saves are readable JSON (format in
  `autoload/save_game.gd`); Godot types appear as `{"Vector2": [x, y]}` and
  nothing but plain data can be stored or loaded. The title screen's **Continue** resumes the most
  recent slot, **New game** always starts a new slot, and **Load game** lists every save newest
  first with its progress and a **Delete** button (a second press confirms).
  In developer mode the title screen also offers a **Save editor**; see
  [Getting started](../docs/GETTING_STARTED.md#2-see-the-game).
  Unfinished minigames save too: leaving one, quitting to title or closing the
  game keeps its progress for the next visit until it is won.
  Older `.cfg` saves (the first save format) convert to JSON the first time the
  title screen opens; one containing object syntax is refused and left alone.
  Sound preferences
  are saved separately in `user://sound.cfg`. Tests and scenes run directly with
  F6 never read or write the saves.

## Controls and a first playthrough

| Device | Controls |
| --- | --- |
| Keyboard | W/S or up/down to walk; A/D to strafe; left/right to turn; Space to jump; E, Enter, or F to interact; Escape or Backspace to go back, or open the pause menu when there is nothing to go back from. All of these can be changed in Pause → Controls |
| Mouse | In the hall the game captures the cursor and the mouse looks directly, no button needed; menus, settings and minigames get the cursor back. Click cards and their targets at the table |
| Touch | On-screen movement/turn pad, A to interact, B to go back; drag elsewhere to look |
| Gamepad (any slot) | Left stick to walk/strafe; right stick to look; D-pad to walk/turn; A (or R1/R2) to interact or confirm in menus; B to go back, and in a minigame to leave it (like its × button) once nothing is left to cancel; Y opens the pause menu; L1 or L2 jumps. In the Workshop the left stick moves the cursor and A clicks. At the card tables the D-pad or stick moves between hand, lanes and bell; A chooses, X rings the bell, L1 shows the rules |

The touch pad fades after keyboard/gamepad input and returns on touch. Input
actions are registered in `autoload/game.gd`.

Mouse capture lives in `scenes/room/mouse_capture.gd`. Browsers only lock the pointer
from a real click or key press and release it on Escape or when the window loses
focus, so whenever keyboard/mouse play is waiting for the cursor the hall shows
**Click to look around** and ignores player input until the click. Keys still held
from a menu do nothing until released. Touch and gamepad play never need capture.
Tuning (`scenes/room/player.gd`): walk 3.5 m/s in any direction, mouse 0.005 rad per
pixel, jump 0.55 m with 20 m/s² gravity, 8 m/s² air steering.

**Credits** (title screen and pause menu) lists who made what and the third-party
assets. Entries live in `ui/credits.gd`; read the note there before adding one: ask
the contributor how they want to be credited rather than guessing.

**Controls** (pause menu, hall or minigame) lists every keyboard key, alternates
included, with a Change button each. Change waits for one key; Escape cancels, and the
Back / pause row has **Use Escape** to choose Escape itself. A key another action uses is
refused with a message naming that action; nothing is swapped or unbound. Edits wait
for **Apply**; **Back** discards them after asking; **Restore defaults** asks first.
The menu navigates with the built-in `ui_*` keys (arrows, Enter, Escape), so it works
whatever the game keys are. `autoload/key_bindings.gd` holds the defaults, labels and
saving; choices go to `user://controls.cfg` (separate from saves and `sound.cfg`) and
replace only keyboard events, so gamepad and touch stay as they are. A missing,
corrupt or invalid file falls back to the defaults and is left untouched. Hints (the
interaction plaque, dialogue, wheel and click-to-look card) read the current keys,
labelled for the player's keyboard layout.

Skip the intro if desired. Room **01 / Egypt Fractal** is open from the start.
Its first win reveals two prisms; use them with the movable lenses in the main
hall to open **02 / Roman Flow**. **03 / The Brothers** is also accessible:
the small card stand or Little Brother starts the three-lane tutorial, and
Older Brother offers the four-lane match. Five cards can be found around the hall
to improve the Older Brother deck. The three other chambers are placeholders;
there is no final escape sequence yet.

For a quick handoff playtest, **Shift+L inside Egypt Fractal** lights all three
crystals and plays the normal victory animation. Press **E** or **Escape** to
return to the hall; the normal two-prism reward reveal follows. This shortcut
only works inside Egypt and does not solve the hall's optical puzzle.

## Project map

Flow: `scenes/title/title.tscn` → `scenes/intro/intro.tscn` (new games) →
`scenes/room/room.tscn` → minigame overlays. Continue and Load game go straight
to the room.

| Area | Responsibility |
| --- | --- |
| `autoload/` | `Game` progress/autosave/input (file format in `save_game.gd`), `Sound` playback/settings, `SceneManager` scene fades, `TouchControls`, `Dialogue`, the `MiniGames` registry/launcher, and the Escape `PauseMenu` |
| `scenes/room/` | Player, NPCs, interactable props, and hub composition. `room.tscn` retains station nodes; the architecture relocates them at runtime. |
| `scenes/escape/` | Six side chambers, main-hall geometry/server details, prism optics, one-item carry system, reward reveal, and the Brothers' walnut/felt parlor. See the [module guide](scenes/escape/README.md). |
| `minigames/newton/` | Egypt Fractal: park three pyramids on different fractal colors. `newton_math.gd` is the shader's CPU twin; keep them in sync. |
| `minigames/turing/` | Roman Flow: Gray–Scott reaction-diffusion, adjustable rollers, and glass pins. A flood-fill worker evaluates paths from simulation snapshots. |
| `minigames/cards/` | Both card encounters, shared rules/combat/AI, 3D cards/table, camera transition, and collection progression. See [rules and modules](minigames/cards/README.md). |
| `scenes/dev/` | Developer tools, shown only in developer mode (`autoload/dev_mode.gd`: editor runs, `--dev`, or `?dev=1` on the Web). The save editor (`save_editor.tscn`) opens, edits, saves and plays saves; its edit rules and hall item checks are in `save_edits.gd`. |
| `ui/` | Shared enamel panels, ivory typography, interaction prompts and physical signs; see the [UI guide](ui/README.md). |
| `audio/` | Semantic cue mapping, scene-owned playback, mixer, ambience and settings; see the [audio guide](audio/README.md). |
| `simulation/cards/` | Seeded matches using production rules and public-information policies; see the [simulator guide](simulation/cards/README.md). |
| `tests/` | Headless rule/integration suites and targeted render checks; see [verification](tests/README.md). |
| `tools/` | In-engine benchmarks, minigame screenshot helpers, and fake results. The repository-root `tools/` contains the audio audition builder and Python report runners. |

Door numbers and scene node names are different: `Challenge4` is Egypt (door 01),
`Challenge5` is Roman Flow (door 02), `Challenge3` is The Brothers (door 03), and
`Challenge1`, `Challenge2`, `Challenge6` are Workshop, Calendar, Observatory
(doors 04, 05, 06). Edit `scenes/escape/hub_architecture.gd` for room placement.
The original 3×2 station-grid description no longer describes the live hall.

Character `.glb` files are in `assets/characters/`, with Blender sources under
[`../blends/`](../blends/README.md). Keep `post_import.gd` as each rigged model's
import script. NPC body idle and face blink/talk animations use separate players.
The brothers retain the existing character art. Platform models live in
`assets/props/`; `newton_platform` and `turing_platform` are also the playable
minigame tables. The mainframe platform is still a placeholder.

Fonts are bundled: DejaVu Sans for small text/fallback glyphs and Libre
Baskerville for headings. Keep their license files with the assets. Web builds
cannot depend on the player's system fonts.

## Adding a minigame

1. Create `godot/minigames/foo/foo.tscn` and a root script extending `MiniGame`.
   Complete it with `finish({"won": true})` or an appropriate non-win result.
2. Add its ID, title and scene path to `REGISTRY` in `autoload/minigames.gd`.
3. Set a placeholder Prop's `minigame_id` in `scenes/room/room.tscn` to that ID.
   Use `hub_architecture.gd` if its room/station needs a new position or label.
4. If it rewards an overworld item or unlock, connect that explicitly in the hub;
   registering a minigame alone does not create the next escape-room step.
5. If it is the Workshop, Calendar or Observatory stage, connect its ID in the `STAGES`
   mapping of `scenes/escape/egg_board.gd`; that stage's board piece already exists.

Escape opens the pause menu (Resume, Leave, Sound, Quit to title) unless your
game handles `back` first. Override `_back_leaves()` to leave directly instead,
for example once solved. To let players resume where they left off, return plain
data from `save_state()` and apply `resume_state` in `_ready()`; it is saved with
the game and cleared after a win. Games without it simply start fresh. Saved
values come back as plain data: numbers may return as decimals (`2` as `2.0`), so
convert what you read with `int()` / `float()`, and compare whole saved structures
with `SaveGame.same_data()` rather than `==`. If your
game renders with GPU viewports that update on their own, stop them on
`NOTIFICATION_DISABLED` so the pause menu really pauses it (see `turing.gd`).

An optional registry `trophy` script can return a Node3D from
`static func build(result: Dictionary) -> Node3D`. Generic Props show that trophy
after a win; see `newton_trophy.gd` and `turing/aqueduct.gd`. The card stand keeps
its own presentation and remains playable for rematches.

The Newton shader's optional continuous root colors (`DISCRETE_COLORS = false`)
are useful for experimentation; its puzzle uses the discrete three-color mode.
Roman Flow's simulation is independent of Newton's code.

## Verification and native macOS export

Import first, then run checks relevant to the changed system from the
[test guide](tests/README.md). A small rules smoke test is:

```sh
godot --headless --audio-driver Dummy --path godot --import
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_test
```

Use the executable path in place of `godot` when it is not on PATH. Automated
checks should be headless and muted. Browser visual checks use a background tab
at [http://localhost:8060/?muted=1](http://localhost:8060/?muted=1).
Simulation results supplement human playtesting; historical win rates do not
describe the current 12-card Older Brother base deck.

For a requested native macOS build, install the matching macOS template and run:

```sh
GODOT="/path/to/Godot.app/Contents/MacOS/Godot" ./godot/build_macos.sh
```

The output is `godot/build/macos/Pass The Game.app`, universal for Apple Silicon
and Intel, ad-hoc signed for local testing, and not notarized for distribution.
An optional argument selects another output path. Web remains the ordinary
handoff/playtest target.
