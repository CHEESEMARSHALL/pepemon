extends Node
class_name GameManager

const SaveManagerScript := preload("res://scripts/game/SaveManager.gd")

@export var overworld_scene: PackedScene
@export var starting_map_data: Resource
@export var battle_scene: PackedScene
@export var starter_monster_data: Resource
@export var starter_party_data: Array[Resource] = []
@export_range(1, 100, 1) var starter_level: int = 5
@export var auto_load_save := true
@export var auto_save_after_battle := true
@export_range(0, 99, 1) var starting_potion_count: int = 3
@export_range(0, 99, 1) var starting_capture_count: int = 3
@export var potion_item: Resource

@onready var _scene_root := %SceneRoot as Node
@onready var _overworld_menu_overlay := %OverworldMenuOverlay as Control
@onready var _menu_title_label := %MenuTitleLabel as Label
@onready var _menu_content_label := %MenuContentLabel as Label
@onready var _party_tab_button := %PartyTabButton as Button
@onready var _bag_tab_button := %BagTabButton as Button
@onready var _leader_button_grid := %LeaderButtonGrid as GridContainer
@onready var _leader_buttons: Array[Button] = [
	%LeaderButton1,
	%LeaderButton2,
	%LeaderButton3,
	%LeaderButton4,
	%LeaderButton5,
	%LeaderButton6,
]
@onready var _use_potion_button := %UsePotionButton as Button
@onready var _rest_party_button := %RestPartyButton as Button
@onready var _save_button := %SaveButton as Button
@onready var _close_menu_button := %CloseMenuButton as Button

var _player_monster: Resource
var _player_party: Array[Resource] = []
var _inventory := {}
var _route_state := {}
var _current_scene: Node
var _current_map_data: Resource
var _pending_overworld_start_cell := Vector2i(-999, -999)
var _current_player_cell := Vector2i(-999, -999)
var _active_menu_tab := "party"
var _pending_trainer_id := ""


func _ready() -> void:
	_connect_overworld_menu()
	_create_player_monster()
	show_overworld()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_overworld_menu()
		get_viewport().set_input_as_handled()


func show_overworld() -> void:
	_clear_current_scene()
	close_overworld_menu()

	if overworld_scene == null:
		push_error("GameManager requires an overworld_scene.")
		return

	_current_scene = overworld_scene.instantiate()

	if _current_map_data == null:
		_current_map_data = starting_map_data

	if _current_map_data != null:
		_current_scene.set("map_data", _current_map_data)

	if _pending_overworld_start_cell != Vector2i(-999, -999):
		_current_scene.set("player_start_cell_override", _pending_overworld_start_cell)
		_current_player_cell = _pending_overworld_start_cell
		_pending_overworld_start_cell = Vector2i(-999, -999)

	_scene_root.add_child(_current_scene)
	_apply_route_state_to_overworld(_current_scene)
	_connect_overworld(_current_scene)
	_capture_overworld_position()


func start_battle(enemy_monster_data: Resource, enemy_level: int = 5) -> void:
	if battle_scene == null:
		push_error("GameManager requires a battle_scene.")
		return

	if enemy_monster_data == null:
		push_error("No enemy monster was selected for battle.")
		return

	_capture_overworld_position()
	_clear_current_scene()

	var enemy_instance := MonsterInstance.new()
	enemy_instance.setup(enemy_monster_data, enemy_level)

	var battle_ui = battle_scene.instantiate()
	battle_ui.auto_start_battle = false
	battle_ui.configure_inventory(_inventory)
	_current_scene = battle_ui
	_scene_root.add_child(_current_scene)
	battle_ui.battle_finished.connect(_on_battle_finished)
	battle_ui.battle_escaped.connect(_on_battle_escaped)
	battle_ui.start_battle(_player_party, enemy_instance, _get_active_party_index())


func _create_player_monster() -> void:
	if auto_load_save and _load_player_monster():
		return

	_inventory = _get_default_inventory()

	if starter_monster_data == null:
		push_error("GameManager requires starter_monster_data.")
		return

	var starting_data := starter_party_data.duplicate()

	if starting_data.is_empty():
		starting_data.append(starter_monster_data)

	_player_party.clear()

	for monster_data in starting_data:
		if monster_data is Resource:
			var monster_instance := MonsterInstance.new()
			monster_instance.setup(monster_data, starter_level)
			_player_party.append(monster_instance)

	if _player_party.is_empty():
		push_error("GameManager could not create a starter party.")
		return

	_player_monster = _player_party[0]


