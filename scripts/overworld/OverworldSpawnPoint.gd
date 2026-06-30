extends Node2D
class_name OverworldSpawnPoint

@export var spawn_id := "default"
@export var grid_cell := Vector2i.ZERO
@export var facing_direction := Vector2i.DOWN
@export var use_scene_position := true

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
		_body.color = Color(0.96, 0.32, 0.32, 0.7)

	if _label != null:
		_label.text = "P"
