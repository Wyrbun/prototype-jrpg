extends SceneTree
# The fight's opening text stays up (own slot) through turns and other messages.
var a
var t := 0.0
var fails := 0
var step := 0
var shot := OS.get_environment("SHOT")
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.5: return false
			check(a._intro_message.contains("Gale Maw never moves") and a._intro_left >= 15.0, "Gale Maw: title + tip, %.0f s to read" % a._intro_left)
			a._flash("A rock crashes down! Hide behind it")
			a._flash_time_left = 0.0  # a new turn clears flashes
			step = 1; t = 0
		1:
			if t < 0.3: return false
			check(a.warning_label.text.begins_with(a._intro_message.split("\n")[0]), "still shown after other messages and a turn")
			if shot != "": root.get_texture().get_image().save_png(shot)
			a._intro_left = 0.01
			step = 2; t = 0
		2:
			if t < 0.3: return false
			check(not a.warning_label.text.contains("Gale Maw never moves"), "gone when its time is up")
			print("FAILS: %d" % fails)
			return true
	return false
