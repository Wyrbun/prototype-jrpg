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
	mk.hp = int(mk.max_hp * 0.72); cl.hp = int(cl.max_hp * 0.72)
	mk.shield = 0; cl.shield = 0
	mk.statuses["haste"] = {"turns": 2, "caster": cl}
	a.ap = 150.0
	a._ai_ability(cl)
	check(mk.shield > 0 and cl.shield > 0, "two allies at 72%%: Shielding (%d, %d)" % [mk.shield, cl.shield])
	var ap_before = a.ap
	a._ai_ability(cl)
	check(is_equal_approx(a.ap, ap_before), "shields still up: no second Shielding")
	# Heals come before your AP reserve, and start at 70% (was 55%).
	mk.shield = 0; cl.shield = 0; cl.hp = cl.max_hp
	mk.hp = int(mk.max_hp * 0.65)
	a.ap = 26.0
	mk.timeline_pos = a.party_command_at - 1.0  # your turn is close: AP is held back for it
	check(a._ai_reserve(cl) > 2.5, "  (your reserve: %.0f AP)" % a._ai_reserve(cl))
	var healed0 = int(a.stats.get("hp_healed", 0))
	hp0 = mk.hp
	a._ai_ability(cl)
	check(mk.hp > hp0, "Monk at 65%%, 26 AP (Healing 25, but AP is held for you): Healing anyway (%d -> %d)" % [hp0, mk.hp])
	check(int(a.stats.get("hp_healed", 0)) - healed0 == mk.hp - hp0, "  reports count hp_healed (+%d)" % (int(a.stats.get("hp_healed", 0)) - healed0))
	mk.hp = int(mk.max_hp * 0.2)
	a.ap = 40.0
	hp0 = mk.hp
	a._ai_ability(cl)
	check(mk.hp > hp0 and mk.hp < mk.max_hp, "Monk at 20%%, 40 AP (Full Cure costs 60): Healing instead (%d -> %d)" % [hp0, mk.hp])
	print("FAILS: %d" % fails)
	return true
