extends Control
class_name BattleUI

signal battle_finished(player_won: bool)
signal battle_escaped

const INVENTORY_POTION_KEY := "potion"
const INVENTORY_CAPTURE_KEY := "capture_capsule"

@export var battle_manager_path: NodePath = NodePath("BattleManager")
@export var auto_start_battle := true
@export var hp_animation_time := 0.35
@export var enemy_turn_delay := 0.65
@export var message_time := 0.75
@export var potion_item: Resource
@export var capture_item: Resource
@export_range(0, 99, 1) var potion_count: int = 3
@export_range(0, 99, 1) var capture_count: int = 3

@onready var _battle_manager := get_node(battle_manager_path) as BattleManager
@onready var _player_name_label := %PlayerNameLabel as Label
@onready var _enemy_name_label := %EnemyNameLabel as Label
@onready var _player_hp_label := %PlayerHpLabel as Label
@onready var _enemy_hp_label := %EnemyHpLabel as Label
@onready var _player_health_bar := %PlayerHealthBar as TextureProgressBar
@onready var _enemy_health_bar := %EnemyHealthBar as TextureProgressBar
@onready var _message_label := %MessageLabel as Label
@onready var _fight_button := %FightButton as Button
@onready var _bag_button := %BagButton as Button
@onready var _monster_button := %MonsterButton as Button
@onready var _run_button := %RunButton as Button
@onready var _move_menu := %MoveMenu as GridContainer
@onready var _bag_menu := %BagMenu as GridContainer
@onready var _party_menu := %PartyMenu as GridContainer
@onready var _potion_button := %PotionButton as Button
@onready var _capture_button := %CaptureButton as Button
@onready var _bag_back_button := %BagBackButton as Button
@onready var _party_back_button := %PartyBackButton as Button
@onready var _move_buttons: Array[Button] = [
	%MoveButton1,
	%MoveButton2,
	%MoveButton3,
	%MoveButton4,
	%MoveButton5,
	%MoveButton6,
]
@onready var _party_buttons: Array[Button] = [
	%PartyButton1,
	%PartyButton2,
	%PartyButton3,
	%PartyButton4,
	%PartyButton5,
	%PartyButton6,
]

var _player_max_hp := 1
var _enemy_max_hp := 1
var _player_moves: Array[Resource] = []
var _player_party: Array[Resource] = []
var _message_queue: Array[String] = []
var _pending_battle_result := ""


func _ready() -> void:
	_connect_battle_manager()
	_connect_command_menu()
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)
	_update_bag_menu()
	_battle_manager.wait_for_ui_after_actions = true

	if auto_start_battle:
		_battle_manager.start_battle()


func start_battle(player_monster, enemy_monster: Resource, active_player_index: int = 0) -> void:
	_battle_manager.start_battle(player_monster, enemy_monster, active_player_index)


func get_player_party() -> Array[Resource]:
	return _battle_manager.get_player_party()


func get_active_player_index() -> int:
	return _battle_manager.get_active_player_index()


func configure_inventory(item_counts: Dictionary) -> void:
	potion_count = max(0, int(item_counts.get(INVENTORY_POTION_KEY, potion_count)))
	capture_count = max(0, int(item_counts.get(INVENTORY_CAPTURE_KEY, capture_count)))

	if is_node_ready():
		_update_bag_menu()


func get_inventory_counts() -> Dictionary:
	return {
		INVENTORY_POTION_KEY: potion_count,
		INVENTORY_CAPTURE_KEY: capture_count,
	}


