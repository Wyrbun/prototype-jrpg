class_name ArtsBook
extends RefCounted
## Which Arts the player has discovered (performed at least once), per class.
## Undiscovered Arts stay hidden (the Arts list only counts them) until they
## are revealed mid-combo. Saved in user://arts.cfg.

const PATH := "user://arts.cfg"

static var _file: ConfigFile = null


static func _load() -> ConfigFile:
	if _file == null:
		_file = ConfigFile.new()
		_file.load(PATH)  # missing file: nothing discovered yet
	return _file


static func known(class_id: String, art_name: String) -> bool:
	return bool(_load().get_value(class_id, art_name, false))


## Marks an Art as discovered. Returns true if it's new.
static func discover(class_id: String, art_name: String) -> bool:
	if known(class_id, art_name):
		return false
	_load().set_value(class_id, art_name, true)
	_file.save(PATH)
	return true


## How many Arts have been discovered, across every class.
static func count() -> int:
	var total := 0
	for section in _load().get_sections():
		for key in _file.get_section_keys(section):
			if bool(_file.get_value(section, key, false)):
				total += 1
	return total


## Forgets everything, so every Art is a surprise again (title menu, tests).
static func reset() -> void:
	_file = ConfigFile.new()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
