extends RefCounted
## Small moving things: shots (both sides), explosion sparks and weapon capsules.

const Pix := preload("res://minigames/arcade/pixel_art.gd")

const WEAPON_NAMES := ["PULSE", "FAN", "SEEKER"]
const WEAPON_COLORS := [Color("6ef2ff"), Color("ffe45c"), Color("d77cff")]


## A bullet. Player shots damage enemies; enemy shots (hostile) hit the player.
class Shot:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 2.0
	var damage := 1
	var hostile := false
	var kind := "pulse"     ## pulse, fan, missile, orb, sand, needle
	var life := 600
	var homing := false
	var dead := false

	func _init(p: Vector2, v: Vector2, k: String, is_hostile := false) -> void:
		pos = p
		vel = v
		kind = k
		hostile = is_hostile
		match k:
			"missile":
				damage = 2
				homing = true
				radius = 3.0
			"orb":
				radius = 2.5
			"sand":
				radius = 2.0

	func update(game) -> void:
		if homing:
			var target = game.nearest_enemy(pos)
			if target != null:
				var want: Vector2 = (target.pos - pos).normalized() * vel.length()
				vel = vel.lerp(want, 0.08).normalized() * vel.length()
		pos += vel
		life -= 1
		if life <= 0 or pos.x < -16 or pos.x > 400 or pos.y < -16 or pos.y > 232:
			dead = true

	func draw(ci: CanvasItem) -> void:
		var p := pos.round()
		match kind:
			"pulse":
				ci.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(8, 2)), Color("6ef2ff"))
				ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(4, 2)), Color.WHITE)
			"fan":
				ci.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(4, 4)), Color("ffe45c"))
				ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color.WHITE)
			"missile":
				var back := p - vel.normalized() * 5.0
				ci.draw_line(back, p, Color("d77cff"), 2.0)
				ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), Color.WHITE)
				ci.draw_rect(Rect2(back + Vector2(-1, -1), Vector2(2, 2)), Color("ffa23a"))
			"orb":
				ci.draw_circle(p, 3.0, Color("ff4d4d"))
				ci.draw_circle(p, 1.5, Color("ffe0e0"))
			"sand":
				ci.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(4, 4)), Color("b8874f"))
				ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color("f2d2a9"))
			"needle":
				ci.draw_line(p - vel.normalized() * 4.0, p + vel.normalized() * 2.0, Color("ffa23a"), 2.0)
				ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color("fff4c0"))


## Explosion debris and muzzle sparks.
class Spark:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 20
	var max_life := 20
	var color := Color.WHITE
	var ring := false
	var size := 2.0

	func update() -> void:
		pos += vel
		vel *= 0.94
		life -= 1

	func draw(ci: CanvasItem) -> void:
		var t := float(life) / float(max_life)
		var c := Color(color, clampf(t * 1.5, 0.0, 1.0))
		if ring:
			ci.draw_arc(pos.round(), size * (1.0 - t) + 2.0, 0.0, TAU, 16, c, 1.0)
		else:
			var s := maxf(1.0, roundf(size * t))
			ci.draw_rect(Rect2(pos.round() - Vector2(s, s) * 0.5, Vector2(s, s)), c)


## A weapon capsule. Capsules from couriers cycle their weapon every two seconds; a
## capsule dropped when the player is shot down keeps the weapon that was lost.
class Pickup:
	var pos := Vector2.ZERO
	var weapon := 0
	var cycles := true
	var age := 0
	var dead := false

	func update() -> void:
		age += 1
		pos.x -= 0.45
		pos.y += sin(age * 0.06) * 0.35
		if cycles and age % 120 == 0:
			weapon = (weapon + 1) % WEAPON_NAMES.size()
		if pos.x < -12:
			dead = true

	func draw(ci: CanvasItem) -> void:
		var p := pos.round()
		var col: Color = WEAPON_COLORS[weapon]
		var blink := (age / 6) % 2 == 0
		ci.draw_rect(Rect2(p - Vector2(7, 6), Vector2(14, 12)), Color("0b0b18"))
		ci.draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), col.darkened(0.45))
		ci.draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), col if blink else col.darkened(0.2))
		Pix.text(ci, p - Vector2(2, 3), WEAPON_NAMES[weapon][0], Color("0b0b18"), 1, 0, false)
