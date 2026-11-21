extends Node
## R1 acts as A (Cross): it confirms and interacts everywhere A does, because each press
## is re-sent as an A press from the same pad. Code that checks for A, or for the
## interact / ui_accept actions, needs no changes. (R2 is the second action and L1 jumps;
## see game.gd.)
##
## A re-sent press also shows up in polled Input.is_joy_button_pressed, so a minigame that
## gives R1 its own meaning sets `pad_aliases = false` (Chrono Raider: R1 changes gear)
## and the alias stays off while it runs.

const ALIASES := [JOY_BUTTON_RIGHT_SHOULDER]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Menus pause the tree.


func _input(event: InputEvent) -> void:
	if is_instance_valid(MiniGames.current) and not MiniGames.current.pad_aliases:
		return
	if event is InputEventJoypadButton and event.button_index in ALIASES:
		_send_a(event.device, event.pressed)


func _send_a(device: int, pressed: bool) -> void:
	var a := InputEventJoypadButton.new()
	a.device = device
	a.button_index = JOY_BUTTON_A
	a.pressed = pressed
	a.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(a)
