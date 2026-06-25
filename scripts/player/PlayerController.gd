extends CharacterBody2D
class_name PlayerController

signal battle_triggered(enemy_monster: Resource, enemy_level: int)
signal interaction_requested(cell: Vector2i)
signal step_finished(cell: Vector2i)
signal facing_changed(direction: Vector2i)

@export_group("Movement")
@export var movement_enabled := true
@export var move_time: float = 0.16
@export var fallback_cell_size: Vector2 = Vector2(16, 16)

@export_group("Tile Detection")
@export var tile_map_path: NodePath
@export var object_tile_layer_paths: Array[NodePath] = []
@export var ground_layer: int = 0
@export var grass_custom_data_key: String = "terrain"
@export var grass_custom_data_value: String = "Grass"
@export var blocked_custom_data_key: String = "blocked"
@export var block_empty_tiles := true

@export_group("Encounters")
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance: float = 0.1
@export var encounter_table: Resource

var _is_moving := false
var _facing_direction := Vector2i.LEFT
var _rng := RandomNumberGenerator.new()
var _encounter_zone_configs_by_cell: Dictionary = {}

@onready var _tile_map := get_node_or_null(tile_map_path)
@onready var _facing_marker := get_node_or_null("FacingMarker") as ColorRect
var _object_tile_layers: Array[Node] = []


func _ready() -> void:
	_rng.randomize()

	_object_tile_layers.clear()
	for layer_path in object_tile_layer_paths:
		var layer := get_node_or_null(layer_path)

		if layer != null:
			_object_tile_layers.append(layer)

	if _tile_map != null and _tile_map.get("tile_set") == null:
		await get_tree().process_frame

	_snap_to_grid()
	_update_facing_marker()


func _process(_delta: float) -> void:
	if not movement_enabled:
		return

	if _is_moving:
		return

	var direction := _get_input_direction()

	if direction == Vector2i.ZERO:
		return

	_set_facing_direction(direction)
	_step(direction)


func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled or _is_moving:
		return

	if event.is_action_pressed("ui_accept"):
		interact()
		get_viewport().set_input_as_handled()


func interact() -> void:
	if _tile_map == null:
		return

	var current_cell := _world_to_map(global_position)
	interaction_requested.emit(current_cell + _facing_direction)


func set_facing_direction(direction: Vector2i) -> void:
	_set_facing_direction(direction)


func get_facing_direction() -> Vector2i:
	return _facing_direction


func _get_input_direction() -> Vector2i:
	if Input.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	if Input.is_action_pressed("ui_up"):
		return Vector2i.UP
	if Input.is_action_pressed("ui_down"):
		return Vector2i.DOWN

	return Vector2i.ZERO


func _step(direction: Vector2i) -> void:
	_is_moving = true

	var target_position := _get_target_position(direction)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_position, move_time)
	tween.finished.connect(_on_step_finished)


func _get_target_position(direction: Vector2i) -> Vector2:
	if _tile_map != null:
		var current_cell := _world_to_map(global_position)
		var target_cell := current_cell + direction

		if _is_blocked_tile(target_cell):
			return global_position

		return _map_to_world(target_cell)

	return global_position + Vector2(direction) * fallback_cell_size


