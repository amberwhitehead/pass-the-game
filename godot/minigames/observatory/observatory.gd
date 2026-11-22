extends MiniGame
## The Observatory's Aetheric Sigil Press.
##
## A brass instrument: aim the telescope (azimuth/elevation/focus) at a drifting
## strange attractor until it resolves; open the aether valves (flow) within
## tolerance; turn the layer crank to solidify clean layers; then pull the
## inscription lever to capture the sigil as a plate. Five distinct sigils to
## collect; collecting all wins the game.
##
## View: orbit camera around the table (A/D or right stick). When in front of a
## control, interact grabs it; A/D turns it; interact releases. Buttons trigger
## on press.

const Math := preload("res://minigames/observatory/observatory_math.gd")
const LAYERS := Math.LAYERS
const SIGIL_COUNT := Math.SIGIL_COUNT

const TABLE_R := 2.4
const APRON_R := 3.4
const CAM_R := 5.8
const CAM_H := 4.1
const ORBIT_SPEED := 1.1
const FOCUS_ARC := 0.32
const ADJUST_TIME := 2.6
const RAMP_TIME := 1.0
const VOID_Z := -4.0

var _theta := 0.0
var _grabbed := -1
var _focus := -1
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
var _plate: Array = []
var _collected: Array = []
var _solved := false
var _crank_accum := 0.0
var _lever_t := 0.0  # 0..1 pull animation
var _stamp_t := -1.0

# controls
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

var _control_nodes := {}
var _attractor_mesh: MultiMeshInstance3D
var _attractor_mat: StandardMaterial3D
var _trail_mesh: MultiMeshInstance3D
var _trail_mat: StandardMaterial3D
var _trail_mesh2: MultiMeshInstance3D
var _trail_mat2: StandardMaterial3D
var _trail_mesh3: MultiMeshInstance3D
var _trail_mat3: StandardMaterial3D
var _pt_history: Array = []
var _prev_pts: PackedVector3Array
var _last_sigil: int = -1
var _last_resolved: bool = false
var _stamp_particles: GPUParticles3D
var _plate_mesh: MeshInstance3D
var _plate_mat: ShaderMaterial
var _lever_node: Node3D
var _lever_mat: StandardMaterial3D
var _crank_node: Node3D
var _az_node: Node3D
var _el_node: Node3D
var _focus_node: Node3D
var _valve_a_node: Node3D
var _valve_b_node: Node3D
var _sigil_node: Node3D
var _gauge_needle: Node3D
var _mold_mat: StandardMaterial3D
var _void_mat: StandardMaterial3D
var _flow_particles: GPUParticles3D
var _flow_dots: Array = []
var _flow_dot_progress: Array = []
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _world: Node3D
var _env_node: WorldEnvironment
var _void_window: MeshInstance3D
var _telescope: Node3D
var _model: Node3D

# materials (cached)
var _mat_brass: StandardMaterial3D
var _mat_brass_dark: StandardMaterial3D
var _mat_copper: StandardMaterial3D
var _mat_stone: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_enamel: StandardMaterial3D
var _mat_aether: StandardMaterial3D


