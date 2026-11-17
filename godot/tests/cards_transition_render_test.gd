extends SceneTree
## Graphical regression: the source portal and destination must render the same
## pixels at an identical camera pose. Run without --headless.

var _checks := 0
var _failures := 0
var _games: Node
var _returned := false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This pixel regression requires a graphical renderer; omit --headless.")
		quit(1)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	root.get_node("Game").set_flag("room_visited")
	_games = root.get_node("MiniGames")
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player: Node3D = room.get_node("Player")
	player.position = Vector3(3.6, 0, 1.15)
	player.rotation.y = PI
	player.get_node("Camera").look_at(Vector3(3.6, 1.15, 3.6))
	for frame in 10:
		await process_frame
	call_deferred("_launch")
	for frame in 600:
		if _games.transition != null:
			break
		await process_frame
	if _games.transition == null:
		_expect(false, "Real hub launch creates the transition renderer")
		quit(1)
		return
	var transition: Control = _games.transition
	await transition.handoff
	transition.set_process(false)
	var game: Control = _games.current
	_expect(transition.coverage_at_handoff, "Graphical handoff waits for complete aperture coverage")
	var frozen_pose: Transform3D = game.table.camera.global_transform
	game.table.world.process_mode = Node.PROCESS_MODE_DISABLED
	game.table.intent_glow.hide() # Shader TIME remains live; remove the pulsing cue.
	await process_frame

	# Both captures use the actual presentation paths. Hiding the root must not
	# disable the nested renderer or leave a stale destination image in the portal.
	game.hide()
	transition.portal.show()
	transition._close.show()
	await _render_frames()
	_expect(game.table.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Hidden table keeps rendering its live portal texture")
	var portal_image := root.get_texture().get_image()
	_expect(not portal_image.is_empty(), "Source portal produces a rendered image")
	game.show()
	transition.portal.hide()
	transition._close.hide()
	await _render_frames()
	_expect(game.table.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Full-screen presentation preserves renderer ownership")
	var direct_image := root.get_texture().get_image()
	_expect(not direct_image.is_empty(), "Destination produces a rendered image")
	_expect(game.table.camera.global_transform.is_equal_approx(frozen_pose),
		"Comparison holds destination camera pose fixed")

	# Ignore only top UI, where hover/focus can differ between the two close buttons.
	var region := Rect2i(0, 80, portal_image.get_width(), portal_image.get_height() - 80)
	var a := portal_image.get_region(region)
	var b := direct_image.get_region(region)
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var source_bytes := a.get_data()
	var target_bytes := b.get_data()
	var maximum := 0
	var total := 0
	var brightness := 0
	for index in source_bytes.size():
		var difference := absi(int(source_bytes[index]) - int(target_bytes[index]))
		maximum = maxi(maximum, difference)
		total += difference
		brightness += int(target_bytes[index])
	var mean := float(total) / source_bytes.size()
	_expect(float(brightness) / target_bytes.size() > 10.0,
		"Pixel equality is checked against a visible table, not two blank buffers")
	_expect(maximum <= 1 and mean <= 0.1,
		"Portal/full-screen pixels match within one 8-bit rounding level (max=%d, mean=%.6f)" % [maximum, mean])
	game.finish({"won": false, "quit": true})
	await process_frame
	_expect(_returned and not paused, "Graphical fixture returns cleanly to the hub")
	room.queue_free()
	await process_frame
	print("Card transition pixels: %d checks, %d failures; max=%d/255, mean=%.6f/255" % [_checks, _failures, maximum, mean])
	quit(0 if _failures == 0 else 1)


func _render_frames() -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _launch() -> void:
	await _games.play("cards")
	_returned = true
