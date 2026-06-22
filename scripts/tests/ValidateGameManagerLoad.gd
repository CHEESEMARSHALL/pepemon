extends SceneTree

const TEST_SAVE_PATH := "user://savegame.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")
	var save_manager_script := load("res://scripts/game/SaveManager.gd") as Script

	if monster_instance_script == null or game_root_scene == null or fire_data == null or water_data == null or save_manager_script == null:
		push_error("GameManager load validation could not load required resources.")
		quit(1)
		return

	var saved_monster = monster_instance_script.new()
	saved_monster.setup(fire_data, 8)
	saved_monster.nickname = "Saved Ember"
	saved_monster.current_hp = 17

	var saved_second = monster_instance_script.new()
	saved_second.setup(water_data, 6)
	saved_second.nickname = "Saved Ripple"
	saved_second.current_hp = 21

	if not save_manager_script.save_game([saved_monster, saved_second], TEST_SAVE_PATH, 1, {"potion": 1, "capture_capsule": 4}):
		push_error("Could not prepare save data for GameManager load validation.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	get_root().add_child(game_root)
	await process_frame

	var loaded_monster = game_root.get("_player_monster")
	var loaded_party: Array = game_root.get("_player_party")
	var loaded_inventory: Dictionary = game_root.get("_inventory")

	if loaded_monster == null or loaded_monster.nickname != "Saved Ripple" or loaded_monster.level != 6 or loaded_monster.current_hp != 21:
		push_error("GameManager did not load saved player monster data.")
		quit(1)
		return

	if loaded_party.size() != 2 or loaded_party[1].nickname != "Saved Ripple" or loaded_party[1].level != 6 or loaded_party[1].current_hp != 21:
		push_error("GameManager did not load the saved party data.")
		quit(1)
		return

	if int(loaded_inventory.get("potion", -1)) != 1 or int(loaded_inventory.get("capture_capsule", -1)) != 4:
		push_error("GameManager did not load saved inventory counts.")
		quit(1)
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	if test_save_tools != null:
		test_save_tools.clear_main_save()

	print("GameManager load validation passed.")
	quit()
