extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene

	if game_root_scene == null:
		push_error("Failed to load GameRoot.tscn.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	get_root().add_child(game_root)
	await process_frame
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var overworld := scene_root.get_child(0)
	var player := overworld.find_child("Player", true, false) as PlayerController

	if overworld == null or player == null:
		push_error("Grass encounter validation could not find overworld player.")
		quit(1)
		return

	var tile_map := player.get_node_or_null(player.tile_map_path) as TileMap

	if tile_map == null:
		push_error("Player is not wired to the overworld TileMap.")
		quit(1)
		return

	player.grass_encounter_chance = 1.0
	Input.action_press("ui_right")
	await create_timer(player.move_time + 0.25).timeout
	Input.action_release("ui_right")
	await process_frame
	await process_frame

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene is BattleUI:
		push_error("Walking onto grass did not transition to BattleUI.")
		quit(1)
		return

	var battle_manager := active_scene.get_node("BattleManager") as BattleManager

	if battle_manager == null or battle_manager.get("_enemy_instance") == null:
		push_error("Grass encounter did not create an enemy monster instance.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	print("Grass encounter validation passed: walking onto TileMap grass started battle.")
	quit()
