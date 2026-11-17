extends RefCounted
## Owns the hub state borrowed by a cinematic; restoring it is safe more than once.
## Capture before pausing or hiding anything. Camera-only restore is safe mid-game.

var _camera: Camera3D
var _camera_state: Dictionary = {}
var _hud_layers: Array[Dictionary] = []
var _tree: SceneTree
var _touch: Node
var _touch_enabled := true
var _was_paused := false
var _captured := false
var _restored := false


func capture(source_camera: Camera3D, room: Node) -> void:
	_camera = source_camera
	_camera_state.clear()
	_hud_layers.clear()
	_restored = false
	var context: Node = room if is_instance_valid(room) and room.is_inside_tree() else source_camera
	_captured = is_instance_valid(context) and context.is_inside_tree()
	if not _captured:
		return
	_tree = context.get_tree()
	_was_paused = _tree.paused
	_touch = _tree.root.get_node_or_null("TouchControls")
	if is_instance_valid(_touch):
		# This is the scene-level switch; the input-device fade state remains live.
		_touch_enabled = bool(_touch.get("_enabled"))
	if is_instance_valid(_camera):
		_camera_state = {
			"transform": _camera.global_transform,
			"fov": _camera.fov,
			"current": _camera.current,
			"keep_aspect": _camera.keep_aspect,
			"frustum_offset": _camera.frustum_offset,
			"near": _camera.near,
			"far": _camera.far,
			"projection": _camera.projection,
			"size": _camera.size,
			"h_offset": _camera.h_offset,
			"v_offset": _camera.v_offset,
		}
	if is_instance_valid(room):
		# Only room-owned UI: do not hide Dialogue, TouchControls or MiniGames.
		for child: Node in room.get_children():
			if child is CanvasLayer:
				_hud_layers.append({"layer": child, "visible": child.visible})


func hide_hud() -> void:
	for entry: Dictionary in _hud_layers:
		if is_instance_valid(entry.layer):
			entry.layer.visible = false


func restore_camera() -> void:
	if not _captured or not is_instance_valid(_camera) or _camera_state.is_empty():
		return
	_camera.projection = _camera_state.projection
	_camera.keep_aspect = _camera_state.keep_aspect
	_camera.frustum_offset = _camera_state.frustum_offset
	_camera.near = _camera_state.near
	_camera.far = _camera_state.far
	_camera.size = _camera_state.size
	_camera.fov = _camera_state.fov
	_camera.h_offset = _camera_state.h_offset
	_camera.v_offset = _camera_state.v_offset
	_camera.global_transform = _camera_state.transform
	_camera.current = _camera_state.current


func restore_hud() -> void:
	for entry: Dictionary in _hud_layers:
		if is_instance_valid(entry.layer):
			entry.layer.visible = entry.visible


func restore() -> void:
	if not _captured or _restored:
		return
	_restored = true
	restore_camera()
	restore_hud()
	if is_instance_valid(_touch):
		_touch.set_enabled(_touch_enabled)
	if is_instance_valid(_tree):
		_tree.paused = _was_paused
