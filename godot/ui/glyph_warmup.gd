extends Node2D
## Draws every glyph dialogue is likely to use, invisibly, for a couple of frames, then
## frees itself.
##
## Godot rasterizes each glyph the first time it is drawn at a size and re-uploads the
## font's cache texture. A speech bubble typing out its first line at a fresh size did
## that dozens of times in a row, which showed as a hitch on the Web build. Warming the
## cache while a scene loads moves that work to where nobody is watching.
##
## Add as a child of the node the text will be drawn under (so the same scale, and so
## the same oversampled cache, is warmed):
##   GlyphWarmup.add_to(stage, [[Style.font(), 22], [Style.font(true), 15]])

const CHARSET := " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~" \
	+ "°±²·×áéü–—‘’“”…‹›←→▲▶▼◀"
const FRAMES := 2

var jobs: Array = []  ## [[Font, size], ...]
var _frames := 0


static func add_to(parent: Node, font_sizes: Array) -> Node2D:
	var w := new()
	w.name = "GlyphWarmup"
	w.jobs = font_sizes
	parent.add_child(w)
	return w


func _ready() -> void:
	z_index = -4096
	queue_redraw()


func _process(_d: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var y := 0.0
	for job: Array in jobs:
		var font: Font = job[0]
		var size: int = job[1]
		y += size
		# Nearly transparent rather than invisible: hidden items aren't drawn at all.
		draw_string(font, Vector2(0, y), CHARSET, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.004))
