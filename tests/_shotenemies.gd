extends SceneTree
# Screenshots: every enemy figure close up, front and back. OUT = folder;
# files enemy_<scene>_front/back.png. Enemies are spawned straight from
# their scenes into a round's arena.
var a
var t := 0.0
var i := 0
var side := 0
var cam: Camera3D
var foes := []
const SCENES := ["goblin_fighter", "kobold_archer", "ogre_warrior", "orc_shaman", "bandit_arcanist", "training_golem", "stone_golem", "living_armor", "dragon_hatchling", "gust_sprite", "shadow_sprite", "gale_maw"]
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.party_ai_override = 0
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 1.0: return false
	if cam == null:
		for c in a.combatants: c.hold = true; c.visible = false
		a.get_node("UI").visible = false
		for k in SCENES.size():
			var e = load("res://scenes/characters/%s.tscn" % SCENES[k]).instantiate()
			e.team = Combatant.Team.ENEMY
			a.add_child(e)
			e.global_position = Vector3(0, 0, 0)
			e.visible = false
			foes.append(e)
		cam = Camera3D.new(); root.add_child(cam); cam.make_current()
		t = 1.0
	if i >= foes.size():
		quit(); return true
	for k in foes.size(): foes[k].visible = (k == i)
	var e = foes[i]
	var h = e.get_node("NameLabel").position.y
	var dist = maxf(h * 1.1, 1.8) if e.body_radius < 2.0 else e.body_radius * 3.2
	var off = Vector3(0.45, 0.0, -1.0) if side == 0 else Vector3(-0.5, 0.0, 1.0)
	cam.global_position = e.global_position + off.normalized() * dist + Vector3(0, h * 0.55, 0)
	cam.look_at(e.global_position + Vector3(0, h * 0.42, 0), Vector3.UP)
	if t < 1.4: return false
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/enemy_%s_%s.png" % [SCENES[i], "front" if side == 0 else "back"])
	t = 1.0
	side += 1
	if side > 1:
		side = 0; i += 1
	return false
