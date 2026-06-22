extends SceneTree


func _init() -> void:
	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var grass_data = load("res://data/monsters/GrassSprout.tres")

	if battle_manager_script == null or monster_instance_script == null or fire_data == null or grass_data == null:
		push_error("Experience validation could not load required resources.")
		quit(1)
		return

	var player_instance = monster_instance_script.new()
	player_instance.setup(fire_data, 3)

	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(grass_data, 5)

	var starting_level := int(player_instance.get("level"))
	var starting_experience := int(player_instance.get("experience"))
	var battle_manager = battle_manager_script.new()
	get_root().add_child(battle_manager)
	battle_manager.start_battle(player_instance, enemy_instance)
	battle_manager.use_player_move(0)

	var ending_experience := int(player_instance.get("experience"))
	var ending_level := int(player_instance.get("level"))

	if battle_manager.state != battle_manager.BattleState.WIN:
		push_error("Expected player to win the XP validation battle.")
		battle_manager.free()
		quit(1)
		return

	if ending_experience <= starting_experience:
		push_error("Expected player XP to increase.")
		battle_manager.free()
		quit(1)
		return

	if ending_level <= starting_level:
		push_error("Expected player to level up from XP reward.")
		battle_manager.free()
		quit(1)
		return

	print("Experience validation passed: XP %d -> %d, level %d -> %d" % [
		starting_experience,
		ending_experience,
		starting_level,
		ending_level,
	])
	battle_manager.free()
	quit()
