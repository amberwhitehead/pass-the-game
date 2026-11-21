# The brothers' card tables

Two playable encounters share **room 3 — The Brothers**. The card stand and Little
Brother launch the three-lane tutorial. Talk to **Older Brother** on the other side
of the stand for the four-lane match. Both use the existing augmented character
model. Older Brother is directly accessible, but his starting matchup is intended
to be very difficult. Five collectible cards around the main hall strengthen the
player's deck without changing the opponent when a card is found.

## Play

Select a card in your hand, then click a highlighted lane. Creature cards need an
empty friendly lane; Bolt targets an enemy; Patch targets a wounded ally. Clicking
a selected hand card again, or pressing Esc, cancels selection. Ring the brass bell to resolve combat.
The duel uses a seated first-person view: cards, lane targets, draw pile, score
track and bell live on a 3D table, with Little Brother sitting opposite you.
Opening from the hub creates a live 3D window into the table. The hub camera moves
through its expanding frame while the destination camera follows the same motion.
The fullscreen handoff waits until the opening geometrically covers the viewport;
the camera then settles into the gameplay pose. Both worlds stay rendered during
the crossing. Rematches skip this entrance; Esc or the close button can interrupt
it. See `TRANSITION.md` for the rendering, camera and lifecycle contracts.
The camera sits close above the table so the lanes fill the view. Move toward the
bottom edge to raise your hand; move back toward the board to lower it. Selecting
a card also lowers the hand so it cannot block its target. On touch, tap the bottom
edge to reveal the hand, then tap a card and its target.
Hover a card to read its enlarged face; selecting a card also keeps its details
visible for touch play. The Journal button reveals the latest combat messages.

On a controller (any slot), the D-pad or left stick moves a focus between three rows:
his lanes, your lanes with the bell at their right end, and your hand (focusing the
hand raises it). The focused target gets the hover highlight and inspector. **A**
chooses it exactly as a click would; choosing a card jumps the focus to its first
legal target, and after a play it returns to the hand. **Y** rings the bell, **X**
opens the rules, and **B** cancels a pending swap or a selected card, closes a panel,
or opens the pause menu. In dialogs the D-pad moves between buttons and A presses.
Moving the mouse hands control back to it. The Journal and New match buttons are
mouse-only. `table_pad.gd` holds all of this; `table_view.gd` only exposes
`pad_active` and `activate(actor)`.

Little Brother's tutorial uses these rules:

- Three lanes; creatures remain in play and keep damage between turns.
- Attention starts at 2, refills to 3 on round two, and caps at 4 thereafter.
  Unspent Attention does not carry over.
- Your creatures attack left to right, including creatures just played. Blockers
  absorb the entire attack with no spillover damage or immediate retaliation.
- A soft glow shows the enemy's next destination lane, without revealing the card.
  The indicator can mark several lanes for future encounters with multiple plays.
- The younger brother deploys his planned card, then his surviving creatures
  attack left to right. His deterministic policy chooses exposed threats to block;
  it never reads your hand or changes a published plan during your turn.
- Unblocked damage moves one shared score: +10 wins, −10 loses.
- Draw one card per new round. The deck contains 16 cards and the hand holds eight.
  A draw into a full hand goes to discard. An exhausted deck causes increasing
  fatigue damage (1, then 2, then 3...). There is no discard recycling.
- Rules, restart confirmation, rematch, and return-to-room controls are included.
  Esc closes an open rules/restart dialog or cancels a pending swap; otherwise it
  opens the pause menu, which can leave the table. During the entrance and after
  the match is decided, Esc still leaves directly. Wins are saved, including when
  leaving with the close button. An unfinished match is kept as its seed, starting
  deck and actions, and replays through the rules on the next visit; if the replay
  no longer reproduces the saved snapshot (for example after a tuning change), a
  fresh match is dealt instead.

## Starter deck

