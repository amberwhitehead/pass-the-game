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
const PadLabels := preload("res://autoload/pad_labels.gd")
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

var _theta := PI / 2.0  # start facing the machine from the south
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
var _stamp_phase := "idle"
var _stamp_time := 0.0
var _shake := 0.0
var _valve_sound_t := 0.0
var _press_platen: Node3D
var _lcd_vp: SubViewport
var _lcd_label: Label
var _lcd_screen_mat: ShaderMaterial
var _status_label: Label3D
const PLATEN_TOP := 0.95
const PLATEN_PRESS := 0.30
const STAMP_ANTICIPATE := 0.14
const STAMP_DESCEND := 0.16
const STAMP_IMPACT := 0.30
const STAMP_RETRACT := 0.55

# controls
var _controls := [
	{"id": "sigil", "label": "Sigil", "min": 0.0, "max": float(SIGIL_COUNT - 1), "def": 0.0, "angle": 4.95, "radius": 2.0, "type": "knob", "step": 1.0},
	{"id": "az", "label": "Azimuth", "min": -PI, "max": PI, "def": 0.0, "angle": 4.55, "radius": 1.9, "type": "knob", "wrap": true},
	{"id": "el", "label": "Elevation", "min": -1.2, "max": 1.2, "def": 0.0, "angle": 4.15, "radius": 1.9, "type": "knob"},
	{"id": "focus", "label": "Focus", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 3.75, "radius": 1.7, "type": "knob"},
	{"id": "v1", "label": "Valve A", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 2.75, "radius": 1.8, "type": "knob"},
	{"id": "v2", "label": "Valve B", "min": 0.0, "max": 1.0, "def": 0.5, "angle": 2.35, "radius": 1.8, "type": "knob"},
	{"id": "crank", "label": "Crank", "min": 0.0, "max": 1.0, "def": 0.0, "angle": 1.15, "radius": 2.1, "type": "knob", "wrap": true},
	{"id": "inscribe", "label": "Inscribe", "min": 0.0, "max": 1.0, "def": 0.0, "angle": 0.65, "radius": 2.1, "type": "button"},
	{"id": "reset_a", "label": "Reset A", "angle": 3.0, "radius": 2.2, "type": "button"},
	{"id": "reset_b", "label": "Reset B", "angle": 3.25, "radius": 2.2, "type": "button"},
]

