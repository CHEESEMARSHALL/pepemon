extends Node2D
class_name OverworldInteractable

enum InteractionAction {
	DIALOGUE,
	BATTLE,
}

@export var grid_cell := Vector2i.ZERO
@export var interactable_id := ""
@export_multiline var dialogue_text := ""
@export_multiline var defeated_dialogue_text := ""
@export var blocks_movement := true
@export var interaction_action := InteractionAction.DIALOGUE
@export var battle_monster_data: Resource
@export_range(1, 100, 1) var battle_monster_level := 5

var is_defeated := false


func place_on_tile_map(tile_map: TileMap) -> void:
	if tile_map == null:
		return

	global_position = tile_map.to_global(tile_map.map_to_local(grid_cell))


func get_interaction_text() -> String:
	if is_defeated and not defeated_dialogue_text.is_empty():
		return defeated_dialogue_text

	return dialogue_text


func get_interaction_action() -> int:
	return interaction_action
