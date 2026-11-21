extends Node
## Controller play at the card table: a focus that steps between the table's targets.
##
## Rows, top to bottom: his lanes, your lanes with the bell at their right end, your hand.
## D-pad or left stick moves the focus (held, it repeats), A chooses what is focused
## (exactly as clicking it would), Y rings the bell, X opens the rules, and B is the
## table's usual back (cancel a swap or a selected card, close a panel, or the menu).
## Focus shows as the same highlight and card inspector the mouse's hover uses; moving
## the mouse hands control back to it. Dialogs use their own buttons: the D-pad moves
## between them and A presses (Godot's ui_* actions). Any connected pad works.

const STICK := 0.5           ## Stick deflection that counts as a direction.
const FIRST_REPEAT := 0.38   ## Seconds before a held direction repeats...
const REPEAT := 0.14         ## ...and between repeats.
const ENEMY := 0
const PLAYER := 1
const HAND := 2

var game: Node   ## The cards MiniGame: its selection, dialog and busy state.
var table: Control
var row := HAND
var index := 0
var _held := Vector2i.ZERO
var _repeat_in := 0.0
var _was_idle := false
var _dpad := {}    ## device -> Vector2i of D-pad buttons down
var _sticks := {}  ## device -> Vector2 left stick


func configure(cards_game: Node, table_view: Control) -> void:
	game = cards_game
	table = table_view


func _input(event: InputEvent) -> void:
	_track_direction(event)
	if not event is InputEventJoypadButton or not event.pressed or Sound.settings_open:
		return
	if is_instance_valid(game._dialog):
		# The dialog's buttons take A and the D-pad; make sure one of them has focus.
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT] \
				and not _dialog_has_focus():
			game._dialog.focus_first()
			get_viewport().set_input_as_handled()
		return
	match event.button_index:
		JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			if _idle():
				_wake()
				_activate(_actor())
		JOY_BUTTON_Y:
			get_viewport().set_input_as_handled()
			if _idle():
				_wake()
				row = PLAYER
				index = table.lane_count
				_activate(table.end_button)
		JOY_BUTTON_X:
			get_viewport().set_input_as_handled()
			game._show_rules()


func _process(delta: float) -> void:
	var idle := _idle()
	if idle and not _was_idle and table.pad_active:
		_after_action()
	_was_idle = idle
	# A new direction steps as its event arrives (_direction_changed); held, it repeats.
	if _held != Vector2i.ZERO and _can_navigate():
		_repeat_in -= delta
		if _repeat_in <= 0.0:
			_repeat_in = REPEAT
			_step(_held)
	if table.pad_active:
		_show_focus()


func _can_navigate() -> bool:
	return _idle() and not is_instance_valid(game._dialog) and not Sound.settings_open


func _direction_changed() -> void:
	var dir := direction()
	if dir == _held:
		return
	_held = dir
	_repeat_in = FIRST_REPEAT
	# A direction held through a dialog or animation waits for the next press.
	if dir != Vector2i.ZERO and _can_navigate():
		_step(dir)


## True when the table is waiting for the player: no entrance, animation or result.
func _idle() -> bool:
	return not game._busy and not game._entering and game._shown.get("winner", "") == "" \
		and not table.locked


## The first pad press takes over from the mouse at a sensible starting point.
func _wake() -> void:
	if table.pad_active:
		return
	table.pad_active = true
	table.hint.text = "Controller: D-pad or stick to move, A to choose, Y rings the bell, X for rules, B to cancel."
	if game._selected >= 0:
		_focus_first_target()
	elif _hand_size() > 0:
		row = HAND
		index = clampi(index, 0, _hand_size() - 1)
	else:
		row = PLAYER
		index = table.lane_count


func _step(dir: Vector2i) -> void:
	# A table button the mouse last clicked would otherwise also take the D-pad.
	get_viewport().gui_release_focus()
	if not table.pad_active:
		_wake()
		_show_focus()
		return
	if dir.y != 0:
		_change_row(row + dir.y)
	elif dir.x != 0:
		index = clampi(index + dir.x, 0, _row_size(row) - 1)
	Sound.play("card_hand", game, 0, .6)


