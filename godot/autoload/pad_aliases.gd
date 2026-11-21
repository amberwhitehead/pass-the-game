extends Node
## Extra controller buttons that act as A (Cross): R1 and R2 confirm and interact
## everywhere A does, because each press is re-sent as an A press from the same pad.
## Code that checks for A, or for the interact / ui_accept actions, needs no changes.
##
## A re-sent press also shows up in polled Input.is_joy_button_pressed, so a minigame that
## gives R1/R2 their own meaning sets `pad_aliases = false` (Chrono Raider: R1 gear, R2
## fire) and the aliases stay off while it runs.

const ALIASES := [JOY_BUTTON_RIGHT_SHOULDER]
const TRIGGER_ON := 0.6    ## R2 travel that counts as a press...
const TRIGGER_OFF := 0.3   ## ...and as a release (hysteresis, so a half press doesn't chatter).

var _trigger_down := {}    ## device -> R2 currently counted as pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Menus pause the tree.


func _input(event: InputEvent) -> void:
	if is_instance_valid(MiniGames.current) and not MiniGames.current.pad_aliases:
		return
	if event is InputEventJoypadButton and event.button_index in ALIASES:
		_send_a(event.device, event.pressed)
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
		var down: bool = _trigger_down.get(event.device, false)
		if not down and event.axis_value >= TRIGGER_ON:
			_trigger_down[event.device] = true
			_send_a(event.device, true)
		elif down and event.axis_value <= TRIGGER_OFF:
			_trigger_down[event.device] = false
			_send_a(event.device, false)


func _send_a(device: int, pressed: bool) -> void:
	var a := InputEventJoypadButton.new()
	a.device = device
	a.button_index = JOY_BUTTON_A
	a.pressed = pressed
	a.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(a)
