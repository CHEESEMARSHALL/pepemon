extends SceneTree


func _init() -> void:
	var player_controller_script := load("res://scripts/player/PlayerController.gd") as Script

	if player_controller_script == null:
		push_error("Failed to load PlayerController.gd.")
		quit(1)
		return

	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script

	if battle_manager_script == null:
		push_error("Failed to load BattleManager.gd.")
		quit(1)
		return

	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script

	if monster_instance_script == null:
		push_error("Failed to load MonsterInstance.gd.")
		quit(1)
		return

	var battle_ui_scene := load("res://scenes/battle/BattleUI.tscn") as PackedScene

	if battle_ui_scene == null:
		push_error("Failed to load BattleUI.tscn.")
		quit(1)
		return

	var battle_ui_flow_script := load("res://scripts/tests/ValidateBattleUIFlow.gd") as Script

	if battle_ui_flow_script == null:
		push_error("Failed to load ValidateBattleUIFlow.gd.")
		quit(1)
		return

	var move_pp_script := load("res://scripts/tests/ValidateMovePP.gd") as Script

	if move_pp_script == null:
		push_error("Failed to load ValidateMovePP.gd.")
		quit(1)
		return

	var type_effectiveness_script := load("res://scripts/tests/ValidateTypeEffectiveness.gd") as Script

	if type_effectiveness_script == null:
		push_error("Failed to load ValidateTypeEffectiveness.gd.")
		quit(1)
		return

	var experience_reward_script := load("res://scripts/tests/ValidateExperienceReward.gd") as Script

	if experience_reward_script == null:
		push_error("Failed to load ValidateExperienceReward.gd.")
		quit(1)
		return

	var game_flow_script := load("res://scripts/tests/ValidateGameFlow.gd") as Script

	if game_flow_script == null:
		push_error("Failed to load ValidateGameFlow.gd.")
		quit(1)
		return

	var save_load_script := load("res://scripts/tests/ValidateSaveLoad.gd") as Script

	if save_load_script == null:
		push_error("Failed to load ValidateSaveLoad.gd.")
		quit(1)
		return

	var test_save_tools_script := load("res://scripts/tests/TestSaveTools.gd") as Script

	if test_save_tools_script == null:
		push_error("Failed to load TestSaveTools.gd.")
		quit(1)
		return

	var game_manager_load_script := load("res://scripts/tests/ValidateGameManagerLoad.gd") as Script

	if game_manager_load_script == null:
		push_error("Failed to load ValidateGameManagerLoad.gd.")
		quit(1)
		return

	var run_flow_script := load("res://scripts/tests/ValidateRunFlow.gd") as Script

	if run_flow_script == null:
		push_error("Failed to load ValidateRunFlow.gd.")
		quit(1)
		return

	var bag_flow_script := load("res://scripts/tests/ValidateBagFlow.gd") as Script

	if bag_flow_script == null:
		push_error("Failed to load ValidateBagFlow.gd.")
		quit(1)
		return

	var switch_flow_script := load("res://scripts/tests/ValidateSwitchFlow.gd") as Script

	if switch_flow_script == null:
		push_error("Failed to load ValidateSwitchFlow.gd.")
		quit(1)
		return

	var forced_switch_flow_script := load("res://scripts/tests/ValidateForcedSwitchFlow.gd") as Script

	if forced_switch_flow_script == null:
		push_error("Failed to load ValidateForcedSwitchFlow.gd.")
		quit(1)
		return

	var capture_flow_script := load("res://scripts/tests/ValidateCaptureFlow.gd") as Script

	if capture_flow_script == null:
		push_error("Failed to load ValidateCaptureFlow.gd.")
		quit(1)
		return

	var capture_game_flow_script := load("res://scripts/tests/ValidateCaptureGameFlow.gd") as Script

	if capture_game_flow_script == null:
		push_error("Failed to load ValidateCaptureGameFlow.gd.")
		quit(1)
		return

	var level_stats_script := load("res://scripts/tests/ValidateLevelStats.gd") as Script

	if level_stats_script == null:
		push_error("Failed to load ValidateLevelStats.gd.")
		quit(1)
		return

	var move_learning_script := load("res://scripts/tests/ValidateMoveLearning.gd") as Script

	if move_learning_script == null:
		push_error("Failed to load ValidateMoveLearning.gd.")
		quit(1)
		return

	var overworld_menu_script := load("res://scripts/tests/ValidateOverworldMenu.gd") as Script

	if overworld_menu_script == null:
		push_error("Failed to load ValidateOverworldMenu.gd.")
		quit(1)
		return

	var party_capacity_script := load("res://scripts/tests/ValidatePartyCapacity.gd") as Script

	if party_capacity_script == null:
		push_error("Failed to load ValidatePartyCapacity.gd.")
		quit(1)
		return

	var overworld_content_script := load("res://scripts/tests/ValidateOverworldContent.gd") as Script

	if overworld_content_script == null:
		push_error("Failed to load ValidateOverworldContent.gd.")
		quit(1)
		return

	var battle_ui = battle_ui_scene.instantiate()
	get_root().add_child(battle_ui)
	battle_ui.queue_free()

	var monster = load("res://data/monsters/FireMonster.tres")

	if monster == null:
		push_error("Failed to load FireMonster.tres as MonsterData.")
		quit(1)
		return

	var enemy_monster = load("res://data/monsters/WaterMonster.tres")

	if enemy_monster == null:
		push_error("Failed to load WaterMonster.tres as MonsterData.")
		quit(1)
		return

	print("Loaded monster: %s" % monster.monster_name)
	print("Base stats: %s" % monster.get_base_stats())
	print("Level 5 XP: %d" % monster.get_experience_for_level(5))

	var player_instance = monster_instance_script.new()
	player_instance.setup(monster, 5)

	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(enemy_monster, 5)

	var battle_manager = battle_manager_script.new()
	get_root().add_child(battle_manager)
	battle_manager.start_battle(player_instance, enemy_instance)
	battle_manager.run_battle_to_end()
	quit()
