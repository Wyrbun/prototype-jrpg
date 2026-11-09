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
## Rectangle: which edges are a lethal drop (marked by a glowing death wall
## lined with skulls). Fighters pushed over one fall out of the fight;
## walking into one asks for a Parry-like save. The other edges are walls.
@export_flags("North (-Z)", "East (+X)", "South (+Z)", "West (-X)") var lethal_sides: int = 0:
	set(value):
		lethal_sides = value
		_rebuild_floor()
## Circle: the whole rim is a lethal drop.
@export var lethal_rim := false:
	set(value):
		lethal_rim = value
		_rebuild_floor()

## Rocks only block sight where they're this solid (1 = their full size).
## A bit under 1 means an attack that just grazes a rock still gets through.
const SIGHT_SHRINK := 0.85
## How far ahead walkers look for obstacles to go around.
const LOOK_AHEAD := 1.2
const EDGE_WIDTH := 0.25
const DEATH_RED := Color(1.0, 0.18, 0.15)
## lethal_sides bits, in the order of the rectangle's sides.
const SIDE_NORTH := 1
const SIDE_EAST := 2
const SIDE_SOUTH := 4
const SIDE_WEST := 8

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
## lethal_open: lethal edges and holes don't hold it back (forced moves and
## the steered fighter's walking; the battle then checks lethal_at).
func keep_inside(fighter: Node3D, body_radius: float, lethal_open: bool = false) -> void:
	var p := fighter.global_position
	for obstacle in obstacles():
		if lethal_open and obstacle.is_lethal():
			continue
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
		if flat.length() > limit and not (lethal_open and lethal_rim):
			flat = flat.normalized() * limit
			p.x = flat.x
			p.z = flat.z
	else:
		var hx := size.x / 2.0 - body_radius
		var hz := size.y / 2.0 - body_radius
		var open := lethal_sides if lethal_open else 0
		p.x = clampf(p.x, -INF if open & SIDE_WEST else -hx, INF if open & SIDE_EAST else hx)
		p.z = clampf(p.z, -INF if open & SIDE_NORTH else -hz, INF if open & SIDE_SOUTH else hz)
	fighter.global_position = p


## True if a point is over a lethal drop: in a hole, or past a lethal edge.
func lethal_at(point: Vector3) -> bool:
	var p := point - global_position
	for obstacle in obstacles():
		if obstacle.is_lethal() and Vector2(point.x - obstacle.global_position.x, point.z - obstacle.global_position.z).length() < obstacle.radius:
			return true
	if shape == Shape.CIRCLE:
		return lethal_rim and Vector2(p.x, p.z).length() > size.x / 2.0
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	return (lethal_sides & SIDE_EAST and p.x > hx) or (lethal_sides & SIDE_WEST and p.x < -hx) \
			or (lethal_sides & SIDE_SOUTH and p.z > hz) or (lethal_sides & SIDE_NORTH and p.z < -hz)


## Which way is back to safety from a point at (or over) a lethal drop.
func inward(point: Vector3) -> Vector3:
	for obstacle in obstacles():
		if obstacle.is_lethal():
			var off := Vector3(point.x - obstacle.global_position.x, 0.0, point.z - obstacle.global_position.z)
			if off.length() < obstacle.radius + 1.0:
				return off.normalized() if off.length() > 0.01 else Vector3.BACK
	var p := point - global_position
	p.y = 0.0
	if shape == Shape.CIRCLE:
		return -p.normalized() if p.length() > 0.01 else Vector3.BACK
	# The nearest side.
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	var gaps := {Vector3.LEFT: hx - p.x, Vector3.RIGHT: p.x + hx, Vector3.FORWARD: hz - p.z, Vector3.BACK: p.z + hz}
	var best := Vector3.BACK
	var best_gap := INF
	for dir in gaps:
		if gaps[dir] < best_gap:
			best_gap = gaps[dir]
			best = dir
	return best


## True if the arena has any lethal edge or hole.
func has_drops() -> bool:
	if lethal_sides != 0 or lethal_rim:
		return true
	for obstacle in obstacles():
		if obstacle.is_lethal():
			return true
	return false


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
			if not lethal_rim:
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
			if lethal_sides & (1 << i):
				continue  # a drop: drawn as a death wall instead (below)
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
	_add_death_walls()


## Lethal edges: a thin glowing red line just inside the drop, lined with
## skulls, so it reads at a glance as "don't go past here".
func _add_death_walls() -> void:
	var paths: Array = []  # each: [from, to] along a lethal edge
	if shape == Shape.CIRCLE:
		if lethal_rim:
			var r := size.x / 2.0
			for i in 72:
				var a0 := TAU * i / 72.0
				var a1 := TAU * (i + 1) / 72.0
				paths.append([Vector3(cos(a0), 0, sin(a0)) * r, Vector3(cos(a1), 0, sin(a1)) * r])
	else:
		var hx := size.x / 2.0
		var hz := size.y / 2.0
		var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
		for i in 4:
			if lethal_sides & (1 << i):
				paths.append([corners[i], corners[(i + 1) % 4]])
	if paths.is_empty():
		return
	var strip := PackedVector3Array()
	var skull_spots: Array[Vector3] = []
	var carry := 0.0
	for path in paths:
		var a: Vector3 = path[0]
		var b: Vector3 = path[1]
		var along := (b - a)
		var length := along.length()
		var inward_dir := Vector3.UP.cross(along.normalized())  # sides run clockwise seen from above: left is inside
		if inward_dir.dot(-((a + b) / 2.0)) < 0.0:
			inward_dir = -inward_dir
		var w := 0.18
		var lift := Vector3(0, 0.04, 0)
		var a_in := a + inward_dir * 0.15
		var b_in := b + inward_dir * 0.15
		strip.append_array([a_in + lift, b_in + lift, b_in + inward_dir * w + lift,
				a_in + lift, b_in + inward_dir * w + lift, a_in + inward_dir * w + lift])
		var d := 1.6 - carry
		while d < length:
			skull_spots.append(a + along.normalized() * d + inward_dir * 0.75)
			d += 1.6
		carry = length - (d - 1.6)
	var wall := MeshInstance3D.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = strip
	var wall_mesh := ArrayMesh.new()
	wall_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = DEATH_RED
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_mesh.surface_set_material(0, glow)
	wall.mesh = wall_mesh
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor.add_child(wall)
	for spot in skull_spots:
		_floor.add_child(ArenaObstacle.make_skull(spot))
