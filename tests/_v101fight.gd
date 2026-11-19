extends SceneTree
# 1.0.1 fight changes:
# - Ogre's Shout stuns whoever it pushes until Sword Spin lands, so both land
#   (play-test: pushed out, they walked straight back out of the ring).
# - The Golem winds up the arm on the side its Smash will hit.
# - Jump shows a ring at its 8 m reach while you aim it.
# - Energy spells: once the code is in, the prompt says to tap.
var a
var t := 0.0
var step := 0
var fails := 0
var ogre
var kn
var hp0 := 0
var spot := Vector3.ZERO
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func load_round(i, party):
	if a: a.queue_free()
	BattleArena._round_index = i
	BattleArena.chosen_for_round = i
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(party)
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	t = 0.0
func _initialize():
	load_round(5, ["res://scenes/characters/assassin.tscn", "res://scenes/characters/knight.tscn"])
func _process(d):
	t += d
	match step:
		0:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			ogre = a.enemies.filter(func(e): return e.display_name == "Ogre Warrior")[0]
			kn = a.party.filter(func(p): return p.class_id == "knight")[0]
			for e in a.enemies: if e != ogre: e.global_position += Vector3(40, 0, 0)
			var other = a.party.filter(func(p): return p != kn)[0]
			other.global_position = ogre.global_position + Vector3(0, 0, 12)
			kn.global_position = ogre.global_position + Vector3(2.0, 0, 0)
			ogre.forced_skill = skill(ogre, "Shout")
			ogre.timeline_pos = a.cast_zone_start
			a._begin_cast(ogre)
			a._reveal_skill(ogre)
			hp0 = kn.hp
			a._enemy_unleash(ogre, true)
			var gap: float = kn.global_position.distance_to(ogre.global_position)
			check(gap > 4.0 and gap < 6.0, "Shout pushed the Knight into Sword Spin's ring (%.1f m)" % gap)
			check(float(kn.get_meta("knocked", 0.0)) >= skill(ogre, "Shout").follow_up_delay, "and stunned them past the follow-up (%.2f s)" % float(kn.get_meta("knocked", 0.0)))
			spot = kn.global_position
			ogre.hold = false
			check(kn.current_move_speed() == 0.0, "stunned: can't walk")
			step = 1
			t = 0.0
		1:
			if kn.hp == hp0 and t < 6.0:
				# Until Sword Spin lands they stay stunned, however long that is.
				if kn.current_move_speed() != 0.0:
					check(false, "the stun lasted until Sword Spin (ended at %.1f s)" % t)
					t = 99.0
				return false
			check(kn.hp < hp0, "Sword Spin landed while they were stuck in its ring (%d -> %d, %.1f s)" % [hp0, kn.hp, t])
			check(kn.global_position.distance_to(spot) < 0.3 or kn.hp < hp0, "  (they hadn't moved)")
			load_round(7, ["res://scenes/characters/archer.tscn", "res://scenes/characters/knight.tscn"])
			step = 2
		2:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			var g = a.enemies[0]
			var anim: FigureAnim = g.anim
			g.loaded_def = skill(g, "Right Golem Smash")
			var right: Dictionary = anim._ready_pose()
			g.loaded_def = skill(g, "Left Golem Smash")
			var left: Dictionary = anim._ready_pose()
			check(right["ArmR"].x < -150.0 and right["ArmL"].x > -60.0, "Right Smash: the right arm goes up")
			check(left["ArmL"].x < -150.0 and left["ArmR"].x > -60.0, "Left Smash: the left arm goes up")
			check(skill(g, "Right Golem Smash").aim_offset_degrees > 0.0, "(the Right Smash aims at its right: +90)")
			g.loaded_def = null
			# Jump's reach ring.
			var ar = a.party.filter(func(p): return p.class_id == "archer")[0]
			a._set_controlled(ar)
			a.active = ar
			a._command_phase = false
			a.ap = 200.0
			a._open_skills()
			var jump := -1
			for i in a._skills.size():
				if a._skills[i]["name"] == "Jump": jump = i
			a._choose_skill(jump)
			var ring: Node3D = a._range_ring
			check(ring != null and ring.is_inside_tree(), "Jump: a ring shows its reach")
			if ring != null:
				var edge: float = (ring.get_child(0) as MeshInstance3D).mesh.get_aabb().size.x / 2.0
				check(absf(edge - 8.0) < 0.05 and ring.global_position.distance_to(Vector3(ar.global_position.x, 0, ar.global_position.z)) < 0.01,
						"  8 m around the Archer (%.2f m)" % edge)
			a._clear_target_marker()
			check(a._range_ring == null, "  and goes when the aiming ends")
			load_round(4, ["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
			step = 3
		3:
			if t < 0.8: return false
			for c in a.combatants: c.hold = true
			var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
			var e1 = a.enemies[0]
			mg.global_position = e1.global_position + Vector3(0, 0, 4.0)
			a._set_controlled(mg); a.active = mg; a._command_phase = false
			a.current_max_ap = 200; a.ap = 200
			a._open_combo_bar(e1)
			var blast := -1
			for i in a._moves.size():
				if a._moves[i]["name"] == "Energy Blast": blast = i
			a._add_to_combo(blast)
			a._execute_combo()
			a._exec_lead_in = 0.0
			var entry: Dictionary = a._plan[0]
			a._exec_time = entry["duration"] * 0.3
			var before: String = a._timing_prompt()
			check(before.contains("1) TYPE") and before.contains("2) then TAP"), "before the code: type, then tap (%s)" % before)
			for arrow in entry["code"]:
				a._judge_code(arrow)
			var after: String = a._timing_prompt()
			check(after.contains("CODE IN!") and after.contains("TAP"), "code in: the prompt says tap now (%s)" % after)
			a._judge_timing()
			a._judge_timing()
			check(a._exec_taps == 2 and a._timing_prompt().contains("(2 / "), "taps count on the prompt")
			print("FAILS: ", fails)
			quit()
			return true
	return false
