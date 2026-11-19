extends Node2D
## Builds the Workshop room: scenery, props and characters, in drawing order.
##
## The same room is built twice: once for play and once inside the Futurescope, which
## shows the room's future. `things` maps names to the nodes so story code can
## reach them; `hotspots()` lists every clickable Thing.

const Thing := preload("res://minigames/workshop/thing.gd")
const Backdrop := preload("res://minigames/workshop/backdrop.gd")
const Icebox := preload("res://minigames/workshop/icebox.gd")
const Bench := preload("res://minigames/workshop/bench.gd")
const Small := preload("res://minigames/workshop/small_props.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Machine := preload("res://minigames/workshop/machine.gd")
const Futurescope := preload("res://minigames/workshop/futurescope.gd")
const Person := preload("res://minigames/workshop/person.gd")

## Where the cats spend their time.
const ICEBOX_TOP := Vector2(450, 330)
const FLOOR_Y := 664.0

var things := {}
## The copy inside the Futurescope: no feed of its own, and nothing in it is clickable.
var is_future := false


func _ready() -> void:
	_add("backdrop", Backdrop.new())
	var floor := Thing.new()
	floor.id = "floor"
	floor.hit_rect = Rect2(0, 690, 1600, 210)
	_add("floor", floor)
	_add("blinds", Small.Blinds.new())
	_add("wire", Small.WireCoil.new())
	_add("clock", Small.Clock.new())
	_add("tv", Futurescope.new())
	_add("box", Small.Box.new())
	_add("machine", Machine.new())
	_add("icebox", Icebox.new())
	_add("bench", Bench.new())
	_add("radio", Small.Radio.new())
	_add("can", Small.CoffeeCan.new())
	_add("basket", Small.Basket.new())
	var tin := Small.Tin.new()
	tin.visible = false
	_add("tin", tin)
	var fuse := Cat.new()
	fuse.position = ICEBOX_TOP
	fuse.pose = "sleep"
	fuse.facing = 1.0
	fuse.id = "fuse"
	_add("fuse", fuse)
	var engineer := Person.new()
	engineer.kind = "engineer"
	engineer.position = Vector2(236, 760)
	_add("engineer", engineer)
	if is_future:
		for t in hotspots():
			t.id = ""
	else:
		var future: Node2D = get_script().new()
		future.is_future = true
		things.tv.setup(future)


func _add(key: String, node: Node2D) -> Node2D:
	node.name = key.to_pascal_case()
	things[key] = node
	add_child(node)
	return node


## Every clickable Thing, topmost (last drawn) first.
func hotspots() -> Array:
	var out := []
	_collect(self, out)
	out.reverse()
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Thing and c.id != "":
			out.append(c)
		_collect(c, out)
