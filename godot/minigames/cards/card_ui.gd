extends RefCounted
## Card-specific colors built on the hall's shared typography and controls.
const Style := preload("res://ui/game_style.gd")
const INK := Style.INK
const PAPER := Style.PAPER
const TABLE := Color("102c32")
const PANEL := Style.PANEL
const MUTED := Style.MUTED
const GOLD := Style.GOLD
const COPPER := Color("bc7955")

static func panel(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	return Style.panel(color, border, 12)

static func label(value: String, font_size: int = 18, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_override("font", Style.font())
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(value: String) -> Button:
	var node := Button.new()
	node.theme = Style.theme()
	node.text = value
	node.custom_minimum_size.y = 38
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 15)
	return node

static func eyebrow(value: String) -> Label:
	var node := label(value, 11, GOLD)
	node.add_theme_font_override("font", Style.font(true))
	return node
