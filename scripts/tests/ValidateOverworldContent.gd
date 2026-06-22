extends SceneTree

var _battle_monster: Resource
var _battle_level := 0
var _pickup_id := ""
var _pickup_item_key := ""
var _pickup_item_count := 0
var _wild_battle_triggered := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_map_data()
	await _validate_scene_content()
	await _validate_trainer_sight_scene()
	await _validate_route_transition_flow()
	await _validate_grass_encounter_flow()
	await _validate_game_manager_trainer_state_flow()
	await _validate_game_manager_pickup_flow()
	print("Overworld content validation passed: authored map, transitions, collisions, signs, NPCs, trainer sight, pickups, and grass encounters.")
	quit()


func _validate_map_data() -> void:
	var route_data = load("res://data/overworld/Route1.tres")

	if route_data == null:
		push_error("Failed to load Route1.tres.")
		quit(1)
		return

	if route_data.map_name != "Pepemon Route 1":
		push_error("Route1.tres has the wrong map name.")
		quit(1)
		return

	if route_data.player_start_cell != Vector2i(8, 8):
		push_error("Route1.tres has the wrong player start cell.")
		quit(1)
		return

	if route_data.get_tile_code(Vector2i(9, 8)) != "G":
		push_error("Route1.tres does not place grass east of the player start.")
		quit(1)
		return

	var route_transition: Dictionary = route_data.get_transition_entry(Vector2i(14, 6))

	if route_transition.is_empty() or str(route_transition.get("target_map_path", "")).is_empty():
		push_error("Route1.tres is missing the authored Route 2 transition.")
		quit(1)
		return

	var route_2 = load(route_transition.get("target_map_path"))

	if route_2 == null or route_2.map_name != "Pepemon Route 2":
		push_error("Route1.tres transition does not load Route 2.")
		quit(1)
		return

	if route_data.encounter_table == null:
		push_error("Route1.tres is missing its route-specific encounter table.")
		quit(1)
		return

	if route_2.encounter_table == null:
		push_error("Route2.tres is missing its route-specific encounter table.")
		quit(1)
		return

	if route_data.encounter_table == route_2.encounter_table:
		push_error("Route1.tres and Route2.tres should not share the same encounter table resource.")
		quit(1)
		return

	var route_2_rng := RandomNumberGenerator.new()
	route_2_rng.seed = 22
	var route_2_encounter: Dictionary = route_2.encounter_table.get_random_encounter(route_2_rng)
	var route_2_monster = route_2_encounter.get("monster", null)

	if route_2_monster == null or route_2_monster.monster_name != "Aquabbit" or int(route_2_encounter.get("level", 0)) != 6:
		push_error("Route2.tres encounter table should produce a level 6 Aquabbit.")
		quit(1)
		return

	if route_data.get_sign_message(Vector2i(7, 8)).is_empty():
		push_error("Route1.tres is missing the route sign message.")
		quit(1)
		return

	if route_data.get_sign_message(Vector2i(5, 6)).is_empty() or route_data.get_sign_message(Vector2i(12, 10)).is_empty():
		push_error("Route1.tres should include multiple authored signs.")
		quit(1)

	for sign_entry in route_data.sign_messages:
		var sign_cell: Vector2i = sign_entry.get("cell", Vector2i(-999, -999))

		if route_data.get_tile_code(sign_cell) != "S":
			push_error("Sign message at %s does not match an authored sign tile." % str(sign_cell))
			quit(1)
			return

	var interactable_entries: Array[Dictionary] = route_data.get_interactable_entries()

	if interactable_entries.size() < 4:
		push_error("Route1.tres should include multiple authored interactables.")
		quit(1)
		return

	var trainer_count := 0
	var pickup_count := 0

	for entry in interactable_entries:
		var interactable_cell: Vector2i = entry.get("cell", Vector2i(-999, -999))

		if str(entry.get("name", "")).is_empty():
			push_error("Route1.tres contains an unnamed interactable.")
			quit(1)
			return

		if str(entry.get("dialogue", "")).is_empty():
			push_error("Route1.tres contains an interactable without dialogue.")
			quit(1)
			return

		if not route_data.is_inside_map(interactable_cell):
			push_error("Route1.tres contains an interactable outside the map: %s." % str(interactable_cell))
			quit(1)
			return

		if route_data.get_tile_code(interactable_cell) == "#":
			push_error("Route1.tres places an interactable on a wall tile: %s." % str(interactable_cell))
			quit(1)
			return

		if int(entry.get("action", 0)) == 1:
			trainer_count += 1

			if entry.get("battle_monster", null) == null or int(entry.get("battle_level", 0)) <= 0:
				push_error("Route1.tres contains a trainer without battle data.")
				quit(1)
				return

			if entry.get("sight_direction", Vector2i.ZERO) == Vector2i.ZERO or int(entry.get("sight_range", 0)) <= 0:
				push_error("Route1.tres contains a trainer without sight data.")
				quit(1)
				return

		if int(entry.get("action", 0)) == 2:
			pickup_count += 1

			if str(entry.get("item_key", "")).is_empty() or int(entry.get("item_count", 0)) <= 0:
				push_error("Route1.tres contains a pickup without item data.")
				quit(1)
				return

	if trainer_count < 2:
		push_error("Route1.tres should include multiple authored trainer battles.")
		quit(1)

	if pickup_count < 2:
		push_error("Route1.tres should include multiple authored pickups.")
		quit(1)