var _control_nodes := {}
var _attractor_mesh: MultiMeshInstance3D
var _attractor_mat: StandardMaterial3D
var _ghost_mesh: MultiMeshInstance3D
var _ghost_mat: StandardMaterial3D
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
var _last_az := 999.0
var _last_el := 999.0
var _last_focusv := 999.0
var _stamp_particles: GPUParticles3D
var _trail_vp: SubViewport
var _trail_cam: Camera3D
var _deposit_vp: SubViewport
var _deposit_cam: Camera3D
var _deposit_points: MultiMeshInstance3D
var _plate_mesh: MeshInstance3D
var _plate_mat: ShaderMaterial
var _lever_node: Node3D
var _lever_mat: StandardMaterial3D
var _crank_node: Node3D
var _crank_lock: Node3D
var _az_node: Node3D
var _el_node: Node3D
var _focus_node: Node3D
var _valve_a_node: Node3D
var _valve_b_node: Node3D
var _sigil_node: Node3D
var _gauge_needle: Node3D
var _layer_drum: Node3D
var _aether_reservoir: Node3D
var _aether_liquid: Node3D
var _sight_glass_a: MeshInstance3D
var _sight_glass_b: MeshInstance3D
var _tell_tale_a: MeshInstance3D
var _tell_tale_b: MeshInstance3D
var _reset_cover_a: Node3D
var _reset_cover_b: Node3D
var _reset_button_a: MeshInstance3D
var _reset_button_b: MeshInstance3D
var _reset_cover_open := {"a": false, "b": false}
var _reset_armed := {"a": false, "b": false}
var _reset_timer := 0.0
var _reset_glow := ""  # which button glows as the ready-to-press partner
var _aether_lamp: MeshInstance3D
var _ready_lamp: MeshInstance3D
var _warning_lamp: MeshInstance3D
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
var _grey_mat: StandardMaterial3D
var _gold_overlay: StandardMaterial3D
var _focus_overlay: StandardMaterial3D
var _reset_glow_mat: StandardMaterial3D
var _highlighted_node: Node3D = null
var _highlight_is_grab := false


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
	_update_stamp(delta)
	_update_reset(delta)
	var steer := 0.0
	# view orbits with A/D (and left/right arrows) at any time
	var orbit := clampf(Input.get_axis("move_left", "move_right") + Input.get_axis("strafe_left", "strafe_right"), -1.0, 1.0)
	if orbit != 0.0:
		_theta -= orbit * ORBIT_SPEED * delta
	if _grabbed >= 0:
		# turn the grabbed control with W/S (and up/down)
		var turn := clampf(Input.get_axis("move_up", "move_down"), -1.0, 1.0)
		var c: Dictionary = _controls[_grabbed]
		_moving = turn != 0.0
		_grab_hold = _grab_hold + delta if _moving else 0.0
		var speed := lerpf(0.12, 1.0, clampf(_grab_hold / RAMP_TIME, 0.0, 1.0))
		var span: float = float(c.max) - float(c.min)
		if span <= 0.0:
			span = 1.0
		var v: float = float(c.get("value", 0.0)) + turn * speed * span / ADJUST_TIME * delta
		if c.id == "crank":
			if not _crank_ready():
				# the lock bar holds the crank: it will not turn
				_valve_sound_t -= delta
				if turn != 0.0 and _valve_sound_t <= 0.0:
					_valve_sound_t = 0.6
					Sound.play("unavailable", self)
			else:
				var oldv: float = float(c.value)
				c.value = wrapf(v, 0.0, 1.0)
				_crank_accum = float(c.value) * TAU
				if oldv > 0.85 and c.value < 0.15 and turn > 0.0:
					_advance_layer()
		elif c.id == "sigil":
			c.value = clampf(v, float(c.min), float(c.max))
			c.value = roundf(c.value)
			_sync_state_from_controls()
		else:
			c.value = clampf(v, float(c.min), float(c.max))
			_sync_state_from_controls()
		if (c.id == "v1" or c.id == "v2") and turn != 0.0:
			_valve_sound_t -= delta
			if _valve_sound_t <= 0.0:
				_valve_sound_t = 0.35
				Sound.play("dial_turn", self)
	else:
		_moving = false
	_update_camera(delta)
	_sync_visuals_from_state()
	_update_highlights()
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
		_valve_a_node.rotation.y = _v1 * TAU
	if _valve_b_node:
		_valve_b_node.rotation.y = _v2 * TAU
	if _crank_node:
		_crank_node.rotation.y = _crank_accum
	if _crank_lock:
		var lock_target := (-PI / 2.0) if _crank_ready() else 0.0
		_crank_lock.rotation.x = lerpf(_crank_lock.rotation.x, lock_target, 0.2)

	if _gauge_needle:
		var s = Math.sigil(_sigil_target)
		var clean := Math.layer_clean(_v1, _v2, s)
		var target_angle := 0.0 if clean else -1.2
		_gauge_needle.rotation.y = lerpf(_gauge_needle.rotation.y, target_angle, 0.1)
	if _focus_node:
		_focus_node.rotation.y = _focusv * TAU
	if _sigil_node:
		_sigil_node.rotation.y = _sigil_target * (TAU / 5.0)
	if _az_node:
		_az_node.rotation.y = _az
	if _el_node:
		_el_node.rotation.y = _el
	if _layer_drum:
		_layer_drum.rotation.y = float(_layer) * (TAU / 4.0)
	# valve tell-tales: green when flow is clean, red when turbulent
	for tt in [_tell_tale_a, _tell_tale_b]:
		if tt:
			var tm := tt.material_override as StandardMaterial3D
			if tm:
				var clean_tt := Math.layer_clean(_v1, _v2, Math.sigil(_sigil_target))
				var c := Color(0.35, 0.9, 0.45) if clean_tt else Color(0.9, 0.3, 0.25)
				tm.albedo_color = c
				tm.emission = c
	# sight glasses glow with flow quality
	for sg in [_sight_glass_a, _sight_glass_b]:
		if sg:
			var gm := sg.material_override as StandardMaterial3D
			if gm:
				var ss = Math.sigil(_sigil_target)
				var ok := Math.layer_clean(_v1, _v2, ss)
				gm.emission_energy_multiplier = 2.5 if ok else 0.6
				gm.albedo_color = Color(0.4, 0.8, 1.0, 0.85) if ok else Color(0.9, 0.4, 0.3, 0.7)
	# aether reservoir level: rises with focus/flow quality
	if _aether_liquid:
		var sr = Math.sigil(_sigil_target)
		var resr := Math.resolved(_az, _el, _focusv, sr)
		var flow_ok := Math.layer_clean(_v1, _v2, sr)
		var level := 0.25
		if resr: level += 0.35
		if flow_ok: level += 0.35
		_aether_liquid.scale = Vector3(1.0, level, 1.0)
	# gauge needle points to flow quality
	if _gauge_needle:
		var s = Math.sigil(_sigil_target)
		var clean := Math.layer_clean(_v1, _v2, s)
		var target := 0.0 if clean else -1.0
		_gauge_needle.rotation.y = lerpf(_gauge_needle.rotation.y, target, 0.15)
	# lamps
	if _aether_lamp:
		var mat := _aether_lamp.material_override as StandardMaterial3D
		if mat:
			var s2 = Math.sigil(_sigil_target)
			var res := Math.resolved(_az, _el, _focusv, s2)
			mat.emission_energy_multiplier = 2.0 if res else 0.3
	if _ready_lamp:
		var mat2 := _ready_lamp.material_override as StandardMaterial3D
		if mat2:
			var s3 = Math.sigil(_sigil_target)
			var complete := (_layer >= LAYERS and Math.all_clean(_plate))
			mat2.emission_energy_multiplier = 2.0 if complete else 0.1
	if _warning_lamp:
		var mat3 := _warning_lamp.material_override as StandardMaterial3D
		if mat3:
			var bad := not _crank_ready()
			mat3.emission_energy_multiplier = 2.0 if bad else 0.1


