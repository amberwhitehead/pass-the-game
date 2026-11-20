# Interconnection: revisiting rooms

Rooms used to be a straight line: solve one, open the next, never go back. This is the
structure for making them affect each other, so a win in one place changes another and
players have reasons to return. It was started in the 50s Engineer's turn (the Workshop)
and is meant to be extended.

## The idea

A win somewhere sets off a **problem** somewhere else. The Workshop's **Futurescope**
(a TV that shows the future) picks up each problem as a **channel** and shows how it
ends: the hint. Things travel between the Engineer's 1955 workshop and the hall through
the two **portal rings**. Rewards for fixing problems are often **bonus cards**, which
join the deck the player takes to Older Brother, so the card table becomes the place
where everything a player has done adds up.

Rules of thumb:

- Keep first visits solvable on their own. Revisits add; they don't gate the main path.
- Show, don't tell: a channel's footage, a darkened room, a changed line of dialogue.
- An "ohhh, that's what that's for" moment is the goal: an object from one room has a
  second life in another.

## The pieces

| Piece | Where | What it does |
| --- | --- | --- |
| `TimeLink` | `godot/autoload/time_link.gd` | Static helper over `Game` flags. `PROBLEMS` registry (`is_active`, `fix`, `active_problems`), the ring tray (`send_to_hall`, `tray_item`), and `SENDABLE` (what 1955 can send). Listen with `Game.flag_changed`. |
| Hall revisits | `godot/scenes/escape/revisits.gd` | The hall's side: the ring tray (a carry slot on the Workshop's tabletop, under the ring), Fuse napping behind the relay cabinet, Egypt's darkness and its reward, and the Engineer's changing lines. `room.gd` adds it with a few lines. |
| Futurescope channels | `godot/minigames/workshop/channels.gd` | One hand-drawn scene per problem, shown when the won Workshop's TV is clicked. |
| Workshop epilogue | `godot/minigames/workshop/epilogue.gd` (`begin()`) | A won Workshop reopens calm: channels on the TV, and sendable items used on the portal go to the hall's ring tray. |
| Bonus cards | `godot/minigames/cards/deck_progression.gd` (`BONUS`) | Join Older Brother's deck like hall discoveries but aren't counted in "N / 5 found". Defined in `card_catalog.gd`. |
| Carry items | `godot/scenes/escape/carry_inventory.gd` (`ITEMS`), `carry_visual.gd` | Hall items, now including the 1955 flashlight. |
| Optics lamp | `godot/scenes/escape/optics_model.gd`, `optics_controller.gd`, `sun_disc.gd` | A second light: the flashlight in lamp socket F, its own beam traced separately, through Egypt's doorway (the model lets a beam continue into that room) to the sun disc on its east wall. It never opens Door 2. |

## What exists now (spoilers)

After the Workshop is won:

1. **Fuse on the loose** (`fuse_loose`). The cat wanders out of the ring and naps on the
   floor in the warm exhaust behind the hall's optical relay cabinet. Pet him: a card
   was stuck in his fur. The
   **Fuse** bonus card (a 1-cost diagonal attacker) joins the deck.
2. **Egypt's lost sun** (`egypt_dark`). Egypt's room goes dark; the Egyptian complains
   that "Ra does not travel well these days. Perhaps he needs... a lamp." The
   Futurescope's Egypt channel shows a flashlight on a stand shining through yellow glass
   onto a sun disc. Fix: send the flashlight through the Workshop's portal, take it from
   the ring tray, set it in the hall's lamp socket **F**, move the yellow lens to mount
   **N**, and aim the lamp through Egypt's doorway at the sun disc inside. White light
   isn't enough; it has to be yellow. The room lights up and the **Sun Scarab** bonus
   card waits under the disc. F, N and the disc lie on one line through the doorway.

## Adding a revisit

1. **Name the problem.** Add an entry to `TimeLink.PROBLEMS`: the minigame whose win sets
   it off (`after`), the flag that marks it fixed (`fixed_flag`), the room it's in, and a
   channel title.
2. **Make it visible where it happens.** In `revisits.gd` (or the room's own code),
   change something while `TimeLink.is_active(id)`: a light, a line of dialogue, an
   object. React to `Game.flag_changed` so it updates live.
3. **Show it on the Futurescope.** Add a scene class to `channels.gd` and an entry in
   `SCENES`. Draw in stage space (1600 × 900; the TV crops x 420–1620) with `ink.gd`,
   and have `play()` show how it ends.
4. **Give it a way to be fixed.** Often something carried from elsewhere. To send a new
   item from 1955, add it to `TimeLink.SENDABLE` and to the hall's `carry_inventory.gd`
   `ITEMS` (with a mesh in `carry_visual.gd`); make sure the Workshop's epilogue
   inventory offers it. Call `TimeLink.fix(id)` when solved.
5. **Reward it.** A bonus card (add to `card_catalog.gd` and `deck_progression.gd` `BONUS`,
   then place a `card_pickup.gd`), or a new item, or the next problem.
6. **Test it** like `godot/tests/revisits_test.gd`: before the trigger nothing changes,
   after it the problem shows, the fix works, it survives a reload, and nothing in the
   main path (Door 2, existing wins) changes.

The developer save editor can set wins and flags (raw JSON) to jump to any of this.

## Ideas not built yet

- **Hall → 1955.** The ring could carry hall items into the Workshop (a prism to split
  the Futurescope's picture? a lens?). `TimeLink` would need an inbox the Workshop reads.
- **Roman Flow's dry aqueduct.** Its win still leads nowhere. A channel could show its
  aqueduct running dry; something from another room (the copper wire as a pin?) fixes it.
- **Little and Older Brother noticing** what you've done: lines that change with bonus
  cards in the deck.
- **The final exit**, which could need one fix from every room.
