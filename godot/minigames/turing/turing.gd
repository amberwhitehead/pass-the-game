extends MiniGame
## Turing Table — a tabletop that runs a two-colour reaction-diffusion (Gray-Scott) pattern.
##
## View: the camera orbits the table (◀ ▶ / A D). Rollers on the rim set the model's parameters
## (feed, kill, and the two diffusion rates): stand in front of one, press A to grab it, ◀ ▶ turns
## it, A lets go. Two trays hold smooth cylinders (amber and teal). Take one with A, carry it round
## the rim (◀ ▶), reach in or out over the table with ▲ ▼, and press A to put it down: it forces the
## colour underneath it to stay amber (colour 0, the background) or teal (colour 1, the pattern's
## colour). Press A near a placed cylinder to pick it up
## again; reaching past the table edge and pressing A puts a carried cylinder back in its tray.
##
## Goal (a maze): two pairs of points sit across the table from each other. Connect the teal start
## to the teal end with a continuous teal path, while the amber point on either side of each end is
## joined to its partner by a continuous amber path (so filling the table with one colour can't win).
## The points are pinned in their colours. Hold all three connections for a couple of seconds.
## A flood-fill solver runs on a worker thread against a snapshot of the state a few times a second;
## the rim's Viz button toggles drawing the routes it found on the table (on by default).
##
## Self-contained on purpose (nothing shared with other minigames). The simulation lives in
## shaders/turing_step.gdshader and runs on the GPU in a ring of offscreen SubViewports.

const STEP_SHADER := preload("res://shaders/turing_step.gdshader")
const SURFACE_SHADER := preload("res://shaders/turing_surface.gdshader")
const TAP_SHADER := preload("res://shaders/turing_tap.gdshader")
const PLATFORM_MODEL := preload("res://assets/props/turing_platform.glb")

# --- simulation ---
const GRID := 256              ## simulation resolution (texels across the table diameter)
const STAGES := 8              ## chained SubViewports = simulation steps per frame (at most)
const MAX_PINS := 16           ## must match pins[] in turing_step.gdshader
const RESET_FRAMES := 4        ## frames the reset flag is held so every stage sees it

# --- scene layout ---
const TABLE_R := 2.2
const APRON_R := 3.3
const KNOB_R := 2.55
const ROLLER_R := 0.3
const ROLLER_LEN := 0.3
const ROLLER_OUTER_R := 3.0     ## the outer end of a roller stays here; the inner end moves out as it shortens
const ROLLER_CENTER_R := ROLLER_OUTER_R - ROLLER_LEN * 0.5
const ROLLER_EXPOSE := 0.1     ## fraction of a roller's height above the table surface (y = 0)
const ROLLER_Y := ROLLER_R * (2.0 * ROLLER_EXPOSE - 1.0)
const ROLLER_TURNS := 2.0
const CAM_R := 5.4
const CAM_H := 3.8
const ORBIT_SPEED := 1.1       ## rad/s
const REACH_SPEED := 1.3       ## m/s of the reach marker
const FOCUS_ARC := 0.28        ## rad either side of a rim object that counts as "in front"
const ADJUST_TIME := 3.0       ## seconds for a grabbed roller (full speed) to sweep its range
const RAMP_TIME := 1.2         ## a held roller speeds up from slow (fine tuning) to full speed
const TRAY_R := 2.7

# --- maze ---
## Lane 0 is the teal path (colour 1); lanes 1 and 2 are the amber lanes either side (colour 0).
## "a" is the start, "b" the end, in table-local (x, z) metres.
const LANES := [
	{"a": Vector2(-1.5, 0.0), "b": Vector2(1.5, 0.0), "color": 1, "r": 0.13, "name": "Teal path"},
	{"a": Vector2(-1.5, -0.6), "b": Vector2(1.5, -0.6), "color": 0, "r": 0.10, "name": "Amber lane"},
	{"a": Vector2(-1.5, 0.6), "b": Vector2(1.5, 0.6), "color": 0, "r": 0.10, "name": "Amber lane"},
]
## Solver grid (cells across the table diameter) and snapshot interval. Without threads (a
## single-threaded web build) the solver runs on the main thread, so it gets a coarser grid and
## runs less often.
## Text lying on the apron just outside the table edge. Angles are chosen to avoid the rim buttons and
## trays (the rollers sit further out, so they don't get in the way).
const INSCRIPTION := "Connect a path for the water, with a wall on either side"
const INSCRIPTION_R := 2.42
const INSCRIPTION_CENTER := 0.4    ## rad
const INSCRIPTION_PIXEL := 0.0019

