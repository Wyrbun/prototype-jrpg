extends SceneTree
# Party AI: the Mage casts Enchant when none is running (Arcane Barrier
# first if an attack is aimed at it): Lightning while a Stagger bar is up,
# Ice against 3+ enemies, Fire otherwise. Not while one runs.
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
	if t < 0.8: return false
	for c in a.combatants: c.hold = true
	var mg = a.party[1]
	var kn = a.party[0]
	a.ap = 120.0
	check(a._ai_ability(mg) and kn.statuses.size() > 0, "enough AP: Enchant (%s)" % [kn.statuses.keys()])
	var got: String = ""
	for e in a.ENCHANTS:
		if kn.statuses.has("enchant_" + e): got = e
	check(got == "fire" or got == "ice" or got == "lightning", "picked an element: %s" % got)
	check(not mg.statuses.has("enchant_" + got), "not on the Mage herself")
	check(not a._ai_ability(mg), "already running: not again")
	# Lasts 2 of her turns.
	kn.tick_statuses(mg)
	check(kn.statuses.has("enchant_" + got), "still there after 1 of her turns")
	kn.tick_statuses(mg)
	check(not kn.statuses.has("enchant_" + got), "gone after 2 of her turns")
	a.ap = 20.0
	check(not a._ai_ability(mg) and not a._enchant_running(), "not enough AP: no cast")
	print("FAILS: %d" % fails)
	return true
