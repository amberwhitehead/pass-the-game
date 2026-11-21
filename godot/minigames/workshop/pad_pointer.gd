extends Node
## A gamepad-driven pointer for the Workshop's point-and-click scene.
##
## The left stick (or D-pad, for fine nudges) moves `position`, in stage coordinates.
## A web page can't move the real mouse pointer, so the Workshop reads its pointer from
## here while `active`, and from the mouse otherwise. Stick movement turns it on; moving
## or clicking the mouse turns it off again. Any connected pad works, since browsers
## often report a pad in a later slot than 0.

const DEADZONE := 0.2
const STICK_SPEED := 1100.0  ## Stage pixels per second at full tilt.
const DPAD_SPEED := 320.0    ## Slower, for lining up small things.
const CURVE := 1.7           ## >1 gives finer control near the centre of the stick.

var active := false
var position := Vector2.ZERO
var bounds := Rect2(0, 0, 1600, 900)
## Returns the mouse position in stage coordinates; where the pointer starts from.
var mouse_position: Callable = func() -> Vector2: return position


func _process(delta: float) -> void:
	var v := _velocity(_stick(), _dpad())
	if v == Vector2.ZERO:
		return
	if not active:
		activate()
	position = (position + v * delta).clamp(bounds.position, bounds.end)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		active = false
	elif event is InputEventMouseButton and event.pressed:
		active = false


## Switches to the pad, starting from wherever the mouse is.
func activate() -> void:
	if active:
		return
	active = true
	position = (mouse_position.call() as Vector2).clamp(bounds.position, bounds.end)


## Pointer speed for a stick reading and a D-pad direction; the stick wins when pushed.
static func _velocity(stick: Vector2, dpad: Vector2) -> Vector2:
	var m := stick.length()
	if m > DEADZONE:
		var t := clampf((m - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		return stick / m * pow(t, CURVE) * STICK_SPEED
	if dpad != Vector2.ZERO:
		return dpad.normalized() * DPAD_SPEED
	return Vector2.ZERO


## The strongest left-stick reading across connected pads.
static func _stick() -> Vector2:
	var best := Vector2.ZERO
	for d in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if s.length_squared() > best.length_squared():
			best = s
	return best


static func _dpad() -> Vector2:
	var v := Vector2.ZERO
	for d in Input.get_connected_joypads():
		v.x += float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT))
		v.y += float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP))
	return v.clamp(Vector2(-1, -1), Vector2(1, 1))
