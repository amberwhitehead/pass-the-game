class_name RomanAqueduct
extends Node3D
## The trophy of Roman Flow: a Roman aqueduct raised along the winning teal path, then water running through it.
## Table units (surface at y = 0); the route is a polyline of table-local (x, z) points.
##
## In the game: `setup(route)`, add to the world, `play_build()`. In the room Prop calls `build(result)` (through
## MiniGames.REGISTRY[id].trophy), which returns the finished aqueduct with the water already flowing.

const WATER_SHADER := preload("res://shaders/aqueduct_water.gdshader")

const STEP := 0.08                  ## route resample spacing, metres
const PIER_SPACING := 0.44
const PIER_W := 0.22                ## across the aqueduct
const PIER_T := 0.09                ## along it
const PIER_H := 0.34                ## pier top = channel floor
const SPRING := 0.16                ## arch springing height
const VOUSSOIRS := 7
const CH_W := 0.2                   ## channel outer width
const FLOOR_T := 0.04
const WALL_T := 0.035
const WALL_H := 0.075

const STONE := Color(0.86, 0.80, 0.66)
const STONE_DARK := Color(0.72, 0.65, 0.5)
const BRICK := Color(0.72, 0.38, 0.26)
const BRICK_DARK := Color(0.6, 0.3, 0.21)

var route := PackedVector2Array()
var _pts: PackedVector3Array
var _cum: PackedFloat32Array        ## distance along the route at each point
var _bays: Array[MeshInstance3D] = []
var _water_mat: ShaderMaterial
var _length := 0.0


static func build(result: Dictionary) -> Node3D:
	var a := RomanAqueduct.new()
	a.setup(result.get("route", PackedVector2Array()))
	a.show_built()
	return a


