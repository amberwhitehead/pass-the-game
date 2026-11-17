extends Control
## Two live worlds with a projection-continuous handoff through a physical aperture.
signal completed
signal handoff
const Portal := preload("res://minigames/cards/table_portal.gd")
const PUSH_DURATION := 2.2
const SETTLE_DURATION := 0.28
const TRAVEL := 2.05
var phase := "warming"
var progress := 0.0
var source_camera: Camera3D
var portal: Node3D
var handed_off := false
var coverage_at_handoff := false
var rendered_frames := 0
var _game: Control
var _destination: Camera3D
var _destination_gate := Transform3D.IDENTITY
var _final_pose := Transform3D.IDENTITY
var _final_fov := 44.0
var _source_fov := 65.0
var _source_settings: Dictionary
var _final_settings: Dictionary
var _clock := 0.0
var _close: Button
var _active := false

func start(camera: Camera3D, game: Control) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_camera = camera
	_game = game
	_destination = game.table.camera
	_final_pose = _destination.global_transform
	_final_fov = _destination.fov
	_source_fov = source_camera.fov
	_source_settings = _projection_settings(source_camera)
	_final_settings = _projection_settings(_destination)
	# At the end of the hub dolly the mapped camera reaches the exact gameplay pose.
	_destination_gate = _final_pose.translated_local(Vector3(0, 0, -(Portal.DISTANCE - TRAVEL)))
	portal = Portal.new()
	source_camera.get_parent().add_child(portal)
	portal.configure(source_camera, game.table.viewport.get_texture())
	_sync_destination()
	_close = Button.new()
	_close.text = " ✕ "
	_close.add_theme_font_size_override("font_size", 32)
	_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close.offset_left = -80
	_close.offset_top = 12
	_close.offset_right = -12
	_close.pressed.connect(func(): _game.finish({"won": false, "quit": true}))
	add_child(_close)
	RenderingServer.frame_post_draw.connect(_frame_rendered)
	_active = true

func _frame_rendered() -> void:
	rendered_frames += 1

func _process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(source_camera) or not is_instance_valid(_game):
		abort()
		return
	_clock += delta
	if DisplayServer.get_name() == "headless":
		rendered_frames += 1
	if phase == "warming":
		# No readback or screenshot: wait for real destination frames before exposing it.
		if rendered_frames >= 2 and _clock >= 0.08:
			phase = "opening"
			_clock = 0.0
		return
	if phase in ["opening", "handoff"]:
		progress = minf(_clock / PUSH_DURATION, 1.0)
		var move := _smooth(clampf((progress - 0.12) / 0.88, 0.0, 1.0))
		var pose: Transform3D = portal.source_anchor
		pose.origin += pose.basis * Vector3(0.12 * pow(sin(move * PI), 2), 0, -TRAVEL * move)
		pose.basis = pose.basis * Basis(Vector3.BACK, 0.025 * sin(move * PI))
		source_camera.global_transform = pose
		source_camera.fov = lerpf(_source_fov, _final_fov_in_source_aspect(), move)
		for property in ["near", "far", "h_offset", "v_offset", "size"]:
			source_camera.set(property, lerpf(_source_settings[property], _final_settings[property], move))
		source_camera.frustum_offset = _source_settings.frustum_offset.lerp(_final_settings.frustum_offset, move)
		_sync_destination()
		if not handed_off:
			portal.set_progress(_smooth(progress))
			if portal.covers_view():
				_transfer_view()
		if progress >= 1.0 and handed_off:
			_destination.global_transform = _final_pose
			for property in _final_settings:
				_destination.set(property, _final_settings[property])
			phase = "settling"
			_clock = 0.0
			_game.table.hud.modulate.a = 0.0
			_game.table.hud.show()
			_game.table.hand.show()
	elif phase == "settling":
		_game.table.hud.modulate.a = clampf(_clock / SETTLE_DURATION, 0.0, 1.0)
		if _clock >= SETTLE_DURATION:
			phase = "done"
			_active = false
			_game.complete_entrance()
			completed.emit()

func _sync_destination() -> void:
	# Rigid portal mapping, including camera roll/lateral motion. SCREEN_UV preserves
	# normalized pixel locations; matching projection preserves parallax and scale.
	_destination.global_transform = _destination_gate * portal.global_transform.affine_inverse() * source_camera.global_transform
	_destination.fov = source_camera.fov
	_destination.projection = source_camera.projection
	_destination.keep_aspect = source_camera.keep_aspect
	_destination.size = source_camera.size
	_destination.frustum_offset = source_camera.frustum_offset
	_destination.near = source_camera.near
	_destination.far = source_camera.far
	_destination.h_offset = source_camera.h_offset
	_destination.v_offset = source_camera.v_offset

func _final_fov_in_source_aspect() -> float:
	if _source_settings.keep_aspect == _final_settings.keep_aspect:
		return _final_fov
	var size := source_camera.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var tangent := tan(deg_to_rad(_final_fov) * 0.5)
	tangent *= aspect if _source_settings.keep_aspect == Camera3D.KEEP_WIDTH else 1.0 / aspect
	return rad_to_deg(2.0 * atan(tangent))

static func _projection_settings(camera: Camera3D) -> Dictionary:
	var result := {}
	for property in ["projection", "keep_aspect", "fov", "size", "near", "far", "h_offset", "v_offset", "frustum_offset"]:
		result[property] = camera.get(property)
	return result

func _transfer_view() -> void:
	coverage_at_handoff = portal.covers_view()
	# Same texture, same camera, same pixel coordinates. No scene reload or pose reset.
	_game.show()
	_close.hide()
	handed_off = true
	phase = "handoff"
	handoff.emit()
	portal.hide()

func abort() -> void:
	_active = false
	if RenderingServer.frame_post_draw.is_connected(_frame_rendered):
		RenderingServer.frame_post_draw.disconnect(_frame_rendered)
	if is_instance_valid(portal):
		portal.queue_free()
	portal = null

func _exit_tree() -> void:
	abort()

static func _smooth(value: float) -> float:
	# Quintic easing: zero velocity and acceleration at both endpoints.
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)
