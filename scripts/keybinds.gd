class_name Keybinds
extends RefCounted
## Rebindable keys and pad buttons. Every action keeps its extra keys
## (arrows, Enter, Backspace, keypad Enter); only its main key changes. Esc
## (and the pad's Menu button) is fixed so the pause menu can always be
## reached. The pad (Xbox layout) gets PAD_DEFAULTS; its main button can be
## changed the same way (rebind_pad). Hints name the pad's buttons while the
## pad is in use (Pad.active).
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

## The pad's defaults, Xbox layout: per action, buttons ["b", button] and
## stick or trigger directions ["a", axis, direction]. The first button is
## the action's main pad button (the one Change Keys shows and changes).
const PAD_DEFAULTS := {
	"move_forward": [["b", JOY_BUTTON_DPAD_UP], ["a", JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [["b", JOY_BUTTON_DPAD_DOWN], ["a", JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [["b", JOY_BUTTON_DPAD_LEFT], ["a", JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [["b", JOY_BUTTON_DPAD_RIGHT], ["a", JOY_AXIS_LEFT_X, 1.0]],
	"confirm": [["b", JOY_BUTTON_A]],
	"cancel": [["b", JOY_BUTTON_B]],
	"end_turn": [["b", JOY_BUTTON_X]],
	"swap_character": [["b", JOY_BUTTON_Y]],
	"parry": [["b", JOY_BUTTON_RIGHT_SHOULDER]],
	"defend": [["b", JOY_BUTTON_LEFT_SHOULDER]],
	"camera_left": [["a", JOY_AXIS_RIGHT_X, -1.0]],
	"camera_right": [["a", JOY_AXIS_RIGHT_X, 1.0]],
	"camera_reset": [["b", JOY_BUTTON_RIGHT_STICK]],
	"menu": [["b", JOY_BUTTON_START]],
	"restart": [["b", JOY_BUTTON_BACK]],
	# Pad only (made at start-up): the right stick tilts the camera.
	"camera_tilt_up": [["a", JOY_AXIS_RIGHT_Y, -1.0]],
	"camera_tilt_down": [["a", JOY_AXIS_RIGHT_Y, 1.0]],
}

static var _applied := false


## Loads saved keys once per run (the title screen and battles both call it).
static func apply_saved() -> void:
	Pad.ensure()
	if _applied:
		return
	_applied = true
	add_pad_defaults()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for entry in ACTIONS:
		var button := int(file.get_value("pad", entry[0], -1))
		if button >= 0:
			_set_main_pad(entry[0], button)
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


## What to press for the action, on the device in use: the main key
## ("J", "Space", "Tab") or, while the pad is in use, its button ("A", "RB").
static func label(action: String) -> String:
	if Pad.active:
		var pad := pad_label(action)
		if pad != "":
			return pad
	return key_label(action)


## The action's main keyboard key, by name.
static func key_label(action: String) -> String:
	var code := main_key(action)
	if code == 0:
		return "?"
	return OS.get_keycode_string(code)


## The action's main pad button (-1 if it has none).
static func main_pad(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return -1


## The pad's control for the action: its main button, else its stick
## direction ("RS left"); "" if the pad doesn't do it.
static func pad_label(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var button := main_pad(action)
	if button >= 0:
		return Pad.button_name(button)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return Pad.axis_name(event.axis, event.axis_value)
	return ""


## Adds the pad's default buttons and stick directions to every action that
## has no pad input yet (the project's input map is keyboard only).
static func add_pad_defaults() -> void:
	for action in PAD_DEFAULTS:
		if not InputMap.has_action(action):
			if not action.begins_with("camera_tilt"):
				continue
			InputMap.add_action(action, 0.2)  # pad-only actions the project doesn't list
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		if has_pad:
			continue
		for spec in PAD_DEFAULTS[action]:
			if spec[0] == "b":
				var button := InputEventJoypadButton.new()
				button.button_index = spec[1]
				InputMap.action_add_event(action, button)
			else:
				var motion := InputEventJoypadMotion.new()
				motion.axis = spec[1]
				motion.axis_value = spec[2]
				InputMap.action_add_event(action, motion)


## Pad buttons that can't be taken: Menu opens the pause menu.
static func reserved_pad(button: int) -> bool:
	return button == JOY_BUTTON_START or button == JOY_BUTTON_GUIDE


## Binds a new main pad button; another action using it as its main button
## gets this one's old button (a swap). Saves. Returns the swapped row's label.
static func rebind_pad(action: String, button: int) -> String:
	var old := main_pad(action)
	var swapped := ""
	for entry in ACTIONS:
		if entry[0] != action and main_pad(entry[0]) == button:
			_set_main_pad(entry[0], old)
			swapped = entry[1]
	_set_main_pad(action, button)
	save()
	return swapped


## The action's main pad button becomes `button` (-1: it has none).
static func _set_main_pad(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
			break
	if button < 0:
		return
	var press := InputEventJoypadButton.new()
	press.button_index = button
	# The main button goes first (main_pad finds the first one).
	var rest: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		rest.append(event)
		InputMap.action_erase_event(action, event)
	InputMap.action_add_event(action, press)
	for event in rest:
		InputMap.action_add_event(action, event)


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
	add_pad_defaults()
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
		file.set_value("pad", entry[0], main_pad(entry[0]))
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
	text = text.replace("{move}", "Left stick" if Pad.active else ("".join(move) if all_single else " / ".join(move)))
	if Pad.active:
		text = _pad_words(text)
	return text


## Hints written for the keyboard, reworded for the pad: the extra keys
## (Enter, Backspace) and the mouse go, Esc is the Menu button.
static func _pad_words(text: String) -> String:
	for gone in [" (or Enter)", " (or Backspace)", " / Enter", " / Backspace", ", Enter", " or right-drag",
			", right-drag", " or a right-drag"]:
		text = text.replace(gone, "")
	return text.replace("Esc", "Menu")


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
