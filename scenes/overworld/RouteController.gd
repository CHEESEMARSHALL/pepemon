extends Node2D

signal battle_triggered(enemy_monster: Resource, enemy_level: int)
signal trainer_battle_triggered(trainer_id: String, enemy_monster: Resource, enemy_level: int)
signal pickup_collected(pickup_id: String, item_key: String, item_count: int, item_name: String)
signal route_transition_requested(target_map: Resource, target_start_cell: Vector2i, target_scene: PackedScene, target_spawn_id: String)

@export var map_data: Resource
@export var authored_map_data: Resource
@export var use_authored_tile_map := true
@export var interactable_scene: PackedScene
@export var route_tile_sheet: Texture2D
@export var player_start_cell_override := Vector2i(-999, -999)
@export var player_start_spawn_id_override := ""

const CELL_SIZE := Vector2i(32, 32)
const SOURCE_ID := 0
const GROUND_LAYER := 0
const OVERLAY_LAYER := 1
const ROUTE_TILE_SHEET_PATH := "res://assets/tiles/route1/route1_tiles.png"
const DIRT_TILE := Vector2i(0, 0)
const GRASS_TILE := Vector2i(1, 0)
const WALL_TILE := Vector2i(2, 0)
const SIGN_TILE := Vector2i(3, 0)
const NPC_TILE := Vector2i(4, 0)
const TREE_TILE := Vector2i(5, 0)
const HOUSE_TILE := Vector2i(6, 0)
const COTTAGE_ROOF_LEFT_TILE := Vector2i(7, 0)
const COTTAGE_ROOF_MIDDLE_TILE := Vector2i(8, 0)
const COTTAGE_ROOF_RIGHT_TILE := Vector2i(9, 0)
const COTTAGE_WALL_LEFT_TILE := Vector2i(10, 0)
const COTTAGE_DOOR_TILE := Vector2i(11, 0)
const COTTAGE_WALL_RIGHT_TILE := Vector2i(12, 0)
const TERRAIN_DATA_KEY := "terrain"
const BLOCKED_DATA_KEY := "blocked"
const INTERACTION_TEXT_DATA_KEY := "interaction_text"
const TERRAIN_DIRT := "Dirt"
const TERRAIN_GRASS := "Grass"
const TERRAIN_WALL := "Wall"
const TERRAIN_SIGN := "Sign"
const TERRAIN_NPC := "NPC"
const TERRAIN_TREE := "Tree"
const TERRAIN_HOUSE := "House"
const MARKER_SIGN := 0
const MARKER_INSPECT := 1
const MARKER_TRANSITION := 2

@onready var _player := %Player as PlayerController
@onready var _ground_tile_map = _get_tile_layer_node("GroundTileMap", "Ground")
@onready var _overlay_tile_layer = _get_tile_layer_node("Objects", "")
@onready var _hint_label := %HintLabel as Label
@onready var _debug_label := %DebugLabel as Label
@onready var _interaction_prompt := %InteractionPrompt as PanelContainer
@onready var _interaction_prompt_label := %InteractionPromptLabel as Label
@onready var _dialogue_panel := %DialoguePanel as PanelContainer
@onready var _dialogue_label := %DialogueLabel as Label
@onready var _interactables := %Interactables as Node2D
@onready var _content_markers := get_node_or_null("%ContentMarkers") as Node2D
@onready var _spawn_points := get_node_or_null("%SpawnPoints") as Node2D
@onready var _encounter_zones := get_node_or_null("%EncounterZones") as Node2D

var _interactables_by_cell: Dictionary = {}
var _sign_messages_by_cell: Dictionary = {}
var _inspect_messages_by_cell: Dictionary = {}
var _transitions_by_cell: Dictionary = {}
var _spawn_points_by_id: Dictionary = {}
var _spawn_facing_by_id: Dictionary = {}
var _encounter_zone_configs_by_cell: Dictionary = {}
var _authored_overlay_atlas_by_cell: Dictionary = {}
var _dynamic_overlay_cells: Dictionary = {}
var _defeated_interactable_ids: Array[String] = []
var _collected_interactable_ids: Array[String] = []
var _active_sight_trainer_id := ""


func _ready() -> void:
	_setup_map()
	_setup_scene_content_markers()
	_spawn_interactables_from_map_data_if_needed()
	_setup_interactables()
	_player.interaction_requested.connect(_on_player_interaction_requested)
	_player.step_finished.connect(_on_player_step_finished)
	_player.facing_changed.connect(_on_player_facing_changed)
	_dialogue_panel.visible = false
	_update_debug_hud()
	_update_interaction_prompt()


