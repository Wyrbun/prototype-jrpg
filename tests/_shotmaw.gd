extends SceneTree
# Screenshots: every Gale Maw skill telegraphed, from above (one PNG each in
# the folder OUT). The party is spread across the arena.
var a
var t := 0.0
var maw
var cam: Camera3D
var i := 0
var phase := 0
var wait := 0.0
var spots := [Vector3(-5, 0, 2), Vector3(-1.5, 0, -1), Vector3(2, 0, 3.5), Vector3(5.5, 0, 0.5)]
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.8: return false
	if maw == null:
		maw = a.enemies[0]
		for c in a.combatants: c.hold = true
		for k in a.party.size():
			a.party[k].global_position = a.arena.global_position + spots[k]
		cam = Camera3D.new()
		root.add_child(cam)
		cam.global_position = a.arena.global_position + Vector3(0, 17, 10.5)
		cam.look_at(a.arena.global_position + Vector3(0, 0, -0.5), Vector3.UP)
		cam.fov = 60
		cam.make_current()
	a._intro_left = 0.0  # no intro or flash text over the picture
	a._flash_time_left = 0.0
	if i >= maw.skills.size():
		return true
	var s: EnemySkill = maw.skills[i]
	if phase == 0:
		maw.forced_skill = s
		maw.timeline_pos = a.cast_zone_start + 1.0
		a._begin_cast(maw)
		maw.timeline_pos = a.cast_zone_start + 12.0
		a._reveal_skill(maw)
		phase = 1; wait = 0.0
	elif phase == 1:
		wait += d
		if wait > 0.5:
			var name := "%02d_%s.png" % [i + 1, s.skill_name.to_lower().replace(" ", "_")]
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + name)
			print("saved ", name)
			a._finish_enemy_skill(maw, false)
			maw.forced_skill = null
			i += 1; phase = 0
	return false