func _sync_state_from_controls() -> void:
	for c in _controls:
		match c.id:
			"az": _az = float(c.value)
			"el": _el = float(c.value)
			"focus": _focusv = float(c.value)
			"v1": _v1 = float(c.value)
			"v2": _v2 = float(c.value)
			"sigil": _sigil_target = int(roundf(float(c.value)))





func _crank_ready() -> bool:
	var s = Math.sigil(_sigil_target)
	return Math.resolved(_az, _el, _focusv, s) and Math.layer_clean(_v1, _v2, s) and _layer < LAYERS


func _advance_layer() -> void:
	if _layer >= LAYERS:
		return
	var s = Math.sigil(_sigil_target)
	var clean := Math.layer_clean(_v1, _v2, s)
	_plate[_layer] = clean
	_layer += 1
	_crank_accum = 0.0
	Sound.play("place" if clean else "unavailable", self)


func _try_inscribe() -> void:
	if _layer < LAYERS:
		Sound.play("unavailable", self)
		return
	if not Math.all_clean(_plate):
		for i in LAYERS:
			_plate[i] = false
		_layer = 0
		Sound.play("unavailable", self)
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
	_start_stamp()
	Sound.play("confirm", self)
	Sound.play("reward_rise", self)
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
		if _shake > 0.0005:
			_camera.position += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * _shake
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
	var is_interact := event.is_action_pressed("interact")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_interact = true
	if not is_interact:
		return
	get_viewport().set_input_as_handled()
	if _grabbed >= 0:
		_grabbed = -1
		_grab_hold = 0.0
		Sound.play("dial_grab", self)
		return
	if _focus >= 0:
		var c = _controls[_focus]
		if c.type == "button":
			_press_button(c)
		else:
			_grabbed = _focus
			_grab_hold = 0.0
			Sound.play("dial_grab", self)


func _press_button(c: Dictionary) -> void:
	if c.id == "inscribe":
		_try_inscribe()
	elif c.id == "reset_a" or c.id == "reset_b":
		_press_reset(c.id.right(1))  # "a" or "b"


