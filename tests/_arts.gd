extends SceneTree
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = int(OS.get_environment("R")) if OS.get_environment("R") != "" else 0
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(id):
	for x in a.party:
		if x.class_id == id: return x
func en(n):
	for e in a.enemies:
		if e.display_name == n: return e
func reset():
	for c in a.combatants:
		c.hp = c.max_hp; c.is_down = false; c.shield = 0; c.statuses.clear(); c.hold = true; c.timeline_pos = 10
		c.riposte_left = 0
		if c.team == 1: a._finish_enemy_skill(c, false)
	for h in a._hazards.duplicate(): a._remove_hazard(h)
	a._strike = null; a.active = null
	for e in a.enemies: e.global_position = Vector3(-9 + a.enemies.find(e) * 9, 0, -7)
	for p in a.party: p.global_position = Vector3(-10 + a.party.find(p) * 5.5, 0, 8)
func skill(e, n):
	for s in e.skills:
		if s.skill_name == n: return s
func cast(e, n, reveal := true):
	e.forced_skill = skill(e, n)
	e.timeline_pos = a.cast_zone_start
	a._begin_cast(e)
	if reveal: a._reveal_skill(e)
func strike(e, reaction := 0):
	a._enemy_unleash(e, false)
	var guard := 0
	while a._strike != null and guard < 10:
		a._strike.reaction = reaction
		a._strike.time_left = 0.0
		a._update_strike(0.0)
		guard += 1
func face(e, p): e.look_at(Vector3(p.global_position.x, 0, p.global_position.z), Vector3.UP); pass
func hp_loss(c, before): return before - c.hp
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
func names(): return a._plan.map(func(e): return "%s(%d)" % [e["name"], e["cost"]])
func open_bar(k, g):
	reset(); g.global_position = Vector3(0, 0, 0); k.global_position = Vector3(0, 0, 1.5)
	a._set_controlled(k); a.active = k; a.current_max_ap = 150; a.ap = 150
	a._open_combo_bar(g)
func add(n): a._add_to_combo(idx(n))
func play():
	a._execute_combo()
	var g := 0
	while a._exec_outro < 0.0 and g < 3000: a._update_combo(1.0 / 120.0); g += 1
