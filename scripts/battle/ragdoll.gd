class_name Ragdoll
extends Node3D
## A physics ragdoll for a figure (Figure.build): the torso, head, arms and
## legs become rigid bodies held together at the neck, shoulders and hips
## by cone-twist joints, and the figure's parts move under them. It's
## visual only: the fight still goes by the fighter's own position.
##
## Named "Limp" and kept under the fighter (top level, so it doesn't follow
## it), so "is this fighter limp?" stays a node lookup. restore() puts every
## part back where it was and frees the rig; blend_to_stand() first eases
## the parts from wherever they lie back to standing.

## Its own collision layer: ragdolls hit the floor and each other only.
const LAYER := 1 << 15
## Gravity, scaled to the fight's feel (the old scripted fall used 22).
const GRAVITY_SCALE := 2.1

## Per limb: [swing limit in degrees, mass, which way it points from its
## joint: 1 up (the head), -1 down (arms and legs)].
const LIMBS := {
	"Head": [35.0, 0.9, 1],
	"ArmL": [85.0, 0.6, -1],
	"ArmR": [85.0, 0.6, -1],
	"LegL": [50.0, 0.8, -1],
	"LegR": [50.0, 0.8, -1],
}
## Left out of the collision boxes (long, thin, sticking out): they'd make
## the bodies prop up on them.
const NO_BOX := ["WeapR", "WeapL", "Tail", "TrailBase", "TrailTip", "TrailBase2", "TrailTip2"]

var fighter: Node3D
var torso: RigidBody3D
var bodies: Array[RigidBody3D] = []

## Played the first time the torso hits the floor after each launch ("" =
## silent): see Sfx.
var land_sound := ""
var _airborne := false

var _moved: Array = []  # [node, parent, rest local transform, child index]
var _blend_t := -1.0
var _blend_len := 0.35
var _blend_from: Array = []
var _blend_to: Array = []


static func build(who: Node3D, body_rest: Vector3) -> Ragdoll:
	var body := who.get_node_or_null("Body") as Node3D
	if body == null:
		return null
	var rig := Ragdoll.new()
	rig.name = "Limp"
	rig.fighter = who
	rig.top_level = true
	who.add_child(rig)
	rig.global_transform = Transform3D.IDENTITY
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LAYER
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	rig.add_child(floor_body)
	# Limbs first (they come off the torso), then the torso itself.
	var limbs := {}
	for limb_name in LIMBS:
		var joint := body.get_node_or_null(limb_name) as Node3D
		if joint != null:
			limbs[limb_name] = joint
	var limb_bodies := {}
	for limb_name in limbs:
		var joint: Node3D = limbs[limb_name]
		var rest := Transform3D(Basis.from_scale(joint.transform.basis.get_scale()), joint.position)
		limb_bodies[limb_name] = rig._make_body(joint, float(LIMBS[limb_name][1]), rest)
	var body_rest_tf := Transform3D(Basis.from_scale(body.transform.basis.get_scale()), body_rest)
	rig.torso = rig._make_body(body, 3.0, body_rest_tf)
	rig.torso.contact_monitor = true
	rig.torso.max_contacts_reported = 2
	rig.torso.body_entered.connect(rig._torso_touched)
	for limb_name in limb_bodies:
		rig._join(limb_bodies[limb_name], float(LIMBS[limb_name][0]), int(LIMBS[limb_name][2]))
	# One figure doesn't collide with itself (the parts start overlapping).
	for a in rig.bodies:
		for b in rig.bodies:
			if a != b:
				a.add_collision_exception_with(b)
	return rig


func _make_body(part: Node3D, mass: float, rest: Transform3D) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.collision_layer = LAYER
	rb.collision_mask = LAYER
	rb.gravity_scale = GRAVITY_SCALE
	rb.linear_damp = 0.15
	rb.angular_damp = 0.8
	rb.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.2
	rb.physics_material_override = mat
	add_child(rb)
	var at := part.global_transform
	rb.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
	# The torso's box is the torso alone: robes, capes and shells hang off
	# it and would stand it up like a crate.
	var box := _bounds(part, rb.global_transform.affine_inverse(), part.name == "Body")
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3(0.1, 0.1, 0.1))
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.position = box.get_center()
	rb.add_child(holder)
	_moved.append([part, part.get_parent(), rest, part.get_index()])
	part.get_parent().remove_child(part)
	rb.add_child(part)
	part.global_transform = at
	bodies.append(rb)
	return rb


