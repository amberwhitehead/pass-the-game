extends RefCounted
## The Raider: movement with four speed gears, the weapon arsenal, lives and respawn.

const Sprites := preload("res://minigames/arcade/sprites.gd")
const Weapons := preload("res://minigames/arcade/weapons.gd")

const GEARS := [1.3, 1.9, 2.5, 3.1]
const HITBOX := 2.5
const BOUNDS := Rect2(12, 18, 360, 190)
const INVULNERABLE := 120

var pos := Vector2(60, 112)
var gear := 1
var owned: Array[int] = [Weapons.PULSE]
var levels := {0: 1, 1: 1, 2: 1}
var current := Weapons.PULSE
var lives := 3
var invulnerable := INVULNERABLE
var alive := true
var respawn_in := 0
var _cooldown := 0
var _fire_frame := 0
var _tilt := 0.0


func update(game, controls) -> void:
	if not alive:
		respawn_in -= 1
		if respawn_in <= 0 and lives > 0:
			alive = true
			pos = Vector2(-20, 112)
			invulnerable = INVULNERABLE
		return
	if invulnerable > 0:
		invulnerable -= 1
	if pos.x < 40.0 and invulnerable > INVULNERABLE - 40:
		pos.x += 2.0  # Fly back in after a respawn.
	if controls.gear_pressed:
		gear = (gear + 1) % GEARS.size()
		game.sfx("arcade_switch")
	if controls.switch_pressed and owned.size() > 1:
		current = owned[(owned.find(current) + 1) % owned.size()]
		game.sfx("arcade_switch")
	pos += controls.move * GEARS[gear]
	pos.x = clampf(pos.x, BOUNDS.position.x, BOUNDS.end.x)
	pos.y = clampf(pos.y, BOUNDS.position.y, BOUNDS.end.y)
	_tilt = lerpf(_tilt, controls.move.y, 0.2)
	if _cooldown > 0:
		_cooldown -= 1
	if controls.fire and _cooldown == 0:
		Weapons.fire(game, current, levels[current], pos + Vector2(12, 1), _fire_frame)
		_fire_frame += 1
		_cooldown = Weapons.COOLDOWN[current]
		game.sfx("arcade_shot")


## Collects a weapon capsule: a new weapon joins the arsenal and is selected; one already
## owned gains a level (up to 3).
func collect(weapon: int) -> void:
	if weapon in owned:
		levels[weapon] = mini(3, levels[weapon] + 1)
	else:
		owned.append(weapon)
		owned.sort()
	current = weapon


## Shot down: lose a life and the weapon in hand (its capsule is dropped to win back).
## Returns the weapon dropped, or -1 for the PULSE, which is never lost (it loses levels).
func hit() -> int:
	alive = false
	lives -= 1
	respawn_in = 70
	var dropped := -1
	if current == Weapons.PULSE:
		levels[current] = 1
	else:
		dropped = current
		owned.erase(current)
		levels[current] = 1
		current = owned[0]
	return dropped


func vulnerable() -> bool:
	return alive and invulnerable <= 0


func draw(ci: CanvasItem, frame: int) -> void:
	if not alive:
		return
	if invulnerable > 0 and (frame / 3) % 2 == 0:
		return
	var tex := Sprites.tex("ship")
	var top := (pos - tex.get_size() / 2.0).round()
	ci.draw_texture(Sprites.tex("flame"), top + Vector2(-4 + (frame % 2), 4))
	ci.draw_texture(tex, top + Vector2(0, roundf(_tilt)))
