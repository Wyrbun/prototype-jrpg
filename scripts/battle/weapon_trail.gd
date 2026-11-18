class_name WeaponTrail
extends MeshInstance3D
## A short ribbon behind a weapon while it swings: each frame the weapon's
## base and tip points are sampled; the strip between the last samples
## fades out over `life` seconds. Drawn in world space (top level).

var base: Node3D
var tip: Node3D
var emitting := false
var life := 0.18
var color := Color.WHITE

var _points: Array = []  # [base, tip, age]
var _mesh := ImmediateMesh.new()


static func make(base_node: Node3D, tip_node: Node3D, trail_color: Color) -> WeaponTrail:
	var t := WeaponTrail.new()
	t.base = base_node
	t.tip = tip_node
	t.color = trail_color
	t.top_level = true
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.mesh = t._mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	t.material_override = mat
	return t


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	for p in _points:
		p[2] += delta
	while not _points.is_empty() and _points[0][2] > life:
		_points.pop_front()
	if emitting and is_instance_valid(base) and is_instance_valid(tip) and base.is_visible_in_tree():
		_points.append([base.global_position, tip.global_position, 0.0])
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _points:
		var a := clampf(1.0 - float(p[2]) / life, 0.0, 1.0) * 0.75
		_mesh.surface_set_color(Color(color, 0.0))
		_mesh.surface_add_vertex(p[0])
		_mesh.surface_set_color(Color(color, a))
		_mesh.surface_add_vertex(p[1])
	_mesh.surface_end()
