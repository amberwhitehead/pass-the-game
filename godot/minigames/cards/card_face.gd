extends Control
## One printed card composition, reused on the tabletop and in the inspector.
## Future artwork can be supplied as `art: Texture2D` or `art_path: String`.
const Style := preload("res://ui/game_style.gd")
const Type := preload("res://minigames/cards/card_typography.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const SIZE := Vector2(384, 512)
const ART_RECT := Rect2(27, 111, 330, 184)
const ROLE_COLORS := {
	"scout": Color("4b7971"), "striker": Color("9b5c46"),
	"guard": Color("536e83"), "heavy": Color("786082"),
	"medic": Color("56816b"), "bolt": Color("af813d"), "patch": Color("56816b"),
	"bruiser": Color("97644f"), "sentinel": Color("4b7e87"),
	"forkshot": Color("857246"), "switcheroo": Color("786b95"),
	"champion": Color("ae843c"), "aegis": Color("4b8290"),
	"tempest": Color("8e689d"), "renewal": Color("56816b"), "thunderbolt": Color("b88436"),
}
const DARK := Color("233331")
const IVORY := Color("e9dfc6")
const BRASS := Color("b9a16d")
const RED := Color("a5473d")
var data: Dictionary = {}
var empty := true
var empty_text := "Empty lane"
var side := "player"
var highlighted := false
var art: Texture2D
static var _art_cache: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(card: Dictionary, vacant_text := "Empty lane", lane_side := "player") -> void:
	data = card
	empty = card.is_empty()
	empty_text = vacant_text
	side = lane_side
	art = card.get("art") as Texture2D
	var path: String = card.get("art_path", "")
	if art == null and not path.is_empty():
		if not _art_cache.has(path):
			_art_cache[path] = load(path) if ResourceLoader.exists(path) else null
		art = _art_cache[path] as Texture2D
	queue_redraw()

func set_highlight(value: bool) -> bool:
	if highlighted == value:
		return false
	highlighted = value
	queue_redraw()
	return true

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / SIZE)
	if empty:
		_draw_empty()
		return
	var accent: Color = ROLE_COLORS.get(str(data.get("id", "")), Color("89765c"))
	var kind: String = str(data.get("kind", "unit"))
	_frame(Rect2(1, 1, 382, 510), Color("4a4335"), Color("302e27"), 12, 2)
	var found: bool = data.get("collectible", false)
	_frame(Rect2(7, 7, 370, 498), IVORY, Style.GOLD if found else BRASS, 9, 3 if found else 2)
	_frame(Rect2(15, 15, 354, 482), IVORY, Color("95866b"), 5, 1)
	if found:
		for corner: Vector2 in [Vector2(19, 19), Vector2(365, 19), Vector2(19, 493), Vector2(365, 493)]:
			draw_circle(corner, 3.5, Style.GOLD)
	# Restrained printing texture, deterministic and cached with the card face.
	for y in range(19, 495, 5):
		draw_line(Vector2(20, y), Vector2(364, y), Color(.35, .26, .12, .025), 1)
	_draw_title(accent, kind)
	_draw_art(accent)
	_draw_rules(accent)
	if kind == "unit":
		_draw_unit_stats(accent)
	else:
		_draw_spell_stats(kind, accent)
	if highlighted:
		_frame(Rect2(2, 2, 380, 508), Color.TRANSPARENT, Style.GOLD, 11, 3)

func _draw_title(accent: Color, kind: String) -> void:
	_frame(Rect2(22, 22, 340, 64), DARK, BRASS, 4, 1)
	var title := Type.fit_title(str(data.get("name", "Card")), Style.font(true), 244)
	_text(title.text, Rect2(33, 33, 244, 42), title.size, Style.PAPER, true)
	var center := Vector2(329, 53)
	draw_circle(center, 31, BRASS)
	draw_circle(center, 27, accent.darkened(.20))
	draw_arc(center, 23, 0, TAU, 48, Color(Style.PAPER, .45), 1, true)
	_text(str(data.get("cost", 0)), Rect2(304, 23, 50, 45), 36, Style.PAPER, false, true)
	_text("COST", Rect2(302, 62, 54, 14), 10, Style.PAPER, false, true)
	var category := "CREATURE" if kind == "unit" else "SPELL"
	if data.get("ability", "") == "heal_allies":
		category += "  /  SUPPORT"
	elif data.get("ability", "") == "intercept":
		category += "  /  INTERCEPTOR"
	elif data.get("ability", "") == "diagonal":
		category += "  /  DIAGONAL"
	elif kind != "unit":
		category += "  /  " + {"heal": "RESTORATION", "damage": "STRIKE", "swap": "MANEUVER"}.get(kind, "UTILITY")
	_text(category, Rect2(30, 89, 324, 16), 12, accent.darkened(.25), false, true)

