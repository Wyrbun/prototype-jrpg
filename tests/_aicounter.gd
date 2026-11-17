extends SceneTree
# Windup: an AI ally whose target raised a Counter stance after it chose
# backs off (its act becomes a Wait) instead of attacking into it and taking
# the counter (a Round 9 log: the Mage took 38 from the Living Armor's).
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.party_ai_override = 1
	BattleArena.windup_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
	var la = a.enemies[0]
	la.global_position = Vector3(0, 0, 0)
	mg.global_position = Vector3(0, 0, 4)
	a.ap = 100.0
	mg.set_meta("windup_target", la)
	la.stance = Skills.Kind.COUNTER
	var hp0 = mg.hp
	var enemy_hp0 = la.hp
	a._ai_turn(mg)
	check(mg.hp == hp0 and la.hp == enemy_hp0, "no attack into the Counter stance, no counter taken")
	check(int(a.stats.get("ai_counter_backoffs", 0)) == 1 and int(a.stats.get("ai_waits", 0)) >= 1, "it backs off: the act becomes a Wait")
	la.stance = Skills.NONE
	mg.set_meta("windup_target", la)
	a._ai_turn(mg)
	check(la.hp < enemy_hp0, "no stance: it attacks as usual")
	print("FAILS: %d" % fails)
	quit()
	return true