## Two-hand reset: open the cover, then press one button; its partner glows for
## four seconds and only then can the second button fire.
func _press_reset(which: String) -> void:
	var open: Dictionary = _reset_cover_open
	if not bool(open[which]):
		open[which] = true
		Sound.play("dial_grab", self)
		return
	# cover is open: try to press
	if bool(_reset_armed[which]):
		Sound.play("unavailable", self)  # already armed this one
		return
	if _reset_glow != "" and _reset_timer > 0.0:
		# a first press is waiting: too soon to press the partner
		Sound.play("unavailable", self)
		return
	if _reset_armed["a"] or _reset_armed["b"]:
		# this is the second press, and the four-second wait has elapsed
		_reset_state()
		_reset_armed = {"a": false, "b": false}
		_reset_glow = ""
		_reset_timer = 0.0
		open["a"] = false
		open["b"] = false
		Sound.play("confirm", self)
		return
	# first press: arm this button and make the other glow
	_reset_armed[which] = true
	_reset_glow = "b" if which == "a" else "a"
	_reset_timer = 4.0
	Sound.play("place", self)


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
	_grey_mat = StandardMaterial3D.new()
	_grey_mat.albedo_color = Color(0.4, 0.4, 0.45)
	_grey_mat.metallic = 0.2
	_grey_mat.roughness = 0.7
	_gold_overlay = StandardMaterial3D.new()
	_gold_overlay.albedo_color = Color(1.0, 0.82, 0.35, 1.0)
	_gold_overlay.emission_enabled = true
	_gold_overlay.emission = Color(1.0, 0.75, 0.2)
	_gold_overlay.emission_energy_multiplier = 0.8
	_gold_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gold_overlay.albedo_color.a = 0.45
	_focus_overlay = StandardMaterial3D.new()
	_focus_overlay.albedo_color = Color(0.55, 0.9, 1.0, 0.30)
	_focus_overlay.emission_enabled = true
	_focus_overlay.emission = Color(0.4, 0.85, 1.0)
	_focus_overlay.emission_energy_multiplier = 0.7
	_focus_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reset_glow_mat = StandardMaterial3D.new()
	_reset_glow_mat.albedo_color = Color(1.0, 0.75, 0.25)
	_reset_glow_mat.emission_enabled = true
	_reset_glow_mat.emission = Color(1.0, 0.7, 0.2)
	_reset_glow_mat.emission_energy_multiplier = 2.5


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
	_gauge_needle = _model.get_node_or_null("GaugeNeedle") as Node3D
	_press_platen = _model.get_node_or_null("PressPlaten") as Node3D
	_layer_drum = _model.get_node_or_null("LayerDrum") as Node3D
	_aether_reservoir = _model.get_node_or_null("AetherReservoir") as Node3D
	_aether_liquid = _model.get_node_or_null("AetherLiquid") as Node3D
	_sight_glass_a = _model.get_node_or_null("SightGlassA") as MeshInstance3D
	_sight_glass_b = _model.get_node_or_null("SightGlassB") as MeshInstance3D
	for sg in [_sight_glass_a, _sight_glass_b]:
		if sg:
			var gm := _mat_aether.duplicate()
			sg.material_override = gm
	_tell_tale_a = _model.get_node_or_null("TellTaleA") as MeshInstance3D
	_tell_tale_b = _model.get_node_or_null("TellTaleB") as MeshInstance3D
	for tt in [_tell_tale_a, _tell_tale_b]:
		if tt:
			var tm := StandardMaterial3D.new()
			tm.albedo_color = Color(0.9, 0.3, 0.25)
			tm.emission_enabled = true
			tm.emission = Color(0.9, 0.3, 0.25)
			tm.emission_energy_multiplier = 1.5
			tt.material_override = tm
	_aether_lamp = _model.get_node_or_null("AetherLamp") as MeshInstance3D
	_ready_lamp = _model.get_node_or_null("ReadyLamp") as MeshInstance3D
	_warning_lamp = _model.get_node_or_null("WarningLamp") as MeshInstance3D
	# give lamps emissive overrides so state can drive them
	for lamp in [_aether_lamp, _ready_lamp, _warning_lamp]:
		if lamp:
			var lm := StandardMaterial3D.new()
			var col := Color(0.6, 0.9, 1.0)
			if lamp == _ready_lamp:
				col = Color(0.4, 1.0, 0.6)
			elif lamp == _warning_lamp:
				col = Color(1.0, 0.35, 0.25)
			lm.albedo_color = col
			lm.emission_enabled = true
			lm.emission = col
			lm.emission_energy_multiplier = 0.3
			lamp.material_override = lm
	# map controls to nodes
	var name_map := {
		"sigil": "SigilSelector", "az": "AzimuthKnob", "el": "ElevationKnob",
		"focus": "FocusRing", "v1": "ValveA", "v2": "ValveB",
		"crank": "Crank", "inscribe": "InscribeLever",
		"reset_a": "ResetButtonA", "reset_b": "ResetButtonB",
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
	_crank_lock = _model.get_node_or_null("CrankLock") as Node3D
	_reset_button_a = _model.get_node_or_null("ResetButtonA") as MeshInstance3D
	_reset_button_b = _model.get_node_or_null("ResetButtonB") as MeshInstance3D
	_reset_cover_a = _model.get_node_or_null("ResetCoverA") as Node3D
	_reset_cover_b = _model.get_node_or_null("ResetCoverB") as Node3D
	for cov in [_reset_cover_a, _reset_cover_b]:
		if cov is MeshInstance3D:
			var gm := _mat_glass.duplicate()
			gm.albedo_color = Color(0.7, 0.85, 0.95, 0.35)
			(cov as MeshInstance3D).material_override = gm

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
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, 0.0)))
	_attractor_mesh.multimesh = mm
	_world.add_child(_attractor_mesh)

	# ghost: the target sigil shape the player must align the live cloud to
	_ghost_mesh = MultiMeshInstance3D.new()
	var gmm := MultiMesh.new()
	gmm.transform_format = MultiMesh.TRANSFORM_3D
	gmm.mesh = SphereMesh.new()
	(gmm.mesh as SphereMesh).radius = 0.028
	(gmm.mesh as SphereMesh).height = 0.056
	(gmm.mesh as SphereMesh).radial_segments = 6
	(gmm.mesh as SphereMesh).rings = 3
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.28)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(1.0, 0.75, 0.3)
	_ghost_mat.emission_energy_multiplier = 0.8
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmm.mesh.surface_set_material(0, _ghost_mat)
	gmm.instance_count = pts.size()
	_ghost_mesh.multimesh = gmm
	_world.add_child(_ghost_mesh)

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
		tmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, 0.0)))
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
		tmm2.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, 0.0)))
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
		tmm3.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i] * 0.9 + Vector3(0, 1.6, 0.0)))
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

	# ---- trail field (deposit viewport + decay trail viewport) ----
	_deposit_vp = SubViewport.new()
	_deposit_vp.size = Vector2i(256, 256)
	_deposit_vp.own_world_3d = true
	_deposit_vp.transparent_bg = false
	_deposit_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_deposit_vp)
	var de = WorldEnvironment.new()
	var de_env := Environment.new()
	de_env.background_mode = Environment.BG_COLOR
	de_env.background_color = Color(0, 0, 0)
	de.environment = de_env
	_deposit_vp.add_child(de)
	_deposit_cam = Camera3D.new()
	_deposit_cam.position = Vector3(0, 0, 2.5)
	_deposit_cam.fov = 60
	_deposit_vp.add_child(_deposit_cam)
	_deposit_cam.look_at(Vector3.ZERO)
	_deposit_points = MultiMeshInstance3D.new()
	var dmm := MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.mesh = SphereMesh.new()
	(dmm.mesh as SphereMesh).radius = 0.04
	(dmm.mesh as SphereMesh).height = 0.08
	(dmm.mesh as SphereMesh).radial_segments = 4
	(dmm.mesh as SphereMesh).rings = 2
	var dmat := _mat_aether.duplicate()
	dmat.albedo_color = Color(0.6, 0.85, 1.0, 1.0)
	dmat.emission_enabled = true
	dmat.emission = Color(0.4, 0.7, 1.0)
	dmat.emission_energy_multiplier = 2.0
	dmm.mesh.surface_set_material(0, dmat)
	var dpts := Math.attractor_points(Math.sigil(0).shape)
	dmm.instance_count = dpts.size()
	for i in dpts.size():
		dmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, dpts[i] * 0.6))
	_deposit_points.multimesh = dmm
	_deposit_vp.add_child(_deposit_points)

	_trail_vp = SubViewport.new()
	_trail_vp.size = Vector2i(256, 256)
	_trail_vp.own_world_3d = false
	_trail_vp.transparent_bg = false
	_trail_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_trail_vp)
	# BackBufferCopy captures previous frame
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_trail_vp.add_child(bbc)
	# ColorRect with decay shader reading deposit_vp texture
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tmat := ShaderMaterial.new()
	tmat.shader = preload("res://shaders/trail_field.gdshader")
	tmat.set_shader_parameter("deposit_tex", _deposit_vp.get_texture())
	cr.material = tmat
	_trail_vp.add_child(cr)

	# void window: a dark, faintly glowing pane (the attractor is the star)
	if _void_window and _void_mat:
		_void_mat.albedo_color = Color(0.03, 0.05, 0.12, 0.9)
		_void_mat.emission_enabled = true
		_void_mat.emission = Color(0.05, 0.1, 0.25)
		_void_mat.emission_energy_multiplier = 0.6

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

	# engraved nameplate
	var nameplate := Label3D.new()
	nameplate.text = "THE AETHERIC SIGIL PRESS"
	nameplate.font_size = 28
	nameplate.pixel_size = 0.003
	nameplate.modulate = Color(0.15, 0.12, 0.08)
	nameplate.position = Vector3(0, 0.72, 2.2)
	nameplate.rotation.y = PI
	_world.add_child(nameplate)

	# true LCD: a SubViewport renders the text, a dot-matrix shader draws it on the panel
	_lcd_vp = SubViewport.new()
	_lcd_vp.size = Vector2i(256, 96)
	_lcd_vp.transparent_bg = false
	_lcd_vp.disable_3d = true
	_lcd_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_lcd_vp)
	var lcd_bg := ColorRect.new()
	lcd_bg.color = Color(0.01, 0.03, 0.02)
	lcd_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lcd_vp.add_child(lcd_bg)
	_lcd_label = Label.new()
	_lcd_label.position = Vector2(6, 2)
	_lcd_label.size = Vector2(244, 92)
	_lcd_label.add_theme_font_override("font", load("res://assets/fonts/DSEG14Classic-Regular.ttf"))
	_lcd_label.add_theme_font_size_override("font_size", 18)
	_lcd_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_lcd_label.text = "SIGIL: THE LANTERN\nLAYER 0/4   SIGILS 0/5\nFLOW: —   TUNING"
	_lcd_vp.add_child(_lcd_label)
	# screen quad flush on the console panel
	var lcd_screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.24, 0.36)
	lcd_screen.mesh = qm
	_lcd_screen_mat = ShaderMaterial.new()
	_lcd_screen_mat.shader = preload("res://shaders/lcd_display.gdshader")
	_lcd_screen_mat.set_shader_parameter("text_tex", _lcd_vp.get_texture())
	lcd_screen.material_override = _lcd_screen_mat
	lcd_screen.position = Vector3(0, 1.20, 2.30)
	_world.add_child(lcd_screen)
	_status_label = null

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


