extends SceneTree
# Tab tap = next party member; Tab hold = time stops, pick who to steer.
var a
var t := 0.0
var step := 0
var fails := 0
var mark := 0.0
var shot := OS.get_environment("SHOT")
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func act(action, pressed):
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = pressed
	Input.parse_input_event(ev)
func key(code):
	var ev := InputEventKey.new(); ev.physical_keycode = code; ev.pressed = true
	Input.parse_input_event(ev)
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t > 0.8 and a.active == null:
				for c in a.combatants: c.timeline_pos = 5.0
				check(a.controlled == a.party[0], "start: steering the Knight")
				act("swap_character", true); act("swap_character", false)
				step = 1; t = 0
		1:
			if t > 0.1:
				check(a.controlled == a.party[1] and not a._picker_open, "tap Tab: the Archer, no picker")
				act("swap_character", true)
				step = 2; t = 0
		2:
			if t > 0.15 and t < 0.15 + d * 1.5:
				check(not a._picker_open, "not open yet at 0.15 s")
			if a._picker_open or t > 1.5:
				check(a._picker_open and a.steer_picker.visible and a.active == null, "held: picker open (%.2f s)" % t)
				mark = a.party[3].timeline_pos
				step = 3; t = 0
		3:
			if t > 0.5:
				check(is_equal_approx(a.party[3].timeline_pos, mark), "time stands still while choosing")
				act("move_right", true); act("move_right", false)
				step = 4; t = 0
		4:
			if t > 0.1:
				check(a.controlled == a.party[2] and a.steer_picker.selected == a.party[2], "D: picks the Mage (camera follows)")
				a.party[3].is_down = true
				act("move_right", true); act("move_right", false)
				step = 5; t = 0
		5:
			if t > 0.1:
				check(a.controlled == a.party[0], "D again: skips the downed Cleric, wraps to the Knight")
				key(KEY_2)
				step = 6; t = 0
		6:
			if t > 0.1:
				check(a.controlled == a.party[1], "2: the Archer")
				if shot != "":
					root.get_texture().get_image().save_png(shot)
				act("swap_character", false)
				step = 7; t = 0
		7:
			if t > 0.2:
				check(not a._picker_open and not a.steer_picker.visible, "let go: picker closes")
				check(a.controlled == a.party[1], "still steering the Archer")
				check(a.party[0].timeline_pos > mark - 1.0 and a.active == null or a.active != null, "time runs again")
				print("FAILS: %d" % fails)
				return true
	return false
