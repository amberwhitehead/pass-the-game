extends MiniGame
## The Observatory's Aetheric Sigil Press.
##
## A brass instrument: aim the telescope (azimuth/elevation/focus) at a drifting
## strange attractor until it resolves; open the aether valves (flow) within
## tolerance; turn the layer crank to solidify clean layers; then pull the
## inscription lever to capture the sigil as a plate. Five distinct sigils to
## collect; collecting all wins the game.
##
## View: orbit camera around the table (A/D). When in front of a control, E/R1
## grabs it; A/D turns it; E/R1 releases. Buttons (inscribe) trigger on press.

const Math := preload("res://minigames/observatory/observatory_math.gd")
const LAYERS := Math.LAYERS
const SIGIL_COUNT := Math.SIGIL_COUNT

const TABLE_R := 2.4
const APRON_R := 3.4
const CAM_R := 5.6
const CAM_H := 3.9
const ORBIT_SPEED := 1.1
const FOCUS_ARC := 0.32
const ADJUST_TIME := 2.6
const RAMP_TIME := 1.0

var _theta := 0.0
var _grabbed := -1
var _focus := -1
var _table_mat: StandardMaterial3D
var _model: Node3D
var _camera: Camera3D
var _hud: Control
var _hud_text: Label
var _moving := false
var _grab_hold := 0.0
var _time := 0.0

# state
var _sigil_target := 0
var _az := 0.0
var _el := 0.0
var _focusv := 0.5
var _v1 := 0.5
var _v2 := 0.5
var _layer := 0
var _plate: Array = []  # bool per layer
var _collected: Array = []  # bool per sigil
var _solved := false
var _inscribing := false

# controls list: id, label, min, max, def, angle, type ("knob"/"button"), value
var _controls := [
	{"id": "sigil", "label": "Sigil", "min": 0.0, "max": float(SIGIL_COUNT - 1), "def": 0.0, "angle": 5.6, "type": "knob", "step": 1.0},
	{"id": "az", "label": "Azimuth", "min": -PI, "max": PI, "def": 0.0, "angle": 4.6, "type": "knob", "wrap": true},
	{"id": "el", "label": "Elevation", "min": -1.2, "max": 1.2, "def": 0.0, "angle": 3.9, "type": "knob"},
	{"id": "focus", "label": "Focus", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 3.2, "type": "knob"},
	{"id": "v1", "label": "Valve A", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 2.4, "type": "knob"},
	{"id": "v2", "label": "Valve B", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 1.7, "type": "knob"},
	{"id": "crank", "label": "Crank", "min": 0.0, "max": 1.0, "def": 0.0, "angle": 1.0, "type": "knob", "wrap": true},
	{"id": "inscribe", "label": "Inscribe", "min": 0.0, "max": 1.0, "def": 0.0, "angle": 0.3, "type": "button"},
	{"id": "reset", "label": "Reset", "angle": 0.0, "type": "button"},
]

var _control_nodes := {}  # id -> Node3D
var _attractor_mesh: MultiMeshInstance3D
var _attractor_mat: StandardMaterial3D
var _plate_mesh: MeshInstance3D
var _plate_mat: StandardMaterial3D
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _world: Node3D
var _env_node: WorldEnvironment


func _ready() -> void:
	use_touch_controls = true
	_collected.resize(SIGIL_COUNT)
	for i in SIGIL_COUNT:
		_collected[i] = false
	_plate.resize(LAYERS)
	for i in LAYERS:
		_plate[i] = false
	_build_world()
	_build_hud()
	super()
	# init values
	for c in _controls:
		if c.has("def"):
			c["value"] = c.def
	# resume
	_resume(resume_state)
	_update_camera(1.0)
	_refresh_visuals()


func _resume(state: Dictionary) -> void:
	_sigil_target = int(state.get("sigil_target", _sigil_target))
	_az = float(state.get("az", _az))
	_el = float(state.get("el", _el))
	_focusv = float(state.get("focus", _focusv))
	_v1 = float(state.get("v1", _v1))
	_v2 = float(state.get("v2", _v2))
	_layer = int(state.get("layer", _layer))
	var plate: Array = state.get("plate", [])
	for i in LAYERS:
		_plate[i] = bool(plate[i]) if i < plate.size() else false
	var coll: Array = state.get("collected", [])
	for i in SIGIL_COUNT:
		_collected[i] = bool(coll[i]) if i < coll.size() else false
	_solved = bool(state.get("solved", _solved))
	# sync control values
	for c in _controls:
		match c.id:
			"sigil": c["value"] = float(_sigil_target)
			"az": c["value"] = _az
			"el": c["value"] = _el
			"focus": c["value"] = _focusv
			"v1": c["value"] = _v1
			"v2": c["value"] = _v2


