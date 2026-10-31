@tool
class_name Arena
extends Node3D
## A battlefield: its floor shape, edges, obstacles and starting spots.
##
## Each arena is its own scene in scenes/arenas/. Open one to move the rocks
## (ArenaObstacle children) and the PartySpawn / EnemySpawn markers around.
## The floor redraws as you change the shape and size in the Inspector.

enum Shape { RECTANGLE, CIRCLE }

@export var shape: Shape = Shape.RECTANGLE:
	set(value):
		shape = value
		_rebuild_floor()
## Rectangle: width (X) and depth (Z) in meters. Circle: X is the diameter.
@export var size: Vector2 = Vector2(16, 14):
	set(value):
		size = value
		_rebuild_floor()
@export var floor_color: Color = Color(0.32, 0.36, 0.33):
	set(value):
		floor_color = value
		_rebuild_floor()

## Rocks only block sight where they're this solid (1 = their full size).
## A bit under 1 means an attack that just grazes a rock still gets through.
const SIGHT_SHRINK := 0.85
## How far ahead walkers look for obstacles to go around.
const LOOK_AHEAD := 1.2
const EDGE_WIDTH := 0.25

var _floor: MeshInstance3D = null


func _ready() -> void:
	_rebuild_floor()


func obstacles() -> Array[ArenaObstacle]:
	var list: Array[ArenaObstacle] = []
	for child in get_children():
		if child is ArenaObstacle:
			list.append(child)
	return list


## Where a group starts and which way it faces. Fighters stand side by
## side around the marker, facing the other group's marker.
func spawn_points(enemy_side: bool, count: int) -> Array[Transform3D]:
	var own := _marker_position("EnemySpawn" if enemy_side else "PartySpawn", enemy_side)
	var other := _marker_position("PartySpawn" if enemy_side else "EnemySpawn", not enemy_side)
	var facing := (other - own)
	facing.y = 0.0
	facing = facing.normalized()
	var side := facing.cross(Vector3.UP)
	var spacing := 2.2
	var result: Array[Transform3D] = []
	for i in count:
		var offset := (i - (count - 1) / 2.0) * spacing
		var pos := own + side * offset
		var facing_basis := Basis.looking_at(facing, Vector3.UP)  # -Z points along facing
		result.append(Transform3D(facing_basis, pos))
	return result


## Pushes a fighter back inside the edges and out of every obstacle.
func keep_inside(fighter: Node3D, body_radius: float) -> void:
	var p := fighter.global_position
	for obstacle in obstacles():
		var offset := p - obstacle.global_position
		offset.y = 0.0
		var min_distance := obstacle.radius + body_radius
		if offset.length() < min_distance:
			var out := offset.normalized() if offset.length() > 0.001 else Vector3.RIGHT
			p = obstacle.global_position + out * min_distance
			p.y = fighter.global_position.y
	if shape == Shape.CIRCLE:
		var flat := Vector3(p.x, 0.0, p.z)
		var limit := size.x / 2.0 - body_radius
		if flat.length() > limit:
			flat = flat.normalized() * limit
			p.x = flat.x
			p.z = flat.z
	else:
		var hx := size.x / 2.0 - body_radius
		var hz := size.y / 2.0 - body_radius
		p.x = clampf(p.x, -hx, hx)
		p.z = clampf(p.z, -hz, hz)
	fighter.global_position = p


## Bends a walking direction around obstacles in the way, so fighters slide
## around rocks and the pit instead of getting stuck on them.
func steer(from: Vector3, direction: Vector3, body_radius: float) -> Vector3:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return direction
	direction = direction.normalized()
	for obstacle in obstacles():
		var to_center := obstacle.global_position - from
		to_center.y = 0.0
		var clearance := obstacle.radius + body_radius + 0.1
		var ahead := to_center.dot(direction)
		if ahead <= 0.0 or ahead > clearance + LOOK_AHEAD:
			continue
		var sideways := (to_center - direction * ahead).length()
		if sideways >= clearance:
			continue
		# Heading into it: walk along its edge, on the side we're already leaning to.
		var tangent := Vector3.UP.cross(to_center).normalized()
		if tangent.dot(direction) < 0.0:
			tangent = -tangent
		return tangent
	return direction


## False if a rock stands between two points (pits don't block sight).
func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for obstacle in obstacles():
		if not obstacle.blocks_sight():
			continue
		var c := Vector2(obstacle.global_position.x, obstacle.global_position.z)
		var ab := b - a
		var t := 0.0 if ab.length_squared() < 0.0001 else clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < obstacle.radius * SIGHT_SHRINK:
			return false
	return true


## A rough size, used to place the camera.
func extent() -> float:
	return maxf(size.x, size.y) / 2.0


func _marker_position(marker_name: String, enemy_side: bool) -> Vector3:
	var marker := get_node_or_null(marker_name) as Node3D
	if marker:
		return marker.global_position
	# No marker: start on opposite sides of the arena.
	var depth := (size.y if shape == Shape.RECTANGLE else size.x) / 2.0
	return Vector3(0, 0, -depth * 0.5 if enemy_side else depth * 0.5)


func _rebuild_floor() -> void:
	if not is_inside_tree():
		return
	if _floor:
		_floor.queue_free()
	_floor = MeshInstance3D.new()
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = floor_color
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = floor_color.darkened(0.55)
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	edge_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var ground := PackedVector3Array()
	var edge := PackedVector3Array()
	if shape == Shape.CIRCLE:
		var r := size.x / 2.0
		var segments := 72
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			ground.append_array([Vector3.ZERO, d0 * r, d1 * r])
			var lift := Vector3(0, 0.02, 0)
			edge.append_array([d0 * (r - EDGE_WIDTH) + lift, d0 * r + lift, d1 * r + lift,
					d0 * (r - EDGE_WIDTH) + lift, d1 * r + lift, d1 * (r - EDGE_WIDTH) + lift])
	else:
		var hx := size.x / 2.0
		var hz := size.y / 2.0
		ground.append_array([Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz),
				Vector3(-hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)])
		var outer := [Vector3(-hx, 0.02, -hz), Vector3(hx, 0.02, -hz), Vector3(hx, 0.02, hz), Vector3(-hx, 0.02, hz)]
		var w := EDGE_WIDTH
		var inner := [Vector3(-hx + w, 0.02, -hz + w), Vector3(hx - w, 0.02, -hz + w),
				Vector3(hx - w, 0.02, hz - w), Vector3(-hx + w, 0.02, hz - w)]
		for i in 4:
			var j := (i + 1) % 4
			edge.append_array([outer[i], outer[j], inner[j], outer[i], inner[j], inner[i]])

	var mesh := ArrayMesh.new()
	for part in [[ground, floor_material], [edge, edge_material]]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part[0]
		var normals := PackedVector3Array()
		normals.resize(part[0].size())
		normals.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
	_floor.mesh = mesh
	add_child(_floor)
