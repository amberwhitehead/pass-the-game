extends CanvasLayer
## Bottom-of-screen dialogue box (above the touch pad and the hall's notices).
##   await Dialogue.say("Mira", ["Hello!", "Nice day."])
## Advance with the A button / tap / E / Enter / F. Resolves when finished.

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
	_panel = preload("res://ui/conversation_sheet.gd").new()
	_panel.anchor_left = .12
	_panel.anchor_right = .88
	_panel.anchor_top = .95
	_panel.anchor_bottom = .95
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	add_child(_panel)
	_name = _panel.speaker
	_text = _panel.copy
	_hint = _panel.hint
	# The sheet's speaker, body and hint text (ui/conversation_sheet.gd).
	var Style := preload("res://ui/game_style.gd")
	preload("res://ui/glyph_warmup.gd").add_to(self, [[Style.font(true), 28], [_text.get_theme_font("normal_font"), 22], [_hint.get_theme_font("font"), 12]])


func say(speaker: String, lines: Array) -> void:
	if active or lines.is_empty():
		return
	active = true
	_lines = lines
	_index = 0
	_name.text = speaker
	_panel.visible = true
	_panel.arrive()
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
	if not active or Sound.settings_open:
		return
	var advance := event.is_action_pressed("interact")
	# A click continues the conversation it started (the hall interacts on click).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		advance = true
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