func save_state() -> Dictionary:
	if _solved:
		return {}
	return {
		"sigil_target": _sigil_target,
		"az": _az, "el": _el, "focus": _focusv,
		"v1": _v1, "v2": _v2,
		"layer": _layer, "plate": _plate.duplicate(),
		"collected": _collected.duplicate(), "solved": _solved,
	}


func _process(delta: float) -> void:
	if Sound.settings_open:
		return
	_time += delta
	var steer := 0.0
	if _grabbed >= 0:
		steer = clampf(Input.get_axis("move_left", "move_right") + Input.get_axis("strafe_left", "strafe_right"), -1.0, 1.0)
		var c: Dictionary = _controls[_grabbed]
		_moving = steer != 0.0
		_grab_hold = _grab_hold + delta if _moving else 0.0
		var speed := lerpf(0.12, 1.0, clampf(_grab_hold / RAMP_TIME, 0.0, 1.0))
		var span: float = float(c.max) - float(c.min)
		if span <= 0.0:
			span = 1.0
		var v: float = float(c.get("value", 0.0)) + steer * speed * span / ADJUST_TIME * delta
		# crank full-turn detection
		if c.id == "crank":
			var oldv: float = float(c.value)
			c.value = wrapf(v, 0.0, 1.0)
			if oldv > 0.85 and c.value < 0.15 and steer > 0.0:
				_advance_layer()
		else:
			c.value = clampf(v, float(c.min), float(c.max))
			_sync_state_from_controls()
		if c.id == "sigil":
			c.value = roundf(c.value)
			_sigil_target = int(c.value)
			_sync_state_from_controls()
	else:
		steer = clampf(Input.get_axis("move_left", "move_right") + Input.get_axis("strafe_left", "strafe_right"), -1.0, 1.0)
		if steer != 0.0:
			_theta -= steer * ORBIT_SPEED * delta
	_moving = steer != 0.0 if _grabbed >= 0 else false
	_update_camera(delta)
	_refresh_visuals()
	if not _solved and _all_collected():
		_solved = true
		finish({"won": true})


func _back_leaves() -> bool:
	return _solved

func _all_collected() -> bool:
	for c in _collected:
		if not bool(c):
			return false
	return true


func _sync_state_from_controls() -> void:
	for c in _controls:
		match c.id:
			"az": _az = float(c.value)
			"el": _el = float(c.value)
			"focus": _focusv = float(c.value)
			"v1": _v1 = float(c.value)
			"v2": _v2 = float(c.value)
			"sigil":
				_sigil_target = int(roundf(float(c.value)))


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	super(event)
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _grabbed >= 0:
		_grabbed = -1
		_grab_hold = 0.0
		return
	if _focus >= 0:
		var c = _controls[_focus]
		if c.type == "button":
			_press_button(c)
		else:
			_grabbed = _focus
			_grab_hold = 0.0


func delta_turn() -> float:
	return 0.05


func _interact() -> void:
	if _grabbed >= 0:
		# release
		_grabbed = -1
		_moving = false
		return
	# find focused control
	if _focus >= 0:
		var c = _controls[_focus]
		if c.type == "button":
			_press_button(c)
		else:
			_grabbed = _focus
			_moving = false


func _press_button(c: Dictionary) -> void:
	if c.id == "inscribe":
		_try_inscribe()
	elif c.id == "reset":
		_reset_state()


func _turn_control(c: Dictionary, amount: float) -> void:
	var id: String = c.id
	match id:
		"sigil":
			var v: float = c.value + amount * c.get("step", 1.0)
			v = clampf(v, c.min, c.max)
			# snap to integer
			v = roundf(v)
			c.value = v
			_sigil_target = int(v)
		"az":
			c.value = wrapf(c.value + amount, c.min, c.max)
			_az = c.value
		"el":
			c.value = clampf(c.value + amount, c.min, c.max)
			_el = c.value
		"focus":
			c.value = clampf(c.value + amount, c.min, c.max)
			_focusv = c.value
		"v1":
			c.value = clampf(c.value + amount, c.min, c.max)
			_v1 = c.value
		"v2":
			c.value = clampf(c.value + amount, c.min, c.max)
			_v2 = c.value
		"crank":
			c.value = wrapf(c.value + amount, 0.0, 1.0)
			# when a full turn completes (wrap), advance layer
			if c.value < 0.05 and amount > 0:
				_advance_layer()


