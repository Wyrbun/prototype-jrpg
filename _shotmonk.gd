extends SceneTree
# Monk's build bar (with his climb steps) next to the party HP list.
var a
var t := 0.0
var step := 0
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/monk.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if step == 0 and t > 0.8:
		for c in a.combatants: c.hold = true
		var m = a.party[0]; var g = a.enemies[0]
		m.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.0)
		a._set_controlled(m); a.active = m; a.ap = 170; a.current_max_ap = 215
		a._command_phase = false
		a._open_combo_bar(g); a._add_to_combo(0); a._add_to_combo(0)
		step = 1; t = 0
	elif step == 1 and t > 0.5:
		root.get_texture().get_image().save_png("/tmp/claude-0/-home-claude/05b81194-2749-584d-a628-b8b7ec5f1f2b/scratchpad/monkbar.png"); return true
	return false
