extends RefCounted
## The timestream: a deep indigo gradient, far-off clock faces and drifting years, stars,
## and bright time-streaks rushing past, in parallax layers.

const Pix := preload("res://minigames/arcade/pixel_art.gd")

var _stars := []     ## [pos, speed, colour]
var _streaks := []   ## [pos, length, speed, colour]
var _clocks := []    ## [pos, radius, speed]
var _years := []     ## [pos, text, speed]
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1963
	for i in 70:
		_stars.append([Vector2(_rng.randf() * 384, _rng.randf() * 216), _rng.randf_range(0.3, 1.4),
			[Color("8fb8ff"), Color("ffffff"), Color("d77cff")][i % 3]])
	for i in 14:
		_streaks.append([Vector2(_rng.randf() * 384, _rng.randf() * 216), _rng.randf_range(10, 40),
			_rng.randf_range(4.0, 7.0), [Color("6ef2ff"), Color("d77cff")][i % 2]])
	for i in 3:
		_clocks.append([Vector2(i * 150.0 + 60, _rng.randf_range(40, 180)), _rng.randf_range(16, 30), 0.25])
	for i in 4:
		_years.append([Vector2(i * 110.0 + 30, _rng.randf_range(30, 190)), str(_rng.randi_range(1900, 2100)), 0.4])


func update() -> void:
	for s in _stars:
		s[0].x -= s[1]
		if s[0].x < 0:
			s[0] = Vector2(384, _rng.randf() * 216)
	for s in _streaks:
		s[0].x -= s[2]
		if s[0].x + s[1] < 0:
			s[0] = Vector2(384 + _rng.randf() * 100, _rng.randf() * 216)
	for c in _clocks:
		c[0].x -= c[2]
		if c[0].x + c[1] < 0:
			c[0] = Vector2(384 + c[1], _rng.randf_range(40, 180))
	for y in _years:
		y[0].x -= y[2]
		if y[0].x < -40:
			y[0] = Vector2(400, _rng.randf_range(30, 190))
			y[1] = str(_rng.randi_range(1900, 2100))


func draw(ci: CanvasItem, frame: int) -> void:
	for i in 9:
		var t := i / 8.0
		ci.draw_rect(Rect2(0, i * 24, 384, 24), Color("0a0820").lerp(Color("23104a"), sin(t * PI)))
	for c in _clocks:
		var col := Color("3b2a78")
		ci.draw_arc(c[0].round(), c[1], 0, TAU, 24, col, 1.0)
		var a: float = frame * 0.01 + c[1]
		ci.draw_line(c[0].round(), c[0].round() + Vector2(cos(a), sin(a)) * c[1] * 0.8, col, 1.0)
		ci.draw_line(c[0].round(), c[0].round() + Vector2(cos(a * 0.1), sin(a * 0.1)) * c[1] * 0.5, col, 1.0)
	for y in _years:
		Pix.text(ci, y[0].round(), y[1], Color("2e2266"), 1, 0, false)
	for s in _stars:
		ci.draw_rect(Rect2(s[0].round(), Vector2(1, 1)), s[2])
	for s in _streaks:
		ci.draw_line(s[0].round(), s[0].round() + Vector2(s[1], 0), Color(s[3], 0.55), 1.0)
