class_name MiniGame
extends Control
## Base class for all mini-games. Each mini-game is its own scene under
## res://minigames/<id>/ and loads whatever it needs itself.
##
## Call finish({"won": true, ...}) when done. Pressing "back" quits.
## Set `use_touch_controls = false` for games that use tap/drag UI instead.

signal finished(result: Dictionary)

var use_touch_controls := true
var _done := false


func _enter_tree() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	TouchControls.set_enabled(use_touch_controls)
	# Always-available exit, even when the touch pad is hidden.
	var close := Button.new()
	close.text = " ✕ "
	close.add_theme_font_size_override("font_size", 32)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -80
	close.offset_top = 12
	close.offset_right = -12
	close.pressed.connect(func(): finish({"won": false, "quit": true}))
	add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		finish({"won": false, "quit": true})


func finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	TouchControls.set_enabled(true)
	finished.emit(result)


## Helper: simple centered title label.
func make_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 16
	add_child(l)
	return l
