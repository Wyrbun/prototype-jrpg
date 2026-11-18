@tool
class_name ArenaObstacle
extends Node3D
## Something on the battlefield nobody can walk through.
##
## Put these as children of an Arena and drag them around in the editor.
## - Rock: blocks movement and line of sight (attacks can't pass it).
## - Pit: blocks movement only; you can see and attack across it.
## - Hole: a lethal drop. Walkers steer around it; anyone pushed into it
##   falls out of the fight (bosses excepted), and walking in asks for a
##   Parry-like save. A black drop glowing deep red far down, embers rising,
##   a broken rim with bones on it.
##
## They look natural: rocks are lumpy, faceted boulders with smaller stones
## round their feet, pits and holes are hollows with broken stone rims.
## Each one's shape comes from where it stands, so it's the same every time.

enum Kind { ROCK, PIT, HOLE }

@export var kind: Kind = Kind.ROCK:
	set(value):
		kind = value
		_rebuild()
## Size in meters (it's round).
@export var radius: float = 1.4:
	set(value):
		radius = value
		_rebuild()

var _visual: MeshInstance3D = null
## Breakable rocks (the Gale Maw): how many times it's been cracked, and
## whether it has crumbled (then it's out of the arena until it regrows).
var cracks := 0
var broken := false
## Holes: the ring of skulls slowly turns round the drop.
var _skull_ring: Node3D = null
const SKULL_TURN_SPEED := 0.25  # radians per second


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _skull_ring != null and not Engine.is_editor_hint():
		_skull_ring.rotation.y += SKULL_TURN_SPEED * delta


## A wall boss's blast cracks it; at `limit` cracks it crumbles. Returns
## true when it crumbles.
func crack(limit: int) -> bool:
	if kind != Kind.ROCK or broken:
		return false
	cracks += 1
	if cracks >= limit:
		broken = true
		visible = false
		return true
	if _visual and _visual.material_override:
		var m := _visual.material_override as StandardMaterial3D
		m.albedo_color = m.albedo_color.darkened(0.35)  # cracked
	return false


## It grows back whole.
func regrow() -> void:
	broken = false
	cracks = 0
	visible = true
	_rebuild()


func blocks_sight() -> bool:
	return kind == Kind.ROCK


func is_lethal() -> bool:
	return kind == Kind.HOLE


## Recolours it to fit the place (see ArenaScenery): rocks, and the stones
## round pits and holes.
func tint(color: Color) -> void:
	_tint = color
	_rebuild()

var _tint := Color(-1, 0, 0)


## A skull lying on the floor (the lethal skill areas' marker).

static func make_skull(spot: Vector3) -> Label3D:
	var skull := Label3D.new()
	skull.text = "☠"
	skull.font_size = 90
	skull.modulate = Color(1.0, 0.95, 0.95, 0.95)
	skull.outline_size = 12
	skull.outline_modulate = Color(0.4, 0.0, 0.0, 0.9)
	skull.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	skull.position = spot + Vector3(0, 0.05, 0)
	return skull


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual:
		_visual.queue_free()
	_skull_ring = null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0))) + int(kind)
	var stone := _tint if _tint.r >= 0.0 else Color(0.45, 0.42, 0.38)
	_visual = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = stone
	if kind == Kind.ROCK:
		# A big lumpy boulder (as tall as it always was: it blocks sight), a
		# couple of smaller ones against it, pebbles round its feet.
		_visual.mesh = boulder_mesh(radius * 0.98, 1.8, rng)
		_visual.material_override = material
		add_child(_visual)
		for i in rng.randi_range(1, 3):
			var a := rng.randf() * TAU
			var small := MeshInstance3D.new()
			var r := radius * rng.randf_range(0.3, 0.45)
			small.mesh = boulder_mesh(r, r * rng.randf_range(1.1, 1.6), rng)
			small.material_override = material
			small.position = Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(0.75, 0.95)
			_visual.add_child(small)
		_scatter_stones(_visual, material, radius * 1.05, radius * 1.35, rng.randi_range(3, 6), rng)
		return
	# Pits and holes: a hollow, darkest in the middle, its rim broken stone.
	var hole := kind == Kind.HOLE
	var deep := Color(0.0, 0.0, 0.0) if hole else stone.darkened(0.82)
	var wall := Color(0.05, 0.03, 0.03) if hole else stone.darkened(0.6)
	_visual.mesh = hollow_mesh(radius, deep, wall, Color(0.42, 0.06, 0.03) if hole else Color(-1, 0, 0), rng)
	var hollow_mat := StandardMaterial3D.new()
	hollow_mat.vertex_color_use_as_albedo = true
	hollow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hollow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_visual.material_override = hollow_mat
	# Just above the floor, well under the enemy areas (drawn at 3 cm): at
	# the same height they'd flicker over each other.
	_visual.position.y = 0.008
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	var rim := Node3D.new()
	_visual.add_child(rim)
	rim.position.y = -0.008
	_scatter_stones(rim, material, radius * 0.92, radius * 1.12, maxi(int(TAU * radius / 0.4), 8), rng)
	if hole:
		# A few bones on the rim, embers drifting up out of the dark.
		var bone_mat := StandardMaterial3D.new()
		bone_mat.albedo_color = Color(0.86, 0.82, 0.72)
		for i in rng.randi_range(2, 3):
			var a := rng.randf() * TAU
			var at := Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(1.05, 1.25)
			var skull := MeshInstance3D.new()
			var head := SphereMesh.new()
			head.radius = 0.13
			head.height = 0.22
			head.radial_segments = 6
			head.rings = 3
			skull.mesh = head
			skull.material_override = bone_mat
			skull.position = at + Vector3(0, 0.08, 0)
			rim.add_child(skull)
			var bone := MeshInstance3D.new()
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.03
			shaft.bottom_radius = 0.03
			shaft.height = 0.45
			shaft.radial_segments = 5
			bone.mesh = shaft
			bone.material_override = bone_mat
			bone.position = at + Vector3(0.25, 0.03, 0.1)
			bone.rotation = Vector3(PI / 2.0, rng.randf() * PI, 0)
			rim.add_child(bone)
		var embers := CPUParticles3D.new()
		embers.amount = maxi(int(radius * 6.0), 6)
		embers.lifetime = 2.0
		embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		embers.emission_sphere_radius = radius * 0.6
		embers.direction = Vector3.UP
		embers.spread = 15.0
		embers.gravity = Vector3.ZERO
		embers.initial_velocity_min = 0.3
		embers.initial_velocity_max = 0.7
		embers.scale_amount_min = 0.5
		embers.scale_amount_max = 1.0
		var spark := SphereMesh.new()
		spark.radius = 0.04
		spark.height = 0.08
		spark.radial_segments = 4
		spark.rings = 2
		var ember_mat := StandardMaterial3D.new()
		ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ember_mat.albedo_color = Color(1.0, 0.4, 0.15)
		spark.material = ember_mat
		embers.mesh = spark
		embers.position.y = -0.3
		embers.color_ramp = Gradient.new()
		embers.color_ramp.set_color(0, Color(1, 1, 1, 1))
		embers.color_ramp.set_color(1, Color(1, 1, 1, 0))
		_visual.add_child(embers)


