# CHRONO RAIDER (the secret room's arcade cabinet)

A 1985 horizontal shooter, smuggled back across the 1963 line and hidden in the Easter
egg room under the hall. Walk up to the cabinet and interact to play. It is optional:
the game never reports a win, so it adds nothing to saves or the travellers' board.

This is a **foundation**: one stage, one boss, three weapons, ready for a design pass.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | Arrows / WASD | Left stick / D-pad |
| Fire (hold) | Z / J / Space | A / right trigger |
| Switch weapon | X / K | X / Y |
| Speed gear (4 settings) | Shift / V | Shoulders |
| Start (title screen) | Fire / Enter | A / Start |
| Pause menu | Escape | B |

## How it plays

- **Weapons, ThunderForce-style.** You keep every weapon you collect and switch freely:
  **PULSE** (twin cannon; level 2 adds diagonals, level 3 rear shots), **FAN**
  (3/5/7-way spread) and **SEEKER** (forward shot plus 1/2/4 homing missiles).
- **Couriers** (violet carriers) drop a capsule that **changes weapon every two
  seconds**: time your grab. A new weapon is added and selected; one you have levels up.
- **Shot down?** You lose a ship and the weapon in your hand, dropped as a capsule you
  can fly back for. PULSE is never lost, only reset to level 1.
- **The temporal patrol:** ticks (weaving clock drones), hourglass mines (burst into
  sand when shot or when their time runs out), gunships (swoop in, fire aimed bursts,
  leave) and spinning gears (rings of shots). Enemies fire more as the stage goes on.
- **The CHRONARCH**, a clock-tower dreadnought, arrives after "WARNING". Its clock
  face is the weak point. It cycles a sweeping minute-hand spray, aimed cannon fans and
  hourglass mines, faster below half health.
- The HUD's YEAR climbs from 1963 to 1985 as you fly up the timestream. The high score
  is kept on this machine in `user://chrono_raider.json`.

## Module map

| File | Role |
| --- | --- |
| `arcade.gd` / `arcade.tscn` | MiniGame root: a 384x216 SubViewport shown with crisp pixels and `arcade_crt.gdshader`; stops the screen while paused |
| `shooter.gd` | The game: modes (title, play, over, clear), the 60 Hz `step()`, collisions, drawing; `attract_only` for the cabinet's screen |
| `controls.gd` | Keyboard and gamepad, with `forced` input for tests and tools |
| `player.gd`, `weapons.gd` | The Raider, gears, arsenal, respawn; weapon fire patterns |
| `enemies.gd`, `boss.gd` | Enemy roster and behaviour; the CHRONARCH |
| `stage.gd` | Stage 1's spawn timeline and the boss's arrival time |
| `entities.gd` | Shots, sparks, weapon capsules |
| `background.gd` | Parallax timestream: clocks, drifting years, stars, streaks |
| `hud.gd`, `pixel_art.gd`, `sprites.gd` | Text and screens; ASCII sprite textures and the 5x7 font; the sprites |
| `high_score.gd` | The cabinet's high score file |
| `../../scenes/escape/arcade_cabinet.gd` | The 3D cabinet in the secret room, running the attract screen live while on camera |

Sounds are the `arcade_*` cues in `assets/audio/cues.json` (existing CC0 files).
`tools/arcade_shot.tscn` renders the title, play, boss and cabinet to PNGs;
`tests/arcade_test.gd` covers the rules, the launcher and the cabinet.

## Ideas for the design pass

- More stages, each a different era of the timestream (Roman, Egyptian, Mayan,
  the 1950s workshop?), with midbosses and terrain.
- Music: a chiptune loop (the original STARLOOM sequenced its own).
- Overdrive / grazing, drones, shields, name entry on the high-score table, an attract
  demo that plays itself, difficulty levels.
- Balance: enemy HP, fire rates and the timeline are all first guesses.
