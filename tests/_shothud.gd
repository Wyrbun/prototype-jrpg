extends SceneTree
# HUD screenshots: command menu, combo bar with Arts and details, tutorial box.
var a
var t := 0.0
var step := 0
const D := "/tmp/claude-0/-home-claude/05b81194-2749-584d-a628-b8b7ec5f1f2b/scratchpad/"
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func snap(n): root.get_texture().get_image().save_png(D + n)
func _process(d):
	t += d
	if step == 0 and t > 0.8:
		for n in ["Double Slash", "Lunge", "Shield Rush", "Smash"]: ArtsBook.discover("knight", n)
		for c in a.combatants: c.hold = true
		var k = a.party[0]; var g = a.enemies[0]
		a.party[1].hp = 60; a.party[2].recoverable = 20; a.party[2].hp = 70
		k.timeline_pos = 69.9; k.hold = false
		step = 1; t = 0
	elif step == 1 and a.active != null and a._turn_intro_left <= 0.0 and t > 0.6:
		snap("hud_menu.png")
		var k = a.party[0]; var g = a.enemies[0]
		k.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.2)
		a._command_phase = false
		a.ap = 150; a.current_max_ap = 200
		a._open_combo_bar(g)
		a._add_to_combo(0); a._add_to_combo(0)
		var tab := InputEventAction.new(); tab.action = "swap_character"; tab.pressed = true
		a._menu_input(tab)
		step = 2; t = 0
	elif step == 2 and t > 0.5:
		snap("hud_combo.png"); return true
	return false
