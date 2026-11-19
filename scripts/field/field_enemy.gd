class_name FieldEnemy
extends CharacterBody3D
## An enemy standing in a room, seen before the fight. Put one in a room's
## scene (under an "Enemies" node), pick its fighter scene, and set it up:
##
## - Patrolling: give it a "Patrol" child with Marker3D points (room
##   coordinates). It walks them in order: round and round (patrol_loop)
##   or there and back. pause_at_points: seconds it stops at each.
## - Standing guard (no Patrol child): it turns between look_angles
##   (degrees, from where it starts facing), look_seconds at each.
## - Sight (sense):
##   CONE: it sees sight_range metres ahead in a sight_angle cone, drawn on
##   the floor. Walls block it. Running within hear_radius (all round) gets
##   you noticed too; sneaking doesn't.
##   CIRCLE: a full circle of sight_range, drawn on the floor, but only
##   running inside it gets you noticed (walking / sneaking doesn't).
##   Either way, touching it does.
##
## While it hasn't seen you, it only moves when you move, at your pace
## (standing still freezes it; sneaking or a half-pushed stick slows it).
## Once it sees you: a "!", a moment's start, then it chases in real time,
## faster than it patrols. If you stay out of its sight (or far enough
## away) for give_up_seconds, it gives up and walks back to where it
## started, at your pace again, still watching.
##
## Touching the leader, or being hit by the leader's swing, starts a fight
## (the field decides how; see FieldScene.engage).

enum Sense { CONE, CIRCLE }
enum State { UNAWARE, NOTICED, CHASE, RETURN }

const LAYER := 5
## Behind: the attacker is in its back arc (as in a fight, Combatant.is_behind).
const BEHIND_DOT := -0.5

@export var fighter_scene: PackedScene
@export var sense := Sense.CONE
@export var sight_range := 7.0
@export_range(10.0, 180.0) var sight_angle := 70.0
## Running this close gets you noticed from any side (CONE).
@export var hear_radius := 2.5
@export var patrol_speed := 1.6
@export var patrol_loop := true
@export var pause_at_points := 1.0
@export var look_angles: PackedFloat32Array = PackedFloat32Array([0.0, 60.0, 0.0, -60.0])
@export var look_seconds := 2.0
## Chasing: faster than its patrol, a little slower than you at full speed
## (4.5 m/s), so you can outrun it.
@export var chase_speed := 4.0
@export var give_up_seconds := 2.5
## Seconds between the "!" and the chase.
@export var notice_seconds := 0.45

const TURN_SPEED := 4.0  # radians per second (paced while unaware)
const TOUCH_GAP := 0.15  # metres between bodies that counts as touching
const GRAVITY := 20.0
const CONE_SEGMENTS := 32
const CONE_REFRESH := 0.1
const CALM := Color(0.85, 0.78, 0.45, 0.22)
const ALARM := Color(0.9, 0.35, 0.3, 0.3)

var figure: Combatant = null
var body_radius := 0.45
var state := State.UNAWARE
var facing := 0.0
## Set by the field each physics frame: the leader, and how fast it's going
## as a share of its full speed (0..1): unaware enemies move at this pace.
var leader: FieldWalker = null
var pace := 0.0
## True if the leader is moving faster than a sneak (running).
var leader_running := false
## Out of play (beaten, or taken out for now).
var gone := false
## Seconds it can't notice anyone (the party just escaped a fight).
var calm_left := 0.0

var _home := Vector3.ZERO
var _home_facing := 0.0
var _points: Array[Vector3] = []
var _point_i := 0
var _point_dir := 1
var _wait := 0.0
var _look_i := 0
var _look_t := 0.0
var _notice_t := 0.0
var _lost_t := 0.0
var _cone: MeshInstance3D
var _cone_t := 0.0
var _cone_mat: StandardMaterial3D
var _cone_facing := 0.0
var _cone_at := Vector3.ZERO
var _alert: Label3D

signal spotted(enemy: FieldEnemy)
signal touched(enemy: FieldEnemy)


