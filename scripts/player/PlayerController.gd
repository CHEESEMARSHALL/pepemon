extends CharacterBody2D
class_name PlayerController

signal battle_triggered(enemy_monster: Resource, enemy_level: int)
signal interaction_requested(cell: Vector2i)

@export_group("Movement")
@export var movement_enabled := true
@export var move_time: float = 0.16
@export var fallback_cell_size: Vector2 = Vector2(16, 16)

@export_group("Tile Detection")
@export var tile_map_path: NodePath
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

@onready var _tile_map := get_node_or_null(tile_map_path) as TileMap


func _ready() -> void:
	_rng.randomize()

	if _tile_map != null and _tile_map.tile_set == null:
		await get_tree().process_frame

	_snap_to_grid()


func _process(_delta: float) -> void:
	if not movement_enabled:
		return

	if _is_moving:
		return

	var direction := _get_input_direction()

	if direction == Vector2i.ZERO:
		return

	_facing_direction = direction
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

	var current_cell := _tile_map.local_to_map(_tile_map.to_local(global_position))
	interaction_requested.emit(current_cell + _facing_direction)


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
		var current_cell := _tile_map.local_to_map(_tile_map.to_local(global_position))
		var target_cell := current_cell + direction

		if _is_blocked_tile(target_cell):
			return global_position

		return _tile_map.to_global(_tile_map.map_to_local(target_cell))

	return global_position + Vector2(direction) * fallback_cell_size


func _on_step_finished() -> void:
	_is_moving = false
	_check_for_grass_encounter()


func _check_for_grass_encounter() -> void:
	if not _is_on_grass_tile():
		return

	if _rng.randf() <= grass_encounter_chance:
		trigger_battle()


func _is_on_grass_tile() -> bool:
	if _tile_map == null:
		return false

	var current_cell := _tile_map.local_to_map(_tile_map.to_local(global_position))
	var tile_data := _tile_map.get_cell_tile_data(ground_layer, current_cell)

	if tile_data == null:
		return false

	var tile_value = tile_data.get_custom_data(grass_custom_data_key)
	return str(tile_value) == grass_custom_data_value


func _is_blocked_tile(cell: Vector2i) -> bool:
	if _tile_map == null:
		return false

	var tile_data := _tile_map.get_cell_tile_data(ground_layer, cell)

	if tile_data == null:
		return block_empty_tiles

	return bool(tile_data.get_custom_data(blocked_custom_data_key))


func _snap_to_grid() -> void:
	if _tile_map != null:
		var current_cell := _tile_map.local_to_map(_tile_map.to_local(global_position))
		global_position = _tile_map.to_global(_tile_map.map_to_local(current_cell))
		return

	global_position = global_position.snapped(fallback_cell_size)


func trigger_battle() -> void:
	var encounter := _get_encounter()
	battle_triggered.emit(encounter.get("monster"), int(encounter.get("level", 5)))


func _get_encounter() -> Dictionary:
	if encounter_table != null and encounter_table.has_method("get_random_encounter"):
		var encounter = encounter_table.call("get_random_encounter", _rng)

		if encounter is Dictionary and encounter.has("monster"):
			return encounter

	return {
		"monster": null,
		"level": 5,
	}