## Turns the solver's cell chain (grid indices, start to end) into a smooth, evenly spaced route in table units.
static func route_from_cells(cells: PackedInt32Array, n: int, table_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(Vector2(((c % n) + 0.5) / n - 0.5, (float(c / n) + 0.5) / n - 0.5) * 2.0 * table_r)
	if pts.size() < 3:
		return pts
	for iter in 5:          # moving average, ends pinned: takes the staircase out of a 4-connected path
		var sm := pts.duplicate()
		for i in range(1, pts.size() - 1):
			var acc := Vector2.ZERO
			var cnt := 0
			for k in range(maxi(0, i - 4), mini(pts.size(), i + 5)):
				acc += pts[k]
				cnt += 1
			sm[i] = acc / cnt
		pts = sm
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		var l := seg.length()
		var at := STEP - carry
		while at <= l:
			out.append(pts[i - 1] + seg * (at / l))
			at += STEP
		carry = l - (at - STEP)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.02:
		out.append(pts[pts.size() - 1])
	return out


func setup(r: PackedVector2Array) -> void:
	route = r
	if route.size() < 2:
		return
	_pts = PackedVector3Array()
	_cum = PackedFloat32Array()
	var d := 0.0
	for i in route.size():
		_pts.append(Vector3(route[i].x, 0.0, route[i].y))
		if i > 0:
			d += route[i].distance_to(route[i - 1])
		_cum.append(d)
	_length = d
	var bays := maxi(2, roundi(_length / PIER_SPACING))
	for i in bays:
		_add_bay(_length * i / bays, _length * (i + 1) / bays, i == 0)
	_add_water()


## Piers and arches rise bay by bay from the start of the path, then the channel fills and the water flows.
func play_build(per_bay := 0.4, gap := 0.22) -> void:
	if _water_mat == null:      # no usable route
		return
	for i in _bays.size():
		var bay := _bays[i]
		bay.visible = false
		bay.scale = Vector3(1.0, 0.02, 1.0)
		var tw := create_tween()
		tw.tween_interval(i * gap)
		tw.tween_callback(func(): bay.visible = true)
		tw.tween_property(bay, "scale:y", 1.0, per_bay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_water_mat.set_shader_parameter("fill", 0.0)
	var wt := create_tween()
	wt.tween_interval(_bays.size() * gap + per_bay + 0.2)
	wt.tween_method(func(v: float): _water_mat.set_shader_parameter("fill", v), 0.0, _length + 0.2, 0.2 + _length / 1.6)


func show_built() -> void:
	for b in _bays:
		b.visible = true
		b.scale = Vector3.ONE
	if _water_mat:
		_water_mat.set_shader_parameter("fill", _length + 1.0)


# --- geometry ----------------------------------------------------------------------------

func _at(s: float) -> Vector3:
	var i := 1
	while i < _cum.size() - 1 and _cum[i] < s:
		i += 1
	var seg := _cum[i] - _cum[i - 1]
	return _pts[i - 1].lerp(_pts[i], clampf((s - _cum[i - 1]) / maxf(seg, 0.0001), 0.0, 1.0))


func _add_bay(s0: float, s1: float, first: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := _at(s0)
	var p1 := _at(s1)
	var chord := p1 - p0
	var clen := chord.length()
	var d := chord / maxf(clen, 0.0001)
	# piers (the first bay also gets the one at the very start)
	for pair in ([[p0, first], [p1, true]]):
		if pair[1]:
			var s: float = s0 if pair[0] == p0 else s1
			var t := (_at(minf(s + 0.05, _length)) - _at(maxf(s - 0.05, 0.0))).normalized()
			var across := t.cross(Vector3.UP).normalized()
			var b := Basis(across, Vector3.UP, across.cross(Vector3.UP))
			_box(st, Transform3D(b, pair[0] + Vector3(0, PIER_H / 2.0, 0)), Vector3(PIER_W, PIER_H, PIER_T),
				BRICK if first and pair[0] == p0 else STONE_DARK)
	# arch: voussoirs round a semicircle between the piers, a stone course (impost) at the springing
	var across_a := d.cross(Vector3.UP).normalized()
	var mid := (p0 + p1) / 2.0
	var r_in := maxf((clen - PIER_T) / 2.0, 0.05)
	var r_mid := r_in + 0.03
	for k in VOUSSOIRS:
		var th := (k + 0.5) * PI / VOUSSOIRS
		var rad := d * cos(th) + Vector3.UP * sin(th)
		var b := Basis(across_a, rad, across_a.cross(rad))
		var key := k == VOUSSOIRS / 2
		_box(st, Transform3D(b, mid + rad * r_mid + Vector3(0, SPRING, 0)),
			Vector3(PIER_W - 0.01, 0.06 + (0.02 if key else 0.0), PI * r_mid / VOUSSOIRS * 1.03),
			STONE if key else (BRICK if k % 2 == 0 else BRICK_DARK))
	# spandrel fill above the arch up to the channel floor
	var span_top := PIER_H - FLOOR_T
	var ctr := Vector3(0, 0, 0)
	_box(st, Transform3D(Basis(across_a, Vector3.UP, across_a.cross(Vector3.UP)), mid + Vector3(0, (SPRING + r_mid + 0.03 + span_top) / 2.0, 0)),
		Vector3(PIER_W - 0.04, maxf(span_top - SPRING - r_mid - 0.03, 0.01), maxf(clen - 0.02, 0.05)), STONE_DARK)
	# channel following the route between the piers: floor and two walls, one short box per route step
	var s := s0
	while s < s1 - 0.001:
		var e := minf(s + STEP, s1)
		var a := _at(s)
		var b2 := _at(e)
		var seg := b2 - a
		var l := seg.length()
		if l > 0.001:
			var dd := seg / l
			var ac := dd.cross(Vector3.UP).normalized()
			var bs := Basis(ac, Vector3.UP, ac.cross(Vector3.UP))
			var c := (a + b2) / 2.0
			_box(st, Transform3D(bs, c + Vector3(0, PIER_H + FLOOR_T / 2.0, 0)), Vector3(CH_W, FLOOR_T, l + 0.025), STONE)
			for sx in [-1.0, 1.0]:
				_box(st, Transform3D(bs, c + ac * sx * (CH_W / 2.0 - WALL_T / 2.0) + Vector3(0, PIER_H + FLOOR_T + WALL_H / 2.0, 0)),
					Vector3(WALL_T, WALL_H, l + 0.025), STONE)
		s = e
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _stone_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_bays.append(mi)


func _add_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var y := PIER_H + FLOOR_T + 0.035
	var hw := (CH_W - 2.0 * WALL_T) / 2.0 - 0.004
	for i in _pts.size():
		var t := (_pts[mini(i + 1, _pts.size() - 1)] - _pts[maxi(i - 1, 0)]).normalized()
		var across := t.cross(Vector3.UP).normalized()
		for e in 2:
			st.set_uv(Vector2(_cum[i], float(e)))
			st.add_vertex(_pts[i] + Vector3(0, y, 0) + across * (hw if e == 1 else -hw))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	_water_mat.set_shader_parameter("fill", 0.0)
	mi.material_override = _water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static var _stone_mat: StandardMaterial3D


static func _stone_material() -> StandardMaterial3D:
	if _stone_mat == null:
		_stone_mat = StandardMaterial3D.new()
		_stone_mat.vertex_color_use_as_albedo = true
		_stone_mat.roughness = 0.85
	return _stone_mat


## A flat-shaded box of `size` at transform `xf`, vertex-coloured.
static func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size / 2.0
	var faces := [   # normal, then the four corners (counter-clockwise seen from outside)
		[Vector3.RIGHT, [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3.DOWN, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3.BACK, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
	]
	for f in faces:
		var n: Vector3 = (xf.basis * f[0]).normalized()
		var c: Array = f[1]
		for idx in [0, 2, 1, 0, 3, 2]:        # clockwise from outside = Godot front face
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(xf * (c[idx] as Vector3))
