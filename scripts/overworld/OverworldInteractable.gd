extends Node2D
class_name OverworldInteractable

enum InteractionAction {
	DIALOGUE,
	BATTLE,
	PICKUP,
}

@export var grid_cell := Vector2i.ZERO
@export var use_scene_position := true
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

const DIALOGUE_COLOR := Color(0.24, 0.36, 0.86, 1.0)
const TRAINER_COLOR := Color(0.92, 0.52, 0.16, 1.0)
const PICKUP_COLOR := Color(0.56, 0.28, 0.86, 1.0)
const INACTIVE_COLOR := Color(0.45, 0.45, 0.5, 1.0)

var is_defeated := false
var is_collected := false

@onready var _body := get_node_or_null("Body") as ColorRect
@onready var _alert_marker := get_node_or_null("AlertMarker") as CanvasItem


func _ready() -> void:
	refresh_visual()
	hide_alert_marker()


func place_on_tile_map(tile_map: Node) -> void:
	if tile_map == null:
		return

	global_position = tile_map.to_global(tile_map.call("map_to_local", grid_cell))
	refresh_visual()


func sync_grid_cell_from_tile_map(tile_map: Node) -> void:
	if tile_map == null or not use_scene_position:
		return

	grid_cell = tile_map.call("local_to_map", tile_map.to_local(global_position))


func get_interaction_text() -> String:
	if is_collected and not collected_dialogue_text.is_empty():
		return collected_dialogue_text

	if is_defeated and not defeated_dialogue_text.is_empty():
		return defeated_dialogue_text

	return dialogue_text


func get_interaction_action() -> int:
	return interaction_action


func refresh_visual() -> void:
	if _body == null:
		_body = get_node_or_null("Body") as ColorRect

	if _body == null:
		return

	_body.color = get_visual_color()


func show_alert_marker() -> void:
	if _alert_marker == null:
		_alert_marker = get_node_or_null("AlertMarker") as CanvasItem

	if _alert_marker != null:
		_alert_marker.visible = true


func hide_alert_marker() -> void:
	if _alert_marker == null:
		_alert_marker = get_node_or_null("AlertMarker") as CanvasItem

	if _alert_marker != null:
		_alert_marker.visible = false


func get_visual_color() -> Color:
	if is_defeated or is_collected:
		return INACTIVE_COLOR

	match interaction_action:
		InteractionAction.BATTLE:
			return TRAINER_COLOR
		InteractionAction.PICKUP:
			return PICKUP_COLOR
		_:
			return DIALOGUE_COLOR
