extends "res://minigames/workshop/thing.gd"
## A hand-drawn person for the Workshop diorama: the 50s Engineer or the Officer.
##
## The node's position is between the feet. `gesture` poses the arms: "idle", "point"
## (toward `point_at`, stage space), "shrug", "think", "hold" (cradling a cat), "salute",
## "cheer". `talking` animates the mouth.

const P := preload("res://minigames/workshop/palette.gd")

@export var kind := "engineer"
var gesture := "idle":
	set(v):
		gesture = v
		queue_redraw()
var talking := false
var point_at := Vector2.ZERO
var facing := 1.0:
	set(v):
		facing = signf(v) if v != 0.0 else 1.0
		scale.x = facing

var _t := randf() * 10.0
var _blink := 0.0
var _next_blink := 3.0


func _init() -> void:
	id = "person"


func _ready() -> void:
	if kind == "engineer":
		id = "engineer"
		hover_name = "The Engineer"
	else:
		id = "officer"
		hover_name = "The Officer"
	hit_rect = Rect2(-60, -330, 120, 330)


## Walks to `x` along the floor, with a little bob; resolves on arrival.
func walk_to(x: float, duration := 1.0) -> void:
	facing = signf(x - position.x) if absf(x - position.x) > 1.0 else facing
	var start := position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		position = Vector2(lerpf(start.x, x, t), start.y - absf(sin(t * PI * 6.0)) * 6.0), 0.0, 1.0, duration)
	await tw.finished
	facing = 1.0


func _tick(delta: float) -> void:
	_t += delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


func _paint() -> void:
	var sway := sin(_t * 1.4) * 1.5
	var engineer := kind == "engineer"
	var shirt := Color("f4f1e6") if engineer else Color("6b6a3e")
	var trousers := Color("6d6f72") if engineer else Color("57562f")
	var shoes := Color("5a3a26") if engineer else Color("1f1a16")
	# Legs.
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * 16, -150)
		var foot := Vector2(side * 22, -4)
		Ink.shape(self, PackedVector2Array([hip + Vector2(-15, 0), hip + Vector2(15, 0), foot + Vector2(12, -10), foot + Vector2(-12, -10)]), trousers, 3.0, 400 + int(side), 0.1, 0.15)
		Ink.shape(self, Ink.rrect(Rect2(foot + Vector2(-14, -14), Vector2(36, 16)), 7), shoes, 3.0, 402 + int(side), 0.25)
	# Torso.
	var torso := PackedVector2Array([Vector2(-44, -258 + sway), Vector2(44, -258 + sway), Vector2(40, -150), Vector2(-40, -150)])
	Ink.shape(self, Ink.smooth(torso, 3), shirt, 3.5, 404, 0.14, 0.16)
	Ink.shape(self, Ink.rrect(Rect2(-42, -164, 84, 18), 5), Color("3a2a1e") if engineer else Color("4a4826"), 3.0, 405)
	Ink.shape(self, Ink.rrect(Rect2(-8, -162, 16, 14), 3), P.BRASS, 2.0, 406)
	if engineer:
		# Narrow black tie, pocket protector with pens, a slide rule in the pocket.
		Ink.shape(self, PackedVector2Array([Vector2(-6, -252 + sway), Vector2(6, -252 + sway), Vector2(9, -180), Vector2(0, -170), Vector2(-9, -180)]), Color("1f2326"), 2.5, 407)
		Ink.shape(self, Ink.rrect(Rect2(14, -236 + sway, 22, 26), 3), Color("dfe9f0"), 2.0, 408, 0.0)
		for k in 3:
			Ink.line(self, PackedVector2Array([Vector2(18 + k * 6, -236 + sway), Vector2(18 + k * 6, -250 + sway)]), [P.RED, Color("2f6aa3"), Ink.OUTLINE][k], 3.0, 409 + k)
		Ink.shape(self, Ink.rrect(Rect2(-36, -246 + sway, 8, 46), 2), P.CREAM, 2.0, 412, 0.0)
	else:
		# Uniform: buttons, a ribbon bar, shoulder boards.
		for k in 4:
			Ink.dot(self, Vector2(0, -244 + k * 22 + sway), 3.5, P.BRASS, 1.5, 413 + k)
		for k in 3:
			draw_rect(Rect2(-36 + k * 9, -238 + sway, 9, 6), [P.RED, Color("2f6aa3"), P.BRASS][k])
		for side in [-1.0, 1.0]:
			Ink.shape(self, Ink.rrect(Rect2(side * 32 - 14, -262 + sway, 28, 10), 3), P.BRASS, 2.0, 417 + int(side))
	_arms(shirt, sway)
	_head(Vector2(0, -292 + sway), engineer)


