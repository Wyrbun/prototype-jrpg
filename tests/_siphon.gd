extends SceneTree
# Archer's Siphon Shot (replaced Riposte): her hits on a Siphoned enemy heal
# her 3% of max HP (6% on a Perfect), for 3 of her turns; only her hits.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/archer.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var ar = a.party.filter(func(p): return p.class_id == "archer")[0]
	var kn = a.party.filter(func(p): return p.class_id == "knight")[0]
	var g = a.enemies[0]
	var names = Moves.skills("archer").map(func(s): return s["name"])
	check(names.has("Siphon Shot") and not names.has("Riposte"), "Siphon Shot replaced Riposte: %s" % [names])
	var siphon = Moves.skills("archer").filter(func(s): return s["name"] == "Siphon Shot")[0]
	ar.global_position = g.global_position + Vector3(0, 0, g.body_radius + 4.0)
	a._set_controlled(ar); a.ap = 100.0
	a._use_skill(siphon, g, ar.global_position)
	check(g.statuses.has("siphoned"), "the enemy is Siphoned")
	ar.hp = 60
	var shot = Moves.attacks("archer")[0]
	a._combo_target = g; a._exec_attacker = ar; a._exec_hit_perfect = false
	a._land_hit(ar, shot.duplicate(true), 1.0, true, true)
	check(ar.hp == 60 + roundi(ar.max_hp * 0.03), "a hit heals her 3%% (%d)" % (ar.hp - 60))
	var hp1 = ar.hp
	a._exec_hit_perfect = true
	a._land_hit(ar, shot.duplicate(true), 1.0, true, true)
	check(ar.hp - hp1 == roundi(ar.max_hp * 0.06), "a Perfect heals 6%% (%d)" % (ar.hp - hp1))
	kn.hp = 50
	a._exec_attacker = kn; a._exec_hit_perfect = false
	a._land_hit(kn, Moves.attacks("knight")[0].duplicate(true), 1.0, true, true)
	check(kn.hp == 50, "the Knight's hits don't heal anyone")
	for i in 3: g.tick_statuses(ar)
	check(not g.statuses.has("siphoned"), "gone after 3 of her turns")
	# AI: hurt and in range -> Siphon.
	g.statuses.erase("siphoned")
	ar.hp = int(ar.max_hp * 0.5); a.ap = 100.0
	var saved = a.controlled
	a.controlled = kn
	check(a._ai_ability(ar) and g.statuses.has("siphoned"), "AI Archer, hurt: Siphon Shot")
	print("FAILS: %d" % fails)
	quit()
	return true
