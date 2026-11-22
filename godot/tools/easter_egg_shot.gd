extends Node
func _ready() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var egg = load("res://ui/easter_egg_cat.gd").new()
	add_child(egg)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/easter_egg.png" % out)
	get_tree().quit()