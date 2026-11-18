extends SceneTree
# Knocked flying: the Living Armor's Combo throws the Knight 5 m; the
# Knight is knocked down, flies there in an arc (no teleport), lies, gets
# up. The first two hits don't knock down (only the throw does).
# FRAMES=folder saves GIF frames.
var a
var t := 0.0
var step := 0
var fails := 0
var kn
var la
var p0
var land
var peak := 0.0
var mid_ok := false
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
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
			for c in a.combatants: c.hold = true; c.timeline_pos = 0.0
			kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			la = a.enemies[0]
			for e in a.enemies:
				if e != la: e.global_position = Vector3(8, 0, 6)
			la.global_position = Vector3(-4, 0, -1)
			la.look_at(Vector3(0, 0, -1), Vector3.UP, true)
			kn.global_position = Vector3(-2.6, 0, -1)
			kn.look_at(la.global_position, Vector3.UP, true)
			kn.max_hp = 9999; kn.hp = 9999
			la.forced_skill = la.skills.filter(func(s): return s.skill_name == "Combo")[0]
			la.timeline_pos = a.cast_zone_start
			a._begin_cast(la); a._reveal_skill(la)
			check(not a._crushing_blow(la), "the Combo's hits aren't crushing on their own")
			step = 1; t = 0
		1:
			frame(d, "a")
			if t < 0.7: return false
			p0 = kn.global_position
			for c in a.party: c.timeline_pos = 0.0
			a.active = null
			la.face_toward(kn.global_position - la.global_position, 1.0, 1000000.0)
			a._enemy_unleash(la, false)
			if OS.get_environment("FRAMES") != "":
				step = 15; t = 0  # let the three hits play out in real time
				return false
			var g = 0
			while a._strike != null and g < 10:
				a._strike.time_left = 0.0; a._update_strike(0.0); g += 1
			check(kn.has_meta("knocked"), "thrown 5 m: knocked down")
			check(kn.get_node("Limp").torso.global_position.distance_to(p0 + Vector3(0, 0.77, 0)) < 0.5, "the body starts its flight where it was hit")
			for c in a.combatants: c.hold = false
			la.hold = true
			step = 2; t = 0
		15:
			frame(d, "a5")
			if not kn.has_meta("knocked"): return false
			for c in a.combatants: c.hold = false
			la.hold = true
			step = 2; t = 0
		2:
			frame(d, "b")
			var rig = kn.get_node_or_null("Limp")
			if rig and rig is Ragdoll:
				var tp = rig.torso.global_position
				var flown = Vector2(tp.x - p0.x, tp.z - p0.z).length()
				if t > 0.15 and t < 0.4 and flown > 0.5 and flown < 4.0: mid_ok = true
				peak = maxf(peak, tp.y)
			if t < 1.2: return false
			var tp2 = kn.get_node("Limp").torso.global_position
			var flown2 = Vector2(tp2.x - p0.x, tp2.z - p0.z).length()
			check(mid_ok, "mid-flight partway there")
			check(flown2 > 3.5 and flown2 < 7.0, "the body lands %.1f m away (the push: 5)" % flown2)
			check(peak > 1.6, "high arc (torso up to %.2f m)" % peak)
			check(kn.has_meta("knocked"), "still down after landing")
			step = 3; t = 0
		3:
			frame(d, "c")
			if t < 2.2: return false
			check(not kn.has_meta("knocked") and kn.get_node_or_null("Limp") == null, "back up")
			# Parried: no throw, no knockdown, whatever the blow.
			for c in a.combatants: c.hold = true; c.timeline_pos = 0.0
			a.active = null
			kn.global_position = Vector3(-2.6, 0, -1)
			for r in [a.Reaction.PARRY, a.Reaction.DEFEND]:
				var sk = "Combo"
				kn.global_position = Vector3(-2.6, 0, -1)
				var at = kn.global_position
				la.forced_skill = la.skills.filter(func(s): return s.skill_name == sk)[0]
				la.timeline_pos = a.cast_zone_start
				a._begin_cast(la); a._reveal_skill(la)
				la.face_toward(kn.global_position - la.global_position, 1.0, 1000000.0)
				a._enemy_unleash(la, false)
				var g = 0
				while a._strike != null and g < 10:
					a._strike.reaction = r
					a._strike.time_left = 0.0; a._update_strike(0.0); g += 1
				if r == a.Reaction.PARRY:
					check(not kn.has_meta("knocked") and kn.global_position.distance_to(at) < 0.05, "Combo parried: no throw, no knockdown")
				else:
					check(not kn.has_meta("knocked") and kn.global_position.distance_to(at) > 1.0, "Combo defended: braced throw (%.1f m), still standing" % kn.global_position.distance_to(at))
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
