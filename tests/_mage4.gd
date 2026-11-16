extends SceneTree
# Mage rework, Parts 7-8: Focus (50 AP bar + 10 per charge, built standing
# still, lost walking, spent attacking; party AP +50% while she's still),
# 5 m reach, Enchant, and spell codes (WASD while casting).
var a
var t := 0.0
var step := 0
var fails := 0
var mg
var kn
var e1
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
	return -1
func skill(n):
	# "Enchant: Fire" -> Enchant with its element picked.
	var parts = n.split(": ")
	for s in Moves.skills("mage"):
		if s["name"] == parts[0]:
			var out = s.duplicate()
			if parts.size() > 1: out["element"] = parts[1].to_lower()
			return out
func start_combo(names: Array):
	a._set_controlled(mg); a.active = mg; a._command_phase = false
	a.current_max_ap = 300; a.ap = 300
	a._open_combo_bar(e1)
	for n in names: a._add_to_combo(idx(n))
	a._execute_combo()
	a._exec_lead_in = 0.0
func stop_combo():
	a._menu_mode = BattleMenu.Mode.HIDDEN
	a.active = null
func _process(d):
	t += d
	if step != 0: return false
	if t < 0.8: return false
	step = 1
	for c in a.combatants: c.hold = true
	mg = a.party.filter(func(p): return p.class_id == "mage")[0]
	kn = a.party.filter(func(p): return p.class_id == "knight")[0]
	e1 = a.enemies[0]
	for e in a.enemies:
		if e != e1: e.global_position = Vector3(-14, e.global_position.y, 8)
	e1.global_position = Vector3(0, e1.global_position.y, 0)
	mg.global_position = Vector3(0, mg.global_position.y, 4.5)
	kn.global_position = Vector3(1.5, kn.global_position.y, 1.5)

	# -- Reach --
	check(mg.attack_reach == 5.0, "Mage reach 5 m (%.1f)" % mg.attack_reach)
	var reaches = Moves.attacks("mage").map(func(m): return float(m.get("reach", 5.0)))
	check(reaches.all(func(r): return r == 5.0 or r < 0.0), "every element reaches 5 m (-1: hers): %s" % [reaches])

	# -- Focus --
	mg.set_focus(0)
	mg.focus_clock = 0.0
	check(mg.combo_limit == 50.0, "base bar 50 (%d)" % mg.combo_limit)
	a._tick_focus(0.0)  # settles the position
	for i in 4: a._tick_focus(0.5)
	check(mg.focus == 1 and mg.combo_limit == 60.0, "2 s still: 1 Focus, bar 60 (%d, %d)" % [mg.focus, mg.combo_limit])
	check(a._focus_ap_mult() == 1.5, "standing still: party AP refills x1.5 (%.2f)" % a._focus_ap_mult())
	for i in 30: a._tick_focus(0.5)
	check(mg.focus == 5 and mg.combo_limit == 100.0, "capped at 5 Focus, bar 100 (%d, %d)" % [mg.focus, mg.combo_limit])
	check(mg.status_text().begins_with("FOCUS 5"), "HUD tag: %s" % mg.status_text())
	for i in 20:
		mg.global_position += Vector3(0.1, 0, 0)
		a._tick_focus(0.05)
	check(mg.focus == 4, "walking 2 m: one Focus lost (%d)" % mg.focus)
	check(a._focus_ap_mult() == 1.0, "walking: no AP bonus")
	mg.global_position += Vector3(-3.0, 0, 0)
	a._tick_focus(0.05)
	check(mg.focus == 4, "a 3 m jump (teleport, push) costs nothing (%d)" % mg.focus)
	mg.global_position = Vector3(0, mg.global_position.y, 4.5)
	a._tick_focus(0.0)

	# -- Spell codes --
	start_combo(["Fire"])
	check(mg.focus == 0 and mg.combo_limit == 50.0, "attacking spends Focus: bar back to 50")
	check(a._exec_limit == 90.0, "the bar played keeps its Focus size (%d)" % a._exec_limit)
	var e = a._plan[0]
	check(int(e["timing"]) == Moves.TimingType.CODE and e["code"] == ["up"], "Fire's code: W (%s)" % [e["code"]])
	a._exec_time = float(e["duration"]) * 0.2
	a._judge_code("down")
	check(a._exec_code == 0 and a._exec_timings[0] == 0, "a wrong arrow: the code starts over, no miss")
	a._judge_timing()
	check(a._menu_mode == BattleMenu.Mode.EXECUTING and a._exec_timings[0] == 0, "the confirm key does nothing (never a miss)")
	var t0 = a._exec_time
	a._update_combo(0.02)
	check(is_equal_approx(a._exec_time - t0, 0.02), "a code still to type: the playhead runs normally")
	a._judge_code("up")
	check(a._exec_timings[0] == 1, "code done before the hit: Perfect")
	t0 = a._exec_time
	a._update_combo(0.02)
	check(is_equal_approx(a._exec_time - t0, 0.02 * a.exec_fast_forward), "nothing left to press: the rest plays %dx faster" % int(a.exec_fast_forward))
	stop_combo()

	# Unfinished: a normal hit, max AP untouched.
	start_combo(["Ice"])
	var max_before = a.current_max_ap
	var ap_before = a.ap
	for i in 200:
		if a._menu_mode != BattleMenu.Mode.EXECUTING or a._exec_hits_done > 0: break
		a._update_combo(0.02)
	check(a._exec_hits_done > 0 or a._menu_mode != BattleMenu.Mode.EXECUTING, "Ice landed without its code")
	check(a.current_max_ap >= max_before and a.ap == ap_before, "no code: no penalty (max AP %d -> %d)" % [max_before, a.current_max_ap])
	stop_combo()

	# Arts: the code follows the bar's order.
	a._open_combo_bar(e1)
	a._add_to_combo(idx("Ice")); a._add_to_combo(idx("Fire"))
	var groups = a._parse_combo(true)
	check(groups.size() == 1 and groups[0]["move"]["name"] == "Steam Burst" and groups[0]["move"]["code"] == ["down", "up"], "Ice + Fire = Steam Burst, code S W (%s)" % [groups[0]["move"].get("code")])
	a._open_combo_bar(e1)
	a._add_to_combo(idx("Fire")); a._add_to_combo(idx("Ice"))
	groups = a._parse_combo(true)
	check(groups[0]["move"]["code"] == ["up", "down"], "Fire + Ice: code W S (%s)" % [groups[0]["move"].get("code")])
	var thunder = Moves.arts("mage").filter(func(m): return m["name"] == "Thunder")[0]
	a._set_controlled(mg)
	var slot = a._plan_slot(thunder)
	check(slot["untimed"] == [true, true, false] and slot["code"] == ["left", "left", "left"], "Thunder: one code (A A A) due before the last hit")
	a.battle_menu.combo.clear()
	stop_combo()

	# Energy: code, then free taps.
	start_combo(["Energy Blast"])
	e = a._plan[0]
	a._exec_time = float(e["duration"]) * 0.2
	a._judge_timing()
	check(a._exec_taps == 0, "Energy: taps before the code don't count")
	a._judge_code("right")
	check(a._exec_timings[0] == 1, "Energy: code D is the Perfect")
	for i in 14: a._judge_timing()
	check(a._exec_taps == 10, "then free taps, capped at 10 (%d)" % a._exec_taps)
	check(is_equal_approx(a._settle_special_timing(e, 0), 1.0), "each tap +10%")
	stop_combo()

	# -- Enchant --
	a._set_controlled(mg)
	a._use_skill(skill("Enchant: Fire"), null, mg.global_position)
	check(kn.statuses.has("enchant_fire") and not mg.statuses.has("enchant_fire"), "Enchant: Fire on the Knight, not on her")
	e1.burn_turns = 0
	var slash = Moves.attacks("knight")[0]
	a._combo_target = e1; a._exec_attacker = kn
	a._land_hit(kn, slash.duplicate(true), 1.0, true, true)
	check(e1.burn_turns == 1, "the Knight's hit burns 1 turn (%d)" % e1.burn_turns)
	a._use_skill(skill("Enchant: Lightning"), null, mg.global_position)
	check(kn.statuses.has("enchant_lightning") and not kn.statuses.has("enchant_fire"), "one Enchant at a time")
	check(is_equal_approx(float(a._enchanted(kn, slash)["stagger_mult"]), 1.5), "Lightning: 1.5x Stagger fill")
	a._use_skill(skill("Enchant: Energy"), null, mg.global_position)
	check(float(a._enchanted(kn, slash)["knockback"]) == 1.0, "Energy: a 1 m push")
	a._use_skill(skill("Enchant: Ice"), null, mg.global_position)
	check(a._enchanted(kn, slash).get("chill", false), "Ice: chills")
	check(a._enchanted(mg, Moves.attacks("mage")[2]) == Moves.attacks("mage")[2], "her own spells unchanged")
	check(Moves.skills("mage").filter(func(s): return s["name"] == "Concentrate").is_empty(), "Concentrate is gone")
	# The Mage goes down: her Enchant still runs out, on the holder's turns.
	a._use_skill(skill("Enchant: Fire"), null, mg.global_position)
	var turns_left = int(kn.statuses["enchant_fire"]["turns"])
	kn.tick_statuses(kn)
	check(kn.statuses.has("enchant_fire") and int(kn.statuses["enchant_fire"]["turns"]) == turns_left, "Mage up: the Knight's own turn doesn't count it down")
	mg.is_down = true
	for i in turns_left: kn.tick_statuses(kn)
	check(not kn.statuses.has("enchant_fire"), "Mage down: it wears off after %d of the Knight's turns" % turns_left)
	mg.is_down = false

	# -- Enchant's element menu --
	for el in a.ENCHANTS: kn.statuses.erase("enchant_" + el)
	a._set_controlled(mg); a.active = mg; a._command_phase = false; a.ap = 100.0
	a._open_skills()
	var idx_e = a._skills.map(func(x): return x["name"]).find("Enchant")
	check(idx_e >= 0 and a._skills.filter(func(x): return String(x["name"]).begins_with("Enchant")).size() == 1, "one Enchant in her Abilities")
	a._choose_skill(idx_e)
	check(a.battle_menu.element_pick, "choosing it opens the element menu")
	var ev = InputEventAction.new(); ev.action = "move_left"; ev.pressed = true
	a._menu_input(ev)
	check(kn.statuses.has("enchant_lightning") and not a.battle_menu.element_pick, "left = Lightning: cast, menu closed")
	a._open_skills()
	a._choose_skill(idx_e)
	var back = InputEventAction.new(); back.action = "cancel"; back.pressed = true
	a._menu_input(back)
	check(not a.battle_menu.element_pick and a._menu_mode == BattleMenu.Mode.SKILLS, "back closes it, the Abilities list stays")

	# -- AI Mage stands still in reach --
	for c in a.enemies: c.hold = true
	mg.global_position = Vector3(0, mg.global_position.y, 4.0)
	var p0 = mg.global_position
	for i in 20: a._ally_step(mg, 0.05)
	check(mg.global_position.distance_to(p0) < 0.05, "AI Mage in reach: stays put (moved %.2f m)" % mg.global_position.distance_to(p0))

	print("FAILS: %d" % fails)
	quit()
	return true
