extends MiniGame
## Newton's Table — walk a circle around a tabletop painted with a Newton fractal.
##
## View: the camera orbits the table (◀ ▶ / A D). Knobs sit on the rim; when you are
## in front of one, press A (interact) to grab it, then ◀ ▶ turns it, A again lets go.
## Knobs: Re(p), Im(p) (the exponent) and `a` (the relaxation); the red button resets.
##
## Goal: three pyramids (laid out like Giza) stand on the table. Turn the rollers until pyramids
## sit over single colours (one Newton basin each) covering all three key colours: cyan, yellow
## and magenta. Each key colour has a crystal on the rim that lights when a pyramid is valid for
## it; light all three and hold still to win. Basins are computed on the CPU by NewtonMath.
##
## The platform, rollers, reset button and crystal sockets come from res://assets/props/newton_platform.glb
## (blends/props/newton_platform.py, game scale). Pyramids, crystals, labels and the inscription are built in
## code. The glb's nodes the game relies on: DisplaySurface, roller_0..3, reset_button.

const FRACTAL_SHADER := preload("res://shaders/newton_fractal.gdshader")
const NewtonMath := preload("res://minigames/newton/newton_math.gd")
const PLATFORM_MODEL := preload("res://assets/props/newton_platform.glb")
const PlaytestSkip := preload("res://minigames/newton/newton_skip.gd")

const TABLE_R := 2.2
const APRON_R := 3.3
const KNOB_R := 2.55 ## roller centre radius: overhangs the table edge (TABLE_R) a little
const ROLLER_R := 0.3
const ROLLER_LEN := 0.3        ## along the radial direction
const ROLLER_OUTER_R := 3.0     ## the outer end of a roller stays here; the inner end moves out as it shortens
const ROLLER_CENTER_R := ROLLER_OUTER_R - ROLLER_LEN * 0.5
const ROLLER_EXPOSE := 0.1      ## fraction of the roller's height above the fractal surface (y = 0)
const ROLLER_Y := ROLLER_R * (2.0 * ROLLER_EXPOSE - 1.0)   ## roller centre height
const ROLLER_TURNS := 2.0      ## full range of a roller = this many revolutions
const CAM_R := 5.4
const CAM_H := 3.8
const ORBIT_SPEED := 1.1       ## rad/s
const FOCUS_ARC := 0.3         ## rad either side of a control that counts as "in front"
const ADJUST_TIME := 3.0       ## seconds for a grabbed knob (at full speed) to sweep its full range
const RAMP_TIME := 1.2         ## a held knob speeds up from slow (fine tuning) to full over this long
const COVERAGE := 0.85         ## fraction of a pyramid's footprint that must be one colour
## true: the fractal is drawn in exactly the three key colours (what the game needs). false: colour
## varies continuously with each root's angle, a rainbow of many basins (looks great; kept for reuse).
const DISCRETE_COLORS := true
const HOLD_TO_WIN := 1.6       ## seconds the solution must hold with every control still

## Crystals, one per key colour (index = NewtonMath colour class), on the apron between controls.
## Rim layout (angle around the table, radians; the reset button is at 0). Crystals are 120 deg
## apart: one opposite the reset button, one either side of it between the reset button and
## the nearest roller.
const CRYSTAL_ANGLES := [PI / 3.0, PI, 5.0 * PI / 3.0]   # cyan, yellow, magenta
const CRYSTAL_R := 2.75
const INSCRIPTION := "light up each pyramid with a different energy by adjusting the fractal"
const INSCRIPTION_R := 2.42        ## just outside the fractal edge (TABLE_R)
const INSCRIPTION_CENTER := 5.35   ## rad; a stretch of rim with no rollers (between a roller and reset)
const INSCRIPTION_PIXEL := 0.0019

## Pyramids: table-local position (x, z) and footprint corner radius. The Giza trio (relative
## positions kept), moved off-centre as a rigid group so rotation matters.
const PYRAMIDS := [
	{"pos": Vector2(0.72, 1.44), "r": 0.38},
	{"pos": Vector2(0.66, 0.19), "r": 0.34},
	{"pos": Vector2(0.61, -0.87), "r": 0.17},
]

## id: shader uniform / label / range / default / angle on the rim (rad)
var _controls := [
	{"id": "re", "label": "Re p", "min": 1.0, "max": 10.0, "def": 6.0, "angle": 4.45},
	{"id": "im", "label": "Im p", "min": -6.0, "max": 6.0, "def": 0.0, "angle": 3.75},
	{"id": "a", "label": "a", "min": 0.2, "max": 2.0, "def": 1.0, "angle": 2.53},
	{"id": "rot", "label": "Rotate", "min": -180.0, "max": 180.0, "def": 90.0, "angle": 1.83, "unit": "°", "wrap": true},
	{"id": "reset", "label": "Reset", "angle": 0.0},
]

