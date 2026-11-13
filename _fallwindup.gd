extends SceneTree
# Windup: an ally walking to its committed target still steps out of a
# falling rock's circle (Ceiling Burst) instead of walking on through it.
var a
var t := 0.0
var step := 0
var cl
var hp0 := 0
var fails := 0
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0: if t > 0.6:
			var g = a.enemies[0]
			for c in a.combatants: c.hold = true
			cl = a.party[1]
			a._set_controlled(a.party[0])
			cl.global_position = g.global_position + Vector3(0, 0, 9.0)
			a._keep_in_arena(cl)
			cl.set_meta("windup_target", g)  # committed, out of reach: walking in
			for s in g.skills:
				if s.skill_name == "Ceiling Burst": g.forced_skill = s
			g.timeline_pos = a.cast_zone_start + 1.0
			a._begin_cast(g)
			g.timeline_pos = a.cast_zone_start + 20.0
			a._reveal_skill(g)
			hp0 = cl.hp
			step = 1; t = 0
		1:
			a._ally_step(cl, d)
			if not a._falls_pending(a.enemies[0]) or t > 12.0:
				check(cl.hp == hp0, "the committed Cleric dodged the falling rocks (HP %d -> %d)" % [hp0, cl.hp])
				print("FAILS: %d" % fails); quit()
	return false
