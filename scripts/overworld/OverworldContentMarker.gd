extends Node2D
class_name OverworldContentMarker

enum MarkerType {
	SIGN,
	INSPECT,
	TRANSITION,
}

@export var marker_type := MarkerType.SIGN
@export var grid_cell := Vector2i.ZERO
@export var use_scene_position := true
@export_multiline var message := ""
@export var prompt := "Check"
@export var target_map: Resource
@export_file("*.tres", "*.res") var target_map_path := ""
@export var target_scene: PackedScene
@export_file("*.tscn", "*.scn") var target_scene_path := ""
@export var target_start_cell := Vector2i.ZERO

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


func refresh_visual() -> void:
	if _body == null:
		_body = get_node_or_null("Body") as ColorRect

	if _label == null:
		_label = get_node_or_null("Label") as Label

	if _body != null:
		_body.color = _get_marker_color()

	if _label != null:
		_label.text = _get_marker_label()


func to_sign_entry() -> Dictionary:
	return {
		"cell": grid_cell,
		"message": message,
	}


func to_inspect_entry() -> Dictionary:
	return {
		"cell": grid_cell,
		"message": message,
		"prompt": prompt,
	}


func to_transition_entry() -> Dictionary:
	return {
		"cell": grid_cell,
		"target_map": target_map,
		"target_map_path": target_map_path,
		"target_scene": target_scene,
		"target_scene_path": target_scene_path,
		"target_start_cell": target_start_cell,
	}


func _get_marker_color() -> Color:
	match marker_type:
		MarkerType.INSPECT:
			return Color(0.42, 0.58, 0.95, 0.7)
		MarkerType.TRANSITION:
			return Color(0.22, 0.86, 0.68, 0.7)
		_:
			return Color(0.95, 0.82, 0.22, 0.7)


func _get_marker_label() -> String:
	match marker_type:
		MarkerType.INSPECT:
			return "?"
		MarkerType.TRANSITION:
			return ">"
		_:
			return "S"
