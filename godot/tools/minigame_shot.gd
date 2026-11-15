extends Node
## Dev tool: loads one mini-game that orbits a table (newton, turing) and saves screenshots from a few angles.
##   godot --path godot res://tools/minigame_shot.tscn -- --game=newton --out=/some/dir
## `--win` fakes solving it and takes the shots over the next seconds, to watch the win animation.
## It also prints any script errors the scene produces, which is the quick smoke test after changing a game.

func _ready() -> void:
	var game := "newton"
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game="):
			game = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var scene: Node = load("res://minigames/%s/%s.tscn" % [game, game]).instantiate()
	add_child(scene)
	for i in 30:
		await get_tree().process_frame
	if "--win" in OS.get_cmdline_user_args():
		scene.set("_solved", true)
		if game == "turing":
			scene.set("_route_cells", FakeResults.turing_cells())
		else:
			for st in scene.get("_pyramids"):
				st.root = Vector2(1, 0)
		scene.call("_celebrate")
		for k in 4:
			await get_tree().create_timer([0.5, 1.5, 3.0, 8.0][k]  - ([0.0, 0.5, 1.5, 3.0][k])).timeout
			get_viewport().get_texture().get_image().save_png("%s/%s_win_%d.png" % [out, game, k])
		get_tree().quit()
		return
	for k in 4:
		scene.set("_theta", scene.get("_theta") + k * 1.2 if k > 0 else scene.get("_theta"))
		for i in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, game, k])
	get_tree().quit()
