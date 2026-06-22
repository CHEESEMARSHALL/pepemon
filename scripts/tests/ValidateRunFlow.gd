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
	var overworld := scene_root.get_child(0)

	if overworld == null or not overworld.has_method("force_test_encounter"):
		push_error("Run validation did not start in overworld.")
		quit(1)
		return

	overworld.call("force_test_encounter")
	await process_frame
	await process_frame

	var battle_ui := scene_root.get_child(0) as BattleUI

	if battle_ui == null:
		push_error("Run validation did not transition to BattleUI.")
		quit(1)
		return

	var run_button := battle_ui.get_node("%RunButton") as Button

	if run_button == null:
		push_error("Run button was not found.")
		quit(1)
		return

	run_button.emit_signal("pressed")
	await create_timer(1.0).timeout

	var active_scene := scene_root.get_child(0)

	if active_scene == null or not active_scene.has_method("force_test_encounter"):
		push_error("Run did not return to overworld.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	print("Run flow validation passed: battle escaped to overworld.")
	quit()
