extends "res://tests/test_suite.gd"
## Continuous hub/table handoff, reservation and cancellation integration checks.

const Layout := preload("res://minigames/cards/table_layout.gd")
var _checks := 0
var _failures := 0
var _games: Node
var _touch: Node
var _room: Node3D
var _camera: Camera3D
var _returned := false
var _duplicate_returned := false
var _result: Dictionary = {}
var _handoffs := 0
var _camera_at_handoff := Transform3D.IDENTITY
var _fov_at_handoff := 0.0
var _source_transform := Transform3D.IDENTITY
var _source_fov := 0.0
var _hud: CanvasLayer
var _destination_projection: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_touch = root.get_node("TouchControls")
	var view: Control = load("res://minigames/cards/table_view.gd").new()
	root.add_child(view)
	_destination_projection = _projection(view.camera)
	view.queue_free()
	await process_frame
	root.get_node("Game").set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	var player: Node3D = _room.get_node("Player")
	player.position = Vector3(3.6, 0, 1.15)
	player.rotation.y = PI
	_camera = player.get_node("Camera")
	_camera.look_at(Vector3(3.6, 1.15, 3.6))
	_camera.fov = 69.0
	for child: Node in _room.get_children():
		if child is CanvasLayer and child.layer == 5:
			_hud = child
	await process_frame
	_source_transform = _camera.global_transform
	_source_fov = _camera.fov

	_returned = false
	_launch()
	_expect(_games.is_running(), "Launcher reserves the request before threaded loading finishes")
	_try_duplicate()
	await process_frame
	_expect(_duplicate_returned, "A duplicate launch returns instead of starting a second scene")
	await _wait_for_transition()
	if _games.current == null or _games.transition == null:
		_finish()
		return
	var game: Node = _games.current
	var transition: Node = _games.transition
	transition.handoff.connect(_on_handoff)
	_expect(game.external_entrance and game._entering, "Hub launch holds the external entrance lifecycle")
	_expect(not game.visible, "Destination stays hidden while the hub presents the portal")
	_expect(_games._backdrop == null or not _games._backdrop.visible or _games._backdrop.color.a <= 0.001,
		"No opaque launcher backdrop replaces the source hub during opening")
	_expect(root.get_camera_3d() == _camera, "Opening keeps the real hub camera rendering")
	_expect(game.table.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Destination viewport stays live while the table is hidden")
	var surface: MeshInstance3D = transition.portal.get_node("Opening/LiveDestination")
	_expect(surface.material_override.get_shader_parameter("destination").get_rid() == game.table.viewport.get_texture().get_rid(),
		"Portal samples the actual live destination viewport, not a captured image")
	_expect(not game.table.hud.visible and not game.table.hand.visible,
		"Gameplay furniture is withheld while crossing worlds")
	var previous := _camera.global_transform
	var moved_frames := 0
	var source_frames := 0
	var settling_frames := 0
	var pre_handoff_frames := 0
	for frame in 1600:
		if not is_instance_valid(game) or not game._entering:
			break
		if is_instance_valid(transition):
			if transition.phase in ["warming", "opening"]:
				pre_handoff_frames += 1
				if not game.visible and root.get_camera_3d() == _camera:
					source_frames += 1
				if not _camera.global_transform.is_equal_approx(previous):
					moved_frames += 1
				previous = _camera.global_transform
			elif transition.phase == "settling":
				settling_frames += 1
				if is_instance_valid(game._dialog):
					_expect(false, "Rules cannot cover the live crossing before settling completes")
		await process_frame
	_expect(not game._entering, "Continuous transition reaches playable table state")
	_expect(pre_handoff_frames >= 5 and source_frames == pre_handoff_frames,
		"The hub remains the presented source for multiple rendered update frames")
	_expect(moved_frames >= 3, "The real hub camera moves over time before handoff")
	_expect(_handoffs == 1, "Exactly one covered handoff occurs")
	_expect(settling_frames >= 3, "Destination camera settles over time after crossing")
	_expect(is_instance_valid(game._dialog), "Tutorial opens only after destination settles")
	_expect(game.visible and game.table.hud.visible and game.table.hand.visible,
		"Settled destination restores its presentation")
	game.hide()
	await process_frame
	_expect(game.table.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Hiding the destination presentation cannot disable its live renderer")
	game.show()
	await process_frame
	_expect(game.table.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Revealing the destination retains its live renderer")
	_expect(_camera.global_transform.is_equal_approx(_source_transform) and is_equal_approx(_camera.fov, _source_fov),
		"Source camera is restored after its work in the transition")
	game.finish({"won": false, "quit": true})
	await _wait_for_return()
	_assert_restored(true, true, "Normal exit")

	# Abort before movement, during movement, and after the covered handoff.
	for desired_phase in ["warming", "opening", "settling"]:
		_returned = false
		_launch()
		await _wait_for_transition()
		if _games.current == null:
			continue
		await _wait_for_phase(desired_phase)
		_expect(_games.current != null and _games.current._entering,
			"Cancellation fixture reaches %s while entry is active" % desired_phase)
		_escape()
		await _wait_for_return()
		_assert_restored(true, true, "Escape during " + desired_phase)

	# Existing hidden UI/input state belongs to the caller and must survive a duel.
	_hud.hide()
	_touch.set_enabled(false)
	_returned = false
	_launch()
	await _wait_for_transition()
	await _wait_for_phase("opening")
	_escape()
	await _wait_for_return()
	_assert_restored(false, false, "Previously hidden HUD and controls")
	_hud.show()
	_touch.set_enabled(true)

	# A non-default source projection must converge without leaving its settings
	# on the gameplay camera, and must be restored exactly when returning.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 76.0
	_camera.h_offset = 0.13
	_camera.v_offset = -0.07
	_camera.frustum_offset = Vector2(0.02, -0.01)
	_camera.near = 0.12
	_camera.far = 130.0
	var source_projection := _projection(_camera)
	_source_fov = _camera.fov
	_returned = false
	_launch()
	await _wait_for_transition()
	_games.transition.handoff.connect(_on_handoff)
	game = _games.current
	await _wait_for_phase("opening")
	root.size = Vector2i(1440, 900)
	for frame in 3:
		await process_frame
	_expect(game.table.viewport.size == Vector2i(game.table.size),
		"Destination render target tracks a window resize during the opening")
	var source_size := _camera.get_viewport().get_visible_rect().size
	var destination_size := Vector2(game.table.viewport.size)
	_expect(is_equal_approx(source_size.x / source_size.y, destination_size.x / destination_size.y),
		"Source and destination retain matching aspect ratios after resize")
	for frame in 1600:
		if not game._entering:
			break
		await process_frame
	_expect(not game._entering, "Horizontal-FOV source reaches the table")
	# The table refits its FOV to the resized window, so compare FOV against that fit.
	var arrived := _projection(game.table.camera)
	var fitted_fov := Layout.camera_fov(game.table.lane_count, Vector2(game.table.viewport.size))
	var expected := _destination_projection.duplicate()
	expected.erase("fov")
	var arrived_fov: float = arrived.fov
	arrived.erase("fov")
	_expect(arrived == expected and is_equal_approx(arrived_fov, fitted_fov),
		"Destination returns to its exact original projection after crossing")
	_expect(_projection(_camera) == source_projection,
		"Completed crossing restores every source projection setting")
	game.finish({"won": false, "quit": true})
	await _wait_for_return()
	_expect(_projection(_camera) == source_projection,
		"Returning to hub preserves source aspect, offsets and clipping planes")
	_assert_restored(true, true, "Non-default source projection")
	_finish()


func _on_handoff() -> void:
	_handoffs += 1
	var transition: Node = _games.transition
	var game: Node = _games.current
	_camera_at_handoff = game.table.camera.global_transform
	_fov_at_handoff = game.table.camera.fov
	_expect(game.visible, "Destination is presented at the handoff signal")
	_expect(transition.portal.covers_view(), "Every viewport corner is covered before ownership transfers")
	var view_size := _camera.get_viewport().get_visible_rect().size
	var polygon: PackedVector2Array = transition.portal.projected_polygon()
	var all_corners_covered := true
	for point in [Vector2.ZERO, Vector2(view_size.x, 0), view_size, Vector2(0, view_size.y)]:
		all_corners_covered = all_corners_covered and Geometry2D.is_point_in_polygon(point, polygon)
	_expect(all_corners_covered, "Independent screen-corner projection confirms aperture coverage")
	_expect(game._entering and game.table.locked and not is_instance_valid(game._dialog),
		"Handoff does not prematurely unlock play or open rules")
	_expect(is_equal_approx(game.table.camera.fov, _camera.fov),
		"Source and portal destination share the same field of view at handoff")


func _assert_restored(hud_visible: bool, touch_enabled: bool, label: String) -> void:
	_expect(_returned and not paused and _games.current == null, label + " releases the launcher and hub pause")
	_expect(_games.transition == null, label + " releases the transition director")
	_expect(_camera.global_transform.is_equal_approx(_source_transform) and is_equal_approx(_camera.fov, _source_fov),
		label + " restores the exact original camera pose and field of view")
	_expect(root.get_camera_3d() == _camera, label + " restores the active source camera")
	_expect(_hud.visible == hud_visible and _touch._enabled == touch_enabled,
		label + " preserves caller HUD and touch-control visibility")


func _projection(camera: Camera3D) -> Dictionary:
	return {"mode": camera.projection, "fov": camera.fov,
		"aspect": camera.keep_aspect, "h": camera.h_offset, "v": camera.v_offset,
		"frustum": camera.frustum_offset, "near": camera.near, "far": camera.far,
		"size": camera.size}


func _wait_for_transition() -> void:
	for frame in 800:
		if _games.current != null and _games.transition != null:
			return
		await process_frame
	_expect(false, "Launcher creates the continuous transition within timeout")


func _wait_for_phase(phase: String) -> void:
	for frame in 1600:
		if _games.transition != null and _games.transition.phase == phase:
			return
		if _returned:
			break
		await process_frame
	_expect(false, "Transition reaches phase " + phase)


func _wait_for_return() -> void:
	for frame in 100:
		await process_frame
		if _returned:
			return
	_expect(false, "Cancelled or completed duel returns to its caller")


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "back"
		event.pressed = pressed
		Input.parse_input_event(event)


func _launch() -> void:
	_result = await _games.play("cards")
	_returned = true


func _try_duplicate() -> void:
	var result: Dictionary = await _games.play("cards")
	_duplicate_returned = result.is_empty()


func _finish() -> void:
	_room.queue_free()
	await process_frame
	print("Card transition: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
