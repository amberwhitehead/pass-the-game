extends Node
## Short, cancellable camera attention cue. No scene swap and no tree pause.

signal finished
signal caption(text: String)

const PAN_IN := 0.85
const HOLD := 1.65
const PAN_OUT := 0.85
var active := false
var _player: Player
var _pedestal: Node3D
var _npc: NPC
var _camera: Camera3D
var _saved_transform := Transform3D.IDENTITY
var _start_global := Transform3D.IDENTITY
var _target_global := Transform3D.IDENTITY
var _saved_fov := 65.0
var _target_fov := 58.0
var _saved_locked := false
var _saved_touch := true
var _elapsed := 0.0
var _reward_started := false


func configure(player: Player, pedestal: Node3D, npc: NPC = null) -> void:
	_player = player
	_pedestal = pedestal
	_npc = npc


func play() -> void:
	if active or not is_instance_valid(_player) or not is_instance_valid(_pedestal):
		return
	_camera = _player.camera
	_saved_transform = _camera.transform
	_start_global = _camera.global_transform
	_saved_fov = _camera.fov
	_saved_locked = bool(_player.get("cinematic_locked"))
	_saved_touch = TouchControls._enabled
	_player.set("cinematic_locked", true)
	_player._look_finger = -1
	_player.velocity.x = 0.0  # Horizontal only: a player in the air still lands.
	_player.velocity.z = 0.0
	TouchControls.set_enabled(false)
	_target_global = _start_global.looking_at(_pedestal.focus_point(), Vector3.UP)
	# A player may finish the station right beside the reward. Widen rather than
	# zoom into the two prisms; the camera remains at its collision-safe origin.
	var distance := _start_global.origin.distance_to(_pedestal.focus_point())
	_target_fov = clampf(rad_to_deg(2.0 * atan(1.35 / maxf(distance, 0.5))), 58.0, 82.0)
	_elapsed = 0.0
	_reward_started = false
	active = true
	if is_instance_valid(_npc):
		_npc._set_talking(true)
	caption.emit("Egyptian: Two prisms, as promised. Take them to the light in the main hall.")


func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_camera) or not is_instance_valid(_pedestal):
		_restore()
		return
	_elapsed += delta
	if not _reward_started and _elapsed >= 0.45:
		_reward_started = true
		_pedestal.reveal(true)
	var zoom_fov := _target_fov
	if _elapsed < PAN_IN:
		var t := _smooth(_elapsed / PAN_IN)
		_camera.global_transform = _start_global.interpolate_with(_target_global, t)
		_camera.fov = lerpf(_saved_fov, zoom_fov, t)
	elif _elapsed < PAN_IN + HOLD:
		_camera.global_transform = _target_global
		_camera.fov = zoom_fov
	elif _elapsed < PAN_IN + HOLD + PAN_OUT:
		var t := _smooth((_elapsed - PAN_IN - HOLD) / PAN_OUT)
		_camera.global_transform = _target_global.interpolate_with(_start_global, t)
		_camera.fov = lerpf(zoom_fov, _saved_fov, t)
	else:
		_restore()


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		cancel()


func cancel() -> void:
	if active:
		_restore()


func _restore() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(_pedestal):
		_pedestal.finish_reveal()
	if is_instance_valid(_camera):
		_camera.transform = _saved_transform
		_camera.fov = _saved_fov
	if is_instance_valid(_player):
		_player.set("cinematic_locked", _saved_locked)
		_player._look_finger = -1
	if is_instance_valid(_npc):
		_npc._set_talking(false)
	TouchControls.set_enabled(_saved_touch)
	finished.emit()


func _exit_tree() -> void:
	_restore()


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