const SOLVE_N_THREADS := 128
const SOLVE_N_NO_THREADS := 64
const SOLVE_INTERVAL_THREADS := 0.4
const SOLVE_INTERVAL_NO_THREADS := 1.0
const PATTERN_THRESHOLD := 0.135 ## v at or above this counts as colour 1 (teal), the rest colour 0 (amber)
const HOLD_TO_WIN := 2.0       ## seconds all lanes must stay connected
const VIZ_NAMES := ["off", "route"]

# --- pieces ---
const SUPPLY := 3              ## cylinders of each colour
const PIECE_R := 0.24
const PIECE_H := 0.3
const COLORS := [Color(1.0, 0.55, 0.18), Color(0.10, 0.62, 0.78)]   # 0 amber (background), 1 teal (pattern)
const COLOR_NAMES := ["Amber", "Teal"]

## Rim objects, evenly spaced; moving right (◀ ▶) goes feed -> kill -> Du -> Dv -> reset -> viz -> trays.
## kind: roller (value) / button / tray (colour index in "color").
var _controls := [
	{"id": "feed", "kind": "roller", "label": "Feed", "min": 0.010, "max": 0.080, "def": 0.055, "dec": 3},
	{"id": "kill", "kind": "roller", "label": "Kill", "min": 0.045, "max": 0.070, "def": 0.062, "dec": 3},
	{"id": "du", "kind": "roller", "label": "Du", "min": 0.6, "max": 1.0, "def": 1.0, "dec": 2},
	{"id": "dv", "kind": "roller", "label": "Dv", "min": 0.2, "max": 0.6, "def": 0.5, "dec": 2},
	{"id": "reset", "kind": "button", "label": "Reset"},
	{"id": "viz", "kind": "button", "label": "Viz"},
	{"id": "tray0", "kind": "tray", "color": 0},
	{"id": "tray1", "kind": "tray", "color": 1},
]

var _theta := PI / 2.0         ## camera / cursor angle around the table (start end is on the left)
var _rho := 1.3                ## reach: distance of the cursor from the table centre
var _grabbed := -1             ## index into _controls of the roller being turned, or -1
var _focus := -1               ## rim object in front of the player, or -1
var _grab_hold := 0.0
var _time := 0.0
var _camera: Camera3D
var _world: Node3D
var _table_mat: ShaderMaterial
var _model: Node3D             ## the instanced platform .glb (blends/props/turing_platform.py)
var _stages := []              ## {"vp": SubViewport, "mat": ShaderMaterial}
var _solve_n := SOLVE_N_THREADS
var _solve_interval := SOLVE_INTERVAL_THREADS
var _tap: SubViewport          ## _solve_n x _solve_n colour mask of the latest state, for the solver
var _reset_frames := RESET_FRAMES
var _pieces := []              ## {"node": Node3D, "kind": int, "pos": Vector2, "placed": bool}
var _held: Variant = null      ## the piece being carried, or null
var _cursor: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _hud_values: Label
var _hud: Control
var _viz_mode := 1               ## index into VIZ_NAMES; also the shader's viz_mode
var _solved := false
var _task_id := -1             ## worker-thread solver job, or -1
var _route_cells := PackedInt32Array()   ## lane 0 route of the latest solution (grid cells)
var _route := PackedVector2Array()      ## the smoothed route, set on winning
var _task_out := {}            ## written by the worker, read after it completes
var _mutex := Mutex.new()
var _solve_timer := 0.0
var _connected := [false, false, false]
var _conn_since := -1.0        ## _time when all lanes became connected (continuously), or -1
var _reach_tex: ImageTexture
var _path_tex: ImageTexture
var _point_rings := []         ## per lane: [StandardMaterial3D start+end rings]


func _ready() -> void:
	use_touch_controls = true
	if not OS.has_feature("threads"):
		_solve_n = SOLVE_N_NO_THREADS
		_solve_interval = SOLVE_INTERVAL_NO_THREADS
	for i in _controls.size():
		var c: Dictionary = _controls[i]
		c["angle"] = PI / 2.0 - i * TAU / _controls.size()
		if c.has("def"):
			c["value"] = c["def"]
	_build_world()
	_build_sim()
	_build_hud()
	super()
	_make_solver_textures()
	_resume(resume_state)
	_apply_params()
	_push_pins()
	_update_camera(1.0)


## Rollers, placed pins and the view. The pattern itself regrows from them; a pin still
## being carried goes back to its tray, as it does when dropped past the edge.
func save_state() -> Dictionary:
	if _solved:
		return {}
	var values := {}
	for c in _controls:
		if c.has("value"):
			values[c.id] = c.value
	var pins := []
	for pc in _pieces:
		if pc.placed:
			pins.append({"kind": pc.kind, "pos": pc.pos})
	return {"values": values, "pins": pins, "viz": _viz_mode, "theta": _theta, "rho": _rho}


