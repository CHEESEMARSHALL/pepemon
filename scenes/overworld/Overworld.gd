extends Node2D

const CELL_SIZE := Vector2i(16, 16)
const SOURCE_ID := 0
const DIRT_TILE := Vector2i(0, 0)
const GRASS_TILE := Vector2i(1, 0)
const TERRAIN_DATA_KEY := "terrain"
const TERRAIN_DIRT := "Dirt"
const TERRAIN_GRASS := "Grass"

@onready var _player := %Player as PlayerController
@onready var _ground_tile_map := %GroundTileMap as TileMap


func _ready() -> void:
	_setup_test_map()


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

	for x in range(9, 13):
		for y in range(7, 11):
			_ground_tile_map.set_cell(0, Vector2i(x, y), SOURCE_ID, GRASS_TILE)


func _create_test_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = CELL_SIZE
	tile_set.add_custom_data_layer(0)
	tile_set.set_custom_data_layer_name(0, TERRAIN_DATA_KEY)
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)

	var image := Image.create(CELL_SIZE.x * 2, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(Vector2i.ZERO, CELL_SIZE), Color(0.45, 0.32, 0.18))
	image.fill_rect(Rect2i(Vector2i(CELL_SIZE.x, 0), CELL_SIZE), Color(0.18, 0.62, 0.22))

	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = CELL_SIZE
	source.create_tile(DIRT_TILE)
	source.create_tile(GRASS_TILE)

	tile_set.add_source(source, SOURCE_ID)
	source.get_tile_data(DIRT_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_DIRT)
	source.get_tile_data(GRASS_TILE, 0).set_custom_data(TERRAIN_DATA_KEY, TERRAIN_GRASS)
	return tile_set
