extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overworld_scene := load("res://scenes/overworld/Overworld.tscn") as PackedScene

	if overworld_scene == null:
		push_error("Failed to load Overworld.tscn.")
		quit(1)
		return

	var overworld := overworld_scene.instantiate()
	get_root().add_child(overworld)
	await process_frame
	await process_frame

	var player := overworld.find_child("Player", true, false) as PlayerController

	if player == null:
		push_error("Collision validation could not find player.")
		quit(1)
		return

	var tile_map := player.get_node_or_null(player.tile_map_path) as TileMap

	if tile_map == null:
		push_error("Collision validation could not find TileMap.")
		quit(1)
		return

	var start_cell := tile_map.local_to_map(tile_map.to_local(player.global_position))

	if start_cell != Vector2i(8, 8):
		push_error("Expected player to start on cell (8, 8), got %s." % str(start_cell))
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(5, 8)))
	await process_frame

	var before_wall_step := player.global_position
	var blocked_target: Vector2 = player.call("_get_target_position", Vector2i.LEFT)

	if blocked_target != before_wall_step:
		push_error("Blocked wall tile returned a movement target.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(8, 8)))
	await process_frame
	var grass_target: Vector2 = player.call("_get_target_position", Vector2i.RIGHT)
	var grass_cell := tile_map.local_to_map(tile_map.to_local(grass_target))

	if grass_cell != Vector2i(9, 8):
		push_error("Grass tile did not return a valid movement target.")
		quit(1)
		return

	print("Overworld collision validation passed: walls block movement and grass remains walkable.")
	quit()
