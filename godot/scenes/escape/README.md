# Refraction Hall

The main room now hosts the optical connector puzzle. The existing station games
and their NPCs occupy six small square chambers with real walkable doorways.
Egypt (01) starts open; its first win reveals two portable prisms. Completing the
beam route opens Roman Flow (02). Little Brother (03) remains accessible; the
three unimplemented stations retain their original placeholder interactions.

## Playing

Look with the mouse, walk with W/S, strafe with A/D, turn with the arrows, and jump
with Space (touch: drag to look). Press E (gamepad A)
on the highlighted control. Aim at LIFT / PLACE to exchange a carried object and
at TURN to engage a mounted prism's handwheel. Drag horizontally, use A/D or
left/right arrows, or use the right stick to rotate continuously. E/gamepad A or
Escape releases the wheel. The body and camera remain still while adjusting.
Empty sockets transmit the beam straight.

Only one item is held. Compatible occupied mounts exchange items atomically;
empty matching mounts and reward cradles provide storage. No dedicated swap tray
is needed. Nothing is consumed or freely dropped. Lens mounts accept lenses, prism sockets accept
prisms, and reward cradles accept prisms. Incompatible actions preserve both items.

Egypt's first win triggers a 3.35-second camera turn and return, a rising reward
pedestal with a warm light pulse, and an Egyptian caption/talking animation.
Escape skips the presentation and leaves both rewards accessible. Replays never
refill the cradles. Camera pose, FOV and prior control state are restored exactly.

## Puzzle rules

The ceiling source feeds the installed starting prism vertically, so it can
rotate continuously while still bending light by 90 degrees. It snaps within
4 degrees of a hardware heading, releasing beyond 6 degrees to prevent jitter.
Portable prism inlets must align with the arriving ray; their two valid exits are
perpendicular to it. A misaligned inlet stops the beam at the prism.
Yellow and blue make green in either order, using the agreed magical color rule.
All horizontal optics share the same height; a solid relay cabinet blocks the
longer apparent route. The installation occupies the east side of the hall;
the receiver is attached to the north jamb of Door 2. The center remains open for
later escape-room puzzles.

The canonical layout is documented in `../../../docs/prism-layout.md`. Its map
coordinates become world coordinates `(3.58+x*0.72, 1.25, -1.72-y*0.72)`.

Spoiler: put prisms in A/B, move the lenses into L/M, aim S toward the upper
sockets, and turn B toward the receiver. C/D can produce green but the engine
blocks delivery. The receiver permanently unlocks Door 2 on the first success;
removing pieces afterward does not trap the player.

## Module boundaries

- `hub_architecture.gd`, `hub_geometry.gd`, `escape_door.gd`: chamber geometry,
  placements, shared materials/tiles and the physical gate. `hub_meshes.gd`,
  `hub_details.gd` and `hub_surface.gdshader` supply cached bevels, batched server
  fittings/conduits, and procedural metal detail.
- `brothers_room.gd`: the card parlor's entrance and composition;
  `brothers_chamber.gd` builds the paneled shell, batched walnut floorboards and
  felt runner; `brothers_decor.gd` supplies lamps, cabinets and lane emblems.
  These reuse the card table's `table_craft.gd` materials. The original brothers
  keep their models, positions and interactions. `../room/brothers_station.gd`
  replaces Challenge 3's orb with a physical card stand while retaining the
  existing challenge ID, completion handling and tutorial rematches.
- `optics_model.gd`: deterministic point-optics trace, color rules and state.
- `optics_controller.gd`: world composition, inventory exchanges and solve events.
- `optics_aiming.gd`: continuous input, angular snapping and player-control lifecycle.
- `optics_device.gd`, `optics_handle.gd`, `optics_art.gd`, `optics_beams.gd`:
  physical controls and rendering. Beam meshes/materials are pooled during aiming;
  `optics_hardware.gd` builds the door receiver and relay cabinet.
- `carry_inventory.gd`, `carry_slot.gd`, `carry_visual.gd`: one-item ownership,
  compatible exchanges, reward cradles and the object held in view.
- `reward_pedestal.gd`, `reward_reveal.gd`: reward contents, animation and camera
  lifecycle. The reveal does not pause or replace the room.
- `hub_hud.gd`: carry state, objective and interaction/caption feedback.
- `../room/room.gd`: composition and minigame/progression connections.

Placements, held item, remaining rewards and the unlocked door are preserved in
`Game` flags across minigames and room recreation within the running session.
There is not yet a disk/browser save system; restarting the page starts fresh.
NPC speech here is an animated text caption, with no recorded voice assets yet.

The player now targets actual 3D interaction positions and checks wall occlusion,
so separate controls can be selected and sealed rooms cannot be used through walls.

## Verification

See `../../tests/README.md`. The optics model enumerates all 3,465 configured
source/turn/lens/placement combinations and admits exactly the two interchangeable
lens orders on A/B. Scene tests cover exchanges, camera cancellation/restoration,
reward duplication, physical openings/locks and conservation after room recreation.
Human playtesting still determines whether the lens relocation insight is clear.

## Easter egg room (spoiler)

`secret_room.gd` lines the hall's east and west walls with a few plain service panels.
Three are inert cladding (meshes only, no prompt or collision of their own). The one
on the east wall near the south-east corner has a recessed latch on a rubbed-bright
patch; it offers "Open service panel" and moves the player to a small empty room 6 m
below the hall, whose labelled panel returns them to where they stood. The room is
left for future developers: build inside `SecretRoom.room` (origin = its floor
centre). Visits are not saved. Covered by `secret_room_test`.
