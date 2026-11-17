extends SceneTree
# Screenshots: the Items list on the Knight's turn (Archer hurt, Mage down)
# and the pouch under the AP bar. OUT = folder.
var a
var t := 0.0
var step := 0
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.windup_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func shot(n):
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _process(d):
	t += d
	match step:
		0:
			if t < 1.0: return false
			for c in a.combatants: c.hold = true
			var kn = a.party[0]
			var ar = a.party[1]
			var mg = a.party[2]
			ar.hp = 60
			mg.hp = 0; mg._go_down()
			a.pouch["Potion"] = 2
			a._set_controlled(kn); a.active = kn; a._command_phase = false; a._skill_used = false
			a._open_commands()
			a.battle_menu.command_index = 3
			step = 1; t = 0
		1:
			if t < 0.4: return false
			shot("items_commands")
			a._open_items()
			step = 2; t = 0
		2:
			if t < 0.4: return false
			shot("items_list")
			quit()
			return true
	return false
