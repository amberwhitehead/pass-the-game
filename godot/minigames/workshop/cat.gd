extends "res://minigames/workshop/thing.gd"
## Fuse, the Engineer's ginger tabby, drawn from code.
##
## The node's position is the point between the cat's feet on whatever it stands on;
## `facing` is 1 (right) or -1 (left). Poses: "sleep", "sit", "stand", "walk", "jump",
## "eat", "crouch". Accessories record what has happened to this cat: tangled in yarn, a
## sardine-tin lid on one ear. A cat displaced in time (`displaced`) shimmers faintly.
## Movement helpers return when the move finishes, so story code can `await` them.

const P := preload("res://minigames/workshop/palette.gd")

signal arrived

var pose := "sleep":
	set(v):
		pose = v
		queue_redraw()
var facing := 1.0:
	set(v):
		facing = signf(v) if v != 0.0 else 1.0
		scale.x = facing * absf(scale.y)
var yarn := false:
	set(v):
		yarn = v
		queue_redraw()
var lid := false:
	set(v):
		lid = v
		queue_redraw()
var displaced := false
var tail_mood := 1.0            ## Tail swish speed: higher looks more excited.
var jump_lean := 0.0            ## Body tilt during a jump, radians.

var _t := randf() * 10.0
var _walk_phase := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _ear_flick := 0.0
var _move: Tween


func _init() -> void:
	id = "cat"
	hover_name = "Fuse"


func _tick(delta: float) -> void:
	_t += delta
	if pose == "walk":
		_walk_phase += delta * 9.0
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 5.0)
		if randf() < 0.4:
			_ear_flick = 0.3
	_blink = maxf(0.0, _blink - delta)
	_ear_flick = maxf(0.0, _ear_flick - delta)
	queue_redraw()


func hit_test(global_point: Vector2) -> bool:
	if id == "" or not enabled or not is_visible_in_tree():
		return false
	var p := to_local(global_point)
	return Rect2(-70, -110, 150, 116).has_point(p)


# --- movement --------------------------------------------------------------------------

## Walks along the ground to `x` (and `y`, if given), then stands.
func walk_to(x: float, y := NAN, speed := 170.0) -> void:
	var target := Vector2(x, position.y if is_nan(y) else y)
	if target.distance_to(position) < 2.0:
		return
	facing = signf(target.x - position.x) if absf(target.x - position.x) > 1.0 else facing
	pose = "walk"
	_stop()
	_move = create_tween()
	_move.tween_property(self, "position", target, position.distance_to(target) / speed)
	await _move.finished
	pose = "stand"
	arrived.emit()


## Leaps in an arc to `target`, landing in `land_pose`.
func jump_to(target: Vector2, height := 120.0, duration := 0.6, land_pose := "stand") -> void:
	facing = signf(target.x - position.x) if absf(target.x - position.x) > 1.0 else facing
	pose = "crouch"
	await get_tree().create_timer(0.25).timeout
	pose = "jump"
	var start := position
	var rise := (start.y - target.y)
	_stop()
	_move = create_tween()
	_move.tween_method(func(t: float):
		var p := start.lerp(target, t)
		p.y -= sin(t * PI) * height
		position = p
		var dy := cos(t * PI) * height * PI + rise
		jump_lean = clampf(-atan2(dy * 0.6, absf(target.x - start.x) + 1.0) * 0.5, -0.7, 0.7)
		, 0.0, 1.0, duration)
	await _move.finished
	jump_lean = 0.0
	pose = "crouch"
	await get_tree().create_timer(0.12).timeout
	pose = land_pose
	arrived.emit()


func _stop() -> void:
	if _move and _move.is_valid():
		_move.kill()


# --- drawing ---------------------------------------------------------------------------

