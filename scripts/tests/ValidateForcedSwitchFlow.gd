extends SceneTree


func _init() -> void:
	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")
	var grass_data = load("res://data/monsters/GrassSprout.tres")

	if battle_manager_script == null or monster_instance_script == null or fire_data == null or water_data == null or grass_data == null:
		push_error("Forced switch validation could not load required resources.")
		quit(1)
		return

	var fire_instance = monster_instance_script.new()
	fire_instance.setup(fire_data, 5)
	fire_instance.current_hp = 1

	var water_instance = monster_instance_script.new()
	water_instance.setup(water_data, 5)

	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(grass_data, 5)

	var battle_manager = battle_manager_script.new()
	get_root().add_child(battle_manager)
	battle_manager.start_battle([fire_instance, water_instance], enemy_instance)
	battle_manager.state = battle_manager.BattleState.ENEMY_TURN
	battle_manager.advance_turn()

	if battle_manager.state != battle_manager.BattleState.FORCE_SWITCH:
		push_error("Expected battle to enter FORCE_SWITCH after active monster fainted.")
		quit(1)
		return

	if not battle_manager.switch_player_monster(1):
		push_error("Expected forced switch to second party member to succeed.")
		quit(1)
		return

	if battle_manager.get_active_player_index() != 1:
		push_error("Forced switch did not activate the second party member.")
		quit(1)
		return

	print("Forced switch validation passed: Tiddler entered after faint.")
	quit()
