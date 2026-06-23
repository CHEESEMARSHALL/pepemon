extends Resource
class_name OverworldMapData

@export var map_name := ""
@export var player_start_cell := Vector2i(8, 8)
@export var encounter_table: Resource
@export var rows: Array[String] = []
@export var overlay_rows: Array[String] = []
@export var sign_messages: Array[Dictionary] = []
@export var inspect_messages: Array[Dictionary] = []
@export var interactables: Array[Dictionary] = []
@export var transitions: Array[Dictionary] = []


func get_tile_code(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return "#"

	var row := rows[cell.y]

	if cell.x < 0 or cell.x >= row.length():
		return "#"

	return row.substr(cell.x, 1)


func get_overlay_tile_code(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= overlay_rows.size():
		return ""

	var row := overlay_rows[cell.y]

	if cell.x < 0 or cell.x >= row.length():
		return ""

	var tile_code := row.substr(cell.x, 1)
	return "" if tile_code == "." else tile_code


func has_overlay_rows() -> bool:
	return not overlay_rows.is_empty()


func get_width() -> int:
	var width := 0

	for row in rows:
		width = maxi(width, row.length())

	for row in overlay_rows:
		width = maxi(width, row.length())

	return width


func get_height() -> int:
	return maxi(rows.size(), overlay_rows.size())


func get_sign_message(cell: Vector2i) -> String:
	for sign_entry in sign_messages:
		if not sign_entry is Dictionary:
			continue

		if sign_entry.get("cell", Vector2i(-999, -999)) == cell:
			return str(sign_entry.get("message", ""))

	return ""


func get_inspect_message(cell: Vector2i) -> String:
	for inspect_entry in inspect_messages:
		if not inspect_entry is Dictionary:
			continue

		if inspect_entry.get("cell", Vector2i(-999, -999)) == cell:
			return str(inspect_entry.get("message", ""))

	return ""


func get_interactable_entries() -> Array[Dictionary]:
	return interactables


func get_transition_entry(cell: Vector2i) -> Dictionary:
	for transition in transitions:
		if not transition is Dictionary:
			continue

		if transition.get("cell", Vector2i(-999, -999)) == cell:
			return transition

	return {}


func is_inside_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < get_width() and cell.y < get_height()
