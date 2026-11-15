class_name Player
extends CharacterBody3D
## First-person player. Eye-level camera is a child of this body.
##
## Touch:     on-screen pad (▲▼ walk, ◀▶ turn, A interact) + drag anywhere else to look.
## Keyboard:  W/S or ↑/↓ walk, A/D or ←/→ turn, E/Space/Enter/F interact.
##            (mouse: click-drag to look, same as touch)
## Gamepad:   left stick walk/strafe (strafe is stick-only), right stick look, D-pad walk/turn, A interact.

signal focus_changed(target: Interactable)

@export var eye_height := 1.6     ## metres; camera height above the floor
@export var speed := 3.5
@export var turn_speed := 2.0     ## rad/s, D-pad / arrow turning
@export var look_speed := 2.6     ## rad/s, right stick
@export var drag_sensitivity := 0.005  ## rad per pixel
@export var max_pitch := 1.0      ## rad up/down
@export var reach := 2.6          ## metres
@export var reach_cone := 0.75    ## min dot(forward, to_target); ~41 degrees

@onready var camera: Camera3D = $Camera
@onready var _reach: Area3D = $Reach

var target: Interactable = null
var _look_finger := -1


func _ready() -> void:
	camera.position.y = eye_height


func _frozen() -> bool:
	return Dialogue.active or MiniGames.is_running()


func _physics_process(delta: float) -> void:
	var walk := 0.0
	var strafe := 0.0
	var yaw := 0.0
	var pitch := 0.0
	if not _frozen():
		walk = Input.get_axis("move_down", "move_up")
		strafe = Input.get_axis("strafe_left", "strafe_right")
		yaw = Input.get_axis("move_right", "move_left") * turn_speed \
			- Input.get_axis("look_left", "look_right") * look_speed
		pitch = -Input.get_axis("look_up", "look_down") * look_speed
	rotation.y += yaw * delta
	_pitch(pitch * delta)
	var move := -global_transform.basis.z * walk + global_transform.basis.x * strafe
	move.y = 0.0
	velocity = move.limit_length(1.0) * speed
	move_and_slide()
	_update_target()


func _pitch(amount: float) -> void:
	camera.rotation.x = clampf(camera.rotation.x + amount, -max_pitch, max_pitch)


## Drag-to-look: a finger that starts on empty screen (not on a pad button)
## steers the camera. Mouse drags arrive here too (touch emulation).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _look_finger == -1 and not _frozen() and not TouchControls.is_over_button(event.position):
				_look_finger = event.index
		elif event.index == _look_finger:
			_look_finger = -1
	elif event is InputEventScreenDrag and event.index == _look_finger and not _frozen():
		rotation.y -= event.relative.x * drag_sensitivity
		_pitch(-event.relative.y * drag_sensitivity)


func forward_flat() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _update_target() -> void:
	var best: Interactable = null
	var best_score := -INF
	var fwd := forward_flat()
	for area in _reach.get_overlapping_areas():
		if area is Interactable:
			var to: Vector3 = area.global_position - global_position
			to.y = 0.0
			var dist := to.length()
			if dist > reach:
				continue
			var facing := fwd.dot(to / maxf(dist, 0.001)) if dist > 0.5 else 1.0
			if facing < reach_cone:
				continue
			var score := facing - dist * 0.15
			if score > best_score:
				best = area
				best_score = score
	if best != target:
		if target:
			target.set_focused(false)
		target = best
		if target:
			target.set_focused(true)
		focus_changed.emit(target)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _frozen() or target == null:
		return
	if Dialogue.last_closed_frame == Engine.get_process_frames():
		return  # same press that just closed a dialogue
	get_viewport().set_input_as_handled()
	target.interact(self)
