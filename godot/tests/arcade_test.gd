extends "res://tests/test_suite.gd"
## CHRONO RAIDER and its cabinet: the game starts from the title, fires, collects and
## levels weapons, kills enemies, loses lives (dropping the weapon in hand), reaches and
## beats the boss, ends in game over, keeps a high score, pauses its screen with the menu,
## never reports a win; and the cabinet stands in the secret room where it can be targeted.

const HighScore := preload("res://minigames/arcade/high_score.gd")
const Entities := preload("res://minigames/arcade/entities.gd")
const Enemies := preload("res://minigames/arcade/enemies.gd")
const Weapons := preload("res://minigames/arcade/weapons.gd")
const Stage := preload("res://minigames/arcade/stage.gd")

var _checks := 0
var _failures := 0
var _returned := false
var _result := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	HighScore.path = "user://test_chrono_raider.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HighScore.path))
	await _game_rules()
	await _through_launcher()
	await _cabinet()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HighScore.path))
	HighScore.path = HighScore.DEFAULT_PATH
	print("Arcade: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _game_rules() -> void:
	var game: Control = load("res://minigames/arcade/arcade.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	var s: Node2D = game.shooter
	_expect(s.mode == "title" and s.frame > 0, "The cabinet boots to its title screen and runs")
	_expect(s.high == HighScore.DEFAULT_HIGH, "A fresh machine shows the default high score")
	_start(s)
	_expect(s.mode == "play" and s.player.lives == 3, "Fire starts a game with three ships")
	_steps(s, 6, {"fire": true})
	_expect(s.shots.any(func(x): return not x.hostile), "Firing launches shots")
	var p = s.player
	var x0: float = p.pos.x
	_steps(s, 10, {"move": Vector2(1, 0)})
	var slow: float = p.pos.x - x0
	_steps(s, 2, {"gear": true})
	_steps(s, 1, {})
	x0 = p.pos.x
	_steps(s, 10, {"move": Vector2(1, 0)})
	_expect(p.pos.x - x0 > slow, "A higher gear flies faster")
	# Weapon capsules.
	_capsule(s, Weapons.FAN)
	_expect(Weapons.FAN in p.owned and p.current == Weapons.FAN, "A new weapon's capsule adds and selects it")
	_capsule(s, Weapons.FAN)
	_expect(p.levels[Weapons.FAN] == 2, "A second capsule of the same weapon levels it up")
	_steps(s, 1, {"switch": true})
	_expect(p.current == Weapons.PULSE, "Switch cycles the arsenal")
	_steps(s, 1, {})
	_steps(s, 1, {"switch": true})
	_expect(p.current == Weapons.FAN, "...and back again")
	var cap := Entities.Pickup.new()
	for i in 120:
		cap.update()
	_expect(cap.weapon == 1, "Courier capsules change weapon every two seconds")
	# Shooting an enemy.
	s.enemies.clear()
	p.invulnerable = 0
	var target := Enemies.Enemy.new("courier", p.pos + Vector2(70, 0))
	s.add_enemy(target)
	var score: int = s.score
	_steps(s, 40, {"fire": true})
	_expect(target.dead and s.score > score, "Shots destroy an enemy and score")
	_expect(s.pickups.size() > 0, "A destroyed courier drops a capsule")
	s.pickups.clear()
	# Being shot down.
	p.invulnerable = 0
	s.shots.clear()
	s.add_shot(Entities.Shot.new(p.pos, Vector2.ZERO, "orb", true))
	_steps(s, 1, {})
	_expect(p.lives == 2 and not p.alive, "A hostile shot costs a ship")
	_expect(not Weapons.FAN in p.owned and s.pickups.any(func(c): return c.weapon == Weapons.FAN and not c.cycles),
		"The weapon in hand is lost, dropped as a capsule to win back")
	_steps(s, 80, {})
	_expect(p.alive and p.invulnerable > 0, "The next ship flies in, briefly invulnerable")
	# Timeline to the boss.
	_expect(not Stage.spawns_at(60).is_empty(), "The stage timeline spawns enemies")
	p.invulnerable = 9999
	s.skip_to_boss()
	_steps(s, 20, {})
	_expect(s.boss != null, "The stage timeline reaches the boss")
	_steps(s, 200, {})
	_expect(s.boss.entered() and s.shots.any(func(x): return x.hostile), "The boss arrives and attacks")
	s.player.invulnerable = 9999
	s.boss.hp = 1
	s.add_shot(Entities.Shot.new(s.boss.pos, Vector2.ZERO, "pulse"))
	_steps(s, 1, {})
	_expect(s.boss.dying > 0, "The boss can be destroyed")
	_steps(s, 160, {})
	_expect(s.mode == "clear", "Beating the boss clears the stage")
	var final: int = s.score
	_steps(s, 310, {})
	_expect(s.mode == "title" and s.high == final and HighScore.load_high() == final, "The high score is kept on the machine")
	# Game over.
	_start(s)
	s.player.lives = 1
	s.player.invulnerable = 0
	s.add_shot(Entities.Shot.new(s.player.pos, Vector2.ZERO, "orb", true))
	_steps(s, 80, {})
	_expect(s.mode == "over", "Losing the last ship is game over")
	_steps(s, 250, {})
	_expect(s.mode == "title", "Game over returns to the title")
	# The pause menu disables the game; its screen stops too.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	_expect(game._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Pausing stops the screen")
	var f: int = s.frame
	await _frames(3)
	_expect(s.frame == f, "Pausing stops the game")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame
	_expect(game._viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Resuming restarts the screen")
	game.queue_free()
	await process_frame


## Fire on the title screen (after its short guard) starts a game.
func _start(s: Node2D) -> void:
	_steps(s, 25, {})
	_steps(s, 1, {"start": true})
	_steps(s, 1, {})


func _capsule(s: Node2D, weapon: int) -> void:
	var cap := Entities.Pickup.new()
	cap.pos = s.player.pos
	cap.weapon = weapon
	s.pickups.append(cap)
	_steps(s, 1, {})


func _through_launcher() -> void:
	var games: Node = root.get_node("MiniGames")
	_returned = false
	_launch.call_deferred(games)
	var game: Node = null
	for i in 600:
		if games.current != null:
			game = games.current
			break
		await process_frame
	_expect(game != null and game.scene_file_path.ends_with("arcade.tscn"), "The arcade opens through the normal launcher")
	if game == null:
		return
	await _frames(3)
	for b in game.find_children("*", "Button", true, false):
		if b.text == "×":
			b.pressed.emit()
	for i in 600:
		if _returned:
			break
		await process_frame
	_expect(_returned and not _result.get("won", true), "Leaving the arcade reports no win")
	_expect(not root.get_node("Game").completed_minigames.has("arcade"), "Playing the arcade records no progress")


func _launch(games: Node) -> void:
	_result = await games.play("arcade")
	_returned = true


func _cabinet() -> void:
	root.get_node("Game").set_flag("room_visited")
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await _physics(3)
	var secret: Node3D = room.get_node("SecretRoom")
	var cabinet: Node = secret.room.get_node_or_null("ArcadeCabinet")
	_expect(cabinet is Interactable and cabinet.minigame_id == "arcade", "The secret room has the arcade cabinet")
	if cabinet == null:
		room.queue_free()
		return
	var local: Vector3 = secret.room.to_local(cabinet.global_position)
	_expect(absf(local.x) < 3.0 and absf(local.z) < 3.0, "The cabinet stands inside the room")
	var player: Player = room.get_node("Player")
	var focus: Vector3 = cabinet.get_focus_position()
	var front: Vector3 = cabinet.global_transform.basis.z.normalized()
	var stand := focus + front * 1.3
	stand.y = secret.room.global_position.y + .02
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var to := focus - stand
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = -0.15
	await _physics(6)
	_expect(player.target == cabinet, "Standing in front of the cabinet targets it")
	room.queue_free()
	await process_frame


func _steps(s: Node2D, n: int, input: Dictionary) -> void:
	s.controls.forced = input if not input.is_empty() else {"move": Vector2.ZERO}
	for i in n:
		s.step()
	s.controls.forced = {}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
