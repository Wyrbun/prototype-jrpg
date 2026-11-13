extends SceneTree
# Gale Maw's Gust Sprites: very tough (20% damage) but light (pushed 1.5x
# as far), so pushing them off the ledge is the way to get rid of them.
var a
var t := 0.0
var done := false
var fails := 0
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6 or done: return false
	done = true
	for c in a.combatants: c.hold = true
	var maw = a.enemies[0]
	print("round: ", maw.display_name, " lethal sides ", a.arena.lethal_sides)
	a._summon(maw)
	var sprites: Array = maw.get_meta("summons", [])
	check(sprites.size() > 0, "Gust Sprites summoned (%d)" % sprites.size())
	var s = sprites[0]
	var hp0: int = s.hp
	s.take_damage(100, false)
	check(hp0 - s.hp == 20, "takes 20%% damage (100 -> %d)" % (hp0 - s.hp))
	var mg = a.party[0]
	a._set_controlled(mg)
	var gust; var fire
	for m in Moves.attacks("mage"):
		if m["name"] == "Gust": gust = m
		if m["name"] == "Fire": fire = m
	check(a._move_answer(gust, s)[0] == "PUSHES", "Gust is tagged PUSHES (%s)" % [a._move_answer(gust, s)[0]])
	check(a._move_answer(fire, s)[0] == "TOUGH", "Fire is tagged TOUGH")
	# pushed 1.5x as far
	s.global_position = Vector3(0, s.global_position.y, 0)
	a._knock_away(s, Vector3(0, 0, 1), 2.0)
	check(absf(s.global_position.z + 3.0) < 0.2, "a 2 m push moves it 3 m (%.1f)" % -s.global_position.z)
	# off the ledge
	var side: int = a.arena.lethal_sides
	var b: Array = a.arena._bounds()
	var edge := Vector3.ZERO; var out := Vector3.ZERO
	if side & 1: edge = Vector3(0, 0, b[2] + 1.0); out = Vector3(0, 0, -1)
	elif side & 2: edge = Vector3(b[1] - 1.0, 0, 0); out = Vector3(1, 0, 0)
	elif side & 4: edge = Vector3(0, 0, b[3] - 1.0); out = Vector3(0, 0, 1)
	elif side & 8: edge = Vector3(b[0] + 1.0, 0, 0); out = Vector3(-1, 0, 0)
	check(side != 0, "the Maw's arena has a ledge")
	s.global_position = Vector3(edge.x, s.global_position.y, edge.z)
	a._knock_away(s, s.global_position - out, 3.0)
	check(s.is_down and s.get_meta("fell", false), "pushed off the ledge: gone")
	# not figured out yet: the push recipe is spelled out
	ArtsBook.reset()  # (the test machine's Arts book)
	a._summon(maw)  # the first one fell: a new one
	a._set_controlled(a.party[1])  # the Knight: Smash / Crusader's Edge are Arts
	a._update_arts_list()
	print("urgent: ", a.battle_menu.arts_urgent)
	check(a.battle_menu.arts_urgent.contains("PUSH IT OFF") and a.battle_menu.arts_urgent.contains(" + "), "a Gust Sprite is up and the Knight knows no push: the recipe is spelled out")
	ArtsBook.discover("knight", "Smash")
	a._update_arts_list()
	check(a.battle_menu.arts_urgent == "", "once a push is known, the box goes")
	# Mage has Gust as a basic move: never needs the hint
	check(a._push_recipe(a.party[0]) == "", "the Mage has Gust: no hint needed")
	# every class has a way to push
	for c in ["knight", "archer", "mage", "assassin", "cleric", "monk"]:
		var pushers := []
		for m in Moves.attacks(c) + Moves.arts(c) + Moves.skills(c):
			if float(m.get("knockback", 0.0)) > 0.0: pushers.append(m["name"])
		check(not pushers.is_empty(), "%s can push: %s" % [c, pushers])
	print("FAILS: %d" % fails)
	quit()
	return true