func _input(event: InputEvent) -> void:
	if _dialogue_panel.visible and event.is_action_pressed("ui_accept"):
		close_dialogue()
		get_viewport().set_input_as_handled()


func force_test_encounter(enemy_monster: Resource = null, enemy_level: int = 5) -> void:
	if enemy_monster != null:
		_player.battle_triggered.emit(enemy_monster, enemy_level)
	else:
		_player.trigger_battle()


func get_player_cell() -> Vector2i:
	if _ground_tile_map == null or _player == null:
		return Vector2i.ZERO

	return _world_to_map(_player.global_position)


func _setup_map() -> void:
	if _ground_tile_map == null:
		push_error("Overworld requires a GroundTileMap TileMap or Ground TileMapLayer.")
		return

	if _get_tile_set(_ground_tile_map) == null:
		_set_tile_set(_ground_tile_map, _create_route_tile_set())

	if _overlay_tile_layer != null and _get_tile_set(_overlay_tile_layer) == null:
		_set_tile_set(_overlay_tile_layer, _get_tile_set(_ground_tile_map))

	_ensure_tile_map_layers()
	_authored_overlay_atlas_by_cell.clear()
	_dynamic_overlay_cells.clear()

	if map_data == null:
		push_error("Overworld requires map_data.")
		return

	if _hint_label != null:
		_hint_label.text = map_data.map_name

	if _uses_authored_tile_map():
		_cache_authored_overlay_tiles()
	else:
		_paint_tile_map_from_map_data()

	_setup_scene_spawn_points()
	_setup_scene_encounter_zones()

	var start_cell := _get_player_start_cell()
	_player.global_position = _map_to_world(start_cell)
	_player.set_facing_direction(_get_player_start_facing_direction())
	_player.encounter_table = map_data.encounter_table
	_player.set_encounter_zone_configs(_encounter_zone_configs_by_cell)


func _get_player_start_cell() -> Vector2i:
	var start_spawn_id := player_start_spawn_id_override.strip_edges()

	if not start_spawn_id.is_empty() and _spawn_points_by_id.has(start_spawn_id):
		return _spawn_points_by_id[start_spawn_id]

	if player_start_cell_override != Vector2i(-999, -999):
		return player_start_cell_override

	if _spawn_points_by_id.has("default"):
		return _spawn_points_by_id["default"]

	return map_data.player_start_cell


func _get_player_start_facing_direction() -> Vector2i:
	var start_spawn_id := player_start_spawn_id_override.strip_edges()

	if not start_spawn_id.is_empty() and _spawn_facing_by_id.has(start_spawn_id):
		return _spawn_facing_by_id[start_spawn_id]

	if player_start_cell_override == Vector2i(-999, -999) and _spawn_facing_by_id.has("default"):
		return _spawn_facing_by_id["default"]

	return _player.get_facing_direction()


func _uses_authored_tile_map() -> bool:
	if not use_authored_tile_map or authored_map_data == null or map_data == null:
		return false

	if map_data == authored_map_data:
		return true

	return not map_data.resource_path.is_empty() and map_data.resource_path == authored_map_data.resource_path


func _paint_tile_map_from_map_data() -> void:
	_clear_tile_layer(_ground_tile_map, GROUND_LAYER)
	_clear_tile_layer(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER)

	var uses_overlay_rows := false

	if map_data.has_method("has_overlay_rows"):
		uses_overlay_rows = bool(map_data.has_overlay_rows())

	for y in range(map_data.get_height()):
		for x in range(map_data.get_width()):
			var cell := Vector2i(x, y)
			var ground_tile := _get_ground_tile_atlas_coords(map_data.get_tile_code(cell)) if uses_overlay_rows else _get_tile_atlas_coords(map_data.get_tile_code(cell))
			_set_cell(_ground_tile_map, GROUND_LAYER, cell, ground_tile)

			if uses_overlay_rows and map_data.has_method("get_overlay_tile_code"):
				var overlay_code := str(map_data.get_overlay_tile_code(cell))

				if not overlay_code.is_empty():
					var overlay_atlas_coords := _get_tile_atlas_coords(overlay_code)
					_authored_overlay_atlas_by_cell[cell] = overlay_atlas_coords
					_set_cell(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell, overlay_atlas_coords)


