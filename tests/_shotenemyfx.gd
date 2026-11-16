extends SceneTree
# Screenshots: enemy hit effects (SpellFx) caught mid-effect: a heavy blow
# landing (shockwave + hit), a Defend, a Parry, a Stagger; also a heal, a
# shield and a knock-back dust trail. OUT=folder.
# Run with --fixed-fps 60.
var a
var t := 0.0
var g
var cam: Camera3D
var i := 0
var wait := -1.0
const SHOTS := ["hit", "defend", "parry", "stagger", "heal", "shield", "dust"]
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	a._intro_left = 0.0
	a._flash_time_left = 0.0
	if t < 0.8: return false
	if g == null:
		for c in a.combatants: c.hold = true
		g = a.enemies[0]
		var k = a.party[0]
		k.global_position = g.global_position + Vector3(0, 0, g.body_radius + 1.2)
		for m in a.party:
			if m != k: m.global_position = Vector3(-10, m.global_position.y, 8)
		cam = Camera3D.new()
		root.add_child(cam)
		cam.global_position = g.global_position + Vector3(5.5, 4.0, 6.5)
		cam.look_at(g.global_position + Vector3(0, 1.0, 1.5), Vector3.UP)
		cam.make_current()
	if i >= SHOTS.size(): return true
	var k = a.party[0]
	if wait < -1.0:
		wait += d
		return false
	if wait < 0.0:
		match SHOTS[i]:
			"hit":
				SpellFx.enemy_blow(a, g, Color(1.0, 0.55, 0.2), 4.5)
				SpellFx.enemy_hit(a, g, k, Color(1.0, 0.55, 0.2), true, "hit")
			"defend":
				SpellFx.enemy_hit(a, g, k, Color(1.0, 0.55, 0.2), false, "defend")
			"parry":
				SpellFx.enemy_hit(a, g, k, Color(1.0, 0.55, 0.2), false, "parry")
			"stagger":
				SpellFx.stagger(a, g)
			"heal":
				SpellFx.heal(a, k)
			"shield":
				SpellFx.shield(a, k)
			"dust":
				SpellFx.dust(a, k, Vector3(1, 0, 0.3).normalized(), 4.0)
		wait = 0.0
		return false
	wait += d
	if wait >= (0.3 if SHOTS[i] in ["heal", "dust"] else 0.1):
		root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/enemy_%s.png" % SHOTS[i])
		print("saved ", SHOTS[i])
		i += 1
		wait = -2.2
	return false
