extends SceneTree
# Not a test (GIF frames, FRAMES = folder): the Living Armor's Combo throws
# the Knight and the Monk; physics ragdolls fly, sprawl and get back up.
var a
var t := 0.0
var step := 0
var la
var hit := []
var cam
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/monk.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func frame(d):
	if OS.get_environment("FRAMES") != "" and int(t / 0.05) != int((t - d) / 0.05):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/%d%04d.png" % [step, int(t / 0.05)])
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true; c.timeline_pos = 0.0
			la = a.enemies[0]
			var kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			var mk = a.party.filter(func(p): return p.class_id == "monk")[0]
			var cl = a.party.filter(func(p): return p.class_id == "cleric")[0]
			la.global_position = Vector3(-4, 0, -1)
			kn.global_position = Vector3(-2.5, 0, -1.7)
			mk.global_position = Vector3(-2.4, 0, -0.2)
			cl.global_position = Vector3(3.5, 0, 3.5)
			for m in [kn, mk]:
				m.max_hp = 9999; m.hp = 9999
				m.face_toward(la.global_position - m.global_position, 1.0, 1000000.0)
			hit = [kn, mk]
			la.forced_skill = la.skills.filter(func(s): return s.skill_name == "Combo")[0]
			la.timeline_pos = a.cast_zone_start
			a._begin_cast(la); a._reveal_skill(la)
			la.face_toward(Vector3(-2.45, 0, -0.95) - la.global_position, 1.0, 1000000.0)
			cam = Camera3D.new(); root.add_child(cam); cam.make_current()
			cam.global_position = Vector3(-0.6, 3.2, 7.2)
			cam.look_at(Vector3(-0.6, 0.6, -1.0), Vector3.UP)
			step = 1; t = 0
		1:
			frame(d)
			if t < 0.5: return false
			a.active = null
			a._enemy_unleash(la, false)
			step = 2; t = 0
		2:
			frame(d)
			if t < 6.5: return false
			quit()
			return true
	return false
