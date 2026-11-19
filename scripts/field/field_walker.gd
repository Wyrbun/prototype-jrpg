class_name FieldWalker
extends CharacterBody3D
## One party member walking on the field: the leader (steered with the move
## keys / left stick, relative to the camera) or a follower (walks the
## leader's trail, a set distance behind, like in more modern games).
##
## The figure is the class's own fighter scene (knight.tscn, ...), so the
## look and the walk cycle are the same as in a fight (FigureAnim follows
## how fast the figure really moves). Its floating name and reach ring are
## hidden out here.
##
## Physics: the room's floors, walls and ramps are on layer 1. The leader is
## on layer 2 (doors look for it), followers on layer 3; neither bumps into
## the other, so the party never jams in a doorway.

const LEADER_LAYER := 2
const FOLLOWER_LAYER := 3

## Metres per second at full stick. (The walk cycle is at full stride from
## 4 m/s.)
@export var walk_speed := 4.5
## How quickly it gets up to speed and stops (m/s per second).
@export var acceleration := 30.0
## Degrees per second it turns to face where it's going.
@export var turn_speed := 720.0
const GRAVITY := 20.0

## The fighter scene shown (its Combatant: the figure, the walk cycle).
var figure: Combatant = null
## True for the one you steer.
var is_leader := false
## Followers: who they walk behind (the leader), and how far back along
## the leader's trail they stay, in metres.
var leader: FieldWalker = null
var follow_distance := 1.4
## Leader only: where it has walked, newest last (followers read it).
var trail: Array[Vector3] = []
const TRAIL_STEP := 0.15
const TRAIL_MAX := 200
## Set by the field: no steering (room changes, menus).
var frozen := false
## Seconds left of a field swing (no walking meanwhile).
var swing_left := 0.0
## Leader: how fast it's really going, as a share of walk_speed (0..1).
## Unaware enemies move at this pace.
var pace := 0.0
## Leader: the steering direction this frame, on the floor (length 0-1),
## worked out by the field from the input and the camera.
var steer := Vector3.ZERO
## Where it faces (radians about Y; 0 = -Z, as fighters do).
var facing := 0.0


static func make(scene: PackedScene, leading: bool) -> FieldWalker:
	var w := FieldWalker.new()
	w.is_leader = leading
	w.name = "Leader" if leading else "Follower"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	w.add_child(shape)
	w.collision_layer = 1 << (LEADER_LAYER - 1) if leading else 1 << (FOLLOWER_LAYER - 1)
	w.collision_mask = 1
	w.floor_snap_length = 0.4
	w.floor_max_angle = deg_to_rad(50.0)
	w.figure = scene.instantiate() as Combatant
	w.add_child(w.figure)
	return w


func _ready() -> void:
	# Out of a fight: no floating name, no reach ring.
	var label := figure.get_node_or_null("NameLabel") as Node3D
	if label:
		label.visible = false
	figure.hide_reach = true
	figure.update_reach_ring(false, false)
	figure.remove_from_group("combatants")


## Puts it somewhere at once (a room's entry), facing a direction.
func place(at: Vector3, face: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	pace = 0.0
	facing = face
	figure.rotation.y = face
	if is_leader:
		trail.clear()


## Leader: refills the trail as a straight line behind it, so followers
## start out lined up behind (entering a room).
func lay_trail_behind(length: float) -> void:
	trail.clear()
	var back := Vector3(sin(facing), 0.0, cos(facing))  # +Z of the figure: behind it
	var steps := int(length / TRAIL_STEP)
	for i in range(steps, 0, -1):
		trail.append(global_position + back * TRAIL_STEP * i)
	trail.append(global_position)


func _physics_process(delta: float) -> void:
	var want := Vector3.ZERO
	swing_left = maxf(swing_left - delta, 0.0)
	if not frozen and swing_left <= 0.0:
		want = _leader_want() if is_leader else _follower_want()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.move_toward(want, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if flat.length() > 0.3:
		facing = rotate_toward(facing, atan2(-flat.x, -flat.z), deg_to_rad(turn_speed) * delta)
	figure.rotation.y = facing
	if is_leader:
		_record_trail()
		pace = clampf(Vector2(velocity.x, velocity.z).length() / walk_speed, 0.0, 1.0)


## The facing direction on the floor.
func flat_forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func _leader_want() -> Vector3:
	var s := steer
	if s.length() > 1.0:
		s = s.normalized()
	return s * walk_speed


## Followers walk to the point of the leader's trail that is
## follow_distance behind the leader (measured along the trail), catching
## up a bit faster when they fall behind.
func _follower_want() -> Vector3:
	if leader == null:
		return Vector3.ZERO
	var target := trail_point(leader, follow_distance)
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.12:
		return Vector3.ZERO
	# The leader's own speed, plus a little more for every metre behind.
	var lead_speed := Vector2(leader.velocity.x, leader.velocity.z).length()
	var speed := minf(lead_speed + dist * 4.0, leader.walk_speed * 1.35)
	return to / dist * speed


## The point on a leader's trail this many metres behind it.
static func trail_point(lead: FieldWalker, back: float) -> Vector3:
	var at := lead.global_position
	var left := back
	var i := lead.trail.size() - 1
	while i >= 0:
		var p: Vector3 = lead.trail[i]
		var step := Vector2(at.x - p.x, at.z - p.z).length()
		if step >= left:
			return at.lerp(p, left / maxf(step, 0.0001))
		left -= step
		at = p
		i -= 1
	return at


func _record_trail() -> void:
	if trail.is_empty():
		trail.append(global_position)
		return
	var last: Vector3 = trail[trail.size() - 1]
	if Vector2(global_position.x - last.x, global_position.z - last.z).length() >= TRAIL_STEP:
		trail.append(global_position)
		if trail.size() > TRAIL_MAX:
			trail.remove_at(0)
