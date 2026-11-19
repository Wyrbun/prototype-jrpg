class_name FieldCamera
extends Camera3D
## The camera on the field: free, with the same controls and Options as in a
## fight (camera keys / right stick / right-drag turn and tilt, the wheel
## zooms, Camera speed, Mouse sensitivity, Invert camera), but each room
## (loading area) has its own set angle, and entering a room snaps back to
## it, like older games. The reset key goes back to the room's angle too.
##
## It follows the leader smoothly. Walls on its side of the room are cut
## away (FieldRoom.cut_away), so it never has to pull in for them; it only
## pulls in for things on the camera-block layer (CAMERA_BLOCK_LAYER, e.g.
## a low ceiling later).

const TURN_DEGREES_PER_SECOND := 100.0
const TILT_DEGREES_PER_SECOND := 60.0
const MOUSE_SENSITIVITY := 0.3
const FOLLOW_SPEED := 5.0
const MIN_PITCH := 15.0
const MAX_PITCH := 75.0
const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 18.0
## Closest it pulls in to the leader when a wall is in the way.
const WALL_MIN := 1.5
## Physics layer of shapes the camera won't go through.
const CAMERA_BLOCK_LAYER := 4
## What it looks at: this far above the leader's feet.
const LOOK_HEIGHT := 1.0

var target: Node3D = null
var yaw := 0.0
var pitch := 40.0
var distance := 10.0
## The room's set angle (reset_view / the reset key).
var home_yaw := 0.0
var home_pitch := 40.0
var home_distance := 10.0
var focus := Vector3.ZERO
## The camera input is ignored (menus, room changes).
var locked := false


func _ready() -> void:
	fov = 55.0
	far = 200.0


## Sets the room's angle and jumps straight to it (entering a room).
func set_home(new_yaw: float, new_pitch: float, new_distance: float) -> void:
	home_yaw = new_yaw
	home_pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	home_distance = clampf(new_distance, MIN_DISTANCE, MAX_DISTANCE)
	reset_view()
	if target:
		focus = target.global_position + Vector3(0, LOOK_HEIGHT, 0)
	_place()


func reset_view() -> void:
	yaw = home_yaw
	pitch = home_pitch
	distance = home_distance


func _process(delta: float) -> void:
	if not locked:
		var turn := Input.get_axis("camera_left", "camera_right")
		yaw -= turn * _turn_sign() * TURN_DEGREES_PER_SECOND * Settings.camera_speed() / 100.0 * delta
		if InputMap.has_action("camera_tilt_up"):
			var tilt := Input.get_axis("camera_tilt_up", "camera_tilt_down")
			pitch = clampf(pitch + tilt * _tilt_sign() * TILT_DEGREES_PER_SECOND * Settings.camera_speed() / 100.0 * delta,
					MIN_PITCH, MAX_PITCH)
	if target:
		var want := target.global_position + Vector3(0, LOOK_HEIGHT, 0)
		focus = focus.lerp(want, 1.0 - exp(-FOLLOW_SPEED * delta))
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		var mouse := MOUSE_SENSITIVITY * Settings.mouse_sensitivity() / 100.0
		yaw -= event.relative.x * mouse * _turn_sign()
		pitch = clampf(pitch + event.relative.y * mouse * _tilt_sign(), MIN_PITCH, MAX_PITCH)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		distance = maxf(distance * 0.9, MIN_DISTANCE)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		distance = minf(distance * 1.1, MAX_DISTANCE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_reset"):
		reset_view()
		get_viewport().set_input_as_handled()


## Turns a stick / WASD input into a direction on the floor, relative to the
## camera (up always walks away from the screen).
func relative(input: Vector2) -> Vector3:
	var right := global_basis.x
	var forward := -global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


func _place() -> void:
	global_rotation_degrees = Vector3(-pitch, yaw, 0.0)
	var back := global_basis.z
	var reach := distance
	# Something on the camera-block layer in the way: come in front of it.
	if is_inside_tree() and get_world_3d() != null:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(focus, focus + back * distance, 1 << (CAMERA_BLOCK_LAYER - 1))
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			reach = maxf(focus.distance_to(hit["position"]) - 0.3, WALL_MIN)
	global_position = focus + back * reach


func _turn_sign() -> float:
	return -1.0 if Settings.invert_x() else 1.0


func _tilt_sign() -> float:
	return -1.0 if Settings.invert_y() else 1.0