func _resume(state: Dictionary) -> void:
	var values: Dictionary = state.get("values", {})
	for c in _controls:
		if values.has(c.id) and c.has("def"):
			c["value"] = clampf(float(values[c.id]), c.min, c.max)
	for pin: Dictionary in state.get("pins", []):
		var kind := int(pin.get("kind", -1))
		if kind in [0, 1] and _available(kind) > 0:
			_add_piece(kind, pin.get("pos", Vector2.ZERO), true)
	_viz_mode = posmod(int(state.get("viz", _viz_mode)), VIZ_NAMES.size())
	_theta = float(state.get("theta", _theta))
	_rho = clampf(float(state.get("rho", _rho)), 0.0, TABLE_R + 0.45)


## The reaction-diffusion ring renders on the GPU every frame regardless of scripts, so
## the pause menu (which disables this node) has to stop it explicitly.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		var mode := SubViewport.UPDATE_ALWAYS if what == NOTIFICATION_ENABLED and not _solved else SubViewport.UPDATE_DISABLED
		for st in _stages:
			st.vp.render_target_update_mode = mode
		if _tap != null:
			_tap.render_target_update_mode = mode


# --- simulation --------------------------------------------------------------------

## A ring of STAGES SubViewports. Each renders one reaction-diffusion step from the previous
## stage's texture; stage 0 reads the last stage's result from the previous frame. Whatever order
## Godot renders them in, every stage output is a valid step of its input, so the state just flows
## round the ring (1 to STAGES steps per frame).
func _build_sim() -> void:
	for i in STAGES:
		var vp := SubViewport.new()
		vp.size = Vector2i(GRID, GRID)
		vp.use_hdr_2d = true               # float target: the chemistry needs more than 8 bits
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var rect := ColorRect.new()
		rect.size = Vector2(GRID, GRID)
		var mat := ShaderMaterial.new()
		mat.shader = STEP_SHADER
		rect.material = mat
		vp.add_child(rect)
		_stages.append({"vp": vp, "mat": mat})
	for i in STAGES:
		var prev: Dictionary = _stages[(i - 1 + STAGES) % STAGES]
		_stages[i].mat.set_shader_parameter("prev", prev.vp.get_texture())
	_table_mat.set_shader_parameter("state", _stages[STAGES - 1].vp.get_texture())
	_tap = SubViewport.new()
	_tap.size = Vector2i(_solve_n, _solve_n)
	_tap.disable_3d = true
	_tap.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_tap)
	var tap_rect := ColorRect.new()
	tap_rect.size = Vector2(_solve_n, _solve_n)
	var tap_mat := ShaderMaterial.new()
	tap_mat.shader = TAP_SHADER
	tap_mat.set_shader_parameter("state", _stages[STAGES - 1].vp.get_texture())
	tap_mat.set_shader_parameter("threshold", PATTERN_THRESHOLD)
	tap_rect.material = tap_mat
	_tap.add_child(tap_rect)


func _apply_params() -> void:
	for st in _stages:
		st.mat.set_shader_parameter("feed", _value("feed"))
		st.mat.set_shader_parameter("kill", _value("kill"))
		st.mat.set_shader_parameter("du", _value("du"))
		st.mat.set_shader_parameter("dv", _value("dv"))


## Sends the placed cylinders to every stage: (u, v, radius) in texture space plus the colour.
func _push_pins() -> void:
	var pins := PackedVector4Array()
	for lane in LANES:
		for key in ["a", "b"]:
			var uv: Vector2 = lane[key] / (2.0 * TABLE_R) + Vector2(0.5, 0.5)
			pins.append(Vector4(uv.x, uv.y, lane.r / (2.0 * TABLE_R), float(lane.color)))
	for pc in _pieces:
		if pc.placed:
			var uv: Vector2 = pc.pos / (2.0 * TABLE_R) + Vector2(0.5, 0.5)
			pins.append(Vector4(uv.x, uv.y, PIECE_R / (2.0 * TABLE_R), float(pc.kind)))
	while pins.size() < MAX_PINS:
		pins.append(Vector4(0, 0, 0, 0))
	for st in _stages:
		st.mat.set_shader_parameter("pins", pins)


func _restart_pattern() -> void:
	_reset_frames = RESET_FRAMES


# --- world -------------------------------------------------------------------------

func _build_world() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	container.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.8
	vp.add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	vp.add_child(_camera)

	_world = Node3D.new()
	_world.name = "Platform"
	vp.add_child(_world)
	_build_platform(_world)
	for i in _controls.size():
		_build_control(_world, i)
	_build_cursor(_world)
	_build_point_markers(_world)
	_build_inscription(_world)