func _draw_art(accent: Color) -> void:
	_frame(ART_RECT.grow(3), DARK, BRASS, 1, 1)
	if art != null:
		var texture_size := art.get_size()
		var scale_factor := maxf(ART_RECT.size.x / texture_size.x, ART_RECT.size.y / texture_size.y)
		var crop_size := ART_RECT.size / scale_factor
		draw_texture_rect_region(art, ART_RECT, Rect2((texture_size - crop_size) * .5, crop_size))
	else:
		# Empty engraving field: intentionally no substitute character illustration.
		draw_rect(ART_RECT, DARK.lerp(accent, .20))
		for line in 8:
			var inset := 14.0 + line * 9
			var frame := ART_RECT.grow(-inset)
			if frame.size.y > 0:
				draw_rect(frame, Color(BRASS, .06), false, 1)
		var center := ART_RECT.get_center()
		draw_arc(center, 31, 0, TAU, 48, Color(BRASS, .45), 1, true)
		draw_arc(center, 35, 0, TAU, 48, Color(BRASS, .16), 1, true)
		_text(str(data.get("name", "?")).left(1), Rect2(center.x-24, center.y-26, 48, 48), 35, Color(Style.PAPER, .65), true, true)
		var label := "REFRACTION COLLECTION"
		if data.get("collectible", false):
			label = "FROM ELSEWHERE" if data.get("id", "") in Progression.BONUS else "HALL DISCOVERY"
		_text(label, Rect2(44, 270, 296, 14), 10, Color(Style.PAPER, .55), false, true)
	for x in [ART_RECT.position.x+8, ART_RECT.end.x-8]:
		for y in [ART_RECT.position.y+8, ART_RECT.end.y-8]:
			draw_circle(Vector2(x, y), 2, BRASS)

func _draw_rules(accent: Color) -> void:
	_text("ON PLAY" if data.get("ability", "") == "heal_allies" else "ABILITY" if data.get("kind", "unit") != "unit" else "TRAITS", Rect2(30, 308, 324, 18), 12, accent.darkened(.3), false, true)
	draw_line(Vector2(38, 331), Vector2(346, 331), Color(BRASS, .65), 1)
	var copy: String = str(data.get("description", ""))
	var layout := Type.rules(copy, Style.font(), 306)
	var point: int = layout.size
	var line_height := point * 1.22
	var total: float = layout.lines.size() * line_height
	var y: float = 342.0 + (78.0-total) * .5
	for line: String in layout.lines:
		_text(line, Rect2(39, y, 306, line_height), point, DARK, false, true)
		y += line_height

func _draw_unit_stats(accent: Color) -> void:
	var hp := int(data.get("hp", data.get("health", 0)))
	var maximum := int(data.get("max_hp", data.get("health", hp)))
	var hurt := hp < maximum
	_stat(Vector2(77, 459), str(data.get("power", 0)), "ATTACK", accent, false)
	_stat(Vector2(307, 459), str(hp), "HEALTH", RED if hurt else accent, true)
	if data.get("ability", "") == "intercept":
		var ready: bool = data.get("intercept_ready", true)
		var shield := PackedVector2Array([Vector2(151,448), Vector2(165,448), Vector2(165,459), Vector2(158,465), Vector2(151,459)])
		draw_colored_polygon(shield, accent if ready else Color("9b9789"))
		_text("READY" if ready else "SPENT", Rect2(171, 447, 78, 18), 12, accent if ready else Color("746b56"), false, true)
	else:
		_text("DIAGONAL" if data.get("ability", "") == "diagonal" else "CREATURE", Rect2(133, 447, 118, 18), 12, Color("746b56"), false, true)
	if hurt:
		_text("%d / %d HP" % [hp, maximum], Rect2(131, 467, 122, 18), 14, RED, false, true)
	else:
		draw_line(Vector2(160, 475), Vector2(224, 475), BRASS, 1)