func _set_facing_direction(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return

	_facing_direction = direction
	_update_facing_marker()
	facing_changed.emit(_facing_direction)


func _update_facing_marker() -> void:
	if _facing_marker == null:
		return

	var marker_size := Vector2(5, 6)
	var half_size := marker_size * 0.5
	var center := Vector2.ZERO

	if _facing_direction == Vector2i.RIGHT:
		center = Vector2(11.0, 0)
	elif _facing_direction == Vector2i.UP:
		center = Vector2(0, -13.0)
		marker_size = Vector2(6, 5)
		half_size = marker_size * 0.5
	elif _facing_direction == Vector2i.DOWN:
		center = Vector2(0, 13.0)
		marker_size = Vector2(6, 5)
		half_size = marker_size * 0.5
	else:
		center = Vector2(-11.0, 0)

	_facing_marker.offset_left = center.x - half_size.x
	_facing_marker.offset_top = center.y - half_size.y
	_facing_marker.offset_right = center.x + half_size.x
	_facing_marker.offset_bottom = center.y + half_size.y


func _on_step_finished() -> void:
	_is_moving = false
	step_finished.emit(_get_current_cell())

	if not movement_enabled:
		return

	_check_for_grass_encounter()


func _check_for_grass_encounter() -> void:
	var current_cell := _get_current_cell()
	var encounter_config := _get_encounter_config(current_cell)

	if encounter_config.is_empty():
		return

	var encounter_chance := float(encounter_config.get("chance", grass_encounter_chance))

	if _rng.randf() <= encounter_chance:
		trigger_battle(encounter_config.get("encounter_table", null))


func set_encounter_zone_configs(encounter_zone_configs_by_cell: Dictionary) -> void:
	_encounter_zone_configs_by_cell = encounter_zone_configs_by_cell.duplicate(true)


func get_encounter_chance_for_cell(cell: Vector2i) -> float:
	var encounter_config := _get_encounter_config(cell)

	if encounter_config.is_empty():
		return 0.0

	return float(encounter_config.get("chance", grass_encounter_chance))


func _get_encounter_config(cell: Vector2i) -> Dictionary:
	if _encounter_zone_configs_by_cell.has(cell):
		return _encounter_zone_configs_by_cell[cell]

	if not _is_on_grass_tile():
		return {}

	return {
		"chance": grass_encounter_chance,
		"encounter_table": encounter_table,
	}


func _is_on_grass_tile() -> bool:
	if _tile_map == null:
		return false

	var current_cell := _world_to_map(global_position)
	var tile_data := _get_tile_data(_tile_map, ground_layer, current_cell)

	if tile_data == null:
		return false

	var tile_value = tile_data.get_custom_data(grass_custom_data_key)
	return str(tile_value) == grass_custom_data_value


func _is_blocked_tile(cell: Vector2i) -> bool:
	if _tile_map == null:
		return false

	var found_tile := false

	for tile_layer in _get_tile_layers():
		var tile_data := _get_tile_data(tile_layer.get("node"), int(tile_layer.get("layer", 0)), cell)

		if tile_data == null:
			continue

		found_tile = true

		if bool(tile_data.get_custom_data(blocked_custom_data_key)):
			return true

	if not found_tile:
		return block_empty_tiles

	return false


func _snap_to_grid() -> void:
	if _tile_map != null:
		var current_cell := _get_current_cell()
		global_position = _map_to_world(current_cell)
		return

	global_position = global_position.snapped(fallback_cell_size)


func _get_current_cell() -> Vector2i:
	if _tile_map == null:
		return Vector2i.ZERO

	return _world_to_map(global_position)


func _world_to_map(world_position: Vector2) -> Vector2i:
	if _tile_map == null:
		return Vector2i.ZERO

	return _tile_map.call("local_to_map", _tile_map.to_local(world_position))


func _map_to_world(cell: Vector2i) -> Vector2:
	if _tile_map == null:
		return global_position

	return _tile_map.to_global(_tile_map.call("map_to_local", cell))


func _get_tile_layers() -> Array[Dictionary]:
	var layers: Array[Dictionary] = []

	if _tile_map == null:
		return layers

	if _tile_map is TileMap:
		for layer in range(_tile_map.get_layers_count()):
			layers.append({ "node": _tile_map, "layer": layer })
	else:
		layers.append({ "node": _tile_map, "layer": 0 })

	for object_layer in _object_tile_layers:
		layers.append({ "node": object_layer, "layer": 0 })

	return layers


func _get_tile_data(tile_layer: Node, layer: int, cell: Vector2i) -> TileData:
	if tile_layer == null:
		return null

	if tile_layer is TileMap:
		return tile_layer.get_cell_tile_data(layer, cell)

	return tile_layer.call("get_cell_tile_data", cell)


func trigger_battle(encounter_table_override: Resource = null) -> void:
	var encounter := _get_encounter(encounter_table_override)
	battle_triggered.emit(encounter.get("monster"), int(encounter.get("level", 5)))


func _get_encounter(encounter_table_override: Resource = null) -> Dictionary:
	var active_encounter_table := encounter_table_override if encounter_table_override != null else encounter_table

	if active_encounter_table != null and active_encounter_table.has_method("get_random_encounter"):
		var encounter = active_encounter_table.call("get_random_encounter", _rng)

		if encounter is Dictionary and encounter.has("monster"):
			return encounter

	return {
		"monster": null,
		"level": 5,
	}
