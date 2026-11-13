extends SceneTree
# Counter-parry: a hit on a Counter stance mid-combo starts a counter-swing;
# the hit key in the window breaks the stance, otherwise you're countered.
# And at ACT you can back out of a Counter stance.
var a
var t := 0.0
var step := 0
var fails := 0
var k
var g
var hp0 := 0
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, n):
	for s in e.skills:
		if s.skill_name == n: return s
func setup():
	for c in a.combatants: c.hold = true
	a._command_phase = false
	g.forced_skill = skill(g, "Parry Stance"); g.timeline_pos = a.cast_zone_start + 5; a._begin_cast(g); a._reveal_skill(g)
	check(g.stance == Skills.Kind.COUNTER, "Armor in Counter stance")
	k.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
	a._set_controlled(k); a.active = k; a.ap = 200; a.current_max_ap = 200
	a._open_combo_bar(g)
	a._add_to_combo(0); a._add_to_combo(0)
	hp0 = k.hp
	a._execute_combo()
func press():
	var ev := InputEventAction.new(); ev.action = "confirm"; ev.pressed = true
	a._menu_input(ev)
func _process(d):
	t += d
	match step:
		0: if t > 0.6:
			k = a.party[0]; g = a.enemies[0]
			setup(); step = 1
		1:
			if a._counter_from != null:
				check(a.battle_menu.counter_progress >= 0.0, "counter prompt shows")
				step = 2
			elif a._menu_mode != BattleMenu.Mode.EXECUTING and t > 8: check(false, "no counter-swing started"); step = 9
		2:
			if a._counter_from != null and absf(a._counter_left) < 0.03:
				press()
				check(g.stance != Skills.Kind.COUNTER and k.hp == hp0, "parried: stance broken, no damage")
				check(a._counter_bonus > 0.0, "rest of the combo +25%")
				var et: float = a._exec_time
				check(a._counter_recover > 0.0, "a breather before the playhead moves on")
				press()
				check(a._menu_mode == BattleMenu.Mode.EXECUTING and is_equal_approx(a._exec_time, et), "presses during the breather are ignored, playhead still")
				step = 3
		3:
			if a._menu_mode != BattleMenu.Mode.EXECUTING:
				check(int(a.stats.get("counter_parries", 0)) == 1, "counted")
				setup(); step = 4; t = 0
		4:
			if a._counter_from != null:
				press()  # too early
				check(k.hp < hp0, "too early: countered (%d -> %d)" % [hp0, k.hp])
				step = 5
		5:
			if a._menu_mode != BattleMenu.Mode.EXECUTING:
				hp0 = k.hp
				setup(); step = 6
		6:
			if a._menu_mode != BattleMenu.Mode.EXECUTING or a._counter_from == null and step == 6 and t > 0 and a.stats.get("counter_parry_tries", 0) >= 3 and a._exec_outro >= 0.0:
				check(k.hp < hp0, "no press: countered when it swings")
				step = 7
		7:
			# ACT back-out
			for c in a.combatants: c.hold = true
			g.forced_skill = skill(g, "Parry Stance"); a._begin_cast(g); a._reveal_skill(g)
			a._set_controlled(k); a.active = k
			a._menu_mode = BattleMenu.Mode.HIDDEN
			a._open_combo_bar(g); a._windup_acting = true
			var ev := InputEventAction.new(); ev.action = "cancel"; ev.pressed = true
			a._menu_input(ev)
			check(a.active != k and int(a.stats.get("counter_waits", 0)) >= 1, "at ACT: backing out of a Counter stance makes it a Wait")
			step = 9
		9:
			print("FAILS: %d" % fails); quit()
	return false
