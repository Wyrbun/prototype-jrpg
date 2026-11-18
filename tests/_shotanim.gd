extends SceneTree
# Frames of the figure animations, all six classes in a row: walking,
# attacks, a hit, a heavy hit, Defend, Parry, casting, an item, victory.
# FRAMES = folder, FPS = frames per second saved. Prints each action's
# first frame number.
var a
var t := 0.0
var n := 0
var cam: Camera3D
var plan := [[0.0, "walk"], [1.6, "attack"], [2.0, "attack"], [2.4, "attack"], [3.2, "hit"], [3.9, "hit_heavy"], [4.8, "defend"], [5.7, "parry"], [6.4, "cast"], [7.5, "item"], [8.6, "victory"], [10.0, "end"]]
var next := 0
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/cleric.tscn", "res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/assassin.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/monk.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
var started := false
var t0 := 0.0
func _process(d):
	t += d
	if t < 1.2: return false
	if not started:
		started = true
		for c in a.combatants: c.hold = true
		a.enemies[0].global_position = Vector3(0, 0, -9)
		a.enemies[0].visible = false
		a.get_node("UI").visible = false
		a.controlled = null
		for i in a.party.size():
			a.party[i].global_position = Vector3(-3.75 + i * 1.5, 0, 2)
		cam = Camera3D.new(); root.add_child(cam)
		cam.global_position = Vector3(0, 2.2, -3.6)
		cam.look_at(Vector3(0, 0.9, 2), Vector3.UP)
		cam.make_current()
		t0 = t
	var at := t - t0
	for m in a.party:
		m.face_toward(Vector3(0, 0, -1), 1.0, 100000.0)
	if next < plan.size() and at >= plan[next][0]:
		var act = plan[next][1]
		print("ACTION %s frame %d" % [act, n])
		if act == "end":
			quit(); return true
		for m in a.party:
			if act == "attack":
				var mv = {"name": "Kick" if (m.class_id == "monk" and next == 2) else "Punch"}
				m.play_lunge(mv)
			elif act != "walk":
				m.animate(act)
		next += 1
	for i in a.party.size():
		# pinned in place; walking first: a quick shuffle side to side
		var walk = sin(at * 5.0) * 0.5 if at < 1.4 else 0.0
		a.party[i].global_position = Vector3(-3.75 + i * 1.5 + walk, 0, 2)
	var fps := float(OS.get_environment("FPS"))
	if int(at * fps) != int((at - d) * fps):
		root.get_texture().get_image().save_png(OS.get_environment("FRAMES") + "/f%04d.png" % n)
		n += 1
	return false
