extends RefCounted
## Turns ASCII pixel art into textures, and draws text in a 5x7 bitmap font.
##
## Each sprite is an array of equal-length strings; every character is a palette entry
## ("." is transparent). Textures are built once and cached by name.

const PALETTE := {
	"k": Color("0b0b18"),   # outline
	"w": Color("ffffff"),
	"W": Color("c8d4ff"),
	"l": Color("8fb8ff"),   # light blue
	"b": Color("3d6fe0"),   # blue
	"B": Color("1c3488"),   # deep blue
	"c": Color("6ef2ff"),   # cyan glow
	"C": Color("1aa6c9"),
	"g": Color("c4c9d6"),   # steel
	"G": Color("6a7186"),
	"r": Color("ff4d4d"),
	"R": Color("a3172e"),
	"o": Color("ffa23a"),
	"O": Color("c25a12"),
	"y": Color("ffe45c"),
	"Y": Color("b38b1c"),   # brass
	"n": Color("7cff8a"),   # green
	"N": Color("1f9a4a"),
	"p": Color("d77cff"),   # violet
	"P": Color("6a2bb0"),
	"s": Color("f2d2a9"),   # sand (hourglass)
	"S": Color("b8874f"),
}

static var _cache := {}


## The texture for `rows`, built on first use and cached under `name`.
static func tex(name: String, rows: Array) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in mini(w, row.length()):
			var ch := row[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	var t := ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


## A tinted copy (all opaque pixels set to `color`), for hit flashes.
static func flash(name: String, rows: Array, color := Color.WHITE) -> ImageTexture:
	var key := name + "#flash"
	if _cache.has(key):
		return _cache[key]
	var img := tex(name, rows).get_image()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, color)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# --- 5x7 font ----------------------------------------------------------------------------

const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
	"?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
	"'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
	"<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
	"x": ["00000", "00000", "10001", "01010", "00100", "01010", "10001"],
	"=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
	"(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
	")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
	"*": ["00000", "00100", "10101", "01110", "10101", "00100", "00000"],
}


## Width in pixels of `text` at `scale`.
static func text_width(text: String, scale := 1) -> int:
	return maxi(0, text.length() * 6 - 1) * scale


## Draws `text` with its top-left at `pos`. `align`: 0 left, 1 centre, 2 right.
static func text(ci: CanvasItem, pos: Vector2, s: String, color: Color, scale := 1, align := 0, shadow := true) -> void:
	var x := pos.x
	if align == 1:
		x -= text_width(s, scale) / 2.0
	elif align == 2:
		x -= text_width(s, scale)
	if shadow:
		_text_raw(ci, Vector2(roundf(x) + scale, roundf(pos.y) + scale), s, Color(0, 0, 0, 0.7 * color.a), scale)
	_text_raw(ci, Vector2(roundf(x), roundf(pos.y)), s, color, scale)


static func _text_raw(ci: CanvasItem, pos: Vector2, s: String, color: Color, scale: int) -> void:
	var x := pos.x
	for ch in s:
		var g: Array = GLYPHS.get(ch, GLYPHS.get(ch.to_upper(), []))
		for y in g.size():
			var row: String = g[y]
			for cx in 5:
				if row[cx] == "1":
					ci.draw_rect(Rect2(x + cx * scale, pos.y + y * scale, scale, scale), color)
		x += 6 * scale
