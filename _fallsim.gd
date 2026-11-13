extends SceneTree
# Realistic check: 4-member party, you steer the Monk and stand still; the
# Golem casts a Smash + Ceiling Burst. How many rocks hit the AI allies?
# Runs the real battle loop (free roam + falls).
var a
var t := 0.0
var step := 0
var hp0 := {}
var g
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0: if t > 0.6:
			seed(int(OS.get_environment("S")))
			g = a.enemies[0]
			for c in a.combatants: c.hold = true
			a._set_controlled(a.party[0])
			for c in a.party:
				c.global_position = g.global_position + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
				a._keep_in_arena(c)
				if OS.get_environment("W") == "1" and c != a.party[0]: c.set_meta("windup_target", g)
				hp0[c] = c.hp
			for s in g.skills:
				if s.skill_name == OS.get_environment("SK"): g.forced_skill = s
			g.timeline_pos = a.cast_zone_start + 1.0
			a._begin_cast(g)
			g.timeline_pos = a.cast_zone_start + 20.0
			a._reveal_skill(g)
			step = 1; t = 0
		1:
			if step == 1 and OS.get_environment("TWICE") == "1" and not has_meta("again") and not a._falls_pending(g):
				set_meta("again", true)
				a._finish_enemy_skill(g, false)
				for c in a.party: hp0[c] = c.hp
				g.timeline_pos = a.cast_zone_start + 1.0
				a._begin_cast(g)
				g.timeline_pos = a.cast_zone_start + 20.0
				a._reveal_skill(g)
				t = 0
				return false
			if OS.get_environment("DBG") == "1" and has_meta("again"):
				var cl = a.party[int(OS.get_environment("WHO"))]
				for f in a._falls:
					var ar = f["area"]
					if ar.contains(cl.global_position, cl.body_radius * 0.6) and float(f["time_left"]) < 1.7:
						var obs := []
						for o in a.arena.obstacles():
							var dd = (o.global_position - cl.global_position); dd.y = 0
							if dd.length() < 4: obs.append("%.1f" % dd.length())
						print("t=%.2f in fall (left %.2f) pos %s dist-to-center %.2f r %.1f; rocks near %s; dangers %d" % [t, f["time_left"], cl.global_position, (cl.global_position - ar.global_position).length(), ar.radius, obs, a._ally_dangers(cl).size()])
			if not a._falls_pending(g) or t > 15.0:
				var out := []
				for c in a.party:
					if c != a.party[0]: out.append("%s %d" % [c.display_name, hp0[c] - c.hp])
				print("RESULT ", " | ".join(out))
				quit()
	return false
