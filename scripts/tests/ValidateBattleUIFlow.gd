extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle_ui_scene := load("res://scenes/battle/BattleUI.tscn") as PackedScene

	if battle_ui_scene == null:
		push_error("Failed to load BattleUI.tscn.")
		quit(1)
		return

	var battle_ui := battle_ui_scene.instantiate()
	get_root().add_child(battle_ui)

	await process_frame

	var fight_button := battle_ui.get_node("%FightButton") as Button
	var move_button := battle_ui.get_node("%MoveButton1") as Button

	if fight_button == null or move_button == null:
		push_error("Battle UI command buttons were not found.")
		quit(1)
		return

	fight_button.emit_signal("pressed")
	await process_frame
	move_button.emit_signal("pressed")

	await create_timer(3.0).timeout
	print("Battle UI flow smoke test completed.")
	quit()
