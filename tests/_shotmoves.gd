extends SceneTree
# Frames of every attack and Art of one class (CLASS), each hit wound up
# the way a combo does it (anticipate, then the hit), against the Golem.
# FRAMES = folder, FPS = frames saved per second. MOVES = "A,B" for only
# those moves. FX=1 also plays the move's effects (arrows, spells). Prints "MOVE <name>
# <first frame>" for captions. Side view, HUD hidden.
var a
var t := 0.0
var n := 0
var cam: Camera3D
var who
var foe
var queue := []  # [time, kind, move, hit]
var started := false
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/%s.tscn" % OS.get_environment("CLASS")])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 1.0: return false
	if not started:
		started = true
		for c in a.combatants: c.hold = true
		a.get_node("UI").visible = false
		who = a.party[0]
		foe = a.enemies[0]
		var ranged = who.class_id in ["archer", "mage"] or OS.get_environment("CLASS") == "cleric"
		who.global_position = Vector3(0, 0, 2.5)
		# melee: in reach (0.8 m gap); ranged: 5 m off
		foe.global_position = Vector3(0, 0, 2.5 - (who.body_radius + foe.body_radius + (0.8 if not ranged else 5.0)))
		var mid = (who.global_position + foe.global_position) / 2.0
		cam = Camera3D.new(); root.add_child(cam); cam.make_current()
		if ranged:
			# from her bow side, framed on the shooter (the target further off)
			var focus = who.global_position.lerp(foe.global_position, 0.3)
			cam.global_position = focus + Vector3(-3.3, 1.2, -0.4)
			cam.look_at(focus + Vector3(0, 0.9, 0), Vector3.UP)
		else:
			cam.global_position = mid + Vector3(3.6, 1.3, 0.9)
			cam.look_at(mid + Vector3(0, 0.8, 0.3), Vector3.UP)
		var at := 0.3
		var only := OS.get_environment("MOVES").split(",", false)
		for m in Moves.attacks(who.class_id) + Moves.arts(who.class_id):
			if not only.is_empty() and not only.has(m["name"]):
				continue
			queue.append([at, "label", m, 0])
			var hits: Array = m["hits"]
			for h in hits.size():
				queue.append([at + 0.35 + h * 0.42 - 0.18, "anticipate", m, h])
				queue.append([at + 0.35 + h * 0.42, "hit", m, h])
			at += 0.35 + hits.size() * 0.42 + 0.75
		queue.append([at, "end", null, 0])
		t = 1.0
	var at := t - 1.0
	who.face_toward(foe.global_position - who.global_position, 1.0, 100000.0)
	while not queue.is_empty() and at >= queue[0][0]:
		var q = queue.pop_front()
		match q[1]:
			"label": print("MOVE %s %d" % [q[2]["name"], n])
			"anticipate": who.anticipate(q[2], q[3], foe, 0.18)
			"hit":
				who.play_lunge(q[2], q[3], foe)
				if OS.get_environment("FX") == "1":
					SpellFx.approach(a, who, foe, q[2], 0.12)
					get_root().get_tree().create_timer(0.12).timeout.connect(func(): SpellFx.impact(a, who, foe, q[2], false))
			"end":
				quit(); return true
	var fps := float(OS.get_environment("FPS"))
	if int(at * fps) != int((at - d) * fps):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%04d.png" % n)
		n += 1
	return false