func _paint() -> void:
	if displaced:
		var a := 0.25 + 0.15 * sin(_t * 5.0)
		var halo := Ink.ellipse(Vector2(0, -38), Vector2(78, 54), 24)
		halo.append(halo[0])
		draw_polyline(Ink.wobble(halo, 4.0, 7), Color(P.PORTAL, a), 6.0, true)
	match pose:
		"sleep":
			_sleeping()
		"sit":
			_sitting()
		"jump":
			_standing(0.0, true)
		"crouch":
			_standing(0.0, false, 0.75)
		"eat":
			_standing(0.0, false, 1.0, true)
		"walk":
			_standing(_walk_phase)
		_:
			_standing(0.0)


func _tail(base: Vector2, pts: Array, width := 11.0) -> void:
	var line := PackedVector2Array([base])
	for p in pts:
		line.append(p)
	var curve := Ink.smooth(line, 5, false)
	draw_polyline(Ink.wobble(curve, 0.8, 30), Ink.OUTLINE, width + 6.0, true)
	draw_polyline(Ink.wobble(curve, 0.8, 30), P.CAT, width, true)
	var tip := curve[curve.size() - 1]
	draw_circle(tip, width * 0.5, P.CAT_STRIPE)


func _leg(top: Vector2, foot: Vector2, seed: int, back := false) -> void:
	var c := P.CAT.darkened(0.12) if back else P.CAT
	var dir := (foot - top).normalized()
	var side := Vector2(-dir.y, dir.x) * 7.0
	var pts := PackedVector2Array([top - side, top + side, foot + side * 0.9, foot - side * 0.9])
	Ink.shape(self, Ink.smooth(pts, 3), c, 3.0, seed, 0.0, 0.0)
	Ink.shape(self, Ink.ellipse(foot + Vector2(3, -2), Vector2(9, 5), 10), c.lightened(0.15), 2.5, seed + 1, 0.0, 0.0)


func _head(c: Vector2, tilt := 0.0, eyes_closed := false) -> void:
	var t := Transform2D(tilt, c)
	var flick := sin(_ear_flick * 40.0) * 0.25 if _ear_flick > 0.0 else 0.0
	# Ears.
	for side in [-1.0, 1.0]:
		var e := PackedVector2Array([Vector2(side * 6 + 2, -16), Vector2(side * 18 + 2, -40 + (flick if side > 0 else 0.0) * 30), Vector2(side * 22 + 2, -10)])
		Ink.shape(self, t * e, P.CAT, 3.0, 40 + int(side), 0.1, 0.0)
		Ink.shape(self, t * PackedVector2Array([Vector2(side * 9 + 2, -16), Vector2(side * 17 + 2, -32), Vector2(side * 19 + 2, -14)]), Color("e98f8a"), 0.0, 42 + int(side), 0.0, 0.0)
	Ink.shape(self, t * Ink.smooth(PackedVector2Array([Vector2(-24, 0), Vector2(-18, -18), Vector2(0, -24), Vector2(20, -18),
		Vector2(28, 2), Vector2(18, 18), Vector2(0, 21), Vector2(-18, 16)]), 4), P.CAT, 3.0, 44, 0.18, 0.1)
	# Forehead stripes.
	for k in 3:
		Ink.line(self, t * PackedVector2Array([Vector2(-6 + k * 6, -22), Vector2(-4 + k * 5, -12)]), P.CAT_STRIPE, 3.0, 45 + k)
	Ink.shape(self, t * Ink.ellipse(Vector2(12, 8), Vector2(13, 9), 12), P.CAT_BELLY, 0.0, 48, 0.0, 0.0)
	var closed := eyes_closed or _blink > 0.0
	for ex in [0.0, 17.0]:
		if closed:
			Ink.line(self, t * Ink.ellipse(Vector2(ex, -2), Vector2(5, 3), 6, 0.2, PI - 0.2), Ink.OUTLINE, 2.5, 49)
		else:
			Ink.shape(self, t * Ink.ellipse(Vector2(ex, -3), Vector2(5, 6), 10), Color("f4f0a8"), 2.0, 50, 0.0, 0.0)
			draw_colored_polygon(t * Ink.ellipse(Vector2(ex + 1, -3), Vector2(1.8, 4.5), 8), Ink.OUTLINE)
	draw_colored_polygon(t * PackedVector2Array([Vector2(20, 5), Vector2(27, 5), Vector2(23.5, 9)]), Color("d66a6a"))
	for k in 2:
		Ink.line(self, t * PackedVector2Array([Vector2(26, 9 + k * 4), Vector2(44, 6 + k * 7)]), Ink.OUTLINE, 1.5, 51 + k)
		Ink.line(self, t * PackedVector2Array([Vector2(4, 9 + k * 4), Vector2(-14, 7 + k * 7)]), Ink.OUTLINE, 1.5, 53 + k)
	if lid:
		# A sardine-tin lid stuck jauntily on the right ear.
		var l := t * Transform2D(-0.5, Vector2(18, -36)) * Ink.ellipse(Vector2.ZERO, Vector2(16, 6), 14)
		Ink.shape(self, l, P.CHROME, 2.5, 56, 0.35, 0.1)
		Ink.line(self, t * PackedVector2Array([Vector2(24, -46), Vector2(34, -54), Vector2(30, -60)]), P.CHROME.darkened(0.3), 2.5, 57)


