extends SceneTree
# Options' camera rows: Camera speed scales how fast the stick / keys turn
# the camera, Mouse sensitivity how far a right-drag turns it, and Invert
# camera mirrors both.
var a
var t := 0.0
var step := 0
var fails := 0
var before := []
var yaw := 0.0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	before = [Settings.camera_speed(), Settings.mouse_sensitivity(), Settings.invert_mode()]
	Settings.set_camera_speed(100)
	Settings.set_mouse_sensitivity(100)
	Settings.set_invert_mode("off")
	BattleArena._round_index = 1
	BattleArena.chosen_for_round = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func turned(delta: float) -> float:
	var from: float = a._cam_yaw
	Input.action_press("camera_right")
	a._update_camera(delta)
	Input.action_release("camera_right")
	return a._cam_yaw - from
func dragged(pixels: float) -> float:
	var from: float = a._cam_yaw
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(pixels, 0)
	e.button_mask = MOUSE_BUTTON_MASK_RIGHT
	a._camera_input(e)
	return a._cam_yaw - from
func tilted() -> float:
	a._cam_pitch = 40.0
	Input.action_press("camera_tilt_down")
	a._update_camera(0.1)
	Input.action_release("camera_tilt_down")
	return a._cam_pitch - 40.0
func _process(d) -> bool:
	t += d
	if t < 1.0: return false
	for c in a.combatants: c.hold = true
	var base := turned(0.1)
	var mouse_base := dragged(20.0)
	check(absf(base) > 0.1 and absf(mouse_base) > 0.1, "the camera turns (%.2f, %.2f)" % [base, mouse_base])
	Settings.set_camera_speed(200)
	check(is_equal_approx(turned(0.1), base * 2.0), "Camera speed 200%: twice as fast")
	Settings.set_mouse_sensitivity(50)
	check(is_equal_approx(dragged(20.0), mouse_base * 0.5), "Mouse sensitivity 50%: half as far")
	check(tilted() > 0.0, "the right stick tilts the camera (down: looks down)")
	Settings.set_invert_mode("x")
	check(turned(0.1) * base < 0.0 and dragged(20.0) * mouse_base < 0.0, "Invert X: stick and mouse turn the other way")
	check(tilted() > 0.0, "Invert X leaves the tilt alone")
	Settings.set_invert_mode("y")
	check(turned(0.1) * base > 0.0 and tilted() < 0.0, "Invert Y: the tilt flips, turning doesn't")
	Settings.set_invert_mode("both")
	check(turned(0.1) * base < 0.0 and tilted() < 0.0, "Invert X and Y: both flip")
	var rows := Settings.option_rows()
	check(rows[7] == "Camera speed: 200%" and rows[8] == "Mouse sensitivity: 50%" and rows[9] == "Invert camera: X and Y", "the Options rows show them: %s" % [rows.slice(7)])
	Settings.change_option(9)
	check(Settings.invert_mode() == "off", "the Invert row cycles (both -> off)")
	Settings.change_option(7)
	check(Settings.camera_speed() == 50, "the row cycles (200% -> 50%)")
	Settings.set_camera_speed(before[0])
	Settings.set_mouse_sensitivity(before[1])
	Settings.set_invert_mode(before[2])
	print("FAILS: ", fails)
	quit()
	return true
