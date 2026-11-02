class_name Keybinds
extends RefCounted
## Rebindable keys. Every action keeps its extra keys (arrows, Enter,
## Backspace, keypad Enter); only its main key changes. Esc is fixed so the
## pause menu can always be reached.
##
## Changes are saved in the game's user data folder (user://keybinds.cfg) and
## applied when the game starts. Hints on screen are written with tokens like
## {confirm} and filled in with fill(), so they always show the current keys.

const PATH := "user://keybinds.cfg"

## [action, label, token] in the order the Keys page lists them.
const ACTIONS := [
	["move_forward", "Move up / menu up", "up"],
	["move_back", "Move down / menu down", "down"],
	["move_left", "Move left", "left"],
	["move_right", "Move right", "right"],
	["confirm", "Confirm / add move / timed hit", "confirm"],
	["cancel", "Back / remove last move", "cancel"],
	["end_turn", "Begin the combo", "begin"],
	["parry", "Parry", "parry"],
	["defend", "Defend", "defend"],
	["swap_character", "Switch party member", "swap"],
	["camera_left", "Turn camera left", "cam_l"],
	["camera_right", "Turn camera right", "cam_r"],
	["camera_reset", "Reset camera", "cam_reset"],
	["restart", "Retry (after a fight)", "restart"],
	["next_round", "Next round", "next"],
	["previous_round", "Previous round", "prev"],
]

static var _applied := false


## Loads saved keys once per run (the title screen and battles both call it).
static func apply_saved() -> void:
	if _applied:
		return
	_applied = true
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for entry in ACTIONS:
		var codes = file.get_value("keys", entry[0], [])
		if typeof(codes) != TYPE_ARRAY or codes.is_empty() or not InputMap.has_action(entry[0]):
			continue
		for event in InputMap.action_get_events(entry[0]):
			if event is InputEventKey:
				InputMap.action_erase_event(entry[0], event)
		var others: Array[InputEvent] = InputMap.action_get_events(entry[0])
		for event in others:
			InputMap.action_erase_event(entry[0], event)
		for code in codes:
			var key := InputEventKey.new()
			key.physical_keycode = int(code)
			InputMap.action_add_event(entry[0], key)
		for event in others:
			InputMap.action_add_event(entry[0], event)


## The action's main key (the first keyboard key bound to it), or 0.
static func main_key(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0


## A short name for the action's main key, e.g. "J", "Space", "Tab".
static func label(action: String) -> String:
	var code := main_key(action)
	if code == 0:
		return "?"
	return OS.get_keycode_string(code)


## Binds a new main key. If another action already uses it as its main key,
## the two swap, so no key ends up doing two things. Saves the result.
static func rebind(action: String, code: int) -> String:
	var old := main_key(action)
	var swapped := ""
	for entry in ACTIONS:
		if entry[0] == action:
			continue
		if main_key(entry[0]) == code:
			_set_main(entry[0], old)
			swapped = entry[1]
		else:
			# An extra key of another action (an arrow, Enter...) moves over.
			for event in InputMap.action_get_events(entry[0]):
				if event is InputEventKey and event.physical_keycode == code:
					InputMap.action_erase_event(entry[0], event)
	_set_main(action, code)
	save()
	return swapped


static func reset_defaults() -> void:
	InputMap.load_from_project_settings()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Saves every keyboard key of every rebindable action, main key first.
static func save() -> void:
	var file := ConfigFile.new()
	for entry in ACTIONS:
		var codes: Array = []
		for event in InputMap.action_get_events(entry[0]):
			if event is InputEventKey:
				codes.append(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		file.set_value("keys", entry[0], codes)
	file.save(PATH)


## Keys that can't be taken: Esc opens the pause menu, O opens the reports
## folder after a fight.
static func reserved(code: int) -> bool:
	return code == KEY_ESCAPE or code == KEY_O


## Replaces tokens like {confirm} or {move} with the current key names.
static func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	for entry in ACTIONS:
		text = text.replace("{%s}" % entry[2], label(entry[0]))
	var move := [label("move_forward"), label("move_left"), label("move_back"), label("move_right")]
	var all_single := true
	for key in move:
		if key.length() != 1:
			all_single = false
	text = text.replace("{move}", "".join(move) if all_single else " / ".join(move))
	return text


static func _set_main(action: String, code: int) -> void:
	if code == 0 or not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	var replaced := false
	for event in events:
		if event is InputEventKey:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_erase_event(action, event)
			InputMap.action_add_event(action, key)
			replaced = true
			break
	if not replaced:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	# Keep the main key first so label() finds it: re-add the extras after it.
	var rest: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if not (event is InputEventKey and (event.physical_keycode == code)):
			rest.append(event)
	for event in rest:
		InputMap.action_erase_event(action, event)
		InputMap.action_add_event(action, event)
