extends SceneTree
# Strike rings: only fighters who can Parry the strike get the shrinking
# timing ring; the rest get a plain mark (blue: Defend works, red: nothing).
var a
var t := 0.0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(e, nm):
	for s in e.skills:
		if s.skill_name == nm: return s
func mods(list):
	var m := {}
	for c in list: m[c] = {"mult": 1.0, "unblockable": false, "one_hp": false}
	return m
func _process(d):
	t += d
	if t < 0.8: return false
	var g = a.enemies[0]
	var k = a.party[0]; var ar = a.party[1]; var cl = a.party[2]
	for c in a.combatants: c.hold = true
	g.loaded_def = skill(g, "Heavy Attack"); g.loaded_skill = g.loaded_def.kind
	a._begin_strike(g, mods([k, ar, cl]), false)
	var s = a._strike
	check(s.rings.size() == 1 and s.rings[0].get_parent() == k, "Heavy Attack: only the Knight gets a Parry ring")
	var colors := {}
	for m in s.markers:
		colors[m.get_parent()] = (m.material_override as StandardMaterial3D).albedo_color
	check(colors.has(ar) and colors[ar].r > 0.9, "  the Archer (no Parry, no Block): a red mark")
	check(colors.has(cl) and colors[cl].b > 0.9, "  the Cleric (Block only): a blue mark")
	a._resolve_strike()
	g.loaded_def = skill(g, "Right Golem Smash"); g.loaded_skill = g.loaded_def.kind
	a._begin_strike(g, mods([k]), false)
	check(a._strike.rings.is_empty(), "Golem Smash (can't be parried): no ring, even on the Knight")
	a._resolve_strike()
	print("FAILS: %d" % fails)
	return true