## The box round a part's meshes, in `to_local` space (skipping NO_BOX
## parts and anything already moved to a body of its own).
func _bounds(part: Node3D, to_local: Transform3D, own_only := false) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [part]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != part and (String(n.name) in NO_BOX or String(n.name) in LIMBS):
			continue
		if n is MeshInstance3D and n.is_visible_in_tree() and not (n as Node3D).top_level:
			var aabb: AABB = (n as MeshInstance3D).get_aabb()
			if aabb.size.length() > 0.001:
				var placed: AABB = (to_local * (n as Node3D).global_transform) * aabb
				box = placed if first else box.merge(placed)
				first = false
		if own_only:
			break
		for c in n.get_children():
			stack.append(c)
	if first:
		return AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
	return box


func _join(limb: RigidBody3D, swing_degrees: float, points: int) -> void:
	var joint := ConeTwistJoint3D.new()
	add_child(joint)
	# The cone's axis is the joint's X: along the limb (down, or up for the head).
	joint.global_transform = Transform3D(torso.global_basis * Basis(Vector3.BACK, PI / 2.0 * points), limb.global_position)
	joint.node_a = joint.get_path_to(torso)
	joint.node_b = joint.get_path_to(limb)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing_degrees))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(25.0))


## Thrown: every part takes `velocity`; the torso spins by `spin` (the limbs
## a little more, at random, so they flail).
func launch(velocity: Vector3, spin: Vector3) -> void:
	for rb in bodies:
		rb.freeze = false
		rb.linear_velocity = velocity
		var flail := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 4.0
		rb.angular_velocity = spin if rb == torso else spin + flail
	_blend_t = -1.0
	_airborne = true


func _torso_touched(other: Node) -> void:
	if _airborne and other is StaticBody3D:
		_airborne = false
		if land_sound != "":
			Sfx.play(land_sound)


func settled() -> bool:
	for rb in bodies:
		if not rb.freeze and not rb.sleeping and rb.linear_velocity.length() > 0.15:
			return false
	return true


func freeze_all() -> void:
	for rb in bodies:
		rb.freeze = true


## Gone: the bodies stop and the whole heap sinks through the floor.
func sink(seconds: float) -> void:
	freeze_all()
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()  # its floor (no longer needed)
	var t := create_tween()
	t.tween_property(self, "position:y", -1.6, seconds).set_ease(Tween.EASE_IN)


func blending() -> bool:
	return _blend_t >= 0.0


## Getting up: the bodies stop and every part eases from where it lies to
## its standing place on the fighter, over `seconds`.
func blend_to_stand(seconds: float) -> void:
	freeze_all()
	_blend_len = maxf(seconds, 0.05)
	_blend_t = 0.0
	_blend_from.clear()
	_blend_to.clear()
	var goal := {}
	for i in range(_moved.size() - 1, -1, -1):  # the torso first: the limbs hang off it
		var entry: Array = _moved[i]
		var parent: Node = entry[1]
		var base: Transform3D = goal[parent] if goal.has(parent) else (parent as Node3D).global_transform
		goal[entry[0]] = base * (entry[2] as Transform3D)
	for entry in _moved:
		_blend_from.append((entry[0] as Node3D).global_transform)
		_blend_to.append(goal[entry[0]])


func _process(delta: float) -> void:
	if _blend_t < 0.0:
		return
	_blend_t = minf(_blend_t + delta / _blend_len, 1.0)
	var k := _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
	for i in _moved.size():
		var part: Node3D = _moved[i][0]
		part.global_transform = (_blend_from[i] as Transform3D).interpolate_with(_blend_to[i], k)


## Every part back on the fighter at its standing place; the rig is gone.
func restore() -> void:
	for i in range(_moved.size() - 1, -1, -1):
		var entry: Array = _moved[i]
		var part: Node3D = entry[0]
		var parent: Node = entry[1]
		if not is_instance_valid(part) or not is_instance_valid(parent):
			continue
		part.get_parent().remove_child(part)
		parent.add_child(part)
		parent.move_child(part, mini(int(entry[3]), parent.get_child_count() - 1))
		part.transform = entry[2]
	_moved.clear()
	name = "LimpGone"
	queue_free()