func _ready() -> void:
	use_touch_controls = true
	_collected.resize(SIGIL_COUNT)
	for i in SIGIL_COUNT:
		_collected[i] = false
	_plate.resize(LAYERS)
	for i in LAYERS:
		_plate[i] = false
	_make_materials()
	_build_world()
	_build_hud()
	super()
	for c in _controls:
		if c.has("def"):
			c["value"] = c.def
	_resume(resume_state)
	_update_camera(0.0)
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
	# lever pull animation
	if _lever_t > 0.0 and _lever_t < 1.0:
		_lever_t = clampf(_lever_t + delta * 2.0, 0.0, 1.0)
	if _stamp_t >= 0.0:
		_stamp_t += delta
		if _stamp_t > 0.6:
			_stamp_t = -1.0
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
		if c.id == "crank":
			var oldv: float = float(c.value)
			c.value = wrapf(v, 0.0, 1.0)
			if oldv > 0.85 and c.value < 0.15 and steer > 0.0:
				_advance_layer()
		elif c.id == "sigil":
			c.value = clampf(v, float(c.min), float(c.max))
			c.value = roundf(c.value)
			_sync_state_from_controls()
		else:
			c.value = clampf(v, float(c.min), float(c.max))
			_sync_state_from_controls()
	else:
		steer = clampf(Input.get_axis("move_left", "move_right") + Input.get_axis("strafe_left", "strafe_right"), -1.0, 1.0)
		if steer != 0.0:
			_theta -= steer * ORBIT_SPEED * delta
	_update_camera(delta)
	_sync_visuals_from_state()
	_update_flow_dots(delta)
	_refresh_visuals()
	if not _solved and _all_collected():
		_solved = true
		finish({"won": true})


func _sync_visuals_from_state() -> void:
	if _telescope:
		_telescope.rotation.y = -_az
		_telescope.rotation.x = _el
	if _valve_a_node:
		_valve_a_node.rotation.z = _v1 * TAU
	if _valve_b_node:
		_valve_b_node.rotation.z = _v2 * TAU
	if _crank_node:
		_crank_node.rotation.x = _crank_accum
	if _lever_node:
		_lever_node.rotation.x = _lever_t * (PI / 2.0)
	if _gauge_needle:
		var s = Math.sigil(_sigil_target)
		var clean := Math.layer_clean(_v1, _v2, s)
		var target_angle := 0.0 if clean else -1.2
		_gauge_needle.rotation.z = lerpf(_gauge_needle.rotation.z, target_angle, 0.1)
	if _focus_node:
		_focus_node.rotation.z = _focusv * TAU
	if _sigil_node:
		_sigil_node.rotation.y = _sigil_target * 0.3


func _sync_state_from_controls() -> void:
	for c in _controls:
		match c.id:
			"az": _az = float(c.value)
			"el": _el = float(c.value)
			"focus": _focusv = float(c.value)
			"v1": _v1 = float(c.value)
			"v2": _v2 = float(c.value)
			"sigil": _sigil_target = int(roundf(float(c.value)))





func _advance_layer() -> void:
	if _layer >= LAYERS:
		return
	var s = Math.sigil(_sigil_target)
	var clean := Math.layer_clean(_v1, _v2, s)
	_plate[_layer] = clean
	_layer += 1
	_crank_accum = 0.0
	# haptic-ish: bump handled by sound elsewhere


func _try_inscribe() -> void:
	if _layer < LAYERS:
		return
	if not Math.all_clean(_plate):
		for i in LAYERS:
			_plate[i] = false
		_layer = 0
		return
	if _collected[_sigil_target]:
		for i in LAYERS:
			_plate[i] = false
		_layer = 0
		return
	_collected[_sigil_target] = true
	Game.collect_card(Math.sigil(_sigil_target).card)
	for i in LAYERS:
		_plate[i] = false
	_layer = 0
	_stamp_t = 0.0
	_lever_t = 0.0
	if _stamp_particles:
		_stamp_particles.restart()
		_stamp_particles.emitting = true
	Sound.play("confirm", self)
	_advance_target()


func _advance_target() -> void:
	for i in SIGIL_COUNT:
		var idx := (_sigil_target + 1 + i) % SIGIL_COUNT
		if not _collected[idx]:
			_sigil_target = idx
			for c in _controls:
				if c.id == "sigil":
					c.value = float(_sigil_target)
			return


func _reset_state() -> void:
	_sigil_target = 0
	_az = 0.0; _el = 0.0; _focusv = 0.5
	_v1 = 0.5; _v2 = 0.5
	_layer = 0
	_crank_accum = 0.0
	for i in LAYERS:
		_plate[i] = false
	for c in _controls:
		if c.has("def"):
			c.value = c.def
	for c in _controls:
		match c.id:
			"sigil": c.value = 0.0
			"az": c.value = 0.0
			"el": c.value = 0.0
			"focus": c.value = 0.5
			"v1": c.value = 0.5
			"v2": c.value = 0.5


