extends Node
## Dev tool: renders the Workshop diorama and saves screenshots, for checking its art and
## story scenes without playing.
##   godot --path godot res://tools/workshop_shot.tscn -- --out=/some/dir --script=a,b,c
## Steps, run in order:
##   run:ID[@ITEM]   click hotspot ID (holding ITEM) and fast-forward the whole scene
##   click:ID[@ITEM] click without waiting (the scene keeps playing)
##   radio:PART      click a part of the radio close-up (power, tune, turn, screw0..3, tube, out)
##   wait:SECONDS    let time pass
##   adv             dismiss the current speech bubble
##   shot:NAME       save workshop_<n>_<NAME>.png
##   any other step is passed to Workshop.debug_step()

var _game: Control
var _out := "/tmp"
var _n := 0


func _ready() -> void:
	var steps: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--script="):
			steps = Array(a.substr(9).split(",", false))
	_game = load("res://minigames/workshop/workshop.tscn").instantiate()
	add_child(_game)
	# Only the scripted steps drive the story: real clicks on the window are ignored.
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.set_process_unhandled_input(false)
	await _frames(30)
	for s: String in steps:
		var arg := s.substr(s.find(":") + 1) if ":" in s else ""
		if s.begins_with("run:") or s.begins_with("click:"):
			var parts := arg.split("@")
			_game._story.click(parts[0], parts[1] if parts.size() > 1 else "", Vector2(760, 760))
			if s.begins_with("run:"):
				await _fast_forward()
		elif s.begins_with("radio:"):
			# A part of the radio close-up: power, tune, turn, screw0..3, tube, out.
			var RV := preload("res://minigames/workshop/radio_view.gd")
			var spots := {"power": RV.POWER, "tune": RV.TUNE, "turn": RV.TURN.get_center(), "tube": RV.TUBE + Vector2(0, -40), "out": Vector2(100, 100)}
			for k in 4:
				spots["screw%d" % k] = RV.SCREWS[k]
			_game._story.radio_click(spots[arg])
			await _fast_forward()
		elif s.begins_with("wait:"):
			await get_tree().create_timer(float(arg)).timeout
		elif s == "adv":
			_game._bubble.advance()
			_game._bubble.advance()
			await _frames(2)
		elif s.begins_with("shot:"):
			await _frames(3)
			_n += 1
			get_viewport().get_texture().get_image().save_png("%s/workshop_%d_%s.png" % [_out, _n, arg])
		else:
			_game.debug_step(s)
			await _frames(10)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fast_forward() -> void:
	Engine.time_scale = 8.0
	await _frames(1)
	while _game._story.busy or _game._bubble.is_open():
		_game._bubble.advance()
		_game._bubble.advance()
		await _frames(1)
	Engine.time_scale = 1.0
	await _frames(2)
