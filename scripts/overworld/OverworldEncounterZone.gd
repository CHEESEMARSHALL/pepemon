extends Node2D
class_name OverworldEncounterZone

@export var zone_id := "grass"
@export var grid_cell := Vector2i.ZERO
@export var size_in_cells := Vector2i.ONE
@export var use_scene_position := true
@export_range(0.0, 1.0, 0.01) var encounter_chance := 0.1
@export var encounter_table: Resource

@onready var _body := get_node_or_null("Body") as ColorRect
@onready var _label := get_node_or_null("Label") as Label


func _ready() -> void:
	refresh_visual()


func sync_grid_cell_from_tile_map(tile_map: Node) -> void:
	if tile_map == null or not use_scene_position:
		return

	grid_cell = tile_map.call("local_to_map", tile_map.to_local(global_position))
	global_position = tile_map.to_global(tile_map.call("map_to_local", grid_cell))
	refresh_visual()


func get_zone_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var width = maxi(1, size_in_cells.x)
	var height = maxi(1, size_in_cells.y)

	for y in range(height):
		for x in range(width):
			cells.append(grid_cell + Vector2i(x, y))

	return cells


func to_encounter_config(default_encounter_table: Resource) -> Dictionary:
	return {
		"zone_id": zone_id,
		"chance": encounter_chance,
		"encounter_table": encounter_table if encounter_table != null else default_encounter_table,
	}


func refresh_visual() -> void:
	if _body == null:
		_body = get_node_or_null("Body") as ColorRect

	if _label == null:
		_label = get_node_or_null("Label") as Label

	var width := maxi(1, size_in_cells.x)
	var height := maxi(1, size_in_cells.y)
	var pixel_size := Vector2(width * 32, height * 32)

	if _body != null:
		_body.offset_left = -16.0
		_body.offset_top = -16.0
		_body.offset_right = -16.0 + pixel_size.x
		_body.offset_bottom = -16.0 + pixel_size.y
		_body.color = Color(0.16, 0.82, 0.34, 0.28)

	if _label != null:
		_label.offset_left = -16.0
		_label.offset_top = -16.0
		_label.offset_right = -16.0 + pixel_size.x
		_label.offset_bottom = -16.0 + pixel_size.y
		_label.text = "Wild"