| Card | Copies | Cost | Attack / health | Effect |
| --- | --- | --- | --- | --- |
| Scout | 3 | 1 | 1 / 2 | Basic inexpensive attacker |
| Striker | 3 | 2 | 2 / 2 | Fragile attacker |
| Guard | 2 | 1 | 0 / 5 | Durable blocker; does not attack |
| Heavy | 2 | 3 | 3 / 4 | Durable attacker |
| Medic | 2 | 2 | 1 / 3 | On play, heal each other ally by 1 |
| Bolt | 2 | 1 | — | Deal 2 damage to one enemy creature |
| Patch | 2 | 1 | — | Restore up to 2 health to one ally |

The opening hand is always Scout, Striker, Guard, Bolt. The remaining cards use a
seeded shuffle, with a new seed on rematch. The first opponent plan is a Guard in
the middle lane. This is deliberately a forgiving first opponent, not final balance.

## Older Brother and discoveries

- Four lanes, a visible prepared enemy board, and a finite opponent reserve.
  The rules panel shows the encounter's current victory threshold and Attention
  progression. Opponent pressure is configured in `match_encounter.gd`.
- Every deal opens with **five cards**: **Bruiser, Forkshot, Sentinel**, then
  **two random draws** from the shuffled remainder. The opening size stays five
  at every collection level; discoveries can appear naturally in the two random
  slots or be drawn on later turns.
- The base deck has **12 cards**: three Bruisers, two Forkshots, one Sentinel,
  one Defender, two Bolts, two Patches, and one Switcheroo. Each discovery adds
  one card, for **12 + k** cards total and **7 + k** left after the opening deal.
  Draw one card per round. The hand limit remains eight. The shuffle treats
  discoveries like the other cards in the draw pile.
- Bruiser is 2/6 and Defender is 1/8. Existing starter-card stats stay consistent.
- Sentinel is 0/8, costs 2, and moves into an adjacent empty lane immediately
  before a creature attack hits it. Once per opposing attack phase; the leftmost
  eligible Sentinel reacts first. It stays in its new lane. Spells do not trigger it.
- Forkshot is 1/6, costs 3, and attacks the two diagonal lanes, left then right.
  It never attacks straight ahead and has one target at the edge.
- Switcheroo costs 1: select an occupied friendly lane, then an occupied adjacent
  lane. Damage, identity and interception readiness move with the creatures. Invalid
  targets cost nothing. Clicking the first creature again or pressing Esc clears
  that choice; selecting another card also cancels it.
- The older brother's prepared creatures are paid from his finite reserve. He
  deploys one announced card per turn using only visible board information. A
  blocked advertised lane delays
  deployment without consuming a card or changing the advertised target mid-turn.
- Both sides suffer increasing fatigue after exhausting their deck/reserve.
  Hover previews explain diagonal attacks and ready Sentinel coverage without
  exposing an unpublished enemy card. Interception and swapping animate physically.

The five discoveries are **Champion**, **Aegis**, **Tempest**, **Renewal**, and
**Thunderbolt**: an attacker, an interceptor, a diagonal attacker, a healing spell,
and a damage spell. Their names, artwork, and exact tuning can evolve independently
of their stable card IDs. Printed effect numbers come from the card definitions.

Look along the main hall's server racks and service shelves. Pickups need no
puzzle gate and join the deck directly; they do not occupy or replace the single
carried prism/lens slot. A collected card disappears from its display. Duplicate
collection is ignored, and the next deal reads the current collection. A duel in
progress cannot gain cards mid-turn.

Collection persists across leaving the table, returning to the hall, rematching,
and relaunching: found cards are part of the saved game. Little Brother always uses
his original tutorial deck. The older table shows `N / 5 found`; loss dialogue
points toward a missing card rather than requiring a fixed discovery order.

This twelve-card version is a **human-playtest baseline**, chosen before another
simulation balance sweep. The intended difficulty curve remains very hard with
no discoveries and very easy with all five; current bot studies do not establish
that curve for this smaller shuffled deck. Card and opponent stats retain the
previous tuning so playtesting can isolate the new deck and dealing rules. The
findings in `../../simulation/cards/` are dated evidence for earlier configurations.
When returning to simulation, compare all 32 subsets and include human feedback.

