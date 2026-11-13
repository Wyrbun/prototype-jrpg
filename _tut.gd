extends SceneTree
# Plays the tutorial like a player would: reads notes (J), then does each goal.
var a
var tut
var t := 0.0
var frames := 0
var last_index := -1
var step_time := 0.0
var q: Array = []
var qt := 0.0
var log_lines: Array = []
var backed_out := false
func _initialize():
	ArtsBook.reset()
	BattleArena.tutorial_mode = true
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func press(action):
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new(); up.action = action; up.pressed = false
	Input.parse_input_event(up)
func release_moves():
	for x in ["move_left", "move_right", "move_forward", "move_back"]: Input.action_release(x)
func walk_to(c, target: Vector3, stop := 0.3):
	release_moves()
	var to = target - c.global_position; to.y = 0
	if to.length() < stop: return true
	to = a.arena.steer(c.global_position, to, c.body_radius)
	if to.x < -0.3: Input.action_press("move_left")
	if to.x > 0.3: Input.action_press("move_right")
	if to.z < -0.3: Input.action_press("move_forward")
	if to.z > 0.3: Input.action_press("move_back")
	return false
func member(id):
	for m in a.party:
		if m.class_id == id: return m
func pick_command(i): a.battle_menu.command_index = i; press("confirm")
func pick_move(name):
	for i in a._moves.size():
		if a._moves[i]["name"] == name: a.battle_menu.move_index = i; press("confirm"); return
func pick_skill(name):
	for i in a._skills.size():
		if a._skills[i]["name"] == name: a.battle_menu.move_index = i; press("confirm"); return