func _ready() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
	if fighter_scene:
		figure = fighter_scene.instantiate() as Combatant
		add_child(figure)
		body_radius = figure.body_radius
		for label in figure.find_children("*", "Label3D", true, false):
			(label as Label3D).visible = false
		# Its fight-time attack area isn't shown out here (the sight is).
		var area := figure.get_node_or_null("AttackRange") as Node3D
		if area:
			area.visible = false
			area.process_mode = Node.PROCESS_MODE_DISABLED
		figure.remove_from_group("combatants")
	# Patrol points are read before the body's turn is moved onto the
	# figure (they're set out relative to the enemy as placed).
	var patrol := get_node_or_null("Patrol")
	if patrol:
		for p in patrol.get_children():
			if p is Node3D:
				_points.append((p as Node3D).global_position)
	facing = rotation.y
	rotation.y = 0.0
	_home = global_position
	_home_facing = facing
	_build_cone()
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.pixel_size = 0.012
	_alert.outline_size = 24
	_alert.outline_modulate = Color(0.1, 0.06, 0.02)
	_alert.modulate = Color(1.0, 0.85, 0.3)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position.y = 2.6
	_alert.visible = false
	add_child(_alert)
	_face_figure()


## Back where it started, unaware (the room resets).
func reset() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	facing = _home_facing
	state = State.UNAWARE
	_point_i = 0
	_point_dir = 1
	_wait = 0.0
	_look_i = 0
	_look_t = 0.0
	_lost_t = 0.0
	_alert.visible = false
	_face_figure()


## Taken out of the room until it's entered again.
func remove() -> void:
	gone = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	collision_layer = 0


func flat_forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


## True if this point is in its back arc.
func is_behind(point: Vector3) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return false
	return flat_forward().dot(to.normalized()) <= BEHIND_DOT


func is_aware() -> bool:
	return state == State.NOTICED or state == State.CHASE


func _physics_process(delta: float) -> void:
	if gone:
		return
	var want := Vector3.ZERO
	calm_left = maxf(calm_left - delta, 0.0)
	match state:
		State.UNAWARE:
			want = _unaware(delta)
			if _sees_leader():
				_notice()
		State.RETURN:
			want = _walk_to(_home, patrol_speed * pace, delta)
			if Vector2(global_position.x - _home.x, global_position.z - _home.z).length() < 0.2:
				state = State.UNAWARE
				_wait = pause_at_points
			if _sees_leader():
				_notice()
		State.NOTICED:
			_notice_t -= delta
			if leader:
				_turn_to(leader.global_position, delta, 1.0)
			if _notice_t <= 0.0:
				state = State.CHASE
				_lost_t = 0.0
		State.CHASE:
			if leader:
				want = _walk_to(leader.global_position, chase_speed, delta, 1.0)
				var in_view := _distance_to_leader() <= sight_range * 1.4 and _clear_line(leader.global_position)
				_lost_t = 0.0 if in_view else _lost_t + delta
				if _lost_t >= give_up_seconds:
					state = State.RETURN
					_alert.visible = false
	velocity.x = want.x
	velocity.z = want.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_face_figure()
	if leader and calm_left <= 0.0 and _distance_to_leader() <= body_radius + 0.35 + TOUCH_GAP:
		touched.emit(self)
	# Rebuilt when it turns or moves (the walls cut it short from where it
	# stands), and every so often anyway.
	_cone_t -= delta
	if _cone_t <= 0.0 or absf(facing - _cone_facing) > 0.01 or global_position.distance_to(_cone_at) > 0.05:
		_cone_t = CONE_REFRESH
		_update_cone()


func _distance_to_leader() -> float:
	var d := leader.global_position - global_position
	d.y = 0.0
	return d.length()


## Patrol or guard, at the leader's pace.
func _unaware(delta: float) -> Vector3:
	if pace <= 0.0:
		return Vector3.ZERO
	var paced := delta * pace
	if _points.is_empty():
		_look_t += paced
		if _look_t >= look_seconds and look_angles.size() > 0:
			_look_t = 0.0
			_look_i = (_look_i + 1) % look_angles.size()
		if look_angles.size() > 0:
			var aim := _home_facing + deg_to_rad(look_angles[_look_i])
			facing = rotate_toward(facing, aim, TURN_SPEED * paced)
		return _walk_to(_home, patrol_speed * pace, delta) if global_position.distance_to(_home) > 0.3 else Vector3.ZERO
	if _wait > 0.0:
		_wait -= paced
		return Vector3.ZERO
	var target := _points[_point_i]
	if Vector2(global_position.x - target.x, global_position.z - target.z).length() < 0.2:
		_wait = pause_at_points
		_next_point()
		return Vector3.ZERO
	return _walk_to(target, patrol_speed * pace, delta)


