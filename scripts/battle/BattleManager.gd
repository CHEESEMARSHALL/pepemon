extends Node
class_name BattleManager

signal battle_started(player_monster: Resource, enemy_monster: Resource, player_hp: int, enemy_hp: int)
signal turn_changed(state: BattleState, actor: String)
signal move_used(actor: String, attacker_name: String, move_name: String)
signal move_missed(actor: String, attacker_name: String)
signal move_failed(actor: String, attacker_name: String, reason: String)
signal move_pp_changed(actor: String, move_index: int, current_pp: int, max_pp: int)
signal effectiveness_resolved(multiplier: float)
signal monster_damaged(target: String, current_hp: int, max_hp: int, damage: int)
signal item_used(actor: String, item_name: String, target_name: String)
signal item_failed(actor: String, reason: String)
signal monster_healed(target: String, current_hp: int, max_hp: int, amount: int)
signal capture_attempted(item_name: String, target_name: String)
signal capture_failed(item_name: String, target_name: String)
signal monster_captured(captured_monster: Resource)
signal player_monster_switched(previous_name: String, new_name: String, current_hp: int, max_hp: int)
signal player_monster_fainted(monster_name: String)
signal switch_failed(reason: String)
signal experience_awarded(monster_name: String, amount: int)
signal monster_leveled_up(monster_name: String, previous_level: int, new_level: int)
signal monster_learned_move(monster_name: String, move_name: String)
signal action_resolved(actor: String)
signal battle_escaped
signal battle_finished(player_won: bool)

enum BattleState {
	START_BATTLE,
	PLAYER_TURN,
	ENEMY_TURN,
	WIN,
	LOSS,
	ESCAPE,
	CAPTURED,
	FORCE_SWITCH
}

const FALLBACK_MOVE := {
	"move_name": "Struggle",
	"power": 35,
	"move_type": 0,
}

const TYPE_NORMAL := 0
const TYPE_FIRE := 1
const TYPE_WATER := 2
const TYPE_GRASS := 3

@export var player_monster: Resource
@export var enemy_monster: Resource
@export_range(1, 100, 1) var default_player_level: int = 5
@export_range(1, 100, 1) var default_enemy_level: int = 5
@export_range(1, 9999, 1) var base_experience_reward: int = 60
@export_range(1, 6, 1) var max_party_size: int = 6
@export var wait_for_ui_after_actions := false

var state: BattleState = BattleState.START_BATTLE
var turn_queue: Array[String] = []
var _turn_index := 0
var _player_party: Array[Resource] = []
var _active_player_index := 0
var _player_instance: Resource
var _enemy_instance: Resource
var _rng := RandomNumberGenerator.new()
var _force_switch_pending := false


func start_battle(new_player_monster = null, new_enemy_monster: Resource = null, active_player_index: int = 0) -> void:
	_rng.randomize()

	if new_player_monster != null:
		if new_player_monster is Array:
			_player_party = _build_party_instances(new_player_monster)
			player_monster = _player_party[0] if not _player_party.is_empty() else null
		else:
			player_monster = new_player_monster
			_player_party = [_ensure_instance(player_monster, default_player_level)]

	if new_enemy_monster != null:
		enemy_monster = new_enemy_monster

	if _player_party.is_empty() and player_monster != null:
		_player_party = [_ensure_instance(player_monster, default_player_level)]

	if _player_party.is_empty() or enemy_monster == null:
		push_error("BattleManager requires both player_monster and enemy_monster.")
		return

	_active_player_index = _get_first_available_party_index(active_player_index)
	_player_instance = _player_party[_active_player_index]
	_enemy_instance = _ensure_instance(enemy_monster, default_enemy_level)

	if _player_instance == null or _enemy_instance == null:
		push_error("BattleManager could not create monster instances.")
		return

	state = BattleState.START_BATTLE
	_turn_index = 0
	_build_turn_queue()

	print("--- Battle started ---")
	print("%s HP: %d" % [_get_monster_name(_player_instance), _get_current_hp(_player_instance)])
	print("%s HP: %d" % [_get_monster_name(_enemy_instance), _get_current_hp(_enemy_instance)])
	print("Turn queue: %s" % str(turn_queue))
	battle_started.emit(_player_instance, _enemy_instance, _get_current_hp(_player_instance), _get_current_hp(_enemy_instance))

	_advance_to_next_turn()


