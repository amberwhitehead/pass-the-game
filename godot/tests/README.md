# Running every check

From the repository root (`py -3` instead of `python3` on Windows):

```sh
python3 tools/run_tests.py
```

This imports the project, then runs every Godot suite headless and muted **in one
Godot process** (about 25 seconds), then the Python tool tests, printing one
PASS/FAIL line per suite with a total. It exits nonzero if anything fails; full
logs are in `godot/build/test-logs/`.

- `--quick` runs only the logic suites that load no scenes, in about 2 seconds.
- Part of a name runs only matching suites: `python3 tools/run_tests.py optics save`.
- `--no-import` skips the import; `--godot PATH` names Godot 4.7.2 if it is not
  found (other versions are refused).
- `cards_transition_render_test` needs a real window, so it is skipped unless you
  pass `--graphical`, which opens one.
- `--shuffle SEED` runs suites in a random order, to check that none depends on
  another; `--isolated` gives each suite its own process (much slower).

Failures are quick and specific:

- **Compile errors.** Before any suite, every script in the project is compiled.
  A compile error anywhere stops the run in about 2 seconds, naming the file and
  line, instead of surfacing later as unrelated failures.
- **Script errors.** A `SCRIPT ERROR` fails its suite at once even if the suite
  reports no failures (Godot carries on after one, skipping the rest of the suite);
  the remaining suites continue in a fresh process.
- **Hangs.** A suite still running after 20 seconds (`--timeout`) is stopped, its
  Godot processes are killed, and the rest continue.

How it works: each suite extends `tests/test_suite.gd`, which supplies the few
`SceneTree` members suites use (`root`, `process_frame`, `quit()`...), so a suite
reads as if it were its own Godot program. `tests/run_suites.gd` runs the suites
named after `--` one after another, resetting the engine and autoloads between
them as a fresh process would. To add a suite, create `tests/<name>_test.gd`
extending `test_suite.gd` and end it with `quit(0)` or `quit(1)`; the runner finds
it by name. Any reset a new kind of state needs belongs in `run_suites.gd`.

The sections below describe what each suite covers. Each command runs one suite
directly with Godot, without the runner.

# Card rules checks

The balance lab uses the actual card rules with seeded, public-information bots:

```sh
python3 tools/card_sim.py --seeds 200
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- sim_config_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- sim_policies_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- sim_runner_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- sim_blindspots_test
python3 -m unittest discover -s tools -p 'test_card_sim*.py'
```

The simulator checks configuration isolation and validation, legal policies with no
access to hidden incoming cards, exact replay determinism, bounded timeouts,
telemetry reconciled against real combat, and statistically correct aggregation.
Adversarial fixtures document deployment cancellation, full-board interception,
first attack advantage, mirrored-board asymmetry, useful swaps, and defensive
fatigue locks. These fixtures establish behavior rather than imposing balance
targets. See `godot/simulation/cards/README.md` for experiments and report usage.

From the repository root, using Godot 4.7.2:

```sh
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_scene_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_table_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_transition_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- card_face_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- older_rules_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- older_scene_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_motion_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- card_progression_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- card_progression_scene_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- card_pickups_test
```

Each script exits nonzero if a check fails. The rules suite runs without loading
game scenes; the integration suite loads them headlessly. Neither renders or
controls a running playtest.

Coverage includes action legality and resource conservation, snapshot isolation,
unit and spell effects, attack order and blocking, telegraphed enemy deployment,
victory/loss, energy progression, deck exhaustion, and deterministic full matches.
Hand-limit checks cover normal boundary draws and discarding an overflow draw.
A simple starter-deck heuristic checks that winning is possible; its win count is
a diagnostic, not a balance target or a substitute for human playtesting.

Targeted fixtures use the rule engine's internal state to isolate a behavior.
Actual actions run through its public `play_card` and `end_turn` methods.

The scene smoke test loads the hub and launches the table through `MiniGames`.
It checks the entrance lock and tutorial timing, exercises actual button signals
through a full victory, checks the result and hub controls, then reopens the table
and exits during combat and entrance animations. Entrance cancellation uses a real
Escape action. It does not check rendered layout; use a graphical playtest for
visual verification.

