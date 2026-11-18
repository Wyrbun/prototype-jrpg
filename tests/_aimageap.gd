extends SceneTree
# The AI Mage doesn't spend her turn on an Enchant that leaves no AP for a
# spell (play-tests: two Enchants, two Waits, no damage); with AP to spare
# she still Enchants.
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.party_ai_override = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d) -> bool:
	t += d
	if t < 1.0: return false
	for c in a.combatants: c.hold = true
	var mage: Combatant = null
	for m in a.party:
		if m.class_id == "mage": mage = m
	check(mage != null, "Round 5 has the Mage")
	a.controlled = null  # nobody to keep AP for: the test sets the pool itself
	var enchant: float = a._ai_skill_cost("mage", "Enchant")
	var spell: float = a._ai_cheapest_attack("mage")
	check(enchant == 30.0 and spell == 20.0, "Enchant costs %d, her cheapest spell %d" % [enchant, spell])
	a.ap = enchant + spell - 5.0
	check(not a._ai_ability(mage) and not a._enchant_running(), "AP for the Enchant but not a spell after: no Enchant")
	a.ap = enchant + spell + 5.0
	check(a._ai_ability(mage) and a._enchant_running(), "AP for both: she Enchants")
	print("FAILS: ", fails)
	quit()
	return true
