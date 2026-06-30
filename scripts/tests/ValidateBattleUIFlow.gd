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
	var player_sprite := battle_ui.get_node("%PlayerBattleSprite") as TextureRect
	var enemy_sprite := battle_ui.get_node("%EnemyBattleSprite") as TextureRect
	var player_placeholder := battle_ui.get_node("%PlayerSpritePlaceholder") as CanvasItem
	var enemy_placeholder := battle_ui.get_node("%EnemySpritePlaceholder") as CanvasItem

	if fight_button == null or move_button == null or player_sprite == null or enemy_sprite == null:
		push_error("Battle UI command buttons or monster sprites were not found.")
		quit(1)
		return

	if player_sprite.texture == null or enemy_sprite.texture == null:
		push_error("Battle UI did not assign monster battle sprites.")
		quit(1)
		return

	if player_placeholder == null or enemy_placeholder == null or player_placeholder.visible or enemy_placeholder.visible:
		push_error("Battle UI placeholders should be hidden when monster sprites are available.")
		quit(1)
		return

	fight_button.emit_signal("pressed")
	await process_frame
	move_button.emit_signal("pressed")

	await create_timer(3.0).timeout
	print("Battle UI flow smoke test completed.")
	quit()
