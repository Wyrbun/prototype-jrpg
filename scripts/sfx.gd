class_name Sfx
extends Node
## Music and sound effects. Static calls from anywhere: Sfx.play("hit_blade"),
## Sfx.music("battle"). The first call puts one Sfx node under the tree's
## root (it outlives scene changes), with a pool of players for sounds and
## one for music. It keeps running while the game is paused (menus).
##
## Sounds live in res://audio/sfx: "name.ogg" (or .wav), or variants
## "name_1.ogg", "name_2.wav"... of which one is picked at random each time.
## Music lives in res://audio/music and loops. Credits: audio/CREDITS.md.

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"
## Players in the pool: the oldest is reused when they're all busy.
const VOICES := 16
## The same sound isn't started twice within this many seconds (one blow
## landing on three enemies plays once).
const REPEAT_GAP := 0.045
## Music sits under the sounds; quieter still while a menu covers the fight.
const MUSIC_DB := -7.0
const DUCK_DB := -9.0
const FADE := 0.6
## Per-sound loudness, in dB, on top of what the caller asks for
## (-6 dB is about half as loud).
const LEVELS := {"menu_confirm": -6.0, "victory": -2.5}
## A track's menu version (an 8-bit take, say): "<track>_8bit".
const MENU_SUFFIX := "_8bit"

static var _node: Sfx
static var _variants := {}  # name -> Array of paths
static var _streams := {}  # path -> AudioStream
static var _scanned := false

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}  # name -> msec
var _music: AudioStreamPlayer
var _music_name := ""
var _fade_in := true  # the next track fades in (false: starts at full volume)
var _ducked := false
var _fade: Tween


# --- Static API ----------------------------------------------------------------

## Plays a sound (a name from res://audio/sfx, without the number or
## extension). volume_db: louder or softer than usual; pitch: 1 = as recorded,
## with a little random wobble on top so repeats don't sound identical.
static func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var node := _instance()
	if node != null:
		node._play(sound, volume_db, pitch)


## Plays a sound after `seconds` (a heal's number popping up after the cast).
static func play_later(sound: String, seconds: float, volume_db := 0.0) -> void:
	var node := _instance()
	if node == null or not node.is_inside_tree():
		return
	node.get_tree().create_timer(seconds, true).timeout.connect(func(): Sfx.play(sound, volume_db))


## Plays one of the sounds at random.
static func play_any(sounds: Array, volume_db := 0.0) -> void:
	if not sounds.is_empty():
		play(String(sounds[randi() % sounds.size()]), volume_db)


## Starts a music track (a file name in res://audio/music, no extension),
## fading out whatever plays now. The same track keeps playing; "" stops.
## fade_in false: it starts at full volume (after a jingle, say).
static func music(track: String, fade_in := true) -> void:
	var node := _instance()
	if node != null:
		node._fade_in = fade_in
		node._start_music(track)


static func stop_music() -> void:
	music("")


## The track playing (or about to): "" for none.
static func current_music() -> String:
	return _node._music_name if is_instance_valid(_node) else ""


## Quieter music while a menu (pause, the Command List) covers the fight.
## If the track has a menu version ("<track>_8bit" in res://audio/music),
## it switches to that instead, at the same point of the tune, and back.
static func duck(on: bool) -> void:
	var node := _instance()
	if node != null and node._ducked != on:
		node._ducked = on
		if not node._swap_menu_version():
			node._apply_music_volume(0.25)


## Settings changed the volumes.
static func apply_volumes() -> void:
	if is_instance_valid(_node):
		_node._apply_music_volume(0.0)


