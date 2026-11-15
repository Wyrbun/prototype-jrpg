extends SceneTree
# Party AI: with nobody hurt, the Cleric hastes the fighter you steer (once
# until it wears off); a hurt ally still gets healed first.
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
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.8: return false
	for c in a.combatants: c.hold = true
	var mk = a.party[0]; var cl = a.party[1]
	a._set_controlled(mk)
	a.ap = 150.0
	check(a._ai_ability(cl) and mk.statuses.has("haste"), "nobody hurt: Haste on the Monk you steer")
	check(not a._ai_ability(cl), "already hasted: not again")
	mk.statuses.erase("haste")
	mk.hp = int(mk.max_hp * 0.4)
	var hp0 = mk.hp
	a._ai_ability(cl)
	check(mk.hp > hp0 and not mk.statuses.has("haste"), "hurt ally: healed instead (%d -> %d)" % [hp0, mk.hp])
	# Shielding: once for hurt allies, not again while their shields hold.
	mk.hp = int(mk.max_hp * 0.7); cl.hp = int(cl.max_hp * 0.7)
	mk.shield = 0; cl.shield = 0
	mk.statuses["haste"] = {"turns": 2, "caster": cl}
	a.ap = 150.0
	a._ai_ability(cl)
	check(mk.shield > 0 and cl.shield > 0, "two allies at 70%%: Shielding (%d, %d)" % [mk.shield, cl.shield])
	var ap_before = a.ap
	a._ai_ability(cl)
	check(is_equal_approx(a.ap, ap_before), "shields still up: no second Shielding")
	print("FAILS: %d" % fails)
	return true