func _cache_authored_overlay_tiles() -> void:
	var overlay_layer = _overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map
	for cell in _get_used_cells(overlay_layer, OVERLAY_LAYER):
		var source_id := _get_cell_source_id(overlay_layer, OVERLAY_LAYER, cell)

		if source_id < 0:
			continue

		_authored_overlay_atlas_by_cell[cell] = _get_cell_atlas_coords(overlay_layer, OVERLAY_LAYER, cell)


func _get_tile_atlas_coords(tile_code: String) -> Vector2i:
	match tile_code:
		"#":
			return WALL_TILE
		"G":
			return GRASS_TILE
		"S":
			return SIGN_TILE
		"T":
			return TREE_TILE
		"H":
			return HOUSE_TILE
		_:
			return DIRT_TILE


func _get_ground_tile_atlas_coords(tile_code: String) -> Vector2i:
	match tile_code:
		"#":
			return WALL_TILE
		"G":
			return GRASS_TILE
		_:
			return DIRT_TILE


func _ensure_tile_map_layers() -> void:
	if not _ground_tile_map is TileMap:
		return

	while _ground_tile_map.get_layers_count() <= OVERLAY_LAYER:
		_ground_tile_map.add_layer(_ground_tile_map.get_layers_count())

	_ground_tile_map.set_layer_name(GROUND_LAYER, "Ground")
	_ground_tile_map.set_layer_name(OVERLAY_LAYER, "Objects")
	_ground_tile_map.set_layer_z_index(GROUND_LAYER, 0)
	_ground_tile_map.set_layer_z_index(OVERLAY_LAYER, 1)


func _create_route_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = CELL_SIZE
	tile_set.add_custom_data_layer(0)
	tile_set.set_custom_data_layer_name(0, TERRAIN_DATA_KEY)
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_custom_data_layer(1)
	tile_set.set_custom_data_layer_name(1, BLOCKED_DATA_KEY)
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)
	tile_set.add_custom_data_layer(2)
	tile_set.set_custom_data_layer_name(2, INTERACTION_TEXT_DATA_KEY)
	tile_set.set_custom_data_layer_type(2, TYPE_STRING)

	var texture := _get_route_tile_texture()
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = CELL_SIZE
	source.create_tile(DIRT_TILE)
	source.create_tile(GRASS_TILE)
	source.create_tile(WALL_TILE)
	source.create_tile(SIGN_TILE)
	source.create_tile(NPC_TILE)
	source.create_tile(TREE_TILE)
	source.create_tile(HOUSE_TILE)
	source.create_tile(COTTAGE_ROOF_LEFT_TILE)
	source.create_tile(COTTAGE_ROOF_MIDDLE_TILE)
	source.create_tile(COTTAGE_ROOF_RIGHT_TILE)
	source.create_tile(COTTAGE_WALL_LEFT_TILE)
	source.create_tile(COTTAGE_DOOR_TILE)
	source.create_tile(COTTAGE_WALL_RIGHT_TILE)

	tile_set.add_source(source, SOURCE_ID)
	source.get_tile_data(DIRT_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_DIRT)
	source.get_tile_data(DIRT_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, false)
	source.get_tile_data(GRASS_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_GRASS)
	source.get_tile_data(GRASS_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, false)
	source.get_tile_data(WALL_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_WALL)
	source.get_tile_data(WALL_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	source.get_tile_data(SIGN_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_SIGN)
	source.get_tile_data(SIGN_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	source.get_tile_data(NPC_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_NPC)
	source.get_tile_data(NPC_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	source.get_tile_data(TREE_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_TREE)
	source.get_tile_data(TREE_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	source.get_tile_data(HOUSE_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_HOUSE)
	source.get_tile_data(HOUSE_TILE, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	for cottage_tile in [
		COTTAGE_ROOF_LEFT_TILE,
		COTTAGE_ROOF_MIDDLE_TILE,
		COTTAGE_ROOF_RIGHT_TILE,
		COTTAGE_WALL_LEFT_TILE,
		COTTAGE_DOOR_TILE,
		COTTAGE_WALL_RIGHT_TILE,
	]:
		source.get_tile_data(cottage_tile, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_HOUSE)
		source.get_tile_data(cottage_tile, 0).set_custom_data(BLOCKED_DATA_KEY, true)
	return tile_set


func _get_route_tile_texture() -> Texture2D:
	if route_tile_sheet != null and route_tile_sheet.get_width() >= CELL_SIZE.x * 13:
		return route_tile_sheet

	if ResourceLoader.exists(ROUTE_TILE_SHEET_PATH):
		var loaded_texture := load(ROUTE_TILE_SHEET_PATH) as Texture2D

		if loaded_texture != null and loaded_texture.get_width() >= CELL_SIZE.x * 13:
			return loaded_texture

	var image := Image.create(CELL_SIZE.x * 13, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(Vector2i.ZERO, CELL_SIZE), Color(0.45, 0.32, 0.18))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x, 0), CELL_SIZE), Color(0.18, 0.62, 0.22))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 2, 0), CELL_SIZE), Color(0.18, 0.18, 0.2))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 3, 0), CELL_SIZE), Color(0.78, 0.68, 0.28))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 4, 0), CELL_SIZE), Color(0.24, 0.36, 0.86))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 5, 0), CELL_SIZE), Color(0.08, 0.38, 0.14))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 6, 0), CELL_SIZE), Color(0.58, 0.2, 0.16))
	for cottage_index in range(7, 13):
		image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * cottage_index, 0), CELL_SIZE), Color(0.58, 0.2, 0.16))
	return ImageTexture.create_from_image(image)