func _connect_overworld(scene: Node) -> void:
	var player := scene.find_child("Player", true, false) as PlayerController

	if player == null:
		push_error("Overworld scene does not contain a PlayerController named Player.")
		return

	player.battle_triggered.connect(start_battle)

	if scene.has_signal("battle_triggered"):
		scene.battle_triggered.connect(start_battle)

	if scene.has_signal("trainer_battle_triggered"):
		scene.trainer_battle_triggered.connect(_start_trainer_battle)

	if scene.has_signal("pickup_collected"):
		scene.pickup_collected.connect(_collect_pickup)

	if scene.has_signal("route_transition_requested"):
		scene.route_transition_requested.connect(_change_route)

	player.step_finished.connect(_on_player_step_finished)


func toggle_overworld_menu() -> void:
	if _current_scene == null or _current_scene is BattleUI:
		return

	if _overworld_menu_overlay.visible:
		close_overworld_menu()
	else:
		open_overworld_menu()


func open_overworld_menu(tab: String = "party") -> void:
	if _overworld_menu_overlay == null:
		return

	_active_menu_tab = tab
	_overworld_menu_overlay.visible = true
	_set_overworld_movement_enabled(false)
	_refresh_overworld_menu()


func close_overworld_menu() -> void:
	if _overworld_menu_overlay != null:
		_overworld_menu_overlay.visible = false
		_set_overworld_movement_enabled(true)


func is_overworld_menu_open() -> bool:
	return _overworld_menu_overlay != null and _overworld_menu_overlay.visible


func _on_battle_finished(_player_won: bool) -> void:
	_sync_party_from_battle()
	_sync_inventory_from_battle()

	if _player_won:
		_mark_pending_trainer_defeated()
	else:
		_pending_trainer_id = ""

	if auto_save_after_battle:
		SaveManagerScript.save_game(_player_party, SaveManagerScript.SAVE_PATH, _get_active_party_index(), _inventory, _route_state, _get_world_state())

	_pending_overworld_start_cell = _current_player_cell
	show_overworld()


func _on_battle_escaped() -> void:
	_sync_party_from_battle()
	_sync_inventory_from_battle()

	if auto_save_after_battle:
		SaveManagerScript.save_game(_player_party, SaveManagerScript.SAVE_PATH, _get_active_party_index(), _inventory, _route_state, _get_world_state())

	_pending_trainer_id = ""

	_pending_overworld_start_cell = _current_player_cell
	show_overworld()


func _connect_overworld_menu() -> void:
	_overworld_menu_overlay.visible = false
	_party_tab_button.pressed.connect(open_overworld_menu.bind("party"))
	_bag_tab_button.pressed.connect(open_overworld_menu.bind("bag"))
	_use_potion_button.pressed.connect(_use_potion_from_menu)
	_rest_party_button.pressed.connect(_rest_party_from_menu)
	_save_button.pressed.connect(_save_from_menu)
	_close_menu_button.pressed.connect(close_overworld_menu)

	for index in _leader_buttons.size():
		_leader_buttons[index].pressed.connect(set_active_party_index.bind(index))


func set_active_party_index(party_index: int) -> bool:
	if party_index < 0 or party_index >= _player_party.size():
		return false

	var monster := _player_party[party_index]

	if _get_monster_current_hp(monster) <= 0:
		return false

	_player_monster = monster

	if is_overworld_menu_open():
		_active_menu_tab = "party"
		_refresh_overworld_menu()

	return true


func _refresh_overworld_menu() -> void:
	if _active_menu_tab == "bag":
		_menu_title_label.text = "Bag"
		_menu_content_label.text = _format_inventory()
		_leader_button_grid.visible = false
		_use_potion_button.visible = true
		_rest_party_button.visible = false
	else:
		_active_menu_tab = "party"
		_menu_title_label.text = "Party"
		_menu_content_label.text = _format_party()
		_leader_button_grid.visible = true
		_use_potion_button.visible = false
		_rest_party_button.visible = true
		_populate_leader_buttons()


