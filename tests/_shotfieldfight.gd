extends SceneTree
# Screenshots: a fight on the field (Prologue Stage 3). The battle
# transition, the fight in the hall, the Victory. SHOT_<n>.png.
var t := 0.0
var n := 0
var stage := 0
var b: BattleArena
func _initialize():
	FieldState.new_game(FieldScene.PROLOGUE_PARTY, FieldScene.PROLOGUE_ROOM, FieldScene.PROLOGUE_ENTRY)
	change_scene_to_file(FieldScene.SCENE)
func find(type) -> Node:
	for c in root.get_children():
		if is_instance_of(c, type): return c
	return null
func shot():
	n += 1
	root.get_texture().get_image().save_png("%s_%d.png" % [OS.get_environment("SHOT"), n])
func _process(d):
	t += d
	match stage:
		0:
			var f: FieldScene = find(FieldScene)
			if f == null or t < 1.0: return false
			f.leader.place(Vector3(-7.3, 0, -3.8), -PI / 2.0)
			f.swing()
			stage = 1
			t = 0.0
		1:
			if t < 0.75: return false
			shot()
			stage = 2
			t = 0.0
		2:
			b = find(BattleArena)
			if b == null or t < 3.0: return false
			shot()
			for e in b.enemies:
				e.take_damage(e.max_hp * 3, false)
			b._check_enemies()
			stage = 3
			t = 0.0
		3:
			if b.field_director._panel == null or t < 1.0 and b.field_director._panel._guard > 0.0: return false
			if t < 1.5: return false
			shot()
			return true
	return t > 30.0