func _connect_battle_manager() -> void:
	_battle_manager.battle_started.connect(_on_battle_started)
	_battle_manager.turn_changed.connect(_on_turn_changed)
	_battle_manager.move_used.connect(_on_move_used)
	_battle_manager.move_missed.connect(_on_move_missed)
	_battle_manager.move_failed.connect(_on_move_failed)
	_battle_manager.move_pp_changed.connect(_on_move_pp_changed)
	_battle_manager.effectiveness_resolved.connect(_on_effectiveness_resolved)
	_battle_manager.monster_damaged.connect(_on_monster_damaged)
	_battle_manager.item_used.connect(_on_item_used)
	_battle_manager.item_failed.connect(_on_item_failed)
	_battle_manager.monster_healed.connect(_on_monster_healed)
	_battle_manager.capture_attempted.connect(_on_capture_attempted)
	_battle_manager.capture_failed.connect(_on_capture_failed)
	_battle_manager.monster_captured.connect(_on_monster_captured)
	_battle_manager.player_monster_switched.connect(_on_player_monster_switched)
	_battle_manager.player_monster_fainted.connect(_on_player_monster_fainted)
	_battle_manager.switch_failed.connect(_on_switch_failed)
	_battle_manager.experience_awarded.connect(_on_experience_awarded)
	_battle_manager.monster_leveled_up.connect(_on_monster_leveled_up)
	_battle_manager.monster_learned_move.connect(_on_monster_learned_move)
	_battle_manager.action_resolved.connect(_on_action_resolved)
	_battle_manager.battle_escaped.connect(_on_battle_escaped)
	_battle_manager.battle_finished.connect(_on_battle_finished)


func _connect_command_menu() -> void:
	_fight_button.pressed.connect(_on_fight_pressed)
	_bag_button.pressed.connect(_on_bag_pressed)
	_monster_button.pressed.connect(_on_monster_pressed)
	_run_button.pressed.connect(_on_run_pressed)
	_potion_button.pressed.connect(_on_potion_pressed)
	_capture_button.pressed.connect(_on_capture_pressed)
	_bag_back_button.pressed.connect(_on_bag_back_pressed)
	_party_back_button.pressed.connect(_on_party_back_pressed)

	for index in _move_buttons.size():
		_move_buttons[index].pressed.connect(_on_move_button_pressed.bind(index))

	for index in _party_buttons.size():
		_party_buttons[index].pressed.connect(_on_party_button_pressed.bind(index))


func _on_battle_started(player_monster: Resource, enemy_monster: Resource, player_hp: int, enemy_hp: int) -> void:
	_player_max_hp = max(1, player_hp)
	_enemy_max_hp = max(1, enemy_hp)

	_player_name_label.text = _get_monster_label(player_monster)
	_enemy_name_label.text = _get_monster_label(enemy_monster)
	_player_party = _battle_manager.get_player_party()
	_player_moves = _get_moves(player_monster)
	_populate_move_menu()
	_populate_party_menu()
	_setup_health_bar(_player_health_bar, _player_max_hp, player_hp)
	_setup_health_bar(_enemy_health_bar, _enemy_max_hp, enemy_hp)
	_update_hp_label(_player_hp_label, player_hp, _player_max_hp)
	_update_hp_label(_enemy_hp_label, enemy_hp, _enemy_max_hp)
	_message_label.text = "A battle started!"


func _on_turn_changed(_state: int, actor: String) -> void:
	if actor == "player":
		_party_back_button.disabled = false
		_message_label.text = "What will you do?"
		_set_command_menu_enabled(true)
		_set_move_menu_visible(false)
		_set_bag_menu_visible(false)
		_set_party_menu_visible(false)
		return

	_message_label.text = "Enemy is choosing a move..."
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)
	await get_tree().create_timer(enemy_turn_delay).timeout
	_battle_manager.advance_turn()


func _on_move_used(_actor: String, attacker_name: String, move_name: String) -> void:
	_queue_message("%s used %s!" % [attacker_name, move_name])


func _on_move_missed(_actor: String, attacker_name: String) -> void:
	_queue_message("%s's attack missed!" % attacker_name)


func _on_move_failed(_actor: String, _attacker_name: String, reason: String) -> void:
	_queue_message(reason)


