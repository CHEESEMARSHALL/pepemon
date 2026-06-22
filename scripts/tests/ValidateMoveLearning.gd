extends SceneTree


func _init() -> void:
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")
	var flame_burst = load("res://data/moves/FlameBurst.tres")

	if monster_instance_script == null or fire_data == null or flame_burst == null:
		push_error("Move learning validation could not load required resources.")
		quit(1)
		return

	var level_four = monster_instance_script.new()
	level_four.setup(fire_data, 4)

	if _has_move(level_four, "Flame Burst"):
		push_error("Emberling should not know Flame Burst before level 5.")
		quit(1)
		return

	var level_five = monster_instance_script.new()
	level_five.setup(fire_data, 5)

	if not _has_move(level_five, "Flame Burst"):
		push_error("Emberling should initialize with Flame Burst at level 5.")
		quit(1)
		return

	var leveling_monster = monster_instance_script.new()
	leveling_monster.setup(fire_data, 4)
	var xp_to_next: int = leveling_monster.get_experience_to_next_level()
	var result: Dictionary = leveling_monster.gain_experience_and_level_up(xp_to_next)
	var learned_moves: Array = result.get("learned_moves", [])

	if not _has_move(leveling_monster, "Flame Burst") or not learned_moves.has("Flame Burst"):
		push_error("Emberling did not learn Flame Burst while leveling to 5.")
		quit(1)
		return

	var six_slot_monster = monster_instance_script.new()
	six_slot_monster.setup(fire_data, 5)

	for index in 5:
		var extra_move := MoveData.new()
		extra_move.move_name = "Test Move %d" % [index + 1]
		extra_move.power = 10 + index
		six_slot_monster.learn_move(extra_move)

	if six_slot_monster.get_moves().size() != 6:
		push_error("Monster move slots should allow exactly 6 moves.")
		quit(1)
		return

	var seventh_move := MoveData.new()
	seventh_move.move_name = "Overflow Move"
	six_slot_monster.learn_move(seventh_move)

	if six_slot_monster.get_moves().size() != 6 or not _has_move(six_slot_monster, "Overflow Move"):
		push_error("Learning a seventh move should keep the move list capped at 6.")
		quit(1)
		return

	print("Move learning validation passed: Emberling learned Flame Burst and supports 6 move slots.")
	quit()


func _has_move(monster, move_name: String) -> bool:
	var moves = monster.call("get_moves")

	if not moves is Array:
		return false

	for move in moves:
		if move is Resource and str(move.get("move_name")) == move_name:
			return true

	return false
