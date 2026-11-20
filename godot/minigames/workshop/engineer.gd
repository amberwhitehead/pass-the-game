extends RefCounted
## The Engineer's side of the story: turning up a moment after you, minding his things,
## getting put out as you rummage, and (only when you're nearly there) a nudge.
## Remarks and nudges are said once each; what's been said is saved with the story.

const Lines := preload("res://minigames/workshop/lines.gd")

const SPOT := Vector2(236, 760)       ## Where he stands.
const OFFSTAGE := Vector2(-140, 760)  ## Through the door on the left.

var story: Node   ## story.gd


func _init(owner_story: Node) -> void:
	story = owner_story


func _node() -> Node2D:
	return story.world.things.engineer


## He wasn't here when you came in. A moment later, he is.
func arrive() -> void:
	var f: Dictionary = story.flags
	var e := _node()
	e.position = OFFSTAGE
	e.facing = 1.0
	await story.wait(1.0)
	await e.walk_to(SPOT.x, 1.1)
	f.visits = int(f.visits) + 1
	if int(f.visits) == 1:
		e.gesture = "shrug"
		await story.says("engineer", Lines.KICKOFF)
	else:
		await story.say("engineer", Lines.FOLLOWING[(int(f.visits) - 2) % Lines.FOLLOWING.size()])
	e.gesture = "idle"


## He arrives a moment after you and says `lines` (the visit after the win).
func arrive_with(lines: Array) -> void:
	var e := _node()
	e.position = OFFSTAGE
	await story.wait(1.0)
	await e.walk_to(SPOT.x, 1.1)
	story.flags.visits = int(story.flags.visits) + 1
	await story.says("engineer", lines)


## You touched one of his things: a remark the first time, and annoyance adds up.
func mine(thing: String) -> void:
	var f: Dictionary = story.flags
	f.annoyance = int(f.annoyance) + 1
	if Lines.MINE.has(thing) and once("mine_" + thing):
		await story.say("engineer", Lines.MINE[thing])
	elif Lines.ANNOYED.has(int(f.annoyance)):
		_node().gesture = "shrug"
		await story.say("engineer", Lines.ANNOYED[int(f.annoyance)])
		_node().gesture = "idle"


## A nudge, said once, when you're close.
func nudge(key: String) -> void:
	if once("nudge_" + key):
		await story.say("engineer", Lines.NUDGES[key])


## Any line, said once under `key`.
func nudge_line(key: String, text: String) -> void:
	if once(key):
		await story.say("engineer", text)


## True the first time `key` is asked about (and remembers it).
func once(key: String) -> bool:
	var said: Array = story.flags.said
	if key in said:
		return false
	said.append(key)
	return true


## His milk: he takes it back, with feeling. The third time, he drinks it.
func milk() -> void:
	var f: Dictionary = story.flags
	var n := int(f.milk_grabs)
	f.milk_grabs = n + 1
	f.annoyance = int(f.annoyance) + 2
	var e := _node()
	e.gesture = "point"
	e.point_at = Vector2(440, 430)
	await story.say("engineer", Lines.MILK[mini(n, Lines.MILK.size() - 1)])
	e.gesture = "idle"
	if n >= 2:
		f.milk = "drunk"
		e.gesture = "think"
		Sound.play("place", story, -6.0, 0.7)
		await story.wait(1.0)
		e.gesture = "idle"
