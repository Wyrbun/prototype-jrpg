extends SceneTree
# Triple Rush with hit 2 pressed 0.08 s late: that press must count as LATE
# (no Perfect), not as a too-early press for the Hold (a miss ending the chain).
var a
var t := 0.0
var step := 0
var m
var pressed := {}
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func key(down):
	var ev := InputEventAction.new(); ev.action = "confirm"; ev.pressed = down
	a._menu_input(ev)
func _process(d):
	t += d
	if step == 0 and t > 0.6:
		ArtsBook.discover("monk", "Triple Rush")
		for c in a.combatants: c.hold = true
		m = a.party[0]; var g = a.enemies[0]
		m.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
		m.tokens = {"Triple": 1, "Rush": 1}; m.climb_step(); print("bar ", m.combo_limit)
		a._set_controlled(m); a.active = m; a.ap = 200; a.current_max_ap = 200; a._command_phase = false
		a._open_combo_bar(g)
		for i in [0, 0, 1, 3]: a._add_to_combo(i)
		print("plan: ", a._parse_combo(false).map(func(x): return x["move"]["name"]))
		a._execute_combo()
		step = 1
	elif step == 1:
		if a._menu_mode != BattleMenu.Mode.EXECUTING:
			var r = a.battle_menu.slot_results[0]
			var ok: bool = r[1] == 0 and r[2] == 1
			print(("ok   " if ok else "FAIL ") + "late press forgiven, Hold still Perfect: %s" % [r])
			print("FAILS: %d" % (0 if ok else 1))
			quit(); return true
		if a._exec_lead_in > 0 or a._exec_reveal_left > 0: return false
		var e = a._plan[a._exec_slot]
		var dur: float = e["duration"]; var win: float = float(e["window"]) * dur
		var times: Array = e["times"]
		var n := times.size()
		for i in n - 1:
			var ht: float = dur * float(times[i])
			var at := ht + 0.08 if i == 1 else ht - win * 0.5
			if not pressed.has(i) and a._exec_time >= at:
				pressed[i] = true; key(true); key(false)
				print("press hit %d at %.3f (box %.3f..%.3f)" % [i, a._exec_time, ht - win, ht])
		var hs: float = dur * float(e["hold_start"])
		if not pressed.has("hold") and a._exec_time >= hs - win * 0.5:
			pressed["hold"] = true; key(true); print("hold at %.3f (box %.3f..%.3f)" % [a._exec_time, hs - win, hs])
		var lt: float = dur * float(times[n - 1])
		if pressed.has("hold") and not pressed.has("rel") and a._exec_time >= lt - win * 0.5:
			pressed["rel"] = true; key(false); print("release at %.3f (box %.3f..%.3f)" % [a._exec_time, lt - win, lt])
	return false
