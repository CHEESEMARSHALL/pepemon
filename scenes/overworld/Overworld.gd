extends Node2D

signal battle_triggered(enemy_monster: Resource, enemy_level: int)
signal trainer_battle_triggered(trainer_id: String, enemy_monster: Resource, enemy_level: int)
signal pickup_collected(pickup_id: String, item_key: String, item_count: int, item_name: String)
signal route_transition_requested(target_map: Resource, target_start_cell: Vector2i)

@export var map_data: Resource
@export var interactable_scene: PackedScene
@export var player_start_cell_override := Vector2i(-999, -999)

const CELL_SIZE := Vector2i(16, 16)
const SOURCE_ID := 0
const DIRT_TILE := Vector2i(0, 0)
const GRASS_TILE := Vector2i(1, 0)
const WALL_TILE := Vector2i(2, 0)
const SIGN_TILE := Vector2i(3, 0)
const NPC_TILE := Vector2i(4, 0)
const TERRAIN_DATA_KEY := "terrain"
const BLOCKED_DATA_KEY := "blocked"
const INTERACTION_TEXT_DATA_KEY := "interaction_text"
const TERRAIN_DIRT := "Dirt"
const TERRAIN_GRASS := "Grass"
const TERRAIN_WALL := "Wall"
const TERRAIN_SIGN := "Sign"
const TERRAIN_NPC := "NPC"

@onready var _player := %Player as PlayerController
@onready var _ground_tile_map := %GroundTileMap as TileMap
@onready var _dialogue_panel := %DialoguePanel as PanelContainer
@onready var _dialogue_label := %DialogueLabel as Label
@onready var _interactables := %Interactables as Node2D

var _interactables_by_cell: Dictionary = {}
var _defeated_interactable_ids: Array[String] = []
var _collected_interactable_ids: Array[String] = []
var _active_sight_trainer_id := ""


func _ready() -> void:
	_setup_map()
	_spawn_interactables_from_map_data()
	_setup_interactables()
	_player.interaction_requested.connect(_on_player_interaction_requested)
	_player.step_finished.connect(_on_player_step_finished)
	_dialogue_panel.visible = false


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

	return _ground_tile_map.local_to_map(_ground_tile_map.to_local(_player.global_position))


func _setup_map() -> void:
	if _ground_tile_map.tile_set == null:
		_ground_tile_map.tile_set = _create_route_tile_set()

	_ground_tile_map.clear()

	if map_data == null:
		push_error("Overworld requires map_data.")
		return

	for y in range(map_data.get_height()):
		for x in range(map_data.get_width()):
			var cell := Vector2i(x, y)
			_ground_tile_map.set_cell(0, cell, SOURCE_ID, _get_tile_atlas_coords(map_data.get_tile_code(cell)))

	var start_cell: Vector2i = player_start_cell_override if player_start_cell_override != Vector2i(-999, -999) else map_data.player_start_cell
	_player.global_position = _ground_tile_map.to_global(_ground_tile_map.map_to_local(start_cell))
	_player.encounter_table = map_data.encounter_table


func _get_tile_atlas_coords(tile_code: String) -> Vector2i:
	match tile_code:
		"#":
			return WALL_TILE
		"G":
			return GRASS_TILE
		"S":
			return SIGN_TILE
		_:
			return DIRT_TILE


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

	var image := Image.create(CELL_SIZE.x * 5, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(Vector2i.ZERO, CELL_SIZE), Color(0.45, 0.32, 0.18))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x, 0), CELL_SIZE), Color(0.18, 0.62, 0.22))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 2, 0), CELL_SIZE), Color(0.18, 0.18, 0.2))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 3, 0), CELL_SIZE), Color(0.78, 0.68, 0.28))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x * 4, 0), CELL_SIZE), Color(0.24, 0.36, 0.86))

	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = CELL_SIZE
	source.create_tile(DIRT_TILE)
	source.create_tile(GRASS_TILE)
	source.create_tile(WALL_TILE)
	source.create_tile(SIGN_TILE)
	source.create_tile(NPC_TILE)

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
	return tile_set


func _setup_interactables() -> void:
	_interactables_by_cell.clear()

	if _interactables == null:
		return

	for child in _interactables.get_children():
		if not child.has_method("place_on_tile_map") or not child.has_method("get_interaction_text"):
			continue

		child.place_on_tile_map(_ground_tile_map)
		_interactables_by_cell[child.grid_cell] = child

		if child.blocks_movement:
			_ground_tile_map.set_cell(0, child.grid_cell, SOURCE_ID, NPC_TILE)


func _spawn_interactables_from_map_data() -> void:
	if _interactables == null or map_data == null or interactable_scene == null:
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


func _on_player_interaction_requested(cell: Vector2i) -> void:
	if _interactables_by_cell.has(cell):
		var interactable = _interactables_by_cell[cell]

		if interactable != null:
			_handle_interactable(interactable)

		return

	var tile_data := _ground_tile_map.get_cell_tile_data(0, cell)

	if tile_data == null:
		return

	var message := ""

	if map_data != null and map_data.has_method("get_sign_message"):
		message = map_data.get_sign_message(cell)

	if message.is_empty():
		message = str(tile_data.get_custom_data(INTERACTION_TEXT_DATA_KEY))

	if message.is_empty():
		return

	_show_dialogue(message)


func _on_player_step_finished(cell: Vector2i) -> void:
	if not _active_sight_trainer_id.is_empty() or _dialogue_panel.visible:
		return

	var trainer := _get_sighting_trainer(cell)

	if trainer == null:
		_check_route_transition(cell)
		return

	_trigger_trainer_sight(trainer)


func _check_route_transition(cell: Vector2i) -> void:
	if map_data == null or not map_data.has_method("get_transition_entry"):
		return

	var transition: Dictionary = map_data.get_transition_entry(cell)

	if transition.is_empty():
		return

	var target_map = transition.get("target_map", null)

	if target_map == null:
		var target_map_path := str(transition.get("target_map_path", ""))

		if not target_map_path.is_empty():
			target_map = load(target_map_path)

	if target_map == null:
		return

	_player.movement_enabled = false
	route_transition_requested.emit(target_map, transition.get("target_start_cell", Vector2i.ZERO))


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
	var tile_data := _ground_tile_map.get_cell_tile_data(0, cell)

	if tile_data == null:
		return true

	if bool(tile_data.get_custom_data(BLOCKED_DATA_KEY)):
		return true

	return _interactables_by_cell.has(cell)


func _trigger_trainer_sight(interactable: Node) -> void:
	_active_sight_trainer_id = str(interactable.get("interactable_id"))
	_player.movement_enabled = false
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
	_dialogue_label.text = message
	_dialogue_panel.visible = true
	_player.movement_enabled = false


func close_dialogue() -> void:
	_dialogue_panel.visible = false
	_player.movement_enabled = true


func set_defeated_interactables(defeated_ids: Array[String]) -> void:
	_defeated_interactable_ids = defeated_ids.duplicate()

	for interactable in _interactables_by_cell.values():
		if interactable != null:
			interactable.is_defeated = _defeated_interactable_ids.has(str(interactable.get("interactable_id")))


func set_collected_interactables(collected_ids: Array[String]) -> void:
	_collected_interactable_ids = collected_ids.duplicate()

	for interactable in _interactables_by_cell.values():
		if interactable != null:
			interactable.is_collected = _collected_interactable_ids.has(str(interactable.get("interactable_id")))
