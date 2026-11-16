extends SceneTree
# Dragon Hatchling review: more and hotter fire (5 turns, cap 3, 20 HP/s,
# 15 to step in), Scorch and Breathe, and the half-HP Wings of Fire phase.
var a
var t := 0.0
var fails := 0
var d
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 9
	BattleArena.chosen_for_round = 9
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(n):
	for s in d.skills:
		if s.skill_name == n: return s
func lay(n):
	d.loaded_def = skill(n)
	d.attack_range.show_skill(d.loaded_def)
	a._spawn_trail(d)
func waves():
	return a._hazards.filter(func(h): return h["owner"] == d and h.get("group", "") == "wave")
func _process(dt):
	t += dt
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	d = a.enemies[0]
	check(d.display_name == "Dragon Hatchling", "round: %s" % d.display_name)
	var fw = skill("Fire Wave")
	check(fw.weight == skill("Breath").weight and fw.trail_turns == 5 and fw.trail_damage_per_second == 20.0 and fw.trail_touch_damage == 15,
			"Fire Wave: as often as Breath, fire 5 turns, 20 HP/s, 15 to step in")
	# Cap of 3 lines.
	var k = a.party[0]
	k.global_position = Vector3(30, k.global_position.y, 30)  # well away while lines are laid
	a.party[1].global_position = Vector3(-30, 0, 30)
	for i in 4: lay("Fire Wave")
	check(waves().size() == 3, "a 4th line puts out the oldest: %d lines" % waves().size())
	# Step in: 15 at once, then the burn.
	for h in waves().slice(1): a._remove_hazard(h)  # (all laid on the same spot: keep one)
	var area: AttackRange = waves()[0]["area"]
	var fwd: Vector3 = -area.global_transform.basis.z
	k.global_position = area.global_position + fwd * 5.0
	k.global_position.y = 0.0
	var hp0 = k.hp
	a._tick_hazards(0.01)
	check(hp0 - k.hp == 15, "stepping in costs 15 (%d)" % (hp0 - k.hp))
	a._tick_hazards(0.5)
	check(hp0 - k.hp >= 25 and hp0 - k.hp <= 27, "then 20 HP/s (%d after 0.5 s)" % (hp0 - k.hp))
	# Already standing there when a line appears: no step-in cost.
	for h in a._hazards.duplicate(): a._remove_hazard(h)
	hp0 = k.hp
	lay("Fire Wave")
	a._tick_hazards(0.01)
	check(hp0 - k.hp == 0, "standing there as it appears: no step-in cost")
	for h in a._hazards.duplicate(): a._remove_hazard(h)
	# Scorch and Breathe.
	var sb = skill("Scorch and Breathe")
	check(sb.follow_up == skill("Breath") and is_equal_approx(sb.follow_up_delay, 1.5), "Scorch and Breathe: Fire Wave, then Breath 1.5 s later")
	# Half HP: Wings of Fire once.
	d.hp = int(d.max_hp * 0.49)
	var first = a._choose_enemy_skill(d)
	check(first.skill_name == "Wings of Fire", "under half HP: Wings of Fire (%s)" % first.skill_name)
	var again = a._choose_enemy_skill(d)
	check(again.skill_name != "Wings of Fire", "only once (%s next)" % again.skill_name)
	d.global_position = Vector3(6, d.global_position.y, -7)  # off-centre, facing anywhere
	d.rotation_degrees.y = 37.0
	d.forced_skill = first
	d.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(d)
	d.forced_skill = null
	var r: AttackRange = d.attack_range
	var o: Vector3 = a.arena.global_position
	var side := Vector3.RIGHT
	# Four 3.4 m fire lines (two along the edges), three 3.4 m lanes free.
	var part := 24.0 / 7.0
	var at := func(k): return o + side * (-12.0 + part * (k + 0.5))  # slot k across the arena
	var lines_hit = [0, 2, 4, 6].map(func(k): return r.contains(at.call(k)))
	var lanes_free = [1, 3, 5].map(func(k): return r.contains(at.call(k)))
	check(lines_hit.all(func(x): return x) and lanes_free.all(func(x): return not x),
			"four fire lines (two along the edges), three lanes free, wherever the Dragon is (%s / %s)" % [lines_hit, lanes_free])
	a._spawn_trail(d)
	check(a._hazards.size() == 1 and int(a._hazards[0]["turns"]) >= 999, "the phase fire stays the rest of the fight")
	a._finish_enemy_skill(d, false)
	check(not r.top_level and Vector2(r.position.x, r.position.z).length() < 0.01, "its area goes back onto the Dragon afterwards")
	# Burning Spike lasts longer below half HP.
	d.loaded_def = skill("Burning Spike")
	check(d.loaded_def.trail_turns == 3 and d.loaded_def.trail_turns_below_half == 5, "Burning Spike: 3 turns, 5 below half HP")
	print("FAILS: %d" % fails)
	quit()
	return true