func _on_move_pp_changed(actor: String, move_index: int, current_pp: int, max_pp: int) -> void:
	if actor != "player":
		return

	if move_index < 0 or move_index >= _move_buttons.size():
		return

	_move_buttons[move_index].text = "%s %d/%d" % [_get_move_name(_player_moves[move_index]), current_pp, max_pp]
	_move_buttons[move_index].disabled = current_pp <= 0


func _on_effectiveness_resolved(multiplier: float) -> void:
	if multiplier > 1.0:
		_queue_message("It's super effective!")
	elif multiplier > 0.0 and multiplier < 1.0:
		_queue_message("It's not very effective...")


func _on_monster_damaged(target: String, current_hp: int, max_hp: int, damage: int) -> void:
	if target == "player":
		_animate_health_bar(_player_health_bar, current_hp)
		_update_hp_label(_player_hp_label, current_hp, max_hp)
		_queue_message("%s took %d damage." % [_player_name_label.text, damage])
	else:
		_animate_health_bar(_enemy_health_bar, current_hp)
		_update_hp_label(_enemy_hp_label, current_hp, max_hp)
		_queue_message("%s took %d damage." % [_enemy_name_label.text, damage])


func _on_item_used(_actor: String, item_name: String, target_name: String) -> void:
	_queue_message("Used %s on %s." % [item_name, target_name])


func _on_item_failed(_actor: String, reason: String) -> void:
	_queue_message(reason)


func _on_monster_healed(target: String, current_hp: int, max_hp: int, amount: int) -> void:
	if target != "player":
		return

	_animate_health_bar(_player_health_bar, current_hp)
	_update_hp_label(_player_hp_label, current_hp, max_hp)
	_queue_message("%s recovered %d HP." % [_player_name_label.text, amount])
	_populate_party_menu()


func _on_capture_attempted(item_name: String, target_name: String) -> void:
	_queue_message("Used %s!" % item_name)
	_queue_message("Trying to catch %s..." % target_name)


func _on_capture_failed(_item_name: String, target_name: String) -> void:
	_queue_message("%s broke free!" % target_name)


func _on_monster_captured(captured_monster: Resource) -> void:
	_player_party = _battle_manager.get_player_party()
	_populate_party_menu()
	_pending_battle_result = "%s was caught!" % _get_monster_name(captured_monster)
	_queue_message("Gotcha!")
	_queue_message(_pending_battle_result)


func _on_player_monster_switched(previous_name: String, new_name: String, current_hp: int, max_hp: int) -> void:
	_player_name_label.text = _get_monster_label(_battle_manager.get("_player_instance"))
	_player_max_hp = max(1, max_hp)
	_player_moves = _get_moves(_battle_manager.get("_player_instance"))
	_setup_health_bar(_player_health_bar, _player_max_hp, current_hp)
	_update_hp_label(_player_hp_label, current_hp, _player_max_hp)
	_populate_move_menu()
	_populate_party_menu()
	_queue_message("%s, come back!" % previous_name)
	_queue_message("Go, %s!" % new_name)


func _on_player_monster_fainted(monster_name: String) -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(true)
	_party_back_button.disabled = true
	_populate_party_menu()
	_queue_message("%s fainted!" % monster_name)
	_message_label.text = "Choose another monster."


func _on_switch_failed(reason: String) -> void:
	_queue_message(reason)


func _on_experience_awarded(monster_name: String, amount: int) -> void:
	_queue_message("%s gained %d XP." % [monster_name, amount])


func _on_monster_leveled_up(monster_name: String, _previous_level: int, new_level: int) -> void:
	_queue_message("%s grew to level %d!" % [monster_name, new_level])


func _on_monster_learned_move(monster_name: String, move_name: String) -> void:
	_queue_message("%s learned %s!" % [monster_name, move_name])
	_player_moves = _get_moves(_battle_manager.get("_player_instance"))
	_populate_move_menu()


func _on_action_resolved(_actor: String) -> void:
	await _play_message_queue()
	_battle_manager.continue_after_action()


