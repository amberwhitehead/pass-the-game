extends RefCounted
## The Workshop after it's won: a calm room, the wire back in, Fuse off somewhere in the
## hall, a Futurescope that picks up other rooms' futures (channels.gd), and a portal
## that sends things to the hall's ring tray (autoload/time_link.gd).

const Machine := preload("res://minigames/workshop/machine.gd")
const Channels := preload("res://minigames/workshop/channels.gd")
const Items := preload("res://minigames/workshop/items.gd")
const Lines := preload("res://minigames/workshop/lines.gd")
const TimeLink := preload("res://autoload/time_link.gd")

var story: Node
var _channel := -1


func _init(owner_story: Node) -> void:
	story = owner_story


func begin() -> void:
	var w: Dictionary = story.world.things
	var f: Dictionary = story.flags
	f.phase = "epilogue"
	f.wire = "machine"
	w.fuse.visible = false
	w.machine.powered = true
	w.machine.fuse_blown = false
	w.wire.taken = true
	w.wire.enabled = false
	w.radio.back_open = true
	w.radio.has_tube = false
	w.tv.has_tube = true
	w.tv.on = true
	w.tv.tuned = true
	story.inventory.items.clear()
	for item: String in TimeLink.SENDABLE:
		if not TimeLink.was_sent(item):
			story.inventory.add(item)


func arrival_lines() -> Array:
	return Lines.EPILOGUE


## Each click on the Futurescope turns to the next channel and watches it.
func next_channel() -> void:
	var w: Dictionary = story.world.things
	var list := Channels.available()
	list.append({"id": "workshop", "title": "1955 · THE WORKSHOP", "scene": null})
	_channel = (_channel + 1) % list.size()
	var ch: Dictionary = list[_channel]
	Sound.play("dial_turn", story)
	if ch.scene == null:
		w.tv.show_channel(null)
		await story.watch("calm", ch.title)
		return
	var scene: Node2D = ch.scene.new()
	w.tv.show_channel(scene)
	story.closeup.open(w.tv.feed_texture(), w.tv.material(), ch.title)
	await scene.play()
	await story.closeup.close()
	w.tv.show_channel(null)


## Sends an item through the portal to the hall's ring tray.
func send(item: String) -> void:
	if not TimeLink.SENDABLE.has(item):
		await story.nope("portal")
		return
	if TimeLink.tray_item() != "":
		await story.nope("portal")
		await story.say("engineer", Lines.TRAY_FULL)
		return
	var m: Node2D = story.world.things.machine
	story.world.things.engineer.gesture = "point"
	story.world.things.engineer.point_at = Machine.PORTAL_CENTER
	m.lever_down = true
	Sound.play("dial_snap", story)
	var tw := story.create_tween()
	tw.tween_property(m, "portal", 1.0, 0.7)
	Sound.play("lens_light", story)
	await tw.finished
	story.use_up(item)
	var icon := ItemIcon.new()
	icon.item = item
	icon.position = Vector2(800, 820)
	story.world.add_child(icon)
	tw = story.create_tween().set_parallel()
	tw.tween_property(icon, "position", Machine.PORTAL_CENTER, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "scale", Vector2(0.2, 0.2), 0.7)
	await tw.finished
	icon.queue_free()
	TimeLink.send_to_hall(item)
	tw = story.create_tween()
	tw.tween_property(m, "portal", 0.0, 0.6)
	await tw.finished
	m.lever_down = false
	await story.say("engineer", Lines.SENT)


class ItemIcon extends Node2D:
	var item := ""

	func _draw() -> void:
		Items.draw_icon(self, item, Vector2.ZERO)
