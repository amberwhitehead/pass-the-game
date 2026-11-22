extends Node
## Dev tool: screenshots the Observatory blackboard in the hall.
func _ready() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var game = get_node("/root/Game")
	game.new_game(0)
	game.set_flag("room_visited")
	var math = load("res://minigames/observatory/observatory_math.gd")
	for i in math.SIGIL_COUNT:
		game.collect_card(math.sigil(i).card)
	var room = load("res://scenes/room/room.tscn").instantiate()
	add_child(room)
	for i in 10:
		await get_tree().process_frame
	var board: Node3D = room.find_child("ObservatoryBoard", true, false)
	if board == null:
		print("no board")
		get_tree().quit()
		return
	var cam := Camera3D.new()
	add_child(cam)
	var at := board.global_position
	cam.position = at + Vector3(0, 0.2, 2.4)
	cam.look_at(at)
	cam.make_current()
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/hall_board.png" % out)
	get_tree().quit()