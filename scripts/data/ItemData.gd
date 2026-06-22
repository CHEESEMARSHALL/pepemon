extends Resource
class_name ItemData

@export_group("Identity")
@export var item_name: String = "Potion"

@export_group("Battle")
@export_range(0, 999, 1) var heal_amount: int = 20
@export_range(0.0, 1.0, 0.01) var capture_rate: float = 0.0
@export var usable_in_battle: bool = true


func is_capture_item() -> bool:
	return capture_rate > 0.0
