class_name Greebles
extends RefCounted
## Sci-fi wall detail for the north and south walls between the pillars, made only of rectangles: panel plates,
## vents, pipe runs with clamps, switch grids, screens, hatches and cable trays, plus a few glowing indicators.
## Everything is one instanced box, drawn in two MultiMeshes (lit stone/metal, and unshaded glow), so the whole
## thing is two draw calls however many rectangles there are. Deterministic (seeded).

const MAX_RECTS := 3000
const GLOW_SHADER := preload("res://shaders/greeble_glow.gdshader")

const GREYS := [Color(0.10, 0.12, 0.16), Color(0.14, 0.16, 0.2), Color(0.07, 0.085, 0.11), Color(0.2, 0.22, 0.26),
	Color(0.12, 0.13, 0.15), Color(0.17, 0.19, 0.22)]
const GLOWS := [Color(0.3, 0.85, 1.0), Color(1.0, 0.7, 0.25), Color(0.4, 1.0, 0.5), Color(1.0, 0.3, 0.3), Color(0.3, 0.85, 1.0)]

var _solid: Array = []      # [Transform3D, Color]
var _glow: Array = []
var _rng := RandomNumberGenerator.new()
var _side := 1.0
var _z0 := 0.0
var _bay_x := 0.0


## Adds the greebles to `parent`. `hw` = half the room width (wall inner face at z = ±hw), `h` = wall height,
## `bays` = [[x0, x1], ...] the clear stretches between pillars. Returns the number of rectangles.
static func build(parent: Node3D, hw: float, h: float, bays: Array) -> int:
	var g := Greebles.new()
	g._rng.seed = 7
	for side in [-1.0, 1.0]:
		for bay in bays:
			g._bay(side, hw, bay[0], bay[1], 0.12, h - 0.12)
	return g._emit(parent)


## Doorway-aware bays. Each section specifies side (-1 north / +1 south),
## wall distance, x limits and vertical limits. All sections share two batches.
static func build_sections(parent: Node3D, sections: Array) -> int:
	var g := Greebles.new()
	g._rng.seed = 7
	for section: Dictionary in sections:
		g._bay(section.side, section.wall, section.x0, section.x1, section.y0, section.y1)
	return g._emit(parent)


func _bay(side: float, hw: float, x0: float, x1: float, y0: float, y1: float) -> void:
	_side = side
	_z0 = side * hw
	# rows of random height, each cut into 1-3 panels
	var y := y0
	while y < y1 - 0.2:
		var rh := minf(_rng.randf_range(0.45, 1.15), y1 - y)
		var x := x0
		var cols := _rng.randi_range(1, 3)
		var widths: Array[float] = []
		var total := 0.0
		for c in cols:
			widths.append(_rng.randf_range(0.6, 1.4))
			total += widths[c]
		for c in cols:
			var w := (x1 - x0) * widths[c] / total
			_panel(x + 0.02, y + 0.02, w - 0.04, rh - 0.04)
			x += w
		y += rh


## One wall panel: a base plate and one kind of equipment on it.
func _panel(x: float, y: float, w: float, h: float) -> void:
	var grey: Color = GREYS[_rng.randi() % GREYS.size()]
	_add(x + w / 2.0, y + h / 2.0, w, h, 0.0, _rng.randf_range(0.02, 0.06), grey)
	var cx := x + w / 2.0
	var cy := y + h / 2.0
	var t := _rng.randi() % 8
	match t:
		0: _vents(x, y, w, h)
		1: _pipes(x, y, w, h)
		2: _switches(x, y, w, h)
		3: _machine(cx, cy, w, h)
		4: _screen(cx, cy, w, h)
		5: _hatch(cx, cy, w, h)
		6: _cables(x, y, w, h)
		_: _vents(x, y, w, h)
	# border rivet strips and a light or two
	if _rng.randf() < 0.6:
		_add(cx, y + 0.015, w - 0.02, 0.012, 0.0, 0.07, grey.lightened(0.15))
		_add(cx, y + h - 0.015, w - 0.02, 0.012, 0.0, 0.07, grey.lightened(0.15))
	if _rng.randf() < 0.55:
		var n := _rng.randi_range(1, 3)
		var col: Color = GLOWS[_rng.randi() % GLOWS.size()]
		for i in n:
			_add(x + 0.07 + i * 0.07, y + h - 0.07, 0.035, 0.025, 0.05, 0.075, col, true)


