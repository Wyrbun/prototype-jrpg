extends SceneTree
# Party AI: an AI ally's Windup grace waits while it's escaping a danger
# area; AI hits deal ai_damage_mult of a normal hit.
var a
var t := 0.0
var step := 0
var fails := 0
var g
var cl
var spot
var g_rot
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.windup_override = 1
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func flat(v):
	v.y = 0
	return v
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]; cl = a.party[1]
			check(is_equal_approx(a.ai_damage_mult, 0.8), "AI hits deal 80%")
			for c in a.combatants: c.hold = true
			g.forced_skill = skill(g, "Right Golem Smash")
			g.timeline_pos = a.cast_zone_start
			a._begin_cast(g)
			a._reveal_skill(g)
			g.set_meta("revealed_for", 1.0)  # past the allies' reaction time
			# Find a spot inside the Smash, far from the Golem (out of reach).
			for i in 600:
				var p = g.global_position + Vector3(randf_range(-16, 16), 0, randf_range(-16, 16))
				p.y = cl.global_position.y
				cl.global_position = p
				a._keep_in_arena(cl)
				p = cl.global_position
				if a._in_danger(p, a._ally_dangers(cl)) and not a._windup_reaches(cl, g):
					# Deep inside, well away from the edges (random spots near
					# the area's edge or the arena's made this flaky).
					var ideal = g.global_position + g.flat_forward().cross(Vector3.UP) * 8.0
					if spot == null or flat(p - ideal).length() < flat(spot - ideal).length():
						spot = p
			check(spot != null, "found a spot in the Smash, out of reach")
			cl.global_position = spot  # not the last random try (it may be in reach)
			g_rot = g.rotation  # a held Golem still turns slowly: keep its Smash where it is
			cl.set_meta("windup_target", g); cl.set_meta("windup_grace", 0.0)
			cl.timeline_pos = a.TIMELINE_LENGTH
			cl.hold = false
			step = 1; t = 0
		1:
			cl.global_position = spot  # kept inside (it would be escaping)
			g.rotation = g_rot
			if t > 4.0:
				check(cl.has_meta("windup_target") and float(cl.get_meta("windup_grace", 0.0)) == 0.0, "4 s inside the danger: the grace hasn't started (%.2f)" % float(cl.get_meta("windup_grace", 0.0)))
				check(cl.has_meta("windup_dodging"), "  DODGING shown")
				a._finish_enemy_skill(g, false)
				step = 2; t = 0
		2:
			cl.global_position = spot
			if not cl.has_meta("windup_target") or t > 8.0:
				check(not cl.has_meta("windup_target"), "danger gone: the grace runs out as usual (%.1f s)" % t)
				print("FAILS: %d" % fails)
				return true
	return false