func advance_turn() -> void:
	match state:
		BattleState.PLAYER_TURN:
			_execute_turn("player")
		BattleState.ENEMY_TURN:
			_execute_turn("enemy")
		BattleState.WIN, BattleState.LOSS, BattleState.ESCAPE, BattleState.CAPTURED:
			print("Battle is already finished.")
		BattleState.FORCE_SWITCH:
			_auto_switch_after_faint()
		_:
			_advance_to_next_turn()


func use_player_move(move_index: int) -> void:
	if state != BattleState.PLAYER_TURN:
		print("Cannot use a player move outside PLAYER_TURN.")
		return

	if _is_fainted(_player_instance):
		move_failed.emit("player", "Choose another monster!")
		return

	_execute_turn("player", move_index)


func continue_after_action() -> void:
	if state == BattleState.WIN or state == BattleState.LOSS or state == BattleState.ESCAPE or state == BattleState.CAPTURED:
		return

	if state == BattleState.FORCE_SWITCH and _force_switch_pending:
		return

	_advance_to_next_turn()


func try_run() -> void:
	if state != BattleState.PLAYER_TURN:
		print("Cannot run outside PLAYER_TURN.")
		return

	state = BattleState.ESCAPE
	print("State: ESCAPE")
	print("Got away safely!")
	battle_escaped.emit()


func use_item(item: Resource) -> bool:
	if state != BattleState.PLAYER_TURN:
		item_failed.emit("player", "You cannot use an item right now.")
		return false

	if item == null:
		item_failed.emit("player", "No item was selected.")
		return false

	if not bool(item.get("usable_in_battle")):
		item_failed.emit("player", "%s cannot be used in battle." % _get_item_name(item))
		return false

	if _is_capture_item(item):
		return try_capture(item)

	var heal_amount := _get_item_heal_amount(item)

	if heal_amount <= 0:
		item_failed.emit("player", "%s had no effect." % _get_item_name(item))
		return false

	if _get_current_hp(_player_instance) >= _get_max_hp(_player_instance):
		item_failed.emit("player", "It won't have any effect.")
		return false

	var actual_heal := _heal_monster(_player_instance, heal_amount)
	print("Used %s on %s." % [_get_item_name(item), _get_monster_name(_player_instance)])
	print("%s recovered %d HP." % [_get_monster_name(_player_instance), actual_heal])
	item_used.emit("player", _get_item_name(item), _get_monster_name(_player_instance))
	monster_healed.emit("player", _get_current_hp(_player_instance), _get_max_hp(_player_instance), actual_heal)
	_finish_action("player")
	return true


func try_capture(item: Resource) -> bool:
	if state != BattleState.PLAYER_TURN:
		item_failed.emit("player", "You cannot use that right now.")
		return false

	if item == null:
		item_failed.emit("player", "No capture item was selected.")
		return false

	if not _is_capture_item(item):
		item_failed.emit("player", "%s cannot capture monsters." % _get_item_name(item))
		return false

	if _player_party.size() >= max_party_size:
		item_failed.emit("player", "Your party is full.")
		return false

	var item_name := _get_item_name(item)
	var target_name := _get_monster_name(_enemy_instance)
	print("Used %s on %s." % [item_name, target_name])
	capture_attempted.emit(item_name, target_name)

	if _roll_capture(item):
		var captured_monster := _clone_captured_monster(_enemy_instance)

		if captured_monster == null:
			item_failed.emit("player", "Capture failed.")
			_finish_action("player")
			return false

		_player_party.append(captured_monster)
		state = BattleState.CAPTURED
		print("State: CAPTURED")
		print("Caught %s!" % _get_monster_name(captured_monster))
		monster_captured.emit(captured_monster)
		battle_finished.emit(true)
		return true

	print("%s broke free!" % target_name)
	capture_failed.emit(item_name, target_name)
	_finish_action("player")
	return true