func _setup_interactables() -> void:
	_interactables_by_cell.clear()

	if _interactables == null:
		return

	for child in _interactables.get_children():
		if not child.has_method("place_on_tile_map") or not child.has_method("get_interaction_text"):
			continue

		if child.has_method("sync_grid_cell_from_tile_map") and child.owner != null:
			child.sync_grid_cell_from_tile_map(_ground_tile_map)

		child.place_on_tile_map(_ground_tile_map)
		_interactables_by_cell[child.grid_cell] = child

		if child.blocks_movement:
			_set_dynamic_overlay_tile(child.grid_cell, NPC_TILE)


func _set_dynamic_overlay_tile(cell: Vector2i, atlas_coords: Vector2i) -> void:
	if _ground_tile_map == null:
		return

	_dynamic_overlay_cells[cell] = atlas_coords
	_set_cell(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell, atlas_coords)


func _clear_dynamic_overlay_tile(cell: Vector2i) -> void:
	if _ground_tile_map == null:
		return

	_dynamic_overlay_cells.erase(cell)

	if _authored_overlay_atlas_by_cell.has(cell):
		_set_cell(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell, _authored_overlay_atlas_by_cell[cell])
		return

	_erase_cell(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell)


func _setup_scene_content_markers() -> void:
	_sign_messages_by_cell.clear()
	_inspect_messages_by_cell.clear()
	_transitions_by_cell.clear()

	if _content_markers == null:
		return

	for marker in _content_markers.get_children():
		if not marker.has_method("sync_grid_cell_from_tile_map"):
			continue

		marker.sync_grid_cell_from_tile_map(_ground_tile_map)

		match int(marker.marker_type):
			MARKER_SIGN:
				_sign_messages_by_cell[marker.grid_cell] = marker.to_sign_entry()
			MARKER_INSPECT:
				_inspect_messages_by_cell[marker.grid_cell] = marker.to_inspect_entry()
			MARKER_TRANSITION:
				_transitions_by_cell[marker.grid_cell] = marker.to_transition_entry()


func _setup_scene_spawn_points() -> void:
	_spawn_points_by_id.clear()
	_spawn_facing_by_id.clear()

	if _spawn_points == null:
		return

	for spawn_point in _spawn_points.get_children():
		if not spawn_point.has_method("sync_grid_cell_from_tile_map"):
			continue

		spawn_point.sync_grid_cell_from_tile_map(_ground_tile_map)
		var spawn_id := str(spawn_point.get("spawn_id"))
		_spawn_points_by_id[spawn_id] = spawn_point.get("grid_cell")
		_spawn_facing_by_id[spawn_id] = spawn_point.get("facing_direction")


func _setup_scene_encounter_zones() -> void:
	_encounter_zone_configs_by_cell.clear()

	if _encounter_zones == null:
		return

	for encounter_zone in _encounter_zones.get_children():
		if not encounter_zone.has_method("sync_grid_cell_from_tile_map") or not encounter_zone.has_method("get_zone_cells"):
			continue

		encounter_zone.sync_grid_cell_from_tile_map(_ground_tile_map)
		var encounter_config: Dictionary = encounter_zone.to_encounter_config(map_data.encounter_table)

		for cell in encounter_zone.get_zone_cells():
			if _has_any_tile_data(cell):
				_encounter_zone_configs_by_cell[cell] = encounter_config


