extends SceneTree
# Screenshots of the field (Prologue Stage 1): the test hall from its set
# angle, the party walking, and the test steps. Saves to SHOT_<n>.png
# (the SHOT environment variable is the path without ".png").
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
	if n == 0 and t > 1.0:
		shot()
		Input.action_press("move_forward")
		Input.action_press("move_right")
	elif n == 1 and t > 1.8:
		shot()
		Input.action_release("move_forward")
		Input.action_release("move_right")
		f.go_to("res://scenes/field/rooms/test_steps.tscn", "from_hall")
	elif n == 2 and t > 3.2:
		shot()
		f.leader.place(Vector3(-1.75, 0, 1.5), 0.0)
		f.camera.yaw = 0.0
		Input.action_press("move_forward")
	elif n == 3 and t > 5.0:
		Input.action_release("move_forward")
		shot()
		return true
	return false
