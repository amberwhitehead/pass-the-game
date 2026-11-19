extends RefCounted
## The stage boss: the CHRONARCH, the temporal patrol's clock-tower dreadnought. Its clock
## face is the weak point. It cycles three attacks, faster below half health:
##   sweep  the minute hand turns and sprays shots along it
##   burst  top and bottom cannons fire aimed fans
##   sand   it lobs hourglass mines that burst into sand

const Entities := preload("res://minigames/arcade/entities.gd")
const Enemies := preload("res://minigames/arcade/enemies.gd")
const Pix := preload("res://minigames/arcade/pixel_art.gd")

const MAX_HP := 420
const PATTERNS := ["sweep", "burst", "sand"]

var pos := Vector2(470, 112)
var hp := MAX_HP
var radius := 26.0           ## The clock face's hit radius.
var age := 0
var pattern := 0
var pattern_age := 0
var flash := 0
var dying := 0               ## Frames into the death sequence (0 = alive).
var dead := false
var _hand := 0.0


func update(game) -> void:
	age += 1
	if flash > 0:
		flash -= 1
	if dying > 0:
		dying += 1
		if dying % 6 == 0:
			game.explode(pos + Vector2(randf_range(-40, 40), randf_range(-50, 50)), Color("ffa23a"), 14)
		if dying > 150:
			game.explode(pos, Color.WHITE, 60)
			dead = true
		return
	# Enter, then bob up and down.
	var home_x := 300.0
	if pos.x > home_x:
		pos.x = maxf(home_x, pos.x - 1.2)
		return
	pos.y = 112.0 + sin(age * 0.012) * 46.0
	var angry := hp < MAX_HP / 2
	pattern_age += 1
	var length := 260
	if pattern_age > length:
		pattern = (pattern + 1) % PATTERNS.size()
		pattern_age = 0
	match PATTERNS[pattern]:
		"sweep":
			_hand += 0.045 if not angry else 0.065
			if pattern_age % (5 if not angry else 3) == 0 and pattern_age > 30:
				var dir := Vector2(cos(_hand), sin(_hand))
				game.add_shot(Entities.Shot.new(pos + dir * 22.0, dir * 1.9, "orb", true))
				if angry:
					game.add_shot(Entities.Shot.new(pos - dir * 22.0, -dir * 1.9, "orb", true))
		"burst":
			_hand += 0.01
			if pattern_age % (45 if not angry else 32) == 20:
				for c in [Vector2(-8, -44), Vector2(-8, 44)]:
					for k in 5:
						game.aim(pos + c, 2.3, "needle", (k - 2) * 0.16)
		"sand":
			_hand += 0.02
			if pattern_age % 70 == 30:
				var mine := Enemies.Enemy.new("hourglass", pos + Vector2(-30, randf_range(-30, 30)), randf() * TAU)
				mine.age = 150 if not angry else 190
				game.add_enemy(mine)


func damage(amount: int, game) -> void:
	if dying > 0 or pos.x > 380:
		return
	hp -= amount
	flash = 2
	if hp <= 0:
		hp = 0
		dying = 1
		game.on_boss_down()


func entered() -> bool:
	return pos.x <= 300.0


func draw(ci: CanvasItem, frame: int) -> void:
	if dead:
		return
	var p := pos.round()
	var hull := Color("6a7186") if flash == 0 else Color.WHITE
	var dark := Color("0b0b18")
	var shake := Vector2(randf_range(-2, 2), randf_range(-2, 2)) if dying > 0 else Vector2.ZERO
	p += shake
	# Tower body, wings and cannons.
	_box(ci, Rect2(p + Vector2(-34, -62), Vector2(84, 124)), hull, dark)
	_box(ci, Rect2(p + Vector2(-20, -74), Vector2(56, 14)), Color("b38b1c"), dark)
	_box(ci, Rect2(p + Vector2(-8, -86), Vector2(32, 14)), Color("b38b1c"), dark)
	for s in [-1.0, 1.0]:
		_box(ci, Rect2(p + Vector2(-26, s * 44 - 7), Vector2(26, 14)), Color("a3172e"), dark)
		_box(ci, Rect2(p + Vector2(-40, s * 44 - 3), Vector2(16, 6)), Color("c4c9d6"), dark)
		_box(ci, Rect2(p + Vector2(40, s * 30 - 20), Vector2(30, 40)), hull.darkened(0.2), dark)
	for k in 5:
		var lit := (frame / 8 + k) % 5 == 0
		ci.draw_rect(Rect2(p + Vector2(18 + k * 5, 52), Vector2(3, 3)), Color("ffe45c") if lit else Color("1c3488"))
	# The clock face: the weak point.
	ci.draw_circle(p, 29.0, dark)
	ci.draw_circle(p, 27.0, Color("b38b1c"))
	ci.draw_circle(p, 24.0, Color("fff4dc") if flash == 0 else Color("ffd0d0"))
	for k in 12:
		var a := TAU * k / 12.0
		var tick := p + Vector2(cos(a), sin(a)) * 20.0
		ci.draw_rect(Rect2(tick.round() - Vector2(1, 1), Vector2(2, 2)), dark)
	var hour := _hand * 0.08 - PI / 2
	ci.draw_line(p, p + Vector2(cos(hour), sin(hour)) * 12.0, dark, 3.0)
	ci.draw_line(p, p + Vector2(cos(_hand), sin(_hand)) * 21.0, Color("a3172e"), 2.0)
	ci.draw_circle(p, 3.0, dark)


static func _box(ci: CanvasItem, r: Rect2, fill: Color, edge: Color) -> void:
	ci.draw_rect(r, edge)
	ci.draw_rect(r.grow(-1), fill)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), fill.lightened(0.25))


## The health bar along the bottom of the screen.
func draw_bar(ci: CanvasItem) -> void:
	if dead or not entered():
		return
	var w := 220.0
	var x := 192.0 - w / 2.0 + 30.0
	ci.draw_rect(Rect2(x - 1, 14, w + 2, 6), Color("0b0b18"))
	ci.draw_rect(Rect2(x, 15, w * hp / MAX_HP, 4), Color("ff4d4d"))
	Pix.text(ci, Vector2(x - 6, 13), "CHRONARCH", Color("ffe45c"), 1, 2)
