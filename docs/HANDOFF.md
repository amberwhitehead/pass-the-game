# Pass The Game handoff

Handoff snapshot: **November 17, 2026**, at the end of tesseract's turn. Earlier
handoffs are kept in [`docs/handoffs/`](handoffs/); cee.wtf's
[November 16 handoff](handoffs/2026-11-16-cee.wtf.md) describes the hall, prism
connector and card game in depth, and most of it still holds.

New here, or coming back? Start with [Getting started](GETTING_STARTED.md): setup,
checking everything works, and what is open. [`Changes.md`](../Changes.md) lists
every commit by contributor.

## What this turn added

This turn worked on a Windows machine and focused on making the game easier to
pick up and keep: saving, menus, tests and tooling. No new rooms or puzzles.

**For players**

- **Title screen with saves.** Continue (the latest save), New game (always a new
  slot) and Load game (every save newest first, each with Delete). Progress
  saves automatically as readable JSON, with as many slots as you like.
- **Escape pause menu** in the hall and in minigames: Resume, Sound, Quit to
  title, and Leave in a minigame. Escape keeps its existing jobs first (releasing
  a prism wheel, closing card dialogs, leaving a solved puzzle).
- **Minigames resume where you left them**, across quitting: Egypt's rollers,
  Roman Flow's rollers and pins, and card matches (replayed exactly through the
  rules). A win clears it.
- **Sound** now opens from the title screen and pause menu instead of a floating
  button.
- **Fix:** pressing a prism's TURN or LIFT/PLACE handle raised a script error that
  stopped editor runs (exported builds were unaffected).

**For contributors**

- **One command for every check:** `python3 tools/run_tests.py` (`py -3` on
  Windows). All Godot suites run in one process, about 30 s with import;
  `--quick` about 2.5 s. Compile errors stop the run in about 2 s naming file and
  line; a script error or hang fails only its suite.
- **One command to build and serve the Web playtest** on any OS:
  `python3 tools/build_web.py --serve`.
- **Save editor** (developer mode: editor runs, `?dev=1`, or `--dev`): open any
  save, tick wins, cards and hall progress or edit the raw JSON, then Save, Save
  as new slot, or Play (unsaved). The quickest way to reach later content.
- **Windows fixes:** three outdated card tests, a macOS-only temp path that hid
  nine checks, Python tools now read files as UTF-8, and Godot no longer rewrites
  texture imports (it was converting the character palettes to lossy compression).
- **Docs:** [Getting started](GETTING_STARTED.md) and [`Changes.md`](../Changes.md).

## What changed for you

**rmurrish** (foundation, characters, Egypt Fractal, Roman Flow)

- The game opens on a title screen (`scenes/title/`); your intro is unchanged and
  plays for New game.
- In Egypt and Roman Flow, Escape opens the pause menu instead of leaving, except
  once solved, where it still leaves (`_back_leaves()`). The × button still leaves.
- Both games save and resume their state (`save_state()` / `resume_state`).
  Roman Flow also stops its GPU simulation while paused.
- The character and prop palette `.import` files have "Detect 3D" off, so they
  stay lossless as committed; `project.godot` defaults new textures the same way.

**cee.wtf** (hall, prism connector, card game, sound, tests)

- `cards_motion`, `cards_scene` and `cards_transition` tests were updated for a
  slow first frame, the card stand and the resize-fitted FOV; they now pass.
- Every test suite's first line changed to `extends "res://tests/test_suite.gd"` so
  they all run in one process; the checks themselves are untouched. Run a single
  suite with `--script res://tests/run_suites.gd -- <suite>`.
- At the card table, Escape opens the pause menu unless it has a job (closing a
  dialog, cancelling a swap, the entrance, a decided match). The rules text says so.
- Card matches resume by replaying the seed and actions; a replay that no longer
  matches the saved snapshot deals a fresh match.
- The optics handle error is fixed; the floating Sound button is gone (the mixer
  is unchanged); `AGENTS.md` now points to the Python build script.

**Amber**

- This turn arrives as a pull request from a fork
  (`tessprime/pass-the-game`, branch `tesseract-changes-11-17`) rather than a
  commit on `main`. How turns should reach the repository is your call.

**Anyone adding a minigame**

- Escape opens the pause menu by default; override `_back_leaves()` to leave
  directly. Return state from `save_state()` and read `resume_state` to resume.