func _vents(x: float, y: float, w: float, h: float) -> void:
	var n := clampi(int(h / 0.075), 3, 9)
	var vw := w * 0.78
	var vh := n * 0.06
	_add(x + w / 2.0, y + h / 2.0, vw + 0.04, vh + 0.04, 0.03, 0.06, Color(0.05, 0.055, 0.07))
	for i in n:
		_add(x + w / 2.0, y + h / 2.0 - vh / 2.0 + (i + 0.5) * vh / n, vw, 0.022, 0.06, 0.09, Color(0.18, 0.2, 0.24))


func _pipes(x: float, y: float, w: float, h: float) -> void:
	var vertical := w < h
	var n := _rng.randi_range(2, 4)
	for i in n:
		var d1 := _rng.randf_range(0.08, 0.13)
		var col: Color = GREYS[_rng.randi() % GREYS.size()].lightened(0.1)
		if vertical:
			var px := x + w * (i + 0.5) / n
			_add(px, y + h / 2.0, 0.045 + 0.02 * (i % 2), h * 0.94, 0.03, d1, col)
			var k := 0.15
			while k < h:
				_add(px, y + k, 0.085, 0.03, 0.03, d1 + 0.015, Color(0.08, 0.09, 0.11))
				k += 0.42
		else:
			var py := y + h * (i + 0.5) / n
			_add(x + w / 2.0, py, w * 0.94, 0.045 + 0.02 * (i % 2), 0.03, d1, col)
			var k := 0.15
			while k < w:
				_add(x + k, py, 0.03, 0.085, 0.03, d1 + 0.015, Color(0.08, 0.09, 0.11))
				k += 0.42


func _switches(x: float, y: float, w: float, h: float) -> void:
	var cols := clampi(int(w / 0.13), 2, 7)
	var rows := clampi(int(h / 0.13), 2, 6)
	_add(x + w / 2.0, y + h / 2.0, cols * 0.12 + 0.04, rows * 0.12 + 0.04, 0.03, 0.055, Color(0.05, 0.055, 0.07))
	for r in rows:
		for c in cols:
			var px := x + w / 2.0 + (c - (cols - 1) / 2.0) * 0.12
			var py := y + h / 2.0 + (r - (rows - 1) / 2.0) * 0.12
			var on := _rng.randf() < 0.22
			_add(px, py, 0.07, 0.07, 0.055, 0.075 + _rng.randf() * 0.03,
				GLOWS[_rng.randi() % GLOWS.size()] if on else Color(0.16, 0.18, 0.2), on)


func _machine(cx: float, cy: float, w: float, h: float) -> void:
	var mw := w * _rng.randf_range(0.55, 0.9)
	var mh := h * _rng.randf_range(0.5, 0.85)
	_add(cx, cy, mw, mh, 0.03, 0.15, Color(0.11, 0.125, 0.15))
	_add(cx, cy + mh * 0.25, mw * 0.8, mh * 0.18, 0.15, 0.17, Color(0.2, 0.22, 0.27))
	_add(cx, cy - mh * 0.12, mw * 0.8, mh * 0.04, 0.15, 0.17, Color(0.06, 0.07, 0.09))
	for i in 3:
		_add(cx - mw * 0.3 + i * mw * 0.3, cy - mh * 0.3, mw * 0.12, mh * 0.1, 0.15, 0.18, Color(0.24, 0.26, 0.3))
	_add(cx + mw / 2.0 - 0.03, cy, 0.03, mh * 0.9, 0.15, 0.2, Color(0.08, 0.09, 0.11))


