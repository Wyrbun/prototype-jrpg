extends SceneTree
# Answer tags: moves and Abilities that answer the enemy right now.
var a
var t := 0.0
var done := false
var fails := 0
var dir := "/tmp/claude-0/-home-claude/05b81194-2749-584d-a628-b8b7ec5f1f2b/scratchpad/"
func check(c, l):
	print(("ok   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	BattleArena._round_index = 8
	BattleArena.chosen_for_round = 8
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/assassin.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func m(n):
	for p in a.party: if p.display_name == n: return p
func tag_of(n):
	for i in a._moves.size():
		if a._moves[i]["name"] == n: return a.battle_menu.move_tags[i] if i < a.battle_menu.move_tags.size() else []
	return []
func skill_tag(n):
	for i in a._skills.size():
		if a._skills[i]["name"] == n: return a.battle_menu.move_tags[i]
	return []
func prep(g, kind):
	var def = null
	for s in g.skills:
		if s.kind == kind: def = s
	if def == null:
		def = g.skills[0]; def.kind = kind
	g.forced_skill = def; g.timeline_pos = a.cast_zone_start; a._begin_cast(g); a._reveal_skill(g)
	return def
func _process(d):
	t += d
	if t < 0.5 or done: return false
	done = true
	var g = a.enemies[0]
	for c in a.combatants: c.hold = true; c.timeline_pos = 10
	var kn = m("Knight"); g.global_position = Vector3(0, 0, -2); kn.global_position = Vector3(0, 0, -0.6)
	a._set_controlled(kn); a.active = kn; a.ap = 100
	# Smash wind-up: Attack-type moves interrupt
	prep(g, Skills.Kind.SMASH)
	a._open_combo_bar(g); a._update_answer_tags()
	var st = tag_of("Slash")
	check(st != null and not st.is_empty() and String(st[0]).begins_with("INTERRUPT") and st[1] == 1, "vs a Smash: Slash interrupts %s" % [st])
	# Defense: Thrust pierces, Slash is blocked
	a._finish_enemy_skill(g, false); g.stance = Skills.Kind.DEFENSE
	a._update_answer_tags()
	check(tag_of("Thrust")[0] == "PIERCES" and tag_of("Slash")[0] == "BLOCKED" and tag_of("Slash")[1] == -1, "vs Defense: Thrust PIERCES, Slash BLOCKED")
	# Counter stance: everything is punished
	g.stance = Skills.Kind.COUNTER; a._update_answer_tags()
	check(tag_of("Slash")[0] == "COUNTER: PARRY IT", "vs Counter: COUNTER: PARRY IT")
	g.stance = Skills.NONE; a._update_answer_tags()
	check(tag_of("Slash").is_empty(), "nothing special: no tag")
	# Abilities: Brace answers a strike coming at you
	a._menu_mode = BattleMenu.Mode.HIDDEN
	prep(g, Skills.Kind.ATTACK); g.cast_target = kn
	a._open_skills(); a._update_answer_tags()
	check(skill_tag("Brace")[0] == "HALVES IT", "a strike coming at the Knight: Brace HALVES IT")
	# a hidden skill isn't read
	g.skill_revealed = false; a._update_answer_tags()
	check(skill_tag("Brace").is_empty(), "not revealed yet: no tag")
	print("FAILS: %d" % fails); quit(); return true
