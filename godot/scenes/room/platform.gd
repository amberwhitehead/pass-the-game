class_name StationPlatform
extends Node3D
## The big decorative platform of a station: a .glb from blends/props/ (authored at the mini-game's own scale, with
## its display surface at y=0) scaled down to a table, with a collider so you can't walk through it.
## Add it as a child of a station Prop; it hides that Prop's pedestal (the floating crystal stays above it).

@export var model: PackedScene
@export var model_scale := 0.3            ## uniform; the model is ~2.6 tall and ~7 wide at scale 1
@export var model_height := 2.6           ## model units from its feet to the display surface
@export var collider_radius := 3.5        ## model units: the wall, not the rocket fins

var _inst: Node3D


func _ready() -> void:
	add_to_group("platform")
	position.y = model_height * model_scale
	_inst = model.instantiate() as Node3D
	_inst.scale = Vector3.ONE * model_scale
	add_child(_inst)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = collider_radius * model_scale
	cyl.height = model_height * model_scale
	shape.shape = cyl
	shape.position.y = -cyl.height / 2.0
	body.add_child(shape)
	add_child(body)
	var pedestal := get_parent().get_node_or_null("Pedestal")
	if pedestal:
		pedestal.visible = false


## Adds something in the model's own (game-scale) units, e.g. a mini-game trophy sitting on the display surface.
func add_to_model(node: Node3D) -> void:
	_inst.add_child(node)
