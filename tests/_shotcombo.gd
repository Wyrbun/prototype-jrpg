extends SceneTree
# Frames of a real combo (the arena's own timing, presses aimed at
# Perfects), then each Ability's animation. CLASS = class, PLAN = "Slash,
# Thrust,..." (moves added to the bar in order; Arts merge, all known),
# ABILITIES = "Brace,Taunt" (optional). FRAMES = folder, FPS = frames per
# second. CAM=wide: a wide side view. Prints "MOVE <name> <frame>" whenever a new block or Ability
# starts, for captions.
var a
var t := 0.0
var n := 0
var step := 0
var who
var foe
var cam: Camera3D
var last_slot := -1
var frame := 0
var abilities := []
var ab_t := 0.0
func _initialize():
	var cls := OS.get_environment("CLASS")
	for art in Moves.arts(cls):
		ArtsBook.discover(cls, art["name"])
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/%s.tscn" % cls])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func press(action):
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new(); up.action = action; up.pressed = false
	Input.parse_input_event(up)
func cls_is(c) -> bool:
	return OS.get_environment("CLASS") == c
func grab(d):
	var fps := float(OS.get_environment("FPS"))
	if int(t * fps) != int((t - d) * fps):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%04d.png" % n)
		n += 1
func _process(d):
	t += d
	match step:
		0:
			if t < 1.0: return false
			for c in a.combatants: c.hold = true
			a.get_node("UI").visible = false
			who = a.party[0]
			foe = a.enemies[0]
			var ranged = who.class_id in ["archer", "mage"]
			who.global_position = Vector3(0, 0, 2.5)
			foe.global_position = Vector3(0, 0, 2.5 - (who.body_radius + foe.body_radius + (0.6 if not ranged else 4.5)))
			who.face_toward(foe.global_position - who.global_position, 1.0, 100000.0)
			var mid = (who.global_position + foe.global_position) / 2.0
			cam = Camera3D.new(); root.add_child(cam); cam.make_current()
			if OS.get_environment("CAM") == "hero":
				# close on the fighter, three-quarters from the front, the target beside him
				var dir = (foe.global_position - who.global_position).normalized()
				var perp = dir.cross(Vector3.UP)
				cam.global_position = who.global_position + perp * 2.6 - dir * 0.2 + Vector3(0, 1.3, 0)
				cam.look_at(who.global_position + dir * 0.7 + Vector3(0, 0.85, 0), Vector3.UP)
			elif OS.get_environment("CAM") == "side":
				# both in view from the side, close enough to read the poses
				cam.global_position = mid + Vector3(5.0, 2.2, 0.6)
				cam.look_at(mid + Vector3(0, 1.3, 0), Vector3.UP)
			elif OS.get_environment("CAM") == "wide":
				# both in view from the side, high enough for the sky (Meteor)
				cam.global_position = mid + Vector3(9.5, 4.0, 0.5)
				cam.look_at(mid + Vector3(0, 2.0, 0), Vector3.UP)
			elif ranged:
				var focus = who.global_position.lerp(foe.global_position, 0.3)
				cam.global_position = focus + Vector3(-3.3, 1.2, -0.4)
				cam.look_at(focus + Vector3(0, 0.9, 0), Vector3.UP)
			else:
				cam.global_position = mid + Vector3(3.6, 1.3, 0.9)
				cam.look_at(mid + Vector3(0, 0.8, 0.3), Vector3.UP)
			if cls_is("monk") and OS.get_environment("CHEER") != "":
				who.tokens["Crowd Cheer"] = 1  # Tortoise Special needs it
			if cls_is("assassin"):
				# his moves want its back and its Marks
				foe.face_toward(foe.global_position - who.global_position, 1.0, 100000.0)
				foe.set_marks(3)
			a._set_controlled(who); a.active = who; a.current_max_ap = 400; a.ap = 400; a._command_phase = false
			who.combo_limit = 400  # room for any Art
			a._open_combo_bar(foe)
			for nm in OS.get_environment("PLAN").split(",", false):
				for i in a._moves.size():
					if a._moves[i]["name"] == nm: a._add_to_combo(i); break
			a._execute_combo()
			abilities = Array(OS.get_environment("ABILITIES").split(",", false))
			step = 1; t = 0
		1:
			if not who.class_id in ["archer", "mage"] and OS.get_environment("CAM") == "":
				var mid2 = (who.global_position + foe.global_position) / 2.0
				cam.global_position = cam.global_position.lerp(mid2 + Vector3(3.6, 1.3, 0.9), minf(d * 4.0, 1.0))
			grab(d)
			who.face_toward(foe.global_position - who.global_position, 1.0, 100000.0)
			if a._menu_mode == BattleMenu.Mode.EXECUTING:
				if a._exec_slot != last_slot and a._exec_lead_in <= 0:
					last_slot = a._exec_slot
					print("MOVE %s %d" % [a._plan[a._exec_slot]["move"]["name"], n])
				var e = a._plan[a._exec_slot]; var h = a._exec_hits_done
				frame += 1
				var timing = int(e["timing"])
				if a._exec_lead_in > 0:
					pass
				elif timing == Moves.TimingType.CODE:
					# type the spell code, then (Energy) tap away
					var code: Array = e["code"]
					if a._exec_code < code.size():
						if a._exec_time >= e["duration"] * e["code_start"] and frame % 3 == 0:
							a._judge_code(code[a._exec_code])
					elif float(e["move"].get("surge", 0.0)) > 0.0 and frame % 4 == 0:
						press("confirm")
				elif timing == Moves.TimingType.TAP:
					if a._exec_time >= e["duration"] * e["tap_start"] and a._exec_taps < int(e["taps"]) and frame % 4 == 0:
						press("confirm")
				elif h < e["times"].size():
					var ht = e["duration"] * e["times"][h]
					if a._exec_time >= ht - e["window"] * e["duration"] * 0.5 and a._exec_timings[h] == 0: press("confirm")
			elif t > 1.0:
				step = 2; t = 0; ab_t = 1.6
		2:
			grab(d)
			ab_t += d
			if ab_t >= 1.7:
				ab_t = 0.0
				if abilities.is_empty():
					quit(); return true
				var nm = abilities.pop_front()
				print("MOVE %s %d" % [nm, n])
				who.animate("cast", {"name": nm, "_target": foe})
				# Cleric Abilities: their effects (on herself: she's alone here).
				match nm:
					"Healing": SpellFx.heal(a, who)
					"Full Cure": SpellFx.pillar(a, who.global_position, SpellFx.HOLY, 0.9); SpellFx.heal(a, who)
					"Haste": SpellFx.haste(a, who)
					"Shielding": SpellFx.dome(a, who.global_position, SpellFx.HOLY_BLUE, 3.0); SpellFx.shield(a, who)
					"Lifeline": SpellFx.streak(a, who.global_position + Vector3(0, 0, 3), who.global_position, SpellFx.HOLY_GREEN)
					# Assassin Abilities: their effects, on the Golem
					"Hook": SpellFx.chain(a, who.global_position + Vector3(0, 1.0, 0), foe.global_position + Vector3(0, 1.0, 0))
					"Death Sentence": SpellFx.sentence(a, foe)
					"Shadow Cloak": SpellFx.rings_up(a, who, SpellFx.SHADOW); SpellFx.shield(a, who)
					"Vanish": SpellFx.shadow_puff(a, who.global_position)
					# Monk Abilities
					"Provoke": SpellFx.provoke(a, foe)
					"Suplex": SpellFx.ring(a, Vector3(who.global_position.x, 0, who.global_position.z), SpellFx.KI, 1.8)
					"Deep Breath": SpellFx.rings_up(a, who, Color(0.6, 1.0, 0.7)); SpellFx.heal(a, who)
	return false
