extends SceneTree
# Not a test: records a Knight combo on the Golem for a README GIF (timed
# presses aimed at Perfects, Arts revealed mid-combo). FRAMES = folder,
# FPS = frames per second saved.
var a
var t := 0.0
var step := 0
var n := 0
var kn
var g
func _initialize():
	ArtsBook.reset()
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func press(action):
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new(); up.action = action; up.pressed = false
	Input.parse_input_event(up)
func idx(name):
	for i in a._moves.size():
		if a._moves[i]["name"] == name: return i
func grab():
	var fps := float(OS.get_environment("FPS"))
	if int(t * fps) != int((t - get_process_delta()) * fps):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%04d.png" % n)
		n += 1
var _d := 0.0
func get_process_delta(): return _d
func _process(d):
	_d = d
	t += d
	match step:
		0:
			if t < 1.0: return false
			for c in a.combatants: c.hold = true
			kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			g = a.enemies[0]
			g.global_position = Vector3(0, g.global_position.y, -2)
			kn.global_position = g.global_position + Vector3(g.body_radius + kn.body_radius + 0.35, 0, 0.6)
			kn.face_toward(g.global_position - kn.global_position, 1.0, 100000.0)
			a._set_controlled(kn); a.active = kn; a.current_max_ap = 200; a.ap = 200; a._command_phase = false
			a._open_combo_bar(g)
			step = 1; t = 0
		1:
			grab()
			# build the bar one move at a time, like a player would
			var plan = ["Slash", "Slash", "Thrust", "Slash", "Guard Strike"]
			var k := int(t / 0.35)
			if k >= 1 and k <= plan.size() and a._plan.size() < k:
				a._add_to_combo(idx(plan[k - 1]))
			if t > 0.35 * plan.size() + 0.7:
				a._execute_combo()
				step = 2
		2:
			grab()
			if a._menu_mode == BattleMenu.Mode.EXECUTING:
				var e = a._plan[a._exec_slot]; var h = a._exec_hits_done
				if h < e["times"].size() and a._exec_lead_in <= 0:
					var ht = e["duration"] * e["times"][h]
					if a._exec_time >= ht - e["window"] * e["duration"] * 0.5 and a._exec_timings[h] == 0: press("confirm")
			elif t > 30.0 or a._menu_mode != BattleMenu.Mode.EXECUTING:
				step = 3; t = 0
		3:
			grab()
			if t > 1.2:
				quit(); return true
	return false
