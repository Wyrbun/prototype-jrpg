extends SceneTree
# The Parry key Defends for a fighter who can't Parry but can block (Cleric):
# alone, it's a plain Defend; next to a Knight, the Knight parries and the
# Cleric defends (one Defend's AP).
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/cleric.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func mods(list):
	var m := {}
	for c in list: m[c] = {"mult": 1.0, "unblockable": false, "one_hp": false}
	return m
func strike_on(g, list, press_at):
	g.loaded_def = skill(g, "Heavy Attack"); g.loaded_skill = g.loaded_def.kind
	a._begin_strike(g, mods(list), false)
	a._strike.time_left = press_at
	a._try_parry()
	var r = a._strike.reaction
	var pd = a._strike.parry_defends
	a._resolve_strike()
	return [r, pd]
func _process(d):
	t += d
	if t < 0.8: return false
	a.boss_damage_mult = 1.0
	var g = a.enemies[0]
	var k = a.party[0]; var cl = a.party[1]; var ar = a.party[2]
	for c in a.combatants: c.hold = true
	var dmg = skill(g, "Heavy Attack").damage
	# Cleric alone, Parry key: Defends.
	a.ap = 100; cl.hp = cl.max_hp; cl.recoverable = 0
	var res = strike_on(g, [cl], 0.05)
	check(res[0] == a.Reaction.DEFEND, "Cleric alone: the Parry key Defends")
	check(cl.hp > cl.max_hp - dmg and a.ap == 100 - a.defend_cost, "  takes the Defend share (%d of %d), pays %d AP" % [cl.max_hp - cl.hp, dmg, a.defend_cost])
	# Knight + Cleric, Parry on time: Knight parries, Cleric defends.
	a.ap = 100; cl.hp = cl.max_hp; k.hp = k.max_hp
	res = strike_on(g, [k, cl], 0.05)
	check(res[0] == a.Reaction.PARRY and res[1], "Knight + Cleric: a Parry, plus a Defend for the Cleric")
	check(k.hp == k.max_hp and cl.hp > cl.max_hp - dmg and cl.hp < cl.max_hp, "  Knight unhurt, Cleric defended (%d of %d)" % [cl.max_hp - cl.hp, dmg])
	# Archer can't block either: the Parry key does nothing for her.
	a.ap = 100; ar.hp = ar.max_hp
	res = strike_on(g, [ar], 0.05)
	check(res[0] == a.Reaction.NONE and ar.hp == ar.max_hp - dmg, "Archer alone: nothing to do, full hit")
	print("FAILS: %d" % fails)
	return true
