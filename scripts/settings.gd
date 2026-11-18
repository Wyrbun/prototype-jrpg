class_name Settings
## Player options that last between sessions (user://settings.cfg).
## Read the values through the getters: the file loads on first use.

const PATH := "user://settings.cfg"

static var _loaded := false
static var _move_details := true
static var _command_windup := true
static var _party_ai := false
static var _style_chosen := false
static var _screen_filter := "normal"
static var _music_volume := 20
static var _sound_volume := 20
static var _master_volume := 100
static var _camera_speed := 100
static var _mouse_sensitivity := 100
## Which camera directions are mirrored: one of INVERT_MODES.
static var _invert_camera := "off"
const INVERT_MODES := ["off", "x", "y", "both"]
const INVERT_NAMES := {"off": "Off", "x": "X (left / right)", "y": "Y (up / down)", "both": "X and Y"}

## Camera speed steps (percent) the Options rows cycle through.
const CAMERA_STEPS := [100, 125, 150, 200, 50, 75]

## Volume steps (percent) the Options rows cycle through.
const VOLUME_STEPS := [100, 80, 60, 40, 20, 0]

## The screen filter (the PS1 look), from strongest to none.
const SCREEN_FILTERS := ["normal", "light", "off"]
const SCREEN_FILTER_NAMES := {"normal": "Normal", "light": "Light", "off": "Off"}
## What each filter does: lines of the low-resolution screen, colour levels
## per channel, dither strength, smooth (blended) or blocky pixels, and the
## lines of the wobbly vertex grid (0: no wobble).
const SCREEN_FILTER_LOOKS := {
	"normal": {"lines": 360.0, "levels": 48.0, "dither": 0.6, "smooth": false, "snap": 320.0},
	"light": {"lines": 540.0, "levels": 96.0, "dither": 0.3, "smooth": true, "snap": 720.0},
	"off": {"lines": 0.0, "levels": 0.0, "dither": 0.0, "smooth": true, "snap": 0.0},
}


## The screen filter: "normal" (the full PS1 look), "light" (sharper and
## smoother) or "off".
static func screen_filter() -> String:
	_load()
	return _screen_filter


static func set_screen_filter(which: String) -> void:
	_load()
	_screen_filter = which if which in SCREEN_FILTERS else "normal"
	_save()


# --- The Options menu (the title screen's and the pause menu's) -------------

## Its rows, each showing its current value.
static func option_rows() -> Array[String]:
	return [
		"Screen filter: %s" % SCREEN_FILTER_NAMES[screen_filter()],
		"Move details: %s" % ("On" if move_details() else "Off"),
		"Command timing: %s" % ("Windup" if command_windup() else "Classic"),
		"Party AI: %s" % ("On" if party_ai() else "Off"),
		"Master volume: %s" % _volume_name(master_volume()),
		"Music: %s" % _volume_name(music_volume()),
		"Sounds: %s" % _volume_name(sound_volume()),
		"Camera speed: %d%%" % camera_speed(),
		"Mouse sensitivity: %d%%" % mouse_sensitivity(),
		"Invert camera: %s" % INVERT_NAMES[invert_mode()],
	]


static func _volume_name(percent: int) -> String:
	return "Off" if percent <= 0 else "%d%%" % percent


## The line under each row.
static func option_note(row: int) -> String:
	match row:
		0:
			match screen_filter():
				"normal":
					return "The full PS1 look: fat pixels, few colours, wobbly edges"
				"light":
					return "A softer PS1 look: finer, smoother pixels, a gentle wobble"
			return "No filter: a clean, sharp picture"
		1:
			return "The box explaining the highlighted move or Ability"
		2:
			return "Windup (default): choose at COM, act at ACT. Applies from the next fight"
		3:
			return "Allies you aren't steering act on their own; Tab takes one over"
		4:
			return "Everything at once: music and sounds"
		5:
			return "How loud the music plays"
		6:
			return "How loud hits, spells and menu sounds play"
		7:
			return "How fast the right stick (or the camera keys) turns the camera"
		8:
			return "How far the camera turns when you drag with the right mouse button"
		9:
			return "Mirror the camera: left / right (X), up / down (Y), or both"
	return ""


## Changes a row's setting to its next value.
static func change_option(row: int) -> void:
	match row:
		0:
			var next := (SCREEN_FILTERS.find(screen_filter()) + 1) % SCREEN_FILTERS.size()
			set_screen_filter(SCREEN_FILTERS[next])
		1:
			set_move_details(not move_details())
		2:
			set_command_windup(not command_windup())
		3:
			set_party_ai(not party_ai())
		4:
			set_master_volume(_next_volume(master_volume()))
		5:
			set_music_volume(_next_volume(music_volume()))
		6:
			set_sound_volume(_next_volume(sound_volume()))
		7:
			set_camera_speed(_next_camera_step(camera_speed()))
		8:
			set_mouse_sensitivity(_next_camera_step(mouse_sensitivity()))
		9:
			set_invert_mode(INVERT_MODES[(INVERT_MODES.find(invert_mode()) + 1) % INVERT_MODES.size()])


static func _next_camera_step(percent: int) -> int:
	var at := CAMERA_STEPS.find(percent)
	return CAMERA_STEPS[(at + 1) % CAMERA_STEPS.size()] if at >= 0 else 100


