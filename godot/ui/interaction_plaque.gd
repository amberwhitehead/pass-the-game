extends VBoxContainer
## The interaction hint: a small caption just below the crosshair, such as "[Click] Talk",
## rather than a box at the bottom of the screen. While aiming the optics it says
## "ALIGN THE LIGHT" above the longer hint. Place it with place_below_center().
const Style := preload("res://ui/game_style.gd")
const PadGlyph := preload("res://ui/pad_glyph.gd")
const MAX_WIDTH := 460.0
const GAP := 18.0  ## Pixels between the centre of the screen and the caption's top.
var key: Label
var title: Label
var key2: Label    ## The second action's key, hidden when there is none.
var title2: Label
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
	# Two columns, so a second action stacks under the first with the keys lined up:
	#   [R1] Adjust prism B
	#   [R2] Take prism from B
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)
	key = _badge(grid)
	title = _caption(grid)
	# A second action, such as taking a prism off the stand it can also adjust.
	key2 = _badge(grid)
	title2 = _caption(grid)


func _badge(row: Control) -> Label:
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
	var label := Style.label("E", 12, Style.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	# A controller button shows as a drawn icon instead (see set_key).
	var glyph := PadGlyph.new()
	glyph.glyph_height = 18.0
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	glyph.visible = false
	badge.add_child(glyph)
	badge.set_meta("style", badge_style)
	return label


## Shows `spec` in a key badge: a word such as "Click", or "pad:<button>:<kind>" for a
## drawn controller button (ui/pad_glyph.gd), e.g. "pad:r1:playstation".
static func set_key(label: Label, spec: String) -> void:
	var badge := label.get_parent() as PanelContainer
	# The HUD calls this every frame; only a change touches the badge, since restyling it
	# redraws and re-lays-out the whole caption (twice and four times a frame, measured).
	if badge.get_meta("spec", "") == spec:
		return
	badge.set_meta("spec", spec)
	var glyph := badge.get_child(1) as Control
	var pad := spec.begins_with("pad:")
	label.visible = not pad
	glyph.visible = pad
	badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if pad else badge.get_meta("style"))
	if pad:
		var parts := spec.split(":")
		glyph.button = parts[1]
		glyph.kind = parts[2] if parts.size() > 2 else "generic"
	else:
		label.text = spec


func _caption(row: Control) -> Label:
	var label := Style.label("", 15, Style.PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_outline(label)
	row.add_child(label)
	return label


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


func present(text: String, input_key: String, aiming: bool, text2 := "", input_key2 := "") -> void:
	set_key(key, "↔" if aiming else input_key)
	detail.visible = aiming
	var second := text2 != "" and not aiming
	key2.get_parent().visible = second
	title2.visible = second
	set_key(key2, input_key2)
	if text + "|" + text2 == _last:
		return
	_last = text + "|" + text2
	title.text = text
	title2.text = text2
	# Short prompts stay on one line; long ones (the optics hint) wrap at MAX_WIDTH.
	var width := title.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > MAX_WIDTH else TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = MAX_WIDTH if width > MAX_WIDTH else 0.0
	reset_size()


## A dark outline keeps small text readable over bright walls.
static func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	label.add_theme_constant_override("outline_size", 5)