The physical-table input suite launches through the actual hub/minigame overlay,
projects 3D actors through the perspective camera, and raycasts their colliders at
three window sizes. It checks empty/occupied lanes, all cards in a full raised hand,
the end-turn control, and modal/animation input locks. Mouse and touch events pass
through the full scene-tree input route (including emulation), reveal and tuck the
hand, then deploy directly from a selected hand card to a friendly lane while the
hand is retracting. Both mouse and touch finish this targeting flow, and the mouse
flow completes a turn. Anonymous incoming glows are
checked with single- and multiple-lane deployment plans. These checks do not
substitute for checking card readability and composition in the rendered game.

The card-face suite checks that starter titles and rules fit in full, future long
copy remains bounded, damaged health stays consistent between table and inspector,
artwork fallback is safe, and empty lanes retain their interaction targets.

The older rules suite exercises intercept priority/readiness, diagonal targets,
swap conservation, finite reserves/fatigue, and deterministic full-match pacing.
The older scene suite launches from the real hub, raycasts all four lanes at three
window sizes, uses the two-target swap flow including invalid/cancelled choices,
plays through the Sentinel/Forkshot bait interaction, and verifies separate victory
registration and return to the hall. The motion suite checks in-flight positions,
transform restoration, directional attacks, and exit cancellation.

The progression rules suite checks all 32 discovery subsets: a twelve-card base
retains every copy, discoveries are added once, and every opening has five cards
(three core creatures plus two random draws). It checks complete-deal conservation,
seed determinism, discoveries appearing either in the opening or later in the
deck, and the normal next-turn draw. Win rates are not correctness assertions.
The progression scene suite verifies that actual controller deals match the
simulator, rematches read new discoveries,
in-progress duels remain isolated, collection counts/rules are current, and the
tutorial is unchanged. It also checks positive healing feedback for the stronger
spell. The pickup suite verifies accessible hall placements, duplicate-safe
collection, room reconstruction, and independence from the carried puzzle item.

For statistical progression reports, run the same seeds against every subset
and inspect both the aggregate curve and individual single-card additions:

```sh
python3 tools/card_sim.py --config /path/to/progression-experiments.json --seeds 500 --output godot/build/web/progression
python3 tools/card_progression_report.py godot/build/web/progression/results.json
```

The generated `curve.html` complements the normal match report. See the simulation
guide for interpretation limits and validation using a separate seed range.

The transition suite starts from the real hub camera. It checks launch reservation,
the live destination viewport binding, multiple frames of source-camera movement,
independent aperture coverage at handoff, and input/tutorial timing. Escape is
exercised before opening, during the approach, and after crossing. Caller camera,
HUD and touch state must return exactly, including an initially hidden HUD and a
source camera with horizontal FOV, offsets and non-default clipping planes. The
window also changes aspect ratio during the approach; the settled destination
must regain its own original projection. These checks validate
the lifecycle and projection contracts; graphical frame capture remains necessary
to detect stale textures, color-conversion jumps or blank rendered frames.

The pixel regression must run with a graphical renderer (it opens and closes its
own game window):

```sh
godot --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- cards_transition_render_test
```

It freezes the real transition at its covered handoff and compares the source
portal with the full-screen destination at the same camera pose. Both paths must
keep rendering while hidden or shown. Gameplay pixels must agree within one
8-bit rounding level, with mean error at most 0.1; the top UI strip is excluded
because close-button focus can differ. A brightness check prevents two blank
buffers from passing. This catches both stale viewport textures and a second
color-conversion pass that crushes shadows at the handoff.

# Escape-room and carry checks

```sh
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- newton_skip_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- optics_model_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- optics_scene_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- optics_aiming_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- carry_inventory_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- escape_hub_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- save_game_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- pause_menu_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- minigame_resume_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- save_editor_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- player_movement_test
godot --headless --audio-driver Dummy --path godot --script res://tests/run_suites.gd -- controls_menu_test
```