func _process(d):
	t += d
	if t < 0.3 or done: return false
	done = true
	a.set_process(false)
	ArtsBook.reset()
	var k = m("knight"); var g = a.enemies[0]
	open_bar(k, g)
	check(a._moves.map(func(x): return x["name"]) == ["Slash", "Thrust", "Guard Strike"], "Knight's list is the three basics")
	check(a.battle_menu.arts.is_empty() and a.battle_menu.arts_hidden == 6, "no Arts known: none listed, 6 counted as hidden")
	add("Slash"); add("Slash")
	check(names() == ["Slash(10)", "Slash(10)"], "an undiscovered recipe doesn't merge while building (%s)" % [names()])
	g.hp = g.max_hp
	a._execute_combo()
	check(a.battle_menu.reveal_name == "" and names() == ["Slash(10)", "Slash(10)"], "still hidden during the lead-in")
	var gg := 0
	while a._exec_lead_in > 0.0 and gg < 1000: a._update_combo(1.0 / 120.0); gg += 1
	a._update_combo(1.0 / 120.0)
	check(names() == ["Double Slash(20)"] and a.battle_menu.reveal_name == "DOUBLE SLASH", "when the playhead reaches it, it reveals: blocks merge, NEW ART banner (%s)" % [names()])
	check(ArtsBook.known("knight", "Double Slash"), "and it's discovered")
	gg = 0
	while a._exec_outro < 0.0 and gg < 3000: a._update_combo(1.0 / 120.0); gg += 1
	check(g.max_hp - g.hp == ceili(15 * 1.25) * 2, "it plays as Double Slash (%d)" % (g.max_hp - g.hp))
	open_bar(k, g)
	check(a.battle_menu.arts.size() == 1 and a.battle_menu.arts[0]["recipe"] == "Slash + Slash" and a.battle_menu.arts_hidden == 5, "now listed with its recipe; 5 hidden")
	add("Slash"); add("Slash")
	check(names() == ["Double Slash(20)"], "known now: merges while building")
	# a hidden finisher that contains a known Art still reveals
	open_bar(k, g); add("Slash"); add("Slash"); add("Thrust"); add("Guard Strike")
	check(names() == ["Double Slash(20)", "Thrust(15)", "Guard Strike(15)"], "finisher hidden: shows Double Slash + parts (%s)" % [names()])
	play()
	check(ArtsBook.known("knight", "Crusader's Edge"), "playing it reveals Crusader's Edge")
	open_bar(k, g); add("Slash"); add("Slash"); add("Thrust"); add("Guard Strike")
	check(names() == ["Crusader's Edge(50)"], "then it merges (%s)" % [names()])
	var cancel := InputEventAction.new(); cancel.action = "cancel"; cancel.pressed = true
	a._menu_input(cancel)
	check(names() == ["Double Slash(20)", "Thrust(15)"], "removing the last move splits it back (%s)" % [names()])
	ArtsBook.discover("knight", "Smash"); ArtsBook.discover("knight", "Lunge")
	# Smash
	open_bar(k, g); add("Thrust"); add("Thrust"); add("Slash")
	check(names() == ["Smash(40)"] and int(a._plan[0]["move"]["kind"]) == Skills.Kind.SMASH, "Thrust + Thrust + Slash = Smash (%s)" % [names()])
	check(int(a._plan[0]["move"]["effect"]) == Moves.Effect.BREAK, "Smash breaks Defense")
	check(float(a._plan[0]["move"].get("knockback", 0.0)) == 4.0, "Smash knocks back 4 m")
	# Not defending: pushed back 4 m
	var gz: float = g.global_position.z
	play()
	check(g.global_position.distance_to(Vector3(0, 0, gz)) > 3.0, "unguarded: Smash knocks it back (moved %.1f m)" % g.global_position.distance_to(Vector3(0, 0, gz)))
	# Defending: guard broken, no push
	open_bar(k, g); g.stance = Skills.Kind.DEFENSE
	a._update_answer_tags()
	var row_tag = func(n):
		for r in a.battle_menu.arts:
			if r.get("name", "") == n: return r.get("tag", [])
		return []
	var mt = func(n): return a.battle_menu.move_tags[idx(n)]
	check(mt.call("Slash")[0] == "BLOCKED", "vs Defense, empty bar: Slash BLOCKED")
	add("Thrust"); add("Thrust"); add("Slash"); a._update_answer_tags()
	var sl = mt.call("Slash")
	check(sl.is_empty() or not String(sl[0]).contains("BLOCKED"), "Smash on the bar: Slash no longer BLOCKED (%s)" % [sl])
	var ds = row_tag.call("Double Slash")
	check(ds == null or ds.is_empty() or not String(ds[0]).contains("BLOCKED"), "...nor the Double Slash Art (%s)" % [ds])
	gz = g.global_position.z
	play()
	check(g.stance != Skills.Kind.DEFENSE, "Smash broke the guard")
	check(g.global_position.distance_to(Vector3(0, 0, gz)) < 0.5, "guarding: no knock-back (moved %.1f m)" % g.global_position.distance_to(Vector3(0, 0, gz)))
	g.stance = Skills.NONE
	# Crusader's Edge: the Knight follows the knock-back
	open_bar(k, g)
	var kz: float = k.global_position.z; var gz2: float = g.global_position.z
	g.control_used = false
	a._resolve_combo_hit(k, g, a._art_named("Crusader's Edge"), 1.0)
	var pushed: float = abs(g.global_position.z - gz2)
	check(pushed > 2.0 and is_equal_approx(abs(k.global_position.z - kz), pushed), "Crusader's Edge: Knight follows (enemy %.1f m, Knight %.1f m)" % [pushed, abs(k.global_position.z - kz)])
	check(k.global_position.distance_to(g.global_position) < 2.0, "...and stays in reach (%.1f m)" % k.global_position.distance_to(g.global_position))
	# Guard Strike: stops its timeline, once per enemy action
	g.control_used = false; g.freeze_left = 0.0
	open_bar(k, g); g.timeline_pos = 50.0; add("Guard Strike"); play()
	check(is_equal_approx(g.timeline_pos, 50.0) and g.freeze_left > 0.0, "Guard Strike halts it, no push back (pos %.1f, halt %.2f)" % [g.timeline_pos, g.freeze_left])
	a.active = k; g.hold = false; a._advance_timeline(0.3)
	check(is_equal_approx(g.timeline_pos, 50.0), "halted: it doesn't move (%.1f)" % g.timeline_pos)
	a._advance_timeline(0.2); a._advance_timeline(0.1)
	check(g.freeze_left == 0.0 and g.timeline_pos > 50.0, "the halt wears off (%.1f)" % g.timeline_pos)
	g.hold = true
	open_bar(k, g); add("Guard Strike"); play()
	check(g.freeze_left == 0.0, "no second halt before it acts (no lock)")
	g.control_used = false  # as if it had acted
	open_bar(k, g); add("Guard Strike"); play()
	check(g.freeze_left > 0.0, "after it acts, a shield blow halts it again")
	g.freeze_left = 0.0
	# limit: 60 bar
	open_bar(k, g); add("Thrust"); add("Thrust"); add("Thrust"); add("Thrust"); add("Thrust")
	check(a.battle_menu.combo.size() == 4, "the 60 AP bar still caps it (4 Thrusts)")
	# Arts list: Tab, pick a known Art, it goes on whole and stays itself
	ArtsBook.discover("knight", "Lunge")
	open_bar(k, g); add("Slash")
	var tab := InputEventAction.new(); tab.action = "swap_character"; tab.pressed = true
	a._menu_input(tab)
	check(a.battle_menu.arts_focus, "Tab opens the Arts list")
	var lunge_row = a.battle_menu.arts.map(func(r): return r["name"]).find("Lunge")
	var dn := InputEventAction.new(); dn.action = "move_back"; dn.pressed = true
	while a.battle_menu.arts_index != lunge_row: a._menu_input(dn)
	var ok := InputEventAction.new(); ok.action = "confirm"; ok.pressed = true
	a._menu_input(ok)
	check(names() == ["Slash(10)", "Lunge(25)"], "picked Lunge stays Lunge after a Slash (%s)" % [names()])
	a._menu_input(cancel); a._menu_input(cancel)
	check(not a.battle_menu.arts_focus and names() == ["Double Slash(20)"], "K leaves the list; removing a move unlocks it: Slash + Slash merge again (%s)" % [names()])
	# One Ability per turn, turn goes on
	open_bar(k, g); a._menu_mode = BattleMenu.Mode.COMMANDS; a._skill_used = false
	var brace
	for sk in Moves.skills("knight"):
		if sk["name"] == "Brace": brace = sk
	a._use_skill(brace, k, k.global_position)
	check(a.active == k and a._menu_mode == BattleMenu.Mode.COMMANDS, "after an Ability the turn goes on (menu back)")
	check(not a.battle_menu.command_enabled[1] and a.battle_menu.command_notes[1] == "used this turn", "Abilities greyed out after one use")
	check(a.battle_menu.used_ability.get("name", "") == "Brace" and k.has_meta("ability_badge"), "the menu shows a Brace chip; the timeline icon a badge")
	a._end_turn()
	check(a.battle_menu.used_ability.is_empty() and not k.has_meta("ability_badge"), "chip and badge go when the turn ends")
	print("FAILS: %d" % fails); quit(); return false
