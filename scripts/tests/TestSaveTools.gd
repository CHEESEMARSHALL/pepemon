extends RefCounted

const SAVE_PATH := "user://savegame.json"


static func clear_main_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)
