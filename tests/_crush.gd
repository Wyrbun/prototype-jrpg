extends SceneTree
# Crush keeps turning at final_turn_speed (80°/s) in its last second, not the
# Golem's slow 40°/s, and locks onto someone far unless Taunted. Other
# lines get line_final_turn_speed; Rock Stomp (a circle round the Golem)
# steps after a target at its edge.
var a
var t := 0.0
var step := 0
var fails := 0
var g
var k
var start_off := 0.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func off():
	var to = k.global_position - g.global_position
	to.y = 0
	return rad_to_deg(g.flat_forward().angle_to(to))
func _process(d):
	t += d
	if g != null:
		g.timeline_pos = a.cast_zone_start  # keep it mid-cast
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]; k = a.party[0]
			a.cast_slow_seconds = 1000.0  # the whole cast counts as its last second
			for c in a.combatants: c.hold = true
			g.hold = false
			g.global_position = Vector3(0, g.global_position.y, 0)
			g.forced_skill = skill(g, "Crush")
			a._begin_cast(g)
			g.cast_target = k
			check(is_equal_approx(g.loaded_def.final_turn_speed, 80.0), "Crush: final_turn_speed 80")
			# Far targeting: Knight close, Archer and Mage far.
			var ar = a.party[1]; var mg = a.party[2]
			k.global_position = g.global_position + Vector3(2.5, 0, 0)
			ar.global_position = g.global_position + Vector3(-9, 0, 0)
			mg.global_position = g.global_position + Vector3(0, 0, 9)
			var picks := {}
			for i in 30:
				var f = a._far_target(g)
				picks[f] = true
			check(not picks.has(k) and picks.has(ar) and picks.has(mg), "  locks onto a random far ally (Archer / Mage), never the close Knight")
			g.statuses["taunt"] = {"caster": k, "turns": 1}
			check(a._far_target(g) == null, "  Taunted: no far pick (the Taunt holds it)")
			g.statuses.erase("taunt")
			ar.global_position = g.global_position + Vector3(-3, 0, 0)
			mg.global_position = g.global_position + Vector3(0, 0, 3)
			check(a._far_target(g) == null, "  nobody far: the usual target")
			ar.global_position = g.global_position + Vector3(-30, 0, 30)
			mg.global_position = g.global_position + Vector3(30, 0, 30)
			for m in [ar, mg]: a._keep_in_arena(m)
			check(is_equal_approx(a._final_turn_speed(skill(g, "Heavy Attack")), 0.0), "Heavy Attack (a cone): no line turn speed")
			var tg = load("res://scenes/characters/training_golem.tscn").instantiate()
			var ts = a._final_turn_speed(tg.skills.filter(func(x): return x.skill_name == "Long Strike")[0])
			tg.free()
			check(is_equal_approx(ts, a.line_final_turn_speed), "Training Golem Long Strike (a line): %.0f°/s" % ts)
			g.forced_skill = skill(g, "Crush")
			a._begin_cast(g)
			g.cast_target = k  # it picked a far ally: test the turning on the Knight
			var side = g.flat_forward().cross(Vector3.UP).normalized()
			k.global_position = g.global_position + side * 8.0
			k.global_position.y = g.global_position.y
			start_off = off()
			step = 1; t = 0
		1:
			if t < 0.5: return false
			var turned = start_off - off()
			var expect = 80.0 * 0.5 * a.battle_speed
			check(abs(turned - expect) < 6.0, "  turned %.0f° in 0.5 s (80°/s at battle speed %.1f: %.0f°; 40°/s would be %.0f°)" % [turned, a.battle_speed, expect, expect / 2])
			a._finish_enemy_skill(g, false)
			g.forced_skill = skill(g, "Rock Stomp")
			a._begin_cast(g)
			g.cast_target = k
			k.global_position = g.global_position + Vector3(4.8, 0, 0)
			check(a._melee_tracking(g, k), "Rock Stomp: a target at its edge is chased")
			print("FAILS: %d" % fails)
			return true
	return false
