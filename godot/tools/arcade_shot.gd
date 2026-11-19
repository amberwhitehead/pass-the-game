extends Node
## Dev tool: screenshots of CHRONO RAIDER (title, play, boss) and of its cabinet in the
## secret room, for checking the art without playing.
##   godot --path godot res://tools/arcade_shot.tscn -- --out=/some/dir

var _out := "/tmp"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var game: Control = load("res://minigames/arcade/arcade.tscn").instantiate()
	add_child(game)
	var s: Node2D = game.shooter
	await _frames(40)
	_shot("title")
	s.controls.forced = {"start": true}
	await _frames(25)
	s.controls.forced = {"fire": true, "move": Vector2(0.3, -0.4)}
	await _frames(60)
	_shot("start")
	for i in 900:
		s.controls.forced = {"fire": true, "move": Vector2(0, sin(i * 0.02)), "switch": i % 200 == 0}
		s.step()
		if s.player.lives < 3:
			s.player.lives = 3  # Keep the demo going.
	await _frames(30)
	_shot("play")
	s.player.collect(1)
	s.player.collect(2)
	s.player.collect(2)
	s.skip_to_boss()
	for i in 520:
		s.controls.forced = {"fire": true, "move": Vector2(0, sin(i * 0.03) * 0.8), "switch": i == 300}
		s.step()
		s.player.lives = 3
	await _frames(20)
	_shot("boss")
	game.queue_free()
	# The cabinet in the secret room.
	var room: Node = load("res://scenes/room/room.tscn").instantiate()
	add_child(room)
	await _frames(10)
	var cabinet: Node3D = room.find_child("ArcadeCabinet", true, false)
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = cabinet.to_global(Vector3(-.6, 1.55, 1.9))
	cam.look_at(cabinet.to_global(Vector3(0, 1.15, 0)))
	cam.current = true
	await _frames(60)
	_shot("cabinet")
	cam.global_position = cabinet.get_parent().to_global(Vector3(-1.2, 1.6, 2.6))
	cam.look_at(cabinet.get_parent().to_global(Vector3(.6, 1.0, -.6)))
	await _frames(30)
	_shot("room")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/arcade_%s.png" % [_out, name])
