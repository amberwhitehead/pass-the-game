# 04 Workshop: the Engineer's time loop

A hand-drawn 2D point-and-click story in the spirit of *Lost in Play*. Step through the
Workshop's portal ring in the hall (room 04) and the scene switches to the Engineer's garage
lab: a 1950s workshop with a sleeping ginger cat called Fuse, a television that shows
the future (the **Futurescope**) and a homemade time machine (the
**Chrono-Oscillator**).

Everything is drawn from code; there are no image assets.

## How you get there

The Workshop's station in the hall is a brass portal ring, twin of the one in the
Engineer's workshop. Through it is 1955, and from the hall the past looks hand-drawn.
"Nobody knows why," says the Engineer.

## The story (spoilers)

The Workshop is for poking at things, not for being told what to do: the Engineer
mostly mutters, the Officer only scoffs, and things that can't be done just wiggle.

1. **Setup.** The Futurescope is missing a tube. The radio has one (play it, open its
   back, take it). Put it in the Futurescope and tune it.
2. **The vision.** The Futurescope shows the room's future: Fuse, tangled in red yarn
   with a sardine-tin lid on one ear, leaps on the machine's lever and walks into the
   portal. Then, live, the portal opens by itself and that same scruffy cat walks *out*.
   The wall clock stops at that minute. Sirens. The Officer arrives, scoffs, and
   announces that this timeline is scheduled for deletion.
3. **Make the loop.** Make the footage come true:
   - **Lid:** sardines from the icebox, put on the floor, opened with the can opener
     from the drawer. Fuse wakes, eats, and wears the lid.
   - **Yarn:** the knitting basket has only grey wool. The only red yarn in the room is
     wrapped around the cat from the future: unwind it off him and give it to Fuse.
     (Nobody ever made that yarn.)
   - **Power:** the machine's fuse is blown and there is no spare. The coil of copper
     wire on the pegboard bridges the socket.
   - **Destination:** turn the counter's wheels to what the footage's counter shows.
     The wall clock stopped at the same minute (click it for a close look).
   - **The lever:** you can't pull it (in the footage the cat did). A flashlight spot
     on it and Fuse pounces. The rule is simply "look like the footage": if anything
     differs, the portal flares red, throws him back out, and what's different flickers.
4. **Break the loop.** The Futurescope now shows the remaining cat doing it again and
   again. Reaching for the wire while he watches makes him jump on the lever first. A
   box in the shade doesn't interest him; open the blinds and put the box in the
   sunbeam, and in he goes. Then pull the wire.

The Futurescope can be rewatched at any time.

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

- Sending things from the workshop through the Chrono-Oscillator into the 3D hall
  (out of the hall's ring), and the Futurescope showing problems in other rooms: a
  way to make earlier rooms worth revisiting.

- Sound design: a proper siren, purring, the portal's hum, the Futurescope's static.
- The Officer could appear on the Futurescope instead of in person.
- More cat business (the sunbeam, the blinds, the radio's music).
