class_name Player
extends CharacterBody3D
## First-person player. The body only turns about yaw; the child Camera pitches.
##
## Keyboard + mouse: the captured mouse looks, W/S walk, A/D strafe, ←/→ turn, Space jumps,
##            E/Enter/F interact. MouseCapture owns the cursor (and its click-to-continue card).
## Touch:     on-screen pad (▲▼ walk, ◀▶ turn, A interact) + drag anywhere else to look.
## Gamepad:   left stick walk/strafe, right stick look, D-pad walk/turn, A interact.

signal focus_changed(target: Interactable)
## The player has just used `target` (the first-person hands reach toward it).
signal reached(target: Interactable)

const MouseCapture := preload("res://scenes/room/mouse_capture.gd")
## Ignored while still held from a menu or modal, until released (see suppress_held_inputs).
const GAMEPLAY_ACTIONS := ["move_up", "move_down", "move_left", "move_right", "strafe_left",
	"strafe_right", "look_left", "look_right", "look_up", "look_down", "jump"]

@export var eye_height := 1.6     ## metres; camera height above the floor
@export var speed := 3.5          ## m/s on the ground, in any direction
@export var turn_speed := 2.0     ## rad/s, D-pad / arrow turning
@export var look_speed := 2.6     ## rad/s, right stick
@export var drag_sensitivity := 0.005  ## rad per pixel, touch drag-to-look
@export var mouse_sensitivity := 0.005  ## rad per screen pixel, captured mouse
@export var max_pitch := 1.0      ## rad up/down
@export var gravity := 20.0       ## m/s²; brisker than 9.8 so a hop feels snappy
@export var jump_height := 0.55   ## metres the feet rise from a standing jump
@export var air_acceleration := 8.0  ## m/s² of steering while airborne
@export var reach := 2.6          ## metres
@export var reach_cone := 0.75    ## min dot(forward, to_target); ~41 degrees

@onready var camera: Camera3D = $Camera
@onready var _reach: Area3D = $Reach

var target: Interactable = null
var mouse_capture: MouseCapture
var _look_finger := -1
var cinematic_locked := false
var interaction_locked := false
var _was_frozen := true  # The first tick treats anything already held as held over.
var _suppressed: Dictionary = {}  # action -> true while a press held over is still down


func _ready() -> void:
	camera.position.y = eye_height
	mouse_capture = MouseCapture.new()
	mouse_capture.configure(self)
	add_child(mouse_capture)
	PauseMenu.closed.connect(suppress_held_inputs)


func _frozen() -> bool:
	return cinematic_locked or interaction_locked or Sound.settings_open or Dialogue.active \
		or MiniGames.is_running() or (mouse_capture != null and mouse_capture.blocks_input())


## Keys and sticks still held when control returns (menu, dialogue, a recovery click)
## do nothing until released, so nothing pressed for a menu replays in the hall.
func suppress_held_inputs() -> void:
	for action: String in GAMEPLAY_ACTIONS:
		if Input.is_action_pressed(action):
			_suppressed[action] = true


func _strength(action: String) -> float:
	if _suppressed.has(action):
		if Input.is_action_pressed(action):
			return 0.0
		_suppressed.erase(action)
	return Input.get_action_strength(action)


func _axis(negative: String, positive: String) -> float:
	return _strength(positive) - _strength(negative)


func jump_speed() -> float:
	return sqrt(2.0 * gravity * jump_height)