func _spawn_interactables_from_map_data_if_needed() -> void:
	if _interactables == null or map_data == null or interactable_scene == null:
		return

	if _has_authored_interactables():
		return

	for child in _interactables.get_children():
		child.queue_free()

	for entry in map_data.get_interactable_entries():
		if not entry is Dictionary:
			continue

		var interactable := interactable_scene.instantiate()
		interactable.name = str(entry.get("name", "Interactable"))
		interactable.interactable_id = str(entry.get("id", interactable.name))
		interactable.grid_cell = entry.get("cell", Vector2i.ZERO)
		interactable.dialogue_text = str(entry.get("dialogue", ""))
		interactable.defeated_dialogue_text = str(entry.get("defeated_dialogue", ""))
		interactable.collected_dialogue_text = str(entry.get("collected_dialogue", interactable.collected_dialogue_text))
		interactable.blocks_movement = bool(entry.get("blocks_movement", true))
		interactable.interaction_action = int(entry.get("action", 0))
		interactable.battle_monster_data = entry.get("battle_monster", null)
		interactable.battle_monster_level = int(entry.get("battle_level", 5))
		interactable.sight_direction = entry.get("sight_direction", Vector2i.ZERO)
		interactable.sight_range = int(entry.get("sight_range", 0))
		interactable.challenge_dialogue_text = str(entry.get("challenge_dialogue", interactable.dialogue_text))
		interactable.pickup_item_key = str(entry.get("item_key", ""))
		interactable.pickup_item_name = str(entry.get("item_name", ""))
		interactable.pickup_count = int(entry.get("item_count", 1))
		interactable.is_defeated = _defeated_interactable_ids.has(interactable.interactable_id)
		interactable.is_collected = _collected_interactable_ids.has(interactable.interactable_id)
		_interactables.add_child(interactable)
		interactable.refresh_visual()


func _has_authored_interactables() -> bool:
	if _interactables == null:
		return false

	for child in _interactables.get_children():
		if child.has_method("place_on_tile_map") and child.has_method("get_interaction_text"):
			return true

	return false


func _on_player_interaction_requested(cell: Vector2i) -> void:
	_hide_interaction_prompt()

	if _interactables_by_cell.has(cell):
		var interactable = _interactables_by_cell[cell]

		if interactable != null:
			_handle_interactable(interactable)

		return

	var tile_data := _get_cell_tile_data_for_interaction(cell)

	if tile_data == null:
		return

	var message := _get_sign_message(cell)

	if message.is_empty():
		message = _get_inspect_message(cell)

	if message.is_empty():
		message = str(tile_data.get_custom_data(INTERACTION_TEXT_DATA_KEY))

	if message.is_empty():
		return

	_show_dialogue(message)


func _on_player_step_finished(cell: Vector2i) -> void:
	_update_debug_hud()

	if not _active_sight_trainer_id.is_empty() or _dialogue_panel.visible:
		return

	var trainer := _get_sighting_trainer(cell)

	if trainer == null:
		if _check_route_transition(cell):
			_hide_interaction_prompt()
			return

		_update_interaction_prompt()
		return

	_hide_interaction_prompt()
	_trigger_trainer_sight(trainer)


func _check_route_transition(cell: Vector2i) -> bool:
	var transition: Dictionary = _get_transition_entry(cell)

	if transition.is_empty():
		return false

	var target_map = transition.get("target_map", null)
	var target_scene: PackedScene = transition.get("target_scene", null) as PackedScene

	if target_map == null:
		var target_map_path := str(transition.get("target_map_path", ""))

		if not target_map_path.is_empty():
			target_map = load(target_map_path)

	if target_map == null:
		return false

	if target_scene == null:
		var target_scene_path := str(transition.get("target_scene_path", ""))

		if not target_scene_path.is_empty():
			target_scene = load(target_scene_path) as PackedScene

	_player.movement_enabled = false
	route_transition_requested.emit(target_map, transition.get("target_start_cell", Vector2i.ZERO), target_scene, str(transition.get("target_spawn_id", "")))
	return true


func _get_sighting_trainer(player_cell: Vector2i) -> Node:
	for interactable in _interactables_by_cell.values():
		if interactable == null:
			continue

		if int(interactable.get("interaction_action")) != 1 or bool(interactable.get("is_defeated")):
			continue

		var sight_direction: Vector2i = interactable.get("sight_direction")
		var sight_range := int(interactable.get("sight_range"))

		if sight_direction == Vector2i.ZERO or sight_range <= 0:
			continue

		for distance in range(1, sight_range + 1):
			var sight_cell: Vector2i = interactable.grid_cell + sight_direction * distance

			if _is_sight_blocked(sight_cell):
				break

			if sight_cell == player_cell:
				return interactable

	return null


