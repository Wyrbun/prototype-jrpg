extends SceneTree
# AI allies react only after the reveal (+ ally_react_seconds); a Knight
# holds its ground in a short melee attack; Golem Smash hides its side
# while grey; bosses lock onto whoever hurt them most (weighed by distance).
var a
var t := 0.0
var step := 0
var fails := 0
var g
var k
var cl
var ar
var spot
var reveal_t := -1.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.windup_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func flat(v):
	v.y = 0
	return v
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			g = a.enemies[0]; k = a.party[0]; cl = a.party[1]; ar = a.party[2]
			a._set_controlled(ar)
			for c in a.combatants: c.hold = true
			g.global_position = Vector3(0, g.global_position.y, 0)
			g.forced_skill = skill(g, "Heavy Attack")
			g.timeline_pos = a.cast_zone_start
			# Cleric right in front, the Knight beside her (both in the cone).
			var fwd = g.flat_forward()
			cl.global_position = g.global_position + fwd * 3.5
			k.global_position = g.global_position + fwd * 3.0 + fwd.cross(Vector3.UP) * 1.2
			ar.global_position = g.global_position - fwd * 12.0
			for m in [cl, k, ar]: m.global_position.y = g.global_position.y
			a._begin_cast(g)
			g.cast_target = cl
			g.hold = false
			spot = cl.global_position
			check(g.attack_range.contains(cl.global_position, cl.body_radius), "Cleric starts inside the grey Heavy Attack")
			step = 1; t = 0
		1:
			if not g.skill_revealed:
				if not g.attack_range.contains(cl.global_position, cl.body_radius):
					check(false, "Cleric left the grey area before the reveal")
					step = 2
				return false
			g.timeline_pos = a.reveal_at + 0.5  # hold the cast here
			var rf := float(g.get_meta("revealed_for", 0.0))
			if reveal_t < 0:
				reveal_t = 1
				check(g.attack_range.contains(cl.global_position, cl.body_radius), "Cleric stayed in it while it was grey")
				spot = cl.global_position
				return false
			if rf < a.ally_react_seconds - 0.05:
				if (cl.global_position - spot).length() > 0.05:
					check(false, "  she moved %.2f m only %.2f s after the reveal" % [(cl.global_position - spot).length(), rf])
					step = 2
				return false
			if rf > a.ally_react_seconds + 0.3:
				check((cl.global_position - spot).length() > 0.3, "  she waits %.1f s after the reveal, then dodges (%.2f m)" % [a.ally_react_seconds, (cl.global_position - spot).length()])
				check(not a._ally_dangers(k).any(func(dd): return dd["area"] == g.attack_range), "Knight in melee range ignores the Heavy Attack (holds ground)")
				check(a._ally_dangers(cl).any(func(dd): return dd["area"] == g.attack_range), "  the Cleric doesn't")
				a._finish_enemy_skill(g, false)
				step = 2; t = 0
		2:
			g.hold = true
			g.forced_skill = skill(g, "Right Golem Smash")
			g.timeline_pos = a.cast_zone_start
			a._begin_cast(g)
			check(is_equal_approx(g.attack_range.angle_degrees, 360.0), "Golem Smash: grey area covers the whole room")
			a._reveal_skill(g)
			check(is_equal_approx(g.attack_range.angle_degrees, 180.0), "  revealed: half the room")
			g.set_meta("revealed_for", 0.1)
			check(not a._ally_reacted(g), "  can't be parried or defended: 0.1 s after the reveal, not yet")
			g.set_meta("revealed_for", 0.25)
			check(a._ally_reacted(g), "  0.25 s: they move (ally_react_unanswerable_seconds 0.2)")
			a._finish_enemy_skill(g, false)
			# Threat.
			g.remove_meta("threat")
			k.global_position = g.global_position + Vector3(2.5, 0, 0)
			ar.global_position = g.global_position + Vector3(-9, 0, 0)
			cl.global_position = g.global_position + Vector3(0, 0, 25)
			check(a._enemy_target(g) == k, "no threat yet: the nearest (Knight)")
			a._add_threat(g, ar, 120)
			a._add_threat(g, k, 30)
			check(a._enemy_target(g) == ar, "Archer hurt it most, 9 m away: it goes for her")
			var before = int(a.stats.get("threat_targets", 0))
			g.forced_skill = skill(g, "Heavy Attack")
			a._begin_cast(g)
			check(int(a.stats.get("threat_targets", 0)) == before + 1 and int(a.stats.get("threat_targets_archer", 0)) >= 1, "  a cast on her counts threat targets (archer)")
			a._finish_enemy_skill(g, false)
			g.set_meta("threat", {ar: 120.0, k: 30.0})  # undo the cast's decay
			ar.global_position = g.global_position + Vector3(-24, 0, 0)
			check(a._enemy_target(g) == k, "  24 m away: the nearby Knight instead")
			ar.global_position = g.global_position + Vector3(-9, 0, 0)
			a._decay_threat(g)
			check(is_equal_approx(float(g.get_meta("threat")[ar]), 60.0), "threat halves each cast")
			a._add_threat(g, k, 120)
			check(a._enemy_target(g) == k, "Knight hits harder now: back on the Knight")
			# Timing: reveal to strike for a Golem Smash at round 8 speed.
			g.remove_meta("threat")
			for c in a.combatants: c.hold = true
			g.hold = false
			g.forced_skill = skill(g, "Right Golem Smash")
			g.timeline_pos = a.cast_zone_start - 0.01
			reveal_t = -1.0
			step = 3; t = 0
		3:
			if reveal_t < 0 and g.skill_revealed:
				reveal_t = t
			if reveal_t >= 0 and a._strike != null:
				print("INFO Golem Smash: %.2f s from reveal to the strike starting, + %.1f s windup" % [t - reveal_t, g.loaded_def.windup])
				print("FAILS: %d" % fails)
				return true
			if t > 15:
				check(false, "smash never struck")
				print("FAILS: %d" % fails)
				return true
	return false
