extends Control
## Quiet table furniture. Information stays at the edges of the playable board.
signal rules_requested
signal restart_requested
const UI := preload("res://minigames/cards/card_ui.gd")
const Card := preload("res://minigames/cards/card_view.gd")
var banter: Label
var hint: Label
var history: RichTextLabel
var restart_button: Button
var inspector: Button
var status: Label
var _log_panel: PanelContainer
var _deck: Label
var _title: Label
var collection_count := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.Style.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status()
	_build_actions()
	_build_footer()
	_build_inspector()
	_build_log()

func _build_status() -> void:
	var panel := _surface()
	panel.position = Vector2(24, 20)
	panel.custom_minimum_size.x = 322
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	_title = UI.Style.eyebrow("THE LITTLE BROTHER'S TABLE")
	column.add_child(_title)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	status = UI.label("Round 01", 24)
	status.add_theme_font_override("font", UI.Style.font(true))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	_deck = UI.label("16 cards", 13, UI.MUTED)
	_deck.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_deck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_deck)
	banter = UI.label("", 14, Color(UI.MUTED, .92))
	banter.offset_left = 40
	banter.offset_right = 438
	banter.offset_top = 141
	banter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banter.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .9))
	banter.add_theme_constant_override("shadow_offset_y", 2)
	add_child(banter)

func _build_actions() -> void:
	# A second row leaves the global sound and exit controls unobstructed.
	var actions := HBoxContainer.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -330
	actions.offset_right = -24
	actions.offset_top = 76
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	var log_button := UI.button("Journal")
	log_button.pressed.connect(func(): _log_panel.visible = not _log_panel.visible)
	actions.add_child(log_button)
	var rules := UI.button("Rules")
	rules.pressed.connect(func(): rules_requested.emit())
	actions.add_child(rules)
	restart_button = UI.button("New match")
	restart_button.pressed.connect(func(): restart_requested.emit())
	actions.add_child(restart_button)

func _build_footer() -> void:
	var footer := _surface()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 18
	footer.offset_right = -18
	footer.offset_top = -44
	footer.offset_bottom = -8
	var style := UI.Style.panel(Color(UI.INK, .94), Color(UI.GOLD, .22), 8)
	style.border_width_top = 1
	footer.add_theme_stylebox_override("panel", style)
	add_child(footer)
	hint = UI.label("", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(hint)

func _build_inspector() -> void:
	inspector = Card.new()
	inspector.position = Vector2(20, 202)
	inspector.size = Vector2(235, 313)
	inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector.focus_mode = Control.FOCUS_NONE
	inspector.visible = false
	add_child(inspector)

func _build_log() -> void:
	_log_panel = _surface()
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_log_panel.offset_left = -330
	_log_panel.offset_right = -24
	_log_panel.offset_top = 126
	_log_panel.offset_bottom = 418
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_panel.visible = false
	add_child(_log_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_log_panel.add_child(column)
	column.add_child(UI.eyebrow("THE LAST FEW MOVES"))
	history = RichTextLabel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_theme_font_override("normal_font", UI.Style.font())
	history.add_theme_font_size_override("normal_font_size", 15)
	history.add_theme_color_override("default_color", UI.PAPER)
	column.add_child(history)

func _surface() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.Style.panel(Color(UI.INK, .93), Color(UI.GOLD, .28), 16))
	return panel

func show_card(card: Dictionary) -> void:
	inspector.visible = not card.is_empty()
	if inspector.visible:
		inspector.configure(card)

func render(state: Dictionary, locked: bool) -> void:
	_title.text = "THE %s'S TABLE" % str(state.get("opponent_name", "Little Brother")).to_upper()
	status.text = "Round %02d" % state.turn
	_deck.text = "%d in deck" % state.deck_count
	if collection_count >= 0:
		_deck.text += "\n%d / 5 found" % collection_count
	restart_button.disabled = locked
