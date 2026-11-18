extends SceneTree
# Screenshots of the Gale Maw's figure in its own arena (Round 11): from
# the party's side, and close from the front. OUT = folder.
var a
var t := 0.0
var step := 0
var cam: Camera3D
func _initialize():
	BattleArena._round_index = 10
	BattleArena.chosen_for_round = 10
	BattleArena.party_ai_override = 0
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	match step:
		0:
			if t < 1.5: return false
			for c in a.combatants: c.hold = true
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/maw_view.png")
			var m = a.enemies[0]
			cam = Camera3D.new(); root.add_child(cam); cam.make_current()
			var fwd = -m.global_basis.z
			cam.global_position = m.global_position + fwd * 14.0 + Vector3(4, 5, 0)
			cam.look_at(m.global_position + Vector3(0, 2, 0), Vector3.UP)
			step = 1; t = 0
		1:
			if t < 0.4: return false
			root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/maw_front.png")
			quit(); return true
	return false