## Code boundaries

- `card_catalog.gd`: card definitions and deck composition.
- `deck_progression.gd`: unique discovery IDs, three core opening creatures, and
  additive deck construction.
- `match_config.gd`: validated match-local tuning and `collected_cards` resolution.
- `match_rules.gd`: deterministic state and action legality; independent event snapshots.
- `match_encounter.gd`: per-brother tuning, opening board and reserves.
- `match_combat.gd`: scheduled combat, interception and diagonal targeting.
- `match_ai.gd`: deterministic placement from public information.
- `cards.gd`: input, event playback, feedback and completion through `MiniGame`.
- `encounter_text.gd`: per-brother rules, banter and result text.
- `../../scenes/escape/card_cache.gd` / `card_pickup.gd`: hall placements, pickup
  feedback, and direct collection through `Game.collect_card`.
- `table_view.gd`: perspective camera, board/hand layout, state rendering and
  physics-ray input routing.
- `table_world.gd`: room, lighting and seated opponent.
- `table_layout.gd`: shared three-/four-lane coordinates.
- `table_preview.gd`: visible-card attack and interception paths.
- `table_craft.gd` / `table_surface.gdshader`: bevelled furniture, walnut, felt and brass details.
- `table_accessories.gd`: balance instrument, score marker and draw pile.
- `table_attention.gd`: physical Attention counter, with remaining/total text and
  brass diamond tokens that recess when spent and rise when replenished.
- `table_handoff.gd`: live hub/table camera mapping, warmup and coverage-gated handoff.
- `table_portal.gd` / `.gdshader`: physical aperture and screen-projected live texture.
- `hub_camera_state.gd`: exact caller camera, HUD, pause and touch-state restoration.
- `table_entrance.gd`: fallback entrance for running the card scene directly without a hub.
- `table_hand.gd`: camera-relative hand layout, reveal/retreat and selection.
- `table_pad.gd`: controller focus over lanes, bell and hand; A/Y/X/B handling.
- `lane_intent.gd`: anonymous destination glows; accepts one or several plans.
- `card_actor.gd`, `table_button.gd`: physical card and bell targets. Card-face
  textures redraw only when their contents change.
- `table_effects.gd`: dealing, attacks, spells, healing and damage animations.
- `table_motion.gd`: scene-owned motion with transform restoration and exit cancellation.
- `table_hud.gd`: status, card inspection and collapsible combat log.
- `card_face.gd` / `card_typography.gd`: shared printed face and bounded text fitting.
- `card_view.gd`, `card_ui.gd`, `table_dialog.gd`: reusable 2D presentation pieces.

Run the rule, scene and spatial-input checks documented in `../../tests/README.md`. A source
playtest can launch directly with:

```sh
godot --path godot res://minigames/cards/cards.tscn
```

## Deliberately deferred

Deck editing, friend-group themes and final artwork. Mouse/touch
is the primary input for this prototype.

Useful playtest feedback: is a turn understandable; does the enemy intent help;
are blocking, healing and spells worth using; does the score feel fair; and does
the match end before the basic cards become repetitive?

## Card artwork and face design

`card_face.gd` draws both the physical card texture and enlarged inspector using
one 384 × 512 composition: title/cost, art window, rules, and separate statistics.
Creature health shows current/maximum when injured; wounded values use red.
Spells have target and effect labels rather than creature attack/health.

Supply `art_path` in a card definition (a `res://` texture path), or an `art`
Texture2D for programmatic cards. The art window is 330 × 184 pixels in the
logical layout, approximately 16:9. Images fill it with a centered crop; keep
important faces/features away from the edge. Title, cost and rules are drawn
separately, so deliver artwork without baked-in lettering. Until artwork is
provided, the frame shows a restrained monogram field.

Faces redraw on content/highlight changes, not every frame. Empty lanes reveal
the table's actual mats, while keeping their physics targets. Name fitting and
rules wrapping share the same helper in both views. All starter descriptions fit
in full; future copy that exceeds three lines is ellipsized and should be shortened
before shipping the card.