var _theta := 4.45            ## camera angle around the table (starts in front of the first roller)
var _grabbed := -1             ## index into _controls, or -1
var _focus := -1
var _table_mat: ShaderMaterial
var _model: Node3D             ## the instanced platform .glb
var _camera: Camera3D
var _hud_values: Label
var _hud: Control
var _pyramids := []            ## per pyramid: {"ring": StandardMaterial3D, "root": Variant, "ok": bool}
var _hold := 0.0               ## how long the current solution has held
var _grab_hold := 0.0          ## how long the grabbed knob has been turned continuously
var _solved := false
var _crystals := []            ## per colour class: {"mat", "light", "node", "lit"}
var _moving := false           ## a grabbed knob is being turned right now
var _time := 0.0


func _ready() -> void:
	use_touch_controls = true
	_build_world()
	_build_hud()
	super()
	for c in _controls:
		if c.has("def"):
			c["value"] = c["def"]
	_resume(resume_state)
	_apply_params()
	_update_camera(1.0)


## Rollers and the walk around the table are all a visit changes; the win is recomputed.
func save_state() -> Dictionary:
	if _solved:
		return {}
	var values := {}
	for c in _controls:
		if c.has("value"):
			values[c.id] = c.value
	return {"values": values, "theta": _theta}


func _resume(state: Dictionary) -> void:
	var values: Dictionary = state.get("values", {})
	for c in _controls:
		if values.has(c.id) and c.has("def"):
			c["value"] = clampf(float(values[c.id]), c.min, c.max)
	_theta = float(state.get("theta", _theta))


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

	var world := Node3D.new()
	world.name = "Platform"
	vp.add_child(world)
	_build_platform(world)
	for i in _controls.size():
		_build_control(world, i)
	for pyr in PYRAMIDS:
		_build_pyramid(world, pyr)
	for k in 3:
		_build_crystal(world, k)
	_build_inscription(world)


## The platform model; its DisplaySurface disc carries the fractal.
func _build_platform(parent: Node3D) -> void:
	_model = PLATFORM_MODEL.instantiate()
	parent.add_child(_model)
	_table_mat = ShaderMaterial.new()
	_table_mat.shader = FRACTAL_SHADER
	_table_mat.set_shader_parameter("table_radius", TABLE_R)
	_table_mat.set_shader_parameter("discrete_colors", DISCRETE_COLORS)
	(_model.get_node("DisplaySurface") as MeshInstance3D).material_override = _table_mat


## Translucent glass pyramid (so the colour underneath stays visible) with a base ring that
## lights up in the basin's colour when the pyramid is over a single colour.
func _build_pyramid(parent: Node3D, pyr: Dictionary) -> void:
	var r: float = pyr.r
	var root := Node3D.new()
	root.position = Vector3(pyr.pos.x, 0.0, pyr.pos.y)
	parent.add_child(root)

	# Four faces only, no base: a base cap would sit exactly on the table and z-fight with it.
	var body := MeshInstance3D.new()
	body.mesh = NewtonTrophy.pyramid_mesh(r, r * 1.4)
	body.material_override = NewtonTrophy.glass_material()
	root.add_child(body)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 1.02
	tm.outer_radius = r * 1.02 + 0.045
	tm.rings = 48
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.03
	var rm := _std_mat(Color(0.35, 0.37, 0.45), 1.0, 0.5, 0.0)
	ring.material_override = rm
	root.add_child(ring)
	_pyramids.append({"ring": rm, "root": null, "ok": false, "cls": -1})


## Adds a flat-shaded triangle whose normal faces away from `inside` (a point inside the solid),
## fixing the winding so back-face culling works whichever way the caller listed the corners.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
		var t := b; b = c; c = t
	# n is the right-hand normal of (a, b, c); Godot's front faces are clockwise, so emit reversed.
	for v in [a, c, b]:
		st.set_normal(n)
		st.add_vertex(v)


