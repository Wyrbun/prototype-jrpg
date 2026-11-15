extends SceneTree
# Monk: earning a step / token mid-combo doesn't move the rest of the bar.
var a
var t := 0.0
var step := 0
var fails := 0
var before := {}
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
func layout():
	var m = a.battle_menu
	return {"first": m.consumed_slots, "px": m._px}
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			ArtsBook.reset()
			for n in ["Knee Smash", "Flash Kick"]: ArtsBook.discover("monk", n)
			for c in a.combatants: c.hold = true
			var g = a.enemies[0]; var m = a.party[0]
			m.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
			a._set_controlled(m); a.active = m; a.current_max_ap = 300; a.ap = 300; a._command_phase = false
			a._open_combo_bar(g)
			for n in ["Kick", "Heavy Kick", "Kick", "Kick"]: a._add_to_combo(idx(n))
			print("plan: ", a._plan.map(func(x): return x["name"]))
			a._execute_combo()
			step = 1; t = 0
		1:
			if a._exec_lead_in > 0.0 or a._exec_reveal_left > 0.0: return false
			if before.is_empty() and t > 0.1:
				before = layout()
				before["limit"] = a.party[0].combo_limit
			# play: perfect the Hold on slot 0 (Knee Smash climbs a step)
			if a._exec_slot == 0:
				var e = a._plan[0]; var dur = float(e["duration"])
				var hs = dur * float(e["hold_start"])
				if not a._exec_holding and a._exec_timings[0] == 0 and a._exec_time >= hs - 0.03:
					a._judge_timing()
				if a._exec_holding and a._exec_time >= dur * float(e["times"][0]) - 0.03:
					a._judge_release()
			if a._exec_slot >= 1 and step == 1:
				var after = layout()
				check(a.party[0].combo_limit > before["limit"], "Knee Smash climbed a step (bar %d -> %d)" % [before["limit"], a.party[0].combo_limit])
				check(after["first"] == before["first"], "played blocks stay on the bar (first visible %d -> %d)" % [before["first"], after["first"]])
				check(is_equal_approx(after["px"], before["px"]), "same scale (%.1f -> %.1f px/AP)" % [before["px"], after["px"]])
				print("FAILS: %d" % fails)
				return true
			if t > 20: print("timeout"); return true
	return false