func _save_from_menu() -> void:
	_capture_overworld_position()

	if SaveManagerScript.save_game(_player_party, SaveManagerScript.SAVE_PATH, _get_active_party_index(), _inventory, _route_state, _get_world_state()):
		_menu_title_label.text = "Saved"
		_menu_content_label.text = "Progress saved."


func _use_potion_from_menu() -> void:
	_active_menu_tab = "bag"
	_menu_title_label.text = "Bag"

	if _player_monster == null:
		_menu_content_label.text = "No active monster.\n\n%s" % _format_inventory()
		return

	var potion_count := int(_inventory.get(BattleUI.INVENTORY_POTION_KEY, 0))

	if potion_count <= 0:
		_menu_content_label.text = "No Potions left.\n\n%s" % _format_inventory()
		return

	if _get_monster_current_hp(_player_monster) >= _get_monster_max_hp(_player_monster):
		_menu_content_label.text = "It won't have any effect.\n\n%s" % _format_inventory()
		return

	var heal_amount := _get_item_heal_amount(potion_item)
	var actual_heal := _heal_monster(_player_monster, heal_amount)

	if actual_heal <= 0:
		_menu_content_label.text = "It won't have any effect.\n\n%s" % _format_inventory()
		return

	_inventory[BattleUI.INVENTORY_POTION_KEY] = maxi(0, potion_count - 1)
	_menu_content_label.text = "Used Potion on %s.\nRecovered %d HP.\n\n%s" % [
		_get_monster_name(_player_monster),
		actual_heal,
		_format_inventory(),
	]


func _rest_party_from_menu() -> void:
	_active_menu_tab = "party"
	var restored_count := 0

	for monster in _player_party:
		if monster != null and monster.has_method("heal_to_full"):
			monster.call("heal_to_full")
			restored_count += 1

		if monster != null and monster.has_method("reset_move_pp"):
			monster.call("reset_move_pp")

	_menu_title_label.text = "Party Rested"
	_menu_content_label.text = "Restored %d monsters.\n\n%s" % [restored_count, _format_party()]
	_leader_button_grid.visible = true
	_use_potion_button.visible = false
	_rest_party_button.visible = true
	_populate_leader_buttons()


func _format_party() -> String:
	if _player_party.is_empty():
		return "No monsters."

	var lines: Array[String] = []

	for index in _player_party.size():
		var monster := _player_party[index]
		var marker := "*" if monster == _player_monster else " "
		lines.append("%s %s Lv.%d HP %d/%d | XP to next: %d" % [
			marker,
			_get_monster_name(monster),
			_get_monster_level(monster),
			_get_monster_current_hp(monster),
			_get_monster_max_hp(monster),
			_get_monster_experience_to_next_level(monster),
		])

	return "\n".join(lines)


func _format_inventory() -> String:
	return "Potion x%d\nCapture Capsule x%d" % [
		int(_inventory.get(BattleUI.INVENTORY_POTION_KEY, 0)),
		int(_inventory.get(BattleUI.INVENTORY_CAPTURE_KEY, 0)),
	]


func _populate_leader_buttons() -> void:
	var active_index := _get_active_party_index()

	for index in _leader_buttons.size():
		var button := _leader_buttons[index]
		var has_monster := index < _player_party.size()
		button.visible = has_monster
		button.disabled = not has_monster

		if has_monster:
			var monster := _player_party[index]
			button.text = "Lead %d" % [index + 1]
			button.disabled = index == active_index or _get_monster_current_hp(monster) <= 0


func _load_player_monster() -> bool:
	var save_data: Dictionary = SaveManagerScript.load_game()

	if save_data.is_empty():
		return false

	var loaded_party := _load_party_from_save(save_data)

	if loaded_party.is_empty():
		return false

	_player_party = loaded_party
	_inventory = _load_inventory_from_save(save_data)
	_route_state = _load_route_state_from_save(save_data)
	_load_world_state_from_save(save_data)
	var active_index := clampi(int(save_data.get("active_party_index", 0)), 0, _player_party.size() - 1)
	_player_monster = _player_party[active_index]
	return true


