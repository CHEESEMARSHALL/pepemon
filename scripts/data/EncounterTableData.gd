extends Resource
class_name EncounterTableData

@export var monsters: Array[Resource] = []
@export var weights: Array[int] = []
@export_range(1, 100, 1) var min_level: int = 3
@export_range(1, 100, 1) var max_level: int = 5


func get_random_encounter(rng: RandomNumberGenerator) -> Dictionary:
	if monsters.is_empty():
		return {}

	var total_weight := _get_total_weight()
	var chosen_index := 0

	if total_weight > 0:
		var roll := rng.randi_range(1, total_weight)
		var running_total := 0

		for index in monsters.size():
			running_total += _get_weight(index)

			if roll <= running_total:
				chosen_index = index
				break
	else:
		chosen_index = rng.randi_range(0, monsters.size() - 1)

	return {
		"monster": monsters[chosen_index],
		"level": rng.randi_range(min_level, max_level),
	}


func _get_total_weight() -> int:
	var total := 0

	for index in monsters.size():
		total += _get_weight(index)

	return total


func _get_weight(index: int) -> int:
	if index < weights.size():
		return max(0, weights[index])

	return 1