func _is_sight_blocked(cell: Vector2i) -> bool:
	if not _has_any_tile_data(cell):
		return true

	if _is_blocked_cell(cell):
		return true

	return _interactables_by_cell.has(cell)


func _trigger_trainer_sight(interactable: Node) -> void:
	_active_sight_trainer_id = str(interactable.get("interactable_id"))
	_player.movement_enabled = false

	if interactable.has_method("show_alert_marker"):
		interactable.call("show_alert_marker")

	var challenge_text := str(interactable.get("challenge_dialogue_text"))

	if challenge_text.is_empty():
		challenge_text = str(interactable.call("get_interaction_text"))

	_show_dialogue(challenge_text)
	call_deferred("_finish_trainer_sight", interactable)


func _finish_trainer_sight(interactable: Node) -> void:
	await get_tree().create_timer(0.2).timeout
	close_dialogue()
	_active_sight_trainer_id = ""

	if interactable != null and not bool(interactable.get("is_defeated")):
		if interactable.has_method("hide_alert_marker"):
			interactable.call("hide_alert_marker")

		trainer_battle_triggered.emit(str(interactable.get("interactable_id")), interactable.battle_monster_data, int(interactable.battle_monster_level))


func _handle_interactable(interactable: Node) -> void:
	var action := 0

	if interactable.has_method("get_interaction_action"):
		action = int(interactable.get_interaction_action())

	if action == 1:
		if bool(interactable.get("is_defeated")):
			if interactable.has_method("get_interaction_text") and not interactable.get_interaction_text().is_empty():
				_show_dialogue(interactable.get_interaction_text())

			return

		trainer_battle_triggered.emit(str(interactable.get("interactable_id")), interactable.battle_monster_data, int(interactable.battle_monster_level))
		return

	if action == 2:
		if bool(interactable.get("is_collected")):
			if interactable.has_method("get_interaction_text") and not interactable.get_interaction_text().is_empty():
				_show_dialogue(interactable.get_interaction_text())

			return

		var pickup_message: String = interactable.get_interaction_text()
		interactable.is_collected = true
		interactable.refresh_visual()
		if not _collected_interactable_ids.has(str(interactable.get("interactable_id"))):
			_collected_interactable_ids.append(str(interactable.get("interactable_id")))

		pickup_collected.emit(
			str(interactable.get("interactable_id")),
			str(interactable.get("pickup_item_key")),
			int(interactable.get("pickup_count")),
			str(interactable.get("pickup_item_name"))
		)
		_show_dialogue(pickup_message)
		return

	if interactable.has_method("get_interaction_text") and not interactable.get_interaction_text().is_empty():
		_show_dialogue(interactable.get_interaction_text())


func _show_dialogue(message: String) -> void:
	_hide_interaction_prompt()
	_dialogue_label.text = message
	_dialogue_panel.visible = true
	_player.movement_enabled = false


func close_dialogue() -> void:
	_dialogue_panel.visible = false
	_player.movement_enabled = true
	_update_interaction_prompt()


func set_defeated_interactables(defeated_ids: Array[String]) -> void:
	_defeated_interactable_ids = defeated_ids.duplicate()

	for interactable in _interactables_by_cell.values():
		if interactable != null:
			interactable.is_defeated = _defeated_interactable_ids.has(str(interactable.get("interactable_id")))
			interactable.refresh_visual()

	_update_interaction_prompt()


func set_collected_interactables(collected_ids: Array[String]) -> void:
	_collected_interactable_ids = collected_ids.duplicate()

	for interactable in _interactables_by_cell.values():
		if interactable != null:
			interactable.is_collected = _collected_interactable_ids.has(str(interactable.get("interactable_id")))
			interactable.refresh_visual()

	_update_interaction_prompt()


func _on_player_facing_changed(_direction: Vector2i) -> void:
	_update_interaction_prompt()


func _update_interaction_prompt() -> void:
	if _interaction_prompt == null or _interaction_prompt_label == null or _player == null:
		return

	var prompt_text := _get_interaction_prompt_text()

	if prompt_text.is_empty():
		_hide_interaction_prompt()
		return

	_interaction_prompt_label.text = prompt_text
	_interaction_prompt.visible = true


func _hide_interaction_prompt() -> void:
	if _interaction_prompt != null:
		_interaction_prompt.visible = false


