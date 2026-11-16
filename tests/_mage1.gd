extends SceneTree
# Mage rework, step 1: four elements (Fire, Ice, Lightning, Energy Blast),
# order-free Arts, the biggest bar, and Ice making Fire cheaper (same combo,
# and the next turn).
var a
var t := 0.0
var fails := 0
var mg
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func idx(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return i
	return -1
func bar(names):
	a.battle_menu.combo.clear()
	a._combo_locks.clear()
	for n in names: a.battle_menu.combo.append(idx(n))
	a._rebuild_plan()
	return a._plan.map(func(e): return "%s:%d" % [e["name"], int(e["cost"])])
func _process(d):
	t += d
	if t < 0.8: return false
	ArtsBook.reset()
	for n in ["Fireball", "Blizzard", "Steam Burst", "Meteor"]: ArtsBook.discover("mage", n)
	for c in a.combatants: c.hold = true
	mg = a.party[0]
	var g = a.enemies[0]
	mg.global_position = g.global_position + Vector3(0, 0, g.body_radius + 2.0)
	a._set_controlled(mg); a.active = mg; a.current_max_ap = 300; a.ap = 300; a._command_phase = false
	a._open_combo_bar(g)
	var names = a._moves.map(func(m): return m["name"])
	check(names == ["Fire", "Ice", "Lightning", "Energy Blast"], "four elements: %s" % [names])
	check(a._moves[idx("Lightning")].get("stun", false), "Lightning interrupts")
	check(float(a._moves[idx("Energy Blast")]["knockback"]) == 3.0 and a._moves[idx("Energy Blast")].has("surge"), "Energy Blast pushes 3 m and taps freely")
	check(mg.combo_limit == 50.0 + 10.0 * mg.focus, "bar 50 + 10 per Focus: %d (%d Focus)" % [mg.combo_limit, mg.focus])
	# Order-free Arts.
	check(bar(["Fire", "Ice"]) == bar(["Ice", "Fire"]) and bar(["Ice", "Fire"])[0].begins_with("Steam Burst"), "Fire + Ice = Ice + Fire = Steam Burst (%s)" % [bar(["Ice", "Fire"])])
	var m1 = bar(["Energy Blast", "Lightning", "Ice", "Fire"])
	check(m1.size() == 1 and m1[0].begins_with("Meteor"), "any order of all four: Meteor (%s)" % [m1])
	var meteor = a._plan[0]["move"]
	check(float(meteor.get("knockback", 0.0)) == 0.0 and not meteor.get("stun", false), "  Meteor doesn't inherit the push or the interrupt")
	# Ice discount, same combo.
	mg.set_meta("ice_carry", false)
	check(bar(["Fire"]) == ["Fire:20"], "Fire alone: 20 AP")
	check(bar(["Ice", "Lightning", "Fire"]) == ["Ice:20", "Lightning:20", "Fire:16"], "one Ice before it: Fire 16 (%s)" % [bar(["Ice", "Lightning", "Fire"])])
	check(bar(["Ice", "Ice", "Lightning", "Fire"]) == ["Blizzard:40", "Lightning:20", "Fire:12"], "two Ices: Fire 12, the 40%% max (%s)" % [bar(["Ice", "Ice", "Lightning", "Fire"])])
	check(bar(["Fire", "Lightning", "Ice"]) == ["Fire:20", "Lightning:20", "Ice:20"], "Ice after Fire: no discount (%s)" % [bar(["Fire", "Lightning", "Ice"])])
	check(bar(["Fire", "Ice"]) == ["Steam Burst:36"], "Steam Burst: its own Ice discounts its Fire (%s)" % [bar(["Fire", "Ice"])])
	bar(["Ice"])
	check(int(a._next_cost(idx("Fire"))) == 16, "the move list shows Fire at 16 after an Ice")
	# Next turn.
	bar(["Ice", "Lightning"])
	a._note_ice_carry(mg)
	check(mg.get_meta("ice_carry_next", false), "a combo with Ice: next turn's Fire is cheaper")
	a._turn_upkeep(mg)
	check(mg.get_meta("ice_carry", false) and not mg.has_meta("ice_carry_next"), "  her next turn: the discount is on")
	check(bar(["Fire"]) == ["Fire:16"], "  Fire alone: 16 (%s)" % [bar(["Fire"])])
	check(bar(["Ice", "Ice", "Lightning", "Fire"])[-1] == "Fire:10", "  with two Ices too: capped at 50%% (%s)" % [bar(["Ice", "Ice", "Lightning", "Fire"])])
	bar(["Fire"])
	a._note_ice_carry(mg)
	a._turn_upkeep(mg)
	check(not mg.get_meta("ice_carry", false), "  a turn without Ice: full price again")
	print("FAILS: %d" % fails)
	return true
