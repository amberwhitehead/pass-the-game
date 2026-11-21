extends Node3D
## Draws, for a couple of frames as the hall opens, a speck of each material that is
## otherwise first drawn mid-play: the focus outline (both passes) and the objective
## console's laser beam and spot. The Web build (GL Compatibility) compiles a shader the
## first time something uses it, which shows as a hitch the first time you look at
## anything or ask the console the way; this moves that work into the fade-in.
##
## The specks are a millimetre across, just past the camera's near plane, low in the
## corner behind the left hand, and gone after FRAMES frames.

const ObjectiveConsole := preload("res://scenes/escape/objective_console.gd")
const FRAMES := 3

var _frames := 0


static func add_to(camera: Camera3D) -> Node3D:
	var warm := new()
	warm.name = "ShaderWarmup"
	camera.add_child(warm)
	return warm


func _ready() -> void:
	position = Vector3(-0.12, -0.12, -0.3)
	var materials: Array = [
		null,  # A plain speck carrying the focus outline as its overlay.
		ObjectiveConsole._glow(ObjectiveConsole.BEAM_COLOR),
		ObjectiveConsole._glow(ObjectiveConsole.BEAM_COLOR, true),
	]
	for i in materials.size():
		var speck := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.001
		speck.mesh = box
		speck.position = Vector3(i * 0.002, 0, 0)
		speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if materials[i] == null:
			speck.material_overlay = Interactable.focus_outline_material()
		else:
			speck.material_override = materials[i]
		add_child(speck)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()
