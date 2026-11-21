extends RefCounted
## What to call a controller's face buttons on screen. Godot names them the Xbox way
## (A, B, X, Y); a PlayStation pad shows its own symbols (✕ ○ □ △) instead, so a hint
## matches the button under the player's thumb. Touch play keeps A and B, as on its pad.
##
##   PadLabels.face(JOY_BUTTON_A, device)   # "✕" on a DualSense, "A" otherwise

const XBOX := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"}
const PLAYSTATION := {JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△"}
## Lower-case pieces of a pad's reported name that mark a PlayStation controller.
const SONY_NAMES := ["dualsense", "dualshock", "playstation", "ps3", "ps4", "ps5", "sony", "054c"]  # 054c: Sony's USB vendor id


static func face(button: JoyButton, device := -1) -> String:
	return (PLAYSTATION if is_playstation(device) else XBOX).get(button, "?")


## True for a PlayStation pad. device -1 checks the first connected pad.
static func is_playstation(device := -1) -> bool:
	if device < 0:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			return false
		device = pads[0]
	var name := Input.get_joy_name(device).to_lower()
	for piece: String in SONY_NAMES:
		if piece in name:
			return true
	# Browsers report a DualSense as "DualSense Wireless Controller"; some older pads
	# only as "Wireless Controller", which is Sony's name for both.
	return name.begins_with("wireless controller")


## Lower-case pieces of a pad's reported name that mark an Xbox (or XInput) controller.
const XBOX_NAMES := ["xbox", "xinput", "microsoft", "x-box", "045e"]  # 045e: Microsoft's USB vendor id


## "playstation", "xbox", or "generic" when the pad's name says neither (or no pad).
## device -1 checks the first connected pad.
static func kind(device := -1) -> String:
	if device < 0:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			return "generic"
		device = pads[0]
	if is_playstation(device):
		return "playstation"
	var name := Input.get_joy_name(device).to_lower()
	for piece: String in XBOX_NAMES:
		if piece in name:
			return "xbox"
	return "generic"
