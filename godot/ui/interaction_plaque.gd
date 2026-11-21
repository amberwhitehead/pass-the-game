extends VBoxContainer
## The interaction hint: a small caption just below the crosshair, such as "[Click] Talk",
## rather than a box at the bottom of the screen. While aiming the optics it says
## "ALIGN THE LIGHT" above the longer hint. Place it with place_below_center().
const Style := preload("res://ui/game_style.gd")
const MAX_WIDTH := 460.0
const GAP := 18.0  ## Pixels between the centre of the screen and the caption's top.
var key: Label
var title: Label
var detail: Label
var _last := ""

func _ready() -> void:
	theme = Style.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)
	detail = Style.eyebrow("ALIGN THE LIGHT")
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(detail)
	add_child(detail)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	add_child(row)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := Style.panel(Style.GOLD, Style.GOLD, 0)
	badge_style.set_content_margin_all(0)
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge_style.set_corner_radius_all(3)
	badge_style.shadow_size = 0
	badge.add_theme_stylebox_override("panel", badge_style)
	row.add_child(badge)
	key = Style.label("E", 12, Style.INK)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(key)
	title = Style.label("", 15, Style.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(title)
	row.add_child(title)


## Centres the caption horizontally, its top edge just below the screen's centre.
func place_below_center() -> void:
	anchor_left = .5
	anchor_right = .5
	anchor_top = .5
	anchor_bottom = .5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END
	offset_top = GAP
	offset_bottom = GAP


func present(text: String, input_key: String, aiming: bool) -> void:
	key.text = "↔" if aiming else input_key
	detail.visible = aiming
	if text == _last:
		return
	_last = text
	title.text = text
	# Short prompts stay on one line; long ones (the optics hint) wrap at MAX_WIDTH.
	var width := title.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > MAX_WIDTH else TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = MAX_WIDTH if width > MAX_WIDTH else 0.0
	reset_size()


## A dark outline keeps small text readable over bright walls.
static func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	label.add_theme_constant_override("outline_size", 5)