## The copper duct path in Godot coordinates (mirrors the Blender duct).
const DUCT_PATH := [
	Vector3(0.0, 1.0, -1.5),
	Vector3(-1.2, 0.8, -1.0),
	Vector3(-1.7, 0.7, -0.3),
	Vector3(-1.4, 0.7, 0.6),
	Vector3(0.2, 0.7, 0.9),
	Vector3(1.2, 0.7, 0.9),
]


func _path_point(t: float) -> Vector3:
	var seg := t * float(DUCT_PATH.size() - 1)
	var i := clampi(int(seg), 0, DUCT_PATH.size() - 2)
	var f := seg - float(i)
	return DUCT_PATH[i].lerp(DUCT_PATH[i + 1], f)


func _start_stamp() -> void:
	_stamp_phase = "anticipate"
	_stamp_time = 0.0
	if _stamp_particles:
		_stamp_particles.restart()
		_stamp_particles.emitting = true


func _ease_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


func _update_stamp(delta: float) -> void:
	if _press_platen == null or _lever_node == null:
		return
	if _stamp_phase == "idle":
		_lever_node.rotation.x = lerpf(_lever_node.rotation.x, 0.0, 0.18)
		_press_platen.position.y = lerpf(_press_platen.position.y, PLATEN_TOP, 0.12)
		return
	_stamp_time += delta
	match _stamp_phase:
		"anticipate":
			var t := _stamp_time / STAMP_ANTICIPATE
			var e := _ease_out(t)
			_press_platen.position.y = lerpf(PLATEN_TOP, PLATEN_TOP + 0.05, e)
			_lever_node.rotation.x = lerpf(0.0, -0.14, e)
			if t >= 1.0:
				_stamp_phase = "descend"
				_stamp_time = 0.0
		"descend":
			var t := _stamp_time / STAMP_DESCEND
			var e := t * t  # accelerate into the plate
			_press_platen.position.y = lerpf(PLATEN_TOP + 0.05, PLATEN_PRESS, e)
			_lever_node.rotation.x = lerpf(-0.14, PI / 2.0, e)
			if t >= 1.0:
				_stamp_phase = "impact"
				_stamp_time = 0.0
				_shake = 0.10
				Sound.play("place", self)
		"impact":
			_press_platen.position.y = PLATEN_PRESS
			_lever_node.rotation.x = PI / 2.0
			_shake = lerpf(_shake, 0.0, 0.22)
			if _stamp_time >= STAMP_IMPACT:
				_stamp_phase = "retract"
				_stamp_time = 0.0
		"retract":
			var t := _stamp_time / STAMP_RETRACT
			var e := _ease_out(t)
			_press_platen.position.y = lerpf(PLATEN_PRESS, PLATEN_TOP, e)
			_lever_node.rotation.x = lerpf(PI / 2.0, 0.0, e)
			if t >= 1.0:
				_stamp_phase = "idle"
				_stamp_time = 0.0


