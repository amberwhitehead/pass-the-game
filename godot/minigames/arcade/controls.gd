extends RefCounted
## Reads the arcade controls once per tick: keyboard (arrows / WASD, Z J Space fire,
## X K switch weapon, Shift V gear) and any gamepad (stick or d-pad, A fire, X / Y switch,
## shoulders gear, Start). Tests set `forced` to drive the game without real input.

var move := Vector2.ZERO
var fire := false
var switch_pressed := false
var gear_pressed := false
var start_pressed := false
## When not empty, replaces real input: {"move": Vector2, "fire": bool, "switch": bool,
## "gear": bool, "start": bool}. Edge-triggered keys fire once per change to true.
var forced := {}

var _was := {"switch": false, "gear": false, "start": false}


func read() -> void:
	var held := forced.duplicate() if not forced.is_empty() else _real()
	move = held.get("move", Vector2.ZERO)
	if move.length() > 1.0:
		move = move.normalized()
	fire = held.get("fire", false)
	switch_pressed = _edge("switch", held.get("switch", false))
	gear_pressed = _edge("gear", held.get("gear", false))
	start_pressed = _edge("start", held.get("start", false))


func _edge(key: String, now: bool) -> bool:
	var pressed: bool = now and not _was[key]
	_was[key] = now
	return pressed


static func _key(keys: Array) -> bool:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false


static func _pad(buttons: Array) -> bool:
	for d in Input.get_connected_joypads():
		for b in buttons:
			if Input.is_joy_button_pressed(d, b):
				return true
	return false


func _real() -> Dictionary:
	var m := Vector2(
		float(_key([KEY_RIGHT, KEY_D]) or _pad([JOY_BUTTON_DPAD_RIGHT])) - float(_key([KEY_LEFT, KEY_A]) or _pad([JOY_BUTTON_DPAD_LEFT])),
		float(_key([KEY_DOWN, KEY_S]) or _pad([JOY_BUTTON_DPAD_DOWN])) - float(_key([KEY_UP, KEY_W]) or _pad([JOY_BUTTON_DPAD_UP])))
	for d in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.3:
			m = stick
	return {
		"move": m,
		"fire": _key([KEY_Z, KEY_J, KEY_SPACE]) or _pad([JOY_BUTTON_A]) or _trigger(),
		"switch": _key([KEY_X, KEY_K]) or _pad([JOY_BUTTON_X, JOY_BUTTON_Y]),
		"gear": _key([KEY_SHIFT, KEY_V]) or _pad([JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]),
		"start": _key([KEY_ENTER, KEY_Z, KEY_J, KEY_SPACE]) or _pad([JOY_BUTTON_START, JOY_BUTTON_A]),
	}


static func _trigger() -> bool:
	for d in Input.get_connected_joypads():
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			return true
	return false