func _validate_scene_content() -> void:
	var overworld := await _instantiate_overworld()
	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap
	var dialogue_panel := overworld.get_node("%DialoguePanel") as PanelContainer
	var dialogue_label := overworld.get_node("%DialogueLabel") as Label

	if player == null or tile_map == null or dialogue_panel == null or dialogue_label == null:
		push_error("Overworld content validation could not find required scene nodes.")
		quit(1)
		return

	player.grass_encounter_chance = 0.0
	var start_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))

	if start_cell != Vector2i(8, 8):
		push_error("Expected player to start on cell (8, 8), got %s." % str(start_cell))
		quit(1)
		return

	if player.encounter_table == null or player.encounter_table != overworld.get("map_data").encounter_table:
		push_error("Overworld did not assign the current map encounter table to the player.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(5, 8)))
	await process_frame

	var before_wall_step := player.global_position
	var blocked_target: Vector2 = player.call("_get_target_position", Vector2i.LEFT)

	if not blocked_target.is_equal_approx(before_wall_step):
		push_error("Authored wall tile returned a movement target.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(8, 8)))
	await process_frame
	var grass_target: Vector2 = player.call("_get_target_position", Vector2i.RIGHT)
	var grass_cell := tile_map.local_to_map(tile_map.to_local(grass_target))

	if grass_cell != Vector2i(9, 8):
		push_error("Authored grass tile did not return a valid movement target.")
		quit(1)
		return

	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("Pepemon Route 1"):
		push_error("Route sign did not show dialogue.")
		quit(1)
		return

	await _close_dialogue(dialogue_panel, player)
	await _validate_blocked_dialogue_interactable(player, dialogue_panel, dialogue_label, tile_map, Vector2i(8, 8), Vector2i.UP, "Scout Mira")
	await _close_dialogue(dialogue_panel, player)
	await _validate_blocked_dialogue_interactable(player, dialogue_panel, dialogue_label, tile_map, Vector2i(6, 9), Vector2i.DOWN, "Keeper Sol")
	await _close_dialogue(dialogue_panel, player)

	overworld.trainer_battle_triggered.connect(_on_trainer_battle_triggered)
	overworld.pickup_collected.connect(_on_pickup_collected)
	await _validate_trainer_interactable(player, tile_map, Vector2i(10, 7), Vector2i.UP, 4)
	await _validate_trainer_interactable(player, tile_map, Vector2i(11, 10), Vector2i.UP, 5)
	var defeated_trainers: Array[String] = ["trainer_rook"]
	overworld.set_defeated_interactables(defeated_trainers)
	await _validate_defeated_trainer_dialogue(player, dialogue_panel, dialogue_label, tile_map, Vector2i(10, 7), Vector2i.UP, "Good match")
	await _close_dialogue(dialogue_panel, player)
	await _validate_pickup_interactable(player, dialogue_panel, dialogue_label, tile_map, Vector2i(5, 3), Vector2i.UP, "route1_potion", "potion", 1, "Found a Potion")
	await _close_dialogue(dialogue_panel, player)
	var collected_pickups: Array[String] = ["route1_capsules"]
	overworld.set_collected_interactables(collected_pickups)
	await _validate_collected_pickup_dialogue(player, dialogue_panel, dialogue_label, tile_map, Vector2i(12, 3), Vector2i.UP, "empty")
	overworld.queue_free()


func _validate_trainer_sight_scene() -> void:
	var overworld := await _instantiate_overworld()
	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap
	var dialogue_panel := overworld.get_node("%DialoguePanel") as PanelContainer
	var dialogue_label := overworld.get_node("%DialogueLabel") as Label

	overworld.trainer_battle_triggered.connect(_on_trainer_battle_triggered)
	player.battle_triggered.connect(_on_wild_battle_triggered)
	player.grass_encounter_chance = 1.0
	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(9, 8)))
	_battle_monster = null
	_battle_level = 0
	_wild_battle_triggered = false
	_release_all_directions()
	Input.action_press("ui_right")
	await create_timer(player.move_time + 0.03).timeout
	Input.action_release("ui_right")
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("training lane"):
		push_error("Trainer sight did not show challenge dialogue.")
		quit(1)
		return

	if _wild_battle_triggered:
		push_error("Grass encounter triggered before trainer sight.")
		quit(1)
		return

	await create_timer(0.25).timeout

	if _battle_monster == null or _battle_level != 4:
		push_error("Trainer sight did not request the configured battle.")
		quit(1)
		return

	var defeated_trainers: Array[String] = ["trainer_rook"]
	overworld.set_defeated_interactables(defeated_trainers)
	_battle_monster = null
	_battle_level = 0
	overworld.call("_on_player_step_finished", Vector2i(10, 8))
	await create_timer(0.25).timeout

	if _battle_monster != null:
		push_error("Defeated trainer sight requested another battle.")
		quit(1)
		return

	overworld.queue_free()