func _yarn_over(center: Vector2, r: Vector2) -> void:
	if not yarn:
		return
	for k in 4:
		var a := 0.4 + k * 0.8
		var loop := Ink.ellipse(center + Vector2(k * 6 - 9, 0), Vector2(r.x * (0.5 + 0.15 * k), r.y), 16, a, a + PI * 1.3)
		Ink.line(self, loop, P.YARN, 3.5, 60 + k, 1.2)
	Ink.line(self, PackedVector2Array([center + Vector2(-r.x, r.y * 0.6), center + Vector2(-r.x - 14, r.y + 10), center + Vector2(-r.x - 4, r.y + 22)]), P.YARN, 3.5, 64)


func _stripes(center: Vector2, r: Vector2) -> void:
	for k in 4:
		var x := center.x - r.x * 0.55 + k * r.x * 0.3
		Ink.line(self, PackedVector2Array([Vector2(x, center.y - r.y * 0.95), Vector2(x + 4, center.y - r.y * 0.4)]), P.CAT_STRIPE, 4.0, 70 + k)


func _standing(phase: float, airborne := false, squash := 1.0, eating := false) -> void:
	var sw := sin(phase)
	var bob := absf(cos(phase)) * 3.0 if phase != 0.0 else sin(_t * 2.0) * 0.8
	var body_c := Vector2(0, -42 * squash - bob)
	var body_r := Vector2(46, 22 * (1.1 - (squash - 0.75) * 0.4))
	if airborne:
		body_r = Vector2(54, 19)
	var lean := Transform2D(jump_lean, Vector2.ZERO)
	# Tail first (behind).
	var wag := sin(_t * 2.2 * tail_mood) * 12.0
	if airborne:
		_tail(lean * (body_c + Vector2(-44, -4)), [lean * (body_c + Vector2(-80, -6)), lean * (body_c + Vector2(-108, -2 + wag * 0.3))])
	else:
		_tail(body_c + Vector2(-42, -6), [body_c + Vector2(-66, -30 + wag * 0.4), body_c + Vector2(-70 + wag, -62), body_c + Vector2(-58 + wag * 1.3, -76)])
	# Back legs (far side), then body, then near legs.
	var leg_y := -body_c.y - 14
	if airborne:
		_leg(lean * (body_c + Vector2(-30, 8)), lean * (body_c + Vector2(-66, 26)), 80, true)
		_leg(lean * (body_c + Vector2(30, 8)), lean * (body_c + Vector2(70, 18)), 82, true)
	else:
		_leg(body_c + Vector2(-28, 10), Vector2(-30 - sw * 14, 0), 80, true)
		_leg(body_c + Vector2(30, 10), Vector2(30 + sw * 14, 0), 82, true)
	var body := lean * Ink.ellipse(body_c, body_r, 26)
	Ink.shape(self, body, P.CAT, 3.5, 84, 0.18, 0.14)
	Ink.shape(self, lean * Ink.ellipse(body_c + Vector2(6, body_r.y * 0.45), Vector2(body_r.x * 0.6, body_r.y * 0.38), 16), P.CAT_BELLY, 0.0, 85, 0.0, 0.0)
	_stripes(lean * body_c, body_r)
	if airborne:
		_leg(lean * (body_c + Vector2(-24, 10)), lean * (body_c + Vector2(-60, 30)), 86)
		_leg(lean * (body_c + Vector2(36, 8)), lean * (body_c + Vector2(76, 24)), 88)
	else:
		_leg(body_c + Vector2(-22, 12), Vector2(-24 + sw * 14, 0), 86)
		_leg(body_c + Vector2(36, 12), Vector2(36 - sw * 14, 0), 88)
	_yarn_over(lean * body_c, body_r)
	var head_c := body_c + Vector2(48, -20)
	if eating:
		head_c = Vector2(56, -22 + sin(_t * 14.0) * 2.0)
	elif squash < 1.0:
		head_c = body_c + Vector2(50, -8)
	_head(lean * head_c, jump_lean + (0.35 if eating else 0.0))


