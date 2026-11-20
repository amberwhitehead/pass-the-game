extends RefCounted
## The Officer's temporal patrol.
##   tick       clockwork drone, weaves in a sine wave
##   hourglass  drifting mine; bursts into sand when shot or when its time runs out
##   gunship    swoops in, fires aimed bursts, then leaves
##   gear       a slow spinning cog that sprays a ring of shots
##   courier    a carrier; drops a weapon capsule

const Sprites := preload("res://minigames/arcade/sprites.gd")
const Entities := preload("res://minigames/arcade/entities.gd")

const STATS := {
	"tick": {"hp": 1, "score": 100, "radius": 6.0},
	"hourglass": {"hp": 3, "score": 200, "radius": 6.0},
	"gunship": {"hp": 12, "score": 600, "radius": 10.0},
	"gear": {"hp": 18, "score": 500, "radius": 13.0},
	"courier": {"hp": 6, "score": 300, "radius": 9.0},
}


class Enemy:
	var kind := "tick"
	var pos := Vector2.ZERO
	var origin := Vector2.ZERO
	var hp := 1
	var radius := 6.0
	var score := 100
	var age := 0
	var dead := false
	var flash := 0
	var param := 0.0       ## Per-spawn variation (wave phase, exit direction).

	func _init(k: String, p: Vector2, extra := 0.0) -> void:
		kind = k
		pos = p
		origin = p
		param = extra
		var s: Dictionary = STATS[k]
		hp = s.hp
		radius = s.radius
		score = s.score

	func update(game) -> void:
		age += 1
		if flash > 0:
			flash -= 1
		match kind:
			"tick":
				pos.x -= 1.7
				pos.y = origin.y + sin(age * 0.07 + param) * 22.0
				if age % 110 == 60 and game.rank > 0.3:
					game.aim(pos, 2.2, "needle")
			"hourglass":
				pos.x -= 0.8
				pos.y = origin.y + sin(age * 0.03 + param) * 8.0
				if age > 260:
					burst(game)
					dead = true
			"gunship":
				if age < 60:
					pos.x = lerpf(origin.x, 300.0 - param * 20.0, ease_out(age / 60.0))
				elif age < 220:
					if age % 50 == 0:
						for k in 3:
							game.aim(pos + Vector2(-12, 2), 2.4, "orb", (k - 1) * 0.18)
				else:
					pos += Vector2(1.4, -1.2 if origin.y > 108 else 1.2)
			"gear":
				pos.x -= 0.55
				if age % 90 == 45:
					var n := 8
					for k in n:
						game.add_shot(Entities.Shot.new(pos, Vector2(1.6, 0).rotated(TAU * k / n + age * 0.01), "orb", true))
			"courier":
				pos.x -= 1.1
				pos.y = origin.y + sin(age * 0.04) * 6.0
		if pos.x < -40 or pos.x > 440 or pos.y < -40 or pos.y > 256:
			dead = true

	static func ease_out(t: float) -> float:
		return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

	## Hourglass mines spill a ring of sand.
	func burst(game) -> void:
		for k in 8:
			game.add_shot(Entities.Shot.new(pos, Vector2(1.3, 0).rotated(TAU * k / 8.0 + 0.2), "sand", true))

	func draw(ci: CanvasItem, _frame: int) -> void:
		if kind == "gear":
			_draw_gear(ci)
			return
		var tex: Texture2D = Sprites.flash(kind) if flash > 0 else Sprites.tex(kind)
		ci.draw_texture(tex, (pos - tex.get_size() / 2.0).round())

	func _draw_gear(ci: CanvasItem) -> void:
		var spin := age * 0.03
		var teeth := 10
		var outline := PackedVector2Array()
		for i in teeth * 4:
			var a := spin + TAU * i / (teeth * 4)
			var r := 14.0 if (i % 4) in [1, 2] else 10.5
			outline.append(pos.round() + Vector2(cos(a), sin(a)) * r)
		var body := Color("ffffff") if flash > 0 else Color("b38b1c")
		ci.draw_colored_polygon(outline, body)
		outline.append(outline[0])
		ci.draw_polyline(outline, Color("0b0b18"), 1.0)
		ci.draw_circle(pos.round(), 6.0, Color("ffe45c") if flash == 0 else Color.WHITE)
		ci.draw_circle(pos.round(), 3.0, Color("0b0b18"))
		for k in 3:
			var a := -spin * 2.0 + TAU * k / 3.0
			ci.draw_line(pos.round(), pos.round() + Vector2(cos(a), sin(a)) * 9.0, Color("6a2bb0"), 1.0)
