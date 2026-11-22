# Pass The Game handoff

Handoff snapshot: **November 22, 2026**, at the end of eternaldensity's turn.
Earlier handoffs are kept in [`docs/handoffs/`](handoffs/). The
[November 16 handoff](handoffs/2026-11-16-cee.wtf.md) still describes the hall,
prism connector and card game in depth; the
[November 17 handoff](handoffs/2026-11-17-tesseract.md) covers saves and
tooling. This file records the state after three more turns (Workshop, UI, and
the Observatory).

New here? Start with [Getting started](GETTING_STARTED.md), then
[`Changes.md`](../Changes.md) for every commit by contributor.

## What changed since the previous handoff

**Patrick Doane — November 19.** Room 04 Workshop became a hand-drawn
point-and-click story (the Engineer, Fuse the cat, a time loop, a Futurescope TV,
a three-station radio), drawn entirely in code. CHRONO RAIDER, a 1985 arcade
shooter, sits in the secret room. A procedural chiptune music system (MML songs,
a Music bus) was added. `docs/INTERCONNECTION.md` introduced room revisits:
after the Workshop is won, Fuse naps in the hall and Egypt's sun disc can be relit
for two bonus cards.

**Daniel Pennypacker — November 20.** Full controller support from any pad slot
with drawn PlayStation/Xbox glyphs; a small prompt under the crosshair naming the
target; a white silhouette outline on what you aim at; first-person hands that
reach, wave and shrug; an objective console with a laser pointer; a How-to-play
placard. Continue and Pause → Relaunch return you to where you were.
[`docs/UI_PATTERNS.md`](UI_PATTERNS.md) records the rules every screen follows.

**eternaldensity — November 22.** Room 06 Observatory became a playable
minigame: **The Observatory's Aetheric Foundry**. See below.

## What this turn added

**For players**

- **06 Observatory** is open. A brass-and-stone engine with a telescope, aether
  valves, sight glasses, a press and a two-hand guarded reset. Five named sigils
  (The Lantern, The Coil, The Weave, The Bell, The Hollow) are tuned, forged and
  inscribed; each grants a bonus card that joins Older Brother's deck. Collecting
  all five wins, leaves a sigil-plate trophy on the platform, and places the
  Observatory's piece on the travellers' board.
- **Ghost alignment**: a faint gold ghost shows the target sigil; the blue live
  cloud is tuned (azimuth, elevation, focus) until it matches. The crank has a
  physical lock bar that lifts only when the sigil is matched and flow is clean.
- **The Observatory chamber's blackboard** in the hall fills with chalk sketches
  of each sigil you forge (blank until you have some).
- **Title easter egg**: a warm gold star low on the right opens a dancing-cat
  screen when clicked while at least half bright.
- **Controls**: A/D orbits the view at all times; while a control is grabbed,
  W/S turns it (the crank only advances on S). Drawn pad glyphs in the prompts.

**For contributors**

- New minigame module: `godot/minigames/observatory/` (main scene, pure
  `observatory_math.gd`, trophy), Blender generator
  `blends/props/observatory_platform.py`, and the shaders
  `observatory_plate.gdshader` (layer solidification), `trail_field.gdshader`
  and `lcd_display.gdshader` (dot/screen display).
- New hall module `godot/scenes/escape/observatory_board.gd`.
- New title module `godot/ui/easter_egg_cat.gd`; the secret star is in
  `story_bg.gdshader` (cell 79,36) and `scenes/title/title.gd`.
- New test suites: `observatory_test`, `observatory_explore_test` (real input
  events), `observatory_board_test`, `easter_egg_title_test`.
- New native screenshot tools (non-Web visual checks):
  `tools/observatory_shot`, `tools/hall_board_shot`, `tools/easter_egg_shot`,
  `tools/star_click_check`. Run with
  `xvfb-run -a godot --rendering-driver opengl3 --path godot res://tools/<tool>.tscn`.
- **Web build fix**: threaded Web export enabled (`variant/thread_support=true`)
  and the local server sends COOP/COEP, so loading is non-blocking. The title
  and scene transitions show cycling loading messages via a CSS overlay injected
  by `tools/build_web.py`.

## What changed for you

**Amber** — this turn, like the previous three, arrived as a pull request from a
fork rather than a commit on `main`. How turns reach the repository is your call.

**rmurrish** (foundation, Egypt, Roman Flow) — unchanged. The Web build is now
threaded; the serve script sends COOP/COEP headers, so run the playtest through
`tools/build_web.py --serve` (or the Bash wrapper) rather than a plain static
server if you want the threaded build to load assets off the main thread.

**cee.wtf** (hall, optics, cards, sound, tests) — the hall gained the
Observatory board; `Challenge6` now launches the Observatory minigame. The hall's
shader warm-up and prompt caching are unchanged. The special gold star in
`story_bg.gdshader` only shows when `show_secret` is set (the title screen sets
it), so the intro is unchanged.

**tesseract** (saves, pause menu, tooling) — `SceneManager.change_scene` now
loads threaded, shows cycling loading text, and warms the incoming scene's
shaders for a few frames before revealing it. The title screen shows the secret
star.