func _stat(at: Vector2, number: String, caption: String, accent: Color, health: bool) -> void:
	var bounds := Rect2(at - Vector2(48, 30), Vector2(96, 62))
	_frame(bounds, DARK, BRASS, 5, 1)
	_text(number, Rect2(at.x - 26, at.y-29, 64, 49), 43, Color("f4ebd7"), false, true)
	if health:
		draw_colored_polygon(PackedVector2Array([at+Vector2(-33,-9), at+Vector2(-25,-9), at+Vector2(-25,2), at+Vector2(-29,8), at+Vector2(-33,2)]), accent.lightened(.3))
	else:
		draw_line(at+Vector2(-33,6), at+Vector2(-24,-9), accent.lightened(.3), 3, true)
		draw_line(at+Vector2(-35,0), at+Vector2(-27,5), accent.lightened(.3), 2, true)
	_text(caption, Rect2(at.x-50, at.y+16, 100, 15), 10, Style.PAPER, false, true)

func _draw_spell_stats(kind: String, accent: Color) -> void:
	_frame(Rect2(29, 431, 326, 62), DARK, BRASS, 5, 1)
	if kind == "swap":
		_text("↔", Rect2(40, 434, 66, 49), 43, Style.PAPER, false, true)
		_text("SWAP POSITIONS", Rect2(119, 440, 222, 23), 18, accent.lightened(.55))
		_text("TWO ADJACENT ALLIES", Rect2(119, 467, 222, 17), 11, Style.PAPER)
		return
	# Spell strength belongs to the card, including discoveries with larger effects.
	var amount := str(data.get("amount", 2))
	_text(amount, Rect2(40, 434, 66, 49), 43, Style.PAPER, false, true)
	var healing := kind == "heal"
	_text("RESTORE HEALTH" if healing else "DEAL DAMAGE", Rect2(119, 440, 222, 23), 18, accent.lightened(.55))
	_text("ONE INJURED ALLY" if healing else "ONE ENEMY CREATURE", Rect2(119, 467, 222, 17), 11, Style.PAPER)

func _draw_empty() -> void:
	var lane := empty_text.split("\n")[0].trim_prefix("Lane ")
	var numeral: String = {"1": "I", "2": "II", "3": "III", "4": "IV"}.get(lane, "")
	_text(numeral, Rect2(25, 15, 334, 38), 27, Color(Style.GOLD, .45), true, true)
	if side == "player":
		var center := Vector2(192, 256)
		draw_line(center-Vector2(10,0), center+Vector2(10,0), Color(Style.GOLD,.25), 2, true)
		draw_line(center-Vector2(0,10), center+Vector2(0,10), Color(Style.GOLD,.25), 2, true)
	if highlighted:
		for corner in [Vector2(14,14), Vector2(370,14), Vector2(14,498), Vector2(370,498)]:
			var dx := 1 if corner.x < 192 else -1
			var dy := 1 if corner.y < 256 else -1
			draw_line(corner, corner+Vector2(dx*40,0), Style.GOLD, 3, true)
			draw_line(corner, corner+Vector2(0,dy*40), Style.GOLD, 3, true)

func _frame(rect: Rect2, bg: Color, border: Color, radius: int, thickness: int) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = bg
	frame.border_color = border
	frame.set_corner_radius_all(radius)
	frame.set_border_width_all(thickness)
	draw_style_box(frame, rect)

func _text(copy: String, bounds: Rect2, point: int, color: Color, serif := false, centered := false) -> void:
	var font := Style.font(serif)
	var baseline := bounds.position.y + (bounds.size.y - font.get_height(point)) * .5 + font.get_ascent(point)
	draw_string(font, Vector2(bounds.position.x, baseline), copy,
		HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, bounds.size.x, point, color)
