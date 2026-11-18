extends "res://tests/test_suite.gd"
## Long copy and modal controls must fit the window without swallowing gameplay input.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 640)]:
		root.size = viewport_size
		await process_frame
		await _check_intro()
		await _check_dialogue()
		await _check_sound()
		await _check_puzzle_hud()
	print("UI panels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_intro() -> void:
	var intro: Control = load("res://scenes/intro/intro.tscn").instantiate()
	root.add_child(intro)
	for page in 5:
		intro._next_page()
		intro._tween.kill()
		intro._label.visible_ratio = 1
		await process_frame
		await process_frame
		_inside(intro._panel, "intro page %d" % page)
		check(intro._label.get_content_height() <= intro._label.size.y + 1, "long intro text fits without scrolling")
	intro.queue_free()
	await process_frame

func _check_dialogue() -> void:
	var dialogue := root.get_node("Dialogue")
	dialogue.say("The Keeper of the Refraction Hall", ["A visitor, at last. The amber chamber is waiting for you. When you return, bring what you find to the empty sockets in the hall. The machine has been quiet for a very long time, but a little light may be all it needs."])
	dialogue._tween.kill()
	dialogue._text.visible_ratio = 1
	await process_frame
	await process_frame
	_inside(dialogue._panel, "dialogue")
	check(dialogue._text.get_content_height() <= dialogue._text.size.y + 1, "dialogue copy fits")
	var sound := root.get_node("Sound")
	var settings := sound.get_node("SoundSettings")
	settings._toggle(true)
	var advance := InputEventAction.new()
	advance.action = "interact"
	advance.pressed = true
	dialogue._unhandled_input(advance)
	check(dialogue.active, "sound menu blocks conversation advance")
	settings._toggle(false)
	dialogue._unhandled_input(advance)
	check(not dialogue.active, "conversation advances after sound menu closes")

func _check_sound() -> void:
	var sound := root.get_node("Sound")
	var settings := sound.get_node("SoundSettings")
	settings._toggle(true)
	await process_frame
	await process_frame
	_inside(settings._panel, "sound panel")
	for button: Node in settings._panel.find_children("*", "Button", true, false):
		_inside(button, "sound action")
	var cancel := InputEventAction.new()
	cancel.action = "back"
	cancel.pressed = true
	settings._input(cancel)
	check(not sound.settings_open, "Escape dismisses sound menu")

func _check_puzzle_hud() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var hud: Control = load("res://ui/puzzle_hud.gd").new()
	host.add_child(hud)
	hud.setup("02", "Roman Flow", "Connect the three routes through the living pattern.")
	hud.values.text = "feed 0.123   kill 0.123   Du 0.12   Dv 0.12\n○ Aqueduct   ○ Fountain   ○ Reservoir\nAmber 8/8   Teal 8/8 in tray   viz: Living pattern"
	hud.hint.text = "Too close to another cylinder     ◀ ▶ walk   ▲ ▼ reach"
	await process_frame
	await process_frame
	_inside(hud.values, "puzzle values")
	_inside(hud.hint, "puzzle hint")
	check(hud.hint.size.y >= hud.hint.get_minimum_size().y, "long action hint fits its panel")
	host.queue_free()
	await process_frame

func _inside(control: Control, description: String) -> void:
	var area := control.get_global_rect()
	var viewport_area := root.get_visible_rect()
	check(viewport_area.encloses(area), "%s stays in %s: %s" % [description, root.size, area])

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
