extends SceneTree
# Screenshots of each arena's setting (not a test). ROUNDS = comma list of
# round indexes (-1: the tutorial's training yard), OUT = folder.
# Per round: the battle view, then two low views from the sides.
var a
var t := 0.0
var rounds := []
var shots := 0
var cam: Camera3D
func _initialize():
	for r in OS.get_environment("ROUNDS").split(","):
		rounds.append(int(r))
	_load()
func _load():
	if a:
		a.queue_free()
	var r = rounds.pop_front()
	BattleArena.tutorial_mode = r < 0
	BattleArena._round_index = maxi(r, 0)
	BattleArena.chosen_for_round = maxi(r, 0)
	BattleArena.party_ai_override = 0
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	a.set_meta("round", r)
	root.add_child(a)
	t = 0.0; shots = 0
func shot(n):
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/arena_%s_%s.png" % [str(a.get_meta("round")).replace("-", "t"), n])
func _process(d):
	t += d
	if t < 1.2 + shots * 0.25: return false
	match shots:
		0:
			for c in a.combatants: c.hold = true
			shot("battle")
			cam = Camera3D.new(); a.add_child(cam); cam.fov = 60
			cam.global_position = Vector3(-14, 3.0, 9)
			cam.look_at(Vector3(4, 1.5, -4), Vector3.UP)
			cam.make_current()
		1:
			shot("side")
			cam.global_position = Vector3(12, 4.0, -12)
			cam.look_at(Vector3(-4, 1.0, 4), Vector3.UP)
		2:
			shot("back")
			# close on the obstacles: a hole if there is one, else a rock
			var obs = a.arena.obstacles()
			var pick = null
			for o in obs:
				if o.is_lethal(): pick = o
			if pick == null and not obs.is_empty(): pick = obs[0]
			if pick != null:
				var at = pick.global_position
				cam.global_position = at + Vector3(2.5, 3.2, 4.5)
				cam.look_at(at + Vector3(0, 0.3, 0), Vector3.UP)
		3:
			shot("close")
			if rounds.is_empty():
				quit()
				return true
			_load()
			return false
	shots += 1
	return false
