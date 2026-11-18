extends SceneTree
# Sim (not a test): Round 5 (the Sky Ruins, holes and a drop) with Party AI
# on for 60 s of fight; prints how often AI allies backed off a drop. It
# used to jitter on the line (hundreds a fight); a handful is normal.
var a
var t := 0.0
var was_ai := false
func _initialize():
	was_ai = Settings.party_ai()
	Settings.set_party_ai(true)
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
	Engine.time_scale = 3.0
func _process(d):
	t += d
	if t < 0.5 and OS.get_environment("H") != "":
		a.ledge_hysteresis = float(OS.get_environment("H"))
	if OS.get_environment("PUSH") != "":
		for e in a.enemies:
			for sk in e.skills:
				if sk.launch > 0.0 and e.loaded_skill == Skills.NONE:
					e.forced_skill = sk
	if OS.get_environment("NEAR") != "" and a.controlled != null:
		# you stand right by a hole (allies follow you)
		for o in a.arena.obstacles():
			if o.is_lethal():
				var spot = o.global_position + Vector3(o.radius + 0.9, 0, 0)
				a.controlled.global_position = Vector3(spot.x, a.controlled.global_position.y, spot.z)
				break
	if OS.get_environment("FOE") != "":
		# the enemies stand right by the holes: allies must walk in to attack
		var holes = a.arena.obstacles().filter(func(o): return o.is_lethal())
		for i in a.enemies.size():
			var o = holes[i % holes.size()]
			var e = a.enemies[i]
			e.hold = true
			var spot = o.global_position + Vector3(0, 0, o.radius + e.body_radius + 0.3)
			e.global_position = Vector3(spot.x, e.global_position.y, spot.z)
	if t < 60.0:
		return false
	print("ledge steps: %d in %.0f s" % [int(a.stats.get("ai_ledge_steps", 0)), t])
	Settings.set_party_ai(was_ai)
	quit()
	return true