The Controls suite clicks and types through the real pause menu: opening from the hall
and a minigame, arrow-key focus, Enter on Change without its release counting, key
repeat ignored, a conflict naming the other action, Escape cancelling, Use Escape,
discard and restore-defaults confirmations, Apply then resuming with the new keys held
(nothing moves until released), the replaced keys no longer acting, gamepad events and
deadzones kept, and saved files that are missing, corrupt, invalid or cannot be written.
It saves to `user://test_controls.cfg`; headless runs never load or save the player's
`user://controls.cfg`.

The movement suite drives the real Player scene on a small floor/wall/low-ceiling
fixture: W/S and A/D after a 90-degree turn, walking at both pitch limits, equal
straight and diagonal speed, moving while looking, standing and running jumps, no
air jumps or held-key bouncing, walls, falling, walking off a ledge, the ceiling, a lock taken mid-jump,
pause preserving a jump without replaying held keys, the remapped keys with
gamepad bindings intact, emulated touch not looking twice, the mouse-capture gate
and the wheel turning with A/D. In the real hall it also checks that Space beside an
NPC jumps without starting the conversation while E still starts it. Real pointer lock
needs a browser and a person.

The pure optical model enumerates 3,465 source/rotation/lens/socket configurations.
Only A/B with either L/M color order wins. Scene checks verify atomic exchanges,
invalid-placement conservation, rotation controls and source-head orientation.
The aiming suite checks capture/release hysteresis, wraparound, input ownership,
absolute head angles, exact right-angle turns, persistence and render-pool reuse.

The inventory/reward suite tests one-item ownership, hidden reward interaction,
reconstruction without duplication, and camera restoration on normal completion,
Escape and removal. The actual-hub suite checks all six chamber floors and
passageways, locked/open door collision and line of sight, real reward triggers
through `MiniGames.ended`, complete prism delivery, permanent unlock, and held and
mounted item conservation across room recreation. It synthesizes the minigame win
result; it does not solve Egypt Fractal's mathematical puzzle.

The Egypt skip suite sends the actual Shift+L keyboard shortcut through the scene
input path. It checks lit pyramids/crystals, a single celebration, normal trophy
and reward delivery, interruption guards, and replay without duplicated rewards.

The save suite round-trips nested flags, colors, vectors and routes through a
JSON save file exactly, checks that files stay readable JSON, that numbers compare
with `same_data`, and that no file can build objects or load resources. It rejects
other format versions and corrupt files, converts old `.cfg` saves (refusing ones
with object syntax), and checks that slots are found on disk with no limit, autosave gating and batching,
loading slots, and the title screen's Continue, New game (always a new slot),
newest-first Load game list and two-press Delete. It points `SaveGame.slot_prefix` at its own
`user://test_save_slot_*.json` files, never the player's saves.

The pause menu suite sends real Escape events in the hall and in Egypt Fractal and
Roman Flow. It checks that the menu pauses the hall or freezes the minigame, that
existing Escape jobs (releasing a prism wheel, the Sound panel) take priority, that
Resume and a second Escape restore play, that Leave exits unsolved, that a solved
puzzle still leaves directly, and that Quit to title saves first.

The minigame resume suite leaves Egypt Fractal, Roman Flow and an Older Brother
match partway through the real menu, reloads the save from disk, and checks that
each reopens where it was left; that a win clears saved progress; that Roman
Flow's GPU simulation stops while paused; that a resumed card match equals the
original exactly even after a new card is found; that a replay which no longer
matches deals a fresh match; and that Quit to title from a minigame saves it.

The save editor suite checks the edit rules (wins keep their details, cards keep
the game's order, hall items are counted across cradles, hand and optics mounts,
skipped progress is flagged), then drives the real screen: opening the latest
save, ticking boxes, item warnings appearing and clearing, invalid and valid raw
JSON, keeping flags it has no control for, clearing minigame progress, Save, Save
as new slot, the blank save, Play (unsaved) writing nothing, and the title
screen's developer-mode button. It uses its own `test_editor_slot_*` files.

Use `--audio-driver Dummy` for automated native tests and keep them headless.
Browser visual checks should run in a background tab at
`http://localhost:8060/?muted=1`; ordinary playtest links retain sound.

Graphical QA separately exercises the actual minigame launch/return path, reward
framing and camera pan, and browser navigation/interaction. The card scene, input
and transition suites remain regression checks for the relocated card room.
