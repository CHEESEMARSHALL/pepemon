extends SceneTree


func _init() -> void:
	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var player_data = load("res://data/monsters/FireMonster.tres")
	var enemy_data = load("res://data/monsters/WaterMonster.tres")

	if battle_manager_script == null or monster_instance_script == null or player_data == null or enemy_data == null:
		push_error("Move PP validation could not load required resources.")
		quit(1)
		return

	var player_instance = monster_instance_script.new()
	player_instance.setup(player_data, 5)

	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(enemy_data, 5)

	var starting_pp := int(player_instance.call("get_move_pp", 0))
	var battle_manager = battle_manager_script.new()
	get_root().add_child(battle_manager)
	battle_manager.start_battle(player_instance, enemy_instance)
	battle_manager.use_player_move(0)

	var ending_pp := int(player_instance.call("get_move_pp", 0))

	if starting_pp != 25 or ending_pp != 24:
		push_error("Expected Ember PP to go from 25 to 24, got %d to %d." % [starting_pp, ending_pp])
		quit(1)
		return

	print("Move PP validation passed: %d -> %d" % [starting_pp, ending_pp])
	quit()
