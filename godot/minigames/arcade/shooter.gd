extends Node2D
## CHRONO RAIDER: the game itself, drawn at 384 x 216 inside the cabinet's screen.
##
## A fixed 60 Hz `step()` runs the current mode: "title" (attract screen; fire starts),
## "play", "over" (game over, back to the title) and "clear" (the boss is down). Everything
## is drawn immediately in _draw(). `attract_only` runs just the title screen with no
## input, for the cabinet's own screen in the secret room.

const Controls := preload("res://minigames/arcade/controls.gd")
const Entities := preload("res://minigames/arcade/entities.gd")
const Player := preload("res://minigames/arcade/player.gd")
const Enemies := preload("res://minigames/arcade/enemies.gd")
const Boss := preload("res://minigames/arcade/boss.gd")
const Stage := preload("res://minigames/arcade/stage.gd")
const Background := preload("res://minigames/arcade/background.gd")
const Hud := preload("res://minigames/arcade/hud.gd")
const HighScore := preload("res://minigames/arcade/high_score.gd")

const SIZE := Vector2i(384, 216)
const TICK := 1.0 / 60.0

signal sound(cue: String)

var attract_only := false
var mode := "title"
var controls := Controls.new()
var player: RefCounted
var enemies: Array = []
var shots: Array = []
var sparks: Array = []
var pickups: Array = []
var boss: RefCounted
var score := 0
var high := 0
var frame := 0
var stage_frame := 0
var mode_frame := 0
var rank := 0.0            ## 0..1: grows as the stage goes on; enemies fire more.
var _accum := 0.0
var _bg := Background.new()


func _ready() -> void:
	high = HighScore.load_high()


func _process(delta: float) -> void:
	_accum = minf(_accum + delta, TICK * 4.0)
	while _accum >= TICK:
		_accum -= TICK
		step()
	queue_redraw()


## One 60 Hz tick of the game.
func step() -> void:
	frame += 1
	mode_frame += 1
	_bg.update()
	if attract_only:
		return
	controls.read()
	match mode:
		"title":
			if controls.start_pressed and mode_frame > 20:
				start()
		"play":
			_play()
		"over":
			_world()
			if mode_frame > 240 or (mode_frame > 60 and controls.start_pressed):
				to_title()
		"clear":
			_world()
			if mode_frame == 1:
				score += 10000 + player.lives * 5000
			if mode_frame > 300:
				to_title()


func start() -> void:
	mode = "play"
	mode_frame = 0
	stage_frame = 0
	score = 0
	rank = 0.0
	player = Player.new()
	enemies.clear()
	shots.clear()
	sparks.clear()
	pickups.clear()
	boss = null
	sfx("arcade_start")


func to_title() -> void:
	if score > high:
		high = score
		HighScore.save_high(high)
	mode = "title"
	mode_frame = 0
	enemies.clear()
	shots.clear()
	pickups.clear()
	boss = null


func _play() -> void:
	stage_frame += 1
	rank = clampf(stage_frame / float(Stage.BOSS_AT), 0.0, 1.0)
	for s in Stage.spawns_at(stage_frame):
		add_enemy(Enemies.Enemy.new(s[0], s[1], s[2]))
	if stage_frame == Stage.BOSS_AT + 150:
		boss = Boss.new()
	player.update(self, controls)
	_world()
	_collide()
	if not player.alive and player.lives <= 0 and player.respawn_in <= 0:
		mode = "over"
		mode_frame = 0
		sfx("arcade_over")


## Moves everything but the player.
func _world() -> void:
	for e in enemies:
		e.update(self)
	if boss != null:
		boss.update(self)
		if boss.dead and mode == "play":
			mode = "clear"
			mode_frame = 0
	for s in shots:
		s.update(self)
	for p in pickups:
		p.update()
	for s in sparks:
		s.update()
	enemies = enemies.filter(func(e): return not e.dead)
	shots = shots.filter(func(s): return not s.dead)
	pickups = pickups.filter(func(p): return not p.dead)
	sparks = sparks.filter(func(s): return s.life > 0)


func _collide() -> void:
	for s in shots:
		if s.dead:
			continue
		if s.hostile:
			if player.vulnerable() and s.pos.distance_to(player.pos) < s.radius + Player.HITBOX:
				s.dead = true
				_player_hit()
			continue
		for e in enemies:
			if not e.dead and s.pos.distance_to(e.pos) < s.radius + e.radius:
				s.dead = true
				_damage(e, s.damage)
				break
		if not s.dead and boss != null and boss.dying == 0 and s.pos.distance_to(boss.pos) < s.radius + boss.radius:
			s.dead = true
			boss.damage(s.damage, self)
			score += 10
	if player.vulnerable():
		for e in enemies:
			if not e.dead and e.pos.distance_to(player.pos) < e.radius * 0.8 + Player.HITBOX:
				_damage(e, 99)
				_player_hit()
				break
		if boss != null and boss.dying == 0 and absf(player.pos.x - boss.pos.x - 8) < 44 and absf(player.pos.y - boss.pos.y) < 62:
			_player_hit()
	if player.alive:
		for p in pickups:
			if p.pos.distance_to(player.pos) < 12.0:
				p.dead = true
				player.collect(p.weapon)
				score += 1000
				sfx("arcade_pickup")