func _update_camera(delta: float) -> void:
	_focus = -1
	var best := 1e9
	for i in _controls.size():
		var c = _controls[i]
		var diff := _angle_diff(c.angle, _theta)
		if abs(diff) < FOCUS_ARC and abs(diff) < best:
			best = abs(diff)
			_focus = i
	if _camera:
		_camera.position = Vector3(cos(_theta) * CAM_R, CAM_H, sin(_theta) * CAM_R)
		_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _angle_diff(a: float, b: float) -> float:
	var d := a - b
	while d > PI: d -= TAU
	while d < -PI: d += TAU
	return d


func _all_collected() -> bool:
	for c in _collected:
		if not bool(c):
			return false
	return true


func _back_leaves() -> bool:
	return _solved


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


func _press_button(c: Dictionary) -> void:
	if c.id == "inscribe":
		_try_inscribe()
	elif c.id == "reset":
		_reset_state()


# ---------- visuals ----------

func _make_materials() -> void:
	_mat_brass = _std(Color(0.78, 0.62, 0.32), 0.7, 0.3)
	_mat_brass_dark = _std(Color(0.45, 0.34, 0.18), 0.7, 0.45)
	_mat_copper = _std(Color(0.72, 0.4, 0.22), 0.65, 0.4)
	_mat_stone = _std(Color(0.22, 0.2, 0.18), 0.1, 0.85)
	_mat_wood = _std(Color(0.3, 0.2, 0.12), 0.05, 0.7)
	_mat_glass = _std(Color(0.4, 0.7, 1.0, 0.35), 0.0, 0.1)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_enamel = _std(Color(0.77, 0.48, 0.9), 0.2, 0.4)
	_mat_aether = _std(Color(0.3, 0.6, 1.0, 0.85), 0.0, 0.2)
	_mat_aether.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_aether.emission_enabled = true
	_mat_aether.emission = Color(0.3, 0.6, 1.0)
	_mat_aether.emission_energy_multiplier = 1.4


