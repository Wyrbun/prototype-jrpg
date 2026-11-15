extends SceneTree
var a
var t := 0.0
var done := false
var fails := 0
var tap_count := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	var _rush = load("res://data/boss_rush.tres")
	BattleArena.chosen_for_round = BattleArena._round_index
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func reset():
	for c in a.combatants:
		c.hp = c.max_hp; c.is_down = false; c.shield = 0; c.statuses.clear(); c.hold = true; c.timeline_pos = 10
		c.riposte_left = 0
		if c.team == 1:
			a._finish_enemy_skill(c, false); c.stance = Skills.NONE
	a._strike = null; a.active = null
	for e in a.enemies: e.global_position = Vector3(-6 + a.enemies.find(e) * 4, 0, -6)
	for p in a.party: p.global_position = Vector3(-4 + a.party.find(p) * 5.5, 0, 5)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
func names(): return a._plan.map(func(e): return "%s(%d)" % [e["name"], e["cost"]])
func open_bar(mk, g):
	reset(); g.global_position = Vector3(0, 0, 0); mk.global_position = Vector3(0, 0, 1.8)
	a._set_controlled(mk); a.active = mk; a.current_max_ap = 300; a.ap = 300
	a._open_combo_bar(g)
func add(n): a._add_to_combo(idx(n))
func to(time):
	var g := 0
	while a._exec_time < time - 0.0001 and g < 3000:
		a._update_combo(minf(1.0 / 120.0, time - a._exec_time)); g += 1
func finish():
	var g := 0
	while a._exec_outro < 0.0 and g < 6000: a._update_combo(1.0 / 120.0); g += 1
func play():
	a._execute_combo()
	finish()
# every timed hit nailed: presses, holds and taps
func play_perfect():
	a._execute_combo()
	while a._exec_lead_in > 0.0 or a._exec_reveal_left > 0.0: a._update_combo(1.0 / 120.0)
	var g := 0
	while a._exec_outro < 0.0 and g < 60:
		g += 1
		while a._exec_reveal_left > 0.0: a._update_combo(1.0 / 120.0)
		var slot = a._exec_slot
		var e = a._plan[slot]; var dur = float(e["duration"]); var w = float(e["window"]) * dur
		for h in e["hits"].size():
			if a._untimed(e, h): continue
			var ht = dur * float(e["times"][h])
			if a._special_hit(e, h) and int(e["timing"]) == 1:
				to(dur * float(e["hold_start"]) - w * 0.4); a._judge_timing()
				to(ht - w * 0.4); a._judge_release()
			elif a._special_hit(e, h) and int(e["timing"]) == 2:
				var ts = dur * float(e["tap_start"]); var k = tap_count if tap_count > 0 else int(e["taps"])
				for j in k:
					to(ts + (ht - ts) * (j + 0.5) / (k + 0.5)); a._judge_timing()
			else:
				to(ht - w * 0.4); a._judge_timing()
		var guard := 0
		while a._exec_slot == slot and a._exec_outro < 0.0 and guard < 3000:
			a._update_combo(1.0 / 120.0); guard += 1
	finish()

# Tortoise Special: no tap ceiling, damage keeps growing; 30 taps is a Perfect.
func tortoise(mk, g, taps):
	mk.tokens = {"Crowd Cheer": 1}; mk.combo_limit = 100
	open_bar(mk, g); a.ap = 200.0
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	tap_count = taps
	g.hp = g.max_hp
	var hp0 = g.hp
	play_perfect()
	tap_count = 0
	return hp0 - g.hp
func _process(d):
	t += d
	if t < 0.3 or done: return false
	done = true
	a.set_process(false)
	ArtsBook.reset()
	ArtsBook.discover("monk", "Tortoise Special")
	var mk = m("monk")
	var g = a.enemies[0]
	g.max_hp = 99999; g.hp = 99999
	open_bar(mk, g); mk.tokens = {"Crowd Cheer": 1}; mk.combo_limit = 100
	open_bar(mk, g)
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	var e = a._plan[0]
	check(e["name"] == "Tortoise Special" and int(e["timing"]) == 2 and e["move"].get("surge_uncapped", false), "Tortoise Special: an uncapped tap")
	var dmg = {}
	for n in [10, 30, 60, 90]:
		dmg[n] = tortoise(mk, g, n)
		print("  %d taps: %d damage" % [n, dmg[n]])
	check(dmg[30] > dmg[10] and dmg[60] > dmg[30] and dmg[90] > dmg[60], "more taps, more damage, no ceiling")
	print("FAILS: %d" % fails)
	return true