func _screen(cx: float, cy: float, w: float, h: float) -> void:
	var sw := w * 0.8
	var sh := h * 0.6
	_add(cx, cy, sw + 0.05, sh + 0.05, 0.03, 0.08, Color(0.06, 0.065, 0.08))
	_add(cx, cy, sw, sh, 0.08, 0.085, Color(0.02, 0.05, 0.07))
	var col: Color = GLOWS[_rng.randi() % GLOWS.size()]
	var bars := _rng.randi_range(3, 6)
	for i in bars:
		var bw := sw * _rng.randf_range(0.2, 0.85)
		_add(cx - sw / 2.0 + 0.04 + bw / 2.0, cy + sh / 2.0 - 0.06 - i * (sh - 0.1) / bars, bw, 0.025, 0.085, 0.095, col, true)


func _hatch(cx: float, cy: float, w: float, h: float) -> void:
	var hw := minf(w * 0.8, 0.9)
	var hh := h * 0.75
	_add(cx, cy, hw, hh, 0.03, 0.08, Color(0.13, 0.145, 0.17))
	for sx in [-1.0, 1.0]:
		_add(cx + sx * (hw / 2.0 - 0.02), cy, 0.03, hh, 0.08, 0.1, Color(0.08, 0.09, 0.11))
	for sy in [-1.0, 1.0]:
		_add(cx, cy + sy * (hh / 2.0 - 0.02), hw, 0.03, 0.08, 0.1, Color(0.08, 0.09, 0.11))
	_add(cx, cy, hw * 0.55, 0.045, 0.1, 0.14, Color(0.3, 0.32, 0.36))
	# hazard stripes along the bottom
	var n := int(hw / 0.1)
	for i in n:
		_add(cx - hw / 2.0 + 0.05 + i * 0.1, cy - hh / 2.0 + 0.035, 0.05, 0.04, 0.1, 0.105,
			Color(0.9, 0.7, 0.1) if i % 2 == 0 else Color(0.05, 0.05, 0.05))


func _cables(x: float, y: float, w: float, h: float) -> void:
	var n := _rng.randi_range(3, 6)
	for i in n:
		var col: Color = [Color(0.04, 0.04, 0.05), Color(0.5, 0.12, 0.1), Color(0.1, 0.2, 0.45), Color(0.45, 0.4, 0.1)][_rng.randi() % 4]
		if w < h:
			_add(x + w * (i + 0.5) / n, y + h / 2.0, 0.028, h * _rng.randf_range(0.7, 0.96), 0.03, 0.065, col)
		else:
			_add(x + w / 2.0, y + h * (i + 0.5) / n, w * _rng.randf_range(0.7, 0.96), 0.028, 0.03, 0.065, col)
	var k := 0.2
	while k < (h if w < h else w):
		if w < h:
			_add(x + w / 2.0, y + k, w * 0.92, 0.035, 0.065, 0.085, Color(0.1, 0.11, 0.13))
		else:
			_add(x + k, y + h / 2.0, 0.035, h * 0.92, 0.065, 0.085, Color(0.1, 0.11, 0.13))
		k += 0.5


## A box on the wall: x along the wall, y up, depth d0..d1 out from the wall surface into the room.
func _add(x: float, y: float, w: float, h: float, d0: float, d1: float, color: Color, glow := false) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var depth := d1 - d0
	var t := Transform3D(Basis.from_scale(Vector3(w, h, depth)), Vector3(x, y, _z0 - _side * (d0 + depth / 2.0)))
	(_glow if glow else _solid).append([t, color])


func _emit(parent: Node3D) -> int:
	var total := _solid.size() + _glow.size()
	assert(total <= MAX_RECTS, "too many greeble rectangles: %d" % total)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var solid_mat := StandardMaterial3D.new()
	solid_mat.vertex_color_use_as_albedo = true
	solid_mat.metallic = 0.55
	solid_mat.roughness = 0.5
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = GLOW_SHADER
	for pair in [[_solid, solid_mat], [_glow, glow_mat]]:
		var items: Array = pair[0]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Greebles"
		mmi.multimesh = mm
		mmi.material_override = pair[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	return total