func _on_battle_finished(player_won: bool) -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)

	if player_won:
		if _pending_battle_result.is_empty():
			_pending_battle_result = "You won!"
	else:
		_pending_battle_result = "You lost..."

	await _play_message_queue()
	_message_label.text = _pending_battle_result
	_pending_battle_result = ""
	battle_finished.emit(player_won)


func _on_battle_escaped() -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)
	_message_queue.clear()
	_message_label.text = "Got away safely!"
	await get_tree().create_timer(message_time).timeout
	battle_escaped.emit()


func _on_fight_pressed() -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(true)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)
	_message_label.text = "Choose a move."


func _on_move_button_pressed(move_index: int) -> void:
	_set_move_menu_visible(false)
	_battle_manager.use_player_move(move_index)


func _on_bag_pressed() -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(true)
	_set_party_menu_visible(false)
	_update_bag_menu()
	_message_label.text = "Choose an item."


func _on_potion_pressed() -> void:
	if potion_count <= 0:
		_queue_message("No Potions left.")
		await _play_message_queue()
		_set_command_menu_enabled(true)
		_set_bag_menu_visible(false)
		return

	var used_item := _battle_manager.use_item(potion_item)

	if used_item:
		potion_count -= 1
		_update_bag_menu()
		_set_bag_menu_visible(false)
	else:
		await _play_message_queue()
		_set_command_menu_enabled(true)
		_set_bag_menu_visible(false)


func _on_capture_pressed() -> void:
	if capture_count <= 0:
		_queue_message("No Capture Capsules left.")
		await _play_message_queue()
		_set_command_menu_enabled(true)
		_set_bag_menu_visible(false)
		return

	var used_item := _battle_manager.try_capture(capture_item)

	if used_item:
		capture_count -= 1
		_update_bag_menu()
		_set_bag_menu_visible(false)
	else:
		await _play_message_queue()
		_set_command_menu_enabled(true)
		_set_bag_menu_visible(false)


func _on_bag_back_pressed() -> void:
	_set_bag_menu_visible(false)
	_set_command_menu_enabled(true)
	_message_label.text = "What will you do?"


func _on_monster_pressed() -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(true)
	_party_back_button.disabled = false
	_populate_party_menu()
	_message_label.text = "Choose a monster."


func _on_party_button_pressed(party_index: int) -> void:
	var switched := _battle_manager.switch_player_monster(party_index)

	if switched:
		_set_party_menu_visible(false)
	else:
		await _play_message_queue()
		if _party_back_button.disabled:
			_set_party_menu_visible(true)
			_populate_party_menu()
			_message_label.text = "Choose another monster."
		else:
			_set_command_menu_enabled(true)
			_set_party_menu_visible(false)


func _on_party_back_pressed() -> void:
	_set_party_menu_visible(false)
	_set_command_menu_enabled(true)
	_message_label.text = "What will you do?"


func _on_run_pressed() -> void:
	_set_command_menu_enabled(false)
	_set_move_menu_visible(false)
	_set_bag_menu_visible(false)
	_set_party_menu_visible(false)
	_battle_manager.try_run()


func _setup_health_bar(health_bar: TextureProgressBar, max_hp: int, current_hp: int) -> void:
	health_bar.min_value = 0
	health_bar.max_value = max_hp
	health_bar.value = current_hp


