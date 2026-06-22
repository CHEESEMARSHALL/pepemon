extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_save_tools := load("res://scripts/tests/TestSaveTools.gd")

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	var game_root_scene := load("res://scenes/game/GameRoot.tscn") as PackedScene

	if game_root_scene == null:
		push_error("Failed to load GameRoot.tscn.")
		quit(1)
		return

	var game_root := game_root_scene.instantiate()
	get_root().add_child(game_root)
	await process_frame

	var scene_root := game_root.get_node("%SceneRoot")
	var starting_party: Array = game_root.get("_player_party")
	var starting_inventory: Dictionary = game_root.get("_inventory")
	var overworld := scene_root.get_child(0)

	if overworld == null or not overworld.has_method("force_test_encounter"):
		push_error("GameRoot did not load the overworld scene.")
		quit(1)
		return

	overworld.call("force_test_encounter")
	await process_frame
	await process_frame

	var battle_ui := scene_root.get_child(0) as BattleUI

	if battle_ui == null:
		push_error("Forced encounter did not transition to BattleUI.")
		quit(1)
		return

	battle_ui.message_time = 0.01

	var bag_button := battle_ui.get_node("%BagButton") as Button
	var capture_button := battle_ui.get_node("%CaptureButton") as Button

	if bag_button == null or capture_button == null:
		push_error("Capture game-flow validation could not find bag buttons.")
		quit(1)
		return

	bag_button.emit_signal("pressed")
	await process_frame
	capture_button.emit_signal("pressed")
	await create_timer(0.5).timeout

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene.has_method("force_test_encounter"):
		push_error("Captured battle did not return to the overworld scene.")
		quit(1)
		return

	var ending_party: Array = game_root.get("_player_party")
	var ending_inventory: Dictionary = game_root.get("_inventory")

	if ending_party.size() != starting_party.size() + 1:
		push_error("Captured monster was not synced back to GameManager party.")
		quit(1)
		return

	if int(ending_inventory.get("capture_capsule", -1)) != int(starting_inventory.get("capture_capsule", 0)) - 1:
		push_error("Capture Capsule count was not synced back to GameManager inventory.")
		quit(1)
		return

	print("Capture game flow validation passed: party size %d -> %d." % [starting_party.size(), ending_party.size()])

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	quit()
