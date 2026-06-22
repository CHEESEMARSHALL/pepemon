extends Resource
class_name MonsterInstance

const BASELINE_LEVEL := 5
const STAT_GROWTH_PER_LEVEL := 0.08
const HP_GROWTH_PER_LEVEL := 0.1
const MAX_MOVES := 6

@export var data: Resource
@export_range(1, 100, 1) var level: int = 5
@export var nickname: String = ""
@export var current_hp: int = -1
@export var experience: int = 0
@export var learned_moves: Array[Resource] = []
@export var move_pp: Array[int] = []


func setup(monster_data: Resource, starting_level: int = 5) -> void:
	data = monster_data
	level = clampi(starting_level, 1, 100)
	learned_moves = _get_initial_moves_for_level(level)
	reset_move_pp()
	current_hp = get_max_hp()
	experience = _get_starting_experience()


func get_display_name() -> String:
	if not nickname.is_empty():
		return nickname

	if data == null:
		return "Unknown Monster"

	var monster_name = data.get("monster_name")

	if monster_name == null or str(monster_name).is_empty():
		return "Unknown Monster"

	return str(monster_name)


func get_stat(stat_name: String) -> int:
	if data == null:
		return 1

	var stats = data.call("get_base_stats")

	if stats is Dictionary and stats.has(stat_name):
		return _scale_stat(int(stats[stat_name]), stat_name)

	return 1


func get_max_hp() -> int:
	return max(1, get_stat("hp"))


func get_attack() -> int:
	return get_stat("attack")


func get_defense() -> int:
	return get_stat("defense")


func get_speed() -> int:
	return get_stat("speed")


func get_moves() -> Array[Resource]:
	if learned_moves.is_empty():
		return _get_data_moves()

	return learned_moves


func get_types() -> Array[int]:
	if data == null:
		return []

	return data.call("get_types")


func reset_move_pp() -> void:
	move_pp.clear()

	for move in get_moves():
		move_pp.append(get_move_max_pp(move))


func get_move_pp(move_index: int) -> int:
	_sync_move_pp()

	if move_index < 0 or move_index >= move_pp.size():
		return 0

	return move_pp[move_index]


func get_move_max_pp_at(move_index: int) -> int:
	var moves := get_moves()

	if move_index < 0 or move_index >= moves.size():
		return 0

	return get_move_max_pp(moves[move_index])


func can_use_move(move_index: int) -> bool:
	return get_move_pp(move_index) > 0


func spend_move_pp(move_index: int) -> bool:
	_sync_move_pp()

	if not can_use_move(move_index):
		return false

	move_pp[move_index] -= 1
	return true


func get_move_max_pp(move: Resource) -> int:
	if move == null:
		return 1

	var max_pp = move.get("max_pp")

	if max_pp == null:
		return 1

	return max(1, int(max_pp))


func is_fainted() -> bool:
	return current_hp <= 0


func take_damage(amount: int) -> int:
	var actual_damage := clampi(amount, 0, current_hp)
	current_hp = max(0, current_hp - actual_damage)
	return actual_damage


func heal_to_full() -> void:
	current_hp = get_max_hp()


func heal(amount: int) -> int:
	var previous_hp := current_hp
	current_hp = clampi(current_hp + max(0, amount), 0, get_max_hp())
	return current_hp - previous_hp


func gain_experience(amount: int) -> void:
	experience = max(0, experience + amount)


func gain_experience_and_level_up(amount: int) -> Dictionary:
	var previous_level := level
	var previous_max_hp := get_max_hp()
	gain_experience(amount)

	while level < 100 and experience >= get_experience_for_level(level + 1):
		level += 1

	var leveled_up := level > previous_level
	var learned_move_names: Array[String] = []

	if leveled_up:
		var max_hp_increase := get_max_hp() - previous_max_hp
		current_hp = clampi(current_hp + maxi(0, max_hp_increase), 0, get_max_hp())
		learned_move_names = _learn_moves_for_level_range(previous_level, level)

	return {
		"experience_gained": amount,
		"previous_level": previous_level,
		"new_level": level,
		"leveled_up": leveled_up,
		"max_hp_increase": maxi(0, get_max_hp() - previous_max_hp),
		"learned_moves": learned_move_names,
	}


func get_experience_for_level(target_level: int) -> int:
	if data == null:
		return 0

	return int(data.call("get_experience_for_level", target_level))


