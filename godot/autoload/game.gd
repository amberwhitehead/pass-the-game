extends Node
## Global game state + input map registration.
## Actions are registered in code so the on-screen buttons, keyboard and
## (later) gamepad all drive the same names.

signal flag_changed(flag: String, value: Variant)

var flags: Dictionary = {}
var completed_minigames: Dictionary = {}  # id -> best result Dictionary


func _ready() -> void:
	# The built-in font lacks arrows, ▲▼◀▶, ✕, minus and superscripts (and web builds have no
	# system fonts to fall back on), so ship DejaVu Sans as the default and the fallback.
	ThemeDB.fallback_font = load("res://assets/fonts/DejaVuSans.ttf")
	_register_actions()


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


## Actions (all devices feed the same names):
##   move_up/down     walk forward/back     (W/S, ↑/↓, left stick Y, D-pad)
##   move_left/right  turn left/right       (A/D, arrows, D-pad)
##   strafe_left/right sidestep             (gamepad left stick X only)
##   look_*           look around           (right stick)
##   interact / back                        (E/Space/Enter/F, pad A) / (Esc/Backspace, pad B)
## Touch: on-screen pad buttons + drag-to-look (see TouchControls / Player).
func _register_actions() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_F],
		"back": [KEY_ESCAPE, KEY_BACKSPACE],
	}
	var pad_buttons := {
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"interact": [JOY_BUTTON_A],
		"back": [JOY_BUTTON_B],
	}
	# [action, axis, direction]
	var pad_axes := [
		["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0],
		["strafe_left", JOY_AXIS_LEFT_X, -1.0], ["strafe_right", JOY_AXIS_LEFT_X, 1.0],
		["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
		["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0],
	]
	for action in ["look_left", "look_right", "look_up", "look_down", "strafe_left", "strafe_right"]:
		_ensure(action)
	for action: String in keys:
		_ensure(action)
		for key: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	for action: String in pad_buttons:
		for btn: int in pad_buttons[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = btn as JoyButton
			InputMap.action_add_event(action, ev)
	for a: Array in pad_axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[1] as JoyAxis
		ev.axis_value = a[2]
		InputMap.action_add_event(a[0], ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
