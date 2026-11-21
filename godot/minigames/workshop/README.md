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

The Workshop is for poking at things, not for being told what to do. The Engineer walks
in a moment after you (every time: "I wasn't following you"), talks mostly about
himself, minds his things and gets steadily more put out as you rummage (his milk above
all), and only nudges when you're nearly there. The Officer only scoffs.

1. **Setup.** He mourns his Futurescope: dark since Tuesday, and nobody makes the tube.
   Fuse is asleep on the icebox and won't stir for anything. The radio opens up close:
   a power knob, a tuning knob with three stations (easy listening, a Bach-style minuet,
   Radio Havana), and round the back four screws, then the tubes. The tube fits the
   Futurescope; tuned, it shows the future.
2. **The vision.** Fuse, tangled in red yarn with a sardine-tin lid on one ear, leaps on
   the machine's lever and walks into the portal. Then, live, the portal opens by itself
   and that very cat walks *out*. Fuse wakes on the icebox; the two see each other and
   both jump. The one from the future couldn't care less and curls up on the floor. The
   clock stops at that minute. Sirens. The Officer, with Form 27-B.
3. **Make the loop.** Make the footage come true. Fuse, awake now, only comes down
   from the icebox for something:
   - **Lid:** sardines from the icebox, on the floor, opened with the can opener from
     the drawer (opened earlier, they've been waiting for him).
   - **Yarn:** the red yarn is on the cat from the future: unwind it and give it to Fuse
     once he's down. (Nobody ever made that yarn.)
   - **Power:** the fuse is blown; the pegboard's copper wire bridges it.
   - **Destination:** the counter must match the footage's (the stopped clock agrees;
     click it for a close look).
   - **The lever:** you can't pull it; in the footage the cat did. Shine the flashlight
     on it and Fuse pounces. Anything not as in the footage and the timeline is
     deleted, as the Officer promised: a glitch, a stamp, a harmless rewind to just
     before the lever (nothing is lost), a remark, and what differs flickers.
   The flashlight makes him pounce at almost anything: the Futurescope, the tubes, the
   bench (knocking the radio to another station), the blind cord, the Engineer's shoe.
4. **Break the loop.** The Futurescope now shows the remaining cat going round again.
   He's fixated on the lever and jumps on it if you reach for the wire. A box in the
   shade gets a look; open the blinds and put the box in the sunbeam, and in he goes.
   The Engineer points out the moment: the wire is all that keeps the portal open.
   Pull it.

Coming back after the win is the epilogue (`epilogue.gd`): Futurescope channels from
other rooms and sending things to the hall; see `docs/INTERCONNECTION.md`.

## Controls

Click things to poke them. Click an item in the tray to hold it, then click where to
use it; right-click or Escape puts it back. Click to skip or dismiss speech. Escape
otherwise opens the pause menu (Leave, Sound, Quit to title).

On a controller (any slot), the left stick moves the cursor and the D-pad nudges it
slowly; A (Cross) clicks, B (Circle) puts a held item back, closes the radio, or leaves
the Workshop; Y (Triangle) opens the pause menu. Moving or clicking the mouse hands the cursor back to it.

## Module map

| File | Job |
| --- | --- |
| `workshop.gd` | The MiniGame: builds the stage, hover, clicks, inventory selection, save/resume. |
| `pad_pointer.gd` | The controller's cursor: stick/D-pad movement, and when it, rather than the mouse, is pointing. |
| `story.gd` | The state machine: what every click does in each phase (`setup`, `loop`, `break`, `done`), and the scenes. |
| `engineer.gd` | The Engineer turning up after you, minding his things (annoyance, his milk), once-only remarks and nudges. |
| `pounce.gd` | The flashlight: where Fuse lands for each thing, and what happens. |
| `radio_view.gd`, `radio_songs.gd` | The radio close-up, and its three stations (procedural music, `godot/audio/music`). |
| `dev_stages.gd` | Jump points for the developer save editor. |
| `epilogue.gd`, `channels.gd` | Visiting after the win: Futurescope channels and sending things through the ring. |
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

Stage space is 1600 × 900 (floor line at y = 660), scaled to fit the window.

## Checks and tools

- `tests/workshop_story_test.gd` plays the whole story through the click handler,
  including save and resume in each phase.
- `tools/workshop_shot.tscn` renders screenshots of scripted steps, e.g.
  `-- --out=/tmp --script=run:radio,run:radio,shot:radio`. See the file for the steps.

## Ideas not reached

- Sound design: a proper siren, purring, the portal's hum, the Futurescope's static.
- The Officer could appear on the Futurescope instead of in person.
- More things to send from 1955 to the hall, and things to send back
  (see `docs/INTERCONNECTION.md`).
- The radio's music reaching the cats (Fuse has opinions about Bach).
