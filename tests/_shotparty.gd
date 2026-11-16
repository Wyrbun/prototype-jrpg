extends SceneTree
# Screenshots: each class's attack effect, timed to the combo. For every
# case, one PNG mid-approach (just before the hit) and one at the impact
# (Perfect: the first hit is pressed in its box). OUT=folder.
# Run with --fixed-fps 60: slow software rendering skews the timing otherwise.
var a
var t := 0.0
var step := 0
var ci := 0
var cam: Camera3D
var shots := 0
var cases := [["knight", ["Slash"]], ["archer", ["Shoot"]], ["assassin", ["Stab"]], ["cleric", ["Bash"]], ["monk", ["Heavy Punch"]], ["mage", ["Fire"]]]
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/assassin.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func who(id):
	for x in a.party:
		if x.class_id == id: return x
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
	return -1
func save(tag):
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s_%s.png" % [cases[ci][0], tag])
	print("saved %s_%s" % [cases[ci][0], tag])
func _process(d):
	t += d
	a._intro_left = 0.0
	a._flash_time_left = 0.0
	if step == 0:
		if t < 0.8: return false
		for c in a.combatants: c.hold = true
		cam = Camera3D.new()
		root.add_child(cam)
		cam.make_current()
		step = 1
	if ci >= cases.size():
		return true
	var g = a.enemies[0]
	match step:
		1:
			var f = who(cases[ci][0])
			for m in a.party:
				if m != f: m.global_position = Vector3(-12, m.global_position.y, 8)
			var reach: float = 4.0 if f.class_id in ["archer", "mage"] else 0.35
			f.global_position = g.global_position + Vector3(-0.6, 0, g.body_radius + f.body_radius + reach)
			f.face_toward(g.global_position - f.global_position, 1.0, 100000.0)
			cam.global_position = g.global_position + Vector3(5.5, 3.2, 3.5 + reach)
			cam.look_at(g.global_position + Vector3(-0.3, 1.0, reach * 0.5), Vector3.UP)
			a._set_controlled(f); a.active = f; a.current_max_ap = 300; a.ap = 300; a._command_phase = false
			a._open_combo_bar(g)
			for n in cases[ci][1]: a._add_to_combo(idx(n))
			if a._plan.is_empty():
				ci += 1
				return false
			a._execute_combo()
			a._exec_lead_in = 0.0
			step = 2
		2:
			var e = a._plan[a._exec_slot]
			var h = a._next_timed(e)
			var hit_time: float = float(e["duration"]) * float(e["times"][mini(h, e["times"].size() - 1)])
			if a._exec_time >= hit_time - float(OS.get_environment("EARLY") if OS.get_environment("EARLY") != "" else "0.09"):
				save("approach")
				# Press in its box: a Perfect.
				if h < e["hits"].size() and int(e["timing"]) == 0:
					a._exec_time = maxf(a._exec_time, hit_time - 0.02)
					a._judge_timing()
				elif int(e["timing"]) == 3:
					for dir in e["code"]: a._judge_code(dir)
				step = 3
		3:
			if a._exec_hits_done > 0:
				step = 4; t = 0.0
		4:
			if t >= 0.07:
				save("impact")
				a._stop_combo()
				a._menu_mode = BattleMenu.Mode.HIDDEN
				a.active = null
				ci += 1
				step = 5; t = 0.0
		5:
			if t > 1.0: step = 1
	return false
