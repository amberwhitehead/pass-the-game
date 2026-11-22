extends "res://tests/test_suite.gd"
## The title screen hides a star hotspot that opens the dancing-cat easter egg.
const Title := preload("res://scenes/title/title.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: " + msg)


func _run() -> void:
	var title = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	var spot = title.find_child("SecretStar", true, false)
	_expect(spot != null, "the title background has a hidden star hotspot")
	_expect(title._egg == null, "the easter egg is closed until found")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	title._secret_bright = 0.2
	spot.gui_input.emit(click)
	await process_frame
	_expect(title._egg == null, "a dim star rejects the click")
	title._secret_bright = 0.8
	spot.gui_input.emit(click)
	await process_frame
	_expect(is_instance_valid(title._egg), "a star at 50%+ brightness opens the dancing-cat screen")
	var cat = title._egg.find_children("*", "Node2D", true, false)
	_expect(cat.size() > 0, "the easter egg contains a drawn cat")
	title.queue_free()
	await process_frame
	print("Easter egg title: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)