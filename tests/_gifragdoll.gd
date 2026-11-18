extends SceneTree
# Not a test (README GIF frames, FRAMES = folder); the checks are _ragdoll.gd.
# Ragdolls: a party member downed by a strong blow (a Smash here) is sent
# flying away from the enemy and ends lying on the floor; one downed by
# anything else (a burn, a small hit) flops over where it stands. Revive
# stands the body back up. SHOTS=folder takes screenshots mid-flight.
var a
var t := 0.0
var step := 0
var fails := 0
var kn
var cl
var g
var start_k
var start_c
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
func lying(m) -> bool:
	var rig = m.get_node_or_null("Limp")
	if rig == null: return false
	var up: Vector3 = rig.torso.global_basis.y
	return absf(up.y) < 0.5 and rig.torso.global_position.y < 0.5
func shot(n):
	if OS.get_environment("SHOTS") != "":
		root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + n + ".png")
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			cl = a.party.filter(func(p): return p.class_id == "cleric")[0]
			g = a.enemies[0]
			g.global_position = Vector3(0, 0, -4)
			kn.global_position = Vector3(0, 0, -1)
			cl.global_position = Vector3(4, 0, 1)
			start_k = kn.global_position
			start_c = cl.global_position
			# The Knight: downed by a Golem Smash (strong): flies.
			g.forced_skill = g.skills.filter(func(s): return s.skill_name == "Left Golem Smash")[0]
			g.timeline_pos = a.cast_zone_start + 1.0
			a._begin_cast(g)
			check(a._strong_blow(g), "a Golem Smash is a strong blow")
			step = 5; t = 0
		5:
			if int(t / 0.0667) != int((t - d) / 0.0667):
				root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/a%03d.png" % int(t / 0.0667))
			if t < 1.0: return false
			a._hurt(kn, 9999, false, "Stone Golem: Left Golem Smash", g, "Left Golem Smash")
			a._finish_enemy_skill(g, false)
			# The Cleric: downed by a burn (no enemy): flops.
			a._hurt(cl, 9999, false, "Fire Wave fire")
			check(kn.is_down and cl.is_down, "both down")
			check(kn.get_node_or_null("Limp") != null and cl.get_node_or_null("Limp") != null, "both bodies go limp (body parts under a pivot)")
			step = 1; t = 0
		1:
			if OS.get_environment("FRAMES") != "" and int(t / 0.0667) != int((t - d) / 0.0667) and t < 3.0:
				root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%03d.png" % int(t / 0.0667))
			if t > 0.25 and t - d <= 0.25:
				shot("ragdoll_air")
				check(kn.get_node("Limp").torso.global_position.y > 1.3, "the Knight is in the air (torso %.1f m up)" % kn.get_node("Limp").torso.global_position.y)
			if t < 4.2: return false
			shot("ragdoll_rest")
			var moved = Vector2(kn.global_position.x - start_k.x, kn.global_position.z - start_k.z)
			check(moved.length() > 2.0 and moved.y > 0.0, "the Knight was thrown %.1f m, away from the Golem" % moved.length())
			check(lying(kn), "and ends lying on the floor")
			check(cl.global_position.distance_to(start_c) < 1.0, "the Cleric crumples about where she stood (%.2f m)" % cl.global_position.distance_to(start_c))
			check(lying(cl), "lying on the floor too")
			check(a._ragdolls.is_empty(), "both settled")
			a._revive(kn, 0.5)
			check(kn.get_node_or_null("Limp") == null and kn.get_node("Body").global_position.y > 0.8, "Revive: standing again")
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
