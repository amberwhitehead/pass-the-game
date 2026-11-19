extends RefCounted
## Everything written on the screen: the score bar, the weapon list, and the title,
## warning, game-over and stage-clear screens.

const Pix := preload("res://minigames/arcade/pixel_art.gd")
const Sprites := preload("res://minigames/arcade/sprites.gd")
const Entities := preload("res://minigames/arcade/entities.gd")
const Stage := preload("res://minigames/arcade/stage.gd")


static func draw_play(ci: CanvasItem, game) -> void:
	var p = game.player
	ci.draw_rect(Rect2(0, 0, 384, 11), Color(0.02, 0.02, 0.07, 0.75))
	Pix.text(ci, Vector2(3, 2), "SCORE %07d" % game.score, Color("ffffff"))
	Pix.text(ci, Vector2(192, 2), "HI %07d" % maxi(game.high, game.score), Color("ffe45c"), 1, 1)
	Pix.text(ci, Vector2(381, 2), "YEAR %d" % Stage.year(game.stage_frame), Color("6ef2ff"), 1, 2)
	# Lives.
	for i in maxi(0, p.lives - (0 if p.alive else 0)):
		ci.draw_texture(Sprites.tex("life"), Vector2(4 + i * 9, 205))
	# Weapons, the one in hand highlighted, with level pips. With more than one, the
	# switch key is shown in front of the list.
	var x := 120.0
	if p.owned.size() > 1:
		Pix.text(ci, Vector2(x - 34, 205), "X/K:", Color("ffe45c"))
	for w in p.owned:
		var name: String = Entities.WEAPON_NAMES[w]
		var col: Color = Entities.WEAPON_COLORS[w] if w == p.current else Color("4a4f66")
		Pix.text(ci, Vector2(x, 205), name, col)
		for l in p.levels[w]:
			ci.draw_rect(Rect2(x + Pix.text_width(name) + 2 + l * 3, 209, 2, 3), col)
		x += Pix.text_width(name) + 16
	var gear := ">".repeat(p.gear + 1)
	Pix.text(ci, Vector2(381, 205), "SPEED " + gear + " ".repeat(3 - p.gear), Color("8fb8ff"), 1, 2)


static func draw_title(ci: CanvasItem, game, frame: int) -> void:
	var bob := sin(frame * 0.05) * 2.0
	_logo(ci, Vector2(192, 46 + bob))
	Pix.text(ci, Vector2(192, 96), "THE TEMPORAL PATROL IS AFTER YOU", Color("8fb8ff"), 1, 1)
	Pix.text(ci, Vector2(192, 108), "FLY UP THE TIMESTREAM. DON'T LOOK BACK.", Color("8fb8ff"), 1, 1)
	if (frame / 30) % 2 == 0:
		Pix.text(ci, Vector2(192, 136), "INSERT COIN", Color("ffe45c"), 2, 1)
	Pix.text(ci, Vector2(192, 160), "PRESS FIRE TO PLAY", Color("ffffff"), 1, 1)
	Pix.text(ci, Vector2(192, 176), "HI SCORE %07d" % game.high, Color("ff4d4d"), 1, 1)
	Pix.text(ci, Vector2(192, 188), "Z FIRE   X SWITCH WEAPON   SHIFT SPEED", Color("6ef2ff"), 1, 1)
	Pix.text(ci, Vector2(192, 202), "(C) 1985 CHRONOSOFT  NOT FOR SALE BEFORE 1963", Color("4a4f66"), 1, 1)


static func _logo(ci: CanvasItem, c: Vector2) -> void:
	var line1 := "CHRONO"
	var line2 := "RAIDER"
	for k in 3:
		var off := Vector2(k, k)
		var col: Color = [Color("ff4d4d"), Color("ffa23a"), Color("ffe45c")][2 - k]
		Pix.text(ci, c + Vector2(0, -18) + off, line1, col, 3, 1, false)
		Pix.text(ci, c + Vector2(0, 6) + off, line2, col if k > 0 else Color("6ef2ff"), 3, 1, false)


static func draw_banner(ci: CanvasItem, text: String, sub: String, color: Color, frame: int) -> void:
	ci.draw_rect(Rect2(0, 84, 384, 44), Color(0.02, 0.02, 0.07, 0.8))
	if (frame / 10) % 2 == 0 or color != Color("ff4d4d"):
		Pix.text(ci, Vector2(192, 90), text, color, 2, 1)
	if sub != "":
		Pix.text(ci, Vector2(192, 112), sub, Color("ffffff"), 1, 1)
