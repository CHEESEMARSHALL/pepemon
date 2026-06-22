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

	var battle_manager := battle_ui.get_node("BattleManager") as BattleManager
	var player_instance = battle_manager.get("_player_instance")

	if battle_manager == null or player_instance == null:
		push_error("Bag validation could not read the active player monster.")
		quit(1)
		return

	var max_hp := int(player_instance.call("get_max_hp"))
	player_instance.current_hp = max_hp - 10

	var bag_button := battle_ui.get_node("%BagButton") as Button
	var potion_button := battle_ui.get_node("%PotionButton") as Button

	if bag_button == null or potion_button == null:
		push_error("Bag validation could not find bag buttons.")
		quit(1)
		return

	bag_button.emit_signal("pressed")
	await process_frame
	potion_button.emit_signal("pressed")
	await process_frame

	if int(player_instance.current_hp) != max_hp:
		push_error("Potion did not heal the player monster to full in the bag validation.")
		quit(1)
		return

	print("Bag flow validation passed: Potion healed HP to %d." % max_hp)
	quit()