func _sitting() -> void:
	var breathe := sin(_t * 2.0) * 1.2
	var wag := sin(_t * 1.6 * tail_mood) * 8.0
	_tail(Vector2(-22, -8), [Vector2(-40, -4), Vector2(-30 + wag * 0.3, 6), Vector2(10 + wag, 2)], 10.0)
	_leg(Vector2(-14, -30), Vector2(-26, 0), 90, true)
	var body := Transform2D(-0.35, Vector2(-4, -44)) * Ink.ellipse(Vector2.ZERO, Vector2(28, 40 + breathe), 24)
	Ink.shape(self, body, P.CAT, 3.5, 91, 0.18, 0.14)
	Ink.shape(self, Transform2D(-0.35, Vector2(4, -40)) * Ink.ellipse(Vector2(6, 0), Vector2(14, 28), 16), P.CAT_BELLY, 0.0, 92, 0.0, 0.0)
	for k in 3:
		Ink.line(self, PackedVector2Array([Vector2(-28 + k * 4, -60 + k * 14), Vector2(-14 + k * 4, -56 + k * 14)]), P.CAT_STRIPE, 4.0, 93 + k)
	_leg(Vector2(8, -36), Vector2(14, 0), 96)
	_leg(Vector2(18, -36), Vector2(26, 0), 98)
	_yarn_over(Vector2(-4, -44), Vector2(28, 30))
	_head(Vector2(10, -88 + breathe * 0.5), 0.05)


func _sleeping() -> void:
	var breathe := sin(_t * 1.5) * 2.0
	_tail(Vector2(-40, -10), [Vector2(-50, 0), Vector2(-20, 4), Vector2(30, 2)], 10.0)
	var body := Ink.ellipse(Vector2(0, -24 - breathe * 0.4), Vector2(50, 24 + breathe), 26)
	Ink.shape(self, body, P.CAT, 3.5, 100, 0.18, 0.14)
	_stripes(Vector2(-4, -24), Vector2(50, 24))
	_yarn_over(Vector2(0, -24), Vector2(50, 24))
	_head(Vector2(34, -24), 0.35, true)
	# Floating Zs.
	for k in 3:
		var ph := fmod(_t * 0.35 + k * 0.33, 1.0)
		var p := Vector2(60 + ph * 30 + sin(ph * 8.0) * 6, -60 - ph * 70)
		var s := 6.0 + ph * 6.0
		var c := Color(Ink.OUTLINE, 1.0 - ph)
		# Drawn in flipped space when facing left, so mirror the letter back.
		var w := s * facing
		draw_polyline(PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(0, s), p + Vector2(w, s)]), c, 2.0)
