extends RefCounted
## Trophy for the Observatory: a brass plate engraved with a sigil.

static func build(result: Dictionary) -> Node3D:
	var root := Node3D.new()
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.2, 0.08, 1.2)
	plate.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.3)
	mat.metallic = 0.7
	mat.roughness = 0.3
	plate.material_override = mat
	root.add_child(plate)
	# a small sigil mark on top
	var mark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	mark.mesh = sm
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.3, 0.6, 1.0)
	m2.emission_enabled = true
	m2.emission = Color(0.3, 0.6, 1.0)
	m2.emission_energy_multiplier = 1.5
	mark.material_override = m2
	mark.position = Vector3(0, 0.15, 0)
	root.add_child(mark)
	return root
