extends SceneTree
# Screenshots: the Mage's four element effects (SpellFx), one PNG each in
# the folder OUT, each caught mid-effect. KIND=art: four Arts instead.
# Run with --fixed-fps 60.
var a
var t := 0.0
var mg
var e1
var cam: Camera3D
var i := 0
var wait := -1.0
const SHOTS := [["fire", "Fire", 0.33], ["ice", "Ice", 0.16], ["lightning", "Lightning", 0.04], ["energy", "Energy Blast", 0.38]]
const ARTS := [["fireball", "Fireball", 0.33], ["steam_burst", "Steam Burst", 0.2], ["thunder", "Thunder", 0.04], ["meteor", "Meteor", 0.31]]
func _initialize():
	BattleArena._round_index = 4
	BattleArena.chosen_for_round = 4
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/mage.tscn", "res://scenes/characters/knight.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func move(n):
	for m in Moves.attacks("mage") + Moves.arts("mage"):
		if m["name"] == n: return m
func _process(d):
	t += d
	if t < 0.8: return false
	if mg == null:
		for c in a.combatants: c.hold = true
		mg = a.party.filter(func(p): return p.class_id == "mage")[0]
		e1 = a.enemies[0]
		e1.global_position = Vector3(0, e1.global_position.y, -1)
		mg.global_position = Vector3(-1.5, mg.global_position.y, 3.5)
		for e in a.enemies:
			if e != e1: e.global_position = Vector3(10, e.global_position.y, -8)
		mg.face_toward(e1.global_position - mg.global_position, 1.0, 100000.0)
		cam = Camera3D.new()
		root.add_child(cam)
		cam.global_position = Vector3(4.5, 3.6, 4.5)
		cam.look_at(Vector3(-0.3, 1.0, 0.5), Vector3.UP)
		cam.make_current()
	a._intro_left = 0.0
	a._flash_time_left = 0.0
	var list = ARTS if OS.get_environment("KIND") == "art" else SHOTS
	if i >= list.size(): return true
	if wait < -1.0:
		wait += d  # a breather: the last effect fades first
		return false
	if wait < 0.0:
		var m = move(list[i][1])
		SpellFx.approach(a, mg, e1, m, 0.28)
		get_root().get_tree().create_timer(0.28).timeout.connect(func(): SpellFx.impact(a, mg, e1, m, false))
		wait = 0.0
		return false
	wait += d
	if wait >= float(list[i][2]):
		root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/fx_%s.png" % list[i][0])
		print("saved ", list[i][0])
		i += 1
		wait = -2.2
	return false
