extends SceneTree
# Party AI: the Mage casts Concentrate whenever it can afford it (not while
# one is running; Arcane Barrier first if an attack is aimed at it).
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
	a.ap = 120.0; a._concentrate_left = 0.0
	check(a._ai_ability(mg) and a._concentrate_left > 0.0, "enough AP: Concentrate (%.0f s)" % a._concentrate_left)
	var ap_after = a.ap
	check(not a._ai_ability(mg), "already running: not again")
	a._concentrate_left = 0.0
	a.ap = 20.0
	check(not a._ai_ability(mg) and a._concentrate_left == 0.0, "not enough AP: no cast")
	print("FAILS: %d" % fails)
	return true
