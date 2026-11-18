extends SceneTree
# Change Keys in the pause menu (Esc): the same rebinding as on the title
# screen. A row waits for a key, takes it, Esc keeps the old one, Reset puts
# every key back. SHOT=file saves a picture of the page.
var a
var t := 0.0
var step := 0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	Keybinds.reset_defaults()
	BattleArena._round_index = 1
	BattleArena.chosen_for_round = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e
func _process(d) -> bool:
	t += d
	if t < 1.0 + step * 0.3: return false
	var pm: PauseMenu = a.pause_menu
	match step:
		0:
			for c in a.combatants: c.hold = true
			pm.open()
			pm.index = pm.items().find("Change Keys")
			check(pm.index >= 0, "Change Keys is in the pause menu")
			pm._select()
			check(pm.in_keys and pm.items().size() == Keybinds.ACTIONS.size() + 2, "it lists every action, Reset and Back")
			var panel := pm._panel()
			check(panel.position.y >= 0.0 and panel.end.y <= pm.size.y, "the page fits the screen (%s in %s)" % [panel, pm.size])
		1:
			var row := -1
			for i in Keybinds.ACTIONS.size():
				if Keybinds.ACTIONS[i][0] == "parry":
					row = i
			pm.index = row
			pm._select()
			check(pm._capturing == row, "choosing a row waits for a key")
			pm._capture_key(key(KEY_ESCAPE))
			check(pm._capturing == -1 and Keybinds.main_key("parry") != KEY_ESCAPE, "Esc keeps the old key")
			pm._select()
			pm._capture_key(key(KEY_G))
			check(Keybinds.main_key("parry") == KEY_G, "the new key is taken (%s)" % Keybinds.label("parry"))
			if OS.get_environment("SHOT") != "":
				root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
		2:
			pm.index = pm.items().find(PauseMenu.RESET_KEYS)
			pm._select()
			check(Keybinds.main_key("parry") != KEY_G, "Reset puts the keys back")
			pm.index = pm.items().find(PauseMenu.OPTIONS_BACK)
			pm._select()
			check(not pm.in_keys and pm.items()[pm.index] == "Change Keys", "Back: to the pause menu, on Change Keys")
			pm.close()
			print("FAILS: ", fails)
			quit()
			return true
	step += 1
	return false