func _arms(sleeve: Color, sway: float) -> void:
	var lsh := Vector2(-40, -246 + sway)
	var rsh := Vector2(40, -246 + sway)
	var l_hand := Vector2(-48, -160)
	var r_hand := Vector2(48, -160)
	match gesture:
		"point":
			var dir := (to_local(point_at) - rsh).normalized() if point_at != Vector2.ZERO else Vector2(1, -0.3).normalized()
			r_hand = rsh + dir * 108
		"shrug":
			l_hand = Vector2(-86, -232 + sin(_t * 3.0) * 4)
			r_hand = Vector2(86, -232 + sin(_t * 3.0) * 4)
		"think":
			r_hand = Vector2(12, -276)
		"hold":
			l_hand = Vector2(-20, -196)
			r_hand = Vector2(30, -190)
		"salute":
			r_hand = Vector2(26, -318)
		"cheer":
			l_hand = Vector2(-70, -330 + sin(_t * 8.0) * 8)
			r_hand = Vector2(70, -330 - sin(_t * 8.0) * 8)
		_:
			l_hand += Vector2(0, sin(_t * 1.4) * 2)
			r_hand += Vector2(0, sin(_t * 1.4 + 1.0) * 2)
	for pair in [[lsh, l_hand, 420], [rsh, r_hand, 422]]:
		var sh: Vector2 = pair[0]
		var hand: Vector2 = pair[1]
		var elbow := (sh + hand) * 0.5 + (hand - sh).orthogonal().normalized() * 10.0 * signf(sh.x)
		Ink.line(self, PackedVector2Array([sh, elbow, hand]), Ink.OUTLINE, 22.0, pair[2])
		Ink.line(self, PackedVector2Array([sh, elbow, hand]), sleeve if kind == "officer" else P.SKIN, 16.0, pair[2])
		if kind == "engineer":
			# Short sleeves.
			Ink.line(self, PackedVector2Array([sh, sh.lerp(elbow, 0.55)]), Ink.OUTLINE, 26.0, pair[2] + 1)
			Ink.line(self, PackedVector2Array([sh, sh.lerp(elbow, 0.55)]), sleeve, 20.0, pair[2] + 1)
		Ink.dot(self, hand, 11, P.SKIN, 2.5, pair[2] + 2, 0.15)


func _head(c: Vector2, engineer: bool) -> void:
	Ink.shape(self, Ink.rrect(Rect2(c + Vector2(-12, 22), Vector2(24, 20)), 6), P.SKIN, 3.0, 430, 0.0)
	var face := Ink.smooth(PackedVector2Array([c + Vector2(-34, -10), c + Vector2(-28, -42), c + Vector2(0, -50),
		c + Vector2(30, -42), c + Vector2(36, -6), c + Vector2(26, 26), c + Vector2(0, 36), c + Vector2(-26, 26)]), 4)
	Ink.shape(self, face, P.SKIN, 3.5, 431, 0.15, 0.12)
	Ink.dot(self, c + Vector2(-35, 2), 8, P.SKIN, 2.5, 432)
	var shut := _blink > 0.0
	if engineer:
		# Crew cut.
		Ink.shape(self, PackedVector2Array([c + Vector2(-34, -16), c + Vector2(-32, -44), c + Vector2(-10, -56), c + Vector2(20, -54),
			c + Vector2(36, -34), c + Vector2(34, -18), c + Vector2(20, -34), c + Vector2(-14, -36)]), Color("3a2a1e"), 3.0, 433, 0.15, 0.0)
		# Horn-rimmed glasses.
		for x in [-4.0, 22.0]:
			Ink.shape(self, Ink.rrect(Rect2(c + Vector2(x - 11, -14), Vector2(22, 17)), 5), Color(0.9, 0.95, 1.0, 0.35), 3.5, 434, 0.0, 0.0)
		Ink.line(self, PackedVector2Array([c + Vector2(7, -8), c + Vector2(11, -8)]), Ink.OUTLINE, 3.0, 435)
	else:
		# Peaked cap and a proud moustache.
		Ink.shape(self, PackedVector2Array([c + Vector2(-40, -22), c + Vector2(-36, -52), c + Vector2(-8, -66), c + Vector2(30, -62),
			c + Vector2(42, -40), c + Vector2(40, -22)]), Color("57562f"), 3.0, 436, 0.15, 0.1)
		Ink.shape(self, PackedVector2Array([c + Vector2(-8, -26), c + Vector2(56, -24), c + Vector2(50, -14), c + Vector2(-6, -16)]), Color("1f1a16"), 3.0, 437, 0.2)
		Ink.dot(self, c + Vector2(4, -44), 7, P.BRASS, 2.0, 438)
		Ink.shape(self, Ink.smooth(PackedVector2Array([c + Vector2(4, 12), c + Vector2(18, 6), c + Vector2(34, 12), c + Vector2(30, 18), c + Vector2(18, 14), c + Vector2(6, 18)]), 3),
			Color("6b4a2e"), 2.5, 439, 0.1)
	for x in [-4.0, 22.0]:
		if shut:
			Ink.line(self, PackedVector2Array([c + Vector2(x - 5, -5), c + Vector2(x + 5, -5)]), Ink.OUTLINE, 2.5, 440)
		else:
			draw_circle(c + Vector2(x + 1, -5), 3.5, Ink.OUTLINE)
	if not engineer:
		# Smug half-lidded brows.
		for x in [-4.0, 22.0]:
			Ink.line(self, PackedVector2Array([c + Vector2(x - 8, -12), c + Vector2(x + 7, -9)]), Ink.OUTLINE, 3.0, 441)
	Ink.line(self, PackedVector2Array([c + Vector2(28, -4), c + Vector2(38, 8), c + Vector2(30, 10)]), Ink.OUTLINE, 2.5, 442)
	var open := talking and fmod(_t * 7.0, 1.0) > 0.45
	var mouth_y := 22.0 if engineer else 24.0
	if open:
		Ink.shape(self, Ink.ellipse(c + Vector2(16, mouth_y), Vector2(8, 6), 10), Color("6a2a2a"), 2.0, 443, 0.0, 0.0)
	elif engineer:
		Ink.line(self, Ink.ellipse(c + Vector2(16, mouth_y - 4), Vector2(9, 5), 8, 0.3, PI - 0.3), Ink.OUTLINE, 2.5, 444)
	else:
		# A smirk.
		Ink.line(self, PackedVector2Array([c + Vector2(8, mouth_y), c + Vector2(20, mouth_y), c + Vector2(27, mouth_y - 5)]), Ink.OUTLINE, 2.5, 445)