func _animate_health_bar(health_bar: TextureProgressBar, current_hp: int) -> void:
	var tween := create_tween()
	tween.tween_property(health_bar, "value", current_hp, hp_animation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_hp_label(label: Label, current_hp: int, max_hp: int) -> void:
	label.text = "%d/%d" % [current_hp, max_hp]


func _set_command_menu_enabled(is_enabled: bool) -> void:
	_fight_button.disabled = not is_enabled
	_bag_button.disabled = not is_enabled
	_monster_button.disabled = not is_enabled
	_run_button.disabled = not is_enabled


func _set_move_menu_visible(is_visible: bool) -> void:
	_move_menu.visible = is_visible


func _set_bag_menu_visible(is_visible: bool) -> void:
	_bag_menu.visible = is_visible


func _set_party_menu_visible(is_visible: bool) -> void:
	_party_menu.visible = is_visible


func _update_bag_menu() -> void:
	_potion_button.text = "Potion x%d" % potion_count
	_potion_button.disabled = potion_count <= 0
	_capture_button.text = "Capture Capsule x%d" % capture_count
	_capture_button.disabled = capture_count <= 0


func _populate_party_menu() -> void:
	var active_index := _battle_manager.get_active_player_index()

	for index in _party_buttons.size():
		var button := _party_buttons[index]
		var has_monster := index < _player_party.size()

		button.visible = has_monster
		button.disabled = not has_monster

		if has_monster:
			var monster := _player_party[index]
			var current_hp := _get_current_hp(monster)
			var max_hp := _get_max_hp(monster)
			button.text = "%s %d/%d" % [_get_monster_name(monster), current_hp, max_hp]
			button.disabled = index == active_index or current_hp <= 0


func _queue_message(message: String) -> void:
	_message_queue.append(message)


func _play_message_queue() -> void:
	while not _message_queue.is_empty():
		_message_label.text = _message_queue.pop_front()
		await get_tree().create_timer(message_time).timeout


func _populate_move_menu() -> void:
	for index in _move_buttons.size():
		var button := _move_buttons[index]
		var has_move := index < _player_moves.size()

		button.visible = has_move
		button.disabled = not has_move

		if has_move:
			button.text = "%s %d/%d" % [
				_get_move_name(_player_moves[index]),
				_get_move_pp(index),
				_get_move_max_pp(index),
			]


func _get_moves(monster: Resource) -> Array[Resource]:
	if monster != null and monster.has_method("get_moves"):
		return monster.call("get_moves")

	if monster == null:
		return []

	var moves = monster.get("moves")

	if moves is Array:
		var resources: Array[Resource] = []

		for move in moves:
			if move is Resource:
				resources.append(move)

		return resources

	return []


func _get_monster_name(monster: Resource) -> String:
	if monster != null and monster.has_method("get_display_name"):
		return str(monster.call("get_display_name"))

	var monster_name = monster.get("monster_name")

	if monster_name == null or str(monster_name).is_empty():
		return "Unknown"

	return str(monster_name)


func _get_monster_label(monster: Resource) -> String:
	var monster_name := _get_monster_name(monster)

	if monster == null:
		return monster_name

	var monster_level = monster.get("level")

	if monster_level == null:
		return monster_name

	return "%s Lv.%d" % [monster_name, int(monster_level)]


func _get_move_name(move: Resource) -> String:
	if move == null:
		return "Struggle"

	var move_name = move.get("move_name")

	if move_name == null or str(move_name).is_empty():
		return "Struggle"

	return str(move_name)


func _get_move_pp(move_index: int) -> int:
	var monster = _battle_manager.get("_player_instance")

	if monster != null and monster.has_method("get_move_pp"):
		return int(monster.call("get_move_pp", move_index))

	return _get_move_max_pp(move_index)


func _get_move_max_pp(move_index: int) -> int:
	var monster = _battle_manager.get("_player_instance")

	if monster != null and monster.has_method("get_move_max_pp_at"):
		return int(monster.call("get_move_max_pp_at", move_index))

	if move_index < 0 or move_index >= _player_moves.size():
		return 0

	var max_pp = _player_moves[move_index].get("max_pp")

	if max_pp == null:
		return 1

	return max(1, int(max_pp))


func _get_current_hp(monster: Resource) -> int:
	if monster == null:
		return 0

	var hp = monster.get("current_hp")

	if hp == null:
		return _get_max_hp(monster)

	return int(hp)


func _get_max_hp(monster: Resource) -> int:
	if monster != null and monster.has_method("get_max_hp"):
		return int(monster.call("get_max_hp"))

	return max(1, _get_current_hp(monster))