## Stones round something: `count` lumps between `from` and `to` metres out.
static func _scatter_stones(parent: Node3D, material: Material, from: float, to: float, count: int, rng: RandomNumberGenerator) -> void:
	for i in count:
		if rng.randf() < 0.2:
			continue  # gaps: it's broken, not built
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var r := rng.randf_range(0.08, 0.22)
		var stone := MeshInstance3D.new()
		stone.mesh = boulder_mesh(r, r * rng.randf_range(0.8, 1.4), rng)
		stone.material_override = material
		stone.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(from, to)
		stone.rotation.y = rng.randf() * TAU
		parent.add_child(stone)


## A lumpy, faceted boulder `radius` across and `height` tall, its base flat
## on the floor; lighter on top, darker underneath, each facet a little
## different (vertex colours: the material's colour tints it).
static func boulder_mesh(radius: float, height: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var shaped := PackedVector3Array()
	shaped.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		# the same bump for the same spot (the seam's twin vertices match)
		var bump := 1.0 + 0.3 * noise.get_noise_3dv(v.snapped(Vector3(0.001, 0.001, 0.001)) * 1.6)
		var p := v * bump
		p.y = maxf(p.y, -0.55)  # sits flat
		p = Vector3(p.x * radius, (p.y + 0.55) / 1.85 * height, p.z * radius)
		p += lean * p.y  # leaning a little
		shaped[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, index.size(), 3):
		var shade := rng.randf_range(0.85, 1.05)
		for k in 3:
			var p := shaped[index[t + k]]
			var up := clampf(p.y / maxf(height, 0.01), 0.0, 1.0)
			var c := lerpf(0.62, 1.0, up) * shade
			st.set_color(Color(c, c, c))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## A pit or hole seen from above: a disc, `deep` in the middle, `wall`
## towards the edge, fading into the floor just past it; `glow` (if set) a
## dim ring far down (a hole's red).
static func hollow_mesh(radius: float, deep: Color, wall: Color, glow: Color, rng: RandomNumberGenerator) -> ArrayMesh:
	var rings := [[0.0, deep], [0.35, deep], [0.62, glow if glow.r >= 0.0 else deep.lerp(wall, 0.4)], [0.86, wall], [1.0, wall], [1.18, Color(wall, 0.0)]]
	var segments := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wobble := []
	for i in segments:
		wobble.append(rng.randf_range(0.94, 1.06))  # a ragged edge
	for r in range(rings.size() - 1):
		var r0: float = rings[r][0]
		var r1: float = rings[r + 1][0]
		var c0: Color = rings[r][1]
		var c1: Color = rings[r + 1][1]
		for i in segments:
			var j := (i + 1) % segments
			var a0 := TAU * i / segments
			var a1 := TAU * j / segments
			var w0: float = wobble[i] if r0 > 0.5 else 1.0
			var w1: float = wobble[j] if r0 > 0.5 else 1.0
			var w0b: float = wobble[i] if r1 > 0.5 else 1.0
			var w1b: float = wobble[j] if r1 > 0.5 else 1.0
			var p00 := Vector3(cos(a0), 0, sin(a0)) * radius * r0 * w0
			var p01 := Vector3(cos(a1), 0, sin(a1)) * radius * r0 * w1
			var p10 := Vector3(cos(a0), 0, sin(a0)) * radius * r1 * w0b
			var p11 := Vector3(cos(a1), 0, sin(a1)) * radius * r1 * w1b
			for pc in [[p00, c0], [p10, c1], [p11, c1], [p00, c0], [p11, c1], [p01, c0]]:
				st.set_color(pc[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(pc[0])
	return st.commit()
