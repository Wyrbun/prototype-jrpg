class_name PositionalRing
extends Node3D
## The ring under an enemy that shows its positionals (like the target rings
## in Final Fantasy XIV), shown while the Assassin is steered:
## - an arrow at the front, a thin white arc round the front and sides, and
##   the rear arc (60 degrees either side of its back) in violet: that's where
##   "from behind" counts. The rear arc glows while the Assassin stands in it.
## - enemies without positionals (no_positionals) get one unbroken violet
##   ring and no arrow: every hit counts as from behind, from anywhere.
## It's a child of the enemy, so it turns with it.

const VIOLET := Color(0.7, 0.42, 1.0)
const REAR_HALF_ANGLE := 60.0
const GAP := 5.0  # degrees left open between the rear and the sides

var _rear_material: StandardMaterial3D
var _omni := false


func build(radius: float, omni: bool) -> void:
	_omni = omni
	position.y = 0.06
	if omni:
		_rear_material = _arc(radius, 0.16, 0.0, 360.0, Color(VIOLET, 0.75))
		_arc(radius - 0.28, 0.06, 0.0, 360.0, Color(VIOLET, 0.45))
		return
	# Front and sides: thin and pale. Rear: thick and violet.
	_arc(radius, 0.09, -(180.0 - REAR_HALF_ANGLE - GAP), 180.0 - REAR_HALF_ANGLE - GAP, Color(1, 1, 1, 0.7))
	_rear_material = _arc(radius, 0.26, 180.0 - REAR_HALF_ANGLE, 180.0 + REAR_HALF_ANGLE, Color(VIOLET, 0.85))
	_arrow(radius)


## Brighter while the Assassin is in the rear arc (or anywhere, for a full ring).
func set_lit(on: bool) -> void:
	if _rear_material:
		_rear_material.albedo_color = Color(VIOLET.lightened(0.35), 0.95) if on else Color(VIOLET, 0.75 if not _omni else 0.6)


## A flat arc from one angle to another, in degrees measured from the
## enemy's front (-Z), clockwise seen from above. Returns its material.
func _arc(radius: float, width: float, from_deg: float, to_deg: float, color: Color) -> StandardMaterial3D:
	var vertices := PackedVector3Array()
	var segments := maxi(int(absf(to_deg - from_deg) / 5.0), 2)
	for i in segments:
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / segments))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / segments))
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		vertices.append_array([d0 * (radius - width), d0 * radius, d1 * radius,
				d0 * (radius - width), d1 * radius, d1 * (radius - width)])
	return _add_mesh(vertices, color)


## A small arrowhead just outside the ring, pointing the way the enemy faces.
func _arrow(radius: float) -> void:
	var tip := Vector3(0, 0, -(radius + 0.8))
	var base_l := Vector3(-0.42, 0, -(radius + 0.05))
	var base_r := Vector3(0.42, 0, -(radius + 0.05))
	var notch := Vector3(0, 0, -(radius + 0.32))
	_add_mesh(PackedVector3Array([tip, base_r, notch, tip, notch, base_l]), Color(1, 1, 1, 0.8))


func _add_mesh(vertices: PackedVector3Array, color: Color) -> StandardMaterial3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.albedo_color = color
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return material