func _update_reset(delta: float) -> void:
	if _reset_timer > 0.0:
		_reset_timer = maxf(0.0, _reset_timer - delta)
		if _reset_timer == 0.0:
			_reset_glow = ""  # the partner stops glowing; the first press stays armed
	if _reset_cover_a:
		var ta := (-PI / 2.0) if bool(_reset_cover_open["a"]) else 0.0
		_reset_cover_a.rotation.x = lerpf(_reset_cover_a.rotation.x, ta, 0.22)
	if _reset_cover_b:
		var tb := (-PI / 2.0) if bool(_reset_cover_open["b"]) else 0.0
		_reset_cover_b.rotation.x = lerpf(_reset_cover_b.rotation.x, tb, 0.22)
	for which in ["a", "b"]:
		var btn: MeshInstance3D = _reset_button_a if which == "a" else _reset_button_b
		if btn:
			if _reset_glow == which and _reset_timer > 0.0:
				btn.material_override = _reset_glow_mat
			else:
				btn.material_override = null


func _update_highlights() -> void:
	var target_node: Node3D = null
	var is_grab := false
	if _grabbed >= 0:
		target_node = _control_nodes.get(_controls[_grabbed].id, null)
		is_grab = true
	elif _focus >= 0:
		target_node = _control_nodes.get(_controls[_focus].id, null)
	# only change when the highlighted node or its mode differs
	if target_node == _highlighted_node and is_grab == _highlight_is_grab:
		return
	_clear_control_overlay(_highlighted_node)
	_highlighted_node = target_node
	_highlight_is_grab = is_grab
	if target_node:
		_apply_control_overlay(target_node, is_grab)


