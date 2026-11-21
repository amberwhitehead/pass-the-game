extends Control
## A shared instrument readout, with a quiet hierarchy around the physical puzzle.
const Style := preload("res://ui/game_style.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const PadLabels := preload("res://autoload/pad_labels.gd")
var values: Label
var hint: Label
var _hint_copy := ""
var _button_prompts := false
var _pad_device := -1  ## The controller last used, for its button symbols; -1 for touch.

func _ready() -> void:
	_button_prompts = TouchControls.button_prompts
	_refresh_hint()
	# Keys can be changed in Controls while this puzzle waits under the pause menu.
	PauseMenu.closed.connect(_refresh_hint)

## Puzzle instructions name keyboard keys unless touch/controller input is active.
## Placeholders: {interact}, {continue}, {steer} (left/right), {reach} (forward/back).
func set_hint(copy: String) -> void:
	if copy == _hint_copy:
		return
	_hint_copy = copy
	_refresh_hint()

func _input(event: InputEvent) -> void:
	var buttons := _button_prompts
	if event is InputEventKey and event.pressed:
		buttons = false
	elif (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > .5):
		buttons = true
		if event.device != _pad_device:
			_pad_device = event.device
			_button_prompts = not buttons  # Relabel for this pad.
	elif event is InputEventScreenTouch and event.device != -1:
		buttons = true
		if _pad_device != -1:
			_pad_device = -1  # Touch shows the touch pad's A and B.
			_button_prompts = not buttons
	if buttons != _button_prompts:
		_button_prompts = buttons
		_refresh_hint()

func _refresh_hint() -> void:
	if hint == null:
		return
	if _button_prompts:
		var a := PadLabels.face(JOY_BUTTON_A, _pad_device) if _pad_device >= 0 else "A"
		var b := PadLabels.face(JOY_BUTTON_B, _pad_device) if _pad_device >= 0 else "B"
		hint.text = _hint_copy.format({"interact": a, "continue": "%s or %s" % [a, b], "steer": "◀ ▶", "reach": "▲ ▼"})
		return
	var interact := KeyBindings.labels("interact", 2)
	hint.text = _hint_copy.format({
		"interact": interact,
		"continue": "%s or %s" % [interact, KeyBindings.label("back")],
		"steer": "%s %s" % [KeyBindings.label("strafe_left"), KeyBindings.label("strafe_right")],
		"reach": "%s %s" % [KeyBindings.label("move_up"), KeyBindings.label("move_down")],
	})

func setup(number: String, title: String, description: String) -> void:
	theme = Style.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var information := VBoxContainer.new()
	information.position = Vector2(30, 22)
	information.size.x = 580
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	information.add_theme_constant_override("separation", 5)
	add_child(information)
	var eyebrow := Label.new()
	eyebrow.text = "CHAMBER " + number
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Style.GOLD)
	information.add_child(eyebrow)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", Style.font(true))
	heading.add_theme_font_size_override("font_size", 34)
	information.add_child(heading)
	var instruction := Label.new()
	instruction.text = description
	instruction.add_theme_font_size_override("font_size", 15)
	instruction.add_theme_color_override("font_color", Style.MUTED)
	information.add_child(instruction)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	information.add_child(gap)
	var data := PanelContainer.new()
	data.add_theme_stylebox_override("panel", Style.panel(Color(Style.INK, .88), Color(Style.GOLD, .22), 14))
	data.mouse_filter = Control.MOUSE_FILTER_IGNORE
	information.add_child(data)
	values = Label.new()
	values.add_theme_font_size_override("font_size", 16)
	values.add_theme_color_override("font_color", Style.MUTED)
	values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	data.add_child(values)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -350
	footer.offset_right = 350
	footer.offset_top = -76
	footer.offset_bottom = -24
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Color(Style.GOLD, .35), 14))
	add_child(footer)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Style.PAPER)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(hint)