func _get_interaction_prompt_text() -> String:
	if _dialogue_panel != null and _dialogue_panel.visible:
		return ""

	if _player == null or not _player.movement_enabled:
		return ""

	var target_cell := get_player_cell() + _player.get_facing_direction()

	if _interactables_by_cell.has(target_cell):
		var interactable = _interactables_by_cell[target_cell]

		if interactable == null:
			return ""

		var action := int(interactable.get("interaction_action"))

		if action == 1:
			return "Talk" if bool(interactable.get("is_defeated")) else "Battle"

		if action == 2:
			return "Check" if bool(interactable.get("is_collected")) else "Pick up"

		return "Talk"

	if not _get_sign_message(target_cell).is_empty():
		return "Read"

	if not _get_inspect_message(target_cell).is_empty():
		var inspect_prompt := _get_inspect_prompt(target_cell)

		if not inspect_prompt.is_empty():
			return inspect_prompt

		return "Check"

	var tile_data := _get_cell_tile_data_for_interaction(target_cell) if _ground_tile_map != null else null

	if tile_data != null and not str(tile_data.get_custom_data(INTERACTION_TEXT_DATA_KEY)).is_empty():
		return "Read"

	return ""


func _get_sign_message(cell: Vector2i) -> String:
	if _sign_messages_by_cell.has(cell):
		return str(_sign_messages_by_cell[cell].get("message", ""))

	if map_data != null and map_data.has_method("get_sign_message"):
		return map_data.get_sign_message(cell)

	return ""


func _get_inspect_message(cell: Vector2i) -> String:
	if _inspect_messages_by_cell.has(cell):
		return str(_inspect_messages_by_cell[cell].get("message", ""))

	if map_data != null and map_data.has_method("get_inspect_message"):
		return map_data.get_inspect_message(cell)

	return ""


func _get_inspect_prompt(cell: Vector2i) -> String:
	if _inspect_messages_by_cell.has(cell):
		var prompt := str(_inspect_messages_by_cell[cell].get("prompt", "Check"))
		return "Check" if prompt.is_empty() else prompt

	if map_data != null and map_data.has_method("get_inspect_prompt"):
		return map_data.get_inspect_prompt(cell)

	return ""


func _get_transition_entry(cell: Vector2i) -> Dictionary:
	if _transitions_by_cell.has(cell):
		return _transitions_by_cell[cell]

	if map_data != null and map_data.has_method("get_transition_entry"):
		return map_data.get_transition_entry(cell)

	return {}


func _update_debug_hud() -> void:
	if _debug_label == null or _player == null:
		return

	var player_cell := get_player_cell()
	var map_name := "Unknown"

	if map_data != null:
		map_name = str(map_data.map_name)

	_debug_label.text = "Map: %s\nCell: %s\nTerrain: %s\nEncounter: %d%%" % [
		map_name,
		str(player_cell),
		_get_current_terrain_name(player_cell),
		roundi(_player.get_encounter_chance_for_cell(player_cell) * 100.0),
	]


func _get_current_terrain_name(cell: Vector2i) -> String:
	if _ground_tile_map == null:
		return "Unknown"

	var ground_tile_data := _get_cell_tile_data(_ground_tile_map, GROUND_LAYER, cell)

	if ground_tile_data == null:
		return "Empty"

	var terrain = ground_tile_data.get_custom_data(TERRAIN_DATA_KEY)

	if terrain == null or str(terrain).is_empty():
		return "Unknown"

	var overlay_tile_data := _get_cell_tile_data(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell)

	if overlay_tile_data == null:
		return str(terrain)

	var overlay_terrain = overlay_tile_data.get_custom_data(TERRAIN_DATA_KEY)

	if overlay_terrain == null or str(overlay_terrain).is_empty():
		return str(terrain)

	return "%s + %s" % [str(terrain), str(overlay_terrain)]


func _get_cell_tile_data_for_interaction(cell: Vector2i) -> TileData:
	if _ground_tile_map == null:
		return null

	var overlay_tile_data := _get_cell_tile_data(_overlay_tile_layer if _overlay_tile_layer != null else _ground_tile_map, OVERLAY_LAYER, cell)

	if overlay_tile_data != null:
		return overlay_tile_data

	var layer_count := _get_layers_count(_ground_tile_map)

	for layer in range(layer_count - 1, -1, -1):
		if _ground_tile_map == _overlay_tile_layer and layer == OVERLAY_LAYER:
			continue

		var tile_data := _get_cell_tile_data(_ground_tile_map, layer, cell)

		if tile_data != null:
			return tile_data

	return null


func _has_any_tile_data(cell: Vector2i) -> bool:
	return _get_cell_tile_data_for_interaction(cell) != null


