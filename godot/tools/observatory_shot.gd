extends Node
## Dev tool: screenshots of the Observatory, tuned and untuned, from a few angles.
##   xvfb-run -a godot --rendering-driver opengl3 --path godot res://tools/observatory_shot.tscn -- --out=/some/dir

func _ready() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var scene: Node = load("res://minigames/observatory/observatory.tscn").instantiate()
	add_child(scene)
	for i in 30:
		await get_tree().process_frame
	# unresolved (start)
	get_viewport().get_texture().get_image().save_png("%s/obs_start.png" % out)
	# tuned to the first sigil's target
	var math = load("res://minigames/observatory/observatory_math.gd")
	var s = math.sigil(0)
	scene.set("_az", s.az)
	scene.set("_el", s.el)
	scene.set("_focusv", s.focus)
	scene.set("_v1", s.v1)
	scene.set("_v2", s.v2)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/obs_tuned.png" % out)
	# orbit for a side view
	for k in 3:
		scene.set("_theta", scene.get("_theta") + 1.4)
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/obs_tuned_%d.png" % [out, k])
	get_tree().quit()