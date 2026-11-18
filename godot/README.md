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

## Local Web playtest — macOS/Linux

Install the **4.7.2 export templates** through **Editor → Manage Export
Templates**. Install Python 3 for the audition-page build and local HTTP server.
The build/server scripts use Bash; they do not require Node, npm, or Python packages.

If `godot` is on PATH, or Godot is installed in `/Applications/Godot.app`:

```sh
./godot/serve_web.sh
```

Otherwise set `GODOT` to the executable, for example on macOS:

```sh
export GODOT="/path/to/Godot.app/Contents/MacOS/Godot"
./godot/serve_web.sh
```

Open **[http://localhost:8060/](http://localhost:8060/)**. The script imports
assets, exports the named `Web` preset into `godot/build/web/`, builds the
[audition page](http://localhost:8060/audio/), and serves both on this computer.
Keep that terminal running; **Ctrl-C** stops the server. The Web
preset is single-threaded and needs no COOP/COEP headers. Serve the export over
HTTP rather than opening `index.html` as a `file://` URL.

After edits, leave the existing server running and rebuild in a second terminal:

```sh
GODOT="/path/to/Godot" ./godot/build_web.sh
```

Then refresh the browser. Saved progress survives rebuilds; choose **New game**
on the title screen to start fresh.
Both scripts honor `GODOT`; omit it when the default executable discovery works.
They import/export headlessly with Dummy audio, so they do not open a game window.

Optional arguments:

```sh
./godot/build_web.sh /absolute/path/to/web-output
./godot/serve_web.sh 8061 /absolute/path/to/web-output
```

The server binds to `127.0.0.1`; these commands do not publish a hosted game.
If port 8060 is already in use by this project's healthy server, rebuild only.
Otherwise stop the old server or use another port.

## Local Web playtest — Windows PowerShell

Use the same editor and matching templates. The Bash wrappers are optional;
these direct commands provide the equivalent import, export, and local server.
Replace the Godot executable path with your installation:

```powershell
$GodotExe = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
New-Item -ItemType Directory -Force "godot/build/web" | Out-Null
$WebOutput = Join-Path (Get-Location) "godot/build/web/index.html"
& $GodotExe --headless --audio-driver Dummy --path godot --import
& $GodotExe --headless --audio-driver Dummy --path godot --export-release Web $WebOutput
py -3 tools/build_audio_audition.py
py -3 -m http.server 8060 --bind 127.0.0.1 --directory godot/build/web
```

Stop if a build command fails; the server should serve a successful export.
If your Python installation uses `python` rather than `py`, substitute `python`
for `py -3`. For later builds, rerun the import, export and audition-page commands
in another terminal and refresh the browser. The Windows steps
use the shared export preset; this handoff's visual QA was performed on macOS.

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
- **Saved progress:** wins, puzzle state, the carried item and found cards save
  automatically to one of three slots, `user://save_slot_1.cfg` to `_3.cfg`
  (browser storage on the Web). The title screen's **Continue** resumes the most
  recent slot, **New game** uses the first empty slot (or asks which to replace,
  with a second press to confirm), and **Load game** lists every slot's progress.
  A pre-slot `user://savegame.cfg` moves into an empty slot 1. Sound preferences
  are saved separately in `user://sound.cfg`. Tests and scenes run directly with
  F6 never read or write the saves.

## Controls and a first playthrough

| Device | Controls |
| --- | --- |
| Keyboard | W/S or up/down to walk; A/D or left/right to turn; E, Space, Enter, or F to interact; Escape or Backspace to go back |
| Mouse | Click-drag to look; click cards and their targets at the table |
| Touch | On-screen movement/turn pad, A to interact, B to go back; drag elsewhere to look |
| Gamepad | Left stick to walk/strafe; right stick to look; D-pad to walk/turn; A to interact; B to go back |

The touch pad fades after keyboard/gamepad input and returns on touch. Input
actions are registered in `autoload/game.gd`.

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
| `autoload/` | `Game` progress/autosave/input (file format in `save_game.gd`), `Sound` playback/settings, `SceneManager` scene fades, `TouchControls`, `Dialogue`, and the `MiniGames` registry/launcher |
| `scenes/room/` | Player, NPCs, interactable props, and hub composition. `room.tscn` retains station nodes; the architecture relocates them at runtime. |
| `scenes/escape/` | Six side chambers, main-hall geometry/server details, prism optics, one-item carry system, reward reveal, and the Brothers' walnut/felt parlor. See the [module guide](scenes/escape/README.md). |
| `minigames/newton/` | Egypt Fractal: park three pyramids on different fractal colors. `newton_math.gd` is the shader's CPU twin; keep them in sync. |
| `minigames/turing/` | Roman Flow: Gray–Scott reaction-diffusion, adjustable rollers, and glass pins. A flood-fill worker evaluates paths from simulation snapshots. |
| `minigames/cards/` | Both card encounters, shared rules/combat/AI, 3D cards/table, camera transition, and collection progression. See [rules and modules](minigames/cards/README.md). |
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
godot --headless --audio-driver Dummy --path godot --script res://tests/cards_test.gd
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
