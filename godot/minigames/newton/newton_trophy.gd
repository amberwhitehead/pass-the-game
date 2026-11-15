class_name NewtonTrophy
extends Node3D
## What Egypt Fractal leaves behind: the three pyramids joined by glowing ribbons, each ribbon a circular arc
## through the two pyramid tips. Units are the game's (table surface at y = 0).
##
## Pyramid data: Array of {"pos": Vector2 (table x, z), "r": float, "color": Color}.
## In the game the pyramids already exist, so only the ribbons are added (`setup(data, false)` then `reveal()`).
## In the room, `build(result)` (called by Prop through MiniGames.REGISTRY) returns pyramids + ribbons, already drawn.

const RIBBON_SHADER := preload("res://shaders/ribbon.gdshader")
const SAG := 0.3                 ## arc height as a fraction of the chord
const HALF_WIDTH := 0.04
const SEGMENTS := 28

var _mats: Array[ShaderMaterial] = []


static func build(result: Dictionary) -> Node3D:
	var t := NewtonTrophy.new()
	t.setup(result.get("pyramids", []), true)
	t.show_all()
	return t


func setup(pyramids: Array, with_pyramids: bool) -> void:
	var tips: Array[Vector3] = []
	var cols: Array[Color] = []
	for p in pyramids:
		var r: float = p.r
		var pos := Vector3(p.pos.x, 0.0, p.pos.y)
		tips.append(pos + Vector3(0.0, r * 1.4, 0.0))
		cols.append(p.color)
		if with_pyramids:
			add_pyramid(self, pos, r, p.color)
	for i in tips.size():
		var j := (i + 1) % tips.size()
		if tips.size() > 2 or i == 0:
			_add_ribbon(tips[i], tips[j], cols[i], cols[j])


## Plays the ribbons in one after another, each stretching from one pyramid tip to the next.
func reveal(per_ribbon := 0.9, gap := 0.45) -> void:
	var tw := create_tween()
	for k in _mats.size():
		var m := _mats[k]
		m.set_shader_parameter("progress", 0.0)
		tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, per_ribbon) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(gap if k > 0 else 0.0)


func show_all() -> void:
	for m in _mats:
		m.set_shader_parameter("progress", 1.0)


func _add_ribbon(a: Vector3, b: Vector3, col_a: Color, col_b: Color) -> void:
	var chord := b - a
	var c := chord.length()
	var dir := chord / c
	var side := dir.cross(Vector3.UP).normalized()           # horizontal, across the ribbon
	var up := side.cross(dir).normalized()                    # in the arc's plane, perpendicular to the chord
	var s := c * SAG
	var R := (c * c / 4.0 + s * s) / (2.0 * s)
	var centre := (a + b) / 2.0 + up * (s - R)
	var half := asin(clampf(c / 2.0 / R, 0.0, 1.0))
	if s > R:
		half = PI - half
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var ang := lerpf(-half, half, t)
		var p := centre + (up * cos(ang) + dir * sin(ang)) * R
		for e in 2:
			st.set_uv(Vector2(t, float(e)))
			st.add_vertex(p + side * (HALF_WIDTH if e == 1 else -HALF_WIDTH))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = RIBBON_SHADER
	m.set_shader_parameter("color_a", col_a.lightened(0.25))
	m.set_shader_parameter("color_b", col_b.lightened(0.25))
	mi.material_override = m
	add_child(mi)
	_mats.append(m)


# --- pieces shared with the game ---------------------------------------------------------

## Translucent glass (so the colour underneath still shows). A little more opaque than it first was.
static func glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.85, 0.55, 0.42)
	m.roughness = 0.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A square pyramid with no base (a cap would z-fight with the table), apex above the origin.
static func pyramid_mesh(r: float, h: float) -> ArrayMesh:
	var corners: Array[Vector3] = []
	for k in 4:
		var ang := PI / 4.0 + k * PI / 2.0
		corners.append(Vector3(cos(ang) * r, 0.0, sin(ang) * r))
	var apex := Vector3(0.0, h, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := corners[k]
		var b := corners[(k + 1) % 4]
		var n := (b - a).cross(apex - a).normalized()
		if n.dot((a + b + apex) / 3.0 - Vector3(0.0, h * 0.3, 0.0)) < 0.0:
			var t := a; a = b; b = t
			n = -n
		st.set_normal(n)
		# Godot's front faces are clockwise: emit (a, apex, b) reversed relative to the right-hand rule
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(apex)
	return st.commit()


## A glass pyramid with a glowing base ring in `color`. Returns the ring material.
static func add_pyramid(parent: Node3D, pos: Vector3, r: float, color: Color) -> StandardMaterial3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = pyramid_mesh(r, r * 1.4)
	body.material_override = glass_material()
	root.add_child(body)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 1.02
	tm.outer_radius = r * 1.02 + 0.045
	tm.rings = 48
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.03
	var rm := StandardMaterial3D.new()
	rm.albedo_color = color
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.6
	rm.roughness = 0.5
	ring.material_override = rm
	root.add_child(ring)
	return rm
