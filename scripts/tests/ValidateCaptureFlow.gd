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
	battle_ui.message_time = 0.01
	get_root().add_child(battle_ui)
	await process_frame

	var battle_manager := battle_ui.get_node("BattleManager") as BattleManager
	var starting_party_size := battle_manager.get_player_party().size()
	var bag_button := battle_ui.get_node("%BagButton") as Button
	var capture_button := battle_ui.get_node("%CaptureButton") as Button

	if battle_manager == null or bag_button == null or capture_button == null:
		push_error("Capture validation could not find the battle manager or bag buttons.")
		quit(1)
		return

	bag_button.emit_signal("pressed")
	await process_frame
	capture_button.emit_signal("pressed")
	await create_timer(0.2).timeout

	if battle_manager.state != battle_manager.BattleState.CAPTURED:
		push_error("Capture item did not end the battle in CAPTURED state.")
		quit(1)
		return

	var ending_party_size := battle_manager.get_player_party().size()

	if ending_party_size != starting_party_size + 1:
		push_error("Captured monster was not added to the player's party.")
		quit(1)
		return

	print("Capture flow validation passed: party size %d -> %d." % [starting_party_size, ending_party_size])
	quit()
