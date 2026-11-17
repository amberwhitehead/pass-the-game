extends RefCounted
## Playtest shortcut: Shift+L lights the trio and uses the ordinary victory path.

static func try_activate(game: Control, event: InputEvent) -> bool:
	if event is not InputEventKey or not event.pressed or event.echo:
		return false
	if not event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	if event.keycode != KEY_L and event.physical_keycode != KEY_L:
		return false
	if game._solved:
		return true
	game._grabbed = -1
	game._grab_hold = 0.0
	game._moving = false
	for index in game._pyramids.size():
		var pyramid: Dictionary = game._pyramids[index]
		pyramid.ok = true
		pyramid.cls = index
		pyramid.root = Vector2.from_angle(TAU * index / 3.0)
	game._update_win(game.HOLD_TO_WIN)
	game._refresh_visuals()
	return true
