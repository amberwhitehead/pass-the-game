# Getting started

For anyone picking up Pass The Game: someone new, or a previous contributor
coming back. It covers setting up, checking that everything works, seeing the
game, what is open to work on, and how earlier turns were handed over.
[`Changes.md`](../Changes.md) lists what each contributor added.

## 1. Set up

You need:

- **Godot 4.7.2** (the standard build, not .NET) and its **4.7.2 export
  templates**, installed through **Editor → Manage Export Templates**. Templates
  must match the editor version exactly.
- **Python 3** for the build script, test runner and local server. No packages
  are needed.
- Blender only if you change the character or prop models in `blends/`.

Then, from the repository root (`py -3` instead of `python3` on Windows):

```sh
python3 tools/run_tests.py          # every check, about a minute
python3 tools/build_web.py --serve  # browser playtest at http://localhost:8060/
```

Both find Godot from `--godot PATH`, the `GODOT` variable, `godot` on PATH, or
`/Applications/Godot.app`, and refuse any version but 4.7.2. Everything should
pass before you change anything; if something fails on a clean checkout, that is
worth knowing first. To work in the editor, import `godot/project.godot` and
press **F5**.

Things that have tripped people up:

- **An older Godot on PATH.** The scripts catch this; pass `--godot` to the
  4.7.2 executable.
- **`.import` file changes you didn't make.** These files are committed source
  (per-asset settings and stable IDs); the cache is the ignored `godot/.godot/`.
  If an editor rewrites them, revert rather than commit them. See the
  troubleshooting notes in the [setup guide](../godot/README.md).
- **Build output becoming project assets.** `godot/build/` needs a `.gdignore`;
  the scripts create it.
- **Native windows during tests.** Checks run headless and muted; browser visual
  checks use a background tab at `http://localhost:8060/?muted=1`.

## 2. See the game

Start a **New game** on the title screen. Escape opens the pause menu almost
everywhere. Progress saves automatically; New game always starts
a new slot, and Load game lists every save.

1. **01 Egypt Fractal** is open from the start. **Shift+L** inside it lights all
   three crystals if you want to skip the puzzle. Winning reveals two prisms.
2. In the hall, carry the prisms and the yellow/blue lenses to route one green
   beam to the receiver beside Door 2. The solution is in the
   [Refraction Hall guide](../godot/scenes/escape/README.md).
3. **02 Roman Flow** opens.
4. **03 The Brothers** is open throughout: Little Brother's tutorial and Older
   Brother's harder match. Five cards hidden around the hall join Older
   Brother's deck when found.
5. **04 Workshop, 05 Calendar, 06 Observatory** are furnished but empty.

**To reach later content quickly**, use the **Save editor**. In developer mode
(running from the Godot editor, `?dev=1` on the Web build, or a `--dev` launch
option) it appears on the title screen; with the scene open in the editor, **F6**
opens it directly. Tick wins, found cards and hall progress, or edit anything in
the raw JSON. It warns if hall items no longer add up (2 prisms, 1 yellow lens, 1
blue lens across cradles, hand and mounts). **Play (unsaved)** tries the result in
the hall without writing a save; **Save** or **Save as new slot** keeps it.

The [setup and project guide](../godot/README.md) has controls, the project map
and how to add a minigame; each area has its own guide linked from there.

## 3. What is open

These are gathered from the [handoff](HANDOFF.md) and the
[design notebook](prism-room-puzzle.md). They are possibilities, not
assignments, and several are the owner's to decide.

**Empty rooms.** Each has a name, an accent color, a resident character and a
subtitle (`godot/scenes/escape/hub_architecture.gd`), but no game:

| Room | Resident | Subtitle |
| --- | --- | --- |
| 04 Workshop | 50s Engineer | IDEAS UNDER CONSTRUCTION |
| 05 Calendar | Mayan | THE SHAPE OF TIME |
| 06 Observatory | Metric A | BEYOND THE KNOWN |

**Connections between rooms.** The intended shape is: win a room, receive an
item, use it in a short hall puzzle, open the next room. One link exists (Egypt →
prisms → beam → Roman Flow). Open:

- Beating Older Brother should award an item for the next hall puzzle; the item,
  puzzle and destination are not chosen.
- Roman Flow's win currently leads nowhere; its place in the chain is undecided.
- The final exit is sealed and has no ending sequence.
- The center of the hall is deliberately kept clear for later puzzles.

**Other plans recorded in the handoff.** Card themes and artwork from the owner's
friend group (card faces accept an `art_path`); more interesting card
discoveries; recorded character speech; music and a listening pass on the mix.
Persistent saves, listed there as unbuilt, now exist.

**Smaller gaps.** No way to edit the deck; card play has no full gamepad
navigation; Roman Flow's puzzle itself (simulation, solver, win detection) has no
automated tests, only its menu and resume behavior; the card balance needs human
playtesting rather than more simulation.

## 4. How earlier turns were handed over

There is no written process. This is what contributors have done so far, as
recorded in the history:

- **Amber Whitehead** created the repository and owns it on GitHub.
- **rmurrish** committed the foundation directly to `main` as one commit.
- **cee.wtf**'s turn was committed to `main` by Amber as one commit. It added the
  [handoff notes](HANDOFF.md), describing the current state, what was dropped,
  and plans not reached, and `AGENTS.md` for AI coding agents.
- **tesseract** worked on a branch (`tesseract-changes-11-17`) in a fork, as a
  series of smaller commits, started [`Changes.md`](../Changes.md) to record each
  contribution, and planned a pull request.

How the next turn reaches the repository, and any conventions for turns, are
Amber's call.
