extends PanelContainer
## Shared dialogue typography and frame; callers retain their story/typewriter logic.
const Style := preload("res://ui/game_style.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
var speaker: Label
var copy: RichTextLabel
var hint: Label
var _arrival: Tween
var _key := ""  # Empty = keyboard: the current Interact key.

func _init() -> void:
	theme = Style.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Style.GOLD.darkened(.42), 24))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	speaker = Label.new()
	speaker.add_theme_font_override("font", Style.font(true))
	speaker.add_theme_font_size_override("font_size", 28)
	speaker.add_theme_color_override("font_color", Style.GOLD)
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(speaker)
	hint = Label.new()
	hint.text = "CLICK  /  CONTINUE"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Style.MUTED)
	header.add_child(hint)
	var rule := HSeparator.new()
	column.add_child(rule)
	copy = RichTextLabel.new()
	copy.bbcode_enabled = true
	copy.fit_content = true
	copy.scroll_active = false
	copy.custom_minimum_size.y = 58
	copy.add_theme_font_size_override("normal_font_size", 22)
	copy.add_theme_color_override("default_color", Style.PAPER)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(copy)

func arrive() -> void:
	_show_hint()  # Keys may have been rebound since the last conversation.
	if _arrival:
		_arrival.kill()
	modulate.a = 0.0
	_arrival = create_tween()
	_arrival.tween_property(self, "modulate:a", 1.0, .18).set_trans(Tween.TRANS_SINE)

func _input(event: InputEvent) -> void:
	if not visible or event is InputEventMouseMotion:
		return
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_key = ""
	elif event is InputEventScreenTouch and event.device != -1:
		_key = "TAP"
	_show_hint()

## R1 while a controller is plugged in, otherwise CLICK (TAP after touching the screen).
func _show_hint() -> void:
	var key := _key
	if key.is_empty():
		key = "R1" if not Input.get_connected_joypads().is_empty() else "CLICK"
	hint.text = key + "  /  CONTINUE"
