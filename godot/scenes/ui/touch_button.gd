extends Control
## A multi-touch-safe on-screen button that presses an InputMap action.
## Listens for touch events globally (so a finger can slide on/off it and two
## buttons can be held at once). Mouse is emulated to touch in project settings
## for desktop testing, and real mouse events are ignored here to avoid doubles.

@export var action := ""
@export var text := ""

var _fingers: Dictionary = {}  # finger index -> true
var _pressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and get_global_rect().has_point(event.position):
			_fingers[event.index] = true
		elif not event.pressed:
			_fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		if get_global_rect().has_point(event.position):
			_fingers[event.index] = true
		else:
			_fingers.erase(event.index)
	else:
		return
	_set_pressed(not _fingers.is_empty())


func _set_pressed(p: bool) -> void:
	if p == _pressed:
		return
	_pressed = p
	_send(p)
	queue_redraw()


## Input.action_press() only flips polling state; handlers that use
## event.is_action_pressed() (dialogue, interact, mini-games) need a real event.
func _send(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _exit_tree() -> void:
	if _pressed:
		_pressed = false
		_send(false)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-2)
	var fill := Color(1, 1, 1, 0.38 if _pressed else 0.16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(minf(size.x, size.y) * 0.3))
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(3)
	draw_style_box(sb, r)
	var font := ThemeDB.fallback_font
	var fs := int(minf(size.x, size.y) * 0.45)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2((size.x - ts.x) / 2.0, (size.y + ts.y * 0.6) / 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