## Menu keys: the cursor moving, a choice, backing out. Call it from a menu's
## input handler with the event it got.
static func menu_keys(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		play("menu_move")
	elif event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		play("menu_confirm")
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		play("menu_back")


## True if there's a sound by this name.
static func has(sound: String) -> bool:
	_scan()
	return _variants.has(sound)


static func _instance() -> Sfx:
	if is_instance_valid(_node):
		return _node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_node = Sfx.new()
	_node.name = "Sfx"
	# The root may be busy adding the first scene: add it a moment later.
	tree.root.add_child.call_deferred(_node)
	return _node


## Every sound file, grouped by name ("hit_blade_2.ogg" is a "hit_blade").
static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	for file in _list(SFX_DIR):
		var base := file.get_basename()
		var parts := base.rsplit("_", true, 1)
		var key := parts[0] if parts.size() == 2 and parts[1].is_valid_int() else base
		if not _variants.has(key):
			_variants[key] = []
		_variants[key].append(SFX_DIR + "/" + file)


## Sound files in a folder (in an exported game, only the .import files are
## listed: their names lead to the sounds).
static func _list(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension() in ["ogg", "wav", "mp3"] and not found.has(file):
			found.append(file)
	found.sort()
	return found


static func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


# --- The node ------------------------------------------------------------------

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	add_child(_music)


func _ready() -> void:
	if _music_name != "" and not _music.playing:
		_begin_track(_music_name)


func _play(sound: String, volume_db: float, pitch: float) -> void:
	if not is_inside_tree():
		return  # the very first frame: nothing to hear yet
	var percent := Settings.sound_volume() * Settings.master_volume() / 100.0
	if percent <= 0:
		return
	_scan()
	var paths: Array = _variants.get(sound, [])
	if paths.is_empty():
		push_warning("Sfx: no sound named " + sound)
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < REPEAT_GAP * 1000.0:
		return
	_last_played[sound] = now
	var stream := _stream(String(paths[randi() % paths.size()]))
	if stream == null:
		return
	var voice := _free_voice()
	voice.stream = stream
	voice.volume_db = volume_db + float(LEVELS.get(sound, 0.0)) + linear_to_db(percent / 100.0)
	voice.pitch_scale = pitch * randf_range(0.96, 1.04)
	voice.play()


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return voice


func _start_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	if not is_inside_tree():
		return  # _ready starts it
	if _fade:
		_fade.kill()
	if _music.playing:
		_fade = create_tween()
		_fade.tween_property(_music, "volume_db", -60.0, FADE * 0.5)
		_fade.tween_callback(func(): _begin_track(_music_name))
	else:
		_begin_track(track)


func _begin_track(track: String) -> void:
	_music.stop()
	if track == "":
		return
	var stream := _track(track + MENU_SUFFIX) if _ducked else null
	if stream == null:
		stream = _track(track)
	if stream == null:
		push_warning("Sfx: no music named " + track)
		return
	_music.stream = stream
	_music.play()
	if _fade_in:
		_music.volume_db = -40.0
		_apply_music_volume(FADE)
	else:
		_apply_music_volume(0.0)


## A music file by name (looping), or null.
func _track(track: String) -> AudioStream:
	for file in _list(MUSIC_DIR):
		if file.get_basename() == track:
			var stream := _stream(MUSIC_DIR + "/" + file)
			if stream != null and "loop" in stream:
				stream.set("loop", true)
			return stream
	return null


## Menu opened or closed: swaps to the track's menu version (or back) at the
## same point of the tune. False if the track has no menu version.
func _swap_menu_version() -> bool:
	if _music_name == "" or not _music.playing:
		return false
	var menu := _track(_music_name + MENU_SUFFIX)
	if menu == null:
		return false
	var to := menu if _ducked else _track(_music_name)
	var from := _music.stream
	if to == null or to == from:
		return false
	var at := _music.get_playback_position()
	var from_length := from.get_length()
	if from_length > 0.0 and to.get_length() > 0.0:
		at = fmod(at, from_length) / from_length * to.get_length()  # same point, if the versions differ in length
	_music.stream = to
	_music.play(at)
	_apply_music_volume(0.0)
	return true


func _music_db() -> float:
	var percent := Settings.music_volume() * Settings.master_volume() / 100.0
	if percent <= 0:
		return -80.0
	return MUSIC_DB + linear_to_db(percent / 100.0) + (DUCK_DB if _ducked else 0.0)


func _apply_music_volume(seconds: float) -> void:
	if _fade:
		_fade.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_music.volume_db = _music_db()
		return
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", _music_db(), seconds)