func _load_party_from_save(save_data: Dictionary) -> Array[Resource]:
	var loaded_party: Array[Resource] = []
	var saved_party = save_data.get("player_party", [])

	if saved_party is Array:
		for saved_member in saved_party:
			if saved_member is Dictionary:
				var loaded_monster := MonsterInstance.new()

				if loaded_monster.load_save_data(saved_member):
					loaded_party.append(loaded_monster)

	if loaded_party.is_empty() and save_data.has("player_monster"):
		var loaded_monster := MonsterInstance.new()

		if loaded_monster.load_save_data(save_data["player_monster"]):
			loaded_party.append(loaded_monster)

	return loaded_party


func _clear_current_scene() -> void:
	if _current_scene == null:
		return

	_current_scene.queue_free()
	_current_scene = null


func _sync_party_from_battle() -> void:
	if _current_scene == null or not _current_scene.has_method("get_player_party"):
		return

	var battle_party: Array[Resource] = _current_scene.call("get_player_party")

	if battle_party.is_empty():
		return

	_player_party = battle_party

	var active_index := 0

	if _current_scene.has_method("get_active_player_index"):
		active_index = clampi(int(_current_scene.call("get_active_player_index")), 0, _player_party.size() - 1)

	_player_monster = _player_party[active_index]


func _sync_inventory_from_battle() -> void:
	if _current_scene == null or not _current_scene.has_method("get_inventory_counts"):
		return

	var battle_inventory: Dictionary = _current_scene.call("get_inventory_counts")
	_inventory = _sanitize_inventory(battle_inventory)


func _set_overworld_movement_enabled(is_enabled: bool) -> void:
	if _current_scene == null:
		return

	var player := _current_scene.find_child("Player", true, false) as PlayerController

	if player != null:
		player.movement_enabled = is_enabled


func _get_default_inventory() -> Dictionary:
	return {
		BattleUI.INVENTORY_POTION_KEY: starting_potion_count,
		BattleUI.INVENTORY_CAPTURE_KEY: starting_capture_count,
	}


func _load_inventory_from_save(save_data: Dictionary) -> Dictionary:
	return _sanitize_inventory(save_data.get("inventory", _get_default_inventory()))


func _load_route_state_from_save(save_data: Dictionary) -> Dictionary:
	var route_state := {
		"defeated_trainers": [],
		"collected_pickups": [],
	}
	var raw_route_state = save_data.get("route_state", {})

	if raw_route_state is Dictionary:
		for trainer_id in raw_route_state.get("defeated_trainers", []):
			var string_id := str(trainer_id)

			if not string_id.is_empty() and not route_state["defeated_trainers"].has(string_id):
				route_state["defeated_trainers"].append(string_id)

		for pickup_id in raw_route_state.get("collected_pickups", []):
			var string_id := str(pickup_id)

			if not string_id.is_empty() and not route_state["collected_pickups"].has(string_id):
				route_state["collected_pickups"].append(string_id)

	return route_state


func _load_world_state_from_save(save_data: Dictionary) -> void:
	var raw_world_state = save_data.get("world_state", {})

	if not raw_world_state is Dictionary:
		return

	var map_path := str(raw_world_state.get("map_path", ""))

	if not map_path.is_empty():
		var loaded_map := load(map_path)

		if loaded_map != null:
			_current_map_data = loaded_map

	var player_cell := _parse_saved_cell(raw_world_state.get("player_cell", null))

	if player_cell != Vector2i(-999, -999):
		_pending_overworld_start_cell = player_cell
		_current_player_cell = player_cell


func _parse_saved_cell(raw_cell) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell

	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -999)), int(raw_cell.get("y", -999)))

	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))

	return Vector2i(-999, -999)


func _sanitize_inventory(raw_inventory) -> Dictionary:
	var defaults := _get_default_inventory()
	var inventory := {}

	if raw_inventory is Dictionary:
		for key in defaults.keys():
			inventory[key] = max(0, int(raw_inventory.get(key, defaults[key])))
	else:
		inventory = defaults

	return inventory


func _get_monster_name(monster: Resource) -> String:
	if monster != null and monster.has_method("get_display_name"):
		return str(monster.call("get_display_name"))

	if monster == null:
		return "Unknown"

	var monster_name = monster.get("monster_name")

	if monster_name == null or str(monster_name).is_empty():
		return "Unknown"

	return str(monster_name)


