extends Node2D
class_name OverworldInteractable

enum InteractionAction {
	DIALOGUE,
	BATTLE,
	PICKUP,
}

@export var grid_cell := Vector2i.ZERO
@export var interactable_id := ""
@export_multiline var dialogue_text := ""
@export_multiline var defeated_dialogue_text := ""
@export_multiline var collected_dialogue_text := "There is nothing here."
@export var blocks_movement := true
@export var interaction_action := InteractionAction.DIALOGUE
@export var battle_monster_data: Resource
@export_range(1, 100, 1) var battle_monster_level := 5
@export var sight_direction := Vector2i.ZERO
@export_range(0, 12, 1) var sight_range := 0
@export_multiline var challenge_dialogue_text := ""
@export var pickup_item_key := ""
@export var pickup_item_name := ""
@export_range(1, 99, 1) var pickup_count := 1

var is_defeated := false
var is_collected := false


func place_on_tile_map(tile_map: TileMap) -> void:
	if tile_map == null:
		return

	global_position = tile_map.to_global(tile_map.map_to_local(grid_cell))


func get_interaction_text() -> String:
	if is_collected and not collected_dialogue_text.is_empty():
		return collected_dialogue_text

	if is_defeated and not defeated_dialogue_text.is_empty():
		return defeated_dialogue_text

	return dialogue_text


func get_interaction_action() -> int:
	return interaction_action