func _advance_layer() -> void:
	if _layer >= LAYERS:
		return
	var s = Math.sigil(_sigil_target)
	var clean := Math.layer_clean(_v1, _v2, s)
	_plate[_layer] = clean
	_layer += 1


func _try_inscribe() -> void:
	if _layer < LAYERS:
		return
	if not Math.all_clean(_plate):
		# fail: reset plate
		for i in LAYERS:
			_plate[i] = false
		_layer = 0
		return
	if _collected[_sigil_target]:
		# already collected; reset plate
		for i in LAYERS:
			_plate[i] = false
		_layer = 0
		return
	# collect
	_collected[_sigil_target] = true
	Game.collect_card(Math.sigil(_sigil_target).card)
	for i in LAYERS:
		_plate[i] = false
	_layer = 0
	# advance target to next uncollected
	_advance_target()


func _advance_target() -> void:
	for i in SIGIL_COUNT:
		var idx := (_sigil_target + 1 + i) % SIGIL_COUNT
		if not _collected[idx]:
			_sigil_target = idx
			# sync sigil control
			for c in _controls:
				if c.id == "sigil":
					c.value = float(_sigil_target)
			return


func _reset_state() -> void:
	_sigil_target = 0
	_az = 0.0; _el = 0.0; _focusv = 0.5
	_v1 = 0.5; _v2 = 0.5
	_layer = 0
	for i in LAYERS:
		_plate[i] = false
	for c in _controls:
		if c.has("def"):
			c.value = c.def
	# sync
	for c in _controls:
		match c.id:
			"sigil": c.value = 0.0
			"az": c.value = 0.0
			"el": c.value = 0.0
			"focus": c.value = 0.5
			"v1": c.value = 0.5
			"v2": c.value = 0.5


func _update_camera(delta: float) -> void:
	# focus detection
	_focus = -1
	var best := 1e9
	for i in _controls.size():
		var c = _controls[i]
		var diff := _angle_diff(c.angle, _theta)
		if abs(diff) < FOCUS_ARC and abs(diff) < best:
			best = abs(diff)
			_focus = i
	# camera position
	if _camera:
		_camera.position = Vector3(cos(_theta) * CAM_R, CAM_H, sin(_theta) * CAM_R)
		_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _angle_diff(a: float, b: float) -> float:
	var d := a - b
	while d > PI: d -= TAU
	while d < -PI: d += TAU
	return d


func _refresh_visuals() -> void:
	var s = Math.sigil(_sigil_target)
	var res := Math.resolved(_az, _el, _focusv, s)
	# rebuild attractor points for current sigil
	if _attractor_mesh and _attractor_mesh.multimesh:
		var pts := Math.attractor_points(s.shape)
		if _attractor_mesh.multimesh.instance_count != pts.size():
			_attractor_mesh.multimesh.instance_count = pts.size()
		for i in pts.size():
			_attractor_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
	# attractor material
	if _attractor_mat:
		_attractor_mat.albedo_color = Color(0.6, 0.85, 1.0, 1.0) if res else Color(0.3, 0.4, 0.55, 0.35)
		_attractor_mat.emission_enabled = res
	# plate material: show layer progress
	if _plate_mat:
		var clean_count := 0
		for c in _plate:
			if bool(c): clean_count += 1
		_plate_mat.albedo_color = Color(0.85, 0.7, 0.3, 0.4 + 0.15 * _layer)
	# hud
	if _hud_text:
		var status := "COLLECTED %d/%d" % [_count_collected(), SIGIL_COUNT]
		var plate_str := "LAYER %d/%d" % [_layer, LAYERS]
		var res_str := "RESOLVED" if res else "tune telescope"
		var flow_str := "CLEAN" if Math.layer_clean(_v1, _v2, s) else "turbulent"
		_hud_text.text = "%s\n%s\n%s | %s\nsigil: %s" % [status, plate_str, res_str, flow_str, s.name]


