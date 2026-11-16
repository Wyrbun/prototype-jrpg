extends SceneTree
# Cleric's Lifeline: dash beside an ally within 8 m (out of whatever she
# stood in); both heal 15% of their max HP. The AI Cleric uses it when she's
# caught in a revealed area and an ally within reach stands clear.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var kn = a.party.filter(func(p): return p.class_id == "knight")[0]
	var cl = a.party.filter(func(p): return p.class_id == "cleric")[0]
	var ar = a.party.filter(func(p): return p.class_id == "archer")[0]
	var g = a.enemies[0]
	g.global_position = Vector3(0, g.global_position.y, -3)
	cl.global_position = g.global_position + Vector3(0, 0, 2.2)
	kn.global_position = g.global_position + Vector3(6.5, 0, 2.5)
	ar.global_position = g.global_position + Vector3(-12, 0, 6)
	var skill = Moves.skills("cleric").filter(func(s): return s["name"] == "Lifeline")
	check(skill.size() == 1, "the Cleric has Lifeline")
	skill = skill[0]
	check(skill["target"] == Moves.Target.OTHER_ALLY and float(skill["cost"]) == 30.0, "30 AP, on another ally")
	a._set_controlled(cl)
	var choices = a._skill_choices(skill)
	check(choices.has(kn) and not choices.has(ar) and not choices.has(cl), "only allies within 8 m (Knight yes, far Archer no, not herself)")
	cl.hp = 50; kn.hp = 100
	a.ap = 100.0
	a._use_skill(skill, kn, cl.global_position)
	check(cl.global_position.distance_to(kn.global_position) < cl.body_radius + kn.body_radius + 0.5, "she lands beside the Knight")
	check(cl.hp == 50 + ceili(cl.max_hp * 0.15) and kn.hp == 100 + ceili(kn.max_hp * 0.15), "both heal 15%% of their max HP (%d, %d)" % [cl.hp, kn.hp])
	check(is_equal_approx(a.ap, 70.0), "costs 30 AP")
	# AI: caught in a revealed Rock Stomp, the Knight clear of it.
	cl.global_position = g.global_position + Vector3(0, 0, 2.2)
	cl.hp = cl.max_hp; kn.hp = kn.max_hp
	var stomp = g.skills.filter(func(s): return s.skill_name == "Rock Stomp")[0]
	g.forced_skill = stomp
	g.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(g)
	a._reveal_skill(g)
	g.set_meta("revealed_for", 5.0)
	check(g.attack_range.contains(cl.global_position, cl.body_radius) and not g.attack_range.contains(kn.global_position, kn.body_radius), "setup: the Cleric is in the Stomp, the Knight isn't")
	check(a._ai_lifeline_target(cl) == kn, "AI: caught, it picks Lifeline to the Knight")
	cl.global_position = g.global_position + Vector3(0, 0, 9)
	check(a._ai_lifeline_target(cl) == null, "AI: not caught and nobody hurt: no Lifeline")
	print("FAILS: %d" % fails)
	quit()
	return true