func _std(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


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
	env.background_color = Color(0.008, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.6)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	_env_node = WorldEnvironment.new()
	_env_node.environment = env
	_vp.add_child(_env_node)

	_world = Node3D.new()
	_vp.add_child(_world)

	# load the Blender-built platform
	const PLATFORM_MODEL := preload("res://assets/props/observatory_platform.glb")
	_model = PLATFORM_MODEL.instantiate()
	_world.add_child(_model)
	# cache nodes by name
	_telescope = _model.get_node_or_null("TelescopeMount")
	_void_window = _model.get_node_or_null("VoidWindow") as MeshInstance3D
	if _void_window:
		_void_mat = _mat_glass.duplicate()
		_void_mat.albedo_color = Color(0.05, 0.08, 0.18, 0.85)
		_void_window.material_override = _void_mat
	_plate_mesh = _model.get_node_or_null("InscriptionPlate") as MeshInstance3D
	if _plate_mesh:
		_plate_mat = ShaderMaterial.new()
		_plate_mat.shader = preload("res://shaders/observatory_plate.gdshader")
		_plate_mesh.material_override = _plate_mat
	_gauge_needle = _model.get_node_or_null("FlowGauge") as MeshInstance3D
	# map controls to nodes
	var name_map := {
		"sigil": "SigilSelector", "az": "AzimuthKnob", "el": "ElevationKnob",
		"focus": "FocusRing", "v1": "ValveA", "v2": "ValveB",
		"crank": "Crank", "inscribe": "InscribeLever", "reset": "ResetButton",
	}
	for c in _controls:
		var nm: String = name_map.get(c.id, "")
		var node := _model.get_node_or_null(nm) as Node3D
		_control_nodes[c.id] = node
		match c.id:
			"sigil": _sigil_node = node
			"az": _az_node = node
			"el": _el_node = node
			"focus": _focus_node = node
			"v1": _valve_a_node = node
			"v2": _valve_b_node = node
			"crank": _crank_node = node
			"inscribe": _lever_node = node

	# attractor (point cloud) in front of void window
	_attractor_mesh = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SphereMesh.new()
	(mm.mesh as SphereMesh).radius = 0.03
	(mm.mesh as SphereMesh).height = 0.06
	(mm.mesh as SphereMesh).radial_segments = 6
	(mm.mesh as SphereMesh).rings = 3
	_attractor_mat = _mat_aether.duplicate()
	mm.mesh.surface_set_material(0, _attractor_mat)
	var pts := Math.attractor_points(Math.sigil(0).shape)
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)))
	_attractor_mesh.multimesh = mm
	_world.add_child(_attractor_mesh)

	# trail ghost (lagging copy)
	_trail_mesh = MultiMeshInstance3D.new()
	var tmm := MultiMesh.new()
	tmm.transform_format = MultiMesh.TRANSFORM_3D
	tmm.mesh = SphereMesh.new()
	(tmm.mesh as SphereMesh).radius = 0.025
	(tmm.mesh as SphereMesh).height = 0.05
	(tmm.mesh as SphereMesh).radial_segments = 6
	(tmm.mesh as SphereMesh).rings = 3
	_trail_mat = _mat_aether.duplicate()
	_trail_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.25)
	_trail_mat.emission_energy_multiplier = 0.6
	tmm.mesh.surface_set_material(0, _trail_mat)
	tmm.instance_count = pts.size()
	for i in pts.size():
		tmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)))
	_trail_mesh.multimesh = tmm
	_world.add_child(_trail_mesh)

	# trail ghost 2 (older)
	_trail_mesh2 = MultiMeshInstance3D.new()
	var tmm2 := MultiMesh.new()
	tmm2.transform_format = MultiMesh.TRANSFORM_3D
	tmm2.mesh = SphereMesh.new()
	(tmm2.mesh as SphereMesh).radius = 0.02
	(tmm2.mesh as SphereMesh).height = 0.04
	_trail_mat2 = _mat_aether.duplicate()
	_trail_mat2.albedo_color = Color(0.3, 0.6, 1.0, 0.15)
	_trail_mat2.emission_energy_multiplier = 0.4
	tmm2.mesh.surface_set_material(0, _trail_mat2)
	tmm2.instance_count = pts.size()
	for i in pts.size():
		tmm2.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)))
	_trail_mesh2.multimesh = tmm2
	_world.add_child(_trail_mesh2)

	# trail ghost 3 (oldest)
	_trail_mesh3 = MultiMeshInstance3D.new()
	var tmm3 := MultiMesh.new()
	tmm3.transform_format = MultiMesh.TRANSFORM_3D
	tmm3.mesh = SphereMesh.new()
	(tmm3.mesh as SphereMesh).radius = 0.015
	(tmm3.mesh as SphereMesh).height = 0.03
	_trail_mat3 = _mat_aether.duplicate()
	_trail_mat3.albedo_color = Color(0.3, 0.6, 1.0, 0.08)
	_trail_mat3.emission_energy_multiplier = 0.2
	tmm3.mesh.surface_set_material(0, _trail_mat3)
	tmm3.instance_count = pts.size()
	for i in pts.size():
		tmm3.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)))
	_trail_mesh3.multimesh = tmm3
	_world.add_child(_trail_mesh3)

	_prev_pts = pts
	_pt_history = [pts]

	# stamp burst particles
	_stamp_particles = GPUParticles3D.new()
	_stamp_particles.amount = 80
	_stamp_particles.lifetime = 0.8
	_stamp_particles.one_shot = true
	_stamp_particles.explosiveness = 1.0
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 1, 0)
	spm.spread = 180.0
	spm.initial_velocity_min = 1.5
	spm.initial_velocity_max = 3.0
	spm.gravity = Vector3(0, -2, 0)
	spm.scale_min = 0.5
	spm.scale_max = 1.2
	spm.color = Color(1.0, 0.9, 0.5, 1.0)
	_stamp_particles.process_material = spm
	var spmesh := SphereMesh.new()
	spmesh.radius = 0.04; spmesh.height = 0.08
	_stamp_particles.draw_pass_1 = spmesh
	_stamp_particles.position = Vector3(0, 0.2, 1.4)
	_stamp_particles.emitting = false
	_world.add_child(_stamp_particles)

	# flow dots along pipes (animated in _process)
	for i in 12:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03; sm.height = 0.06
		sm.radial_segments = 6; sm.rings = 3
		d.mesh = sm
		var m := _mat_aether.duplicate()
		m.albedo_color = Color(0.3, 0.6, 1.0, 0.85)
		d.material_override = m
		d.position = Vector3(0, 0.15, 0)
		_world.add_child(d)
		_flow_dots.append(d)
		_flow_dot_progress.append(randf())

	# camera
	_camera = Camera3D.new()
	_camera.fov = 50
	_vp.add_child(_camera)
	_update_camera(0.0)

	# light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 40, 0)
	light.light_energy = 1.2
	_world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -120, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.6, 0.7, 1.0)
	_world.add_child(fill)


