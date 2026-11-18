extends SceneTree
# Party AI doesn't run on the spot (play-test: the Cleric jogged in place by
# the Round 4 pit, escaping an area). Three full-AI Round 4s: no fighter's walk
# animation runs for long while it goes nowhere. Before the fix: up to 6 s.
var a
var t := 0.0
var hist := {}
var jog := {}
var fails := 0
var fight := 0
const FIGHTS := 3
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	_start()
func _start():
	t = 0.0
	hist = {}
	BattleArena._round_index = 3
	BattleArena.chosen_for_round = 3
	BattleArena.party_ai_override = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.5: return false
	if t < 0.6:
		seed(3 + fight)
		a.controlled = null
		Engine.time_scale = 2.0
	for m in a.party:
		if m.is_down or a.end_screen != null: continue
		var k: String = m.display_name
		var h: Array = hist.get(k, [])
		h.append(m.global_position)
		if h.size() > 60: h.pop_front()
		hist[k] = h
		if h.size() == 60:
			var path := 0.0
			for i in range(1, 60): path += (h[i] as Vector3).distance_to(h[i - 1])
			# Over a second: the legs moved a meter, the fighter 30 cm at most.
			if path > 1.0 and (h[59] as Vector3).distance_to(h[0]) < 0.3:
				jog[k] = int(jog.get(k, 0)) + 1
	if t > 100.0 or (a.end_screen != null and t > 1.0):
		Engine.time_scale = 1.0
		fight += 1
		if fight < FIGHTS:
			a.queue_free()
			_start()
			return false
		for k in jog:
			check(int(jog.get(k, 0)) < 90, "%s: jogged on the spot for %d frames in %d fights (under 90)" % [k, int(jog.get(k, 0)), FIGHTS])
		print("FAILS: ", fails)
		quit()
		return true
	return false
