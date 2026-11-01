class_name AttackRange
extends MeshInstance3D
## An enemy's area drawn on the floor.
##
## Put this as a child of an enemy. It turns with the enemy, so the area
## behind the enemy is safe, which is what makes flanking worthwhile.
##
## It has two looks:
## - Dormant: a faint outline showing the enemy's reach and facing. Harmless.
## - Live: while the enemy is casting, the area takes the shape and color
##   of the loaded skill. Anyone inside a live offensive area when the
##   enemy's turn comes is hit.

## Dormant reach, in meters.
@export var radius: float = 3.0
## Dormant width. 360 makes it a full circle.
@export_range(10.0, 360.0) var angle_degrees: float = 120.0
@export var dormant_color: Color = Color(0.9, 0.9, 0.95, 0.08)

const SEGMENTS := 40
## The color of an area whose skill is still hidden.
const HIDDEN_COLOR := Color(0.78, 0.78, 0.85)

var live := false
## The current shape (an EnemySkill.Shape). Dormant is always a cone.
var shape: int = EnemySkill.Shape.CONE
## Line width and donut hole size, used by those shapes.
var width: float = 1.2
var inner_radius: float = 0.0
var _live_color := Color.RED
var _alert := false
var _base_radius: float
var _base_angle: float
var _material: StandardMaterial3D


func _ready() -> void:
	_base_radius = radius
	_base_angle = angle_degrees
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _build_mesh()
	_refresh_color()


## Reshapes the area for a loaded skill and makes it live.
## hidden = true draws the shape in grey: you can see where it will land, not
## what it is (the skill is still "???").
## radius_override replaces the skill's radius (growing circles, lines
## stretched to reach a target).
func show_skill(skill: EnemySkill, hidden: bool = false, radius_override: float = -1.0) -> void:
	shape = skill.shape
	if skill.special == EnemySkill.Special.ON_EACH_TARGET or skill.special == EnemySkill.Special.GROWING \
			or skill.special == EnemySkill.Special.HEAL_ALLIES or skill.special == EnemySkill.Special.ON_MARKED:
		shape = EnemySkill.Shape.CIRCLE
	elif skill.special == EnemySkill.Special.LINE_TO_EACH:
		shape = EnemySkill.Shape.LINE
	radius = skill.radius if radius_override < 0.0 else radius_override
	angle_degrees = 360.0 if shape == EnemySkill.Shape.CIRCLE else skill.angle
	width = skill.width
	inner_radius = skill.inner_radius
	_live_color = HIDDEN_COLOR if hidden else skill.color()
	live = true
	mesh = _build_mesh()
	_refresh_color()


## Back to the faint, harmless default shape.
func go_dormant() -> void:
	shape = EnemySkill.Shape.CONE
	radius = _base_radius
	angle_degrees = _base_angle
	live = false
	_alert = false
	mesh = _build_mesh()
	_refresh_color()


## True if a point (plus an optional body radius) is inside the area.
func contains(point: Vector3, extra_radius: float = 0.0) -> bool:
	var to_point := point - global_position
	to_point.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var distance := to_point.length()
	match shape:
		EnemySkill.Shape.LINE:
			# A rectangle starting at the enemy and running forward.
			var along := to_point.dot(forward)
			var side := absf(to_point.dot(forward.cross(Vector3.UP)))
			return along >= -extra_radius and along <= radius + extra_radius \
					and side <= width / 2.0 + extra_radius
		EnemySkill.Shape.DONUT:
			# Safe close up and far away.
			return distance <= radius + extra_radius and distance >= inner_radius - extra_radius
	if distance > radius + extra_radius:
		return false
	if distance < 0.001 or angle_degrees >= 360.0:
		return true
	return rad_to_deg(forward.angle_to(to_point)) <= angle_degrees / 2.0


## A lingering hazard (a fire trail): always live, in its own color.
func show_hazard(skill: EnemySkill, color: Color) -> void:
	show_skill(skill)
	_live_color = color
	_refresh_color()


## Makes a live area glow brighter while someone is standing in it.
func set_alert(on: bool) -> void:
	if on != _alert:
		_alert = on
		_refresh_color()


func _refresh_color() -> void:
	if not live:
		_material.albedo_color = dormant_color
		return
	var c := _live_color
	c.a = 0.6 if _alert else 0.32
	_material.albedo_color = c


func _build_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	match shape:
		EnemySkill.Shape.LINE:
			var h := width / 2.0
			var corners := [Vector3(-h, 0, 0), Vector3(h, 0, 0), Vector3(h, 0, -radius), Vector3(-h, 0, -radius)]
			vertices.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
		EnemySkill.Shape.DONUT:
			var inner := clampf(inner_radius, 0.0, radius)
			for i in SEGMENTS:
				var a0 := TAU * i / SEGMENTS
				var a1 := TAU * (i + 1) / SEGMENTS
				var d0 := Vector3(sin(a0), 0.0, -cos(a0))
				var d1 := Vector3(sin(a1), 0.0, -cos(a1))
				vertices.append_array([d0 * inner, d0 * radius, d1 * radius, d0 * inner, d1 * radius, d1 * inner])
		_:
			# A flat fan of triangles pointing forward (-Z).
			var half := deg_to_rad(angle_degrees) / 2.0
			for i in SEGMENTS:
				var a0 := -half + 2.0 * half * i / SEGMENTS
				var a1 := -half + 2.0 * half * (i + 1) / SEGMENTS
				vertices.append(Vector3.ZERO)
				vertices.append(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
				vertices.append(Vector3(sin(a1), 0.0, -cos(a1)) * radius)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var area := ArrayMesh.new()
	area.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return area
