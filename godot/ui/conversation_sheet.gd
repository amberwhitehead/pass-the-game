extends PanelContainer
## Shared dialogue typography and frame; callers retain their story/typewriter logic.
const Style := preload("res://ui/game_style.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const PadGlyph := preload("res://ui/pad_glyph.gd")
const PadLabels := preload("res://autoload/pad_labels.gd")
var speaker: Label
var copy: RichTextLabel
var hint: Label
var glyph: Control  ## The controller's R1, drawn, before the hint while a pad is plugged in.
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
	glyph = PadGlyph.new()
	glyph.button = "r1"
	glyph.glyph_height = 16.0
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.visible = false
	header.add_child(glyph)
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

## The controller's R1 button, drawn, while one is plugged in; otherwise CLICK (TAP
## after touching the screen).
func _show_hint() -> void:
	var pad := _key.is_empty() and not Input.get_connected_joypads().is_empty()
	glyph.visible = pad
	if pad:
		glyph.kind = PadLabels.kind()
		hint.text = "  CONTINUE"
		return
	hint.text = (_key if not _key.is_empty() else "CLICK") + "  /  CONTINUE"