func switch_player_monster(party_index: int) -> bool:
	var is_forced_switch := state == BattleState.FORCE_SWITCH

	if state != BattleState.PLAYER_TURN and not is_forced_switch:
		switch_failed.emit("You cannot switch right now.")
		return false

	if party_index < 0 or party_index >= _player_party.size():
		switch_failed.emit("That monster is not in your party.")
		return false

	if party_index == _active_player_index:
		switch_failed.emit("%s is already in battle." % _get_monster_name(_player_instance))
		return false

	var next_monster := _player_party[party_index]

	if _is_fainted(next_monster):
		switch_failed.emit("%s cannot battle." % _get_monster_name(next_monster))
		return false

	var previous_name := _get_monster_name(_player_instance)
	_active_player_index = party_index
	_player_instance = next_monster
	_build_turn_queue()

	print("Switched from %s to %s." % [previous_name, _get_monster_name(_player_instance)])
	player_monster_switched.emit(previous_name, _get_monster_name(_player_instance), _get_current_hp(_player_instance), _get_max_hp(_player_instance))

	if is_forced_switch:
		_force_switch_pending = false
		_turn_index = 0

		if wait_for_ui_after_actions:
			action_resolved.emit("player")
		else:
			_advance_to_next_turn()
	else:
		_finish_action("player")

	return true


func get_player_party() -> Array[Resource]:
	return _player_party


func get_active_player_index() -> int:
	return _active_player_index


func run_battle_to_end(max_turns: int = 100) -> void:
	var turns_taken := 0

	while state != BattleState.WIN and state != BattleState.LOSS and state != BattleState.ESCAPE and state != BattleState.CAPTURED:
		if turns_taken >= max_turns:
			push_error("Battle stopped after max_turns to avoid an infinite loop.")
			return

		advance_turn()
		turns_taken += 1


func calculate_damage(attacker: Resource, defender: Resource, move: Resource) -> int:
	var attack := float(_get_stat(attacker, "attack"))
	var defense := maxf(1.0, float(_get_stat(defender, "defense")))
	var move_power := float(_get_move_power(move))
	var type_multiplier := _get_type_effectiveness(move, defender)

	return max(1, roundi((attack / defense) * move_power * type_multiplier))


func _execute_turn(actor: String, move_index: int = 0) -> void:
	var attacker := _player_instance if actor == "player" else _enemy_instance
	var defender := _enemy_instance if actor == "player" else _player_instance
	var move := _choose_move(attacker, move_index)

	if move != null and not _spend_move_pp(attacker, move_index):
		var fail_reason := "%s has no PP left!" % _get_move_name(move)
		print(fail_reason)
		move_failed.emit(actor, _get_monster_name(attacker), fail_reason)
		_finish_action(actor)
		return

	if move != null:
		move_pp_changed.emit(actor, move_index, _get_move_pp(attacker, move_index), _get_move_max_pp(attacker, move_index))

	print("%s used %s!" % [_get_monster_name(attacker), _get_move_name(move)])
	move_used.emit(actor, _get_monster_name(attacker), _get_move_name(move))

	if not _does_move_hit(move):
		print("%s's attack missed!" % _get_monster_name(attacker))
		move_missed.emit(actor, _get_monster_name(attacker))
		_finish_action(actor)
		return

	var damage := calculate_damage(attacker, defender, move)
	var type_multiplier := _get_type_effectiveness(move, defender)
	var actual_damage := _take_damage(defender, damage)

	print("%s took %d damage." % [_get_monster_name(defender), actual_damage])
	_print_effectiveness(type_multiplier)
	effectiveness_resolved.emit(type_multiplier)

	if actor == "player":
		monster_damaged.emit("enemy", _get_current_hp(_enemy_instance), _get_max_hp(_enemy_instance), actual_damage)
	else:
		monster_damaged.emit("player", _get_current_hp(_player_instance), _get_max_hp(_player_instance), actual_damage)

	print("%s HP: %d | %s HP: %d" % [
		_get_monster_name(_player_instance),
		_get_current_hp(_player_instance),
		_get_monster_name(_enemy_instance),
		_get_current_hp(_enemy_instance),
	])

	if _check_for_battle_end():
		return

	if actor == "enemy" and _is_fainted(_player_instance):
		_start_forced_switch()
		return

	_finish_action(actor)