func _get_monster_level(monster: Resource) -> int:
	if monster == null:
		return 1

	var monster_level = monster.get("level")
	return int(monster_level) if monster_level != null else 1


func _get_monster_current_hp(monster: Resource) -> int:
	if monster == null:
		return 0

	var current_hp = monster.get("current_hp")
	return int(current_hp) if current_hp != null else _get_monster_max_hp(monster)


func _get_monster_max_hp(monster: Resource) -> int:
	if monster != null and monster.has_method("get_max_hp"):
		return int(monster.call("get_max_hp"))

	if monster != null and monster.has_method("get_base_stats"):
		var stats = monster.call("get_base_stats")

		if stats is Dictionary and stats.has("hp"):
			return maxi(1, int(stats["hp"]))

	return 1


func _get_monster_experience_to_next_level(monster: Resource) -> int:
	if monster != null and monster.has_method("get_experience_to_next_level"):
		return int(monster.call("get_experience_to_next_level"))

	return 0


func _heal_monster(monster: Resource, amount: int) -> int:
	if monster != null and monster.has_method("heal"):
		return int(monster.call("heal", amount))

	return 0


func _get_item_heal_amount(item: Resource) -> int:
	if item == null:
		return 20

	var heal_amount = item.get("heal_amount")

	if heal_amount == null:
		return 20

	return maxi(0, int(heal_amount))


func _get_active_party_index() -> int:
	for index in _player_party.size():
		if _player_party[index] == _player_monster:
			return index

	return 0


func _start_trainer_battle(trainer_id: String, enemy_monster_data: Resource, enemy_level: int = 5) -> void:
	_pending_trainer_id = trainer_id
	start_battle(enemy_monster_data, enemy_level)


func _mark_pending_trainer_defeated() -> void:
	if _pending_trainer_id.is_empty():
		return

	if not _route_state.has("defeated_trainers") or not _route_state["defeated_trainers"] is Array:
		_route_state["defeated_trainers"] = []

	if not _route_state["defeated_trainers"].has(_pending_trainer_id):
		_route_state["defeated_trainers"].append(_pending_trainer_id)

	_pending_trainer_id = ""


func _apply_route_state_to_overworld(scene: Node) -> void:
	if scene == null:
		return

	var defeated_ids: Array[String] = []

	for trainer_id in _route_state.get("defeated_trainers", []):
		defeated_ids.append(str(trainer_id))

	if scene.has_method("set_defeated_interactables"):
		scene.call("set_defeated_interactables", defeated_ids)

	var collected_ids: Array[String] = []

	for pickup_id in _route_state.get("collected_pickups", []):
		collected_ids.append(str(pickup_id))

	if scene.has_method("set_collected_interactables"):
		scene.call("set_collected_interactables", collected_ids)


func _collect_pickup(pickup_id: String, item_key: String, item_count: int, _item_name: String) -> void:
	if pickup_id.is_empty() or item_key.is_empty() or item_count <= 0:
		return

	_inventory[item_key] = maxi(0, int(_inventory.get(item_key, 0))) + item_count

	if not _route_state.has("collected_pickups") or not _route_state["collected_pickups"] is Array:
		_route_state["collected_pickups"] = []

	if not _route_state["collected_pickups"].has(pickup_id):
		_route_state["collected_pickups"].append(pickup_id)


func _change_route(target_map: Resource, target_start_cell: Vector2i) -> void:
	if target_map == null:
		return

	_current_map_data = target_map
	_pending_overworld_start_cell = target_start_cell
	_current_player_cell = target_start_cell
	show_overworld()


func _on_player_step_finished(cell: Vector2i) -> void:
	_current_player_cell = cell


func _capture_overworld_position() -> void:
	if _current_scene == null or _current_scene is BattleUI:
		return

	if _current_scene.has_method("get_player_cell"):
		_current_player_cell = _current_scene.call("get_player_cell")


func _get_world_state() -> Dictionary:
	var map_path := ""

	if _current_map_data != null:
		map_path = str(_current_map_data.resource_path)

	var player_cell := _current_player_cell

	if player_cell == Vector2i(-999, -999):
		if _current_map_data != null:
			player_cell = _current_map_data.player_start_cell
		else:
			player_cell = Vector2i.ZERO

	return {
		"map_path": map_path,
		"player_cell": player_cell,
	}
