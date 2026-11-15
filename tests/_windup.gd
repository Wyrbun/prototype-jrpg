extends SceneTree
# Command timing "windup": choose at the command point, get in reach by the end
# (plus grace), else the turn becomes a Wait.
var a
var t := 0.0
var step := 0
var waits0 := 0
var fails := 0
var kn
var cl
var g
var ap0 := 0.0
var start_pos := Vector3.ZERO
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena.windup_override = 1
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0: if t > 0.5:
			kn = a.party[0]; cl = a.party[1]; g = a.enemies[0]
			for c in a.combatants: c.hold = true; c.timeline_pos = 0
			kn.hold = false; kn.timeline_pos = a.party_command_at - 1.0
			kn.global_position = Vector3(0, 0, 6); g.global_position = Vector3(0, 0, -6)
			check(a.timeline_bar.party_command_at == a.party_command_at, "the timeline shows the command point")
			step = 1; t = 0
		1: if a.active == kn and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			check(a._command_phase and is_equal_approx(kn.timeline_pos, a.party_command_at), "the turn opens at the command point (%.1f)" % kn.timeline_pos)
			check(a.battle_menu.command_enabled[0], "Attack is open even with nobody in reach")
			ap0 = a.ap
			a._commit_windup(g)
			check(a.active == null and kn.has_meta("windup_target") and a.controlled == kn, "committed: time runs, you steer the Knight")
			step = 2; t = 0
		2: if t > 0.2:
			check(kn.timeline_pos > a.party_command_at, "the Knight's icon keeps going (%.1f)" % kn.timeline_pos)
			kn.timeline_pos = 99.5
			step = 3; t = 0
		3:
			if kn.has_meta("windup_target") and kn.timeline_pos >= 100.0 and t < 0.6:
				pass
			elif t >= 0.6 and t < 0.65:
				check(kn.has_meta("windup_target") and a.active == null, "out of reach at the end: a short grace, no turn yet")
			if not kn.has_meta("windup_target"):
				check(t > 0.9, "after the grace (%.2f s)" % t)
				check(kn.timeline_pos >= a.wait_head_start - 0.01 and kn.timeline_pos < 50.0 and a.stats.get("windup_misses", 0) == 1, "the turn became a Wait (%.1f)" % kn.timeline_pos)
				step = 4; t = 0
			elif t > 4.0:
				check(false, "grace never ran out"); step = 4
		4:
			# Second try: in reach at the end -> combo bar on the chosen enemy
			kn.timeline_pos = a.party_command_at - 0.5; step = 5; t = 0
		5: if a.active == kn and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			ap0 = a.ap
			a._commit_windup(g)
			kn.global_position = g.global_position + Vector3(0, 0, 1.3)
			kn.timeline_pos = 99.8
			step = 6; t = 0
		6: if a.active == kn and a._turn_intro_left <= 0.0:
			check(a._menu_mode == BattleMenu.Mode.COMBO and a._combo_target == g, "in reach at the end: the combo bar opens on the chosen enemy")
			check(is_equal_approx(a.ap, ap0), "no second turn-start AP (%d vs %d)" % [a.ap, ap0])
			var cancel := InputEventAction.new(); cancel.action = "cancel"; cancel.pressed = true
			a._menu_input(cancel)
			check(a._menu_mode == BattleMenu.Mode.COMBO and a.active == kn, "at ACT the committed attack can't be backed out of")
			a._end_turn()
			# Grace catch: commit, end out of reach, then walk in during the grace
			kn.timeline_pos = a.party_command_at - 0.5; step = 7; t = 0
		7: if a.active == kn and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			a._commit_windup(g)
			kn.global_position = g.global_position + Vector3(0, 0, 5.0)
			kn.timeline_pos = 99.9
			step = 8; t = 0
		8:
			if t > 0.4 and t < 0.5:
				kn.global_position = g.global_position + Vector3(0, 0, 1.3)  # made it during the grace
			if a.active == kn and a._turn_intro_left <= 0.0:
				check(a._menu_mode == BattleMenu.Mode.COMBO and t < 1.2, "reaching it during the grace still acts (%.2f s)" % t)
				a._end_turn()
				step = 9; t = 0
			elif t > 3.0:
				check(false, "grace catch never acted"); step = 9
		9:
			# An Ability at the command point, then still an Attack
			kn.timeline_pos = a.party_command_at - 0.5; step = 90; t = 0
		90: if a.active == kn and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			a.ap = 200; a._open_skills()
			var bi := -1
			for i in a._skills.size():
				if a._skills[i]["target"] == Moves.Target.SELF and a.battle_menu.move_usable[i]: bi = i; break
			check(bi >= 0, "a self Ability to use")
			if bi >= 0: a._choose_skill(bi)
			check(a.active == kn and a._menu_mode == BattleMenu.Mode.COMMANDS and a._command_phase and a.battle_menu.command_enabled[0], "after an Ability at COM you can still Attack")
			a._commit_windup(g)
			check(kn.has_meta("ability_badge"), "the Ability badge rides the icon after committing")
			kn.global_position = g.global_position + Vector3(0, 0, 1.3); kn.timeline_pos = 99.8
			step = 92; t = 0
		92: if a.active == kn and a._turn_intro_left <= 0.0:
			check(kn.has_meta("ability_badge") and a._menu_mode == BattleMenu.Mode.COMBO, "still shown at ACT")
			a._end_turn()
			check(not kn.has_meta("ability_badge"), "gone once the attack's turn ends")
			# Committed, in reach of nothing affordable (AP spent): a Wait, not stuck
			kn.timeline_pos = a.party_command_at - 0.5; step = 95; t = 0
		95: if a.active == kn and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			a._commit_windup(g)
			kn.global_position = g.global_position + Vector3(0, 0, 1.3); kn.timeline_pos = 99.8
			waits0 = int(a.stats.get("waits", 0))
			a.ap = 0.0
			step = 96; t = 0
		96: if int(a.stats.get("waits", 0)) > waits0 or t > 6.0:
			check(int(a.stats.get("waits", 0)) > waits0 and a._menu_mode != BattleMenu.Mode.COMBO, "no affordable move in reach at ACT: a Wait, not a stuck combo bar")
			a.ap = 200.0
			kn.hold = true; step = 93; t = 0
		93:
			# An AI ally walks to its chosen enemy
			cl.hold = false; cl.timeline_pos = a.party_command_at - 0.5; kn.hold = true
			step = 10; t = 0
		10: if a.active == cl and a._turn_intro_left <= 0.0 and a._menu_mode == BattleMenu.Mode.COMMANDS:
			a._commit_windup(g)
			check(a.controlled == kn, "after the Cleric commits, control goes back to the Knight you were steering (%s)" % a.controlled.display_name)
			cl.global_position = Vector3(6, 0, 6)
			start_pos = cl.global_position
			cl.timeline_pos = 75.0
			step = 11; t = 0
		11: if t > 1.0:
			check(cl.global_position.distance_to(g.global_position) < start_pos.distance_to(g.global_position) - 1.0, "an AI ally heads for its chosen enemy (%.1f -> %.1f m)" % [start_pos.distance_to(g.global_position), cl.global_position.distance_to(g.global_position)])
			BattleArena.windup_override = -1
			print("FAILS: %d" % fails); quit()
	return false