## Camera speed with the stick or keys, and with the mouse (percent), and
## whether turning is mirrored. The fight reads them as the camera turns.
static func camera_speed() -> int:
	_load()
	return _camera_speed


static func set_camera_speed(percent: int) -> void:
	_load()
	_camera_speed = clampi(percent, 10, 400)
	_save()


static func mouse_sensitivity() -> int:
	_load()
	return _mouse_sensitivity


static func set_mouse_sensitivity(percent: int) -> void:
	_load()
	_mouse_sensitivity = clampi(percent, 10, 400)
	_save()


## "off", "x" (turning left / right mirrored), "y" (tilting up / down
## mirrored) or "both".
static func invert_mode() -> String:
	_load()
	return _invert_camera


static func set_invert_mode(mode: String) -> void:
	_load()
	_invert_camera = mode if mode in INVERT_MODES else "off"
	_save()


static func invert_x() -> bool:
	return invert_mode() in ["x", "both"]


static func invert_y() -> bool:
	return invert_mode() in ["y", "both"]


static func _next_volume(percent: int) -> int:
	var at := VOLUME_STEPS.find(percent)
	return VOLUME_STEPS[(at + 1) % VOLUME_STEPS.size()] if at >= 0 else VOLUME_STEPS[0]


## The master volume, in percent (0 = off): it scales music and sounds.
static func master_volume() -> int:
	_load()
	return _master_volume


static func set_master_volume(percent: int) -> void:
	_load()
	_master_volume = clampi(percent, 0, 100)
	_save()
	Sfx.apply_volumes()


## Music and sound volume, in percent (0 = off). Sfx applies them, times the
## master volume.
static func music_volume() -> int:
	_load()
	return _music_volume


static func set_music_volume(percent: int) -> void:
	_load()
	_music_volume = clampi(percent, 0, 100)
	_save()
	Sfx.apply_volumes()


static func sound_volume() -> int:
	_load()
	return _sound_volume


static func set_sound_volume(percent: int) -> void:
	_load()
	_sound_volume = clampi(percent, 0, 100)
	_save()
	Sfx.apply_volumes()


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


## Party AI (off by default): party members you aren't steering choose and
## play their own turns, instantly. Tab (or hold Tab) takes one over.
static func party_ai() -> bool:
	_load()
	return _party_ai


static func set_party_ai(on: bool) -> void:
	_load()
	_party_ai = on
	_save()


## The first Boss Rush / Round Select asks for a play style (Command timing
## and Party AI) once; after that, only the pause menu changes them.
static func style_chosen() -> bool:
	_load()
	return _style_chosen


static func set_style_chosen(on: bool) -> void:
	_load()
	_style_chosen = on
	_save()


## Best end-screen rank per round title ("S" / "A" / "B" / "C"; "" = none).
static func best_rank(round_title: String) -> String:
	var file := ConfigFile.new()
	file.load(PATH)
	return String(file.get_value("ranks", round_title, ""))


## Stores a rank if it beats the best so far. Returns the best after it.
static func record_rank(round_title: String, rank: String) -> String:
	var order := "SABC"
	var best := best_rank(round_title)
	if best == "" or order.find(rank) < order.find(best):
		var file := ConfigFile.new()
		file.load(PATH)
		file.set_value("ranks", round_title, rank)
		file.save(PATH)
		best = rank
	return best


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		_move_details = bool(file.get_value("ui", "move_details", true))
		_command_windup = bool(file.get_value("battle", "command_windup", true))
		_party_ai = bool(file.get_value("battle", "party_ai", false))
		_style_chosen = bool(file.get_value("battle", "style_chosen", false))
		_screen_filter = String(file.get_value("video", "screen_filter", "normal"))
		if not _screen_filter in SCREEN_FILTERS:
			_screen_filter = "normal"
		_music_volume = clampi(int(file.get_value("audio", "music_volume", 20)), 0, 100)
		_sound_volume = clampi(int(file.get_value("audio", "sound_volume", 20)), 0, 100)
		_master_volume = clampi(int(file.get_value("audio", "master_volume", 100)), 0, 100)
		_camera_speed = clampi(int(file.get_value("camera", "speed", 100)), 10, 400)
		_mouse_sensitivity = clampi(int(file.get_value("camera", "mouse", 100)), 10, 400)
		var invert = file.get_value("camera", "invert", "off")
		if invert is bool:
			invert = "x" if invert else "off"  # saved before X / Y: it mirrored turning
		_invert_camera = String(invert) if String(invert) in INVERT_MODES else "off"


static func _save() -> void:
	var file := ConfigFile.new()
	file.load(PATH)  # keep anything else stored there
	file.set_value("ui", "move_details", _move_details)
	file.set_value("battle", "command_windup", _command_windup)
	file.set_value("battle", "party_ai", _party_ai)
	file.set_value("battle", "style_chosen", _style_chosen)
	file.set_value("video", "screen_filter", _screen_filter)
	file.set_value("audio", "music_volume", _music_volume)
	file.set_value("audio", "sound_volume", _sound_volume)
	file.set_value("audio", "master_volume", _master_volume)
	file.set_value("camera", "speed", _camera_speed)
	file.set_value("camera", "mouse", _mouse_sensitivity)
	file.set_value("camera", "invert", _invert_camera)
	file.save(PATH)
