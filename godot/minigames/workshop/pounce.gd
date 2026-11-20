extends RefCounted
## The flashlight spot, and Fuse chasing it. Shine it at almost anything and he pounces:
## onto the Futurescope, the machine's tubes, the bench (knocking the radio's tuning), the
## window sill (swatting the blind cord), the icebox, the Engineer's shoe... Only the
## lever matters to the time loop (story.gd handles that one); the rest are just cat.

const Lines := preload("res://minigames/workshop/lines.gd")

const FLOOR_Y := 724.0
## Hotspot id -> where he lands, and whether he stays up there.
const TARGETS := {
	"tv": {"to": Vector2(900, 272), "stay": false},
	"machine": {"to": Vector2(1160, 420), "stay": false},
	"radio": {"to": Vector2(760, 496), "stay": false},
	"can": {"to": Vector2(840, 496), "stay": false},
	"drawer": {"to": Vector2(700, 496), "stay": false},
	"blinds": {"to": Vector2(300, 432), "stay": false},
	"icebox": {"to": Vector2(450, 330), "stay": true},
	"engineer": {"to": Vector2(320, 764), "stay": true},
	"clock": {"to": Vector2(1150, FLOOR_Y), "stay": true, "leap": 480.0},
	"twin": {"to": Vector2.ZERO, "stay": true},
	"placed_box": {"to": Vector2.ZERO, "stay": true},
	"floor": {"to": Vector2.ZERO, "stay": true},
}

var story: Node


func _init(owner_story: Node) -> void:
	story = owner_story


func can_target(id: String) -> bool:
	return TARGETS.has(id)


## Fuse chases the light to `id` (at stage point `at`, for the floor). Resolves when he
## has landed and had his moment.
func chase(id: String, at: Vector2) -> void:
	var w: Dictionary = story.world.things
	var fuse: Node2D = w.fuse
	var spec: Dictionary = TARGETS[id]
	var to: Vector2 = spec.to
	match id:
		"floor":
			to = Vector2(clampf(at.x, 520, 1240), clampf(at.y, 700, 800))
		"twin":
			to = story.twin.position + Vector2(-110 if story.twin.position.x > fuse.position.x else 110, 0)
		"placed_box":
			to = story.box_node().position + Vector2(0, -12)
	var spot: Node2D = story.light_spot(to + Vector2(0, -30))
	fuse.tail_mood = 3.0
	fuse.pose = "crouch"
	await story.wait(0.5)
	# Down from the icebox first, unless that's where the light is.
	if fuse.position.y < 600 and id != "icebox":
		await fuse.jump_to(Vector2(560, FLOOR_Y), 60.0, 0.55)
	if id == "floor":
		await fuse.walk_to(to.x, to.y)
	else:
		var height: float = spec.get("leap", 110.0)
		await fuse.jump_to(to, height, 0.6, "sit")
	spot.queue_free()
	await _consequence(id)
	if not spec.stay:
		await story.wait(0.9)
		await fuse.jump_to(Vector2(to.x + 40, FLOOR_Y), 60.0, 0.5, "sit")
	fuse.tail_mood = 1.0


func _consequence(id: String) -> void:
	var w: Dictionary = story.world.things
	match id:
		"radio":
			story.radio_next_station(false)
		"blinds":
			story.flags.blinds = not story.flags.blinds
			w.blinds.open = story.flags.blinds
			Sound.play("dial_snap", story)
		"tv":
			w.tv.tuned = false
			await story.wait(0.5)
			w.tv.tuned = story.flags.tuned
		"twin":
			story.twin.startle()
			Sound.play("unavailable", story, -6.0, 1.6)
		"placed_box":
			story.raise_box_over(w.fuse)
		"engineer":
			w.engineer.gesture = "shrug"
	if Lines.POUNCE.has(id):
		await story.engineer.nudge_line("pounce_" + id, Lines.POUNCE[id])
	w.engineer.gesture = "idle"