func _build_crystal(parent: Node3D, k: int) -> void:
	var col: Color = NewtonMath.KEYS[k]
	var a: float = CRYSTAL_ANGLES[k]
	var root := Node3D.new()
	root.position = Vector3(cos(a), 0.0, sin(a)) * CRYSTAL_R
	parent.add_child(root)

	# (the platform's crystal socket is the base the shards grow from)
	# A broken cluster: one tall shard and a few smaller ones leaning outwards.
	var mat := _std_mat(col.darkened(0.55), 0.0, 0.15, 0.1)
	mat.rim_enabled = true
	mat.rim = 0.6
	var gem := Node3D.new()
	gem.position.y = 0.03
	gem.rotation.y = k * 1.9
	root.add_child(gem)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + k
	var shards := [   # azimuth, lean (rad), radius, height
		[0.0, 0.08, 0.11, 0.66],
		[0.4, 0.45, 0.075, 0.38],
		[2.2, 0.6, 0.085, 0.3],
		[3.6, 0.4, 0.07, 0.42],
		[5.1, 0.7, 0.06, 0.24],
	]
	for sh in shards:
		var m := MeshInstance3D.new()
		m.mesh = _shard_mesh(rng, sh[2], sh[3])
		m.material_override = mat
		m.rotation = Vector3(0.0, sh[0], 0.0)
		var pivot := Node3D.new()      # azimuth -> lean outward -> small random twist
		pivot.rotation.y = sh[0]
		var lean := Node3D.new()
		lean.rotation.z = -sh[1]
		lean.position.x = 0.0 if sh[1] < 0.15 else 0.07
		m.rotation = Vector3(0.0, rng.randf() * TAU, 0.0)
		lean.add_child(m)
		pivot.add_child(lean)
		gem.add_child(pivot)
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = 2.2
	light.light_energy = 0.0
	light.position.y = 0.45
	gem.add_child(light)
	_crystals.append({"mat": mat, "light": light, "node": gem, "lit": false})


