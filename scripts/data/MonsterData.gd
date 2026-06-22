extends Resource
class_name MonsterData

enum MonsterType {
	NORMAL,
	FIRE,
	WATER,
	GRASS,
	ELECTRIC,
	ICE,
	FIGHTING,
	POISON,
	GROUND,
	FLYING,
	PSYCHIC,
	BUG,
	ROCK,
	GHOST,
	DRAGON,
	DARK,
	STEEL,
	FAIRY
}

enum GrowthRate {
	FAST,
	MEDIUM,
	SLOW,
	CUSTOM
}

const MIN_LEVEL := 1
const MAX_LEVEL := 100

@export_group("Identity")
@export var monster_name: String = "Unnamed Monster"
@export_enum(
	"Normal",
	"Fire",
	"Water",
	"Grass",
	"Electric",
	"Ice",
	"Fighting",
	"Poison",
	"Ground",
	"Flying",
	"Psychic",
	"Bug",
	"Rock",
	"Ghost",
	"Dragon",
	"Dark",
	"Steel",
	"Fairy"
)
var primary_type: int = MonsterType.NORMAL
@export_enum(
	"Normal",
	"Fire",
	"Water",
	"Grass",
	"Electric",
	"Ice",
	"Fighting",
	"Poison",
	"Ground",
	"Flying",
	"Psychic",
	"Bug",
	"Rock",
	"Ghost",
	"Dragon",
	"Dark",
	"Steel",
	"Fairy"
)
var secondary_type: int = MonsterType.NORMAL
@export var has_secondary_type: bool = false

@export_group("Base Stats")
@export_range(1, 999, 1) var base_hp: int = 10
@export_range(1, 999, 1) var base_attack: int = 10
@export_range(1, 999, 1) var base_defense: int = 10
@export_range(1, 999, 1) var base_speed: int = 10

@export_group("Moves")
@export var moves: Array[Resource] = []
@export var learnset_levels: Array[int] = []
@export var learnset_moves: Array[Resource] = []

@export_group("Experience")
@export_enum("Fast", "Medium", "Slow", "Custom")
var growth_rate: int = GrowthRate.MEDIUM
@export var custom_experience_curve: Curve


func get_types() -> Array[int]:
	if has_secondary_type and secondary_type != primary_type:
		return [primary_type, secondary_type]

	return [primary_type]


func get_base_stats() -> Dictionary:
	return {
		"hp": base_hp,
		"attack": base_attack,
		"defense": base_defense,
		"speed": base_speed,
	}


func get_learnable_moves_for_level(target_level: int) -> Array[Resource]:
	var learned: Array[Resource] = []
	var clamped_level := clampi(target_level, MIN_LEVEL, MAX_LEVEL)
	var pair_count := mini(learnset_levels.size(), learnset_moves.size())

	for index in pair_count:
		if learnset_levels[index] <= clamped_level and learnset_moves[index] is Resource:
			learned.append(learnset_moves[index])

	return learned


func get_moves_learned_between(previous_level: int, new_level: int) -> Array[Resource]:
	var learned: Array[Resource] = []
	var min_level := clampi(previous_level + 1, MIN_LEVEL, MAX_LEVEL)
	var max_level := clampi(new_level, MIN_LEVEL, MAX_LEVEL)
	var pair_count := mini(learnset_levels.size(), learnset_moves.size())

	for index in pair_count:
		var learn_level := learnset_levels[index]

		if learn_level >= min_level and learn_level <= max_level and learnset_moves[index] is Resource:
			learned.append(learnset_moves[index])

	return learned


func get_experience_for_level(level: int) -> int:
	var clamped_level := clampi(level, MIN_LEVEL, MAX_LEVEL)

	if clamped_level <= MIN_LEVEL:
		return 0

	if growth_rate == GrowthRate.CUSTOM and custom_experience_curve != null:
		return roundi(custom_experience_curve.sample_baked(_level_to_curve_position(clamped_level)))

	var level_cubed := clamped_level * clamped_level * clamped_level

	match growth_rate:
		GrowthRate.FAST:
			return roundi(0.8 * level_cubed)
		GrowthRate.SLOW:
			return roundi(1.25 * level_cubed)
		_:
			return level_cubed


func get_experience_to_next_level(current_level: int) -> int:
	var clamped_level := clampi(current_level, MIN_LEVEL, MAX_LEVEL)

	if clamped_level >= MAX_LEVEL:
		return 0

	return get_experience_for_level(clamped_level + 1) - get_experience_for_level(clamped_level)


func _level_to_curve_position(level: int) -> float:
	return inverse_lerp(MIN_LEVEL, MAX_LEVEL, level)
