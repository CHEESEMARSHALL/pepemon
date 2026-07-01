extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(512, 384)
	var battle_ui_scene := load("res://scenes/battle/BattleUI.tscn") as PackedScene

	if battle_ui_scene == null:
		push_error("Failed to load BattleUI.tscn.")
		quit(1)
		return

	var battle_ui := battle_ui_scene.instantiate() as Control
	get_root().add_child(battle_ui)
	await process_frame
	await process_frame

	var enemy_panel := battle_ui.get_node("BattleField/EnemyPanel") as Control
	var enemy_sprite := battle_ui.get_node("%EnemyBattleSprite") as Control
	var player_panel := battle_ui.get_node("BattleField/PlayerPanel") as Control
	var player_sprite := battle_ui.get_node("%PlayerBattleSprite") as Control
	var bottom_panel := battle_ui.get_node("BottomPanel") as Control
	var command_menu := battle_ui.get_node("%CommandMenu") as Control
	var message_panel := battle_ui.get_node("BottomPanel/MessagePanel") as Control

	if enemy_panel == null or enemy_sprite == null or player_panel == null or player_sprite == null or bottom_panel == null or command_menu == null or message_panel == null:
		push_error("Battle layout validation could not find required UI nodes.")
		quit(1)
		return

	var enemy_panel_rect := enemy_panel.get_global_rect()
	var enemy_sprite_rect := enemy_sprite.get_global_rect()
	var player_panel_rect := player_panel.get_global_rect()
	var player_sprite_rect := player_sprite.get_global_rect()
	var bottom_panel_rect := bottom_panel.get_global_rect()
	var command_menu_rect := command_menu.get_global_rect()
	var message_panel_rect := message_panel.get_global_rect()

	if enemy_panel_rect.position.x >= enemy_sprite_rect.position.x or enemy_panel_rect.position.y >= enemy_sprite_rect.position.y:
		push_error("Enemy status should sit above-left of the enemy sprite.")
		quit(1)
		return

	if player_sprite_rect.position.x >= player_panel_rect.position.x or player_sprite_rect.position.y >= player_panel_rect.position.y:
		push_error("Player sprite should sit left and above the player status panel.")
		quit(1)
		return

	if bottom_panel_rect.position.y <= player_panel_rect.end.y:
		push_error("Command/message panel should be anchored below the battle stage.")
		quit(1)
		return

	if message_panel_rect.position.x >= command_menu_rect.position.x:
		push_error("Message panel should sit to the left of the command menu.")
		quit(1)
		return

	if player_sprite.texture == null or enemy_sprite.texture == null:
		push_error("Battle layout validation expected visible monster sprites.")
		quit(1)
		return

	print("Battle UI layout validation passed: classic opposing HUD, sprite, and command positions are intact.")
	quit()
