extends CanvasLayer
## Screen-space exhibit guide. The same brass/enamel vocabulary lives on world signs.
const Style := preload("res://ui/game_style.gd")
const Plaque := preload("res://ui/interaction_plaque.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const PadLabels := preload("res://autoload/pad_labels.gd")
var _player: Player
var _inventory: Node
var _prompt: Control  ## The small interaction caption below the crosshair.
var _notice: Label
var _notice_panel: PanelContainer
var _notice_time := 0.0
var _aiming := false
var _aim_hint := ""
var _interact_key := "E"  ## "E" after keyboard input, "pad" after a controller, "touch" after touch.
var _pad_device := -1
var _crosshair: Label

func configure(player: Player, inventory: Node) -> void:
	_player = player
	_inventory = inventory

func _ready() -> void:
	layer = 5
	# The objective lives on the console by the entrance (objective_console.gd).
	_prompt = Plaque.new()
	add_child(_prompt)
	_prompt.place_below_center()
	_prompt.hide()
	_notice_panel = _panel(Vector2(.28, .88), Vector2(.72, .88))
	_notice_panel.add_theme_stylebox_override("panel", Style.panel(Color(.07, .12, .13, .96), Style.TEAL.darkened(.35), 14))
	_notice = Style.label("", 16)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_panel.add_child(_notice)
	_notice_panel.hide()
	_crosshair = Style.label("·", 28, Style.PAPER)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -5
	_crosshair.offset_top = -20
	add_child(_crosshair)

func _process(delta: float) -> void:
	var target := _player.target
	var show_prompt := not Sound.settings_open and not Dialogue.active and (_aiming or (is_instance_valid(target) and not _player._frozen()))
	_prompt.visible = show_prompt
	if show_prompt:
		var keyboard := _interact_key == "E"
		var a := _button(JOY_BUTTON_A)
		var text: String = target.prompt if not _aiming else _aim_hint.format({
			"turn": "Drag / %s %s" % [KeyBindings.label("strafe_left"), KeyBindings.label("strafe_right")] if keyboard else "◀ ▶",
			"interact": KeyBindings.labels("interact", 2) if keyboard else a,
			"back": KeyBindings.label("back") if keyboard else _button(JOY_BUTTON_B),
		})
		_prompt.present(text, _interact_label(), _aiming)
		_prompt.modulate.a = move_toward(_prompt.modulate.a, 1, delta * 8)
	else:
		_prompt.modulate.a = 0
	_crosshair.visible = not _player._frozen()
	_crosshair.modulate = Style.GOLD if is_instance_valid(target) else Color(1, 1, 1, .55)
	_notice_time = maxf(0, _notice_time - delta)
	# Conversations use the bottom of the screen too; notices wait until they end.
	_notice_panel.visible = _notice_time > 0 and not Sound.settings_open and not Dialogue.active
	_notice_panel.modulate.a = minf(1, _notice_time)

func set_aiming(active: bool, hint: String) -> void:
	_aiming = active
	_aim_hint = hint

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_interact_key = "E"
	elif (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		# Only a real press or push: a resting stick's drift sends tiny motions too,
		# which used to flip the prompt between keyboard and controller.
		_interact_key = "pad"
		_pad_device = event.device
	elif event is InputEventScreenTouch and event.device != -1:
		_interact_key = "touch"


## The interact prompt's badge: Click with mouse and keyboard, L1 on a controller
## (✕, R1 and R2 work too), A on the touch pad.
func _interact_label() -> String:
	match _interact_key:
		"pad":
			return "L1"
		"touch":
			return "A"
	return "Click"


## A face button's name for the last input: the controller's own symbol, or the touch
## pad's letter.
func _button(button: JoyButton) -> String:
	return PadLabels.face(button, _pad_device) if _interact_key == "pad" else PadLabels.XBOX[button]

func notify(text: String, duration := 5.0) -> void:
	_notice.text = text
	_notice_time = duration


func _panel(from: Vector2, to: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = Style.theme()
	panel.anchor_left = from.x
	panel.anchor_top = from.y
	panel.anchor_right = to.x
	panel.anchor_bottom = to.y
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Style.panel(Color(.055, .09, .105, .92), Color("536055"), 16))
	add_child(panel)
	return panel
