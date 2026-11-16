extends SceneTree
# Sim (not pass/fail): the Gale Maw fight with a full AI party (nobody
# steered). A Gust Sprite is summoned at the start; how long until the AI
# gets it off the ledge or into a hole, and how many hits it takes.
# S=seed. Prints SPRITE lines.
var a
var t := 0.0
var step := 0
var s
var maw
var hits := 0
var last_hp := 0
var log_t := 0.0
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.party_ai_override = 1
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 0.6: return false
			seed(int(OS.get_environment("S")))
			Engine.time_scale = 4.0
			maw = a.enemies[0]
			maw.hp = maw.max_hp * 10; maw.max_hp *= 10  # keep the fight going
			for m in a.party: m.max_hp *= 10; m.hp = m.max_hp
			a.controlled = null
			a._summon(maw)
			s = maw.get_meta("summons", [])[0]
			last_hp = s.hp
			step = 1; t = 0
		1:
			if s.hp < last_hp: hits += 1
			last_hp = s.hp
			if s.is_down:
				print("SPRITE gone after %.0f s, %d hits, fell=%s, lightweight_falls=%s, fuse out=%s, booms=%s, party dmg=%s" % [t, hits, s.get_meta("fell", false), a.stats.get("lightweight_falls", 0), a.stats.get("fuses_out", 0), a.stats.get("self_destructs", 0), a.party.map(func(m): return m.max_hp - m.hp)])
				return true
			if t - log_t > 20.0:
				log_t = t
				print("  t=%.0f sprite at %s, hits %d" % [t, s.global_position, hits])
			if t > 240.0:
				print("SPRITE still up after %.0f s, %d hits, at %s" % [t, hits, s.global_position])
				return true
	return false
