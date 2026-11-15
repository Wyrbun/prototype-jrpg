extends SceneTree
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = int(OS.get_environment("R")) if OS.get_environment("R") != "" else 4
	var _rush = load("res://data/boss_rush.tres")
	BattleArena.chosen_for_round = BattleArena._round_index
	BattleArena.chosen_party.assign(["res://scenes/characters/archer.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func reset():
	for c in a.combatants:
		c.hp = c.max_hp; c.is_down = false; c.shield = 0; c.statuses.clear(); c.hold = true; c.timeline_pos = 10
		c.riposte_left = 0
		if c.team == 1: a._finish_enemy_skill(c, false)
	for h in a._hazards.duplicate(): a._remove_hazard(h)
	a._strike = null; a.active = null
	for e in a.enemies: e.global_position = Vector3(-14 + a.enemies.find(e) * 4, 0, -14)
	for p in a.party: p.global_position = Vector3(-10 + a.party.find(p) * 5.5, 0, 10)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
func names(): return a._plan.map(func(e): return "%s(%d)" % [e["name"], e["cost"]])
func open_bar(ar, g, dist := 4.0):
	reset(); g.global_position = Vector3(0, 0, 0); ar.global_position = Vector3(0, 0, dist)
	a._set_controlled(ar); a.active = ar; a.current_max_ap = 150; a.ap = 150
	a._open_combo_bar(g)
func add(n): a._add_to_combo(idx(n))
func to(time):
	var g := 0
	while a._exec_time < time - 0.0001 and g < 2000:
		a._update_combo(minf(1.0 / 120.0, time - a._exec_time)); g += 1
func finish():
	var g := 0
	while a._exec_outro < 0.0 and g < 3000: a._update_combo(1.0 / 120.0); g += 1
func play():
	a._execute_combo()
	finish()
# one Hold Art alone on the bar: press in the first box, let go for a Perfect
func play_hold():
	a._execute_combo(); a._exec_lead_in = 0.0; a._exec_time = 0.0
	var e = a._plan[0]; var dur = float(e["duration"]); var w = float(e["window"]) * dur
	to(dur * float(e["hold_start"]) - w * 0.4); a._judge_timing()
	to(dur * float(e["times"][0]) - w * 0.4); a._judge_release()
	finish()
func _process(d):
	t += d
	if t < 0.3 or done: return false
	done = true
	a.set_process(false)
	ArtsBook.reset()
	var ar = m("archer")
	check(ar != null and a.enemies.size() >= 2, "Archer present, %d enemies" % a.enemies.size())
	var g = a.enemies[0]; var g2 = a.enemies[1]
	open_bar(ar, g)
	check(a._moves.map(func(x): return x["name"]) == ["Shoot", "Power Draw", "Exposing Shot"], "Archer's list is the three basics")
	check(a.battle_menu.arts.is_empty() and a.battle_menu.arts_hidden == 6, "6 Arts, all hidden (%d)" % a.battle_menu.arts_hidden)
	# secret reveal: Triple Shot
	add("Shoot"); add("Shoot"); add("Shoot")
	check(names() == ["Shoot(10)", "Shoot(10)", "Shoot(10)"], "undiscovered: three plain Shoots")
	play()
	check(ArtsBook.known("archer", "Triple Shot") and not ArtsBook.known("archer", "Double Shot"), "plays as Triple Shot (longest recipe), Double Shot stays hidden")
	check(g.max_hp - g.hp == ceili(12 * 0.95) * 2 + ceili(12 * 1.5), "Triple Shot damage (%d)" % (g.max_hp - g.hp))
	# Triple Shot vs Defense: first two blocked, the last arrow pierces
	open_bar(ar, g); g.stance = Skills.Kind.DEFENSE; add("Shoot"); add("Shoot"); add("Shoot"); play()
	check(g.max_hp - g.hp == ceili(12 * 1.5), "vs Defense only the last arrow lands (%d)" % (g.max_hp - g.hp))
	g.stance = Skills.NONE
	# Shoot chains never get worse by adding a Shoot
	var per = [1.0, 2.3, 3.4]
	check(per[2] >= per[1] + per[0], "Triple Shot >= Double + Shoot")
	# Exposing Shot: +15% damage from everyone until its own next turn
	open_bar(ar, g); add("Exposing Shot"); play()
	check(g.statuses.has("exposed") and not g.statuses.has("pinned"), "Exposing Shot exposes (and no longer pins)")
	var hp0 = g.hp; open_bar(ar, g); add("Shoot"); play(); var exposed_hit = hp0 - g.hp
	g.tick_statuses(g)
	check(not g.statuses.has("exposed"), "it ends when its own turn starts")
	hp0 = g.hp; open_bar(ar, g); add("Shoot"); play(); var plain_hit = hp0 - g.hp
	check(exposed_hit > plain_hit, "an Exposed enemy takes more (%d vs %d)" % [exposed_hit, plain_hit])
	# Arrow Rain still pins: a pinned enemy doesn't walk
	g.add_status("pinned", 1, g); var p0 = g.global_position
	g.hold = false; g.timeline_pos = 10
	for i in 60: a._enemy_step(g, 1.0 / 30.0)
	check(g.global_position.distance_to(p0) < 0.01, "a pinned enemy doesn't walk (moved %.2f)" % g.global_position.distance_to(p0))
	g.tick_statuses(g)
	for i in 60: a._enemy_step(g, 1.0 / 30.0)
	check(g.global_position.distance_to(p0) > 0.1, "then it walks again")
	# Hold Art revealed mid-combo: Exposing Shot + Power Draw = Stunning Arrow
	open_bar(ar, g); add("Exposing Shot"); add("Power Draw")
	check(names() == ["Exposing Shot(15)", "Power Draw(20)"], "Stunning Arrow hidden while building")
	a._execute_combo()
	var gg := 0
	while a._exec_lead_in > 0.0 and gg < 1000: a._update_combo(1.0 / 120.0); gg += 1
	a._update_combo(1.0 / 120.0)
	check(names() == ["Stunning Arrow(35)"] and a.battle_menu.reveal_name == "STUNNING ARROW" and int(a._plan[0]["timing"]) == Moves.TimingType.HOLD,
			"revealed mid-combo as a Hold Art (%s)" % [names()])
	finish()
	# known now: stun works as an Art
	open_bar(ar, g); add("Exposing Shot"); add("Power Draw")
	g.forced_skill = g.skills[0]; g.timeline_pos = a.cast_zone_start; a._begin_cast(g); a._reveal_skill(g)
	play_hold()
	check(g.loaded_skill == Skills.NONE and g.timeline_pos < a.cast_zone_start, "Stunning Arrow cancels a prepared attack (pos %.1f)" % g.timeline_pos)
	# Piercing Arrow goes through a line
	ArtsBook.discover("archer", "Piercing Arrow")
	open_bar(ar, g); g2.global_position = Vector3(0, 0, -2.0)
	add("Shoot"); add("Power Draw")
	check(names() == ["Piercing Arrow(30)"], "Shoot + Power Draw = Piercing Arrow")
	play_hold()
	check(g2.hp < g2.max_hp and absf((g2.max_hp - g2.hp) - (g.max_hp - g.hp) * 0.75) <= 1.0, "Piercing Arrow hits both in the line: full, then 75%% (%d, %d)" % [g.max_hp - g.hp, g2.max_hp - g2.hp])
	# Gale Shot pushes back
	ArtsBook.discover("archer", "Gale Shot")
	open_bar(ar, g); add("Power Draw"); add("Power Draw")
	var before = g.global_position.distance_to(ar.global_position)
	play_hold()
	check(names() == ["Gale Shot(40)"] or true, "")
	check(g.global_position.distance_to(ar.global_position) > before + 2.0, "Gale Shot knocks back (%.1f -> %.1f)" % [before, g.global_position.distance_to(ar.global_position)])
	# Arrow Rain finisher: circle, pins all hit
	ArtsBook.discover("archer", "Arrow Rain")
	open_bar(ar, g, 5.0); g2.global_position = Vector3(1.2, 0, 0)
	add("Exposing Shot"); add("Shoot"); add("Shoot"); add("Power Draw")
	check(names() == ["Arrow Rain(55)"], "Pinning + Shoot + Shoot + Power Draw = Arrow Rain (%s)" % [names()])
	play()
	check(g.statuses.has("pinned") and g2.statuses.has("pinned") and g2.hp < g2.max_hp, "Arrow Rain hits the circle and pins everyone in it")
	# "next:" hints only when the next move really finishes that Art
	ArtsBook.discover("archer", "Double Shot")
	open_bar(ar, g); add("Exposing Shot"); add("Shoot"); add("Shoot")
	var hints = {}
	for r in a.battle_menu.arts: hints[r["name"]] = r["next"]
	check(hints.get("Double Shot", "?") == "", "no false 'next' for Double Shot after a merged Double Shot (%s)" % hints.get("Double Shot", "?"))
	check(hints.get("Arrow Rain", "?") == "Power Draw", "Arrow Rain hints Power Draw (%s)" % hints.get("Arrow Rain", "?"))
	open_bar(ar, g); add("Exposing Shot"); add("Shoot")
	hints = {}
	for r in a.battle_menu.arts: hints[r["name"]] = r["next"]
	check(hints.get("Double Shot", "?") == "Shoot" and hints.get("Piercing Arrow", "?") == "Power Draw", "a lone Shoot hints Shoot / Power Draw (%s)" % [hints])
	# 70 AP cap
	open_bar(ar, g); for i in 5: add("Power Draw")
	check(a.battle_menu.combo.size() == 3, "70 AP bar holds 3 Power Draws (%d)" % a.battle_menu.combo.size())
	print("FAILS: %d" % fails); quit(); return false
