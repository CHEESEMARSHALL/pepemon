extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene
	var grass_data = load("res://data/monsters/GrassSprout.tres")

	if game_root_scene == null or grass_data == null:
		push_error("Failed to load GameRoot.tscn.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	game_root.auto_load_save = false
	game_root.auto_save_after_battle = false
	get_root().add_child(game_root)
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var overworld := scene_root.get_child(0)

	if overworld == null or not overworld.has_method("force_test_encounter"):
		push_error("GameRoot did not load the overworld scene.")
		quit(1)
		return

	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap
	var encounter_cell := Vector2i(9, 8)

	if player == null or tile_map == null:
		push_error("Game flow validation could not find the overworld player or tile map.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(encounter_cell))
	await process_frame
	overworld.call("force_test_encounter", grass_data, 5)
	await process_frame
	await process_frame

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene is BattleUI:
		push_error("Forced encounter did not transition to BattleUI.")
		quit(1)
		return

	var fight_button := active_scene.get_node("%FightButton") as Button
	var move_button := active_scene.get_node("%MoveButton1") as Button

	if fight_button == null or move_button == null:
		push_error("BattleUI command buttons were not found during game-flow validation.")
		quit(1)
		return

	fight_button.emit_signal("pressed")
	await process_frame
	move_button.emit_signal("pressed")
	await create_timer(5.5).timeout

	active_scene = scene_root.get_child(0)

	if active_scene == null or not active_scene.has_method("force_test_encounter"):
		push_error("Finished battle did not return to the overworld scene.")
		quit(1)
		return

	if not active_scene.has_method("get_player_cell") or active_scene.call("get_player_cell") != encounter_cell:
		push_error("Finished battle did not return the player to the encounter cell.")
		quit(1)
		return

	print("Game flow validation passed: overworld -> battle -> overworld.")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	quit()
