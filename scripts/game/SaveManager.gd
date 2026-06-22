extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"


static func save_game(
	player_data,
	path: String = SAVE_PATH,
	active_party_index: int = 0,
	inventory: Dictionary = {},
	route_state: Dictionary = {},
	world_state: Dictionary = {}
) -> bool:
	var party_data := _serialize_party(player_data)

	if party_data.is_empty():
		push_error("SaveManager.save_game requires a MonsterInstance-like resource or party.")
		return false

	var save_data := {
		"version": 5,
		"player_party": party_data,
		"active_party_index": clampi(active_party_index, 0, party_data.size() - 1),
	}

	if not inventory.is_empty():
		save_data["inventory"] = _serialize_inventory(inventory)

	if not route_state.is_empty():
		save_data["route_state"] = _serialize_route_state(route_state)

	if not world_state.is_empty():
		save_data["world_state"] = _serialize_world_state(world_state)

	if party_data.size() == 1:
		save_data["player_monster"] = party_data[0]

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Could not open save file for writing: %s" % path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	return true


static func load_game(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Could not open save file for reading: %s" % path)
		return {}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())

	if parse_error != OK:
		push_error("Could not parse save file: %s" % json.get_error_message())
		return {}

	var data = json.data

	if data is Dictionary:
		return data

	return {}


static func _serialize_party(player_data) -> Array:
	var party := []

	if player_data is Array:
		for member in player_data:
			var serialized := _serialize_monster(member)

			if not serialized.is_empty():
				party.append(serialized)
	else:
		var serialized := _serialize_monster(player_data)

		if not serialized.is_empty():
			party.append(serialized)

	return party


static func _serialize_monster(monster) -> Dictionary:
	if monster == null or not monster.has_method("to_save_data"):
		return {}

	return monster.call("to_save_data")


static func _serialize_inventory(inventory: Dictionary) -> Dictionary:
	var serialized := {}

	for key in inventory.keys():
		serialized[str(key)] = max(0, int(inventory[key]))

	return serialized


static func _serialize_route_state(route_state: Dictionary) -> Dictionary:
	var serialized := {}
	var defeated_trainers := []
	var collected_pickups := []

	for trainer_id in route_state.get("defeated_trainers", []):
		var string_id := str(trainer_id)

		if not string_id.is_empty() and not defeated_trainers.has(string_id):
			defeated_trainers.append(string_id)

	serialized["defeated_trainers"] = defeated_trainers

	for pickup_id in route_state.get("collected_pickups", []):
		var string_id := str(pickup_id)

		if not string_id.is_empty() and not collected_pickups.has(string_id):
			collected_pickups.append(string_id)

	serialized["collected_pickups"] = collected_pickups
	return serialized


static func _serialize_world_state(world_state: Dictionary) -> Dictionary:
	var serialized := {}
	var map_path := str(world_state.get("map_path", ""))
	var player_cell = world_state.get("player_cell", Vector2i.ZERO)

	if not map_path.is_empty():
		serialized["map_path"] = map_path

	if player_cell is Vector2i:
		serialized["player_cell"] = {
			"x": player_cell.x,
			"y": player_cell.y,
		}
	elif player_cell is Dictionary:
		serialized["player_cell"] = {
			"x": int(player_cell.get("x", 0)),
			"y": int(player_cell.get("y", 0)),
		}

	return serialized
