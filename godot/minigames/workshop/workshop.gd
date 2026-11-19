extends MiniGame
## 04 Workshop: the 50s Engineer's garage lab, a hand-drawn 2D point-and-click story.

const World := preload("res://minigames/workshop/world.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const STAGE_SIZE := Vector2(1600, 900)

var _stage: Node2D
var _world: Node2D


func _ready() -> void:
	use_touch_controls = false
	var bg := ColorRect.new()
	bg.color = Color("1d1410")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_world = World.new()
	_stage.add_child(_world)
	resized.connect(_fit_stage)
	_fit_stage()
	super()


func _fit_stage() -> void:
	var s := minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = (size - STAGE_SIZE * s) * 0.5


## Dev hook for tools/workshop_shot.gd.
func debug_step(step: String) -> void:
	match step:
		"poses":
			var x := 120.0
			for p in ["sit", "stand", "walk", "jump", "crouch", "eat", "sleep"]:
				var c := Cat.new()
				c.pose = p
				c.position = Vector2(x, 840)
				c.yarn = p == "sit"
				c.lid = p in ["sit", "stand"]
				c.displaced = p == "stand"
				_world.add_child(c)
				x += 210.0
		"tv":
			_world.things.tv.has_tube = true
			_world.things.tv.on = true
			_world.things.tv.tuned = true
			_world.things.machine.powered = true
			_world.things.machine.portal = 1.0
			_world.things.tv.future.things.machine.portal = 0.6
			_world.things.tv.future.things.fuse.position = Vector2(1300, 470)
			_world.things.tv.future.things.fuse.pose = "sit"
		"open":
			_world.things.icebox.open = true
			_world.things.bench.drawer_open = true
			_world.things.radio.back_open = true
			_world.things.blinds.open = true
			_world.things.box.folded = true
			_world.things.box.position = Vector2(700, 664)