func _count_collected() -> int:
	var n := 0
	for c in _collected:
		if bool(c): n += 1
	return n


func _build_world() -> void:
	_vp_container = SubViewportContainer.new()
	_vp_container.stretch = true
	_vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.handle_input_locally = false
	_vp.size = Vector2i(1280, 720)
	_vp_container.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.6)
	env.ambient_light_energy = 0.7
	_env_node = WorldEnvironment.new()
	_env_node.environment = env
	_vp.add_child(_env_node)

	_world = Node3D.new()
	_vp.add_child(_world)

	# table
	var table := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = TABLE_R
	tm.bottom_radius = TABLE_R
	tm.height = 0.12
	table.mesh = tm
	_table_mat = StandardMaterial3D.new()
	_table_mat.albedo_color = Color(0.18, 0.16, 0.14)
	_table_mat.metallic = 0.4
	_table_mat.roughness = 0.6
	table.material_override = _table_mat
	table.position = Vector3(0, 0, 0)
	_world.add_child(table)

	# attractor (multi-mesh point cloud)
	_attractor_mesh = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SphereMesh.new()
	(mm.mesh as SphereMesh).radius = 0.025
	(mm.mesh as SphereMesh).height = 0.05
	_attractor_mat = StandardMaterial3D.new()
	_attractor_mat.albedo_color = Color(0.3, 0.4, 0.55, 0.35)
	_attractor_mat.emission_enabled = true
	_attractor_mat.emission = Color(0.4, 0.7, 1.0)
	_attractor_mat.emission_energy_multiplier = 1.2
	mm.mesh.surface_set_material(0, _attractor_mat)
	var pts := Math.attractor_points(Math.sigil(0).shape)
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
	_attractor_mesh.multimesh = mm
	_attractor_mesh.position = Vector3(0, 2.6, 0)
	_attractor_mesh.scale = Vector3(1.6, 1.6, 1.6)
	_world.add_child(_attractor_mesh)

	# plate mesh (sigil plate being forged)
	_plate_mesh = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(1.0, 0.06, 1.0)
	_plate_mesh.mesh = pm
	_plate_mat = StandardMaterial3D.new()
	_plate_mat.albedo_color = Color(0.85, 0.7, 0.3, 0.4)
	_plate_mat.metallic = 0.6
	_plate_mat.roughness = 0.4
	_plate_mesh.material_override = _plate_mat
	_plate_mesh.position = Vector3(0, 0.1, 0)
	_world.add_child(_plate_mesh)

	# controls around rim
	for c in _controls:
		var node := _build_control(c)
		_control_nodes[c.id] = node
		_world.add_child(node)

	# camera
	_camera = Camera3D.new()
	_camera.fov = 50
	_vp.add_child(_camera)
	_update_camera(0.0)

	# light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 1.1
	_world.add_child(light)


func _build_control(c: Dictionary) -> Node3D:
	var root := Node3D.new()
	var ang: float = c.angle
	var pos := Vector3(cos(ang) * TABLE_R, 0.15, sin(ang) * TABLE_R)
	root.position = pos
	root.rotation.y = -ang + PI / 2.0
	if c.type == "button":
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.12, 0.35)
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.4, 0.3) if c.id == "reset" else Color(0.3, 0.6, 0.4)
		mat.metallic = 0.5
		m.material_override = mat
		root.add_child(m)
	else:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.18
		cm.height = 0.25
		m.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.6, 0.3)
		mat.metallic = 0.7
		mat.roughness = 0.35
		m.material_override = mat
		m.rotation.x = PI / 2.0
		root.add_child(m)
	# label
	var lbl := Label3D.new()
	lbl.text = c.label
	lbl.font_size = 24
	lbl.position = Vector3(0, 0.35, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)
	return root


func _build_attractor_mesh(pts: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	for p in pts:
		verts.append(p)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mat := StandardMaterial3D.new()
	mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
	for p in pts:
		mesh.surface_add_vertex(p)
	mesh.surface_end()
	return mesh


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud_text = Label.new()
	_hud_text.position = Vector2(16, 16)
	_hud_text.add_theme_font_size_override("font_size", 16)
	_hud_text.text = ""
	_hud.add_child(_hud_text)


func _build_trophy(result: Dictionary) -> Node3D:
	return null