func _finish_action(actor: String) -> void:
	_turn_index += 1

	if wait_for_ui_after_actions:
		action_resolved.emit(actor)
	else:
		_advance_to_next_turn()


func _advance_to_next_turn() -> void:
	if turn_queue.is_empty():
		push_error("BattleManager turn queue is empty.")
		return

	if _turn_index >= turn_queue.size():
		_turn_index = 0
		_build_turn_queue()
		print("--- New round ---")
		print("Turn queue: %s" % str(turn_queue))

	var next_actor := turn_queue[_turn_index]

	if next_actor == "player":
		state = BattleState.PLAYER_TURN
		print("State: PLAYER_TURN")
	else:
		state = BattleState.ENEMY_TURN
		print("State: ENEMY_TURN")

	turn_changed.emit(state, next_actor)


func _build_turn_queue() -> void:
	var player_speed := _get_stat(_player_instance, "speed")
	var enemy_speed := _get_stat(_enemy_instance, "speed")

	if player_speed >= enemy_speed:
		turn_queue = ["player", "enemy"]
	else:
		turn_queue = ["enemy", "player"]


func _check_for_battle_end() -> bool:
	if _is_fainted(_enemy_instance):
		state = BattleState.WIN
		print("State: WIN")
		print("%s wins!" % _get_monster_name(_player_instance))
		_award_win_experience()
		battle_finished.emit(true)
		return true

	if _are_all_player_monsters_fainted():
		state = BattleState.LOSS
		print("State: LOSS")
		print("%s wins!" % _get_monster_name(_enemy_instance))
		battle_finished.emit(false)
		return true

	return false


func _start_forced_switch() -> void:
	_turn_index += 1
	state = BattleState.FORCE_SWITCH
	_force_switch_pending = true
	print("%s fainted!" % _get_monster_name(_player_instance))
	print("State: FORCE_SWITCH")
	player_monster_fainted.emit(_get_monster_name(_player_instance))


func _auto_switch_after_faint() -> void:
	var switch_index := _get_first_available_switch_index()

	if switch_index < 0:
		_check_for_battle_end()
		return

	switch_player_monster(switch_index)


func _choose_move(monster: Resource, move_index: int = 0) -> Resource:
	var moves = monster.call("get_moves") if monster.has_method("get_moves") else monster.get("moves")

	if moves is Array and not moves.is_empty():
		var clamped_index := clampi(move_index, 0, moves.size() - 1)

		if moves[clamped_index] is Resource:
			return moves[clamped_index]

	return null


func _get_stat(monster: Resource, stat_name: String) -> int:
	if monster != null and monster.has_method("get_stat"):
		return int(monster.call("get_stat", stat_name))

	var stats = monster.call("get_base_stats")

	if stats is Dictionary and stats.has(stat_name):
		return int(stats[stat_name])

	return 1


func _get_monster_name(monster: Resource) -> String:
	if monster != null and monster.has_method("get_display_name"):
		return str(monster.call("get_display_name"))

	var monster_name = monster.get("monster_name")

	if monster_name == null or str(monster_name).is_empty():
		return "Unknown Monster"

	return str(monster_name)


func _get_move_name(move: Resource) -> String:
	if move == null:
		return FALLBACK_MOVE["move_name"]

	var move_name = move.get("move_name")

	if move_name == null or str(move_name).is_empty():
		return FALLBACK_MOVE["move_name"]

	return str(move_name)


func _get_move_power(move: Resource) -> int:
	if move == null:
		return FALLBACK_MOVE["power"]

	var power = move.get("power")

	if power == null:
		return FALLBACK_MOVE["power"]

	return max(1, int(power))