**Patrick Doane** (Workshop, arcade, music, revisits) — the Workshop's Cat is
reused, scaled, as the title easter egg's dancing cat. Nothing in the Workshop
changed.

**Daniel Pennypacker** (controller, prompts, hands) — the Observatory follows the
UI patterns: drawn pad glyphs, prompt under the crosshair naming the control, a
shrug on no-op, and a white outline on the focused control (gold glow when
grabbed). A/D still orbits while a control is grabbed; W/S turns it.

**Anyone adding a minigame** — the Observatory is a worked example of
`save_state()` / `resume_state`, a trophy, a board piece, a bonus card, and a
real-input test suite. Escape opens the pause menu; override `_back_leaves()` to
leave directly. The minigame's save values are plain data.

## What a player can do now

| Place | Current behavior |
| --- | --- |
| Title screen | Continue, New game, Load game, Sound, Credits; a secret star opens the dancing cat. |
| 01 — Egypt Fractal | Open from the start; its first win reveals the two prisms. |
| Main hall optics | Route green light to Door 2; a second lamp (flashlight) relights Egypt after the Workshop. |
| 02 — Roman Flow | Open after the optics puzzle; resumes where left. |
| 03 — The Brothers | Little Brother's tutorial and Older Brother's match; five hall cards and revisit bonus cards join the deck. |
| 04 Workshop | The Engineer's time loop; after a win, Fuse and the sun-disc revisit in the hall. |
| 05 Calendar | Furnished, no game yet. |
| 06 Observatory | **Playable**: forge five sigil plates; win places the board piece and a trophy. |
| Secret room | CHRONO RAIDER arcade and the travellers' board. |
| Final exit | Still sealed. |

Card balance is unchanged from cee.wtf's handoff (Older Brother's 12-card base
deck plus discoveries and bonus cards; "very hard with none, very easy with all").
It still needs human playtesting.

## Where to make changes

cee.wtf's [table](handoffs/2026-11-16-cee.wtf.md#where-to-make-changes) still
applies for the hall, optics, cards and audio. Newer areas:

| Area | Main entry points |
| --- | --- |
| Observatory minigame | `godot/minigames/observatory/observatory.gd`; logic in `observatory_math.gd`; prop `blends/props/observatory_platform.py` |
| Observatory hall board | `godot/scenes/escape/observatory_board.gd` (wired in `hub_architecture.gd`) |
| Title easter egg | `godot/scenes/title/title.gd` (`_add_star_hotspot`), `godot/ui/easter_egg_cat.gd`, `godot/shaders/story_bg.gdshader` |
| Scene loading | `godot/autoload/scene_manager.gd`; loading overlay in `tools/build_web.py` |
| Native screenshot tools | `godot/tools/*_shot.*`, `godot/tools/star_click_check.*` |
| Design notes | `docs/observatory-design.md`, `docs/observatory-mechanism-design.md` |

## Plans not reached

- **Calendar (05) and Observatory's neighbours (06 is now built).** Calendar is
  still a placeholder.
- **Older Brother's reward** for the next hall connector; **Roman Flow**'s win
  still leads nowhere.
- **The final exit** and ending sequence.
- **Observatory extras**: a Futurescope channel, a second lamp/connector,
  multiple attractor presets per sigil, and sound for every detent.
- **Card work**: deck editing, controller support for Journal/New match,
  friend-group art, recorded character speech, and a human balance pass.
- **Committed test saves** and a loader test; optics layout in the save editor.

## Known limits and useful checks

- **Observatory interaction** uses an orbit camera and angle-based focus, not a
  raycast. Controls are grouped by function and sit at varied radii; if you move
  one, update both `_controls[].angle` and the Blender position.
- **The secret star's click gate and its twinkle share one brightness value**
  driven from `title.gd`, so they cannot drift apart. The shader's `show_secret`
  keeps the star out of the intro.
- **Aether flow, solidification and the LCD** are approximations: the plate uses
  a layer-count shader, the trail field is a lagged ghost, and the LCD is a
  SubViewport rendered through a screen shader with the DSEG14 font.
- **The threaded Web build** needs COOP/COEP; use the provided serve script.
  Without those headers the build falls back or fails to load threaded assets.
- `cards_transition_render_test` needs a real window and is skipped headless.
- The full suite is green: **47 passed, 1 skipped, 3045 checks** in about two
  minutes on this machine (the skipped suite is the window-only render test).

A focused playtest: New game → 06 Observatory → select a sigil, align the blue
cloud to the gold ghost, open the valves until the sight glasses glow, crank four
clean layers, pull the inscribe lever; then check the hall blackboard and the
Observatory's trophy/board piece. Try the two-hand reset (open both covers,
press A, wait for amber→green, press B). On the title, click the gold star.

## Verification and working habits

At handoff, `tools/run_tests.py` passes. Automated checks run headless and muted;
browser checks use a background tab with `?muted=1`. Native visual checks are
possible with Xvfb + the OpenGL renderer and the `tools/*_shot.tscn` helpers.
Rebuild the Web playtest after gameplay or presentation changes; see
[`AGENTS.md`](../AGENTS.md).
