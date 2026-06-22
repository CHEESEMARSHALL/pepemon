extends Resource
class_name MoveData

@export_group("Identity")
@export var move_name: String = "Tackle"

@export_group("Battle")
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
var move_type: int = 0
@export_range(1, 999, 1) var power: int = 40
@export_range(1, 99, 1) var max_pp: int = 25
@export_range(0.0, 1.0, 0.01) var accuracy: float = 1.0
