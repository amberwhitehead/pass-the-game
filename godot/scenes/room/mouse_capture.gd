extends CanvasLayer
## Desktop mouse look for the hall: captures the cursor while keyboard/mouse play owns the view
## and gives it back whenever a menu, a settings panel or a minigame needs a pointer.
##
## Browsers only grant pointer lock from a genuine input event and may drop it at any moment
## (Escape, switching windows), so capture is requested from input callbacks and never assumed.
## While keyboard/mouse play is waiting for it, a "click to continue" card blocks the player.
## Touch and gamepad play never need capture; the last device used decides.

const Style := preload("res://ui/game_style.gd")
## Mouse motion is ignored for a moment after capture begins: browsers can report one
## large jump as the pointer locks, which would snap the view.
const SETTLE_FRAMES := 2

var keyboard_mouse := false
var _player: Node3D
var _captured_frame := -1
var _was_captured := false
var _card: PanelContainer


func configure(player: Node3D) -> void:
	_player = player


func _ready() -> void:
	name = "MouseCapture"
	layer = 45  # Above the hall HUD, below dialogue, touch pad and menus.
	process_mode = Node.PROCESS_MODE_ALWAYS  # Releases the cursor while the hall is paused.
	keyboard_mouse = supported() and not TouchControls.button_prompts
	_build_card()
	# Resuming and leaving a minigame happen inside a click or key press, which is when a
	# browser allows capture. Deferred, so "Quit to title" has started its fade first.
	PauseMenu.closed.connect(request, CONNECT_DEFERRED)
	MiniGames.ended.connect(_on_minigame_ended, CONNECT_DEFERRED)


func _on_minigame_ended(_id: String, _result: Dictionary) -> void:
	request()


## Headless runs (tests, exports) have no cursor to capture.
static func supported() -> bool:
	return DisplayServer.get_name() != "headless"


func is_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Hall gameplay with keyboard and mouse, and nothing over it that needs a pointer.
func wants_capture() -> bool:
	return keyboard_mouse and is_instance_valid(_player) and _player.is_inside_tree() \
		and not get_tree().paused and not PauseMenu.is_open() and not Sound.settings_open \
		and not MiniGames.is_running() and not SceneManager.is_busy()


## True while keyboard/mouse play is waiting for the cursor: the player ignores input.
func blocks_input() -> bool:
	return wants_capture() and not is_captured()


## Captured long enough that mouse motion is real looking, not the lock's first report.
func look_ready() -> bool:
	return is_captured() and Engine.get_process_frames() - _captured_frame >= SETTLE_FRAMES


## Asks for capture. On the Web this only succeeds from an input callback; the card
## stays up until the browser actually grants it.
func request() -> void:
	if wants_capture() and not is_captured():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if wants_capture():
		if not is_captured() and not OS.has_feature("web"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # Desktop builds need no gesture.
	elif is_captured():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var captured := is_captured()
	if captured and not _was_captured:
		_captured_frame = Engine.get_process_frames()
	_was_captured = captured
	_card.visible = blocks_input()


func _input(event: InputEvent) -> void:
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and emulated:
		# A click on the card also arrives as emulated touch; keep it from the hall.
		if _card.visible:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		keyboard_mouse = supported()
	elif event is InputEventMouseButton and event.pressed and not emulated:
		keyboard_mouse = supported()
		if wants_capture() and not is_captured():
			request()
			get_viewport().set_input_as_handled()  # The recovery click does nothing else.
	elif event is InputEventScreenTouch or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		keyboard_mouse = false


func _exit_tree() -> void:
	if is_captured():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme = Style.theme()
	_card.add_theme_stylebox_override("panel", Style.panel(Color(Style.INK, .9), Style.GOLD.darkened(.3), 18))
	_card.anchor_left = .5
	_card.anchor_right = .5
	_card.anchor_top = .5
	_card.anchor_bottom = .5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	var title := Style.label("Click to look around", 22, Style.PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Style.label("Mouse looks  ·  WASD moves  ·  Space jumps  ·  Esc for the menu", 14, Style.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_card.visible = false
	add_child(_card)
