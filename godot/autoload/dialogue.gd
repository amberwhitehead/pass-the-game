extends CanvasLayer
## Bottom-of-screen dialogue box.
##   await Dialogue.say("Mira", ["Hello!", "Nice day."])
## Advance with the A button / tap / E / Space. Resolves when finished.

signal finished

var active := false
var last_closed_frame := -1  # lets callers ignore the press that closed the box

var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _lines: Array = []
var _index := 0
var _tween: Tween


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.08
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.1, 0.9)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	style.border_color = Color(0.6, 0.5, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	_name.add_theme_font_size_override("font_size", 26)
	vb.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size.y = 70
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 28)
	vb.add_child(_text)
	_hint = Label.new()
	_hint.text = "A ▸"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(_hint)


func say(speaker: String, lines: Array) -> void:
	if active or lines.is_empty():
		return
	active = true
	_lines = lines
	_index = 0
	_name.text = speaker
	_panel.visible = true
	_show_line()
	await finished


func _show_line() -> void:
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, 0.03 * _text.get_total_character_count() + 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var advance := event.is_action_pressed("interact")
	# Tapping the dialogue panel itself also advances.
	if event is InputEventScreenTouch and event.pressed \
			and _panel.get_global_rect().has_point(event.position):
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _text.visible_ratio < 1.0:
		_tween.kill()
		_text.visible_ratio = 1.0
		return
	_index += 1
	if _index >= _lines.size():
		_panel.visible = false
		active = false
		last_closed_frame = Engine.get_process_frames()
		finished.emit()
	else:
		_show_line()
