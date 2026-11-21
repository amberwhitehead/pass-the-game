extends "res://tests/test_suite.gd"
## The Workshop on a controller: the left stick's speed curve, A (Cross) clicking at the
## pad cursor through the real input path, from a pad in a later slot than 0 (Chrome put
## a DualSense in slot 2), B (Circle) closing the radio, and the mouse taking over again.

const PadPointer := preload("res://minigames/workshop/pad_pointer.gd")
const PAD := 2

var _checks := 0
var _failures := 0
var _game: Control
var _story: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The speed curve.
	_expect(PadPointer._velocity(Vector2(0.15, 0), Vector2.ZERO) == Vector2.ZERO, "A resting stick inside the deadzone doesn't drift")
	_expect(is_equal_approx(PadPointer._velocity(Vector2(1, 0), Vector2.ZERO).x, PadPointer.STICK_SPEED), "Full tilt moves at full speed")
	var half := PadPointer._velocity(Vector2(0, 0.6), Vector2.ZERO).y
	_expect(half > 0.0 and half < PadPointer.STICK_SPEED * 0.5, "Part tilt moves slower than in proportion, for aiming")
	_expect(is_equal_approx(PadPointer._velocity(Vector2.ZERO, Vector2(-1, 0)).x, -PadPointer.DPAD_SPEED), "The D-pad nudges slowly")

	Engine.time_scale = 8.0
	root.size = Vector2i(1280, 720)
	_game = load("res://minigames/workshop/workshop.tscn").instantiate()
	root.add_child(_game)
	_story = _game._story
	await _settle()
	_expect(not _game._pad.active, "The mouse drives the cursor until the pad is used")

	# Point at the radio with the pad and press A.
	var radio: Node2D = _story.world.things.radio
	var at: Vector2 = _game._stage.to_local(radio.to_global(radio.hit_rect.get_center()))
	_game._pad.activate()
	_game._pad.position = at
	await process_frame
	_expect(_game._stage_mouse() == at, "While the pad is in use, the scene points where its cursor is")
	_expect(_game._cursor.position.distance_to(at) < 0.5, "The drawn cursor follows the pad")
	_button(JOY_BUTTON_A)
	await _settle()
	_expect(_story.radio_open(), "A on the radio opens it up close")

	_button(JOY_BUTTON_B)
	await create_timer(0.5).timeout  # The close-up fades out before it hides.
	_expect(not _story.radio_open(), "B closes the radio")

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	Input.parse_input_event(motion)
	await process_frame
	_expect(not _game._pad.active, "Moving the mouse hands the cursor back to it")

	_game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("Workshop pad: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = PAD
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _settle() -> void:
	await process_frame
	var guard := 0
	while (_story.busy or _story.bubble.is_open()) and guard < 20000:
		_story.bubble.advance()
		_story.bubble.advance()
		await process_frame
		guard += 1
	_expect(guard < 20000, "A scene finished")


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
