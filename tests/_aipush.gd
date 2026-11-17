extends SceneTree
# AI allies don't push an enemy whose area moves with it while it prepares
# (a pushed Golem Smash landed on the side the party had run to). You still
# can; Lightweight Gust Sprites are still pushed.
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
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
	var g = a.enemies[0]
	g.global_position = Vector3(0, 0, -2)
	mg.global_position = Vector3(0, 0, 2)
	var blast = Moves.attacks("mage").filter(func(m): return m["name"] == "Energy Blast")[0].duplicate(true)
	check(float(blast.get("knockback", 0.0)) > 0.0, "Energy Blast pushes (%.1f m)" % float(blast.get("knockback", 0.0)))
	var smash = g.skills.filter(func(s): return s.skill_name == "Left Golem Smash")[0]
	g.forced_skill = smash
	g.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(g)
	check(a._carries_area(g), "a Golem Smash is carried by the Golem")
	a._exec_attacker = mg
	a._combo_target = g
	var p0 = g.global_position
	a._ai_playing = true
	a._land_hit(mg, blast.duplicate(true), 1.0, true, true)
	a._ai_playing = false
	check(g.global_position.distance_to(p0) < 0.01, "AI Mage: the Golem isn't pushed while it prepares the Smash")
	a._land_hit(mg, blast.duplicate(true), 1.0, true, true)
	check(g.global_position.distance_to(p0) > 0.5, "you: the push still works (%.1f m)" % g.global_position.distance_to(p0))
	a._finish_enemy_skill(g, false)
	g.global_position = p0
	a._ai_playing = true
	a._land_hit(mg, blast.duplicate(true), 1.0, true, true)
	a._ai_playing = false
	check(g.global_position.distance_to(p0) > 0.5, "AI, nothing being prepared: pushes as usual")
	print("FAILS: %d" % fails)
	quit()
	return true
