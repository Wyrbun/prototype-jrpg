extends SceneTree
# Knockdowns: a living party member hit by a strong blow (a Golem Smash) or
# pushed far goes down in a heap where it is, can't walk, but its timeline
# runs on; after knockdown_seconds it gets up. If it was winding up an
# attack, it gets extra grace to walk back in. A wall boss's breath never
# knocks down. FRAMES=folder saves GIF frames.
var a
var t := 0.0
var step := 0
var fails := 0
var kn
var ar
var g
var pos0
var tl0
var peak := 0.0
var h0 := 0.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func frame(d, prefix):
	if OS.get_environment("FRAMES") != "" and int(t / 0.0667) != int((t - d) / 0.0667):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/%s%03d.png" % [prefix, int(t / 0.0667)])
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			ar = a.party.filter(func(p): return p.class_id == "archer")[0]
			g = a.enemies[0]
			# Side on to the camera, so the fall reads.
			g.global_position = Vector3(-3.5, 0, -1)
			g.look_at(Vector3(0, 0, -1), Vector3.UP, true)
			kn.global_position = Vector3(-0.6, 0, -1)
			kn.look_at(g.global_position, Vector3.UP, true)
			ar.global_position = Vector3(5, 0, 2)
			kn.max_hp = 9999; kn.hp = 9999
			g.forced_skill = g.skills.filter(func(s): return s.skill_name == "Left Golem Smash")[0]
			g.timeline_pos = a.cast_zone_start + 1.0
			a._begin_cast(g)
			step = 1; t = 0
		1:
			frame(d, "a")
			if t < 0.9: return false
			# The Knight was winding up an attack on the Golem.
			kn.set_meta("windup_target", g)
			a._hurt(kn, 30, false, "Stone Golem: Left Golem Smash", g, "Left Golem Smash")
			a._finish_enemy_skill(g, false)
			check(not kn.is_down, "the Knight survives the Smash")
			check(kn.has_meta("knocked"), "and is knocked down")
			check(kn.get_node_or_null("Limp") != null, "body limp (ragdoll)")
			check(kn.current_move_speed() == 0.0, "can't walk while down")
			pos0 = kn.global_position
			h0 = kn.get_node("Limp").torso.global_position.y
			kn.timeline_pos = 10.0
			tl0 = kn.timeline_pos
			for c in a.combatants: c.hold = false
			g.hold = true; ar.hold = true
			step = 2; t = 0
		2:
			frame(d, "b")
			if OS.get_environment("DBG") != "":
				var lp = kn.get_node_or_null("Limp")
				print("t=%.2f limp=%s %s %s body=%s kids=%s" % [t, lp != null, lp.position if lp else "", lp.rotation_degrees if lp else "", kn.get_node("Body").get_parent().name if kn.get_node_or_null("Body") else "?", kn.get_children().map(func(n): return n.name)])
			if kn.get_node_or_null("Limp"):
				peak = maxf(peak, kn.get_node("Limp").torso.global_position.y)
			if t < 1.0: return false
			check(peak > h0 + 0.2, "tossed up a little (%.2f m above where it started)" % (peak - h0))
			var torso = kn.get_node("Limp").torso
			check(absf(torso.global_basis.y.y) < 0.5 and torso.global_position.y < 0.5, "lying on the floor (torso %.2f m up, tilt %.2f)" % [torso.global_position.y, torso.global_basis.y.y])
			check(Vector2(torso.global_position.x - pos0.x, torso.global_position.z - pos0.z).length() < 1.5, "about where it was hit")
			check(kn.has_meta("knocked"), "still down after 1 s")
			check(Vector2(kn.global_position.x - pos0.x, kn.global_position.z - pos0.z).length() < 0.05, "locked in place")
			check(kn.timeline_pos > tl0, "its timeline kept running (%.1f -> %.1f)" % [tl0, kn.timeline_pos])
			step = 3; t = 0
		3:
			frame(d, "c")
			if t < 0.6: return false
			check(not kn.has_meta("knocked"), "up again after knockdown_seconds")
			check(kn.get_node_or_null("Limp") == null, "body no longer limp")
			check(float(kn.get_meta("windup_grace", 0.0)) < 0.0, "extra grace to walk back in (%.1f s)" % -float(kn.get_meta("windup_grace", 0.0)))
			check(kn.current_move_speed() > 0.0, "can walk again")
			step = 4; t = 0
		4:
			frame(d, "d")
			if t < 1.6: return false
			check(kn.get_node("Body").global_position.y > 0.6, "standing (%.2f)" % kn.get_node("Body").global_position.y)
			# A defended Smash: no knockdown.
			g.forced_skill = g.skills.filter(func(s): return s.skill_name == "Left Golem Smash")[0]
			g.timeline_pos = a.cast_zone_start + 1.0
			a._begin_cast(g)
			check(a._crushing_blow(g), "(the Smash is loaded again)")
			a._hurt(kn, 20, true, "Stone Golem: Left Golem Smash", g, "Left Golem Smash")
			check(not kn.has_meta("knocked"), "a defended Smash keeps the Knight up")
			a._finish_enemy_skill(g, false)
			# Pushed far: knocked down too.
			a._knock_down(ar, g)
			check(ar.has_meta("knocked"), "a far push knocks down too")
			# Small blow from a non-strong attack: no knockdown.
			var weak = Combatant.new()
			check(not a._strong_blow(null), "no enemy: not a strong blow")
			weak.free()
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
