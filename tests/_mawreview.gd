extends SceneTree
# Gale Maw review: Deep Breath's Stagger bar, feeding it a Gust Sprite while
# it pulls (it chokes), teal pulls, follow-up previews, shelter marks.
var a
var t := 0.0
var fails := 0
var maw
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/mage.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func skill(n):
	for s in maw.skills:
		if s.skill_name == n: return s
func cast(n):
	if maw.loaded_skill != Skills.NONE: a._finish_enemy_skill(maw, false)
	maw.forced_skill = skill(n)
	maw.timeline_pos = a.cast_zone_start + 1.0
	a._begin_cast(maw)
	a._reveal_skill(maw)
func _process(d):
	t += d
	if t < 0.6: return false
	for c in a.combatants: c.hold = true
	maw = a.enemies[0]
	# Part 1
	check(skill("Deep Breath").stagger_bar == 70, "Deep Breath has a Stagger bar (%d)" % skill("Deep Breath").stagger_bar)
	# Part 3
	check(skill("Inhale").color() == EnemySkill.PULL_COLOR and skill("Exhale").color() != EnemySkill.PULL_COLOR, "pulls are teal, pushes aren't")
	cast("Deep Breath")
	var nodes: Array = maw.get_meta("telegraphs", [])
	var previews = nodes.filter(func(n): return n is AttackRange and n.preview)
	check(previews.size() == 1 and previews[0].radius == 8.0, "Deep Breath previews Maw Bite (%d previews)" % previews.size())
	var marks = nodes.filter(func(n): return n is MeshInstance3D and not (n is AttackRange) and n.mesh is PlaneMesh)
	var rocks = a.arena.obstacles().filter(func(o): return o.blocks_sight()).size()
	check(marks.size() == rocks and rocks > 0, "the floor behind each rock shows clear (%d of %d)" % [marks.size(), rocks])
	cast("Maw Bite")
	nodes = maw.get_meta("telegraphs", [])
	check(nodes.filter(func(n): return n is MeshInstance3D and n.mesh is PlaneMesh).is_empty(), "no shelter marks for Maw Bite (not whole-arena)")
	cast("Inhale")
	a._update_mouths()
	check(maw.get_meta("mouth").visible, "Inhale: the black mouth shows")
	cast("Exhale")
	a._update_mouths()
	check(not maw.get_meta("mouth").visible, "Exhale: mouth closed")
	# Part 2: feed it a sprite while it Inhales.
	a._summon(maw)
	var s = maw.get_meta("summons", [])[0]
	var fwd: Vector3 = maw.flat_forward()
	cast("Exhale")
	s.global_position = maw.global_position + fwd * (maw.body_radius + 2.0)
	a._knock_away(s, s.global_position + fwd, 2.0)
	var gap = (s.global_position - maw.global_position).length() - maw.body_radius - s.body_radius
	check(not s.is_down and gap > -0.05, "mouth closed (Exhale): no choke, it bounces off its body (gap %.2f)" % gap)
	cast("Inhale")
	maw.stagger_fill = 0.0
	s.global_position = maw.global_position + fwd * (maw.body_radius + 2.0)
	var hp0 = maw.hp
	a._knock_away(s, s.global_position + fwd, 2.0)
	check(s.is_down and not s.get_meta("fell", false), "knocked into its mouth while it Inhales: the sprite is gone")
	check(hp0 - maw.hp == 135, "the blast goes off inside it: %d damage" % (hp0 - maw.hp))
	check(maw.statuses.has("staggered") and maw.loaded_skill == Skills.NONE, "the Maw is Staggered, its Inhale broken")
	check(int(a.stats.get("chokes", 0)) == 1, "counted as a choke")
	print("FAILS: %d" % fails)
	quit()
	return true