func _is_blocked_cell(cell: Vector2i) -> bool:
	if _ground_tile_map == null:
		return false

	for tile_layer in _get_collision_tile_layers():
		var tile_data := _get_cell_tile_data(tile_layer.get("node"), int(tile_layer.get("layer", 0)), cell)

		if tile_data != null and bool(tile_data.get_custom_data(BLOCKED_DATA_KEY)):
			return true

	return false


func _get_tile_layer_node(tile_map_name: String, tile_layer_name: String) -> Node:
	var tile_map := get_node_or_null("%" + tile_map_name)

	if tile_map != null:
		return tile_map

	if not tile_layer_name.is_empty():
		var unique_tile_layer := get_node_or_null("%" + tile_layer_name)

		if unique_tile_layer != null:
			return unique_tile_layer

		return find_child(tile_layer_name, true, false)

	return null


func _get_tile_set(tile_layer: Node) -> TileSet:
	if tile_layer == null:
		return null

	return tile_layer.get("tile_set") as TileSet


func _set_tile_set(tile_layer: Node, tile_set: TileSet) -> void:
	if tile_layer != null:
		tile_layer.set("tile_set", tile_set)


func _world_to_map(world_position: Vector2) -> Vector2i:
	if _ground_tile_map == null:
		return Vector2i.ZERO

	return _ground_tile_map.call("local_to_map", _ground_tile_map.to_local(world_position))


func _map_to_world(cell: Vector2i) -> Vector2:
	if _ground_tile_map == null:
		return Vector2.ZERO

	return _ground_tile_map.to_global(_ground_tile_map.call("map_to_local", cell))


func _get_layers_count(tile_layer: Node) -> int:
	if tile_layer == null:
		return 0

	if tile_layer is TileMap:
		return tile_layer.get_layers_count()

	return 1


func _get_collision_tile_layers() -> Array[Dictionary]:
	var layers: Array[Dictionary] = []

	if _ground_tile_map == null:
		return layers

	if _ground_tile_map is TileMap:
		for layer in range(_ground_tile_map.get_layers_count()):
			layers.append({ "node": _ground_tile_map, "layer": layer })
	else:
		layers.append({ "node": _ground_tile_map, "layer": GROUND_LAYER })

	if _overlay_tile_layer != null:
		layers.append({ "node": _overlay_tile_layer, "layer": OVERLAY_LAYER })

	return layers


func _get_cell_tile_data(tile_layer: Node, layer: int, cell: Vector2i) -> TileData:
	if tile_layer == null:
		return null

	if tile_layer is TileMap:
		return tile_layer.get_cell_tile_data(layer, cell)

	return tile_layer.call("get_cell_tile_data", cell)


func _set_cell(tile_layer: Node, layer: int, cell: Vector2i, atlas_coords: Vector2i) -> void:
	if tile_layer == null:
		return

	if tile_layer is TileMap:
		tile_layer.set_cell(layer, cell, SOURCE_ID, atlas_coords)
		return

	tile_layer.call("set_cell", cell, SOURCE_ID, atlas_coords)


func _erase_cell(tile_layer: Node, layer: int, cell: Vector2i) -> void:
	if tile_layer == null:
		return

	if tile_layer is TileMap:
		tile_layer.erase_cell(layer, cell)
		return

	tile_layer.call("erase_cell", cell)


func _clear_tile_layer(tile_layer: Node, layer: int) -> void:
	if tile_layer == null:
		return

	if tile_layer is TileMap:
		tile_layer.clear_layer(layer)
		return

	tile_layer.call("clear")


func _get_used_cells(tile_layer: Node, layer: int) -> Array[Vector2i]:
	if tile_layer == null:
		return []

	if tile_layer is TileMap:
		return tile_layer.get_used_cells(layer)

	return tile_layer.call("get_used_cells")


func _get_cell_source_id(tile_layer: Node, layer: int, cell: Vector2i) -> int:
	if tile_layer == null:
		return -1

	if tile_layer is TileMap:
		return tile_layer.get_cell_source_id(layer, cell)

	return int(tile_layer.call("get_cell_source_id", cell))


func _get_cell_atlas_coords(tile_layer: Node, layer: int, cell: Vector2i) -> Vector2i:
	if tile_layer == null:
		return Vector2i(-1, -1)

	if tile_layer is TileMap:
		return tile_layer.get_cell_atlas_coords(layer, cell)

	return tile_layer.call("get_cell_atlas_coords", cell)