func _control_meshes(node: Node) -> Array:
	var arr: Array = []
	if node is MeshInstance3D:
		arr.append(node)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		arr.append(m)
	return arr


func _apply_control_overlay(node: Node3D, grabbed: bool) -> void:
	var overlay: Material = _gold_overlay if grabbed else _focus_overlay
	for m in _control_meshes(node):
		(m as MeshInstance3D).material_overlay = overlay


func _clear_control_overlay(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	for m in _control_meshes(node):
		(m as MeshInstance3D).material_overlay = null


func _update_flow_dots(delta: float) -> void:
	if _flow_dots.is_empty():
		return
	var s = Math.sigil(_sigil_target)
	var clean := Math.layer_clean(_v1, _v2, s)
	var speed := 0.10 if clean else 0.18
	for i in _flow_dots.size():
		_flow_dot_progress[i] = float(_flow_dot_progress[i]) + delta * speed * (0.7 + 0.3 * randf())
		if _flow_dot_progress[i] > 1.0:
			_flow_dot_progress[i] = 0.0
		var t: float = float(_flow_dot_progress[i])
		var pos := _path_point(t)
		pos.y += sin(t * PI) * 0.05
		_flow_dots[i].position = pos
		var mat := _flow_dots[i].material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = (1.0 - t) * 0.6 + 0.2
			mat.emission_energy_multiplier = 1.0 + (0.0 if clean else 1.5)


func _refresh_visuals() -> void:
	var s = Math.sigil(_sigil_target)
	# continuity: the shape is always visible; tuning rotates, tightens and brightens it
	var align_az := 1.0 - clampf(absf(_angle_diff(_az, s.az)) / 0.9, 0.0, 1.0)
	var align_el := 1.0 - clampf(absf(_el - float(s.el)) / 0.9, 0.0, 1.0)
	var align := align_az * align_el
	var focus_f := clampf((_focusv - 0.1) / 0.85, 0.0, 1.0)
	var tune := clampf(0.55 * align + 0.45 * focus_f, 0.0, 1.0)
	var res := align > 0.75 and focus_f > 0.75
	if _attractor_mat:
		_attractor_mat.albedo_color = Color(0.22, 0.32, 0.48, 0.6).lerp(Color(0.7, 0.92, 1.0, 0.98), tune)
		_attractor_mat.emission_energy_multiplier = lerpf(0.5, 2.8, tune)
	# the ghost fades out as the live cloud matches it
	if _ghost_mat:
		_ghost_mat.albedo_color.a = 0.30 * (1.0 - tune)
		_ghost_mat.emission_energy_multiplier = 0.8 * (1.0 - tune)
	# rebuild attractor points when any telescope parameter changes
	var dirty := (_sigil_target != _last_sigil) \
		or absf(_az - _last_az) > 0.004 \
		or absf(_el - _last_el) > 0.004 \
		or absf(_focusv - _last_focusv) > 0.004
	if dirty and _attractor_mesh and _attractor_mesh.multimesh:
		_last_sigil = _sigil_target
		_last_resolved = res
		_last_az = _az
		_last_el = _el
		_last_focusv = _focusv
		var base := Math.attractor_points(s.shape)
		var basis := Basis(Vector3.UP, _az) * Basis(Vector3.RIGHT, _el)
		# loose but recognizable: small deterministic wobble that tightens with tune
		var wobble := (1.0 - tune) * 0.09
		var spread := lerpf(0.80, 1.10, tune)
		var pts := PackedVector3Array()
		pts.resize(base.size())
		for i in base.size():
			var p: Vector3 = basis * (base[i] * 0.9 * spread)
			# deterministic per-point jitter (same point moves consistently)
			var j := Vector3(sin(float(i) * 1.7), cos(float(i) * 2.3), sin(float(i) * 3.1))
			p += j * wobble
			pts[i] = p + Vector3(0, 1.6, 0.0)
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
				tmesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, hpts[i]))
		_prev_pts = pts
		# sync deposit points (centered, no offset)
		if _deposit_points and _deposit_points.multimesh:
			if _deposit_points.multimesh.instance_count != pts.size():
				_deposit_points.multimesh.instance_count = pts.size()
			for i in pts.size():
				var dp := pts[i] - Vector3(0, 1.6, 0.0)
				_deposit_points.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, dp * 0.6))
		if _attractor_mesh.multimesh.instance_count != pts.size():
			_attractor_mesh.multimesh.instance_count = pts.size()
		for i in pts.size():
			_attractor_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
		# ghost target at the ideal orientation
		if _ghost_mesh and _ghost_mesh.multimesh:
			var tgt_basis := Basis(Vector3.UP, float(s.az)) * Basis(Vector3.RIGHT, float(s.el))
			var gcount := base.size()
			if _ghost_mesh.multimesh.instance_count != gcount:
				_ghost_mesh.multimesh.instance_count = gcount
			for i in gcount:
				var gp: Vector3 = tgt_basis * (base[i] * 0.9 * 1.05) + Vector3(0, 1.6, 0.0)
				_ghost_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, gp))
	# plate shader
	if _plate_mat:
		_plate_mat.set_shader_parameter("layer_count", float(_layer))
	# mold
	if _mold_mat:
		_mold_mat.albedo_color = Color(0.22, 0.2, 0.18)
	# void window tint
	if _void_mat:
		_void_mat.albedo_color = (Color(0.08, 0.12, 0.25, 0.7) if res else Color(0.04, 0.05, 0.12, 0.9))
	# disabled-state greying on crank and lever
	var plate_complete := (_layer >= LAYERS and Math.all_clean(_plate))
	var can_inscribe: bool = plate_complete and not _collected[_sigil_target]
	if _crank_node and _crank_node is MeshInstance3D:
		if not _crank_ready():
			(_crank_node as MeshInstance3D).material_override = _grey_mat
		else:
			(_crank_node as MeshInstance3D).material_override = null
	if _lever_node and _lever_node is MeshInstance3D:
		if not can_inscribe:
			(_lever_node as MeshInstance3D).material_override = _grey_mat
		else:
			(_lever_node as MeshInstance3D).material_override = null

	# LCD text (rendered into the panel, not floating)
	if _lcd_label:
		var flow_ok := Math.layer_clean(_v1, _v2, s)
		var res_txt := "RESOLVED" if res else "TUNING"
		var flow_txt := "CLEAN" if flow_ok else "TURBULENT"
		_lcd_label.text = "SIGIL: %s\nLAYER %d/%d   SIGILS %d/%d\n%s   FLOW: %s" % [
			String(s.name).to_upper(), _layer, LAYERS, _count_collected(), SIGIL_COUNT, res_txt, flow_txt]

	# hud
	if _hud_text:
		var status := "COLLECTED %d/%d" % [_count_collected(), SIGIL_COUNT]
		var plate_str := "LAYER %d/%d" % [_layer, LAYERS]
		var res_str := "RESOLVED" if res else "tune telescope"
		var flow_str := "CLEAN" if Math.layer_clean(_v1, _v2, s) else "turbulent"
		var focus_name := ""
		if _focus >= 0:
			focus_name = _controls[_focus].label
		var grab_hint := ""
		var act_key := _interact_key()
		var turn_key := _turn_key()
		var orbit_key := _orbit_key()
		if _grabbed >= 0:
			var gc = _controls[_grabbed]
			grab_hint = "GRABBED: %s — %s turn  ·  %s orbit  ·  %s release" % [gc.label, turn_key, orbit_key, act_key]
		elif _focus >= 0:
			var fc = _controls[_focus]
			var action := "press" if fc.type == "button" else "grab"
			grab_hint = "%s %s: %s   |   %s orbit" % [act_key, action, focus_name, orbit_key]
		else:
			grab_hint = "%s orbit   |   face a control and %s grab" % [orbit_key, act_key]
		_hud_text.text = "%s\n%s\n%s | %s\nsigil: %s\n%s" % [status, plate_str, res_str, flow_str, s.name, grab_hint]


func _has_pad() -> bool:
	return not Input.get_connected_joypads().is_empty()


func _interact_key() -> String:
	return PadLabels.face(JOY_BUTTON_A) if _has_pad() else "Click"


func _turn_key() -> String:
	return "Stick" if _has_pad() else "W/S"


func _orbit_key() -> String:
	return "Stick" if _has_pad() else "A/D"


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
	_hud_text.add_theme_font_size_override("font_size", 18)
	_hud_text.text = ""
	_hud.add_child(_hud_text)