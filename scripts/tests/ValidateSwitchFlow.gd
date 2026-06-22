extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle_ui_scene := load("res://scenes/battle/BattleUI.tscn") as PackedScene
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var water_data = load("res://data/monsters/WaterMonster.tres")
	var grass_data = load("res://data/monsters/GrassSprout.tres")

	if battle_ui_scene == null or monster_instance_script == null or fire_data == null or water_data == null or grass_data == null:
		push_error("Switch validation could not load required resources.")
		quit(1)
		return

	var fire_instance = monster_instance_script.new()
	fire_instance.setup(fire_data, 5)

	var water_instance = monster_instance_script.new()
	water_instance.setup(water_data, 5)

	var enemy_instance = monster_instance_script.new()
	enemy_instance.setup(grass_data, 5)

	var battle_ui := battle_ui_scene.instantiate()
	battle_ui.auto_start_battle = false
	get_root().add_child(battle_ui)
	await process_frame
	battle_ui.start_battle([fire_instance, water_instance], enemy_instance)
	await process_frame

	var monster_button := battle_ui.get_node("%MonsterButton") as Button
	var second_party_button := battle_ui.get_node("%PartyButton2") as Button

	if monster_button == null or second_party_button == null:
		push_error("Switch validation could not find party buttons.")
		quit(1)
		return

	monster_button.emit_signal("pressed")
	await process_frame
	second_party_button.emit_signal("pressed")
	await process_frame

	var battle_manager := battle_ui.get_node("BattleManager") as BattleManager

	if battle_manager == null or battle_manager.get_active_player_index() != 1:
		push_error("Switch validation did not update active player index.")
		quit(1)
		return

	var player_label := battle_ui.get_node("%PlayerNameLabel") as Label

	if player_label == null or not player_label.text.contains("Aquabbit"):
		push_error("Switch validation did not update the player monster label.")
		quit(1)
		return

	print("Switch flow validation passed: active monster is Aquabbit.")
	quit()
