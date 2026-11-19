extends Node3D
## Machined optical stand; item exchange and the vernier dial remain distinct controls.

signal exchange_requested(id: String)
signal turn_requested(id: String)

const Sign := preload("res://ui/world_sign.gd")
const Art := preload("res://scenes/escape/optics_art.gd")
const Handle := preload("res://scenes/escape/optics_handle.gd")
const Model := preload("res://scenes/escape/optics_model.gd")
const CarryVisual := preload("res://scenes/escape/carry_visual.gd")

var device_id := ""
var kind := "prism"
var take_handle: Area3D
var turn_handle: Area3D
var _contents: Node3D
var _status: Label3D
var _turn_label: Label3D
var _ring: MeshInstance3D
var _alignment_ring: MeshInstance3D
var _last_item := "uninitialized"
var _rotation_tween: Tween
var _adjusting := false
var _last_angle := INF
var _alignment_state := 0
var _alignment_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	var steel := Art.material(Color(.17, .23, .28), false, true)
	var dark := Art.material(Color(.045, .065, .08), false, true)
	var brass := Art.material(Color(.68, .49, .23), false, true)
	Art.cylinder(self, .36, .10, Vector3(0, .05, 0), dark)
	Art.ring(self, .29, .35, Vector3(0, .10, 0), steel)
	Art.rounded_box(self, Vector3(.35, .72, .35), Vector3(0, .48, 0), steel, .045)
	Art.collision_box(self, Vector3(.35, .88, .35), Vector3(0, .44, 0))
	Art.rounded_box(self, Vector3(.20, .48, .035), Vector3(0, .48, .18), dark, .008)
	Art.cylinder(self, .32, .12, Vector3(0, .90, 0), brass)
	Art.cylinder(self, .30, .055, Vector3(0, .982, 0), dark)
	_alignment_materials = [Art.material(Color(.28, .45, .49), true), Art.material(Color(.9, .67, .26), true), Art.material(Color(.35, 1, .65), true)]
	_alignment_ring = Art.ring(self, .225, .242, Vector3(0, 1.013, 0), _alignment_materials[0])
	_build_ticks()
	_contents = Node3D.new()
	_contents.name = "OpticalHead"
	add_child(_contents)
	_status = Sign.tag(self, device_id + " · " + kind.to_upper(), Vector3(0, 1.63, 0), .95, Sign.GOLD, 3.0)
	if kind == "lens":
		_ring = Art.ring(self, .185, .225, Vector3(0, 1.25, 0), brass)
		_ring.quaternion = Quaternion(Vector3.UP, _lens_normal())
		Art.line(self, Vector3(-.14, .99, 0), Vector3(-.14, 1.12, 0), steel, .035)
		Art.line(self, Vector3(.14, .99, 0), Vector3(.14, 1.12, 0), steel, .035)
		take_handle = _handle("Exchange", Vector3(0, 1.04, .36), false)
	elif kind == "starter":
		turn_handle = _handle("Adjust source", Vector3(0, 1.04, .42), true)
	elif kind == "lamp":
		# A cradle for a hand lamp: two brass forks either side of the head.
		for x in [-.12, .12]:
			Art.line(self, Vector3(x, .99, 0), Vector3(x, 1.18, 0), brass, .03)
		take_handle = _handle("Exchange", Vector3(-.46, 1.0, .36), false)
		turn_handle = _handle("Aim lamp", Vector3(.46, 1.0, .36), true)
		_turn_label = Sign.tag(self, "AIM", Vector3(.46, 1.20, .36), .36, Sign.Style.TEAL, 2.8)
		Sign.tag(self, "LIFT", Vector3(-.46, 1.20, .36), .36, Sign.GOLD, 2.8)
	else:
		take_handle = _handle("Exchange", Vector3(-.46, 1.0, .36), false)
		turn_handle = _handle("Adjust prism", Vector3(.46, 1.0, .36), true)
		_turn_label = Sign.tag(self, "AIM", Vector3(.46, 1.20, .36), .36, Sign.Style.TEAL, 2.8)
		Sign.tag(self, "LIFT", Vector3(-.46, 1.20, .36), .36, Sign.GOLD, 2.8)


func _build_ticks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mark := BoxMesh.new()
	mark.size = Vector3(.012, .006, .035)
	mm.mesh = mark
	mm.instance_count = 32
	for i in 32:
		var angle := i * TAU / 32.0
		var size := Vector3(1, 1, 1.65 if i % 4 == 0 else 1.0)
		var basis := Basis(Vector3.UP, -angle).scaled(size)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(sin(angle)*.28, 1.013, cos(angle)*.28)))
	var marks := MultiMeshInstance3D.new()
	marks.multimesh = mm
	marks.material_override = Art.material(Color(.7, .72, .65), true)
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)