## One broken hexagonal shard: slightly irregular, tapering, with a slanted, jagged break at the
## top. Built from flat-shaded triangles; the base sits at y = 0 and the shard grows up +Y.
func _shard_mesh(rng: RandomNumberGenerator, radius: float, height: float) -> ArrayMesh:
	const SIDES := 6
	var base: Array[Vector3] = []
	var top: Array[Vector3] = []
	var slope_dir := Vector2.from_angle(rng.randf() * TAU)
	var slope := rng.randf_range(0.25, 0.6) * height / radius * 0.3
	for i in SIDES:
		var ang := TAU * i / SIDES + rng.randf_range(-0.18, 0.18)
		var rb := radius * rng.randf_range(0.8, 1.15)
		var rt := rb * rng.randf_range(0.45, 0.8)
		var d := Vector2.from_angle(ang)
		base.append(Vector3(d.x * rb, 0.0, d.y * rb))
		var cut := height * (1.0 - 0.18 * rng.randf()) + d.dot(slope_dir) * rt * slope * 2.5
		top.append(Vector3(d.x * rt, cut, d.y * rt))
	var centre_top := Vector3.ZERO
	for t in top:
		centre_top += t / SIDES
	var inside := Vector3(0.0, height * 0.4, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var j := (i + 1) % SIDES
		_tri(st, base[i], base[j], top[j], inside)
		_tri(st, base[i], top[j], top[i], inside)
		_tri(st, top[i], top[j], centre_top, inside)   # the flat-ish broken face
	return st.commit()


## Text lying flat on the apron, one Label3D per character along an arc. Letters' tops point at
## the table, and it reads clockwise seen from above (left to right for a player on the rim).
func _build_inscription(parent: Node3D) -> void:
	var font_size := 48
	var pixel := INSCRIPTION_PIXEL
	var font := Style.font(true)
	var widths := []
	var total := 0.0
	for i in INSCRIPTION.length():
		var w := font.get_string_size(INSCRIPTION[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * pixel
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
		l.pixel_size = pixel
		l.shaded = false
		l.modulate = Color(0.85, 0.78, 0.55, 0.9)
		l.outline_size = 0
		l.position = Vector3(cos(mid), 0.005, sin(mid)) * INSCRIPTION_R
		l.rotation = Vector3(-PI / 2.0, PI / 2.0 - mid, 0.0)
		parent.add_child(l)


func _build_control(parent: Node3D, i: int) -> void:
	var c: Dictionary = _controls[i]
	var root := Node3D.new()      # sits over the control; carries its label
	root.position = Vector3(cos(c.angle), 0.0, sin(c.angle)) * (KNOB_R if c.id == "reset" else ROLLER_CENTER_R)
	root.rotation.y = -c.angle   # local +X points outward from the table
	parent.add_child(root)
	c["node"] = root

	# The model's roller_<i> (controls 0..3) turns about its local X axis, which points outward.
	var mat := _highlight_mat()
	c["mat"] = mat
	var part: MeshInstance3D
	if c.id == "reset":
		part = _model.get_node("reset_button")
	else:
		part = _model.get_node("roller_%d" % i)
		c["roller"] = part
	part.material_overlay = mat

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0028
	label.font = Style.font()
	label.font_size = 64
	label.outline_size = 3
	label.outline_modulate = Style.INK
	label.position = Vector3(0.0, 0.55, 0.0)
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


# --- HUD ---------------------------------------------------------------------------

func _build_hud() -> void:
	var hud := preload("res://ui/puzzle_hud.gd").new()
	add_child(hud)
	hud.setup("01", "Egypt Fractal", "Bring the three crystals into alignment.")
	_hud_values = hud.values
	_hud = hud


# --- loop --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Sound.settings_open:
		return
	_time += delta
	# +1 = right. A/D are strafe actions (the hall's sidestep), arrows/D-pad are move_*.
	var steer := clampf(Input.get_axis("move_left", "move_right")
		+ Input.get_axis("strafe_left", "strafe_right"), -1.0, 1.0)
	if _grabbed >= 0:
		var c: Dictionary = _controls[_grabbed]
		var span: float = c.max - c.min
		_moving = steer != 0.0
		_grab_hold = _grab_hold + delta if _moving else 0.0
		var speed := lerpf(0.12, 1.0, clampf(_grab_hold / RAMP_TIME, 0.0, 1.0))
		var v: float = c.value + steer * speed * span / ADJUST_TIME * delta
		# wrapping controls (angles) roll over instead of stopping at the end
		c["value"] = wrapf(v, c.min, c.max) if c.get("wrap", false) else clampf(v, c.min, c.max)
		_apply_params()
	else:
		_moving = false
		_theta -= steer * ORBIT_SPEED * delta   # moving right = clockwise seen from above
		_update_focus()
	_update_camera(minf(delta * 10.0, 1.0))
	_update_win(delta)
	_refresh_visuals()


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


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if PlaytestSkip.try_activate(self, event):
		get_viewport().set_input_as_handled()
		return
	super(event)
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _solved:
		finish({"won": true})
	elif _grabbed >= 0:
		Sound.play("confirm", self)
		_grabbed = -1
	elif _focus >= 0:
		Sound.play("dial_grab", self)
		if _controls[_focus].id == "reset":
			_reset()
		else:
			_grabbed = _focus


## Once solved, back leaves (as the HUD says) instead of opening the pause menu.
func _back_leaves() -> bool:
	return _solved


## Once solved, leaving by any route (A, B, the close button) still counts as a win. The result carries the
## pyramids' positions and colours, so the room can show them (NewtonTrophy) after you leave.
func finish(result: Dictionary) -> void:
	super(result if not _solved else {"won": true, "pyramids": _pyramid_data()})


func _pyramid_data() -> Array:
	var out := []
	for i in PYRAMIDS.size():
		var st: Dictionary = _pyramids[i]
		var col := NewtonMath.palette(st.root, DISCRETE_COLORS) if st.root != null else Color(0.8, 0.8, 0.9)
		out.append({"pos": PYRAMIDS[i].pos, "r": PYRAMIDS[i].r, "color": col})
	return out


## Solved: glowing ribbons stretch between the three pyramid tips, one pair after another.
func _celebrate() -> void:
	Sound.play("victory", self)
	var ribbons := NewtonTrophy.new()
	ribbons.setup(_pyramid_data(), false)
	_model.get_parent().add_child(ribbons)
	ribbons.reveal()


func _reset() -> void:
	for c in _controls:
		if c.has("def"):
			c["value"] = c["def"]
	_apply_params()


func _apply_params() -> void:
	var re: float = _value("re")
	var im: float = _value("im")
	_table_mat.set_shader_parameter("exponent", Vector2(re, im))
	_table_mat.set_shader_parameter("relax", _value("a"))
	_table_mat.set_shader_parameter("rotation", deg_to_rad(_value("rot")))
	_evaluate()


## Which basin is each pyramid over? Samples the footprint (centre + two rings) and takes the
## dominant converged root; the pyramid is "ok" if it covers COVERAGE of the samples.
func _evaluate() -> void:
	var p := Vector2(_value("re"), _value("im"))
	var a := _value("a")
	var rot := deg_to_rad(_value("rot"))
	for i in PYRAMIDS.size():
		var pyr: Dictionary = PYRAMIDS[i]
		var pts: Array[Vector2] = [pyr.pos]
		for k in 8:
			var dir := Vector2.from_angle(TAU * k / 8.0)
			pts.append(pyr.pos + dir * pyr.r * 0.9)
			pts.append(pyr.pos + dir * pyr.r * 0.45)
		# Colour class (0 cyan, 1 yellow, 2 magenta) of every sample; -1 = never converged (dark).
		var counts := [0, 0, 0]
		var sample_root: Array = [null, null, null]
		for q in pts:
			var root: Variant = NewtonMath.basin(q, TABLE_R, p, a, rot)
			if root != null:
				var c := NewtonMath.color_class(root)
				counts[c] += 1
				sample_root[c] = root
		var best_c := 0
		for c in 3:
			if counts[c] > counts[best_c]:
				best_c = c
		var st: Dictionary = _pyramids[i]
		st.ok = counts[best_c] >= COVERAGE * pts.size()
		st.root = sample_root[best_c] if st.ok else null
		st.cls = best_c if st.ok else -1


## Per colour class: is some pyramid valid (over a single colour) for it?
func _lit(k: int) -> bool:
	for st in _pyramids:
		if st.cls == k:
			return true
	return false


func _all_lit() -> bool:
	return _lit(0) and _lit(1) and _lit(2)


func _update_win(delta: float) -> void:
	if _solved:
		return
	# The timer only runs while every control is still, so a lucky pass-through doesn't win.
	_hold = _hold + delta if _all_lit() and not _moving else 0.0
	if _hold >= HOLD_TO_WIN:
		_solved = true
		_grabbed = -1
		_moving = false
		_celebrate()


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
		if c.has("value"):
			label.text = ("%s = %.0f%s" if c.has("unit") else "%s = %.2f%s") % [c.label, c.value, c.get("unit", "")]
			var t: float = inverse_lerp(c.min, c.max, c.value)
			(c.roller as Node3D).rotation.x = -t * TAU * ROLLER_TURNS
		else:
			label.text = c.label
		label.modulate = Style.GOLD if lit else Color(Style.PAPER, .78)

	for st in _pyramids:
		var m: StandardMaterial3D = st.ring
		var col := Color(0.35, 0.37, 0.45)
		if st.ok:
			# same colour mapping as the shader: hue from the root's argument
			col = NewtonMath.palette(st.root, DISCRETE_COLORS)
		m.albedo_color = col
		m.emission = col
		var glow := 1.6 if st.ok else 0.3
		if _solved:
			glow = 2.5 + 1.5 * sin(_time * 4.0)
		elif st.ok and _hold > 0.0:
			glow = 1.6 + 2.0 * _hold / HOLD_TO_WIN   # brightens as the lock-in timer fills
		m.emission_energy_multiplier = glow
	var settled := 0
	for k in 3:
		var cr: Dictionary = _crystals[k]
		var on := _lit(k)
		var key: Color = NewtonMath.KEYS[k]
		# Lit crystals glow but are far from fully emissive, so facets still read as a surface.
		cr.mat.emission_enabled = on
		cr.mat.emission = key
		cr.mat.emission_energy_multiplier = (0.45 + (0.25 * sin(_time * 4.0) if _solved else 0.0)) if on else 0.0
		cr.mat.albedo_color = key if on else key.darkened(0.55)
		cr.mat.rim = 0.9 if on else 0.3
		cr.light.light_energy = 1.2 if on else 0.0
		if on:
			settled += 1
	var p := Vector2(_value("re"), _value("im"))
	_hud_values.text = "p = %.2f %s %.2fi     a = %.2f     rotation = %.0f°\nz ← z − a·(zᵖ − 1) / (p·zᵖ⁻¹)" % [
		p.x, "+" if p.y >= 0.0 else "−", absf(p.y), _value("a"), _value("rot")] \
		+ "\nCrystals lit: %d/3" % settled
	if _solved:
		_hud.set_hint("Aligned!   {continue} to continue")
	elif _all_lit():
		_hud.set_hint("Almost… hold still" if not _moving else "That's it! Let go and hold still")
	elif _grabbed >= 0:
		_hud.set_hint("◀ ▶ turn %s     {interact} release" % _controls[_grabbed].label)
	elif _focus >= 0:
		_hud.set_hint("{interact} %s %s" % ["press" if _controls[_focus].id == "reset" else "grab",
			_controls[_focus].label])
	else:
		_hud.set_hint("◀ ▶ walk round the table")