func get_experience_to_next_level() -> int:
	if level >= 100:
		return 0

	return max(0, get_experience_for_level(level + 1) - experience)


func to_save_data() -> Dictionary:
	return {
		"data_path": data.resource_path if data != null else "",
		"level": level,
		"nickname": nickname,
		"current_hp": current_hp,
		"experience": experience,
		"learned_move_paths": _get_move_paths(),
		"move_pp": move_pp.duplicate(),
	}


func load_save_data(save_data: Dictionary) -> bool:
	var data_path := str(save_data.get("data_path", ""))

	if data_path.is_empty():
		return false

	var loaded_data := load(data_path)

	if loaded_data == null:
		return false

	data = loaded_data
	level = clampi(int(save_data.get("level", 1)), 1, 100)
	nickname = str(save_data.get("nickname", ""))
	current_hp = clampi(int(save_data.get("current_hp", get_max_hp())), 0, get_max_hp())
	experience = max(0, int(save_data.get("experience", get_experience_for_level(level))))
	learned_moves = _load_moves_from_paths(save_data.get("learned_move_paths", []))
	move_pp = _load_int_array(save_data.get("move_pp", []))
	_sync_move_pp()
	return true


func _sync_move_pp() -> void:
	var moves := get_moves()

	while move_pp.size() < moves.size():
		move_pp.append(get_move_max_pp(moves[move_pp.size()]))

	if move_pp.size() > moves.size():
		move_pp.resize(moves.size())


func learn_move(move: Resource) -> bool:
	if move == null or _has_move(move):
		return false

	if learned_moves.size() >= MAX_MOVES:
		learned_moves.pop_front()

		if not move_pp.is_empty():
			move_pp.pop_front()

	learned_moves.append(move)
	move_pp.append(get_move_max_pp(move))
	return true


func _scale_stat(base_value: int, stat_name: String) -> int:
	var growth_per_level := HP_GROWTH_PER_LEVEL if stat_name == "hp" else STAT_GROWTH_PER_LEVEL
	var level_offset := level - BASELINE_LEVEL
	var multiplier := 1.0 + float(level_offset) * growth_per_level

	return max(1, roundi(float(base_value) * maxf(0.2, multiplier)))


func _get_initial_moves_for_level(target_level: int) -> Array[Resource]:
	var initial_moves := _get_data_moves().duplicate()

	if data != null and data.has_method("get_learnable_moves_for_level"):
		for move in data.call("get_learnable_moves_for_level", target_level):
			if move is Resource and not initial_moves.has(move):
				initial_moves.append(move)

	while initial_moves.size() > MAX_MOVES:
		initial_moves.pop_front()

	return initial_moves


func _learn_moves_for_level_range(previous_level: int, new_level: int) -> Array[String]:
	var learned_move_names: Array[String] = []

	if data == null or not data.has_method("get_moves_learned_between"):
		return learned_move_names

	for move in data.call("get_moves_learned_between", previous_level, new_level):
		if move is Resource and learn_move(move):
			learned_move_names.append(_get_move_name(move))

	return learned_move_names


func _has_move(move: Resource) -> bool:
	for learned_move in learned_moves:
		if learned_move == move:
			return true

	return false


func _get_move_name(move: Resource) -> String:
	if move == null:
		return "Move"

	var move_name = move.get("move_name")

	if move_name == null or str(move_name).is_empty():
		return "Move"

	return str(move_name)


func _get_data_moves() -> Array[Resource]:
	if data == null:
		return []

	var moves = data.get("moves")

	if moves is Array:
		var resources: Array[Resource] = []

		for move in moves:
			if move is Resource:
				resources.append(move)

		return resources

	return []


func _get_move_paths() -> Array[String]:
	var paths: Array[String] = []

	for move in get_moves():
		if move != null:
			paths.append(move.resource_path)

	return paths


func _load_moves_from_paths(paths) -> Array[Resource]:
	var moves: Array[Resource] = []

	if not paths is Array:
		return _get_data_moves()

	for path in paths:
		var move := load(str(path))

		if move is Resource:
			moves.append(move)

	if moves.is_empty():
		return _get_data_moves()

	return moves


func _load_int_array(values) -> Array[int]:
	var ints: Array[int] = []

	if not values is Array:
		return ints

	for value in values:
		ints.append(max(0, int(value)))

	return ints


func _get_starting_experience() -> int:
	if data == null:
		return 0

	return int(data.call("get_experience_for_level", level))
