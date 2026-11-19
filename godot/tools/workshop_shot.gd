extends Node
## Dev tool: renders the Workshop diorama and saves screenshots, for checking its art
## without playing.
##   godot --path godot res://tools/workshop_shot.tscn -- --out=/some/dir [--script=a,b,c] [--frames=40]
## `--script=` runs debug steps (Workshop.debug_step) one per shot, e.g. "fix_tv,arrival".

func _ready() -> void:
	var out := "/tmp"
	var steps: Array = []
	var frames := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--script="):
			steps = Array(a.substr(9).split(",", false))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	var game: Control = load("res://minigames/workshop/workshop.tscn").instantiate()
	add_child(game)
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/workshop_0.png" % out)
	var n := 1
	for s in steps:
		if s.begins_with("wait"):
			await get_tree().create_timer(float(s.substr(4))).timeout
		else:
			game.call("debug_step", s)
			for i in frames:
				await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/workshop_%d_%s.png" % [out, n, s])
		n += 1
	get_tree().quit()