func _get_move_type(move: Resource) -> int:
	if move == null:
		return FALLBACK_MOVE["move_type"]

	var move_type = move.get("move_type")

	if move_type == null:
		return FALLBACK_MOVE["move_type"]

	return int(move_type)


func _get_move_accuracy(move: Resource) -> float:
	if move == null:
		return 1.0

	var accuracy = move.get("accuracy")

	if accuracy == null:
		return 1.0

	return clampf(float(accuracy), 0.0, 1.0)


func _does_move_hit(move: Resource) -> bool:
	return _rng.randf() <= _get_move_accuracy(move)


func _get_type_effectiveness(move: Resource, defender: Resource) -> float:
	var multiplier := 1.0
	var move_type := _get_move_type(move)
	var defender_types := _get_monster_types(defender)

	for defender_type in defender_types:
		multiplier *= _get_single_type_multiplier(move_type, defender_type)

	return multiplier


func _get_single_type_multiplier(move_type: int, defender_type: int) -> float:
	match move_type:
		TYPE_FIRE:
			if defender_type == TYPE_GRASS:
				return 2.0
			if defender_type == TYPE_WATER or defender_type == TYPE_FIRE:
				return 0.5
		TYPE_WATER:
			if defender_type == TYPE_FIRE:
				return 2.0
			if defender_type == TYPE_GRASS or defender_type == TYPE_WATER:
				return 0.5
		TYPE_GRASS:
			if defender_type == TYPE_WATER:
				return 2.0
			if defender_type == TYPE_FIRE or defender_type == TYPE_GRASS:
				return 0.5

	return 1.0


func _get_monster_types(monster: Resource) -> Array[int]:
	if monster == null:
		return []

	if monster.has_method("get_types"):
		return monster.call("get_types")

	return []


func _print_effectiveness(multiplier: float) -> void:
	if multiplier > 1.0:
		print("It's super effective!")
	elif multiplier > 0.0 and multiplier < 1.0:
		print("It's not very effective...")


func _ensure_instance(monster: Resource, level: int) -> Resource:
	if monster == null:
		return null

	if monster.has_method("take_damage") and monster.has_method("get_max_hp"):
		return monster

	var instance := MonsterInstance.new()
	instance.setup(monster, level)
	return instance


func _build_party_instances(party_members: Array) -> Array[Resource]:
	var party: Array[Resource] = []

	for member in party_members:
		if member is Resource:
			var instance := _ensure_instance(member, default_player_level)

			if instance != null:
				party.append(instance)

	return party


func _get_first_available_party_index(preferred_index: int = 0) -> int:
	if preferred_index >= 0 and preferred_index < _player_party.size() and not _is_fainted(_player_party[preferred_index]):
		return preferred_index

	for index in _player_party.size():
		if not _is_fainted(_player_party[index]):
			return index

	return 0


func _get_first_available_switch_index() -> int:
	for index in _player_party.size():
		if index != _active_player_index and not _is_fainted(_player_party[index]):
			return index

	return -1


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

	return _get_stat(monster, "hp")


func _take_damage(monster: Resource, damage: int) -> int:
	if monster != null and monster.has_method("take_damage"):
		return int(monster.call("take_damage", damage))

	return damage


func _heal_monster(monster: Resource, amount: int) -> int:
	if monster != null and monster.has_method("heal"):
		return int(monster.call("heal", amount))

	return 0


func _is_fainted(monster: Resource) -> bool:
	if monster != null and monster.has_method("is_fainted"):
		return bool(monster.call("is_fainted"))

	return _get_current_hp(monster) <= 0


func _are_all_player_monsters_fainted() -> bool:
	for monster in _player_party:
		if not _is_fainted(monster):
			return false

	return true


func _spend_move_pp(monster: Resource, move_index: int) -> bool:
	if monster != null and monster.has_method("spend_move_pp"):
		return bool(monster.call("spend_move_pp", move_index))

	return true


func _get_move_pp(monster: Resource, move_index: int) -> int:
	if monster != null and monster.has_method("get_move_pp"):
		return int(monster.call("get_move_pp", move_index))

	return 1