func _validate_route_transition_flow() -> void:
	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene

	if game_root_scene == null:
		push_error("Failed to load GameRoot.tscn for route transition validation.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	game_root.auto_load_save = false
	game_root.auto_save_after_battle = false
	get_root().add_child(game_root)
	await process_frame
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var overworld := scene_root.get_child(0)
	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap
	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(14, 6)))
	overworld.call("_on_player_step_finished", Vector2i(14, 6))
	await process_frame
	await process_frame

	overworld = scene_root.get_child(0)
	player = overworld.find_child("Player", true, false) as PlayerController
	tile_map = overworld.get_node("%GroundTileMap") as TileMap
	var route_2_data = overworld.get("map_data")
	var route_2_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))

	if route_2_data == null or route_2_data.map_name != "Pepemon Route 2" or route_2_cell != Vector2i(1, 6):
		push_error("Route transition did not move the player to Route 2.")
		quit(1)
		return

	if player.encounter_table == null or player.encounter_table != route_2_data.encounter_table:
		push_error("Route transition did not assign Route 2 encounter data to the player.")
		quit(1)
		return

	overworld.call("_on_player_step_finished", Vector2i(1, 6))
	await process_frame
	await process_frame

	overworld = scene_root.get_child(0)
	player = overworld.find_child("Player", true, false) as PlayerController
	tile_map = overworld.get_node("%GroundTileMap") as TileMap
	var route_1_data = overworld.get("map_data")
	var route_1_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))

	if route_1_data == null or route_1_data.map_name != "Pepemon Route 1" or route_1_cell != Vector2i(14, 6):
		push_error("Return transition did not move the player back to Route 1.")
		quit(1)
		return

	if player.encounter_table == null or player.encounter_table != route_1_data.encounter_table:
		push_error("Return transition did not restore Route 1 encounter data to the player.")
		quit(1)
		return

	game_root.queue_free()


