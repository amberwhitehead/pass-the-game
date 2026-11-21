extends ColorRect
## A reading card with a bounded scroll area; actions always remain reachable.
const UI := preload("res://minigames/cards/card_ui.gd")

func setup(title: String, body: String, actions: Array, eyebrow := "THE LITTLE BROTHER'S TABLE") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.Style.theme()
	color = Color(.015, .025, .03, .86)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var view := get_viewport_rect().size
	var width := minf(690, view.x - 48)
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", UI.Style.panel(UI.PANEL, Color(UI.GOLD, .55), 28))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(UI.eyebrow(eyebrow))
	var heading := UI.label(title, 29)
	heading.add_theme_font_override("font", UI.Style.font(true))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var rule := HSeparator.new()
	column.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = clampf(body.length() * .34, 110, minf(390, view.y - 260))
	column.add_child(scroll)
	var copy := UI.label(body, 18)
	copy.custom_minimum_size.x = width - 76
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_constant_override("line_spacing", 5)
	scroll.add_child(copy)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	for action: Dictionary in actions:
		var button := UI.button(action.label)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.pressed.connect(action.callback)
		buttons.add_child(button)
		if buttons.get_child_count() == 1:
			button.grab_focus()
	panel.modulate.a = 0
	create_tween().tween_property(panel, "modulate:a", 1.0, .18)

## Gives the first button focus again, for a controller after the mouse took it away.
func focus_first() -> void:
	for button: Button in find_children("*", "Button", true, false):
		button.grab_focus()
		return
