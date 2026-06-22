extends SceneTree


func _init() -> void:
	var monster_instance_script := load("res://scripts/data/MonsterInstance.gd") as Script
	var fire_data = load("res://data/monsters/FireMonster.tres")

	if monster_instance_script == null or fire_data == null:
		push_error("Level stat validation could not load required resources.")
		quit(1)
		return

	var level_five = monster_instance_script.new()
	level_five.setup(fire_data, 5)

	var level_ten = monster_instance_script.new()
	level_ten.setup(fire_data, 10)

	var base_stats: Dictionary = fire_data.get_base_stats()

	if level_five.get_attack() != int(base_stats["attack"]) or level_five.get_max_hp() != int(base_stats["hp"]):
		push_error("Level 5 should remain the baseline for monster stats.")
		quit(1)
		return

	if level_ten.get_attack() <= level_five.get_attack() or level_ten.get_max_hp() <= level_five.get_max_hp():
		push_error("Higher-level monster stats did not scale above the baseline.")
		quit(1)
		return

	var leveling_monster = monster_instance_script.new()
	leveling_monster.setup(fire_data, 5)
	leveling_monster.current_hp = leveling_monster.get_max_hp() - 3
	var previous_hp := int(leveling_monster.current_hp)
	var previous_max_hp: int = leveling_monster.get_max_hp()
	var xp_to_next: int = leveling_monster.get_experience_to_next_level()
	var result: Dictionary = leveling_monster.gain_experience_and_level_up(xp_to_next)

	if not bool(result.get("leveled_up", false)):
		push_error("Expected monster to level up after gaining enough XP.")
		quit(1)
		return

	if leveling_monster.get_max_hp() <= previous_max_hp:
		push_error("Max HP did not increase after level-up.")
		quit(1)
		return

	if int(leveling_monster.current_hp) <= previous_hp:
		push_error("Current HP did not receive the level-up HP increase.")
		quit(1)
		return

	print("Level stat validation passed: HP %d -> %d, Attack %d -> %d." % [
		previous_max_hp,
		leveling_monster.get_max_hp(),
		level_five.get_attack(),
		level_ten.get_attack(),
	])
	quit()
