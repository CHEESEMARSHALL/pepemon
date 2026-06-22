extends SceneTree


func _init() -> void:
	var battle_manager_script := load("res://scripts/battle/BattleManager.gd") as Script
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")
	var grass_data = load("res://data/monsters/GrassSprout.tres")
	var capture_item = load("res://data/items/CaptureCapsule.tres")

	if battle_manager_script == null or monster_instance_script == null or fire_data == null or water_data == null or grass_data == null or capture_item == null:
		push_error("Party capacity validation could not load required resources.")
		quit(1)
		return

	var party_five := _build_party(monster_instance_script, fire_data, water_data, 5)
	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(grass_data, 5)

	var battle_manager = battle_manager_script.new()
	get_root().add_child(battle_manager)
	battle_manager.start_battle(party_five, enemy_instance)

	if not battle_manager.try_capture(capture_item):
		push_error("Capture should be allowed when party has 5 monsters.")
		quit(1)
		return

	if battle_manager.get_player_party().size() != 6 or battle_manager.state != battle_manager.BattleState.CAPTURED:
		push_error("Capture did not fill the sixth party slot.")
		quit(1)
		return

	battle_manager.queue_free()

	var party_six := _build_party(monster_instance_script, fire_data, water_data, 6)
	var full_party_enemy = monster_instance_script.new()
	full_party_enemy.setup(grass_data, 5)

	var full_party_battle = battle_manager_script.new()
	get_root().add_child(full_party_battle)
	full_party_battle.start_battle(party_six, full_party_enemy)

	if full_party_battle.try_capture(capture_item):
		push_error("Capture should fail when party already has 6 monsters.")
		quit(1)
		return

	if full_party_battle.get_player_party().size() != 6:
		push_error("Full party capture should not change party size.")
		quit(1)
		return

	print("Party capacity validation passed: capture fills slot 6 and blocks slot 7.")
	quit()


func _build_party(monster_instance_script: Script, first_data: Resource, second_data: Resource, size: int) -> Array[Resource]:
	var party: Array[Resource] = []

	for index in size:
		var instance = monster_instance_script.new()
		instance.setup(first_data if index % 2 == 0 else second_data, 5)
		party.append(instance)

	return party
