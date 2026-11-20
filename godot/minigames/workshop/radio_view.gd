extends Node2D
## The Engineer's radio, up close. The front has a power knob, a tuning knob and a dial
## window; turn it round and the back panel is held on by four screws, with the tubes
## behind it. This only draws and hit-tests; story.gd decides what each part does.

const Ink := preload("res://minigames/workshop/ink.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Style := preload("res://ui/game_style.gd")
const Small := preload("res://minigames/workshop/small_props.gd")

const BODY := Rect2(430, 210, 740, 450)
const POWER := Vector2(1000, 560)
const TUNE := Vector2(1100, 560)
const DIAL := Rect2(860, 270, 270, 90)
const TURN := Rect2(1190, 610, 150, 60)
const SCREWS := [Vector2(470, 250), Vector2(1130, 250), Vector2(470, 620), Vector2(1130, 620)]
const TUBE := Vector2(800, 520)
const RadioSongs := preload("res://minigames/workshop/radio_songs.gd")

var view := "front":       ## "front" or "back"
	set(v):
		view = v
		queue_redraw()
var on := false
var station := 0
var tuning := 0.0          ## > 0 while the needle sweeps between stations (static).
var screws_out := 0        ## How many of the four screws are out (in order).
var tube_present := true
var _t := 0.0


func _ready() -> void:
	z_index = 40
	visible = false


func open() -> void:
	view = "front"
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		tuning = maxf(0.0, tuning - delta)
		queue_redraw()


## What part of the radio is at a stage point: "power", "tune", "turn", "screw", "tube",
## "body" (nothing in particular) or "outside".
func part_at(p: Vector2) -> String:
	if TURN.has_point(p):
		return "turn"
	if view == "front":
		if p.distance_to(POWER) < 42:
			return "power"
		if p.distance_to(TUNE) < 42:
			return "tune"
	else:
		if screws_out < 4:
			for k in range(screws_out, 4):
				if p.distance_to(SCREWS[k]) < 26:
					return "screw"
		elif tube_present and p.distance_to(TUBE + Vector2(0, -40)) < 60:
			return "tube"
	return "body" if BODY.has_point(p) else "outside"


func hover_label(p: Vector2) -> String:
	match part_at(p):
		"power": return "Power" if not on else "Switch off"
		"tune": return "Tuning knob"
		"turn": return "Turn it round" if view == "front" else "Turn it back"
		"screw": return "Screw"
		"tube": return "Vacuum tube"
	return ""


func _draw() -> void:
	draw_rect(Rect2(-50, -50, 1700, 1000), Color(0.08, 0.05, 0.04, 0.8))
	if view == "front":
		_front()
	else:
		_back()
	# The turn-around button.
	Ink.shape(self, Ink.rrect(TURN, 12), P.CREAM, 3.0, 960, 0.1, 0.1)
	var arrow := TURN.get_center()
	Ink.line(self, Ink.ellipse(arrow + Vector2(-26, 0), Vector2(16, 14), 12, PI * 0.2, PI * 1.6), Ink.OUTLINE, 3.0, 961)
	draw_string(Style.font(true), arrow + Vector2(-2, 6), "TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ink.OUTLINE)


func _front() -> void:
	Ink.shape(self, Ink.rrect(BODY, 70), Color("b33a35"), 5.0, 900, 0.25, 0.15)
	# Speaker grille.
	var grille := Rect2(480, 260, 330, 350)
	Ink.shape(self, Ink.rrect(grille, 40), P.CREAM, 4.0, 901, 0.0, 0.12)
	for k in 11:
		Ink.line(self, PackedVector2Array([Vector2(505, 290 + k * 29), Vector2(785, 290 + k * 29)]), P.WOOD_DARK, 3.0, 902 + k)
	if on and tube_present:
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		draw_rect(grille.grow(-30), Color(1, 0.9, 0.6, 0.05 + 0.05 * pulse))
	# Dial window with a needle.
	Ink.shape(self, Ink.rrect(DIAL, 14), Color("f3e6b8") if on else Color("8a8270"), 3.5, 920, 0.1, 0.1)
	for k in 9:
		var x := DIAL.position.x + 20 + k * 29
		draw_line(Vector2(x, DIAL.position.y + 12), Vector2(x, DIAL.position.y + (30 if k % 2 == 0 else 22)), Ink.OUTLINE, 2.0)
	var needle_x := DIAL.position.x + 30 + station * (DIAL.size.x - 60) / maxf(1.0, RadioSongs.STATIONS.size() - 1) + (sin(_t * 30.0) * 8.0 if tuning > 0.0 else 0.0)
	draw_line(Vector2(needle_x, DIAL.position.y + 8), Vector2(needle_x, DIAL.end.y - 8), P.RED, 3.0)
	var label := "· · ·" if not on or not tube_present else ("~ static ~" if tuning > 0.0 else "%s · %s" % [RadioSongs.STATIONS[station].frequency, RadioSongs.STATIONS[station].name.to_upper()])
	draw_string(Style.font(true), Vector2(DIAL.position.x, DIAL.end.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, DIAL.size.x, 15, Ink.OUTLINE)
	# Knobs.
	for c in [POWER, TUNE]:
		Ink.dot(self, c, 40, P.CREAM, 4.0, 930 + int(c.x), 0.25, 0.15)
	var pa := -0.8 if not on else 0.8
	Ink.line(self, PackedVector2Array([POWER, POWER + Vector2(sin(pa), -cos(pa)) * 30]), Ink.OUTLINE, 4.0, 932)
	var ta := -1.2 + station * 1.2
	Ink.line(self, PackedVector2Array([TUNE, TUNE + Vector2(sin(ta), -cos(ta)) * 30]), Ink.OUTLINE, 4.0, 933)
	draw_string(Style.font(true), POWER + Vector2(-40, 62), "POWER", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, P.CREAM)
	draw_string(Style.font(true), TUNE + Vector2(-40, 62), "TUNING", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, P.CREAM)
	if on and tube_present:
		Ink.dot(self, Vector2(1050, 610), 7, Color("ff8a3a"), 2.0, 934, 0.4)


func _back() -> void:
	Ink.shape(self, Ink.rrect(BODY, 70), Color("8a2c28"), 5.0, 940, 0.12, 0.2)
	if screws_out < 4:
		var panel := BODY.grow(-30)
		Ink.shape(self, Ink.rrect(panel, 40), Color("6b4a2e"), 4.0, 941, 0.1, 0.15)
		for k in 6:
			Ink.line(self, PackedVector2Array([Vector2(560 + k * 90, 300), Vector2(560 + k * 90, 580)]), Color("4a3320"), 4.0, 942 + k)
		draw_string(Style.font(true), Vector2(panel.position.x, panel.get_center().y), "NO USER SERVICEABLE PARTS INSIDE", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 20, P.CREAM.darkened(0.3))
	else:
		var inside := BODY.grow(-30)
		Ink.shape(self, Ink.rrect(inside, 40), Color("2a1d14"), 4.0, 950, 0.0, 0.0)
		for k in 3:
			var at := Vector2(620 + k * 180, 560)
			if k == 1 and not tube_present:
				Ink.shape(self, Ink.rrect(Rect2(at + Vector2(-34, -10), Vector2(68, 34)), 6), P.STEEL, 3.0, 951)
				continue
			Small.Radio._tube(self, at, 2.6, 952 + k, on and k == 1)
	for k in range(screws_out, 4):
		var c: Vector2 = SCREWS[k]
		Ink.dot(self, c, 16, P.CHROME, 3.0, 960 + k, 0.35, 0.1)
		Ink.line(self, PackedVector2Array([c + Vector2(-10, -4), c + Vector2(10, 4)]), Ink.OUTLINE, 3.0, 965 + k)
