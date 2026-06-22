extends SceneTree

var _battle_monster: Resource
var _battle_level := 0


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
	overworld.battle_triggered.connect(_on_battle_triggered)
	await process_frame
	await process_frame

	var player := overworld.find_child("Player", true, false) as PlayerController
	var tile_map := overworld.get_node("%GroundTileMap") as TileMap

	if player == null or tile_map == null:
		push_error("Trainer interaction validation could not find player or tile map.")
		quit(1)
		return

	player.global_position = tile_map.to_global(tile_map.map_to_local(Vector2i(10, 7)))
	await process_frame

	var position_before_trainer_step := player.global_position
	Input.action_press("ui_up")
	await process_frame
	await create_timer(player.move_time + 0.05).timeout
	Input.action_release("ui_up")
	await process_frame

	if not player.global_position.is_equal_approx(position_before_trainer_step):
		push_error("Trainer interactable did not block movement.")
		quit(1)
		return

	player.interact()
	await process_frame

	if _battle_monster == null or _battle_level != 4:
		push_error("Trainer interaction did not request the configured battle.")
		quit(1)
		return

	print("Trainer interaction validation passed: blocked trainer requested battle.")
	quit()


func _on_battle_triggered(enemy_monster: Resource, enemy_level: int) -> void:
	_battle_monster = enemy_monster
	_battle_level = enemy_level
