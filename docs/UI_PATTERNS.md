# UI and input patterns

The rules the hall, the minigames and their controls follow. They came out of
playtesting with a PlayStation (DualSense) controller and a mouse in the Web
build. Follow them in new work; if something here doesn't fit, change this file
in the same commit rather than quietly doing something else.

## Controller

Every screen must be fully playable with a controller, and with mouse and keyboard.

| Button | Does |
|---|---|
| ✕ / A, **R1** | The main action: interact, confirm, choose. (R1 is re-sent as A: `autoload/pad_aliases.gd`.) |
| **R2**, □ / X | The second action on a thing (e.g. take a prism off its stand). R2 is analog: read it per event with hysteresis (`player.gd` `_r2_motion`), never by polling once per tick. |
| ○ / B | Back: close or cancel what is open; in a minigame with nothing left to cancel, leave it like its × button. In the hall with nothing to go back from: **shrug** (see Feedback), not the menu. |
| △ / Y | The pause menu, everywhere. |
| **L1** | Jump. |
| D-pad / left stick | Move; in menus and 2D screens, move the focus or cursor. |

- **Any pad slot.** Browsers put pads in later slots (a DualSense showed up as 2). Pad events made in code use `device = -1`; polled reads loop over `Input.get_connected_joypads()`.
- **Menus** use Godot's `ui_*` actions; ✕ is `ui_accept` and ○ is `ui_cancel` (`game.gd`).
- **2D point-and-click** screens get a stick-driven cursor (`minigames/workshop/pad_pointer.gd`); **board games** get a focus that steps between legal targets (`minigames/cards/table_pad.gd`). Moving the mouse hands control back to it; tiny mouse jitter (< 4 px) doesn't.
- Keyboard keys stay rebindable (Controls); Escape still opens the menu.

## Showing buttons

- **Draw controller buttons, don't spell them.** `ui/pad_glyph.gd` draws the real button for the pad that is plugged in: PlayStation ✕ ○ □ △ in their colours, L1/R1 bars, L2/R2 triggers; Xbox coloured A B X Y, LB/RB, LT/RT; an unknown pad gets a plain circle (face) or rectangle (shoulder) that still says L1/R1/L2/R2. `autoload/pad_labels.gd` `kind()` tells them apart (by name and USB vendor id).
- **Pick the label by what is plugged in**: a controller plugged in shows its R1/R2; otherwise **Click** / **Right-click** (and A / T after touching the screen). Don't show keyboard letters such as E for interacting; clicking is the interaction.
- In plain text (hints, rules), use `PadLabels.face()` so a PlayStation pad reads ✕ ○ □ △.

## Prompts and labels

- **The interaction prompt is a small caption just under the crosshair** (`ui/interaction_plaque.gd`): a key badge and the action, e.g. `[R1] Adjust prism B`. Two actions stack on two lines with the badges in one column:
  ```
  [R1] Adjust prism B
  [R2] Take prism from B
  ```
- **The prompt names the thing**: "Talk to Egyptian", "Adjust prism B", not a bare "Talk".
- **No floating labels** over objects or characters (no names over heads, no tags over stands). Put identifying text *on* the object (a stand's letter on its front plate), or in the prompt.
- **No HUD panels for world information**. The objective lives on the console by the entrance (`scenes/escape/objective_console.gd`); the controls on the How to play placard (`scenes/escape/controls_placard.gd`). Prefer an in-world object to a screen panel.
- **Conversations sit at the bottom of the screen**; their continue hint follows the device (R1 drawn, or CLICK).

## Targeting

- Target **what the crosshair is on**: a ray from the crosshair picks the object it hits (any part of it); the nearest-in-angle rule is only the fallback (`player.gd` `_update_target`). An object made of parts returns its whole self from `Interactable.outline_root()`.
- The target gets a **2 px white outline round its silhouette** (`shaders/focus_mask.gdshader` + `focus_outline.gdshader`, applied by `Interactable._set_outline`).

## Feedback

- **Never silent.** Every press does something visible. When an action can't do anything here (nothing targeted, an empty socket with empty hands, an item that doesn't fit, ○ with nothing to go back from), the hands **shrug**: `get_tree().call_group("player_feedback", "shrug")`. Add the "unavailable" sound and a hint saying why when there is a reason to give.
- **First-person hands act things out** (`scenes/escape/fp_hands.gd`): the right hand (which holds items) reaches to use, place or take; the left waves when a conversation opens; both roll palms up, mirrored, to shrug.

## Highlighting choices

- **Options you can pick next are quiet**: a soft pulsing frame and a small half-clear marker (red to hit an enemy, gold for your own lanes, teal for playable cards; the bell pulses when it is the only move).
- **The one you're on is bold**: a solid, thicker white frame and a full-size marker. "What I'm on" must always stand out from "what I could pick" (`minigames/cards/card_actor.gd`).
- With a choice made, the controller focus visits **only legal targets**. If a choice has nowhere to go, say so (sound + hint) rather than doing nothing.

## Progress and reloading

- Never lose progress: minigames snapshot every few seconds; the save records the open room and the hall spot; Continue (and Pause → Relaunch game) puts the player back where they were.

## Style

- The Workshop is drawn with its ink kit (`minigames/workshop/ink.gd`): new things there, cursors included, use it.
- The hall uses the dark-teal/brass exhibit style (`ui/game_style.gd`, `ui/world_sign.gd`).

## Tests

- Drive controller input through `Input.parse_input_event` from **device 2**.
- Don't assume whether a pad is plugged into the machine running the tests: check `Input.get_connected_joypads()` when a label depends on it.
