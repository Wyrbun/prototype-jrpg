extends SceneTree
# Golem: Ceiling Burst comes for sure once its HP first drops to 75%.
var a
var t := 0.0
var fails := 0
func check(ok, what):
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func pick(g):
	var s = a._choose_enemy_skill(g)
	g.set_meta("skills_used", [s.skill_name])
	return s.skill_name
func _process(d):
	t += d
	if t < 0.8: return false
	var g = a.enemies[0]
	check(g.name.to_lower().contains("golem") or g.display_name.contains("Golem"), "round 7 is the Golem")
	# Above 75%: no forced pick (Ceiling Burst only by chance).
	var forced := 0
	for i in 40:
		if a._sure_hp_skill(g, g.skills) != null: forced += 1
	check(forced == 0, "full HP: nothing forced")
	g.hp = int(g.max_hp * 0.74)
	check(pick(g) == "Ceiling Burst", "first pick at 74% HP is Ceiling Burst")
	var again := 0
	for i in 30:
		if a._sure_hp_skill(g, g.skills) != null: again += 1
	check(again == 0, "only once")
	# A Golem that already dropped rocks isn't forced.
	g.remove_meta("sure_done")
	g.rock_bursts = 1
	check(a._sure_hp_skill(g, g.skills) == null, "skipped after an earlier burst")
	# A Golem that already used Ceiling Burst (by chance) isn't forced either.
	g.remove_meta("sure_done")
	g.rock_bursts = 0
	g.set_meta("skills_used", ["Ceiling Burst"])
	check(a._sure_hp_skill(g, g.skills) == null, "skipped after it already used Ceiling Burst")
	print("FAILS: %d" % fails)
	return true
