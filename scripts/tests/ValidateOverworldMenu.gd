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

	if not game_root.has_method("open_overworld_menu") or not game_root.has_method("is_overworld_menu_open"):
		push_error("GameRoot does not expose overworld menu methods.")
		quit(1)
		return

	game_root.call("open_overworld_menu", "party")
	await process_frame

	var content_label := game_root.get_node("%MenuContentLabel") as Label
	var title_label := game_root.get_node("%MenuTitleLabel") as Label
	var scene_root := game_root.get_node("%SceneRoot")
	var overworld_scene := scene_root.get_child(0)
	var player := overworld_scene.find_child("Player", true, false) as PlayerController

	if not bool(game_root.call("is_overworld_menu_open")):
		push_error("Overworld menu did not open.")
		quit(1)
		return

	if player == null or player.movement_enabled:
		push_error("Opening the overworld menu did not lock player movement.")
		quit(1)
		return

	if title_label.text != "Party" or not content_label.text.contains("Emberling") or not content_label.text.contains("Aquabbit") or not content_label.text.contains("XP to next"):
		push_error("Overworld menu did not render the starter party.")
		quit(1)
		return

	var second_leader_button := game_root.get_node("%LeaderButton2") as Button

	if second_leader_button == null:
		push_error("Overworld menu did not expose party leader buttons.")
		quit(1)
		return

	second_leader_button.emit_signal("pressed")
	await process_frame

	var active_monster = game_root.get("_player_monster")

	if active_monster == null or not str(active_monster.call("get_display_name")).contains("Aquabbit") or not content_label.text.contains("* Aquabbit"):
		push_error("Overworld menu did not switch the active party leader.")
		quit(1)
		return

	var player_party: Array = game_root.get("_player_party")

	for monster in player_party:
		monster.current_hp = maxi(1, monster.get_max_hp() - 7)
		monster.spend_move_pp(0)

	var rest_party_button := game_root.get_node("%RestPartyButton") as Button

	if rest_party_button == null:
		push_error("Overworld menu did not expose the rest action.")
		quit(1)
		return

	rest_party_button.emit_signal("pressed")
	await process_frame

	for monster in player_party:
		if int(monster.current_hp) != int(monster.get_max_hp()) or int(monster.get_move_pp(0)) != int(monster.get_move_max_pp_at(0)):
			push_error("Rest action did not restore party HP and PP.")
			quit(1)
			return

	if title_label.text != "Party Rested" or not content_label.text.contains("Restored"):
		push_error("Overworld menu did not report party rest.")
		quit(1)
		return

	game_root.call("open_overworld_menu", "bag")
	await process_frame

	if title_label.text != "Bag" or not content_label.text.contains("Potion x3") or not content_label.text.contains("Capture Capsule x3"):
		push_error("Overworld menu did not render inventory counts.")
		quit(1)
		return

	active_monster.current_hp = active_monster.get_max_hp() - 10
	var use_potion_button := game_root.get_node("%UsePotionButton") as Button

	if use_potion_button == null:
		push_error("Overworld menu did not expose the potion action.")
		quit(1)
		return

	use_potion_button.emit_signal("pressed")
	await process_frame

	var inventory_after_potion: Dictionary = game_root.get("_inventory")

	if int(active_monster.current_hp) != int(active_monster.get_max_hp()) or int(inventory_after_potion.get("potion", -1)) != 2:
		push_error("Overworld menu potion action did not heal the leader and decrement inventory.")
		quit(1)
		return

	if not content_label.text.contains("Used Potion") or not content_label.text.contains("Potion x2"):
		push_error("Overworld menu did not report potion use.")
		quit(1)
		return

	var save_button := game_root.get_node("%SaveButton") as Button
	save_button.emit_signal("pressed")
	await process_frame

	if title_label.text != "Saved":
		push_error("Overworld menu save action did not report success.")
		quit(1)
		return

	game_root.call("close_overworld_menu")
	await process_frame

	if bool(game_root.call("is_overworld_menu_open")):
		push_error("Overworld menu did not close.")
		quit(1)
		return

	var overworld := scene_root.get_child(0)

	if overworld == null or not overworld.has_method("force_test_encounter"):
		push_error("Could not find overworld scene after closing menu.")
		quit(1)
		return

	if player == null or not player.movement_enabled:
		push_error("Closing the overworld menu did not restore player movement.")
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

	var player_name_label := battle_ui.get_node("%PlayerNameLabel") as Label

	if player_name_label == null or not player_name_label.text.contains("Aquabbit"):
		push_error("Battle did not start with the selected party leader.")
		quit(1)
		return

	if test_save_tools != null:
		test_save_tools.clear_main_save()

	print("Overworld menu validation passed: party, bag, potion use, party rest, leader switch, movement lock, save, close.")
	quit()
