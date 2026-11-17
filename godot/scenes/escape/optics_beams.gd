extends Node3D
## Pooled beam segments: continuous aiming changes transforms/material references,
## never creates meshes, materials, labels or deferred frees in the update path.

const Art := preload("res://scenes/escape/optics_art.gd")
const Model := preload("res://scenes/escape/optics_model.gd")
const MAX_SEGMENTS := 24
var _materials: Dictionary = {}
var _segments: Array[MeshInstance3D] = []
var _endpoint: MeshInstance3D
var _impact: Label3D


func _ready() -> void:
	for id: int in Model.COLORS:
		_materials[id] = Art.material(Model.COLORS[id], true)
	var shape := CylinderMesh.new()
	shape.top_radius = 1.0
	shape.bottom_radius = 1.0
	shape.height = 1.0
	shape.radial_segments = 12
	for index in MAX_SEGMENTS:
		var part := MeshInstance3D.new()
		part.name = "Beam%d" % index
		part.mesh = shape
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		add_child(part)
		_segments.append(part)
	Art.line(self, Model.world(Model.SOURCE, 4.8), Model.world(Model.SOURCE), _materials[0], 0.016)
	_endpoint = Art.sphere(self, 0.045, Vector3.ZERO, _materials[0])
	_endpoint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact = Art.label(self, "", Vector3.ZERO, 20, Color(1, 0.76, 0.47), 5.0)


func draw_trace(trace: Dictionary) -> void:
	var count: int = mini(trace.segments.size(), _segments.size())
	for index in _segments.size():
		var part := _segments[index]
		part.visible = index < count
		if index >= count:
			continue
		var segment: Dictionary = trace.segments[index]
		var a := Model.world(segment.from)
		var b := Model.world(segment.to)
		var offset := b - a
		var length := offset.length()
		part.position = (a + b) * .5
		part.quaternion = Quaternion(Vector3.UP, offset / maxf(length, .0001))
		part.scale = Vector3(.014, maxf(length, .0001), .014)
		part.material_override = _materials[segment.color]
	if count == 0:
		_endpoint.hide()
		_impact.hide()
		return
	_endpoint.show()
	_endpoint.position = Model.world(trace.segments[count - 1].to)
	_endpoint.material_override = _materials[trace.color]
	_impact.position = _endpoint.position + Vector3(0, .3, 0)
	_impact.visible = trace.hit in ["obstacle", "misaligned"]
	_impact.text = "BLOCKED" if trace.hit == "obstacle" else "ALIGN INLET"