- Saved values come back as plain data: convert numbers with `int()`/`float()`
  and compare saved structures with `SaveGame.same_data()`. The
  [project guide](../godot/README.md#adding-a-minigame) has the details.

## What a player can do now

| Place | Current behavior |
| --- | --- |
| Title screen | Continue, New game, Load game (with Delete), Sound; Save editor in developer mode. |
| 01 — Egypt Fractal | Open from the start; its first win reveals the two prisms. Resumes where left. |
| Main hall optics | Route green light to Door 2 to open Roman Flow. Saved across quitting. |
| 02 — Roman Flow | Open after the optics puzzle. Resumes where left. |
| 03 — The Brothers | Little Brother's tutorial and Older Brother's match; matches resume. Five hall cards join Older Brother's deck. |
| 04 Workshop, 05 Calendar, 06 Observatory | Furnished, no games yet. |
| Final exit | Still sealed. |

Card balance is unchanged from cee.wtf's handoff (Older Brother's 12-card base
deck, five discoveries, "very hard with none, very easy with all five"); see
[that handoff](handoffs/2026-11-16-cee.wtf.md#card-balance-at-handoff). It still
needs human playtesting.

## Where to make changes

cee.wtf's [table](handoffs/2026-11-16-cee.wtf.md#where-to-make-changes) still
applies for the hall, optics, cards and audio. New this turn:

| Area | Main entry points |
| --- | --- |
| Saving, slots, save format | `godot/autoload/save_game.gd` (JSON format, type allow list, migration); `godot/autoload/game.gd` (autosave, Continue, New game) |
| Title screen | `godot/scenes/title/title.gd` |
| Pause menu | `godot/autoload/pause_menu.gd`; `MiniGame._back_leaves()` in `godot/minigames/mini_game.gd` |
| Minigame resume | `save_state()` / `resume_state` in each minigame; storage in `godot/autoload/minigames.gd` |
| Developer tools | `godot/autoload/dev_mode.gd`; `godot/scenes/dev/` (save editor and its rules) |
| Tests | `tools/run_tests.py`; `godot/tests/run_suites.gd` and `test_suite.gd`; [test guide](../godot/tests/README.md) |
| Build | `tools/build_web.py` (any OS); the Bash scripts remain for macOS/Linux |

## Plans not reached

Still open from cee.wtf's list: friend-group card themes and art, more interesting
card discoveries, the next item and hall connector (beginning with Older
Brother's reward), recorded character speech, music and a listening pass, and the
remaining rooms and final exit. Persistent saves, item 4 there, are done.

Started or noticed this turn:

1. **Committed test saves.** Save files for points in the game (Egypt solved,
   Door 2 open, all cards found, a card match in progress), made with the save
   editor, plus a test that loads each into the real hall and checks what a
   player would see. They would catch save-format breaks early.
2. **Optics layout in the save editor.** It is raw-JSON only for now.
3. **Wins ticked in the save editor** record only that they were won, so the Egypt
   and Roman Flow trophies (built from a real win's details) show nothing for them.
4. **Skip the compile pass when no script changed** (saves about a second a run).
5. **Roman Flow's puzzle** (simulation, solver, win) has no automated tests.
6. **Sound is unreachable** from the intro and the save editor, which have no menu.

## Known limits and useful checks

- **Not checked visually:** the title screen's save list with many saves, the
  pause menu and the save editor, especially at narrow widths. Browser tools
  weren't available this turn, and native windows were avoided.
- **Web tab closing** may not trigger Godot's close notification, so the last
  half second of changes, or an open minigame's progress, could be lost. Untested.
- `cards_transition_render_test` needs a real window and was not run on Windows.
- `--isolated` once reported `ui_panels_test` as "Godot did not run the suite"
  with an empty log; it passes otherwise. Unexplained, and set aside.
- "Detect 3D" is now off for every committed texture and by default for new ones,
  so the editor should no longer rewrite `.import` files. If one appears changed
  anyway, revert it rather than commit it.

A focused playtest: New game, solve Egypt (or Shift+L), carry the prisms and open
Door 2, leave Roman Flow midway and come back, quit to title and Continue, then try
the save editor at `?dev=1` to jump to Older Brother with all five cards.

## Verification and working habits

At handoff, `tools/run_tests.py` passes: 27 Godot suites and the Python tool
tests, 2,278 checks, in about 30 seconds on Windows with Godot 4.7.2. The
window-only render test is skipped. Automated checks run headless and muted;
browser checks use a background tab with `?muted=1`. Rebuild the Web playtest
after gameplay or presentation changes; see [`AGENTS.md`](../AGENTS.md).