func _make_flow_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, 1)
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0, 0, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color = Color(0.3, 0.6, 1.0, 0.8)
	return m


func _make_pipe(from: Vector3, to: Vector3) -> void:
	var mid := (from + to) * 0.5
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	var pipe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035; cm.bottom_radius = 0.035; cm.height = length
	pipe.mesh = cm
	pipe.material_override = _mat_copper
	pipe.position = mid
	_world.add_child(pipe)
	pipe.look_at(to, Vector3.UP)
	pipe.rotate_object_local(Vector3(1, 0, 0), PI / 2.0)


func _build_control(c: Dictionary) -> Node3D:
	var root := Node3D.new()
	var ang: float = c.angle
	var pos := Vector3(cos(ang) * TABLE_R, 0.12, sin(ang) * TABLE_R)
	root.position = pos
	root.rotation.y = -ang + PI / 2.0
	if c.type == "button":
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.1, 0.3)
		m.mesh = bm
		var mat := _mat_brass_dark if c.id == "reset" else _mat_enamel
		m.material_override = mat
		root.add_child(m)
		# lever arm for inscribe
		if c.id == "inscribe":
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(0.06, 0.4, 0.06)
			arm.mesh = am
			arm.material_override = _mat_brass
			arm.position = Vector3(0, 0.2, 0)
			arm.rotation.x = 0.0
			root.add_child(arm)
	else:
		# knob body
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16; cm.bottom_radius = 0.16; cm.height = 0.22
		m.mesh = cm
		m.material_override = _mat_brass
		m.rotation.x = PI / 2.0
		root.add_child(m)
		# knurled edge (torus)
		var kn := MeshInstance3D.new()
		var km := TorusMesh.new()
		km.inner_radius = 0.17; km.outer_radius = 0.19
		kn.mesh = km
		kn.material_override = _mat_brass_dark
		kn.rotation.x = PI / 2.0
		root.add_child(kn)
		# pointer mark
		var pm := MeshInstance3D.new()
		var pmm := BoxMesh.new()
		pmm.size = Vector3(0.02, 0.18, 0.04)
		pm.mesh = pmm
		pm.material_override = _mat_enamel
		pm.position = Vector3(0, 0.12, 0)
		root.add_child(pm)
		# valve wheel spokes (for v1/v2)
		if c.id == "v1" or c.id == "v2":
			for k in 4:
				var spoke := MeshInstance3D.new()
				var sm := BoxMesh.new()
				sm.size = Vector3(0.02, 0.02, 0.32)
				spoke.mesh = sm
				spoke.material_override = _mat_brass_dark
				spoke.rotation.y = k * PI / 4.0
				spoke.position = Vector3(0, 0, 0)
				root.add_child(spoke)
	# label
	var lbl := Label3D.new()
	lbl.text = c.label
	lbl.font_size = 22
	lbl.position = Vector3(0, 0.32, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)
	return root


