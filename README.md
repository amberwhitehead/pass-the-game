# Pass The Game

A collaborative Godot game: a first-person escape-room hall connects small
puzzles contributed by different developers. The current build includes Egypt
Fractal, Roman Flow, a prism puzzle that connects them, and two brothers' card
duels. Three side rooms remain available for future games.

## Start here

- **[Getting started](docs/GETTING_STARTED.md):** set up, check everything works
  (`tools/run_tests.py`), see the game, what is open to work on, and how earlier
  turns were handed over.
- **[Changes](Changes.md):** what each contributor added, by turn.
- **[UI and input patterns](docs/UI_PATTERNS.md):** controller layout, prompts, targeting,
  feedback and highlighting rules every screen follows.
- **[Handoff notes](docs/HANDOFF.md):** the state at the end of the latest turn,
  what changed for returning contributors, unfinished plans, and useful next
  steps. Earlier handoffs are in [docs/handoffs](docs/handoffs/).
- **[Setup and project guide](godot/README.md):** editor, Web, Windows, macOS,
  controls, architecture, and adding a minigame.
- **[Audio guide](godot/audio/README.md):** the CC0 sounds are included in the
  repository. Audition alternatives, adjust the mix, and export choices for review.
- **[Refraction Hall](godot/scenes/escape/README.md)** and
  **[card game](godot/minigames/cards/README.md):** mechanics and module maps.
- **[Checks](godot/tests/README.md)** and
  **[balance simulator](godot/simulation/cards/README.md):** regression coverage
  and data-driven tuning tools. Older simulation reports describe earlier deck
  configurations; the current card balance needs human playtesting.

## Quick start

Use **Godot 4.7.2** with its matching export templates. Python 3 is needed
for the Web build/audition page and local server; no Python packages are
needed just to play or build. The game uses GDScript and GL Compatibility.

```sh
git clone https://github.com/amberwhitehead/pass-the-game.git
cd pass-the-game
```

Import `godot/project.godot` in Godot, let its asset import finish, and press
**F5** for the whole game. For the Web playtest on any OS, install the export
templates through Godot's **Editor → Manage Export Templates**, then run from the
repository root (`py -3` instead of `python3` on Windows):

```sh
python3 tools/build_web.py --serve
```

Open **[http://localhost:8060/](http://localhost:8060/)**. If Godot 4.7.2 is not
on PATH or installed at `/Applications/Godot.app`, pass it explicitly:

```sh
python3 tools/build_web.py --serve --godot /path/to/Godot
```

See the [full setup guide](godot/README.md) for rebuilds and options.
All game sounds are included in the checkout. After a Web build, the
[audition page](http://localhost:8060/audio/) lets you compare sound choices.

Look with the **mouse** (click the game once so it can take the cursor), walk with
**W/S**, strafe with **A/D**, jump with **Space**, and press **E** to interact.
Every keyboard key can be changed in **Escape → Controls**.
**Escape** opens a pause menu (Resume, Sound, Quit to title, or leave the current
minigame) whenever it has nothing else to do. Progress saves automatically, with as many
save slots as you like; the title screen offers **Continue**, **New game** and **Load game**.
There is no final escape sequence
yet.
