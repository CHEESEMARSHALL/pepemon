extends SceneTree

const TEST_SAVE_PATH := "user://test_savegame.json"


func _init() -> void:
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var save_manager_script := load("res://scripts/game/SaveManager.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")

	if monster_instance_script == null or save_manager_script == null or fire_data == null or water_data == null:
		push_error("Save validation could not load required resources.")
		quit(1)
		return

	var original = monster_instance_script.new()
	original.setup(fire_data, 7)
	original.nickname = "Cinder"
	original.current_hp = 11
	original.experience = 400
	original.spend_move_pp(0)
	original.spend_move_pp(0)

	var second = monster_instance_script.new()
	second.setup(water_data, 4)
	second.nickname = "Ripple"
	second.current_hp = 22

	var inventory := {
		"potion": 2,
		"capture_capsule": 1,
	}

	if not save_manager_script.save_game([original, second], TEST_SAVE_PATH, 1, inventory):
		push_error("SaveManager failed to save test data.")
		quit(1)
		return

	var save_data: Dictionary = save_manager_script.load_game(TEST_SAVE_PATH)
	var loaded = monster_instance_script.new()
	var loaded_second = monster_instance_script.new()

	if save_data.is_empty() or not save_data.has("player_party") or save_data["player_party"].size() != 2:
		push_error("SaveManager failed to save the full party.")
		quit(1)
		return

	if int(save_data.get("active_party_index", -1)) != 1:
		push_error("SaveManager failed to save the active party index.")
		quit(1)
		return

	if not save_data.has("inventory") or int(save_data["inventory"].get("potion", -1)) != 2 or int(save_data["inventory"].get("capture_capsule", -1)) != 1:
		push_error("SaveManager failed to save inventory counts.")
		quit(1)
		return

	if not loaded.load_save_data(save_data["player_party"][0]) or not loaded_second.load_save_data(save_data["player_party"][1]):
		push_error("SaveManager failed to reload test data.")
		quit(1)
		return

	if loaded.nickname != "Cinder" or loaded.level != 7 or loaded.current_hp != 11 or loaded.experience != 400:
		push_error("Loaded monster core fields did not match saved data.")
		quit(1)
		return

	if loaded.get_move_pp(0) != original.get_move_pp(0):
		push_error("Loaded move PP did not match saved data.")
		quit(1)
		return

	if loaded_second.nickname != "Ripple" or loaded_second.level != 4 or loaded_second.current_hp != 22:
		push_error("Loaded second party member did not match saved data.")
		quit(1)
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("Save/load validation passed.")
	quit()
