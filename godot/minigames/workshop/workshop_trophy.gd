extends Node3D
## What the Workshop leaves on its platform once won: the Futurescope, still glowing, and
## Fuse sitting in his box. Units are the platform model's (surface at y = 0).

const Geometry := preload("res://scenes/escape/hub_geometry.gd")


static func build(_result: Dictionary) -> Node3D:
	var t := new()
	t._make()
	t.scale = Vector3.ONE * 2.2
	return t


func _make() -> void:
	var wood := Geometry.material(Color("8b5a36"))
	var dark := Geometry.material(Color("2a2622"))
	var chrome := Geometry.material(Color("c7cfd0"), 0.8)
	var screen := Geometry.material(Color("5fc8c0"), 0.0, 0.7)
	var cardboard := Geometry.material(Color("c49a62"))
	var ginger := Geometry.material(Color("d9833a"))
	# The Futurescope.
	var tv := Node3D.new()
	tv.position = Vector3(-0.32, 0, 0)
	tv.rotation.y = 0.25
	add_child(tv)
	Geometry.box(tv, Vector3(0, 0.3, 0), Vector3(0.72, 0.56, 0.46), wood)
	Geometry.box(tv, Vector3(-0.07, 0.31, 0.225), Vector3(0.5, 0.4, 0.02), dark)
	Geometry.box(tv, Vector3(-0.07, 0.31, 0.24), Vector3(0.44, 0.33, 0.02), screen)
	for k in 2:
		Geometry.box(tv, Vector3(0.27, 0.42 - k * 0.14, 0.235), Vector3(0.08, 0.08, 0.03), chrome)
	for side in [-1.0, 1.0]:
		var ear := Geometry.box(tv, Vector3(side * 0.12, 0.76, 0), Vector3(0.02, 0.42, 0.02), chrome)
		ear.rotation.z = side * -0.45
	var glow := OmniLight3D.new()
	glow.light_color = Color("8fe8e0")
	glow.light_energy = 0.6
	glow.omni_range = 1.2
	glow.position = Vector3(-0.07, 0.31, 0.5)
	tv.add_child(glow)
	# Fuse in his box.
	var box := Node3D.new()
	box.position = Vector3(0.42, 0, 0.12)
	box.rotation.y = -0.3
	add_child(box)
	Geometry.box(box, Vector3(0, 0.17, 0), Vector3(0.42, 0.34, 0.42), cardboard)
	for side in [-1.0, 1.0]:
		var flap := Geometry.box(box, Vector3(side * 0.27, 0.36, 0), Vector3(0.16, 0.02, 0.4), cardboard)
		flap.rotation.z = side * 0.6
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.27
	head.mesh = sphere
	head.material_override = ginger
	head.position = Vector3(0, 0.42, 0.04)
	box.add_child(head)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.09, 0.11, 0.04)
		ear.mesh = prism
		ear.material_override = ginger
		ear.position = Vector3(side * 0.08, 0.56, 0.04)
		ear.rotation.z = side * -0.25
		box.add_child(ear)
	# The sardine-tin lid, still on his ear.
	var lid := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.01
	lid.mesh = disc
	lid.material_override = chrome
	lid.position = Vector3(0.1, 0.62, 0.04)
	lid.rotation.z = -0.6
	box.add_child(lid)
