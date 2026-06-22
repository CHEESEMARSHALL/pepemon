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
	var dialogue_panel := overworld.get_node("%DialoguePanel") as PanelContainer
	var dialogue_label := overworld.get_node("%DialogueLabel") as Label

	if player == null or dialogue_panel == null or dialogue_label == null:
		push_error("Interaction validation could not find player or dialogue nodes.")
		quit(1)
		return

	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("Pepemon Route 1"):
		push_error("Interacting with the sign did not show dialogue.")
		quit(1)
		return

	if player.movement_enabled:
		push_error("Dialogue did not lock player movement.")
		quit(1)
		return

	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	Input.parse_input_event(accept_event)
	await process_frame

	accept_event.pressed = false
	Input.parse_input_event(accept_event)
	await process_frame

	if dialogue_panel.visible or not player.movement_enabled:
		push_error("Closing dialogue did not restore movement.")
		quit(1)
		return

	var position_before_npc_step := player.global_position
	Input.action_press("ui_up")
	await process_frame
	await create_timer(player.move_time + 0.05).timeout
	Input.action_release("ui_up")
	await process_frame

	if not player.global_position.is_equal_approx(position_before_npc_step):
		push_error("Blocked NPC tile allowed the player to move into it.")
		quit(1)
		return

	player.interact()
	await process_frame

	if not dialogue_panel.visible or not dialogue_label.text.contains("Scout Mira"):
		push_error("Facing the NPC did not show NPC dialogue.")
		quit(1)
		return

	print("Overworld interaction validation passed: sign and NPC dialogue open, lock, and close.")
	quit()
