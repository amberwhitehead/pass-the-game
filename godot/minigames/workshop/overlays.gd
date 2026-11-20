extends RefCounted
## Stage-space layers drawn over the Workshop room: the inventory tray, the cursor label,
## the Futurescope close-up and the temporal alarm.

const Ink := preload("res://minigames/workshop/ink.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Items := preload("res://minigames/workshop/items.gd")
const Style := preload("res://ui/game_style.gd")


## A row of carried items along the bottom of the stage. Click one to hold it.
class Inventory extends Node2D:
	const SLOT := 84.0
	const Y := 820.0
	var items: Array[String] = []
	var selected := ""

	func _ready() -> void:
		z_index = 35

	func add(item: String) -> void:
		if item not in items:
			items.append(item)
		queue_redraw()

	func remove(item: String) -> void:
		items.erase(item)
		if selected == item:
			selected = ""
		queue_redraw()

	func has(item: String) -> bool:
		return item in items

	func _slot_rect(i: int) -> Rect2:
		var total := items.size() * SLOT + (items.size() - 1) * 10.0
		var x0 := 800.0 - total * 0.5
		return Rect2(x0 + i * (SLOT + 10.0), Y - SLOT * 0.5, SLOT, SLOT)

	## The item under a stage point, or "".
	func item_at(p: Vector2) -> String:
		for i in items.size():
			if _slot_rect(i).has_point(p):
				return items[i]
		return ""

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if items.is_empty():
			return
		var total := _slot_rect(items.size() - 1).end.x - _slot_rect(0).position.x
		Ink.shape(self, Ink.rrect(Rect2(_slot_rect(0).position - Vector2(14, 10), Vector2(total + 28, SLOT + 20)), 18),
			Color(0.16, 0.11, 0.08, 0.82), 3.0, 800, 0.0, 0.0)
		for i in items.size():
			var r := _slot_rect(i)
			var held := items[i] == selected
			Ink.shape(self, Ink.rrect(r, 12), Color("f2e6c9") if not held else Color("ffe08a"), 2.5, 801 + i, 0.1, 0.1)
			if not held:
				Items.draw_icon(self, items[i], r.get_center())


## Follows the mouse: shows what is under it, and the held item.
class Cursor extends Node2D:
	var label := ""
	var held := ""

	func _ready() -> void:
		z_index = 60

	func _process(_d: float) -> void:
		position = get_parent().get_local_mouse_position()
		queue_redraw()

	func _draw() -> void:
		# A held item sits right under the pointer: the item itself is what you aim with.
		if held != "":
			draw_circle(Vector2.ZERO, 34, Color(1, 0.95, 0.7, 0.25))
			Items.draw_icon(self, held, Vector2.ZERO)
		if label == "":
			return
		var font := Style.font(true)
		var text := label if held == "" else "Use %s on %s" % [Items.NAMES.get(held, held).to_lower(), label]
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var r := Rect2(Vector2(26, -54) if held == "" else Vector2(40, -60), size + Vector2(20, 12))
		if position.x + r.end.x > 1590:
			r.position.x = -r.size.x - 12
		draw_rect(r, Color(0.16, 0.11, 0.08, 0.85))
		draw_string(font, r.position + Vector2(10, size.y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff3d6"))


## The Futurescope filling the screen: a big wooden set around the live feed.
class Closeup extends Node2D:
	const SCREEN := Rect2(350, 130, 800, 600)
	var _sprite: Sprite2D
	var _caption := ""

	func _ready() -> void:
		z_index = 40
		visible = false
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_sprite.position = SCREEN.position
		add_child(_sprite)

	func open(tex: Texture2D, mat: Material, caption := "") -> void:
		_sprite.texture = tex
		_sprite.material = mat
		_sprite.scale = SCREEN.size / tex.get_size()
		_caption = caption
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

	func close() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		await tw.finished
		visible = false

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-50, -50, 1700, 1000), Color(0.08, 0.05, 0.04, 0.82))
		var body := Rect2(SCREEN.position - Vector2(60, 60), SCREEN.size + Vector2(260, 140))
		Ink.shape(self, Ink.rrect(body, 46), Color("8b5a36"), 5.0, 850, 0.2, 0.18)
		Ink.shape(self, Ink.rrect(SCREEN.grow(18), 40), Color("2a2622"), 4.0, 851, 0.0, 0.0)
		for k in 2:
			Ink.dot(self, Vector2(SCREEN.end.x + 100, SCREEN.position.y + 70 + k * 110), 34, P.CREAM, 3.5, 852 + k)
		for k in 7:
			Ink.line(self, PackedVector2Array([Vector2(SCREEN.end.x + 66, 420 + k * 26), Vector2(SCREEN.end.x + 134, 420 + k * 26)]), Color("5a3a26"), 4.0, 854 + k)
		var plate := Rect2(SCREEN.get_center().x - 130, SCREEN.end.y + 36, 260, 36)
		Ink.shape(self, Ink.rrect(plate, 8), P.BRASS, 3.0, 862, 0.25)
		draw_string(Style.font(true), Vector2(plate.position.x, plate.position.y + 26), "FUTURESCOPE", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 24, Ink.OUTLINE)
		if _caption != "":
			# On the wooden frame above the screen (the picture covers anything drawn on it).
			draw_circle(Vector2(SCREEN.position.x + 4, SCREEN.position.y - 34), 7, Color(1, 0.3, 0.2, 0.55 + 0.45 * sin(Time.get_ticks_msec() / 250.0)))
			draw_string(Style.font(true), Vector2(SCREEN.position.x + 20, SCREEN.position.y - 26), _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Ink.OUTLINE)


## Sirens: a flashing edge glow, a spinning beacon and a lit warning sign.
class Alarm extends Node2D:
	var mode := "":          ## "", "violation" (red) or "instability" (amber)
		set(v):
			mode = v
			visible = v != ""
	var _t := 0.0

	func _ready() -> void:
		z_index = 30
		visible = false

	func _process(d: float) -> void:
		if visible:
			_t += d
			queue_redraw()

	func _draw() -> void:
		var col := P.ALARM if mode == "violation" else Color("ffb22e")
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		for k in 6:
			var w := 18.0 + k * 22.0
			var c := Color(col, (0.22 - k * 0.035) * pulse)
			draw_rect(Rect2(0, 0, 1600, w), c)
			draw_rect(Rect2(0, 900 - w, 1600, w), c)
			draw_rect(Rect2(0, 0, w, 900), c)
			draw_rect(Rect2(1600 - w, 0, w, 900), c)
		# Beacon.
		var b := Vector2(560, 34)
		var a := _t * 6.0
		draw_colored_polygon(PackedVector2Array([b, b + Vector2(cos(a - 0.25), sin(a - 0.25)) * 420, b + Vector2(cos(a + 0.25), sin(a + 0.25)) * 420]), Color(col, 0.12))
		Ink.shape(self, Ink.ellipse(b, Vector2(22, 18), 16, PI, TAU), col.lightened(0.2 * pulse), 3.0, 870, 0.4)
		Ink.shape(self, Ink.rrect(Rect2(b + Vector2(-28, 0), Vector2(56, 12)), 3), P.STEEL, 3.0, 871)
		# Sign.
		var text := "EXTREME TEMPORAL VIOLATION" if mode == "violation" else "LOOP INSTABILITY"
		var font := Style.font(true)
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		var r := Rect2(Vector2(800 - size.x * 0.5 - 26, 22), Vector2(size.x + 52, 56))
		Ink.shape(self, Ink.rrect(r, 10), Color("2a1a14"), 4.0, 872, 0.0, 0.0)
		var glow := col.lerp(Color.WHITE, 0.25 * pulse)
		draw_string(font, Vector2(r.position.x + 26, r.position.y + 39), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, glow)
