extends RefCounted
## Drawing kit for the Workshop's hand-drawn 2D diorama.
##
## Everything in the diorama is drawn from code with these helpers: flat fills, a soft
## highlight and shade inside each shape, and a warm ink outline. Outlines "boil" (wobble
## between a few fixed variants a few times a second) the way hand-drawn animation does.
## Call them from a CanvasItem's _draw(); `ci` is that CanvasItem.

const OUTLINE := Color("3a2618")
const BOIL_FPS := 6.0
const BOIL_FRAMES := 3


## Which boil variant is showing now (shared by every drawing so they boil together).
static func boil_frame() -> int:
	return int(Time.get_ticks_msec() / 1000.0 * BOIL_FPS) % BOIL_FRAMES


## Points of an ellipse centred on `c`.
static func ellipse(c: Vector2, r: Vector2, n := 28, start := 0.0, end := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var closed := is_equal_approx(end - start, TAU)
	var count := n if closed else n + 1
	for i in count:
		var a := start + (end - start) * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## A rectangle with rounded corners, as a polygon.
static func rrect(r: Rect2, radius := 10.0, per_corner := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for i in per_corner + 1:
			var a: float = c[1] + PI / 2.0 * float(i) / float(per_corner)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


## A smooth closed curve through `pts` (Catmull-Rom), for organic shapes.
static func smooth(pts: PackedVector2Array, steps := 6, closed := true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 3:
		return pts
	var segs := n if closed else n - 1
	for i in segs:
		var p0 := pts[(i - 1 + n) % n] if closed or i > 0 else pts[0]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n] if closed or i + 2 < n else pts[n - 1]
		for s in steps:
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(pts[n - 1])
	return out


## Nudges every point a little, differently per boil frame, so lines look hand drawn.
static func wobble(pts: PackedVector2Array, amount := 1.2, seed := 0) -> PackedVector2Array:
	if amount <= 0.0:
		return pts
	var out := PackedVector2Array()
	out.resize(pts.size())
	var f := boil_frame()
	for i in pts.size():
		var h := _hash(i * 7 + seed * 131 + f * 977)
		var a := h * TAU
		var m := amount * (0.4 + 0.6 * _hash(i * 13 + seed * 17 + f * 59))
		out[i] = pts[i] + Vector2(cos(a), sin(a)) * m
	return out


## Draws a filled shape with a soft inner highlight and shade, then its ink outline.
## `light` and `shade` are 0..1 strengths; set them to 0 for a perfectly flat fill.
static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, width := 3.0,
		seed := 0, light := 0.18, shade := 0.16, outline := OUTLINE, wob := 1.0) -> void:
	var w := wobble(pts, wob, seed)
	if w.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(w).is_empty():
		ci.draw_colored_polygon(w, fill)
		var bounds := _bounds(w)
		var inset := clampf(minf(bounds.size.x, bounds.size.y) * 0.12, 2.0, 14.0)
		if shade > 0.0:
			for poly in Geometry2D.offset_polygon(w, -inset):
				var moved := _shift(poly, Vector2(-inset * 0.5, -inset * 0.6))
				var clipped := Geometry2D.clip_polygons(w, moved)
				for c in clipped:
					if not Geometry2D.triangulate_polygon(c).is_empty():
						ci.draw_colored_polygon(c, fill.darkened(shade))
		if light > 0.0:
			for poly in Geometry2D.offset_polygon(w, -inset * 1.4):
				var moved := _shift(poly, Vector2(-inset * 0.35, -inset * 0.5))
				for c in Geometry2D.intersect_polygons(moved, w):
					if not Geometry2D.triangulate_polygon(c).is_empty():
						ci.draw_colored_polygon(c, fill.lightened(light))
	if width > 0.0:
		var loop := w.duplicate()
		loop.append(w[0])
		ci.draw_polyline(loop, outline, width, true)


## An open ink stroke (a wire, a whisker, a crease).
static func line(ci: CanvasItem, pts: PackedVector2Array, color := OUTLINE, width := 3.0,
		seed := 0, wob := 0.8) -> void:
	ci.draw_polyline(wobble(pts, wob, seed), color, width, true)


## A filled circle with outline.
static func dot(ci: CanvasItem, c: Vector2, r: float, fill: Color, width := 2.5, seed := 0,
		light := 0.2, shade := 0.12) -> void:
	shape(ci, ellipse(c, Vector2(r, r), maxi(12, int(r * 0.9))), fill, width, seed, light, shade)


## Wraps a shape's points by an affine transform (offset, rotation, scale).
static func xform(pts: PackedVector2Array, t: Transform2D) -> PackedVector2Array:
	return t * pts


static func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func _hash(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0
