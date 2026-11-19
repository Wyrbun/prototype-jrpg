extends SceneTree
# Screenshots: field enemies' sight (Prologue Stage 2). The hall with the
# Ratkin's and Kobold's cones; the Kobold noticing the party (red, "!");
# the steps room with the Living Armor's circle. SHOT_<n>.png.
var f: FieldScene
var t := 0.0
var n := 0
func _initialize():
	f = load(FieldScene.SCENE).instantiate()
	root.add_child(f)
func shot():
	n += 1
	root.get_texture().get_image().save_png("%s_%d.png" % [OS.get_environment("SHOT"), n])
func _process(d):
	t += d
	if n == 0 and t > 1.6:
		Input.action_release("move_left")
		shot()
		f.leader.place(Vector3(5.5, 0, -0.5), 0.0)
	elif n == 0 and t > 1.0 and not Input.is_action_pressed("move_left"):
		f.camera.distance = 14.0
		f.camera.pitch = 55.0
		Input.action_press("move_left")
	elif n == 1 and t > 2.05:
		shot()
		f.go_to("res://scenes/field/rooms/test_steps.tscn", "from_hall")
	elif n == 2 and t > 4.2:
		shot()
		return true
	elif n == 2 and t > 3.5 and f.camera.distance < 14.0:
		f.camera.distance = 14.0
		f.camera.pitch = 55.0
		f.camera.yaw = 0.0
		f.leader.place(Vector3(-1.6, 1.5, -4.0), 0.0)
	return false
