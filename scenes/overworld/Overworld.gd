extends Node2D

signal battle_triggered(enemy_monster: Resource, enemy_level: int)

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
const SIGN_MESSAGE := "Pepemon Route 1\nTall grass hides wild monsters."

@onready var _player := %Player as PlayerController
@onready var _ground_tile_map := %GroundTileMap as TileMap
@onready var _dialogue_panel := %DialoguePanel as PanelContainer
@onready var _dialogue_label := %DialogueLabel as Label
@onready var _interactables := %Interactables as Node2D

var _interactables_by_cell: Dictionary = {}


func _ready() -> void:
	_setup_test_map()
	_setup_interactables()
	_player.interaction_requested.connect(_on_player_interaction_requested)
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


func _setup_test_map() -> void:
	if _ground_tile_map.tile_set == null:
		_ground_tile_map.tile_set = _create_test_tile_set()

	_ground_tile_map.clear()

	for x in range(4, 14):
		for y in range(5, 12):
			_ground_tile_map.set_cell(0, Vector2i(x, y), SOURCE_ID, DIRT_TILE)

	for x in range(4, 14):
		_ground_tile_map.set_cell(0, Vector2i(x, 5), SOURCE_ID, WALL_TILE)
		_ground_tile_map.set_cell(0, Vector2i(x, 11), SOURCE_ID, WALL_TILE)

	for y in range(5, 12):
		_ground_tile_map.set_cell(0, Vector2i(4, y), SOURCE_ID, WALL_TILE)
		_ground_tile_map.set_cell(0, Vector2i(13, y), SOURCE_ID, WALL_TILE)

	for x in range(9, 13):
		for y in range(7, 11):
			_ground_tile_map.set_cell(0, Vector2i(x, y), SOURCE_ID, GRASS_TILE)

	_ground_tile_map.set_cell(0, Vector2i(7, 8), SOURCE_ID, SIGN_TILE)


func _create_test_tile_set() -> TileSet:
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
	source.get_tile_data(SIGN_TILE, 0).set_custom_data(INTERACTION_TEXT_DATA_KEY, SIGN_MESSAGE)
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


func _on_player_interaction_requested(cell: Vector2i) -> void:
	if _interactables_by_cell.has(cell):
		var interactable = _interactables_by_cell[cell]

		if interactable != null:
			_handle_interactable(interactable)

		return

	var tile_data := _ground_tile_map.get_cell_tile_data(0, cell)

	if tile_data == null:
		return

	var message := str(tile_data.get_custom_data(INTERACTION_TEXT_DATA_KEY))

	if message.is_empty():
		return

	_show_dialogue(message)


func _handle_interactable(interactable: Node) -> void:
	var action := 0

	if interactable.has_method("get_interaction_action"):
		action = int(interactable.get_interaction_action())

	if action == 1:
		battle_triggered.emit(interactable.battle_monster_data, int(interactable.battle_monster_level))
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