func _update_flow_dots(delta: float) -> void:
	if _flow_dots.is_empty():
		return
	var s = Math.sigil(_sigil_target)
	var clean := Math.layer_clean(_v1, _v2, s)
	var speed := 0.6 if clean else 1.2
	var valve_a := _valve_a_node.position if _valve_a_node else Vector3(2.0, 0.12, 0.0)
	var valve_b := _valve_b_node.position if _valve_b_node else Vector3(-2.0, 0.12, 0.0)
	var mold := Vector3(0, 0.1, 1.4)
	for i in _flow_dots.size():
		_flow_dot_progress[i] = float(_flow_dot_progress[i]) + delta * speed * (0.7 + 0.3 * randf())
		if _flow_dot_progress[i] > 1.0:
			_flow_dot_progress[i] = 0.0
		var t: float = float(_flow_dot_progress[i])
		var start: Vector3 = valve_a if (i % 2 == 0) else valve_b
		var pos := start.lerp(mold, t)
		pos.y += sin(t * PI) * 0.15
		_flow_dots[i].position = pos
		var mat := _flow_dots[i].material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = (1.0 - t) * 0.6 + 0.2
			mat.emission_energy_multiplier = 1.0 + (0.0 if clean else 1.5)


func _refresh_visuals() -> void:
	var s = Math.sigil(_sigil_target)
	var res := Math.resolved(_az, _el, _focusv, s)
	# attractor
	if _attractor_mat:
		_attractor_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.9) if res else Color(0.25, 0.35, 0.5, 0.3)
		_attractor_mat.emission_energy_multiplier = 2.0 if res else 0.4
	# rebuild attractor points only when sigil or resolution state changes
	var dirty := (_sigil_target != _last_sigil) or (res != _last_resolved)
	if dirty and _attractor_mesh and _attractor_mesh.multimesh:
		_last_sigil = _sigil_target
		_last_resolved = res
		var pts := Math.attractor_points(s.shape)
		_pt_history.push_front(pts)
		if _pt_history.size() > 4:
			_pt_history.pop_back()
		var trails := [_trail_mesh, _trail_mesh2, _trail_mesh3]
		for ti in trails.size():
			var tmesh: MultiMeshInstance3D = trails[ti]
			if tmesh == null or tmesh.multimesh == null:
				continue
			var idx := ti + 1
			if idx >= _pt_history.size():
				continue
			var hpts: PackedVector3Array = _pt_history[idx]
			if tmesh.multimesh.instance_count != hpts.size():
				tmesh.multimesh.instance_count = hpts.size()
			for i in hpts.size():
				var tp: Vector3 = hpts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)
				tmesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, tp))
		_prev_pts = pts
		if _attractor_mesh.multimesh.instance_count != pts.size():
			_attractor_mesh.multimesh.instance_count = pts.size()
		for i in pts.size():
			var p: Vector3 = pts[i] * 0.9 + Vector3(0, 1.6, VOID_Z + 0.6)
			if not res:
				p += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.15
			_attractor_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	# plate shader
	if _plate_mat:
		_plate_mat.set_shader_parameter("layer_count", float(_layer))
	# mold
	if _mold_mat:
		_mold_mat.albedo_color = Color(0.22, 0.2, 0.18)
	# void window tint
	if _void_mat:
		_void_mat.albedo_color = (Color(0.08, 0.12, 0.25, 0.7) if res else Color(0.04, 0.05, 0.12, 0.9))
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