## The platform model (res://assets/props/turing_platform.glb, game scale). Nodes the game relies on:
## DisplaySurface (carries the reaction-diffusion), roller_0..3, reset_button, viz_button, tray_anchor_0/1.
func _build_platform(parent: Node3D) -> void:
	_model = PLATFORM_MODEL.instantiate()
	parent.add_child(_model)
	_table_mat = ShaderMaterial.new()
	_table_mat.shader = SURFACE_SHADER
	_table_mat.set_shader_parameter("table_radius", TABLE_R)
	_table_mat.set_shader_parameter("color_a", COLORS[0])
	_table_mat.set_shader_parameter("color_b", COLORS[1])
	(_model.get_node("DisplaySurface") as MeshInstance3D).material_override = _table_mat


func _build_control(parent: Node3D, i: int) -> void:
	var c: Dictionary = _controls[i]
	var root := Node3D.new()      # sits over the control; carries its label (and the tray's cylinder stack)
	var radius := TRAY_R if c.kind == "tray" else (ROLLER_CENTER_R if c.kind == "roller" else KNOB_R)
	root.position = Vector3(cos(c.angle), 0.0, sin(c.angle)) * radius
	root.rotation.y = -c.angle   # local +X points outward from the table
	parent.add_child(root)
	c["node"] = root

	var mat := _highlight_mat()
	c["mat"] = mat
	match c.kind:
		"button":
			(_model.get_node("%s_button" % c.id) as MeshInstance3D).material_overlay = mat
		"roller":
			# roller_<n> turns about its local X axis, which points outward from the table.
			var roller := _model.get_node("roller_%d" % i) as MeshInstance3D
			roller.material_overlay = mat
			c["roller"] = roller
		"tray":
			# The marble basin is part of the platform; a flat glow disc over its felt shows the highlight.
			var glow := MeshInstance3D.new()
			var gm := CylinderMesh.new()
			gm.top_radius = 0.335; gm.bottom_radius = 0.335; gm.height = 0.004; gm.radial_segments = 12
			glow.mesh = gm
			glow.position.y = 0.038
			glow.material_override = mat
			root.add_child(glow)
			# the stack of cylinders still available; shown/hidden as they're taken
			var stack := []
			for s in SUPPLY:
				var m := MeshInstance3D.new()
				var sm := CylinderMesh.new()
				sm.top_radius = 0.2; sm.bottom_radius = 0.2; sm.height = 0.12
				m.mesh = sm
				m.position.y = 0.1 + s * 0.13
				m.material_override = _glass_mat(COLORS[c.color])
				root.add_child(m)
				stack.append(m)
			c["stack"] = stack

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0028
	label.font = Style.font()
	label.font_size = 64
	label.outline_size = 3
	label.outline_modulate = Style.INK
	label.position = Vector3(0.0, 0.6 if c.kind != "tray" else 0.8, 0.0)
	label.no_depth_test = true
	root.add_child(label)
	c["label3d"] = label


## Highlight overlay for a control: an additive pass over the platform's mesh (the whole platform shares one
## palette material, so a control can't be lit through its own material). Black = off.
func _highlight_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color.BLACK
	return m


func _set_highlight(mat: StandardMaterial3D, lit: bool, grabbed: bool) -> void:
	mat.albedo_color = (Color(0.30, 0.24, 0.08) if grabbed else Color(0.08, 0.15, 0.25)) if lit else Color.BLACK


## Rings and a thin light column on each maze point so they read from across the table.
func _build_point_markers(parent: Node3D) -> void:
	for lane in LANES:
		var col: Color = COLORS[lane.color]
		for key in ["a", "b"]:
			var pos: Vector2 = lane[key]
			var root := Node3D.new()
			root.position = Vector3(pos.x, 0.0, pos.y)
			parent.add_child(root)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = lane.r * 1.15
			tm.outer_radius = lane.r * 1.15 + 0.03
			tm.rings = 32
			tm.ring_segments = 6
			ring.mesh = tm
			ring.position.y = 0.02
			ring.material_override = _std_mat(col.lightened(0.4), 1.6, 0.4, 0.0)
			root.add_child(ring)
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.015; pm.bottom_radius = 0.015; pm.height = 0.45 if lane.color == 1 else 0.28
			post.mesh = pm
			post.position.y = pm.height * 0.5
			var pmat := _std_mat(col.lightened(0.5), 1.8, 0.4, 0.0)
			post.material_override = pmat
			root.add_child(post)
			_point_rings.append(pmat)


