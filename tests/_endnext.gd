extends SceneTree
# End panel choices made with the keyboard load the next scene cleanly:
# Next round after a Round 8 win opens Round 9 (its party picker). It used
# to stop on a script error (the battle had already left the tree when it
# marked the key press as used), which froze the game on a grey screen.
var a
var t := 0.0
var step := 0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	current_scene = a
func _process(d):
	t += d
	match step:
		0:
			if t < 0.6: return false
			var g = a.enemies[0]
			g.hp = 0; g._go_down(); a._check_enemies()
			step = 1; t = 0
		1:
			if a.end_screen == null: return false
			check(a.end_screen.choices()[0][0] == "next", "Next round is selected")
			var ev = InputEventAction.new(); ev.action = "confirm"; ev.pressed = true
			Input.parse_input_event(ev)
			step = 2; t = 0
		2:
			if t < 2.0: return false
			check(current_scene != a and BattleArena._round_index == 8, "the next round loaded (Round 9)")
			check(current_scene.get_node("UI").get_children().any(func(c): return c is PartyPicker), "with its party picker")
			print("FAILS: %d" % fails)
			quit()
			return true
	return false
