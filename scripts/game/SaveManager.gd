extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"


static func save_game(player_data, path: String = SAVE_PATH, active_party_index: int = 0, inventory: Dictionary = {}) -> bool:
	var party_data := _serialize_party(player_data)

	if party_data.is_empty():
		push_error("SaveManager.save_game requires a MonsterInstance-like resource or party.")
		return false

	var save_data := {
		"version": 3,
		"player_party": party_data,
		"active_party_index": clampi(active_party_index, 0, party_data.size() - 1),
	}

	if not inventory.is_empty():
		save_data["inventory"] = _serialize_inventory(inventory)

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
