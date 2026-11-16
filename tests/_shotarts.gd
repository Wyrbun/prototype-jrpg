extends SceneTree
# Screenshot: the Mage's Arts list (19 Arts) in the combo bar. KNOWN=all|few.
var a
var t := 0.0
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 1.0: return false
	if t < 1.1:
		ArtsBook.reset()
		var all = Moves.arts("mage")
		var n = all.size() if OS.get_environment("KNOWN") == "all" else 3
		for i in n: ArtsBook.discover("mage", all[i]["name"])
		for c in a.combatants: c.hold = true
		var mg = a.party.filter(func(p): return p.class_id == "mage")[0]
		var g = a.enemies[0]
		mg.global_position = g.global_position + Vector3(0, 0, g.body_radius + 2.0)
		a._set_controlled(mg); a.active = mg; a.current_max_ap = 200; a.ap = 200; a._command_phase = false
		a._open_combo_bar(g)
		for nm in ["Ice", "Fire"]:
			for i in a._moves.size():
				if a._moves[i]["name"] == nm: a._add_to_combo(i)
		return false
	if t < 1.6: return false
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	return true
