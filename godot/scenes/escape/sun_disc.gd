extends Node3D
## The sun disc inside Egypt's room, on its east wall: a bronze disc that wants sunlight. Dark until the 1955 flashlight's beam reaches it through the yellow
## lens; then it blazes, and Egypt's room has its light back (autoload/time_link.gd).

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")
const HEIGHT := 1.25

var lit := false
var _disc: MeshInstance3D
var _dark: StandardMaterial3D
var _wrong: StandardMaterial3D
var _bright: StandardMaterial3D
var _glow: OmniLight3D
var _label: Label3D


func _ready() -> void:
	name = "SunDisc"
	var bronze := Geometry.material(Color("8c6a3a"), 0.8)
	# A backing plate on the wall, then the rayed disc facing into the hall (+Z).
	var plate := Geometry.box(self, Vector3(0, HEIGHT, -0.06), Vector3(0.9, 0.9, 0.05), Geometry.material(Color("2a2016"), 0.3))
	plate.name = "Plate"
	for k in 12:
		var ray := Geometry.box(self, Vector3(0, HEIGHT, -0.02), Vector3(0.05, 0.78, 0.03), bronze)
		ray.rotation.z = PI * k / 12.0
	_dark = Geometry.material(Color("3a2c1a"), 0.6)
	_wrong = Geometry.material(Color("8a7a60"), 0.4, 0.6)
	_bright = Geometry.material(Color("ffcf4a"), 0.2, 2.6)
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.26
	cyl.bottom_radius = 0.26
	cyl.height = 0.06
	cyl.radial_segments = 32
	_disc.mesh = cyl
	_disc.rotation.x = PI / 2.0
	_disc.position = Vector3(0, HEIGHT, 0.01)
	_disc.material_override = _dark
	add_child(_disc)
	_glow = OmniLight3D.new()
	_glow.light_color = Color("ffcf4a")
	_glow.light_energy = 0.0
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, HEIGHT, 0.5)
	add_child(_glow)
	_label = Sign.tag(self, "SUNLIGHT REQUIRED", Vector3(0, HEIGHT + 0.62, 0.05), 1.1, Sign.GOLD, 3.0)


## Lit by sunlight, or (wrong) touched by a beam of some other colour.
func set_lit(value: bool, wrong := false) -> void:
	lit = value
	if _disc == null:
		return
	_disc.material_override = _bright if value else (_wrong if wrong else _dark)
	_glow.light_energy = 1.6 if value else 0.0
	_label.text = "SUN RESTORED" if value else "SUNLIGHT REQUIRED"
	Sign.fit_tag(_label)
