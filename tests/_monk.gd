extends SceneTree
var a
var t := 0.0
var done := false
var fails := 0
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
				var ts = dur * float(e["tap_start"]); var k = int(e["taps"])
				for j in k:
					to(ts + (ht - ts) * (j + 0.5) / (k + 0.5)); a._judge_timing()
			else:
				to(ht - w * 0.4); a._judge_timing()
		var guard := 0
		while a._exec_slot == slot and a._exec_outro < 0.0 and guard < 3000:
			a._update_combo(1.0 / 120.0); guard += 1
	finish()
func perfect_hits_ok():
	return true
func _process(d):
	t += d
	if t < 0.3 or done: return false
	done = true
	a.set_process(false)
	ArtsBook.reset()
	var mk = m("monk"); var kn = m("knight")
	var g = a.enemies[0]
	g.max_hp = 99999; g.hp = 99999
	check(mk.max_hp == 160 and mk.climbs() and mk.combo_limit == 30, "Monk: 160 HP, bar 30")
	open_bar(mk, g)
	check(a._moves.map(func(x): return x["name"]) == ["Punch", "Kick", "Heavy Punch", "Heavy Kick", "Headbutt"], "Monk's basics")
	check(a._plan.is_empty() and a.battle_menu.arts_hidden == 6, "6 Arts, all hidden")
	add("Punch")
	check(a._plan[0]["untimed"] == [true, true, true], "Punch: no timing, every hit lands by itself")
	# Knee Smash, sloppy: the step but no token; paid from party AP
	open_bar(mk, g); a.ap = 100.0
	add("Kick"); add("Heavy Kick")
	play()
	check(is_equal_approx(a.ap, 75.0), "party AP pays: 100 -> 75 (%d)" % a.ap)
	check(mk.combo_limit == 50 and not mk.tokens.has("Rush"), "sloppy Knee Smash: bar 50, no Rush (%s)" % [mk.tokens])
	# Knee Smash again, all Perfect: Rush
	open_bar(mk, g); add("Kick"); add("Heavy Kick")
	check(names() == ["Knee Smash(25)"], "Knee Smash known now")
	play_perfect()
	check(mk.combo_limit == 80 and mk.tokens.get("Rush", 0) == 1, "Perfect Knee Smash: climbs again (50 -> 80) and gives Rush (%s)" % [mk.tokens])
	mk.combo_limit = 50
	# Triple Rush, Perfect: bar 80, Crusher; Rush and the inner Triples used up
	open_bar(mk, g)
	for n in ["Punch", "Punch", "Kick", "Heavy Kick"]: add(n)
	check(a.battle_menu.combo_cost() == 35, "Triple Rush is P P K HK, 35 AP")
	play_perfect()
	check(mk.combo_limit == 80 and mk.tokens == {"Crusher": 1}, "Perfect Triple Rush: bar 80, Crusher only (%s)" % [mk.tokens])
	# a miss in his own combo: the climb holds, only the newest token goes
	mk.tokens = {"Crusher": 1, "Mountain": 1}
	open_bar(mk, g); add("Headbutt"); a._execute_combo(); a._exec_lead_in = 0.0
	to(float(a._plan[0]["duration"]) * 0.2); a._judge_timing(); finish()
	check(mk.combo_limit == 80 and mk.tokens == {"Crusher": 1}, "a miss: bar stays 80, newest token (Mountain) lost (%s, bar %d)" % [mk.tokens, mk.combo_limit])
	# (an avoidable hit or early Parry still drops a step: set that up for what follows)
	mk.drop_step(); mk.tokens = {"Crusher": 1}
	check(mk.combo_limit == 50 and mk.lost_step == 80, "a step lost the other ways: bar 80 -> 50")
	# Deep Breath gives the step back
	reset(); a._set_controlled(mk); a.active = mk; a.ap = 100
	a._use_skill(Moves.skills("monk")[2], null, Vector3.ZERO)
	check(mk.combo_limit == 80 and mk.lost_step == 0.0, "Deep Breath: bar back to 80")
	# Crowd Cheer goes last
	mk.tokens = {"Crowd Cheer": 1, "Rush": 1}; mk.combo_limit = 100; mk.drop_step()
	check(mk.combo_limit == 80 and mk.tokens == {"Crowd Cheer": 1}, "a drop takes Rush before Crowd Cheer (%s)" % [mk.tokens])
	# Mountain Crusher Perfect at 80: bar 100, Crowd Cheer
	mk.tokens = {}; mk.combo_limit = 80
	open_bar(mk, g)
	for n in ["Heavy Punch", "Kick", "Kick", "Kick", "Heavy Kick"]: add(n)
	check(a.battle_menu.combo_cost() == 55, "Mountain Crusher is HP K K K HK, 55 AP")
	play_perfect()
	check(mk.combo_limit == 100 and mk.tokens.has("Crowd Cheer") and mk.tokens.get("Triple", 0) == 1, "Perfect Mountain Crusher: bar 100, Crowd Cheer, Triple (%s)" % [mk.tokens])
	# any climb Art climbs one step; sloppy at the top: no Crowd Cheer
	mk.tokens = {}; mk.combo_limit = 80
	open_bar(mk, g); add("Kick"); add("Heavy Kick"); play()
	check(mk.combo_limit == 100 and not mk.tokens.has("Crowd Cheer"), "a sloppy Knee Smash at 80 climbs to 100, but no Crowd Cheer (%s)" % [mk.tokens])
	open_bar(mk, g); add("Kick"); add("Heavy Kick"); play_perfect()
	check(mk.combo_limit == 100 and mk.tokens.has("Crowd Cheer"), "a Perfect climb Art at the top earns it (%s)" % [mk.tokens])
	# the preview names what it uses and what a Perfect gives
	mk.tokens = {"Crusher": 1, "Crowd Cheer": 1}; mk.combo_limit = 50
	open_bar(mk, g); for n in ["Punch", "Punch", "Kick", "Heavy Kick"]: add(n)
	var pv = a._monk_preview()
	check("Step: bar 80" in pv[0] and "+Crusher" in pv[1] and pv[2], "preview: '%s' / '%s'" % [pv[0], pv[1]])
	mk.tokens = {"Crowd Cheer": 1}; mk.combo_limit = 100
	# Tortoise only forms with Crowd Cheer
	var saved = mk.tokens.duplicate(); mk.tokens = {}
	open_bar(mk, g)
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	check(names() == ["Heavy Punch(20)", "Heavy Kick(20)", "Headbutt(30)"], "no Crowd Cheer: no Tortoise Special (%s)" % [names()])
	mk.tokens = saved
	# cash-out at 100: 2.5x, bar back to 30; fresh bar after it is paid too
	open_bar(mk, g); a.ap = 200.0
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	add("Kick"); add("Heavy Kick")
	var hp0 = g.hp
	play_perfect()
	var top = hp0 - g.hp
	check(ArtsBook.known("monk", "Tortoise Special"), "Tortoise Special revealed")
	check(is_equal_approx(a.ap, 200.0 - 95.0), "the fresh bar after the Headbutt is paid too (%d AP left)" % a.ap)
	check(mk.combo_limit == 50 and not mk.tokens.has("Crowd Cheer"), "cash-out: the climb is spent (back to 30), then Knee Smash on the fresh bar lifts it to 50 (%d)" % mk.combo_limit)
	# cash-out at 80: 1.5x
	mk.tokens = {"Crowd Cheer": 1}; mk.combo_limit = 80
	open_bar(mk, g); for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	var p80 = a._token_plan(mk, a._plan[0]["move"])
	mk.combo_limit = 100
	var p100 = a._token_plan(mk, a._plan[0]["move"])
	check(is_equal_approx(p80["cashout"], 1.5) and is_equal_approx(p100["cashout"], 2.5), "cash-out: 1.5x at 80, 2.5x at 100")
	print("  Tortoise at 100 + Knee Smash dealt %d" % top)
	# the fresh bar after a Headbutt waits for a READY lead-in
	mk.tokens = {"Crowd Cheer": 1}; mk.combo_limit = 100
	open_bar(mk, g); for n in ["Heavy Punch", "Heavy Kick", "Headbutt", "Kick", "Heavy Kick"]: add(n)
	a._execute_combo(); a._exec_lead_in = 0.0
	var gg := 0
	while a._exec_resume_slot < 0 and a._exec_outro < 0.0 and gg < 3000:
		a._update_combo(1.0 / 120.0); gg += 1
	check(a._exec_resume_slot == 1 and a._exec_lead_in > 0.9 and a._exec_slot == 0, "after Tortoise: a READY lead-in before the fresh bar (%.2f s)" % a._exec_lead_in)
	for k in 60: a._update_combo(1.0 / 120.0)
	check(a._exec_slot == 0, "the fresh bar hasn't started half a second in")
	for k in 70: a._update_combo(1.0 / 120.0)
	check(a._exec_slot == 1 and a._exec_resume_slot == -1, "then it starts")
	finish()
	# party AP limits the fresh bar
	mk.combo_limit = 100; mk.tokens = {"Crowd Cheer": 1}
	open_bar(mk, g); a.ap = 80.0
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt"]: add(n)
	add("Kick"); add("Heavy Kick")
	check(a.battle_menu.combo_cost() == 75, "with 80 party AP: Tortoise (70) + Kick (5) fit, the Heavy Kick doesn't (%d)" % a.battle_menu.combo_cost())
	# Suplex counter: +1 Mountain
	mk.tokens = {}; mk.counter_name = "Suplex"
	var lines: PackedStringArray = []
	a._riposte(mk, g, lines)
	check(mk.tokens.get("Mountain", 0) == 1, "a Suplex counter gives Mountain (%s)" % [lines])
	# Provoke
	reset(); a._set_controlled(mk); a.active = mk; a.ap = 100; mk.global_position = Vector3(0, 0, 3)
	a._use_skill(Moves.skills("monk")[0], g, Vector3.ZERO)
	check(g.statuses.has("taunt") and mk.statuses.has("provoking") and a._enemy_target(g) == mk, "Provoke: the enemy goes after the Monk")
	# a late full turn at 100, for scale
	mk.combo_limit = 100; mk.tokens = {"Crowd Cheer": 1}
	open_bar(mk, g); a.ap = 300.0
	for n in ["Heavy Punch", "Heavy Kick", "Headbutt", "Heavy Punch", "Kick", "Kick", "Kick", "Heavy Kick"]: add(n)
	hp0 = g.hp; play_perfect()
	print("  late turn (Tortoise at 100 + fresh-bar Mountain Crusher) dealt %d" % (hp0 - g.hp))
	for pair in [["Knee Smash", ["Kick", "Heavy Kick"]], ["Triple Rush", ["Punch", "Punch", "Kick", "Heavy Kick"]], ["Mountain Crusher", ["Heavy Punch", "Kick", "Kick", "Kick", "Heavy Kick"]]]:
		mk.tokens = {}; mk.combo_limit = 80; open_bar(mk, g)
		for n in pair[1]: add(n)
		var cost = a.battle_menu.combo_cost()
		hp0 = g.hp; play_perfect()
		print("  %s: %d AP, %d damage, %.2f per AP" % [pair[0], cost, hp0 - g.hp, float(hp0 - g.hp) / cost])
	ArtsBook.discover("knight", "Crusader's Edge"); open_bar(kn, g)
	for n in ["Slash", "Slash", "Thrust", "Guard Strike"]: add(n)
	hp0 = g.hp; play_perfect()
	print("  Knight Crusader's Edge dealt %d" % (hp0 - g.hp))
	# Arts picked from the list still build bigger Arts
	ArtsBook.reset(); for n in ["Palm Strike", "Knee Smash"]: ArtsBook.discover("monk", n)
	mk.combo_limit = 100; open_bar(mk, g)
	var row_of = func(nm):
		for r in a.battle_menu.arts.size():
			if a.battle_menu.arts[r]["name"] == nm: return r
	a._add_art(row_of.call("Palm Strike")); a._add_art(row_of.call("Palm Strike")); a._add_art(row_of.call("Knee Smash"))
	play()
	check(ArtsBook.known("monk", "Triple Rush"), "picked Arts reveal Triple Rush")
	# knocked out: the climb starts over
	mk.combo_limit = 80; mk.tokens = {"Crusher": 1}; mk.take_damage(9999, false)
	check(mk.is_down and mk.combo_limit == 30 and mk.tokens.is_empty(), "knocked out: bar 30, tokens gone")
	var ma = {}
	for x in Moves.arts("monk"): ma[x["name"]] = x
	check(ma["Palm Strike"]["hits"] == [1.0] and ma["Flash Kick"]["hits"] == [1.0] and ma["Knee Smash"]["hits"] == [2.5] and ma["Triple Rush"]["hits"] == [0.6, 0.6, 3.2] and ma["Mountain Crusher"]["hits"] == [0.9, 0.5, 0.5, 4.4], "Monk round 3 numbers")
	print("FAILS: %d" % fails); quit(); return false
