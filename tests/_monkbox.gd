extends SceneTree
# Timing boxes: a press anywhere inside the drawn box counts (Monk especially).
var a
var t := 0.0
var step := 0
var fails := 0
var cases := [["monk", ["Punch", "Punch", "Kick", "Heavy Kick"]], ["monk", ["Kick", "Kick", "Kick", "Heavy Kick"]], ["monk", ["Heavy Punch", "Kick", "Kick", "Kick", "Heavy Kick"]], ["knight", ["Thrust", "Thrust", "Slash"]], ["archer", ["Shot", "Shot", "Shot"]], ["mage", ["Fire", "Ice"]], ["cleric", ["Bash", "Bash"]], ["assassin", ["Stab", "Stab"]]]
var ci := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
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
func _process(d):
	t += d
	if step == 0 and t > 0.8:
		ArtsBook.reset()
		for n in ["Palm Strike", "Flash Kick", "Knee Smash", "Triple Rush", "Mountain Crusher"]: ArtsBook.discover("monk", n)
		for c in a.combatants: c.hold = true
		step = 1; t = 0
	elif step == 1:
		if ci >= cases.size():
			print("FAILS: %d" % fails); return true
		var g = a.enemies[0]
		var f = who(cases[ci][0])
		f.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
		a._set_controlled(f); a.active = f; a.current_max_ap = 300; a.ap = 300; a._command_phase = false
		f.combo_limit = maxi(f.combo_limit, 100) if f.class_id == "monk" else f.combo_limit
		a._open_combo_bar(g)
		for n in cases[ci][1]: a._add_to_combo(idx(n))
		a._execute_combo()
		a._exec_lead_in = 0.0
		step = 2; t = 0
	elif step == 2 and t > 0.15:  # a few drawn frames: the zoom is set
		while a._next_timed(a._plan[a._exec_slot]) >= a._plan[a._exec_slot]["hits"].size() and a._exec_slot + 1 < a._plan.size():
			a._start_combo_slot(a._exec_slot + 1)
		var e = a._plan[a._exec_slot]
		var px: float = a.battle_menu._px
		var seg: float = float(e["cost"]) * px
		var real_px: float = float(e["window"]) * seg
		var frac: float = a.battle_menu.box_fraction(e)
		var names = a._plan.map(func(x): return x["name"])
		print("%s %s: px/AP %.1f, window %.1f px -> box %.1f px" % [cases[ci][0], names, px, real_px, frac * seg])
		# Press at the very left edge of the first timed box.
		var dur: float = e["duration"]
		var h = a._next_timed(e)
		var target_time: float
		if h < e["hits"].size() and a._special_hit(e, h) and int(e["timing"]) == 1:
			target_time = dur * float(e["hold_start"])
		else:
			target_time = dur * float(e["times"][h])
		a._exec_time = target_time - frac * dur + 0.002
		a._exec_hits_done = 0
		a._judge_timing()
		var ok = a._exec_holding or a._exec_timings[h] == 1 or a._exec_taps > 0
		if h < e["hits"].size() and int(e["timing"]) in [2, 3] and a._special_hit(e, h): ok = true  # Tap / spell code: no box
		check(ok and a._menu_mode == BattleMenu.Mode.EXECUTING, "  press at the box's left edge counts")
		a._stop_combo()
		a._menu_mode = BattleMenu.Mode.HIDDEN
		ci += 1; step = 1
	return false
