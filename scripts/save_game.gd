class_name SaveGame
extends RefCounted
## Boss Rush progress: which round to continue from. Saving from the pause
## menu during a Boss Rush fight stores that round; Continue on the title
## screen starts it again from the beginning.
##
## Stored in the game's user data folder (user://save.cfg; on Windows
## %APPDATA%\Godot\app_userdata\Prototype JRPG\save.cfg).

const PATH := "user://save.cfg"


static func save_round(round_index: int) -> void:
	var file := ConfigFile.new()
	file.set_value("boss_rush", "round", round_index)
	file.set_value("boss_rush", "saved_at", Time.get_datetime_string_from_system().replace("T", " "))
	file.save(PATH)


static func has_save() -> bool:
	return saved_round() >= 0


## The saved round (0-based), or -1 if there's no save.
static func saved_round() -> int:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return -1
	return int(file.get_value("boss_rush", "round", -1))


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
