extends Button
## Same printed face as the physical card, with optional button behavior.
## The inspector deliberately uses this renderer instead of a second text layout.
const UI := preload("res://minigames/cards/card_ui.gd")
const Face := preload("res://minigames/cards/card_face.gd")
const ROLE_COLORS := Face.ROLE_COLORS
var _card: Dictionary = {}
var _selected := false
var _available := true
var _empty := true
var _side := "player"
var _face: Control
var _pulse_tween: Tween

func _init() -> void:
	theme = UI.Style.theme()
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := UI.Style.panel(Color.TRANSPARENT, UI.GOLD, 0)
	focus.set_border_width_all(2)
	add_theme_stylebox_override("focus", focus)
	_face = Face.new()
	add_child(_face)
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func(): _face.size = size)

func configure(card: Dictionary, _compact: bool = false) -> void:
	_card = card.duplicate(true)
	_empty = card.is_empty()
	_face.configure(_card)
	var hp: int = int(card.get("hp", card.get("health", 0)))
	tooltip_text = "%s · %s Attention\n%s" % [card.get("name", "Card"), card.get("cost", 0), card.get("description", "")]
	if card.get("kind", "unit") == "unit":
		tooltip_text += "\n%d Attack · %d Health" % [int(card.get("power", 0)), hp]
	_refresh()

func set_selected(value: bool) -> void:
	_selected = value
	_refresh()

func set_available(value: bool) -> void:
	_available = value
	_refresh()

func set_empty(value: String, side: String = "player") -> void:
	_empty = true
	_card = {}
	_side = side
	_selected = false
	_available = true
	_face.configure({}, value, side)
	_refresh()

func pulse(color: Color) -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	modulate = color
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, .3)

func _refresh() -> void:
	_face.modulate = Color.WHITE if _available else Color(.7, .7, .7)
	_face.set_highlight(_selected)
	queue_redraw()