func _physics_process(delta: float) -> void:
	var frozen := _frozen()
	if _was_frozen and not frozen:
		suppress_held_inputs()
		_look_finger = -1
	_was_frozen = frozen
	var walk := 0.0
	var strafe := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var jump := false
	if not frozen:
		walk = _axis("move_down", "move_up")
		strafe = _axis("strafe_left", "strafe_right")
		yaw = _axis("move_right", "move_left") * turn_speed - _axis("look_left", "look_right") * look_speed
		pitch = -_axis("look_up", "look_down") * look_speed
		_strength("jump")  # Clears a hold-over once Space is released.
		jump = Input.is_action_just_pressed("jump") and not _suppressed.has("jump")
		# R2 is an analog trigger, so it is read as a press here rather than per event.
		if Input.is_action_just_pressed("secondary") and _pad_secondary():
			_use_secondary()
	rotation.y += yaw * delta
	_pitch(pitch * delta)
	# Yaw-only axes: looking up or down never tilts or slows walking.
	var input := Vector2(strafe, walk).limit_length(1.0)
	var wish := Basis(Vector3.UP, rotation.y) * Vector3(input.x, 0.0, -input.y) * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var on_floor := is_on_floor()
	horizontal = wish if on_floor else horizontal.move_toward(wish, air_acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if on_floor:
		if jump:
			velocity.y = jump_speed()
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_update_target()


func _pitch(amount: float) -> void:
	camera.rotation.x = clampf(camera.rotation.x + amount, -max_pitch, max_pitch)


## One mouse or drag displacement, applied directly (never scaled by frame time).
func look(relative: Vector2, sensitivity: float) -> void:
	rotation.y -= relative.x * sensitivity
	_pitch(-relative.y * sensitivity)


## Captured mouse looks without a button. Drag-to-look is for real touches only: mouse
## drags also arrive as emulated touches, which would otherwise turn the view twice.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if mouse_capture.look_ready() and not _frozen():
			look(event.screen_relative, mouse_sensitivity)
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _look_finger == -1 and not _frozen() and not TouchControls.is_over_button(event.position):
				_look_finger = event.index
		elif event.index == _look_finger:
			_look_finger = -1
	elif event is InputEventScreenDrag and event.index == _look_finger and not _frozen():
		look(event.relative, drag_sensitivity)


func forward_flat() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _update_target() -> void:
	var best: Interactable = null
	var best_score := -INF
	var fwd := -camera.global_basis.z
	for area in _reach.get_overlapping_areas():
		if area is Interactable and area.is_visible_in_tree() and not _frozen():
			var point: Vector3 = area.get_focus_position()
			var to: Vector3 = point - camera.global_position
			var dist := to.length()
			if dist > reach:
				continue
			var facing := fwd.dot(to / maxf(dist, 0.001))
			if facing < reach_cone:
				continue
			if not _can_see(area, point):
				continue
			var score := facing - dist * 0.025
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


func _can_see(area: Interactable, point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, [get_rid()])
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return true
	var collider: Node = hit.collider
	return area.is_ancestor_of(collider) or collider == area \
		or camera.global_position.distance_to(hit.position) + 0.18 >= camera.global_position.distance_to(point)


func _unhandled_input(event: InputEvent) -> void:
	# A left click interacts while the mouse is looking around (E still works too).
	var click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION \
		and mouse_capture != null and mouse_capture.is_captured()
	var right_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.device != InputEvent.DEVICE_ID_EMULATION \
		and mouse_capture != null and mouse_capture.is_captured()
	if right_click or ((event is InputEventKey or event is InputEventAction) and event.is_action_pressed("secondary") and not event.is_echo()):
		_use_secondary()
		return
	if not (click or event.is_action_pressed("interact")) or event.is_echo():
		return
	if _frozen() or target == null:
		return
	if Dialogue.last_closed_frame == Engine.get_process_frames():
		return  # same press that just closed a dialogue
	get_viewport().set_input_as_handled()
	reached.emit(target)
	target.interact(self)


## A target's second action (right-click, R, or R2), e.g. taking a prism off its stand.
func _use_secondary() -> void:
	if _frozen() or target == null or target.secondary_prompt.is_empty():
		return
	if Dialogue.last_closed_frame == Engine.get_process_frames():
		return
	get_viewport().set_input_as_handled()
	reached.emit(target)
	target.secondary(self)


## True while the secondary action is held on a controller (not the keyboard's R, which
## arrives as an event in _unhandled_input).
func _pad_secondary() -> bool:
	for d in Input.get_connected_joypads():
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			return true
	return false
