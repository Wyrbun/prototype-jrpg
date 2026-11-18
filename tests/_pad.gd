extends SceneTree
# Gamepad (Xbox layout): every action has its pad button, the hints name
# pad buttons while the pad is in use, the left stick walks and also moves
# menu cursors one step per push, pad buttons drive the menus, and pad
# buttons can be rebound (with a swap) and reset.
var a
var t := 0.0
var step := 0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func button(index: int, pressed := true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(e)
func stick(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
func key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
func _initialize():
	Keybinds.reset_defaults()
	BattleArena._round_index = 1
	BattleArena.chosen_for_round = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d) -> bool:
	t += d
	if t < 1.0 + step * 0.25: return false
	var pm: PauseMenu = a.pause_menu
	match step:
		0:
			for c in a.combatants: c.hold = true
			check(Keybinds.main_pad("confirm") == JOY_BUTTON_A and Keybinds.main_pad("cancel") == JOY_BUTTON_B, "A confirms, B goes back")
			check(Keybinds.main_pad("menu") == JOY_BUTTON_START, "Menu (Start) pauses")
			check(Keybinds.pad_label("parry") == "RB" and Keybinds.pad_label("defend") == "LB", "RB parries, LB defends")
			check(Keybinds.pad_label("camera_left") == "RS left", "the right stick turns the camera")
			check(not Pad.active and Keybinds.label("confirm") == Keybinds.key_label("confirm"), "keyboard first: hints name keys")
			button(JOY_BUTTON_A)
			button(JOY_BUTTON_A, false)
		1:
			check(Pad.active, "a pad press switches the hints to the pad")
			check(Keybinds.label("confirm") == "A", "{confirm} is A")
			var hint := Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: select     Esc / {cancel}: back")
			check(hint == "Up / Down: choose     A: select     Menu / B: back", "a menu hint, for the pad: " + hint)
			check(Keybinds.fill("{move}: move") == "Left stick: move", "{move} is the left stick")
			stick(JOY_AXIS_LEFT_Y, -0.9)
		2:
			var walk := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			check(walk.y < -0.5, "the left stick walks (%s)" % walk)
			stick(JOY_AXIS_LEFT_Y, 0.0)
			button(JOY_BUTTON_START)
			button(JOY_BUTTON_START, false)
		3:
			check(pm.visible, "Menu opens the pause menu")
			pm.index = 0
			stick(JOY_AXIS_LEFT_Y, 0.9)
		4:
			stick(JOY_AXIS_LEFT_Y, 0.95)  # still held
		5:
			check(pm.index == 1, "a push down moves the cursor once (index %d)" % pm.index)
			stick(JOY_AXIS_LEFT_Y, 0.1)
		6:
			stick(JOY_AXIS_LEFT_Y, 0.9)
		7:
			stick(JOY_AXIS_LEFT_Y, 0.0)
			check(pm.index == 2, "let go and push again: one more (index %d)" % pm.index)
			button(JOY_BUTTON_DPAD_DOWN)
			button(JOY_BUTTON_DPAD_DOWN, false)
		8:
			check(pm.index == 3 and pm.items()[3] == "Change Keys", "the D-pad moves it too")
			button(JOY_BUTTON_A)
			button(JOY_BUTTON_A, false)
		9:
			check(pm.in_keys, "A opens Change Keys")
			var row := -1
			for i in Keybinds.ACTIONS.size():
				if Keybinds.ACTIONS[i][0] == "parry":
					row = i
			pm.index = row
			pm._select()
			button(JOY_BUTTON_X)
			button(JOY_BUTTON_X, false)
		10:
			check(Keybinds.main_pad("parry") == JOY_BUTTON_X, "a pad button rebinds Parry (%s)" % Keybinds.pad_label("parry"))
			check(Keybinds.main_pad("end_turn") == JOY_BUTTON_RIGHT_SHOULDER, "Begin takes Parry's old RB (a swap)")
			pm.index = pm.items().find(PauseMenu.RESET_KEYS)
			pm._select()
			check(Keybinds.main_pad("parry") == JOY_BUTTON_RIGHT_SHOULDER and Keybinds.main_pad("end_turn") == JOY_BUTTON_X, "Reset puts the pad back too")
			button(JOY_BUTTON_B)
			button(JOY_BUTTON_B, false)
		11:
			check(not pm.in_keys and pm.visible, "B goes back")
			button(JOY_BUTTON_B)
			button(JOY_BUTTON_B, false)
		12:
			check(not pm.visible, "B again resumes")
			key(KEY_W)
		13:
			check(not Pad.active and Keybinds.label("confirm") == Keybinds.key_label("confirm"), "a key switches the hints back")
			print("FAILS: ", fails)
			quit()
			return true
	step += 1
	return false