func _damage(e, amount: int) -> void:
	e.hp -= amount
	e.flash = 3
	if e.hp > 0:
		sfx("arcade_hit")
		return
	e.dead = true
	score += e.score
	explode(e.pos, Color("ffa23a"), 12 if e.radius < 9 else 22)
	sfx("arcade_boom")
	if e.kind == "hourglass":
		e.burst(self)
	if e.kind == "courier":
		var cap := Entities.Pickup.new()
		cap.pos = e.pos
		cap.weapon = frame % Entities.WEAPON_NAMES.size()
		pickups.append(cap)


func _player_hit() -> void:
	explode(player.pos, Color("6ef2ff"), 30)
	sfx("arcade_die")
	var dropped: int = player.hit()
	if dropped >= 0:
		var cap := Entities.Pickup.new()
		cap.pos = player.pos + Vector2(40, 0)
		cap.weapon = dropped
		cap.cycles = false
		pickups.append(cap)
	# A moment of mercy: clear nearby bullets.
	for s in shots:
		if s.hostile and s.pos.distance_to(player.pos) < 60.0:
			s.dead = true


func on_boss_down() -> void:
	score += 20000
	for s in shots:
		if s.hostile:
			s.dead = true
	sfx("arcade_boom")


# --- used by enemies, weapons and the boss ----------------------------------------------

func add_shot(s) -> void:
	shots.append(s)


func add_enemy(e) -> void:
	enemies.append(e)


## Fires an enemy shot from `from` toward the player, `turn` radians off.
func aim(from: Vector2, speed: float, kind: String, turn := 0.0) -> void:
	if player == null:
		return
	var dir: Vector2 = (player.pos - from).normalized().rotated(turn)
	add_shot(Entities.Shot.new(from, dir * speed, kind, true))


func nearest_enemy(from: Vector2):
	var best = null
	var best_d := INF
	for e in enemies:
		var d := from.distance_squared_to(e.pos)
		if not e.dead and d < best_d and e.pos.x < 390:
			best_d = d
			best = e
	if boss != null and boss.dying == 0 and boss.entered() and from.distance_squared_to(boss.pos) < best_d:
		best = boss
	return best


func explode(at: Vector2, color: Color, n: int) -> void:
	for i in n:
		var s := Entities.Spark.new()
		s.pos = at
		s.vel = Vector2(randf_range(0.5, 2.6), 0).rotated(randf() * TAU)
		s.color = [color, Color("ffe45c"), Color.WHITE][i % 3]
		s.life = randi_range(14, 30)
		s.max_life = s.life
		s.size = 3.0
		sparks.append(s)
	var ring := Entities.Spark.new()
	ring.pos = at
	ring.ring = true
	ring.size = n * 1.2
	ring.life = 16
	ring.max_life = 16
	ring.color = color
	sparks.append(ring)


func sfx(cue: String) -> void:
	sound.emit(cue)


## Jumps the stage to just before the boss (for tests and the shot tool).
func skip_to_boss() -> void:
	if mode != "play":
		start()
	stage_frame = Stage.BOSS_AT + 140
	enemies.clear()


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	_bg.draw(self, frame)
	if mode == "title" or attract_only:
		Hud.draw_title(self, self, mode_frame)
		return
	for p in pickups:
		p.draw(self)
	for e in enemies:
		e.draw(self, frame)
	if boss != null:
		boss.draw(self, frame)
	player.draw(self, frame)
	for s in shots:
		s.draw(self)
	for s in sparks:
		s.draw(self)
	if boss != null:
		boss.draw_bar(self)
	Hud.draw_play(self, self)
	if mode == "play" and stage_frame > Stage.BOSS_AT and stage_frame < Stage.BOSS_AT + 150:
		Hud.draw_banner(self, "WARNING", "THE CHRONARCH APPROACHES", Color("ff4d4d"), frame)
	elif mode == "play" and stage_frame < 150:
		Hud.draw_banner(self, "STAGE 1", "UPSTREAM FROM 1963", Color("6ef2ff"), frame)
	elif mode == "over":
		Hud.draw_banner(self, "GAME OVER", "THE PATROL CAUGHT UP WITH YOU", Color("ff4d4d"), frame)
	elif mode == "clear":
		Hud.draw_banner(self, "STAGE CLEAR", "BONUS %d" % (10000 + player.lives * 5000), Color("ffe45c"), frame)
