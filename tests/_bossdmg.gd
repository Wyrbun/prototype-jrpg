extends SceneTree
# Bosses deal boss_damage_mult (1.15) more; other enemies and hazards don't.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.8: return false
	for c in a.combatants: c.hold = true
	var g = a.enemies[0]
	var m = a.party[0]
	m.shield = 0; m.hp = m.max_hp
	check(g.boss, "the Golem is a boss")
	var taken = a._hurt(m, 100, false, "test", g, "test")
	check(taken == 115, "boss hit 100 -> 115 (%d)" % taken)
	m.hp = m.max_hp
	taken = a._hurt(m, 100, false, "Rock spike")
	check(taken == 100, "hazard without an owner unchanged (%d)" % taken)
	g.boss = false; m.hp = m.max_hp
	taken = a._hurt(m, 100, false, "test", g, "test")
	check(taken == 100, "non-boss enemy unchanged (%d)" % taken)
	print("FAILS: %d" % fails)
	return true
