extends SceneTree
# First Boss Rush / Round Select: the Play style page asks once (Command
# timing, Party AI), saves both, then carries on to what was chosen.
var m
var t := 0.0
var step := 0
var fails := 0
var shot := OS.get_environment("SHOT")
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	Settings.set_style_chosen(false)
	Settings.set_command_windup(true)
	Settings.set_party_ai(false)
	change_scene_to_file("res://scenes/ui/title_menu.tscn")
func _process(d):
	t += d
	match step:
		0:
			if t < 0.6: return false
			m = current_scene
			m.index = m._main_items().find("Round Select")
			m._select()
			check(m.page == m.Page.STYLE and m._style_then == "Round Select", "first Round Select: the Play style page opens")
			m._style_row = 1
			m._style_pick()  # Party AI: Off -> On
			check(m._style_ai, "Party AI flips to On")
			if shot != "":
				step = 1; t = 0
				return false
			step = 2
		1:
			if t > 0.4:
				root.get_texture().get_image().save_png(shot)
				step = 2
		2:
			m._style_row = 2
			m._style_pick()
			check(Settings.style_chosen() and Settings.party_ai() and Settings.command_windup(), "Start: both saved, asked once")
			check(m.page == m.Page.ROUNDS, "then on to the round list")
			m.page = m.Page.MAIN
			m.index = m._main_items().find("Round Select")
			m._select()
			check(m.page == m.Page.ROUNDS, "second time: straight to the list, no question")
			Settings.set_style_chosen(false)
			Settings.set_party_ai(false)
			print("FAILS: %d" % fails)
			return true
	return false