func _handle(text: String, at: Vector3, turn: bool) -> Area3D:
	var area := Handle.new()
	area.name = "TurnHandle" if turn else "ItemHandle"
	area.position = at
	area.prompt = text
	area.used.connect(func():
		if turn:
			turn_requested.emit(device_id)
		else:
			exchange_requested.emit(device_id))
	add_child(area)
	var mat := Art.material(Color(.35, .55, .61) if turn else Color(.60, .43, .20), false, true)
	Art.cylinder(area, .115, .065, Vector3.ZERO, mat)
	Art.ring(area, .079, .104, Vector3(0, .035, 0), Art.material(Color(.2, .27, .29), false, true))
	Art.box(area, Vector3(.022, .008, .085), Vector3(0, .041, 0), Art.material(Color(.85, .84, .7), true))
	return area


func update_state(item: String, held: String, turn: int, incoming: Vector2 = Vector2.ZERO) -> void:
	if item != _last_item:
		_last_item = item
		for child in _contents.get_children():
			_contents.remove_child(child)
			child.queue_free()
		if item == "prism" or kind == "starter":
			Art.mesh(_contents, Art.prism_mesh(), Vector3(0, 1.25, 0), Art.glass(Color(.35, .75, .88)))
			var metal := Art.material(Color(.40, .51, .56), false, true)
			Art.line(_contents, Vector3(.16, 1.25, 0), Vector3(.38, 1.25, 0), metal, .075)
			var port := Art.ring(_contents, .048, .068, Vector3(.39, 1.25, 0), Art.material(Color(.62, .83, .88), true))
			port.rotation.z = PI / 2.0
			Art.box(_contents, Vector3(.22, .012, .025), Vector3(.08, 1.028, 0), Art.material(Color(.9, .69, .32), true))
		elif item == "flashlight":
			var lamp := CarryVisual.build_item("flashlight")
			lamp.position = Vector3(0, 1.25, 0)
			lamp.rotation.y = -PI / 2.0   # Its head (-Z) faces the beam direction (+X).
			_contents.add_child(lamp)
		elif item.begins_with("lens_"):
			var tint: Color = Model.COLORS[1 if item == "lens_yellow" else 2]
			var glass := Art.cylinder(_contents, .175, .04, Vector3(0, 1.25, 0), Art.glass(tint))
			glass.quaternion = Quaternion(Vector3.UP, _lens_normal())
	if is_instance_valid(take_handle):
		var destination := "prism socket " if kind == "prism" else ("lamp socket " if kind == "lamp" else "lens mount ")
		if held.is_empty():
			take_handle.prompt = ("Take " + _item_name(item) + " from " + device_id) if not item.is_empty() else "Empty " + destination + device_id
		elif item.is_empty():
			take_handle.prompt = "Place " + _item_name(held) + " in " + device_id
		else:
			take_handle.prompt = "Swap " + _item_name(held) + " for " + _item_name(item)
	if is_instance_valid(turn_handle):
		var enabled := kind == "starter" or item == "prism" or (kind == "lamp" and item == "flashlight")
		turn_handle.collision_layer = 1 if enabled else 0
		turn_handle.visible = enabled
		if _turn_label:
			_turn_label.get_parent().visible = enabled
		turn_handle.prompt = "Adjust source" if kind == "starter" else ("Aim lamp " if kind == "lamp" else "Adjust prism ") + device_id
	var empty_name := "SOCKET" if kind == "prism" else ("LAMP SOCKET" if kind == "lamp" else "MOUNT")
	_status.text = device_id + " · " + ("SOURCE" if kind == "starter" else (empty_name if item.is_empty() else _item_name(item).to_upper()))
	Sign.fit_tag(_status)
	if incoming != Vector2.ZERO and not item.is_empty() and not _adjusting and kind != "lamp":
		var outgoing := Vector2(-incoming.y, incoming.x) * turn
		set_head_angle(atan2(outgoing.y, outgoing.x), false)


func point_source(outgoing: Vector2) -> void:
	if kind == "starter" and not _adjusting:
		set_head_angle(atan2(outgoing.y, outgoing.x), false)


func set_head_angle(angle: float, immediate := true) -> void:
	if _contents == null:
		return
	if is_finite(_last_angle) and absf(wrapf(angle - _last_angle, -PI, PI)) < .0001:
		if immediate and _rotation_tween and _rotation_tween.is_running():
			_rotation_tween.kill()
			_contents.rotation.y = angle
		return
	_last_angle = angle
	if _rotation_tween:
		_rotation_tween.kill()
	if immediate:
		_contents.rotation.y = angle
		return
	_rotation_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := _contents.rotation.y + wrapf(angle - _contents.rotation.y, -PI, PI)
	_rotation_tween.tween_property(_contents, "rotation:y", target, .18)


func set_adjusting(active: bool, snapped := false) -> void:
	_adjusting = active
	var state := 2 if active and snapped else (1 if active else 0)
	if _alignment_ring and state != _alignment_state:
		_alignment_state = state
		_alignment_ring.material_override = _alignment_materials[state]


func _lens_normal() -> Vector3:
	return Vector3.RIGHT if device_id == "J" else Vector3(1, 0, -1).normalized()


func _item_name(item: String) -> String:
	return item.replace("lens_", "") + (" lens" if item.begins_with("lens_") else "")
