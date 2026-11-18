extends SceneTree
# The Options menu: the screen filter (Normal / Light / Off) and the play
# settings, on the title screen and in the pause menu (Esc). The filter
# applies at once and is remembered. SHOTS=folder saves the three looks.
var a
var t := 0.0
var step := 0
var fails := 0
var before := ""
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	before = Settings.screen_filter()
	Settings.set_screen_filter("normal")
	BattleArena._round_index = 1
	BattleArena.chosen_for_round = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func shot(n):
	if OS.get_environment("SHOTS") != "":
		root.get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/filter_%s.png" % n)
func _process(d):
	t += d
	if t < 1.0 + step * 0.4: return false
	var pm: PauseMenu = a.pause_menu
	match step:
		0:
			for c in a.combatants: c.hold = true
			check(a.retro_screen.visible, "Normal: the filter is on")
			check(Figure._materials.values()[0].get_shader_parameter("snap_lines") == 320.0, "Normal: the full wobble")
			shot("normal")
			pm.open()
			check(pm.items() == ["Resume", "Command List", "Options", "Change Keys", "Restart fight", "Quit to title"], "pause menu: the play settings moved to Options, keys there too")
			pm.index = pm.items().find("Options")
			pm._select()
			check(pm.in_options and pm.items()[0] == "Screen filter: Normal", "Options opens, the filter first")
			check(pm.items().size() == 11 and pm.items()[10] == "Back", "with Move details, Command timing, Party AI, Master, Music, Sounds, camera speed, mouse, invert, Back")
			pm.index = 0
			pm._select()
			check(Settings.screen_filter() == "light" and pm.items()[0] == "Screen filter: Light", "it changes to Light")
			pm.close()
		1:
			var mat: ShaderMaterial = a.retro_screen.material
			check(a.retro_screen.visible and mat.get_shader_parameter("smooth_pixels") == true and mat.get_shader_parameter("lines") == 540.0, "Light: finer, smooth pixels, at once")
			check(Figure._materials.values()[0].get_shader_parameter("snap_lines") == 720.0, "Light: a gentle wobble")
			shot("light")
			pm.open(); pm.index = 2; pm._select(); pm.index = 0; pm._select()
			check(Settings.screen_filter() == "off", "then Off")
			pm.index = pm.items().size() - 1
			pm._select()
			check(not pm.in_options and pm.items()[pm.index] == "Options", "Back: to the pause menu, on Options")
			pm.close()
		2:
			check(not a.retro_screen.visible, "Off: no filter")
			check(Figure._materials.values()[0].get_shader_parameter("snap_lines") == 0.0, "Off: no wobble")
			shot("off")
			var f := ConfigFile.new()
			f.load(Settings.PATH)
			check(f.get_value("video", "screen_filter", "") == "off", "remembered in settings.cfg")
			# the title screen's Options page
			var m = load("res://scenes/ui/title_menu.tscn").instantiate()
			root.add_child(m)
			check(m._main_items().has("Options"), "the title menu has Options")
			m.index = m._main_items().find("Options")
			m._select()
			check(m.page == m.Page.OPTIONS and m._items()[0] == "Screen filter: Off", "title Options: same page")
			m.index = 0
			m._select()
			check(Settings.screen_filter() == "normal", "Off -> Normal from the title screen")
			m.index = m._items().size() - 1
			m._select()
			check(m.page == m.Page.MAIN and m._main_items()[m.index] == "Options", "Back: to the title menu, on Options")
			m.queue_free()
			Settings.set_screen_filter(before)
			print("FAILS: %d" % fails)
			quit()
			return true
	step += 1
	return false
