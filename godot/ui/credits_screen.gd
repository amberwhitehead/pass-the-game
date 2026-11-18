extends CanvasLayer
## Credits, opened from the title screen and the pause menu. One scrolling page of who
## made what (ui/credits.gd), with Back. Escape (ui_cancel) also goes back. It consumes
## input while open, so the menu beneath keeps its own state: a paused game stays paused.

const Style := preload("res://ui/game_style.gd")
const Credits := preload("res://ui/credits.gd")

signal closed

var back_button: Button
var text: RichTextLabel
var _veil: ColorRect


func _ready() -> void:
	layer = 116  # Above the pause menu (110) and Controls (115), below Sound settings.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.theme = Style.theme()
	_veil.color = Color(Style.INK, .92)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Style.GOLD.darkened(.4), 26))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(Style.eyebrow("Pass The Game"))
	column.add_child(Style.label("Credits", 28, Style.PAPER, true))
	column.add_child(HSeparator.new())
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = true
	text.focus_mode = Control.FOCUS_ALL  # Arrow keys and Page Up/Down scroll it.
	text.custom_minimum_size = Vector2(668, 380)
	text.add_theme_font_override("normal_font", Style.font())
	text.add_theme_font_override("bold_font", Style.font(true))
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 19)
	text.add_theme_color_override("default_color", Style.PAPER)
	text.text = page()
	column.add_child(text)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.add_theme_font_size_override("font_size", 18)
	back_button.pressed.connect(close)
	column.add_child(back_button)
	text.focus_neighbor_bottom = text.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(text)
	_veil.hide()


## The whole page as BBCode, built from ui/credits.gd.
static func page() -> String:
	var gold := Style.GOLD.to_html(false)
	var muted := Style.MUTED.to_html(false)
	var lines: PackedStringArray = []
	lines.append("[color=#%s]CONTRIBUTORS[/color]\n" % gold)
	for entry: Dictionary in Credits.CONTRIBUTORS:
		lines.append("[b]%s[/b]  [color=#%s]%s[/color]\n%s\n" % [entry.name, muted, entry.role, entry.work])
	lines.append("[color=#%s]WITH THANKS TO[/color]\n" % gold)
	for entry: Dictionary in Credits.ACKNOWLEDGMENTS:
		lines.append("[b]%s[/b]\n%s\n" % [entry.name, entry.work])
	return "\n".join(lines)


func is_open() -> bool:
	return _veil.visible


func open() -> void:
	text.scroll_to_line(0)
	_veil.show()
	text.grab_focus()


func close() -> void:
	if not is_open():
		return
	_veil.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(_event: InputEvent) -> void:
	if is_open():
		get_viewport().set_input_as_handled()  # Nothing beneath reacts while Credits is up.