func _next_point() -> void:
	if _points.size() < 2:
		return
	if patrol_loop:
		_point_i = (_point_i + 1) % _points.size()
		return
	if _point_i + _point_dir < 0 or _point_i + _point_dir >= _points.size():
		_point_dir = -_point_dir
	_point_i += _point_dir


## A velocity toward a point (flat), turning to face it.
func _walk_to(point: Vector3, speed: float, delta: float, turn_pace := -1.0) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.05 or speed <= 0.0:
		return Vector3.ZERO
	_turn_to(point, delta, pace if turn_pace < 0.0 else turn_pace)
	return to.normalized() * speed


func _turn_to(point: Vector3, delta: float, turn_pace: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	facing = rotate_toward(facing, atan2(-to.x, -to.z), TURN_SPEED * 2.0 * turn_pace * delta)


func _face_figure() -> void:
	if figure:
		figure.rotation.y = facing
	if _cone:
		_cone.rotation.y = facing


func _notice() -> void:
	state = State.NOTICED
	_notice_t = notice_seconds
	_alert.visible = true
	_update_cone()
	spotted.emit(self)


func _sees_leader() -> bool:
	if leader == null or calm_left > 0.0:
		return false
	var dist := _distance_to_leader()
	match sense:
		Sense.CIRCLE:
			return leader_running and dist <= sight_range and _clear_line(leader.global_position)
		_:
			if leader_running and dist <= hear_radius and _clear_line(leader.global_position):
				return true
			if dist > sight_range:
				return false
			var to := leader.global_position - global_position
			to.y = 0.0
			if to.length() > 0.01 and flat_forward().dot(to.normalized()) < cos(deg_to_rad(sight_angle * 0.5)):
				return false
			return _clear_line(leader.global_position)


## No wall (layer 1) between its eyes and that point's chest height.
func _clear_line(point: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.2, 0), point + Vector3(0, 1.0, 0), 1)
	return space.intersect_ray(query).is_empty()


# --- The sight shape on the floor -----------------------------------------

func _build_cone() -> void:
	_cone = MeshInstance3D.new()
	_cone.position.y = 0.04
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = false
	_cone_mat.albedo_color = CALM
	_cone.material_override = _cone_mat
	add_child(_cone)


## Rebuilds the floor shape: a fan cut short by walls (CONE) or a ring
## (CIRCLE), calm or alarmed.
func _update_cone() -> void:
	if _cone == null:
		return
	_cone_mat.albedo_color = ALARM if is_aware() else CALM
	_cone_facing = facing
	_cone_at = global_position
	var verts := PackedVector3Array()
	var full := sense == Sense.CIRCLE
	var half := PI if full else deg_to_rad(sight_angle * 0.5)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var eye := global_position + Vector3(0, 0.5, 0)
	var reach: Array[float] = []
	for i in CONE_SEGMENTS + 1:
		var a := -half + 2.0 * half * i / CONE_SEGMENTS
		var local := Vector3(-sin(a), 0, -cos(a))  # around -Z, in the cone's frame
		var r := sight_range
		if space and not full:
			var world_dir := local.rotated(Vector3.UP, facing)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + world_dir * sight_range, 1))
			if not hit.is_empty():
				r = eye.distance_to(hit["position"])
		reach.append(r)
	for i in CONE_SEGMENTS:
		var a0 := -half + 2.0 * half * i / CONE_SEGMENTS
		var a1 := -half + 2.0 * half * (i + 1) / CONE_SEGMENTS
		var p0 := Vector3(-sin(a0), 0, -cos(a0)) * reach[i]
		var p1 := Vector3(-sin(a1), 0, -cos(a1)) * reach[i + 1]
		if full:
			# A ring: the outer 0.35 m only, so the floor inside still reads.
			var q0 := p0 * ((sight_range - 0.35) / sight_range)
			var q1 := p1 * ((sight_range - 0.35) / sight_range)
			verts.append_array([q0, p0, p1, q0, p1, q1])
		else:
			verts.append_array([Vector3.ZERO, p0, p1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cone.mesh = mesh