func _process(d):
	t += d; frames += 1; step_time += d
	if tut == null: tut = a.tutorial
	if tut == null or frames < 5: return false
	if tut.index != last_index:
		last_index = tut.index; step_time = 0.0
		if tut.index < tut.steps.size():
			var s = tut.steps[tut.index]
			log_lines.append("[%5.1fs] step %d %s | goal: %s" % [t, tut.index, s["lesson"], s["goal"]])
			print(log_lines[-1])
	if tut.index >= tut.steps.size() or a._game_over:
		print("END: index %d/%d game_over=%s result=%s t=%.0fs" % [tut.index, tut.steps.size(), a._game_over, a._result_text, t]); return true
	if frames > 60 * 60 * 24:
		print("TIMEOUT at step ", tut.index, " ", tut.steps[tut.index]["goal"]); return true
	var s = tut.steps[tut.index]
	if step_time > (400 if s["goal"].begins_with("Defeat") else 90):
		var gg = a.enemies[0]; print("STUCK at step ", tut.index, " ", s["goal"], " stats=", a.stats, " golem hp=", gg.hp, " loaded=", gg.loaded_skill, " stance=", gg.stance, " pos=", gg.timeline_pos, " hold=", gg.hold, " active=", a.active, " menu=", a._menu_mode, " strike=", a._strike, " knight=", member("knight").global_position, " ctrl=", a.controlled.display_name, " forced=", gg.forced_skill.skill_name if gg.forced_skill else "none",); return true
	# notes
	if s["goal"] == "":
		release_moves()
		if step_time > 0.3: press("confirm"); step_time = -10.0
		return false
	var g: String = s["goal"]
	var k = member("knight")
	var golem = a.enemies[0]
	# strike reactions
	if a._strike != null:
		release_moves()
		if g.begins_with("Parry") or g.begins_with("Raise max"):
			if a._strike.time_left < 0.15 and a._strike.reaction == 0: press("parry")
		elif g.begins_with("Defend"):
			if a._strike.reaction == 0: press("defend")
		return false
	# party turn handling
	if a._party_turn():
		release_moves()
		if g.begins_with("Attack with the Mage") and fmod(step_time, 1.0) < d: print("  turn ", a.active.display_name, " menu ", a._menu_mode, " cmd_enabled ", a.battle_menu.command_enabled, " gap ", a.active.gap_to(golem), " plan ", a._plan.size(), " ap ", a.ap)
		qt += d
		if qt < 0.15: return false
		qt = 0.0
		var who = a.active
		match a._menu_mode:
			BattleMenu.Mode.COMMANDS:
				var assassin_goal = g.begins_with("Hit the Golem from behind") or g.begins_with("Use Shadowstep") or g.begins_with("Put 4") or g.begins_with("Use Execute") or g.begins_with("Auto-parry")
				if assassin_goal and (who.class_id != "assassin" or g.begins_with("Auto-parry")): pick_command(2)
				elif assassin_goal and g.begins_with("Put 4"): pick_command(1 if a.battle_menu.command_enabled[1] else 2)
				elif assassin_goal: pick_command(0) if a.battle_menu.command_enabled[0] else pick_command(2)
				elif g.begins_with("Choose Wait") : pick_command(2)
				elif not a.battle_menu.command_enabled[1] and (g.begins_with("Use an Ability") or g.begins_with("Use one of the Cleric")): pick_command(2)
				elif g.begins_with("Use an Ability") and who.class_id == "knight": pick_command(1)
				elif g.begins_with("Use one of the Cleric") and who.class_id == "cleric": pick_command(1)
				elif g.begins_with("Use an Ability") and who.class_id != "knight": pick_command(1)
				elif g.begins_with("Attack with the Mage") and who.class_id != "mage": pick_command(2)
				elif a.battle_menu.command_enabled[0] and not backed_out: pick_command(0)
				else: pick_command(2)
			BattleMenu.Mode.COMBO:
				if who.class_id == "monk":
					var want = ["Heavy Punch", "Heavy Kick", "Headbutt"] if g.begins_with("Cash out") else ["Kick", "Heavy Kick"]
					if a.battle_menu.combo.size() < want.size(): pick_move(want[a.battle_menu.combo.size()])
					else: press("end_turn")
				elif a._plan.is_empty():
					if who.class_id == "assassin":
						var want = "Stab"
						if g.begins_with("Use Shadowstep"): want = "Shadowstep"
						elif g.begins_with("Use Execute"): want = "Execute"
						var idx = a._moves.map(func(m): return m["name"]).find(want)
						if idx >= 0 and a.battle_menu.move_usable[idx]: pick_move(want)
						else: press("cancel"); backed_out = true
					elif g.begins_with("Add an Art from the list"):
						if not a.battle_menu.arts_focus: press("swap_character")
						else: press("confirm")
					elif g.begins_with("Hit through"): pick_move("Thrust")
					elif who.class_id == "knight": pick_move("Slash")
					else:
						var found = false
						for i in a._moves.size():
							if a.battle_menu.move_usable[i] and a._moves[i]["cost"] <= a.ap: a.battle_menu.move_index = i; press("confirm"); found = true; break
						if not found: press("cancel"); backed_out = true
				elif g.begins_with("Play Slash + Slash") and a.battle_menu.combo.size() < 2: pick_move("Slash")
				else:
					if a.battle_menu.arts_focus: press("swap_character")
					press("end_turn")
			BattleMenu.Mode.EXECUTING:
				# aim for perfects: press when inside the next box
				var e = a._plan[a._exec_slot]; var h = a._exec_hits_done
				if h < e["times"].size() and a._exec_lead_in <= 0:
					var ht = e["duration"] * e["times"][h]
					if a._exec_time >= ht - e["window"] * e["duration"] * 0.6 and a._exec_timings[h] == 0: press("confirm")
			BattleMenu.Mode.SKILLS:
				if who.class_id == "assassin": pick_skill("Death Sentence")
				elif who.class_id == "cleric": pick_skill("Healing")
				elif who.class_id == "knight": pick_skill("Brace")
				else:
					a.battle_menu.move_index = 0
					for i in a._skills.size():
						if a.battle_menu.move_usable[i]: a.battle_menu.move_index = i; break
					press("confirm")
			BattleMenu.Mode.TARGET:
				press("confirm")
		return false
	qt = 0.0
	backed_out = false
	if a.active != null: release_moves(); return false
	# free roam goals
	var c = a.controlled
	# Windup: a committed member you steer walks into reach of its target
	# (assassin, rock and monk lessons walk on their own below).
	if c != null and c.has_meta("windup_target") and not (g.begins_with("Hit the Golem from behind") or g.begins_with("Let the rock") or g.begins_with("Climb") or g.begins_with("Cash out") or g.begins_with("Put 4") or g.begins_with("Use Execute") or g.begins_with("Auto-parry") or g.begins_with("Use Shadowstep")):
		var tg = c.get_meta("windup_target")
		if is_instance_valid(tg):
			var dir = c.global_position - tg.global_position; dir.y = 0
			walk_to(c, tg.global_position + dir.normalized() * (tg.body_radius + c.body_radius + 0.4))
			return false
	if g.begins_with("Walk around"):
		walk_to(k, k.global_position + Vector3(3, 0, 0) if fmod(t, 4.0) < 2.0 else k.global_position + Vector3(-3, 0, 0))
	elif g.begins_with("Walk up") or g.begins_with("Wait for") or g.begins_with("Get in reach") or g.begins_with("Choose Attack") or g.begins_with("Add an Art") or g.begins_with("Play Slash") or g.begins_with("Build") or g.begins_with("Land") or g.begins_with("Choose Wait") or g.begins_with("Hit through") or g.begins_with("Interrupt"):
		if c != k and a._standing(a.party).size() > 1: press("swap_character")
		walk_to(k, golem.global_position + Vector3(0, 0, 1.0) * (golem.body_radius + k.body_radius + 0.4))
	elif g.begins_with("Make the Golem"):
		# keep away; once its area covers us while it casts, step out sideways/back
		if golem.loaded_skill != -1 and golem.attack_range.contains(k.global_position, k.body_radius + 0.3):
			var away = k.global_position - golem.global_position; away.y = 0
			var side = away.normalized().cross(Vector3.UP)
			var out = k.global_position + (away.normalized() * 2.0 + side * 3.0)
			out.x = clamp(out.x, -6.5, 6.5); out.z = clamp(out.z, -6.5, 6.5)
			walk_to(k, out)
		else:
			walk_to(k, Vector3(8, 0, 6) if golem.global_position.distance_to(Vector3(8, 0, 6)) > 6.0 else Vector3(-8, 0, -6))
	elif g.begins_with("Parry") or g.begins_with("Defend") or g.begins_with("Raise max"):
		if c != k: press("swap_character")
		walk_to(k, golem.global_position + golem.flat_forward() * 2.0)
	elif g.begins_with("Attack with the Mage"):
		var m = member("mage")
		if c != m: press("swap_character"); return false
		walk_to(m, golem.global_position + Vector3(0, 0, 3.0))
	elif g.begins_with("Let the rock"):
		if golem.loaded_skill != -1 and golem.skill_revealed and fmod(step_time, 0.5) < d:
			var rk = a.arena.obstacles()[0].global_position
			print("  golem ", golem.global_position, " knight ", k.global_position, " rock ", rk, " in_area ", golem.attack_range.contains(k.global_position, k.body_radius), " see ", a._can_see(golem, k), " ctrl ", c.display_name, " fwd ", golem.flat_forward(), " taunt ", golem.statuses.has("taunt"), " active ", a.active)
		if c != k: press("swap_character"); return false
		var rock = a.arena.obstacles()[0].global_position
		var away = (rock - golem.global_position); away.y = 0
		walk_to(k, rock + away.normalized() * 2.2)
	elif g.begins_with("Hit the Golem from behind") or g.begins_with("Use Execute") or g.begins_with("Use Shadowstep") or g.begins_with("Put 4") or g.begins_with("Auto-parry"):
		var s2 = member("assassin")
		if c != s2: press("swap_character"); return false
		var spot = golem.global_position - golem.flat_forward() * (golem.body_radius + s2.body_radius + 0.4)
		if g.begins_with("Use Shadowstep") or g.begins_with("Auto-parry"): spot = golem.global_position + golem.flat_forward() * (golem.body_radius + s2.body_radius + 0.4)
		walk_to(s2, spot)
	elif g.begins_with("Climb") or g.begins_with("Cash out"):
		var mo = member("monk")
		if mo != null:
			if c != mo: press("swap_character"); return false
			walk_to(mo, golem.global_position + Vector3(0, 0, golem.body_radius + mo.body_radius + 0.4))
	elif g.begins_with("Defeat"):
		walk_to(c, golem.global_position + Vector3(0, 0, 1.5))
	else:
		release_moves()
	return false
