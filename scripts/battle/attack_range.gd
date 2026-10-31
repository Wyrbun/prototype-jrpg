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
##   of the loaded skill. Touching a live offensive area makes the enemy
##   use its skill on you.

## Dormant reach, in meters.
@export var radius: float = 3.0
## Dormant width. 360 makes it a full circle.
@export_range(10.0, 360.0) var angle_degrees: float = 120.0
@export var dormant_color: Color = Color(0.9, 0.9, 0.95, 0.08)

const SEGMENTS := 40

var live := false
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
	mesh = _build_cone_mesh()
	_refresh_color()


## Reshapes the area for a loaded skill and makes it live.
func show_skill(new_radius: float, new_angle: float, color: Color) -> void:
	radius = new_radius
	angle_degrees = new_angle
	_live_color = color
	live = true
	mesh = _build_cone_mesh()
	_refresh_color()


## Back to the faint, harmless default shape.
func go_dormant() -> void:
	radius = _base_radius
	angle_degrees = _base_angle
	live = false
	_alert = false
	mesh = _build_cone_mesh()
	_refresh_color()


## True if a point (plus an optional body radius) is inside the area.
func contains(point: Vector3, extra_radius: float = 0.0) -> bool:
	var to_point := point - global_position
	to_point.y = 0.0
	var distance := to_point.length()
	if distance > radius + extra_radius:
		return false
	if distance < 0.001 or angle_degrees >= 360.0:
		return true
	var forward := -global_basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to_point)) <= angle_degrees / 2.0


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


## Builds a flat fan of triangles pointing forward (-Z), lying on the floor.
func _build_cone_mesh() -> ArrayMesh:
	var half := deg_to_rad(angle_degrees) / 2.0
	var vertices := PackedVector3Array()
	for i in SEGMENTS:
		var a0 := -half + 2.0 * half * i / SEGMENTS
		var a1 := -half + 2.0 * half * (i + 1) / SEGMENTS
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
		vertices.append(Vector3(sin(a1), 0.0, -cos(a1)) * radius)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var cone := ArrayMesh.new()
	cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return cone
