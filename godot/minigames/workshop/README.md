# 04 Workshop: the Engineer's time loop

A hand-drawn 2D point-and-click story in the spirit of *Lost in Play*. Walk up to the
Workshop's bench in the hall (room 04) and the scene switches to the Engineer's garage
lab: a 1950s workshop with a sleeping ginger cat called Fuse, a television that shows
the future (the **Futurescope**) and a homemade time machine (the
**Chrono-Oscillator**).

Everything is drawn from code; there are no image assets.

## The story (spoilers)

1. **Setup.** The Futurescope is missing a tube. Click the radio three times (play it,
   open its back, take the tube), put the tube in the Futurescope and click it again to
   tune it.
2. **The vision.** The Futurescope shows the room's future: Fuse, tangled in yarn with a
   sardine-tin lid on one ear, leaps on the machine's lever and walks into the portal.
   Then, live, the portal opens by itself and that same scruffy cat walks *out*. Two
   cats. Sirens. The Officer from the intro arrives to gloat.
3. **Make the loop.** Make the footage come true:
   - icebox → sardines; drop them on the floor; the drawer's can opener opens them. Fuse
     wakes, eats, and gets the lid stuck on his ear.
   - the knitting basket → the yarn ball rolls out and Fuse gets tangled.
   - the coffee can → the fuse; put it in the machine.
   - set the dial to what the footage showed (**A MOMENT AGO**). Click the Futurescope
     to watch the footage again.
   - the flashlight on the lever → Fuse pounces, the portal opens, in he goes. The
     flashlight refuses (with the Engineer saying what's still different) until every
     detail matches.
4. **Break the loop.** The Futurescope now shows the remaining cat doing it again and
   again: cats pouring out of the portal. Lure it away with the flattened box (put it on
   the floor: if it fits, it sits), then pull the fuse out of the machine.

Clicking the Engineer always gives a hint for the next step.

## Controls

Click things to poke them. Click an item in the tray to hold it, then click where to
use it; right-click or Escape puts it back. Click to skip or dismiss speech. Escape
otherwise opens the pause menu (Leave, Sound, Quit to title).

## Module map

| File | Job |
| --- | --- |
| `workshop.gd` | The MiniGame: builds the stage, hover, clicks, inventory selection, save/resume. |
| `story.gd` | What every click does in each phase (`setup`, `loop`, `break`, `done`), and the scenes. |
| `lines.gd` | Everything the Engineer and the Officer say, plus hints. Rewrite freely. |
| `vision.gd` | The scenes the Futurescope shows, played in a second copy of the room. |
| `world.gd` | Builds the room in drawing order; also built inside the Futurescope. |
| `ink.gd` | The drawing kit: wobbly outlines that boil, soft inner light and shade. |
| `palette.gd` | Colours. |
| `thing.gd` | Base for drawn objects and clickable hotspots. |
| `backdrop.gd`, `icebox.gd`, `bench.gd`, `small_props.gd`, `machine.gd`, `futurescope.gd` | The room and its props. |
| `cat.gd` | Fuse: poses, walking, jumping, yarn and lid. |
| `person.gd` | The Engineer and the Officer. |
| `bubble.gd`, `items.gd`, `overlays.gd` | Speech bubbles, item icons, inventory tray, cursor label, Futurescope close-up, alarm. |
| `crt.gdshader` | The Futurescope's picture. |
| `workshop_trophy.gd` | The 3D trophy on the hall platform after a win. |

Stage space is 1600 × 900 (floor line at y = 660), scaled to fit the window.

## Checks and tools

- `tests/workshop_story_test.gd` plays the whole story through the click handler,
  including save and resume in each phase.
- `tools/workshop_shot.tscn` renders screenshots of scripted steps, e.g.
  `-- --out=/tmp --script=run:radio,run:radio,shot:radio`. See the file for the steps.

## Ideas not reached

- Sound design: a proper siren, purring, the portal's hum, the Futurescope's static.
- The Officer could appear on the Futurescope instead of in person.
- More cat business (the sunbeam, the blinds, the radio's music).
- A reward item for a future hall puzzle (the fuse? the Futurescope's tube?).
