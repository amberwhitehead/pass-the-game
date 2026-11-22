extends Node
func _ready() -> void:
	var title = load("res://scenes/title/title.tscn").instantiate()
	add_child(title)
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/opencode/title_star.png")
	var vp := get_viewport().get_visible_rect().size
	var at := vp * Vector2(0.8833, 0.73)
	print("viewport ", vp, " click at ", at)
	Input.warp_mouse(at)
	await get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	print("egg: ", title._egg)
	get_tree().quit()