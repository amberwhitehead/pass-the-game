extends Node
## Room benchmark: loads the room, parks the player at a few viewpoints and prints frame time, draw calls and
## primitives for each (vsync off, so frame time is the real cost, not the display refresh).
##
##   godot --path godot res://tools/bench.tscn                    # as it is
##   godot --path godot res://tools/bench.tscn -- --hide-platforms # nodes in group "platform" hidden
##
## `-- --hide-greebles` hides the wall greebles (A/B test).
## `-- --door-open` opens the west door.
## `-- --won` shows the mini-game trophies (pyramid ribbons, aqueduct) as if both games were won.
## `-- --shots=/some/dir` also saves a PNG of every view there.
## Add `--rendering-driver opengl3` (the project default is GL Compatibility) or `--resolution 960x540` to taste.

const ROOM := preload("res://scenes/room/room.tscn")
const WARMUP := 40
const SAMPLES := 240

## name, position, yaw (rad; 0 faces -z), pitch
const VIEWS := [
	["start (west door, looking east)", Vector3(-6.5, 0, 0), -PI / 2, 0.0],
	["centre, facing the platform row", Vector3(0, 0, -0.6), 0.0, -0.1],
	["close to Newton platform", Vector3(-3.6, 0, -1.7), 0.0, -0.25],
	["close to Turing platform", Vector3(0, 0, -1.7), 0.0, -0.25],
	["close to mainframe (Challenge 1)", Vector3(-3.6, 0, 1.7), PI, -0.25],
	["looking back across the room", Vector3(6.0, 0, 1.5), PI / 2, 0.0],
	["west door", Vector3(-4.8, 0, 0), PI / 2, 0.05],
	["north wall greebles", Vector3(-1.6, 0, 3.0), 0.0, 0.15],
	["south wall greebles", Vector3(1.6, 0, -3.0), PI, 0.15],
]


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.set_flag("room_visited")        # skip the door-opening intro
	if "--won" in OS.get_cmdline_user_args():       # pretend the two 3D mini-games are won (trophies show)
		Game.completed_minigames["newton"] = FakeResults.newton()
		Game.completed_minigames["turing"] = FakeResults.turing()
	var room := ROOM.instantiate()
	add_child(room)
	if "--hide-platforms" in OS.get_cmdline_user_args():
		for n in get_tree().get_nodes_in_group("platform"):
			n.visible = false
	if "--hide-greebles" in OS.get_cmdline_user_args():
		for n in room.find_children("Greebles", "", true, false):
			n.visible = false
	if "--door-open" in OS.get_cmdline_user_args():
		(room.get_node("DoorWest") as DoubleDoor).set_open(true, false)
	await _run(room)
	get_tree().quit()


func _run(room: Node) -> void:
	var player: Player = room.get_node("Player")
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("renderer: ", RenderingServer.get_current_rendering_method(), "  ", RenderingServer.get_video_adapter_name(),
		"  window ", get_window().size)
	print("%-34s %8s %8s %8s %10s %9s" % ["view", "fps", "ms", "calls", "prims", "gpu ms"])
	var totals := [0.0, 0.0, 0.0, 0.0]
	for v in VIEWS:
		player.global_position = v[1]
		player.rotation.y = v[2]
		player.camera.rotation.x = v[3]
		for i in WARMUP:
			await get_tree().process_frame
		var t := 0.0
		var calls := 0.0
		var prims := 0.0
		var gpu := 0.0
		for i in SAMPLES:
			await get_tree().process_frame
			t += get_process_delta_time()
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				get_viewport().get_texture().get_image().save_png("%s/view_%d.png" % [a.substr(8), VIEWS.find(v)])
		var ms := t / SAMPLES * 1000.0
		print("%-34s %8.0f %8.2f %8.0f %10.0f %9.2f" % [v[0], 1000.0 / ms, ms, calls / SAMPLES, prims / SAMPLES, gpu / SAMPLES])
		totals[0] += ms; totals[1] += calls / SAMPLES; totals[2] += prims / SAMPLES; totals[3] += gpu / SAMPLES
	var n := float(VIEWS.size())
	print("%-34s %8.0f %8.2f %8.0f %10.0f %9.2f" % ["average", 1000.0 / (totals[0] / n), totals[0] / n, totals[1] / n, totals[2] / n, totals[3] / n])
