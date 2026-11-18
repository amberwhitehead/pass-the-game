extends CanvasLayer
## Small global mixer, usable during paused-world card encounters as well as the hub.
const Style := preload("res://ui/game_style.gd")
var _panel: PanelContainer
var _arrival: Tween
var _veil: ColorRect
var _button: Button

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.theme = Style.theme()
	_button.text = "Sound"
	_button.add_theme_font_size_override("font_size", 14)
	_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 170
	_button.offset_right = 250
	_button.offset_top = 18
	_button.offset_bottom = 56
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func(): _toggle(true))
	add_child(_button)
	_veil = ColorRect.new()
	_veil.theme = Style.theme()
	_veil.color = Color(Style.INK, .86)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	var panel := PanelContainer.new()
	_panel = panel
	panel.add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Style.GOLD.darkened(.4), 0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -236
	panel.offset_bottom = 236
	_veil.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	column.add_child(Style.eyebrow("PREFERENCES"))
	column.add_child(Style.label("Sound & atmosphere", 28, Style.PAPER, true))
	var description := Style.label("Find your balance in the hall.", 15, Style.MUTED)
	column.add_child(description)
	column.add_child(HSeparator.new())
	for bus in ["Master", "Effects", "Ambience"]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = bus
		label.custom_minimum_size.x = 100
		label.add_theme_font_size_override("font_size", 16)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = bus
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = Sound.mixer.levels[bus] * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_slider(slider)
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 44
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 14)
		value.add_theme_color_override("font_color", Style.GOLD)
		value.text = "%d%%" % slider.value
		row.add_child(value)
		slider.value_changed.connect(func(level: float):
			Sound.mixer.set_level(bus, level / 100.0)
			value.text = "%d%%" % level)
	var mute := Button.new()
	mute.toggle_mode = true
	mute.custom_minimum_size.y = 40
	mute.text = "Mute all sound"
	mute.button_pressed = Sound.mixer.muted or Sound.mixer.forced_mute
	mute.disabled = Sound.mixer.forced_mute
	mute.text = "Sound muted" if mute.button_pressed else "Sound enabled"
	mute.toggled.connect(func(value: bool):
		Sound.mixer.set_muted(value)
		mute.text = "Sound muted" if value else "Sound enabled")
	column.add_child(mute)
	var preview := Button.new()
	preview.text = "Listen to a few effects"
	preview.custom_minimum_size.y = 40
	preview.pressed.connect(func():
		Sound.play("card_place", self)
		Sound.play("pickup", self, -4)
		Sound.play("dial_grab", self, -5))
	column.add_child(preview)
	var close := Button.new()
	close.text = "Back to game  ›"
	close.custom_minimum_size.y = 44
	close.pressed.connect(func(): _toggle(false))
	column.add_child(close)
	_veil.hide()

func open() -> void:
	_toggle(true)

func _toggle(open: bool) -> void:
	Sound.settings_open = open
	_veil.visible = open
	_button.visible = not open
	if _arrival:
		_arrival.kill()
	if open:
		_panel.modulate.a = 0.0
		_arrival = create_tween()
		_arrival.tween_property(_panel, "modulate:a", 1.0, .16)
	else:
		Sound.mixer.save()

func _input(event: InputEvent) -> void:
	if _veil.visible and event.is_action_pressed("back"):
		_toggle(false)
		get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if _veil.visible:
		get_viewport().set_input_as_handled()

func _style_slider(slider: HSlider) -> void:
	var track := Style.panel(Style.INK, Color.TRANSPARENT, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.shadow_size = 0
	slider.add_theme_stylebox_override("slider", track)
	var fill := Style.panel(Style.GOLD.darkened(.15), Color.TRANSPARENT, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	fill.shadow_size = 0
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in 18:
		for y in 18:
			if Vector2(x - 8.5, y - 8.5).length() < 7:
				image.set_pixel(x, y, Style.PAPER)
	var texture := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber", texture)
	slider.add_theme_icon_override("grabber_highlight", texture)
