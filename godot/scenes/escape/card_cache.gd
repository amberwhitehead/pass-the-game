extends Node3D
## Discoverable additions live on the hall's perimeter, outside every puzzle gate.
signal message(text: String)
const Pickup := preload("res://scenes/escape/card_pickup.gd")
const PLACEMENTS := [
	{"id": "champion", "at": Vector3(9.45, 1.38, 7.35), "yaw": PI},
	{"id": "aegis", "at": Vector3(-10.45, 1.55, -5.2), "yaw": PI / 2},
	{"id": "tempest", "at": Vector3(-9.5, 1.30, -7.35), "yaw": 0.0},
	{"id": "renewal", "at": Vector3(-3.3, 1.20, 7.35), "yaw": PI},
	{"id": "thunderbolt", "at": Vector3(7.3, 1.70, -7.35), "yaw": 0.0},
]


func _ready() -> void:
	for placement: Dictionary in PLACEMENTS:
		if placement.id in Game.collected_cards:
			continue
		var card := Pickup.new()
		card.name = String(placement.id).to_pascal_case() + "Card"
		card.configure(placement.id)
		card.position = placement.at
		card.rotation.y = placement.yaw
		card.message.connect(func(text: String): message.emit(text))
		add_child(card)