func _get_move_max_pp(monster: Resource, move_index: int) -> int:
	if monster != null and monster.has_method("get_move_max_pp_at"):
		return int(monster.call("get_move_max_pp_at", move_index))

	return 1


func _award_win_experience() -> void:
	var reward := _calculate_experience_reward(_enemy_instance)

	if reward <= 0:
		return

	print("%s gained %d XP." % [_get_monster_name(_player_instance), reward])
	experience_awarded.emit(_get_monster_name(_player_instance), reward)

	if _player_instance == null or not _player_instance.has_method("gain_experience_and_level_up"):
		return

	var result = _player_instance.call("gain_experience_and_level_up", reward)

	if result is Dictionary and bool(result.get("leveled_up", false)):
		var previous_level := int(result.get("previous_level", 1))
		var new_level := int(result.get("new_level", previous_level))
		print("%s grew to level %d!" % [_get_monster_name(_player_instance), new_level])
		monster_leveled_up.emit(_get_monster_name(_player_instance), previous_level, new_level)

		var learned_moves = result.get("learned_moves", [])

		if learned_moves is Array:
			for move_name in learned_moves:
				print("%s learned %s!" % [_get_monster_name(_player_instance), str(move_name)])
				monster_learned_move.emit(_get_monster_name(_player_instance), str(move_name))


func _calculate_experience_reward(defeated_monster: Resource) -> int:
	var defeated_level := int(defeated_monster.get("level")) if defeated_monster != null else default_enemy_level
	return max(1, base_experience_reward + defeated_level * 12)


func _get_item_name(item: Resource) -> String:
	var item_name = item.get("item_name")

	if item_name == null or str(item_name).is_empty():
		return "Item"

	return str(item_name)


func _get_item_heal_amount(item: Resource) -> int:
	var heal_amount = item.get("heal_amount")

	if heal_amount == null:
		return 0

	return max(0, int(heal_amount))


func _is_capture_item(item: Resource) -> bool:
	if item == null:
		return false

	if item.has_method("is_capture_item"):
		return bool(item.call("is_capture_item"))

	var capture_rate = item.get("capture_rate")
	return capture_rate != null and float(capture_rate) > 0.0


func _get_item_capture_rate(item: Resource) -> float:
	if item == null:
		return 0.0

	var capture_rate = item.get("capture_rate")

	if capture_rate == null:
		return 0.0

	return clampf(float(capture_rate), 0.0, 1.0)


func _roll_capture(item: Resource) -> bool:
	var item_capture_rate := _get_item_capture_rate(item)

	if item_capture_rate >= 1.0:
		return true

	var max_hp := maxi(1, _get_max_hp(_enemy_instance))
	var current_hp := clampi(_get_current_hp(_enemy_instance), 0, max_hp)
	var missing_hp_ratio := 1.0 - (float(current_hp) / float(max_hp))
	var chance := clampf(item_capture_rate + missing_hp_ratio * 0.5, 0.05, 0.95)
	return _rng.randf() <= chance


func _clone_captured_monster(monster: Resource) -> Resource:
	if monster == null:
		return null

	var monster_data: Resource = null

	if monster.has_method("to_save_data"):
		var save_data: Dictionary = monster.call("to_save_data")
		var data_path := str(save_data.get("data_path", ""))

		if not data_path.is_empty():
			monster_data = load(data_path)

	if monster_data == null:
		monster_data = monster.get("data")

	if monster_data == null:
		return null

	var captured := MonsterInstance.new()
	captured.setup(monster_data, int(monster.get("level")) if monster.get("level") != null else default_enemy_level)
	captured.current_hp = clampi(_get_current_hp(monster), 1, captured.get_max_hp())

	var moves = monster.call("get_moves") if monster.has_method("get_moves") else []
	if moves is Array and not moves.is_empty():
		captured.learned_moves = moves.duplicate()

	var source_pp = monster.get("move_pp")
	if source_pp is Array:
		captured.move_pp.clear()
		for value in source_pp:
			captured.move_pp.append(max(0, int(value)))
		captured.call("_sync_move_pp")

	return captured
