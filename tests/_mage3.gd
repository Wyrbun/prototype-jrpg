extends SceneTree
# Mage rework, step 3: the last six Arts (19 in all) and the AI Mage's setups.
var a
var t := 0.0
var fails := 0
var mg
var e1
var e2
var e3
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func art(n):
	for m in Moves.arts("mage"):
		if m["name"] == n: return m
func reset_enemies():
	for e in [e1, e2, e3]:
		e.hp = e.max_hp; e.burn_turns = 0; e.burn_stacks = 1; e.statuses.clear(); e.freeze_left = 0.0
		e.control_used = false; e.cancel_lock = 0; e.boss = false
		e.remove_meta("stasis_resist"); e.remove_meta("freeze_resist")
func hit(move, target):
	a._combo_target = target
	a._exec_attacker = mg
	var hits: Array = move["hits"]
	for i in hits.size():
		var m = move.duplicate(true)
		if m.has("last_hit") and i == hits.size() - 1: m.merge(m["last_hit"], true)
		a._land_hit(mg, m, float(hits[i]), i == 0, i == hits.size() - 1)
func _process(d):
	t += d
	if t < 0.8: return false
	for c in a.combatants: c.hold = true
	mg = a.party.filter(func(p): return p.class_id == "mage")[0]; e1 = a.enemies[0]; e2 = a.enemies[1]; e3 = a.enemies[2]
	a._set_controlled(mg)
	var arts = Moves.arts("mage")
	check(arts.size() == 19, "19 Arts: the most in the party (%d)" % arts.size())
	var seen := {}
	var dupes := 0
	for x in arts:
		var r: Array = x["recipe"].duplicate(); r.sort()
		var key = ",".join(r)
		if seen.has(key): dupes += 1
		seen[key] = true
	check(dupes == 0, "every recipe is a different mix")
	e1.global_position = Vector3(0, e1.global_position.y, 0)
	e2.global_position = Vector3(2, e2.global_position.y, 0)
	e3.global_position = Vector3(-12, e3.global_position.y, 6)
	mg.global_position = Vector3(0, mg.global_position.y, 3)
	# Plasma
	var pl = art("Plasma")
	check(pl.get("stun", false) and float(pl.get("burn", 0.0)) > 0.0 and float(pl.get("knockback", 0.0)) == 0.0, "Plasma: Burn + interrupt")
	# Static Frost
	reset_enemies()
	hit(art("Static Frost"), e1)
	check(e1.statuses.has("chilled") and not e1.statuses.has("frozen"), "Static Frost: chills a fresh target")
	hit(art("Static Frost"), e1)
	check(e1.statuses.has("frozen"), "  freezes one that was already Chilled")
	# Tri-Disaster
	reset_enemies()
	hit(art("Tri-Disaster"), e1)
	check(e2.burn_turns > 0 and e2.statuses.has("chilled") and e1.burn_turns > 0, "Tri-Disaster: Burn and Chill on everyone in the circle")
	check(e3.burn_turns == 0, "  not on the far one")
	# Thermal Shock
	check(int(art("Thermal Shock")["effect"]) == Moves.Effect.BREAK and float(art("Thermal Shock").get("knockback", 0.0)) == 0.0, "Thermal Shock: breaks Defense, no push")
	# Nova
	reset_enemies()
	e1.global_position = Vector3(0, e1.global_position.y, 4.5)
	e2.global_position = Vector3(10, e2.global_position.y, 0)
	a._combo_target = e1
	var v = a._hit_victims(mg, art("Nova")).map(func(x): return x[0])
	check(v.has(e1) and not v.has(e2), "Nova: everything near the Mage, not far away")
	check(art("Nova").get("stun", false) and float(art("Nova").get("knockback", 0.0)) == 0.0, "  interrupts, no push")
	# Stasis
	reset_enemies()
	e2.boss = true
	e2.timeline_pos = 60.0
	hit(art("Stasis"), e1)
	check(e1.freeze_left >= 2.9 and e3.freeze_left >= 2.9, "Stasis: every regular enemy's timeline stops 3 s")
	check(e2.freeze_left == 0.0 and is_equal_approx(60.0 - e2.timeline_pos, 8.0), "  a boss only loses 8 (%.1f)" % (60.0 - e2.timeline_pos))
	e2.timeline_pos = 60.0
	hit(art("Stasis"), e1)
	check(is_equal_approx(60.0 - e2.timeline_pos, 4.0), "  then 4 (%.1f)" % (60.0 - e2.timeline_pos))
	check(not art("Stasis").get("stun", false), "  no interrupt on everyone")
	# AI setups
	reset_enemies()
	a._exec_attacker = mg
	var flare_cold = a._ai_value(art("Flare"), e1, true)
	e1.burn_turns = 2; e1.burn_damage = 5; e1.burn_stacks = 3
	e2.burn_turns = 2; e2.burn_damage = 5; e2.burn_stacks = 3
	var flare_hot = a._ai_value(art("Flare"), e1, true)
	check(flare_hot > flare_cold * 2.0, "AI: Flare is worth much more on burning enemies (%.1f -> %.1f)" % [flare_cold, flare_hot])
	reset_enemies()
	var sh_cold = a._ai_value(art("Shatter"), e1, true)
	e1.add_status("frozen", 1, e1)
	var sh_frozen = a._ai_value(art("Shatter"), e1, true)
	check(sh_frozen > sh_cold * 3.0, "AI: Shatter on a Frozen enemy (%.1f -> %.1f)" % [sh_cold, sh_frozen])
	# Arts list pages (A/D)
	ArtsBook.reset()
	for x in arts: ArtsBook.discover("mage", x["name"])
	a.active = mg; a.current_max_ap = 300; a.ap = 300; a._command_phase = false
	a._open_combo_bar(e1)
	a.battle_menu.arts_per_page = 11
	a.battle_menu.arts_pages = 2
	a.battle_menu.arts_page = 0
	a._turn_arts_page(1)
	check(a.battle_menu.arts_page == 1, "D: next Arts page")
	a._turn_arts_page(1)
	check(a.battle_menu.arts_page == 0, "  wraps round")
	a.battle_menu.arts_focus = true
	a._turn_arts_page(1)
	check(a.battle_menu.arts_index == 11, "  focused: the pick jumps to that page (%d)" % a.battle_menu.arts_index)
	a.battle_menu.arts_focus = false
	print("FAILS: %d" % fails)
	return true
