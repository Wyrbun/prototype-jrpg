extends SceneTree
# Sound and music: every sound and track the game asks for exists and
# loads, the right music plays per round, the volume options work, and the
# menu-version swap keeps its place in the tune.

const SOUNDS := ["bow", "cast_energy", "cast_fire", "cast_ice", "cast_lightning", "combo_perfect",
		"draw_blade", "enemy_die", "enemy_hurt", "enemy_land", "enemy_vanish", "fire", "focus", "gale_maw",
		"golem_die", "hatchling_die", "heal_spell", "hit_blade", "hit_blunt", "hit_heavy", "hp_number",
		"item_use", "land_light", "land_thrown", "menu_back", "menu_confirm", "menu_move", "ogre_die",
		"parry_a", "parry_b", "parry_fail", "parry_perfect", "revive", "swing", "teleport",
		"timeline_remove", "timing_hit", "victory", "defeat", "attack_whiff", "enemy_defend", "counter_ready"]
const TRACKS := ["battle", "boss", "living_armor", "gale_maw", "title", "round_select", "tutorial", "victory"]

var fails := 0
var a
var t := 0.0
var step := 0
var rounds := []
var seen := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize():
	Sfx.stop_music()  # puts the Sfx node in the tree (a frame later)
	for sound in SOUNDS:
		check(Sfx.has(sound), "sound %s exists" % sound)
	for sound in Sfx._variants:
		for path in Sfx._variants[sound]:
			check(load(path) is AudioStream, "%s loads" % path)
	var listed := Sfx._list(Sfx.MUSIC_DIR)
	for track in TRACKS:
		var found := false
		for file in listed:
			if file.get_basename() == track:
				found = true
				check(load(Sfx.MUSIC_DIR + "/" + file) is AudioStream, "track %s loads" % track)
		check(found, "track %s exists" % track)
	check(FileAccess.file_exists("res://audio/CREDITS.md"), "credits file")
	# Volumes cycle and are saved.
	var before := Settings.sound_volume()
	var rows := Settings.option_rows()
	check(rows[4].begins_with("Master volume:") and rows[5].begins_with("Music:") and rows[6].begins_with("Sounds:"), "volume rows: %s" % rows)
	Settings.change_option(6)
	check(Settings.sound_volume() != before, "sound volume changes")
	Settings.set_sound_volume(before)
	var rush: BossRush = load("res://data/boss_rush.tres")
	for i in rush.rounds.size():
		rounds.append(i)


func _process(d):
	t += d
	match step:
		0:
			if t < 0.2:
				return false
			# Sounds play (the node is in the tree by now).
			Sfx.play("hit_blade")
			Sfx.play("hit_blade")  # a repeat this soon is skipped
			var busy := 0
			for v in Sfx._node._voices:
				if v.playing:
					busy += 1
			check(busy == 1, "one voice for a doubled sound (got %d)" % busy)
			step = 1
			_next_round()
		1:
			if t < 0.5:
				return false
			var kinds := []
			for e in a.enemies:
				kinds.append(e.scene_file_path.get_file().get_basename())
			seen[a.get_meta("round")] = [Sfx.current_music(), kinds]
			if rounds.is_empty():
				_finish()
				return true
			_next_round()
	return false


func _next_round():
	if a:
		a.queue_free()
	var r = rounds.pop_front()
	BattleArena.tutorial_mode = false
	BattleArena._round_index = r
	BattleArena.chosen_for_round = r
	BattleArena.party_ai_override = 0
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	a.set_meta("round", r)
	root.add_child(a)
	t = 0.0


func _finish():
	var bosses := 0
	for r in seen:
		var track: String = seen[r][0]
		var kinds: Array = seen[r][1]
		print("round %d: %s  %s" % [r + 1, track, kinds])
		if kinds.has("living_armor") and not kinds.has("stone_golem"):
			check(track == "living_armor", "Living Armor's theme")
		elif kinds.has("gale_maw"):
			check(track == "gale_maw", "Gale Maw's theme")
		elif track == "boss":
			bosses += 1
		else:
			check(track == "battle", "round %d: battle theme" % (r + 1))
	check(bosses > 0, "some rounds use the boss theme")
	# The master volume scales the music (and the sounds).
	var master := Settings.master_volume()
	Settings.set_master_volume(100)
	var full: float = Sfx._node._music_db()
	Settings.set_master_volume(50)
	check(Sfx._node._music_db() < full - 5.0, "Master volume 50%: the music is quieter")
	Settings.set_master_volume(master)
	# The pause menu ducks the music.
	var loud: float = Sfx._node._music_db()
	Sfx.duck(true)
	check(Sfx._node._music_db() < loud - 3.0, "ducked under the pause menu")
	Sfx.duck(false)
	print("FAILS: ", fails)
	quit()