## Text lying flat on the apron, one Label3D per character along an arc. Letters' tops point at the
## table, and it reads clockwise seen from above (left to right for a player on the rim).
func _build_inscription(parent: Node3D) -> void:
	var font_size := 48
	var font := Style.font(true)
	var widths := []
	var total := 0.0
	for i in INSCRIPTION.length():
		var w := font.get_string_size(INSCRIPTION[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * INSCRIPTION_PIXEL
		widths.append(w)
		total += w
	var ang := INSCRIPTION_CENTER + total / INSCRIPTION_R / 2.0   # running clockwise (angle falls)
	for i in INSCRIPTION.length():
		var mid: float = ang - widths[i] / INSCRIPTION_R / 2.0
		ang -= widths[i] / INSCRIPTION_R
		if INSCRIPTION[i] == " ":
			continue
		var l := Label3D.new()
		l.text = INSCRIPTION[i]
		l.font = font
		l.font_size = font_size
		l.pixel_size = INSCRIPTION_PIXEL
		l.shaded = false
		l.modulate = Color(0.85, 0.78, 0.55, 0.9)
		l.outline_size = 0
		l.position = Vector3(cos(mid), 0.005, sin(mid)) * INSCRIPTION_R
		l.rotation = Vector3(-PI / 2.0, PI / 2.0 - mid, 0.0)
		parent.add_child(l)


## The reach marker: a ring on the table where a carried cylinder would go down.
func _build_cursor(parent: Node3D) -> void:
	_cursor = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = PIECE_R * 1.05
	tm.outer_radius = PIECE_R * 1.05 + 0.04
	tm.rings = 40
	tm.ring_segments = 6
	_cursor.mesh = tm
	_cursor_mat = _std_mat(Color(1, 1, 1), 1.2, 0.5, 0.0)
	_cursor.material_override = _cursor_mat
	parent.add_child(_cursor)


func _std_mat(color: Color, emit: float, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m


func _glass_mat(color: Color) -> StandardMaterial3D:
	var m := _std_mat(Color(color.r, color.g, color.b, 0.55), 0.35, 0.12, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.rim_enabled = true
	m.rim = 0.7
	return m


## A smooth glass cylinder. No bottom cap: it would sit exactly on the table and z-fight with it.
func _make_piece_node(kind: int) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = PIECE_R; cm.bottom_radius = PIECE_R; cm.height = PIECE_H
	cm.radial_segments = 64
	cm.cap_bottom = false
	body.mesh = cm
	body.position.y = PIECE_H * 0.5
	body.material_override = _glass_mat(COLORS[kind])
	root.add_child(body)
	_world.add_child(root)
	return root


# --- HUD ---------------------------------------------------------------------------

func _build_hud() -> void:
	var hud := preload("res://ui/puzzle_hud.gd").new()
	add_child(hud)
	hud.setup("02", "Roman Flow", "Connect the three routes through the living pattern.")
	_hud_values = hud.values
	_hud = hud


# --- loop --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Sound.settings_open:
		return
	_time += delta
	_run_reset_flag()
	var steer := Input.get_axis("move_left", "move_right")   # +1 = right
	if _grabbed >= 0:
		var c: Dictionary = _controls[_grabbed]
		var span: float = c.max - c.min
		_grab_hold = _grab_hold + delta if steer != 0.0 else 0.0
		var speed := lerpf(0.12, 1.0, clampf(_grab_hold / RAMP_TIME, 0.0, 1.0))
		c["value"] = clampf(c.value + steer * speed * span / ADJUST_TIME * delta, c.min, c.max)
		_apply_params()
	else:
		_theta -= steer * ORBIT_SPEED * delta   # moving right = clockwise seen from above
		var reach := Input.get_axis("move_down", "move_up")   # +1 = forward, towards the centre
		_rho = clampf(_rho - reach * REACH_SPEED * delta, 0.0, TABLE_R + 0.45)
		_update_focus()
	_update_camera(minf(delta * 10.0, 1.0))
	_update_held()
	_tick_solver(delta)
	_refresh_visuals()


func _run_reset_flag() -> void:
	var on := _reset_frames > 0
	for st in _stages:
		st.mat.set_shader_parameter("reset_state", on)
	if on:
		_reset_frames -= 1


func _update_camera(weight: float) -> void:
	var want := Vector3(cos(_theta) * CAM_R, CAM_H, sin(_theta) * CAM_R)
	_camera.position = _camera.position.lerp(want, weight)
	_camera.look_at(Vector3(0, -0.3, 0))


func _update_focus() -> void:
	_focus = -1
	var best := FOCUS_ARC
	for i in _controls.size():
		var d := absf(angle_difference(_theta, _controls[i].angle))
		if d < best:
			best = d
			_focus = i


## The reach marker is only needed to put a carried cylinder down, or to aim at one already placed.
func _cursor_visible() -> bool:
	if _held != null:
		return true
	for pc in _pieces:
		if pc.placed:
			return true
	return false


func _cursor_pos() -> Vector2:
	return Vector2(cos(_theta), sin(_theta)) * _rho


func _off_table() -> bool:
	return _rho > TABLE_R - 0.1


func _nearest_placed() -> Variant:
	var best: Variant = null
	var best_d := PIECE_R * 1.4
	for pc in _pieces:
		if pc.placed:
			var d: float = (pc.pos - _cursor_pos()).length()
			if d < best_d:
				best_d = d
				best = pc
	return best


## A carried cylinder can't go down overlapping one that's already placed.
func _blocked() -> bool:
	for lane in LANES:
		for key in ["a", "b"]:
			if (lane[key] - _cursor_pos()).length() < PIECE_R + lane.r + 0.06:
				return true
	for pc in _pieces:
		if pc.placed and (pc.pos - _cursor_pos()).length() < PIECE_R * 2.0:
			return true
	return false


func _available(kind: int) -> int:
	var n := SUPPLY
	for pc in _pieces:
		if pc.kind == kind:
			n -= 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	super(event)
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _solved:
		finish({"won": true})
	elif _grabbed >= 0:
		_grabbed = -1
	elif _held != null:
		_put_down()
	else:
		var near: Variant = _nearest_placed() if _cursor_visible() else null
		if near != null:
			_pick_up(near)
		elif _focus >= 0:
			_use_control(_focus)


func _use_control(i: int) -> void:
	Sound.play("confirm", self)
	var c: Dictionary = _controls[i]
	match c.kind:
		"roller":
			_grabbed = i
		"button":
			if c.id == "viz":
				_viz_mode = (_viz_mode + 1) % VIZ_NAMES.size()
				_table_mat.set_shader_parameter("viz_mode", _viz_mode)
			else:
				_reset_all()
		"tray":
			if _available(c.color) > 0:
				_held = _add_piece(c.color, _cursor_pos(), false)


func _add_piece(kind: int, pos: Vector2, placed: bool) -> Dictionary:
	var pc := {"node": _make_piece_node(kind), "kind": kind, "pos": pos, "placed": placed}
	_pieces.append(pc)
	_place_node(pc)
	if placed:
		_push_pins()
	return pc


func _place_node(pc: Dictionary) -> void:
	(pc.node as Node3D).position = Vector3(pc.pos.x, 0.004, pc.pos.y)


func _pick_up(pc: Dictionary) -> void:
	Sound.play("pickup", self)
	pc.placed = false
	_held = pc
	_push_pins()


func _put_down() -> void:
	var pc: Dictionary = _held
	if _off_table():
		# reached past the table edge: back into the tray
		_pieces.erase(pc)
		(pc.node as Node3D).queue_free()
		_held = null
	elif not _blocked():
		Sound.play("place", self)
		pc.pos = _cursor_pos()
		pc.placed = true
		_place_node(pc)
		_held = null
		_push_pins()


func _update_held() -> void:
	if _held != null:
		var pc: Dictionary = _held
		pc.pos = _cursor_pos()
		(pc.node as Node3D).position = Vector3(pc.pos.x, 0.12 + 0.03 * sin(_time * 5.0), pc.pos.y)


## Reset button: pattern restarts, parameters go back to defaults, every cylinder returns to its tray.
func _reset_all() -> void:
	for pc in _pieces:
		(pc.node as Node3D).queue_free()
	_pieces.clear()
	_held = null
	for c in _controls:
		if c.has("def"):
			c["value"] = c["def"]
	_apply_params()
	_push_pins()
	_restart_pattern()


## Once solved, back leaves (as the HUD says) instead of opening the pause menu.
func _back_leaves() -> bool:
	return _solved


## Once solved, leaving by any route (A, B, the close button) still counts as a win.
func finish(result: Dictionary) -> void:
	super(result if not _solved else {"won": true, "route": _route})


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)


# --- maze solver -------------------------------------------------------------------

func _make_solver_textures() -> void:
	var blank := Image.create_empty(_solve_n, _solve_n, false, Image.FORMAT_RGB8)
	_reach_tex = ImageTexture.create_from_image(blank)
	_path_tex = ImageTexture.create_from_image(blank)
	_table_mat.set_shader_parameter("reach", _reach_tex)
	_table_mat.set_shader_parameter("lane_path", _path_tex)
	_table_mat.set_shader_parameter("viz_mode", _viz_mode)


func _tick_solver(delta: float) -> void:
	if _solved:
		return
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_mutex.lock()
		var out: Dictionary = _task_out
		_mutex.unlock()
		_apply_solution(out)
	_solve_timer += delta
	if _task_id < 0 and _solve_timer >= _solve_interval:
		_solve_timer = 0.0
		var img: Image = _tap.get_texture().get_image()
		_task_id = WorkerThreadPool.add_task(_solve_job.bind(img.get_data()))


func _solve_job(data: PackedByteArray) -> void:
	var out := _solve(data)
	_mutex.lock()
	_task_out = out
	_mutex.unlock()


func _apply_solution(out: Dictionary) -> void:
	_connected = out.connected
	if _connected[0]:
		_route_cells = out.route
	_reach_tex.update(Image.create_from_data(_solve_n, _solve_n, false, Image.FORMAT_RGB8, out.reach))
	_path_tex.update(Image.create_from_data(_solve_n, _solve_n, false, Image.FORMAT_RGB8, out.path))
	if _connected[0] and _connected[1] and _connected[2]:
		if _conn_since < 0.0:
			_conn_since = _time
		elif _time - _conn_since >= HOLD_TO_WIN:
			_win()
	else:
		_conn_since = -1.0


func _win() -> void:
	_solved = true
	_grabbed = -1
	for st in _stages:   # freeze the pattern so the win stays on screen
		st.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_celebrate()


## Solved: a Roman aqueduct rises along the winning teal path (bay by bay), then the water runs through it.
## The route also goes into the result, so the room can show the aqueduct after you leave (RomanAqueduct).
func _celebrate() -> void:
	Sound.play("victory", self)
	_route = RomanAqueduct.route_from_cells(_route_cells, _solve_n, TABLE_R)
	var aq := RomanAqueduct.new()
	aq.setup(_route)
	_model.get_parent().add_child(aq)
	aq.play_build()


## Runs on a worker thread: reads only the mask bytes and constants. `data` is the tap texture
## (_solve_n x _solve_n, R = colour 1). Classifies cells into colour 0 / colour 1 / outside, then for each lane
## flood-fills (4-connected, same colour) from its start and records the distance field, whether the
## end was reached, and the shortest route.
func _solve(data: PackedByteArray) -> Dictionary:
	var n := _solve_n
	var bpp := data.size() / (n * n)      # 3 or 4 bytes per pixel depending on the viewport format
	var cls := PackedByteArray()
	cls.resize(n * n)
	var half := n * 0.5
	var limit := (half - 1.0) * (half - 1.0)
	for y in n:
		var dy := y + 0.5 - half
		for x in n:
			var dx := x + 0.5 - half
			if dx * dx + dy * dy > limit:
				cls[y * n + x] = 2
			elif data[(y * n + x) * bpp] > 127:
				cls[y * n + x] = 1
	var reach := PackedByteArray()
	reach.resize(n * n * 3)
	var path := PackedByteArray()
	path.resize(n * n * 3)
	var connected := [false, false, false]
	var route := PackedInt32Array()       # lane 0's shortest route as cell indices, start to end
	var dist := PackedInt32Array()
	dist.resize(n * n)
	var parent := PackedInt32Array()
	parent.resize(n * n)
	var queue := PackedInt32Array()
	queue.resize(n * n)
	var total := n * n
	for k in LANES.size():
		var lane: Dictionary = LANES[k]
		var col: int = lane.color
		var a: Vector2 = lane.a / (2.0 * TABLE_R) + Vector2(0.5, 0.5)
		var b: Vector2 = lane.b / (2.0 * TABLE_R) + Vector2(0.5, 0.5)
		var src := clampi(int(a.y * n), 0, n - 1) * n + clampi(int(a.x * n), 0, n - 1)
		var dst := clampi(int(b.y * n), 0, n - 1) * n + clampi(int(b.x * n), 0, n - 1)
		if cls[src] != col:
			continue
		dist.fill(-1)
		dist[src] = 0
		parent[src] = -1
		var head := 0
		var tail := 1
		queue[0] = src
		while head < tail:
			var cur := queue[head]
			head += 1
			var d := dist[cur] + 1
			var cx := cur % n
			var nb := cur - 1
			if cx > 0 and dist[nb] < 0 and cls[nb] == col:
				dist[nb] = d; parent[nb] = cur; queue[tail] = nb; tail += 1
			nb = cur + 1
			if cx < n - 1 and dist[nb] < 0 and cls[nb] == col:
				dist[nb] = d; parent[nb] = cur; queue[tail] = nb; tail += 1
			nb = cur - n
			if nb >= 0 and dist[nb] < 0 and cls[nb] == col:
				dist[nb] = d; parent[nb] = cur; queue[tail] = nb; tail += 1
			nb = cur + n
			if nb < total and dist[nb] < 0 and cls[nb] == col:
				dist[nb] = d; parent[nb] = cur; queue[tail] = nb; tail += 1
		for i in tail:
			var cell := queue[i]
			reach[cell * 3 + k] = clampi(1 + dist[cell] / 2, 1, 255)
		if dist[dst] >= 0:
			connected[k] = true
			var cell := dst
			while cell >= 0:
				path[cell * 3 + k] = 255
				if k == 0:
					route.append(cell)
				cell = parent[cell]
	route.reverse()
	return {"connected": connected, "reach": reach, "path": path, "route": route}


func _value(id: String) -> float:
	for c in _controls:
		if c.id == id:
			return c.get("value", c.get("def", 0.0))
	return 0.0


func _refresh_visuals() -> void:
	for i in _controls.size():
		var c: Dictionary = _controls[i]
		var lit := i == _focus or i == _grabbed
		_set_highlight(c.mat, lit, i == _grabbed)
		var label: Label3D = c.label3d
		match c.kind:
			"roller":
				label.text = "%s = %s" % [c.label, String.num(c.value, c.dec)]
				var t: float = inverse_lerp(c.min, c.max, c.value)
				(c.roller as Node3D).rotation.x = -t * TAU * ROLLER_TURNS
			"tray":
				var left := _available(c.color)
				label.text = "%s x%d" % [COLOR_NAMES[c.color], left]
				for s in SUPPLY:
					(c.stack[s] as Node3D).visible = s < left
			_:
				label.text = c.label
		label.modulate = Style.GOLD if lit else Color(Style.PAPER, .78)

	# reach marker
	var cp := _cursor_pos()
	_cursor.position = Vector3(cp.x, 0.02, cp.y)
	_cursor.visible = _grabbed < 0 and _cursor_visible()
	var cursor_col := Color(1, 1, 1, 1)
	if _held != null:
		cursor_col = Color(1, 0.35, 0.3) if (_blocked() and not _off_table()) else \
			(Color(0.6, 0.6, 0.7) if _off_table() else COLORS[_held.kind])
	elif _nearest_placed() != null:
		cursor_col = Color(1, 0.9, 0.4)
	_cursor_mat.albedo_color = cursor_col
	_cursor_mat.emission = cursor_col

	var marks := ""
	for k in LANES.size():
		marks += "%s %s     " % ["●" if _connected[k] else "○", LANES[k].name]
	_hud_values.text = "feed %.3f   kill %.3f   Du %.2f   Dv %.2f\n%s\n%s %d/%d   %s %d/%d in tray   viz: %s" % [
		_value("feed"), _value("kill"), _value("du"), _value("dv"), marks.strip_edges(),
		COLOR_NAMES[0], _available(0), SUPPLY, COLOR_NAMES[1], _available(1), SUPPLY, VIZ_NAMES[_viz_mode]]
	var all_ok: bool = _connected[0] and _connected[1] and _connected[2]
	for pm in _point_rings:
		pm.emission_energy_multiplier = (2.2 + 1.2 * sin(_time * 5.0)) if _solved else (2.0 if all_ok else 1.4)
	if _solved:
		_hud.set_hint("Connected!   {continue} to continue")
	elif all_ok:
		_hud.set_hint("Connected… hold it   %.1f s" % maxf(HOLD_TO_WIN - (_time - _conn_since), 0.0))
	elif _grabbed >= 0:
		_hud.set_hint("◀ ▶ turn %s     {interact} release" % _controls[_grabbed].label)
	elif _held != null:
		if _off_table():
			_hud.set_hint("{interact} return to tray     ◀ ▶ walk   ▲ ▼ reach")
		elif _blocked():
			_hud.set_hint("Too close to another cylinder     ◀ ▶ walk   ▲ ▼ reach")
		else:
			_hud.set_hint("{interact} put down     ◀ ▶ walk   ▲ ▼ reach")
	elif _cursor_visible() and _nearest_placed() != null:
		_hud.set_hint("{interact} pick up")
	elif _focus >= 0:
		var c: Dictionary = _controls[_focus]
		match c.kind:
			"roller": _hud.set_hint("{interact} grab %s" % c.label)
			"button": _hud.set_hint(("{interact} change visualization (now: %s)" % VIZ_NAMES[_viz_mode]) if c.id == "viz" \
				else "{interact} press: restart the pattern and put everything back")
			_: _hud.set_hint("{interact} take a %s cylinder" % COLOR_NAMES[c.color] if _available(c.color) > 0 \
				else "The %s tray is empty" % COLOR_NAMES[c.color])
	else:
		_hud.set_hint("◀ ▶ walk round the table     ▲ ▼ move the reach marker")