func _change_row(target: int) -> void:
	target = clampi(target, ENEMY, HAND)
	if target == HAND and _hand_size() == 0:
		return
	if target == row:
		return
	var from_x := _column_fraction(row, index)
	row = target
	var count := _row_size(row)
	if row == PLAYER and from_x > 1.0:
		index = table.lane_count  # Keep the bell when coming back down from the hand's end.
	else:
		var lanes := count - (1 if row == PLAYER else 0)
		index = clampi(roundi(clampf(from_x, 0.0, 1.0) * (lanes - 1)), 0, count - 1)


## Where in its row the focus sits, from 0 (left) to 1 (right); the bell is past 1.
func _column_fraction(r: int, i: int) -> float:
	if r == PLAYER and i >= table.lane_count:
		return 1.5
	var n: int = table.lane_count if r != HAND else _hand_size()
	return 0.5 if n <= 1 else float(i) / float(n - 1)


func _row_size(r: int) -> int:
	match r:
		ENEMY: return table.lane_count
		PLAYER: return table.lane_count + 1  # The bell.
	return maxi(1, _hand_size())


func _hand_size() -> int:
	return table.hand_cards.size()


func _actor() -> Node3D:
	match row:
		ENEMY: return table.slot("enemy", index)
		PLAYER: return table.end_button if index >= table.lane_count else table.slot("player", index)
	if index < _hand_size():
		return table.hand_cards[index]
	return null


func _activate(actor: Node3D) -> void:
	if actor == null:
		return
	var was_selected: int = game._selected
	table.activate(actor)
	# Choosing a card sends the focus to its first legal target.
	if row == HAND and game._selected >= 0 and game._selected != was_selected:
		_focus_first_target()


func _focus_first_target() -> void:
	for side in ["player", "enemy"]:
		for lane in table.lane_count:
			if table._eligible(side, lane):
				row = PLAYER if side == "player" else ENEMY
				index = lane
				return


## After a play or a turn resolves, return to the hand (or the bell if it is empty).
func _after_action() -> void:
	if game._selected >= 0:
		return
	if _hand_size() > 0:
		index = clampi(index if row == HAND else 0, 0, _hand_size() - 1)
		row = HAND
	else:
		row = PLAYER
		index = table.lane_count


func _show_focus() -> void:
	if not _idle():
		return
	if row == HAND and _hand_size() == 0:
		row = PLAYER
		index = table.lane_count
	index = clampi(index, 0, _row_size(row) - 1)
	table.hand.set_expanded(row == HAND)
	var actor := _actor()
	if actor != table._hovered:
		table._set_hover(actor)


func _dialog_has_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and game._dialog.is_ancestor_of(owner)


## Keeps the latest D-pad and left-stick state per pad, from events, so any pad in any
## slot works (and synthetic events drive it in tests).
func _track_direction(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var step := Vector2i.ZERO
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: step = Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT: step = Vector2i.RIGHT
			JOY_BUTTON_DPAD_UP: step = Vector2i.UP
			JOY_BUTTON_DPAD_DOWN: step = Vector2i.DOWN
			_: return
		var held: Vector2i = _dpad.get(event.device, Vector2i.ZERO)
		if event.pressed:
			held = step  # The newest press wins; one direction at a time.
		elif (step.x != 0 and held.x == step.x) or (step.y != 0 and held.y == step.y):
			held = Vector2i.ZERO
		_dpad[event.device] = held
		_direction_changed()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var stick: Vector2 = _sticks.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X:
			stick.x = event.axis_value
		else:
			stick.y = event.axis_value
		_sticks[event.device] = stick
		_direction_changed()


## The direction being held on any pad: a D-pad press, else the stick past STICK on its
## stronger axis.
func direction() -> Vector2i:
	for d in _dpad:
		if _dpad[d] != Vector2i.ZERO:
			return _dpad[d]
	for d in _sticks:
		var v: Vector2 = _sticks[d]
		if v.length() >= STICK:
			return Vector2i(int(signf(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, int(signf(v.y)))
	return Vector2i.ZERO
