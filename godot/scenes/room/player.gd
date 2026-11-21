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
	# What the crosshair is actually on wins: any part of an object (a stand's body, its
	# prism, either knob) picks that object, even when a neighbour's knob is nearer in
	# angle. Without a hit, the nearest in angle within the reach cone is used.
	var hit := _crosshair_hit(fwd)
	var on: Node = hit.get("collider")
	var on_best: Interactable = null
	var on_score := -INF
	for area in _reach.get_overlapping_areas():
		if area is Interactable and area.is_visible_in_tree() and not _frozen():
			var point: Vector3 = area.get_focus_position()
			var to: Vector3 = point - camera.global_position
			var dist := to.length()
			var facing := fwd.dot(to / maxf(dist, 0.001))
			var score := facing - dist * 0.025
			# Part of what the crosshair is on: its knob may sit round the side, a little
			# out of the cone or reach, and still be the one meant.
			var root: Node = area.outline_root()
			if on != null and (on == root or root.is_ancestor_of(on)) and dist <= reach + 0.6 \
					and score > on_score:
				on_best = area
				on_score = score
			if dist > reach or facing < reach_cone or not _can_see(area, point):
				continue
			if score > best_score:
				best = area
				best_score = score
	# It wins only if the hit is nearer that object's middle than the angle pick's own
	# point: so stand M beats stand D's nearby knob, while a small tray resting on a big
	# station's table stays the tray's.
	if on_best != null and best == null:
		best = on_best
	elif on_best != null and on_best != best:
		var at: Vector3 = hit.position
		var flat := func(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()
		var to_middle: float = flat.call(at, on_best.outline_root().global_position)
		if to_middle < ON_FOOTPRINT or to_middle < flat.call(at, best.get_focus_position()):
			best = on_best
	if best != target:
		if target:
			target.set_focused(false)
		target = best
		if target:
			target.set_focused(true)
		focus_changed.emit(target)


const ON_FOOTPRINT := 0.45  ## A hit this close to an object's middle is plainly on it.

## The first solid thing straight ahead of the crosshair within reach: the ray's hit
## ({collider, position, ...}), or {} for nothing.
func _crosshair_hit(fwd: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + fwd * reach, 1, [get_rid(), _reach.get_rid()])
	ray.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(ray)


func _can_see(area: Interactable, point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, [get_rid()])
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return true
	var collider: Node = hit.collider
	# A knob seen past its own stand's body still counts as seen: it's the same object.
	var root: Node = area.outline_root()
	return area.is_ancestor_of(collider) or collider == area or root.is_ancestor_of(collider) \
		or camera.global_position.distance_to(hit.position) + 0.18 >= camera.global_position.distance_to(point)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
		_r2_motion(event)
		return
	# A left click interacts while the mouse is looking around (E still works too).
	var click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION \
		and mouse_capture != null and mouse_capture.is_captured()
	var right_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.device != InputEvent.DEVICE_ID_EMULATION \
		and mouse_capture != null and mouse_capture.is_captured()
	if right_click or ((event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) \
			and event.is_action_pressed("secondary") and not event.is_echo()):
		_use_secondary()
		return
	if not (click or event.is_action_pressed("interact")) or event.is_echo():
		return
	if _frozen():
		return
	if Dialogue.last_closed_frame == Engine.get_process_frames():
		return  # same press that just closed a dialogue
	get_viewport().set_input_as_handled()
	if target == null:
		shrug()  # Nothing here to use.
		return
	reached.emit(target)
	target.interact(self)


## "You tried, but that does nothing here": the hands shrug (fp_hands.gd).
func shrug() -> void:
	get_tree().call_group("player_feedback", "shrug")


## A target's second action (right-click, R, R2 or □), e.g. taking a prism off its stand.
func _use_secondary() -> void:
	if _frozen() or Dialogue.last_closed_frame == Engine.get_process_frames():
		return
	get_viewport().set_input_as_handled()
	if target == null or target.secondary_prompt.is_empty():
		shrug()  # Nothing here has a second action.
		return
	reached.emit(target)
	target.secondary(self)



## R2 is analog. Read per event, with hysteresis, so a quick tap that goes up and back
## between two game ticks still counts (polling once per tick missed those), and a
## trigger resting around the threshold doesn't fire twice.
const R2_PRESS := 0.35
const R2_RELEASE := 0.15
var _r2_down := {}  ## device -> R2 counted as held


func _r2_motion(event: InputEventJoypadMotion) -> void:
	var down: bool = _r2_down.get(event.device, false)
	if not down and event.axis_value >= R2_PRESS:
		_r2_down[event.device] = true
		_use_secondary()
	elif down and event.axis_value <= R2_RELEASE:
		_r2_down[event.device] = false
