extends Node
## Continuous handwheel input with a magnetic detent. Raw motion stays independent
## from the snapped output, so a player can pull out of a detent without getting stuck.

signal adjusted(angle: float, snapped: bool)
signal finished(id: String)

const CAPTURE := deg_to_rad(4.0)
const RELEASE := deg_to_rad(6.0)
const TURN_SPEED := deg_to_rad(68.0)
const DRAG_SPEED := 0.0055
var active_id := ""
var raw_angle := 0.0
var angle := 0.0
var snapped := false
var targets: Array[float] = []
var _detent := NAN
var _player: Node
var _previous_lock := false
var _finger := -1
var _started_frame := -1


func configure(player: Node) -> void:
	_player = player


func begin(id: String, initial: float, snap_targets: Array[float]) -> void:
	if not active_id.is_empty():
		finish()
	active_id = id
	raw_angle = initial
	angle = initial
	targets = snap_targets.duplicate()
	_detent = NAN
	_started_frame = Engine.get_process_frames()
	if is_instance_valid(_player):
		_previous_lock = bool(_player.interaction_locked)
		_player.interaction_locked = true
		_player._look_finger = -1
		# Stop walking, but let a player who grabbed the wheel mid-jump land.
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
	_apply_detent()


func finish() -> void:
	if active_id.is_empty():
		return
	var id := active_id
	active_id = ""
	_finger = -1
	if is_instance_valid(_player):
		_player.interaction_locked = _previous_lock
		_player._look_finger = -1
	finished.emit(id)


func nudge(delta_angle: float) -> void:
	if active_id.is_empty():
		return
	raw_angle = wrapf(raw_angle + delta_angle, -PI, PI)
	_apply_detent()


func _apply_detent() -> void:
	if not is_nan(_detent) and absf(angle_difference(raw_angle, _detent)) > RELEASE:
		_detent = NAN
	if is_nan(_detent):
		var closest := CAPTURE
		for target in targets:
			var distance := absf(angle_difference(raw_angle, target))
			if distance < closest:
				closest = distance
				_detent = target
	snapped = not is_nan(_detent)
	angle = _detent if snapped else raw_angle
	adjusted.emit(angle, snapped)


func _process(delta: float) -> void:
	if active_id.is_empty():
		return
	if MiniGames.is_running() or Dialogue.active:
		finish()
		return
	if Sound.settings_open:
		return
	# A/D are strafe in the hall; while the player is locked to the wheel they turn it too.
	var input := Input.get_axis("move_right", "move_left") + Input.get_axis("strafe_right", "strafe_left") \
		+ Input.get_axis("look_right", "look_left")
	if absf(input) > 0.01:
		var fine := 0.3 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		nudge(clampf(input, -1, 1) * TURN_SPEED * fine * delta)


func _input(event: InputEvent) -> void:
	if active_id.is_empty() or Sound.settings_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not TouchControls.is_over_button(event.position):
			_finger = event.index
		elif event.index == _finger:
			_finger = -1
	elif event is InputEventScreenDrag and event.index == _finger:
		nudge(-event.relative.x * DRAG_SPEED)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if active_id.is_empty() or event.is_echo():
		return
	if Engine.get_process_frames() == _started_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		finish()


func _exit_tree() -> void:
	finish()
