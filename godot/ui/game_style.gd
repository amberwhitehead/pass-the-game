extends RefCounted
## Shared exhibit-house identity for screen furniture and physical signs.
## Warm paper, aged brass and enamel; use accent color for meaning, not every word.
const INK := Color("101b20")
const PANEL := Color("18282d")
const PAPER := Color("f0e8d7")
const MUTED := Color("a2b6b4")
const GOLD := Color("d6b577")
const TEAL := Color("75b9ac")
const BODY := preload("res://assets/fonts/DejaVuSans.ttf")
static var _theme: Theme
const HEADING := preload("res://assets/fonts/LibreBaskerville.ttf")

static func font(heading := false) -> Font:
	if not heading:
		return BODY
	return HEADING

static func panel(bg: Color = PANEL, edge: Color = Color("50605b"), padding := 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, .01, .015, .30)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 4)
	return style

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font()
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", PAPER)
	_theme.set_color("default_color", "RichTextLabel", PAPER)
	_theme.set_stylebox("panel", "PanelContainer", panel())
	_theme.set_constant("separation", "VBoxContainer", 10)
	_theme.set_constant("separation", "HBoxContainer", 12)
	for kind in ["Button", "CheckButton", "OptionButton"]:
		_theme.set_color("font_color", kind, PAPER)
		_theme.set_color("font_hover_color", kind, Color("fff5db"))
		_theme.set_color("font_pressed_color", kind, GOLD)
		_theme.set_color("font_disabled_color", kind, Color("647570"))
		_theme.set_stylebox("normal", kind, panel(Color("203237"), Color("4d625e"), 12))
		_theme.set_stylebox("hover", kind, panel(Color("2c4144"), GOLD, 12))
		_theme.set_stylebox("pressed", kind, panel(INK, GOLD, 12))
		_theme.set_stylebox("disabled", kind, panel(Color("182429"), Color("33423e"), 12))
		var focus := panel(Color.TRANSPARENT, GOLD, 0)
		focus.set_border_width_all(2)
		focus.shadow_size = 0
		_theme.set_stylebox("focus", kind, focus)
	var line := StyleBoxLine.new()
	line.color = Color("53635b")
	line.thickness = 1
	_theme.set_stylebox("separator", "HSeparator", line)
	_theme.set_stylebox("panel", "TooltipPanel", panel(INK, GOLD, 12))
	_theme.set_color("font_color", "TooltipLabel", PAPER)
	_theme.set_font_size("font_size", "TooltipLabel", 16)
	for axis in ["VScrollBar", "HScrollBar"]:
		var track := panel(INK, Color.TRANSPARENT, 3)
		track.shadow_size = 0
		_theme.set_stylebox("scroll", axis, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var thumb := panel(GOLD.darkened(.35) if state == "grabber" else GOLD, Color.TRANSPARENT, 3)
			thumb.shadow_size = 0
			_theme.set_stylebox(state, axis, thumb)
	return _theme

static func label(text: String, size := 18, color: Color = PAPER, heading := false) -> Label:
	var result := Label.new()
	result.text = text
	result.theme = theme()
	result.add_theme_font_override("font", font(heading))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func eyebrow(text: String, color: Color = GOLD) -> Label:
	return label(text.to_upper(), 12, color, false)
