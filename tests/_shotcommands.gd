extends SceneTree
# Screenshots + checks: Pause > Command List. Opens it, picks a member and a
# move, and saves the screen with the preview mid-loop. OUT=folder.
# Run with --fixed-fps 60.
var a
var t := 0.0
var step := 0
var cl: CommandList
var fails := 0
var shots := [["mage", "Fire", 1.25], ["knight", "Slash", 0.6], ["cleric", "Healing", 0.35], ["archer", "Shoot", 0.5]]
var si := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func pick(cls, move_name):
	for i in cl.members.size():
		if cl.members[i].class_id == cls:
			cl.member_index = i
	cl._fill_rows()
	for k in cl.rows.size():
		if cl.rows[k].has("move") and cl.rows[k]["move"]["name"] == move_name:
			cl.index = k
	cl._play_selected()
func _process(d):
	t += d
	a._intro_left = 0.0
	if t < 0.8: return false
	match step:
		0:
			a.pause_menu.party = a.party.duplicate()
			a.pause_menu.open()
			a.pause_menu.index = a.pause_menu.items().find("Command List")
			a.pause_menu._select()
			cl = a.pause_menu.command_list
			check(paused and cl.visible and not a.pause_menu.visible, "Pause > Command List opens it; the fight stays paused")
			check(cl.rows.filter(func(r): return r.has("header")).size() == 3, "Attacks, Arts, Abilities sections")
			step = 1; t = 0.8
		1:
			if si >= shots.size() and step != 9:
				# Practice: Knight Slash.
				pick("knight", "Slash")
				var j = InputEventAction.new(); j.action = "confirm"; j.pressed = true
				cl._unhandled_input(j)
				check(cl.practice and cl._loop_t < 0.0, "J on an attack: practice, with a lead-in")
				var e = cl._entry
				var hit_t = float(e["duration"]) * float(e["times"][0])
				cl._loop_t = hit_t - cl._window() * 2.0
				cl._practice_press()
				check(int(cl._res[0]) == 2, "pressed before the box: too early")
				cl._new_practice_round()
				cl._loop_t = hit_t - cl._window() * 0.5
				cl._practice_press()
				check(int(cl._res[0]) == 1, "pressed in the box: Perfect")
				cl._loop_t = float(e["duration"]) + 0.99
				cl._tick_preview(0.02)
				check(cl._rounds == 1 and cl._perfect_rounds == 1 and cl._loop_t < 0.0, "round counted (%d/%d), next round starts" % [cl._perfect_rounds, cl._rounds])
				# The Mage's code.
				pick("mage", "Fire")
				cl._unhandled_input(j)
				e = cl._entry
				cl._loop_t = float(e["duration"]) * 0.4
				var w = InputEventAction.new(); w.action = "move_back"; w.pressed = true
				cl._unhandled_input(w)
				check(cl._code_i == 0 and cl.practice, "practice: S is a code arrow (wrong: start over), not the list")
				var up = InputEventAction.new(); up.action = "move_forward"; up.pressed = true
				cl._unhandled_input(up)
				check(int(cl._res[(e["hits"] as Array).size() - 1]) == 1, "W: Fire's code done, Perfect")
				var esc = InputEventAction.new(); esc.action = "cancel"; esc.pressed = true
				cl._unhandled_input(esc)
				check(not cl.practice and cl.visible, "Esc stops practising, the list stays")
				# Counter drill: Tab toggles it; a caught hit's swing must be pressed on time.
				var tab = InputEventAction.new(); tab.action = "swap_character"; tab.pressed = true
				cl._unhandled_input(tab)
				check(cl.counter_drill, "Tab: Counter drill on")
				pick("knight", "Slash")
				cl._unhandled_input(j)
				cl._stance = true
				var e2 = cl._entry
				cl._loop_t = float(e2["duration"]) * float(e2["times"][0]) + 0.001
				cl._fired["a0"] = true
				cl._tick_preview(0.0)
				check(cl._counter_left > 0.0 and cl._counters == 1, "a hit on a Counter stance: caught, its swing coming")
				var frozen = cl._loop_t
				cl._tick_preview(0.2)
				check(cl._loop_t == frozen, "the playhead waits for the swing")
				cl._counter_left = 0.05
				cl._practice_press()
				check(cl._counters_broken == 1 and not cl._stance and cl._counter_recover > 0.0, "pressed as it lands: COUNTER BROKEN")
				cl._new_practice_round()
				cl._stance = true
				cl._loop_t = float(e2["duration"]) * float(e2["times"][0]) + 0.001
				cl._fired.clear(); cl._fired["a0"] = true
				cl._tick_preview(0.0)
				cl._practice_press()  # far too early
				check(cl._round_failed and cl._counters_broken == 1, "pressed too early: countered, the round ends")
				cl._unhandled_input(esc)
				# A practice screenshot.
				pick("knight", "Slash")
				cl._unhandled_input(j)
				step = 9; t = 0.0
				return false
			if step == 9:
				return false
			if si >= shots.size():
				var ev = InputEventAction.new(); ev.action = "cancel"; ev.pressed = true
				cl._unhandled_input(ev)
				check(not cl.visible and a.pause_menu.visible and paused, "back: the pause menu again, still paused")
				print("FAILS: %d" % fails)
				return true
			pick(shots[si][0], shots[si][1])
			check(cl.rows[cl.index]["move"]["name"] == shots[si][1], "%s: %s selected" % shots[si].slice(0, 2))
			step = 2; t = 0.0
		9:
			if not cl._stance and t < 0.5:
				cl._stance = true  # this round: a Counter stance
				cl._tint_target()
			if t >= 1.0 + 0.62 and t < 1.0 + 0.64:
				cl._practice_press()
			if t >= 1.0 + 0.667 + 0.35:
				root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/commands_practice.png")
				print("saved practice")
				var esc2 = InputEventAction.new(); esc2.action = "cancel"; esc2.pressed = true
				cl._unhandled_input(esc2)
				cl._unhandled_input(esc2)
				check(not cl.visible and a.pause_menu.visible and paused, "back: the pause menu again, still paused")
				print("FAILS: %d" % fails)
				return true
		2:
			if t >= float(shots[si][2]):
				root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/commands_%s.png" % shots[si][0])
				print("saved ", shots[si][0])
				si += 1
				step = 1
	return false
