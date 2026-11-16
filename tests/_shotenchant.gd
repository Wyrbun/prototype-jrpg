extends SceneTree
# Screenshot: the Mage's Enchant element menu (four directions).
var a
var t := 0.0
var done := false
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 1.0: return false
	if not done:
		done = true
		for c in a.combatants: c.hold = true
		var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
		a._set_controlled(mg); a.active = mg; a._command_phase = false; a.ap = 100.0
		a._open_skills()
		a._choose_skill(a._skills.map(func(x): return x["name"]).find("Enchant"))
	a._intro_left = 0.0
	if t < 1.5: return false
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	return true
