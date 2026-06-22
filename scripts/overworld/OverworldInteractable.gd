extends Node2D
class_name OverworldInteractable

@export var grid_cell := Vector2i.ZERO
@export_multiline var dialogue_text := ""
@export var blocks_movement := true


func place_on_tile_map(tile_map: TileMap) -> void:
	if tile_map == null:
		return

	global_position = tile_map.to_global(tile_map.map_to_local(grid_cell))


func get_interaction_text() -> String:
	return dialogue_text
