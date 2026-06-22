extends SceneTree


func _init() -> void:
	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")

	if battle_manager_script == null or monster_instance_script == null or fire_data == null or water_data == null:
		push_error("Type validation could not load required resources.")
		quit(1)
		return

	var fire_instance = monster_instance_script.new()
	fire_instance.setup(fire_data, 5)

	var water_instance = monster_instance_script.new()
	water_instance.setup(water_data, 5)

	var fire_move = fire_instance.call("get_moves")[0]
	var water_move = water_instance.call("get_moves")[0]
	var battle_manager = battle_manager_script.new()

	var fire_damage: int = battle_manager.calculate_damage(fire_instance, water_instance, fire_move)
	var water_damage: int = battle_manager.calculate_damage(water_instance, fire_instance, water_move)

	if fire_damage != 21:
		push_error("Expected Fire vs Water damage to be resisted to 21, got %d." % fire_damage)
		quit(1)
		return

	if water_damage != 85:
		push_error("Expected Water vs Fire damage to be super effective at 85, got %d." % water_damage)
		battle_manager.free()
		quit(1)
		return

	print("Type effectiveness validation passed: Fire->Water %d, Water->Fire %d" % [fire_damage, water_damage])
	battle_manager.free()
	quit()
