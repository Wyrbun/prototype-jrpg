class_name Settings
## Player options that last between sessions (user://settings.cfg).
## Read the values through the getters: the file loads on first use.

const PATH := "user://settings.cfg"

static var _loaded := false
static var _move_details := true
static var _command_windup := true


## The details box beside the move and Ability lists (what a move does,
## beyond its one-line description). On by default.
static func move_details() -> bool:
	_load()
	return _move_details


static func set_move_details(on: bool) -> void:
	_load()
	_move_details = on
	_save()


## Command timing (Windup is the default): off = classic (choose at the end of the
## timeline); on = windup (choose at the command point, then get in reach
## before your icon reaches the end).
static func command_windup() -> bool:
	_load()
	return _command_windup


static func set_command_windup(on: bool) -> void:
	_load()
	_command_windup = on
	_save()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		_move_details = bool(file.get_value("ui", "move_details", true))
		_command_windup = bool(file.get_value("battle", "command_windup", true))


static func _save() -> void:
	var file := ConfigFile.new()
	file.load(PATH)  # keep anything else stored there
	file.set_value("ui", "move_details", _move_details)
	file.set_value("battle", "command_windup", _command_windup)
	file.save(PATH)
