extends PanelContainer
## One quiet interaction surface. Stable width avoids jumping while the beam moves.
const Style := preload("res://ui/game_style.gd")
var key: Label
var title: Label
var detail: Label
var _last := ""

func _ready() -> void:
	theme = Style.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Style.panel(Color(.055, .09, .105, .96), Style.GOLD.darkened(.35), 16))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Style.panel(Style.GOLD, Style.GOLD, 8))
	row.add_child(badge)
	key = Style.label("E", 18, Style.INK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(key)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	row.add_child(column)
	detail = Style.eyebrow("INTERACT")
	column.add_child(detail)
	title = Style.label("", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

func present(text: String, input_key: String, aiming: bool) -> void:
	key.text = "↔" if aiming else input_key
	detail.text = "ALIGN THE LIGHT" if aiming else "INTERACT"
	if text == _last:
		return
	_last = text
	title.text = text