func _validate_grass_encounter_flow() -> void:
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

	player.grass_encounter_chance = 1.0
	Input.action_press("ui_right")
	await create_timer(player.move_time + 0.25).timeout
	Input.action_release("ui_right")
	await process_frame
	await process_frame

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene is BattleUI:
		push_error("Walking onto authored grass did not transition to BattleUI.")
		quit(1)
		return

	var battle_manager := active_scene.get_node("BattleManager") as BattleManager

	if battle_manager == null or battle_manager.get("_enemy_instance") == null:
		push_error("Authored grass encounter did not create an enemy monster instance.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	game_root.queue_free()


func _validate_game_manager_trainer_state_flow() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene

	if game_root_scene == null:
		push_error("Failed to load GameRoot.tscn for trainer state validation.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	game_root.auto_load_save = false
	game_root.auto_save_after_battle = false
	get_root().add_child(game_root)
	await process_frame
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var overworld := scene_root.get_child(0)
	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap

	if player == null or tile_map == null:
		push_error("Trainer state validation could not find overworld player.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(10, 8)))
	overworld.call("_on_player_step_finished", Vector2i(10, 8))
	await process_frame
	await create_timer(0.25).timeout

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene is BattleUI:
		push_error("Trainer sight did not transition to BattleUI through GameManager.")
		quit(1)
		return

	game_root.call("_on_battle_finished", true)
	await process_frame
	await process_frame

	var route_state: Dictionary = game_root.get("_route_state")

	if not route_state.get("defeated_trainers", []).has("trainer_rook"):
		push_error("GameManager did not mark the defeated trainer in route state.")
		quit(1)
		return

	overworld = scene_root.get_child(0)
	player = overworld.find_child("Player", true, false) as PlayerController
	tile_map = overworld.get_node("%GroundTileMap") as TileMap
	var dialogue_panel := overworld.get_node("%DialoguePanel") as PanelContainer
	var dialogue_label := overworld.get_node("%DialogueLabel") as Label
	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(10, 7)))
	player.set("_facing_direction", Vector2i.UP)
	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("Good match"):
		push_error("Returned overworld did not apply defeated trainer post-battle dialogue.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	game_root.queue_free()


func _validate_game_manager_pickup_flow() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene

	if game_root_scene == null:
		push_error("Failed to load GameRoot.tscn for pickup validation.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	game_root.auto_load_save = false
	game_root.auto_save_after_battle = false
	get_root().add_child(game_root)
	await process_frame
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var overworld := scene_root.get_child(0)
	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap
	var dialogue_panel := overworld.get_node("%DialoguePanel") as PanelContainer
	var dialogue_label := overworld.get_node("%DialogueLabel") as Label

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(5, 3)))
	player.set("_facing_direction", Vector2i.UP)
	player.interact()
	await process_frame

	var inventory: Dictionary = game_root.get("_inventory")
	var route_state: Dictionary = game_root.get("_route_state")

	if int(inventory.get("potion", 0)) < 4:
		push_error("GameManager did not add the picked-up Potion to inventory.")
		quit(1)
		return

	if not route_state.get("collected_pickups", []).has("route1_potion"):
		push_error("GameManager did not mark the pickup as collected.")
		quit(1)
		return

	if not dialogue_panel.visible or not dialogue_label.text.contains("Found a Potion"):
		push_error("Pickup did not show first-collection dialogue.")
		quit(1)
		return

	await _close_dialogue(dialogue_panel, player)
	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("empty"):
		push_error("Collected pickup did not show empty dialogue.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	game_root.queue_free()


func _instantiate_overworld() -> Node:
	var overworld_scene := load("res://scenes/overworld/Overworld.tscn") as PackedScene

	if overworld_scene == null:
		push_error("Failed to load Overworld.tscn.")
		quit(1)
		return null

	var overworld := overworld_scene.instantiate()
	get_root().add_child(overworld)
	await process_frame
	await process_frame
	return overworld


func _validate_blocked_dialogue_interactable(
	player: PlayerController,
	dialogue_panel: PanelContainer,
	dialogue_label: Label,
	tile_map: TileMap,
	start_cell: Vector2i,
	direction: Vector2i,
	expected_text: String
) -> void:
	var target_cell := start_cell + direction
	var target_tile_data := tile_map.get_cell_tile_data(0, target_cell)

	if target_tile_data == null or not bool(target_tile_data.get_custom_data("blocked")):
		push_error("%s is not authored as a blocked tile at %s." % [expected_text, str(target_cell)])
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	await process_frame
	var position_before_step := player.global_position
	var target_position: Vector2 = player.call("_get_target_position", direction)

	if not target_position.is_equal_approx(position_before_step):
		push_error("%s did not block movement." % expected_text)
		quit(1)
		return

	player.set("_facing_direction", direction)
	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains(expected_text):
		push_error("%s did not show dialogue." % expected_text)
		quit(1)


func _validate_trainer_interactable(player: PlayerController, tile_map: TileMap, start_cell: Vector2i, direction: Vector2i, expected_level: int) -> void:
	_battle_monster = null
	_battle_level = 0
	player.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	await process_frame
	var position_before_step := player.global_position
	var target_position: Vector2 = player.call("_get_target_position", direction)

	if not target_position.is_equal_approx(position_before_step):
		push_error("Trainer interactable did not block movement.")
		quit(1)
		return

	player.set("_facing_direction", direction)
	player.interact()
	await process_frame

	if _battle_monster == null or _battle_level != expected_level:
		push_error("Trainer interaction did not request the configured level %d battle." % expected_level)
		quit(1)


func _validate_defeated_trainer_dialogue(
	player: PlayerController,
	dialogue_panel: PanelContainer,
	dialogue_label: Label,
	tile_map: TileMap,
	start_cell: Vector2i,
	direction: Vector2i,
	expected_text: String
) -> void:
	_battle_monster = null
	_battle_level = 0
	player.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	await process_frame
	player.set("_facing_direction", direction)
	player.interact()
	await process_frame

	if _battle_monster != null:
		push_error("Defeated trainer requested another battle.")
		quit(1)
		return

	if not dialogue_panel.visible or not dialogue_label.text.contains(expected_text):
		push_error("Defeated trainer did not show post-battle dialogue.")
		quit(1)


func _validate_pickup_interactable(
	player: PlayerController,
	dialogue_panel: PanelContainer,
	dialogue_label: Label,
	tile_map: TileMap,
	start_cell: Vector2i,
	direction: Vector2i,
	expected_id: String,
	expected_item_key: String,
	expected_count: int,
	expected_text: String
) -> void:
	_pickup_id = ""
	_pickup_item_key = ""
	_pickup_item_count = 0
	player.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	await process_frame
	player.set("_facing_direction", direction)
	player.interact()
	await process_frame

	if _pickup_id != expected_id or _pickup_item_key != expected_item_key or _pickup_item_count != expected_count:
		push_error("Pickup did not emit the configured item collection.")
		quit(1)
		return

	if not dialogue_panel.visible or not dialogue_label.text.contains(expected_text):
		push_error("Pickup did not show collection dialogue.")
		quit(1)


func _validate_collected_pickup_dialogue(
	player: PlayerController,
	dialogue_panel: PanelContainer,
	dialogue_label: Label,
	tile_map: TileMap,
	start_cell: Vector2i,
	direction: Vector2i,
	expected_text: String
) -> void:
	_pickup_id = ""
	player.global_position = tile_map.to_global(tile_map.map_to_local(start_cell))
	await process_frame
	player.set("_facing_direction", direction)
	player.interact()
	await process_frame

	if not _pickup_id.is_empty():
		push_error("Collected pickup emitted another collection.")
		quit(1)
		return

	if not dialogue_panel.visible or not dialogue_label.text.contains(expected_text):
		push_error("Collected pickup did not show empty dialogue.")
		quit(1)


func _step_player(direction: Vector2i, move_time: float) -> void:
	_release_all_directions()
	_press_direction(direction)
	await process_frame
	await create_timer(move_time + 0.05).timeout
	_release_direction(direction)
	_release_all_directions()
	await process_frame


func _press_direction(direction: Vector2i) -> void:
	Input.action_press(_get_direction_action(direction))


func _release_direction(direction: Vector2i) -> void:
	Input.action_release(_get_direction_action(direction))


func _release_all_directions() -> void:
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")


func _get_direction_action(direction: Vector2i) -> String:
	if direction == Vector2i.LEFT:
		return "ui_left"
	if direction == Vector2i.RIGHT:
		return "ui_right"
	if direction == Vector2i.UP:
		return "ui_up"
	return "ui_down"


func _close_dialogue(dialogue_panel: PanelContainer, player: PlayerController) -> void:
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	Input.parse_input_event(accept_event)
	await process_frame
	accept_event.pressed = false
	Input.parse_input_event(accept_event)
	await process_frame

	if dialogue_panel.visible or not player.movement_enabled:
		push_error("Closing dialogue did not restore movement.")
		quit(1)


func _on_trainer_battle_triggered(_trainer_id: String, enemy_monster: Resource, enemy_level: int) -> void:
	_battle_monster = enemy_monster
	_battle_level = enemy_level


func _on_pickup_collected(pickup_id: String, item_key: String, item_count: int, _item_name: String) -> void:
	_pickup_id = pickup_id
	_pickup_item_key = item_key
	_pickup_item_count = item_count


func _on_wild_battle_triggered(_enemy_monster: Resource, _enemy_level: int) -> void:
	_wild_battle_triggered = true
