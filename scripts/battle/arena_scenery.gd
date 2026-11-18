@tool
class_name ArenaScenery
extends Node3D
## Everything around a fight that's only for looks: where it is. A textured
## floor, the ground around it, props past the edges (houses, trees, cave
## walls, a colosseum's stands and crowd...), the sky, fog and light.
## Nothing here touches the fight: fighters never reach it (the arena's
## edges stop them) and it never blocks sight.
##
## An arena picks its place with Arena.setting; build() makes it. Low props
## sit close to the edges, tall ones further out, where the camera (which
## can circle the fight) passes over or behind them; tall props also hide
## when the camera gets right up to them.

## Setting -> how it looks. Textures: see _texture(). Props: see _props_for().
const SETTINGS := {
	"plaza": {
		"title": "Town Plaza",
		"floor": "cobble", "floor_colors": [Color(0.56, 0.53, 0.5), Color(0.36, 0.33, 0.31)],
		"ground": "cobble", "ground_colors": [Color(0.46, 0.43, 0.4), Color(0.3, 0.28, 0.26)],
		"sky": [Color(0.32, 0.52, 0.86), Color(0.78, 0.84, 0.92)],
		"fog": Color(0.74, 0.8, 0.9), "fog_range": [40.0, 120.0],
		"ambient": Color(0.7, 0.72, 0.8), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.96, 0.88), "sun_energy": 1.0,
		"rock": Color(0.6, 0.57, 0.52), "mountains": Color(0.5, 0.6, 0.7),
	},
	"forest": {
		"title": "Forest Clearing",
		"floor": "grass", "floor_colors": [Color(0.42, 0.52, 0.28), Color(0.3, 0.38, 0.2)],
		"ground": "grass", "ground_colors": [Color(0.32, 0.44, 0.22), Color(0.22, 0.32, 0.15)],
		"sky": [Color(0.4, 0.58, 0.82), Color(0.8, 0.86, 0.8)],
		"fog": Color(0.6, 0.7, 0.6), "fog_range": [30.0, 95.0],
		"ambient": Color(0.62, 0.72, 0.6), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.93, 0.78), "sun_energy": 0.95,
		"rock": Color(0.45, 0.5, 0.42), "mountains": Color(0.35, 0.48, 0.42),
	},
	"pass": {
		"title": "Mountain Pass",
		"floor": "dirt", "floor_colors": [Color(0.55, 0.45, 0.34), Color(0.4, 0.32, 0.24)],
		"ground": "rock", "ground_colors": [Color(0.42, 0.4, 0.38), Color(0.28, 0.26, 0.25)],
		"sky": [Color(0.42, 0.6, 0.88), Color(0.86, 0.88, 0.9)],
		"fog": Color(0.8, 0.84, 0.9), "fog_range": [35.0, 110.0],
		"ambient": Color(0.7, 0.74, 0.82), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.97, 0.92), "sun_energy": 1.0,
		"rock": Color(0.44, 0.41, 0.38), "mountains": Color(0.55, 0.6, 0.7),
	},
	"cave": {
		"title": "Crystal Cave",
		"floor": "rock", "floor_colors": [Color(0.4, 0.36, 0.34), Color(0.24, 0.21, 0.2)],
		"ground": "rock", "ground_colors": [Color(0.28, 0.25, 0.25), Color(0.16, 0.14, 0.14)],
		"sky": [], "background": Color(0.02, 0.02, 0.04),
		"fog": Color(0.06, 0.05, 0.1), "fog_range": [16.0, 46.0],
		"ambient": Color(0.5, 0.48, 0.65), "ambient_energy": 0.65,
		"sun": Color(0.7, 0.72, 0.95), "sun_energy": 0.45,
		"rock": Color(0.42, 0.38, 0.38),
	},
	"ruins": {
		"title": "Sky Ruins",
		"floor": "tiles", "floor_colors": [Color(0.62, 0.58, 0.52), Color(0.4, 0.37, 0.33)],
		"ground": "tiles", "ground_colors": [Color(0.52, 0.5, 0.44), Color(0.33, 0.31, 0.28)],
		"sky": [Color(0.32, 0.26, 0.5), Color(0.98, 0.62, 0.42)],
		"fog": Color(0.85, 0.6, 0.55), "fog_range": [35.0, 110.0],
		"ambient": Color(0.8, 0.66, 0.7), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.78, 0.58), "sun_energy": 0.95,
		"rock": Color(0.6, 0.55, 0.5), "mountains": Color(0.55, 0.42, 0.55),
		"abyss": Color(0.95, 0.75, 0.75), "clouds": Color(1.0, 0.86, 0.84),
	},
	"colosseum": {
		"title": "Grand Colosseum",
		"floor": "sand", "floor_colors": [Color(0.66, 0.55, 0.4), Color(0.5, 0.4, 0.28)],
		"ground": "sand", "ground_colors": [Color(0.6, 0.5, 0.36), Color(0.45, 0.36, 0.26)],
		"sky": [Color(0.3, 0.5, 0.86), Color(0.86, 0.86, 0.9)],
		"fog": Color(0.85, 0.85, 0.9), "fog_range": [60.0, 160.0],
		"ambient": Color(0.75, 0.72, 0.72), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.05,
		"rock": Color(0.66, 0.6, 0.5),
	},
	"cliff": {
		"title": "Windswept Cliff",
		"floor": "rockgrass", "floor_colors": [Color(0.42, 0.44, 0.38), Color(0.3, 0.33, 0.26)],
		"ground": "grass", "ground_colors": [Color(0.34, 0.46, 0.22), Color(0.24, 0.34, 0.16)],
		"sky": [Color(0.34, 0.54, 0.86), Color(0.82, 0.88, 0.94)],
		"fog": Color(0.78, 0.84, 0.92), "fog_range": [30.0, 120.0],
		"ambient": Color(0.72, 0.76, 0.86), "ambient_energy": 0.5,
		"sun": Color(1.0, 0.97, 0.9), "sun_energy": 0.95,
		"rock": Color(0.46, 0.47, 0.46), "mountains": Color(0.52, 0.6, 0.74),
		"abyss": Color(0.36, 0.5, 0.42), "clouds": Color(0.96, 0.97, 1.0),
		# the Gale Maw's place in the north wall stays clear
		"keep_clear": [[Vector3(0, 0, -14), 9.0]],
		# past the drop: a gorge, with a far side across it
		"chasm": 24.0,
	},
	"canyon": {
		"title": "Red Canyon",
		"floor": "sand", "floor_colors": [Color(0.78, 0.5, 0.34), Color(0.6, 0.38, 0.26)],
		"ground": "sand", "ground_colors": [Color(0.72, 0.46, 0.32), Color(0.55, 0.34, 0.24)],
		"sky": [Color(0.42, 0.6, 0.84), Color(0.96, 0.86, 0.7)],
		"fog": Color(0.95, 0.82, 0.68), "fog_range": [35.0, 120.0],
		"ambient": Color(0.82, 0.72, 0.64), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.92, 0.78), "sun_energy": 1.1,
		"rock": Color(0.68, 0.42, 0.3), "mountains": Color(0.72, 0.5, 0.4),
	},
	"yard": {
		"title": "Training Yard",
		"floor": "dirt", "floor_colors": [Color(0.58, 0.48, 0.34), Color(0.44, 0.36, 0.25)],
		"ground": "grass", "ground_colors": [Color(0.4, 0.5, 0.26), Color(0.28, 0.38, 0.18)],
		"sky": [Color(0.38, 0.58, 0.88), Color(0.84, 0.88, 0.9)],
		"fog": Color(0.78, 0.84, 0.88), "fog_range": [40.0, 120.0],
		"ambient": Color(0.72, 0.74, 0.78), "ambient_energy": 0.6,
		"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.0,
		"rock": Color(0.55, 0.5, 0.44), "mountains": Color(0.48, 0.6, 0.66),
	},
}

## Every colour out here is muted this much toward grey and dimmed this
## much (easier on the eyes over a long session; the fighters and effects,
## which aren't muted, stand out against it).
const MUTE_GREY := 0.3
const MUTE_DIM := 0.18
## And the light: the sun and ambient light at this share of each setting's.
const MUTE_LIGHT := 0.85


static func mute(c: Color) -> Color:
	var grey := c.get_luminance()
	var m := c.lerp(Color(grey, grey, grey, c.a), MUTE_GREY).darkened(MUTE_DIM)
	m.a = c.a
	return m


## A setting's data with its colours muted (props are muted as they're made).
static func _muted(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	for key in ["floor_colors", "ground_colors", "sky"]:
		var colors: Array = []
		for c in out.get(key, []):
			# the sky a little dimmer still: it's most of the screen's top
			colors.append(mute(c).darkened(0.15) if key == "sky" else mute(c))
		out[key] = colors
	for key in ["fog", "ambient", "abyss", "clouds", "background"]:
		if out.has(key):
			out[key] = mute(out[key])
	return out


## Tall props hide when the camera is closer than this (so it never ends up inside one).
const HIDE_NEAR := 5.0

var arena: Arena
var setting := ""
var data: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _placed: Array = []  # [position, radius] of props already placed
## Moving bits: crowd, clouds, flames.
var _crowd: MultiMeshInstance3D = null
var _crowd_heads: MultiMeshInstance3D = null
var _crowd_base: Array = []  # [body transform, head transform, phase]
var _clouds: Array = []  # [node, speed, wrap]
var _flames: Array = []  # [OmniLight3D, base energy, phase]
var _time := 0.0
var _crowd_tick := 0.0

static var _textures := {}


static func build(for_arena: Arena, which: String) -> ArenaScenery:
	if not SETTINGS.has(which):
		return null
	var s := ArenaScenery.new()
	s.name = "Scenery"
	s.arena = for_arena
	s.setting = which
	s.data = _muted(SETTINGS[which])
	s._rng.seed = hash(which)
	for_arena.add_child(s)
	s._build()
	return s


func _build() -> void:
	_texture_floor()
	_outer_ground()
	if data.has("chasm"):
		_chasm()
	_tint_rocks()
	if data.has("abyss"):
		_abyss()
	if data.has("mountains"):
		_mountains(data["mountains"])
	_props_for(setting)


# --- Sky, fog and light ---------------------------------------------------------

## Puts this place's sky, fog and light on the fight's environment and sun.
func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	if env == null:
		return
	var sky_colors: Array = data["sky"]
	if sky_colors.is_empty():
		env.background_mode = Environment.BG_COLOR
		env.background_color = data.get("background", Color.BLACK)
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = sky_colors[0]
		sky_mat.sky_horizon_color = sky_colors[1]
		sky_mat.ground_horizon_color = sky_colors[1]
		sky_mat.ground_bottom_color = (data["fog"] as Color).darkened(0.3)
		sky_mat.sun_angle_max = 8.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = data["ambient"]
	env.ambient_light_energy = float(data["ambient_energy"]) * MUTE_LIGHT
	# PS1-style distance fog: the far ground and the mountains fade out.
	# (Exponential: it looks the same in every renderer.) At fog_range's end
	# it's about half fog; close up, barely any.
	env.fog_enabled = true
	env.fog_light_color = data["fog"]
	env.fog_light_energy = 1.0
	env.fog_density = 0.6 / float(data["fog_range"][1])
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	if sun:
		sun.light_color = data["sun"]
		sun.light_energy = float(data["sun_energy"]) * MUTE_LIGHT


# --- Ground ----------------------------------------------------------------------

func _ground_material(kind: String, colors: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(kind, colors[0], colors[1])
	# Chunky texels up close, but averaged out (anisotropic mipmaps) far away
	# and at low angles, where thin lines like mortar would otherwise shimmer.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)  # 4 m a tile: chunky texels, like the PS1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _texture_floor() -> void:
	var floor_node := arena.get_floor_mesh()
	if floor_node == null or floor_node.mesh == null:
		return
	var m := _ground_material(data["floor"], data["floor_colors"])
	floor_node.mesh.surface_set_material(0, m)


## The ground past the floor's edges, out to the horizon; none past a drop.
func _outer_ground() -> void:
	var far := 160.0
	var verts := PackedVector3Array()
	var y := -0.03
	if arena.shape == Arena.Shape.CIRCLE:
		if arena.lethal_rim:
			return
		var r := arena.size.x / 2.0 - 0.05
		for i in 48:
			var a0 := TAU * i / 48.0
			var a1 := TAU * (i + 1) / 48.0
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var p := [d0 * r, d1 * r, d1 * far, d0 * far]
			for k in [0, 1, 2, 0, 2, 3]:
				verts.append((p[k] as Vector3) + Vector3(0, y, 0))
	else:
		var hx := arena.size.x / 2.0 - 0.05
		var hz := arena.size.y / 2.0 - 0.05
		var lethal := arena.lethal_sides
		var slabs := []
		if not lethal & Arena.SIDE_NORTH:
			slabs.append([-far, far, -far, -hz])
		if not lethal & Arena.SIDE_SOUTH:
			slabs.append([-far, far, hz, far])
		var z_from := -far if lethal & Arena.SIDE_NORTH else -hz
		var z_to := far if lethal & Arena.SIDE_SOUTH else hz
		if data.has("chasm"):
			# A gorge runs the whole way along the drop: the land beside the
			# floor ends where the floor does (crumbled edges too).
			var b := arena._bounds()
			z_from = b[2] if lethal & Arena.SIDE_NORTH else z_from
			z_to = b[3] if lethal & Arena.SIDE_SOUTH else z_to
		var chasm := data.has("chasm")
		var side_from: float = z_from if chasm or not lethal & Arena.SIDE_NORTH else -hz
		var side_to: float = z_to if chasm or not lethal & Arena.SIDE_SOUTH else hz
		if not lethal & Arena.SIDE_WEST:
			slabs.append([-far, -hx, side_from, side_to])
		if not lethal & Arena.SIDE_EAST:
			slabs.append([hx, far, side_from, side_to])
		if chasm:
			# The far side of the gorge.
			var across := hz + float(data["chasm"])
			if lethal & Arena.SIDE_SOUTH:
				slabs.append([-far, far, across, far])
			if lethal & Arena.SIDE_NORTH:
				slabs.append([-far, far, -far, -across])
		for s in slabs:
			var a := Vector3(s[0], y, s[2])
			var b := Vector3(s[1], y, s[2])
			var c := Vector3(s[1], y, s[3])
			var d := Vector3(s[0], y, s[3])
			verts.append_array([a, b, c, a, c, d])
	if verts.is_empty():
		return
	add_child(_flat_mesh(verts, _ground_material(data["ground"], data["ground_colors"])))


func _flat_mesh(verts: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Past a drop: the land far below (fading in the fog) and clouds drifting
## under the edge.
func _abyss() -> void:
	var below := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	below.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["abyss"]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var chasm := data.has("chasm")
	if chasm:
		# A gorge's floor: dark, far down (the walls fade into it).
		mat.albedo_color = mute(data["abyss"]).darkened(0.68)
		mat.disable_fog = true
	below.material_override = mat
	below.position.y = -45.0
	add_child(below)
	var cloud_color: Color = data.get("clouds", Color.WHITE)
	if chasm:
		cloud_color = cloud_color.darkened(0.25)  # wisps of mist down in the shade
	for i in (9 if chasm else 26):
		var spot := _drop_spot(6.0, 40.0)
		if spot == Vector3.INF:
			continue
		var cloud := Node3D.new()
		add_child(cloud)
		cloud.position = spot + Vector3(0, _rng.randf_range(-26.0, -14.0) if chasm else _rng.randf_range(-14.0, -5.0), 0)
		for k in _rng.randi_range(3, 5):
			var puff := _ball(_rng.randf_range(1.4, 2.6), cloud_color, true)
			puff.scale.y *= 0.45
			puff.position = Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.5, 1.5))
			cloud.add_child(puff)
		_clouds.append([cloud, _rng.randf_range(0.4, 1.0), 60.0])


## A gorge along each north or south drop: a jagged rock face going down from
## the floor's edge into the dark, and another rising on the far side, where
## the land carries on. It follows the edge as it crumbles (the scenery is
## rebuilt then).
func _chasm() -> void:
	var b := arena._bounds()
	var width := float(data["chasm"])
	var hz := arena.size.y / 2.0
	var top: Color = mute(data["rock"])
	var deep: Color = mute(data["abyss"]).darkened(0.62)
	for side in [Arena.SIDE_SOUTH, Arena.SIDE_NORTH]:
		if not arena.lethal_sides & side:
			continue
		var out := 1.0 if side == Arena.SIDE_SOUTH else -1.0
		var edge: float = b[3] if side == Arena.SIDE_SOUTH else -b[2]
		# The near face, under the floor's edge, and the far one, facing it.
		add_child(_rock_face(edge, out, 1.0, top, deep))
		add_child(_rock_face(hz + width, out, -1.0, top, deep))


## A rock face along x at `z` (times `out`: +1 south, -1 north), from the
## ground down to the gorge's floor. facing: +1 looks away from the arena
## (the near face), -1 toward it (the far face). Jagged: each column of rock
## juts out or back a little, lighter at the top, dark far down.
func _rock_face(z: float, out: float, facing: float, top: Color, deep: Color) -> MeshInstance3D:
	const SPAN := 90.0
	const COLUMN := 2.5
	const DEPTH := 46.0
	const ROWS := 5
	var columns := int(SPAN * 2.0 / COLUMN)
	var grid: Array = []  # [column][row] -> Vector3
	for c in columns + 1:
		var x := -SPAN + c * COLUMN
		var col: Array = []
		for r in ROWS + 1:
			var y := -DEPTH * pow(float(r) / ROWS, 1.4)
			# The top row stays on the edge (no gap under the floor); lower
			# down the rock juts in and out.
			var jut := 0.0 if r == 0 else _rng.randf_range(-0.9, 0.9) - facing * r * 0.25
			col.append(Vector3(x + (0.0 if r == 0 else _rng.randf_range(-0.6, 0.6)), y, (z + jut) * out))
		grid.append(col)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for c in columns:
		for r in ROWS:
			var a: Vector3 = grid[c][r]
			var bb: Vector3 = grid[c + 1][r]
			var cc: Vector3 = grid[c + 1][r + 1]
			var d: Vector3 = grid[c][r + 1]
			var quad := [a, bb, cc, a, cc, d]
			for v in quad:
				verts.append(v)
				var k := clampf(-(v as Vector3).y / DEPTH, 0.0, 1.0)
				colors.append(top.lerp(deep, pow(k, 0.6)).darkened(_rng.randf_range(0.0, 0.12) if r > 0 else 0.0))
	# Flat-shaded: one normal per triangle (the facets catch the light).
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(0, verts.size(), 3):
		var nrm := (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i]).normalized()
		normals[i] = nrm
		normals[i + 1] = nrm
		normals[i + 2] = nrm
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # the colours are picked by eye
	mat.disable_fog = true  # the dark depths stay dark (the fog would pale them)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A spot over the drop, `near` to `far` metres past its edge (INF if none).
func _drop_spot(near: float, far: float) -> Vector3:
	for attempt in 30:
		var p := Vector3(_rng.randf_range(-far - 20, far + 20), 0, _rng.randf_range(-far - 20, far + 20))
		if _outside_by(p) >= near and _outside_by(p) <= far and _over_drop(p):
			return p
	return Vector3.INF


func _mountains(color: Color) -> void:
	for i in 22:
		var a := TAU * i / 22.0 + _rng.randf_range(-0.1, 0.1)
		var d := _rng.randf_range(110.0, 140.0)
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = _rng.randf_range(0.0, 3.0)
		cone.bottom_radius = _rng.randf_range(22.0, 36.0)
		cone.height = _rng.randf_range(22.0, 48.0)
		cone.radial_segments = 6
		cone.rings = 1
		peak.mesh = cone
		peak.material_override = _flat(color.darkened(_rng.randf_range(0.0, 0.2)))
		peak.position = Vector3(cos(a) * d, cone.height / 2.0 - 6.0, sin(a) * d)
		peak.rotation.y = _rng.randf() * TAU
		peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(peak)


func _tint_rocks() -> void:
	for o in arena.obstacles():
		o.tint(mute(data["rock"]))
	arena.tint_edges(mute(data["rock"]))


# --- Placing props ------------------------------------------------------------------

## How far a point is outside the floor (0 inside it).
func _outside_by(p: Vector3) -> float:
	if arena.shape == Arena.Shape.CIRCLE:
		return maxf(Vector2(p.x, p.z).length() - arena.size.x / 2.0, 0.0)
	var dx := maxf(absf(p.x) - arena.size.x / 2.0, 0.0)
	var dz := maxf(absf(p.z) - arena.size.y / 2.0, 0.0)
	return Vector2(dx, dz).length()


## Past a lethal edge (nothing stands there: it's a drop).
func _over_drop(p: Vector3) -> bool:
	if arena.shape == Arena.Shape.CIRCLE:
		return arena.lethal_rim and _outside_by(p) > 0.0
	var hx := arena.size.x / 2.0
	var hz := arena.size.y / 2.0
	var l := arena.lethal_sides
	if data.has("chasm"):
		var across := hz + float(data["chasm"])
		return (l & Arena.SIDE_NORTH and p.z < -hz and p.z > -across) \
				or (l & Arena.SIDE_SOUTH and p.z > hz and p.z < across) \
				or (l & Arena.SIDE_EAST and p.x > hx) or (l & Arena.SIDE_WEST and p.x < -hx)
	return (l & Arena.SIDE_NORTH and p.z < -hz) or (l & Arena.SIDE_SOUTH and p.z > hz) \
			or (l & Arena.SIDE_EAST and p.x > hx) or (l & Arena.SIDE_WEST and p.x < -hx)


## Where the tall props start: past where the camera usually is.
func _tall_from() -> float:
	var half := minf(arena.size.x, arena.size.y) / 2.0
	return clampf(12.5 - half, 3.0, 9.0)


## Up to `count` free spots `near`..`far` metres outside the floor, each
## `gap` from the others. Not over a drop, not in a kept-clear place.
func _spots(count: int, near: float, far: float, gap: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var reach := maxf(arena.size.x, arena.size.y) / 2.0 + far
	for i in count:
		for attempt in 40:
			var p := Vector3(_rng.randf_range(-reach, reach), 0.0, _rng.randf_range(-reach, reach))
			var d := _outside_by(p)
			if d < near or d > far or _over_drop(p) or _crowded(p, gap):
				continue
			out.append(p)
			_placed.append([p, gap])
			break
	return out


func _crowded(p: Vector3, gap: float) -> bool:
	for keep in data.get("keep_clear", []):
		if p.distance_to(keep[0]) < float(keep[1]):
			return true
	for other in _placed:
		if p.distance_to(other[0]) < maxf(gap, float(other[1])) * 0.5 + gap * 0.5:
			return true
	return false


## Faces a prop toward the middle of the fight (houses, stands, dummies).
func _face_in(node: Node3D, p: Vector3) -> void:
	var to := -Vector3(p.x, 0, p.z)
	if to.length() > 0.01:
		node.rotation.y = atan2(to.x, to.z)


func _put(node: Node3D, p: Vector3, tall := false, face_in := false) -> Node3D:
	add_child(node)
	node.position = p
	if face_in:
		_face_in(node, p)
	else:
		node.rotation.y = _rng.randf() * TAU
	if tall:
		for mesh in node.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).visibility_range_begin = HIDE_NEAR
	return node


func _props_for(which: String) -> void:
	var tall := _tall_from()
	match which:
		"plaza":
			for p in _spots(14, tall + 1.0, tall + 18.0, 7.0):
				_put(_house(), p, true, true)
			for p in _spots(8, 1.0, 4.0, 3.0):
				_put(_crates(), p)
			for p in _spots(6, 0.6, 2.0, 5.0):
				_put(_lamp(), p, false)
			for p in _spots(4, tall, tall + 6.0, 6.0):
				_put(_stall(), p, true, true)
			for p in _spots(10, tall, tall + 20.0, 4.0):
				_put(_round_tree(), p, true)
		"forest":
			for p in _spots(70, tall, tall + 26.0, 3.2):
				_put(_pine() if _rng.randf() < 0.6 else _round_tree(), p, true)
			for p in _spots(18, 0.6, tall, 2.2):
				_put(_bush() if _rng.randf() < 0.7 else _mushrooms(), p)
			for p in _spots(5, 1.5, tall + 4.0, 4.0):
				_put(_log(), p)
		"pass":
			for p in _spots(30, tall - 1.0, tall + 10.0, 5.0):
				_put(_crag(_rng.randf_range(5.0, 11.0)), p, true)
			for p in _spots(20, tall + 6.0, tall + 30.0, 5.0):
				_put(_pine(), p, true)
			for p in _spots(14, 0.6, tall - 1.0, 2.2):
				_put(_boulder(_rng.randf_range(0.3, 0.8)), p)
		"cave":
			for p in _spots(36, tall - 1.5, tall + 8.0, 4.0):
				_put(_crag(_rng.randf_range(6.0, 14.0)), p, true)
			for p in _spots(16, 0.8, tall, 2.6):
				_put(_crystals(), p)
			for p in _spots(14, 0.6, tall, 2.0):
				_put(_stalagmite(), p)
			for p in _spots(5, 1.2, 3.0, 8.0):
				_put(_torch(), p)
		"ruins":
			for p in _spots(16, 0.8, tall + 10.0, 3.5):
				_put(_pillar(), p, true)
			for p in _spots(3, tall, tall + 12.0, 9.0):
				_put(_arch(), p, true, true)
			for p in _spots(10, 0.6, tall, 2.0):
				_put(_rubble(), p)
			for i in 10:
				var p := _drop_spot(5.0, 30.0)
				if p != Vector3.INF:
					var rock := _put(_floating_rock(), p + Vector3(0, _rng.randf_range(-6.0, 3.0), 0))
					_clouds.append([rock, _rng.randf_range(0.1, 0.3), 0.0])  # a slow bob, no drift
		"colosseum":
			_stands()
			for p in _spots(8, 0.7, 2.0, 6.0):
				_put(_brazier(), p)
		"cliff":
			for p in _spots(16, tall, tall + 22.0, 5.0):
				_put(_bent_tree(), p, true)
			for p in _spots(16, 0.6, tall + 4.0, 2.6):
				_put(_boulder(_rng.randf_range(0.3, 1.0)), p)
			for p in _spots(18, 0.6, tall, 2.0):
				_put(_bush(), p)
		"canyon":
			for p in _spots(16, tall + 2.0, tall + 30.0, 9.0):
				_put(_mesa(), p, true)
			for p in _spots(14, 1.0, tall + 6.0, 3.0):
				_put(_cactus(), p, false)
			for p in _spots(10, 0.6, tall, 2.4):
				_put(_boulder(_rng.randf_range(0.3, 0.9), Color(0.7, 0.42, 0.3)), p)
			for p in _spots(4, 0.8, tall, 4.0):
				_put(_bones(), p)
		"yard":
			_fence()
			for p in _spots(5, 1.6, 4.0, 3.5):
				_put(_dummy(), p, false, true)
			for p in _spots(6, 1.4, 5.0, 3.0):
				_put(_hay(), p)
			for p in _spots(3, 1.6, 5.0, 4.0):
				_put(_rack(), p, false, true)
			for p in _spots(2, tall + 2.0, tall + 8.0, 10.0):
				_put(_house(), p, true, true)
			for p in _spots(20, tall + 2.0, tall + 26.0, 4.0):
				_put(_round_tree() if _rng.randf() < 0.5 else _pine(), p, true)


# --- Building blocks ----------------------------------------------------------------

static var _flat_cache := {}


func _flat(color: Color) -> Material:
	return Figure.material(mute(color))


func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func _box(size: Vector3, color: Color, at := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _flat(color)
	node.position = at
	node.rotation_degrees = rot
	return node


func _cyl(top: float, bottom: float, height: float, color: Color, at := Vector3.ZERO, sides := 7) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = _flat(color)
	node.position = at
	return node


func _ball(radius: float, color: Color, unshaded := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	node.material_override = _glow(color) if unshaded else _flat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if unshaded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node


func _vary(c: Color, amount := 0.08) -> Color:
	var k := _rng.randf_range(-amount, amount)
	return Color(clampf(c.r + k, 0, 1), clampf(c.g + k, 0, 1), clampf(c.b + k, 0, 1))


func _house() -> Node3D:
	var n := Node3D.new()
	var w := _rng.randf_range(4.0, 6.0)
	var d := _rng.randf_range(3.5, 5.0)
	var h := _rng.randf_range(2.6, 4.2)
	var walls := [Color(0.86, 0.8, 0.66), Color(0.8, 0.72, 0.6), Color(0.74, 0.76, 0.7), Color(0.88, 0.84, 0.76)]
	var roofs := [Color(0.62, 0.26, 0.2), Color(0.42, 0.3, 0.24), Color(0.3, 0.36, 0.5), Color(0.55, 0.36, 0.22)]
	n.add_child(_box(Vector3(w, h, d), _vary(walls[_rng.randi() % walls.size()], 0.04), Vector3(0, h / 2.0, 0)))
	# a pitched roof: a three-sided prism lying along the width, one edge up
	var r := d * 0.62
	var roof := _cyl(r, r, w + 0.4, roofs[_rng.randi() % roofs.size()], Vector3(0, h + r * 0.25, 0), 3)
	roof.rotation_degrees = Vector3(0, 0, 90)
	roof.scale = Vector3(0.5, 1.0, 1.0)
	n.add_child(roof)
	# timber beams, a door, windows (toward the fight: +Z faces in)
	var timber := Color(0.36, 0.25, 0.16)
	n.add_child(_box(Vector3(w + 0.05, 0.18, d + 0.05), timber, Vector3(0, h * 0.55, 0)))
	n.add_child(_box(Vector3(0.9, 1.7, 0.1), timber, Vector3(_rng.randf_range(-w / 4.0, w / 4.0), 0.85, d / 2.0 + 0.03)))
	for x in [-w / 2.0 + 0.9, w / 2.0 - 0.9]:
		n.add_child(_box(Vector3(0.7, 0.6, 0.1), Color(0.22, 0.26, 0.34), Vector3(x, h * 0.78, d / 2.0 + 0.03)))
	return n


func _crates() -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.6, 0.44, 0.26)
	for i in _rng.randi_range(1, 3):
		var s := _rng.randf_range(0.45, 0.7)
		n.add_child(_box(Vector3(s, s, s), _vary(wood), Vector3(_rng.randf_range(-0.4, 0.4), s / 2.0, _rng.randf_range(-0.4, 0.4)), Vector3(0, _rng.randf_range(0, 40), 0)))
	if _rng.randf() < 0.6:
		n.add_child(_cyl(0.28, 0.28, 0.75, Color(0.5, 0.34, 0.2), Vector3(0.7, 0.37, 0.2), 8))  # a barrel
	return n


func _lamp() -> Node3D:
	var n := Node3D.new()
	n.add_child(_cyl(0.06, 0.08, 2.6, Color(0.18, 0.18, 0.2), Vector3(0, 1.3, 0), 6))
	n.add_child(_box(Vector3(0.3, 0.38, 0.3), Color(0.2, 0.2, 0.22), Vector3(0, 2.75, 0)))
	var flame := _ball(0.12, Color(1.0, 0.85, 0.5), true)
	flame.position = Vector3(0, 2.75, 0)
	n.add_child(flame)
	return n


func _stall() -> Node3D:
	var n := Node3D.new()
	var cloth: Color = [Color(0.8, 0.25, 0.22), Color(0.25, 0.45, 0.75), Color(0.85, 0.7, 0.25)][_rng.randi() % 3]
	for x in [-1.2, 1.2]:
		for z in [-0.8, 0.8]:
			n.add_child(_cyl(0.05, 0.05, 2.2, Color(0.4, 0.28, 0.18), Vector3(x, 1.1, z), 5))
	n.add_child(_box(Vector3(2.8, 0.1, 2.0), cloth, Vector3(0, 2.25, 0), Vector3(8, 0, 0)))
	n.add_child(_box(Vector3(2.4, 0.8, 0.8), Color(0.55, 0.4, 0.24), Vector3(0, 0.4, 0.5)))
	for i in 4:
		n.add_child(_ball(0.12, [Color(0.9, 0.3, 0.2), Color(0.9, 0.7, 0.2), Color(0.4, 0.7, 0.3)][i % 3]))
		n.get_child(n.get_child_count() - 1).position = Vector3(-0.9 + i * 0.6, 0.9, 0.5)
	return n


func _round_tree() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(2.0, 3.4)
	n.add_child(_cyl(0.16, 0.24, h, Color(0.42, 0.3, 0.2), Vector3(0, h / 2.0, 0), 6))
	var leaves := _vary(Color(0.3, 0.5, 0.24), 0.06)
	for i in 3:
		var blob := _ball(_rng.randf_range(1.0, 1.5), leaves)
		blob.position = Vector3(_rng.randf_range(-0.5, 0.5), h + _rng.randf_range(0.0, 0.9), _rng.randf_range(-0.5, 0.5))
		n.add_child(blob)
	return n


func _pine() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(4.0, 7.0)
	n.add_child(_cyl(0.15, 0.22, h * 0.35, Color(0.38, 0.27, 0.18), Vector3(0, h * 0.17, 0), 6))
	var green := _vary(Color(0.2, 0.38, 0.24), 0.05)
	for i in 3:
		var w := (1.0 - i * 0.28) * h * 0.26
		n.add_child(_cyl(0.0, w, h * 0.42, green.lightened(i * 0.06), Vector3(0, h * (0.3 + i * 0.22), 0), 7))
	return n


func _bush() -> Node3D:
	var n := Node3D.new()
	var green := _vary(Color(0.32, 0.5, 0.26), 0.07)
	for i in _rng.randi_range(2, 3):
		var b := _ball(_rng.randf_range(0.3, 0.5), green)
		b.position = Vector3(_rng.randf_range(-0.3, 0.3), 0.25, _rng.randf_range(-0.3, 0.3))
		b.scale.y = 0.75
		n.add_child(b)
	return n


func _mushrooms() -> Node3D:
	var n := Node3D.new()
	for i in _rng.randi_range(2, 4):
		var at := Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		var h := _rng.randf_range(0.15, 0.35)
		n.add_child(_cyl(0.04, 0.05, h, Color(0.9, 0.86, 0.76), at + Vector3(0, h / 2.0, 0), 5))
		var cap := _cyl(0.0, h * 0.7, h * 0.5, Color(0.85, 0.2, 0.18), at + Vector3(0, h + 0.05, 0), 7)
		n.add_child(cap)
	return n


func _log() -> Node3D:
	var n := Node3D.new()
	var l := _cyl(0.28, 0.28, _rng.randf_range(2.0, 3.2), Color(0.42, 0.3, 0.2), Vector3(0, 0.28, 0), 7)
	l.rotation_degrees = Vector3(0, 0, 90)
	n.add_child(l)
	return n


func _crag(height: float) -> Node3D:
	var n := Node3D.new()
	var base: Color = data["rock"]
	var r := height * _rng.randf_range(0.3, 0.45)
	n.add_child(_cyl(r * 0.5, r, height, _vary(base.darkened(0.1)), Vector3(0, height / 2.0 - 0.3, 0), 6))
	var top := _cyl(r * 0.2, r * 0.65, height * 0.45, _vary(base), Vector3(r * 0.3, height * 0.85, 0), 5)
	top.rotation_degrees = Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
	n.add_child(top)
	return n


func _boulder(size: float, color := Color(-1, 0, 0)) -> Node3D:
	var n := Node3D.new()
	var c: Color = data["rock"] if color.r < 0.0 else color
	var b := _ball(size, _vary(c))
	b.scale = Vector3(1.0, 0.7, 0.85)
	b.position.y = size * 0.45
	(b.mesh as SphereMesh).radial_segments = 6
	n.add_child(b)
	return n


func _crystals() -> Node3D:
	var n := Node3D.new()
	var tints := [Color(0.4, 0.9, 1.0), Color(0.8, 0.5, 1.0), Color(0.5, 1.0, 0.8)]
	var tint: Color = tints[_rng.randi() % tints.size()]
	for i in _rng.randi_range(2, 4):
		var h := _rng.randf_range(0.5, 1.3)
		var c := _cyl(0.0, h * 0.22, h, tint, Vector3(_rng.randf_range(-0.3, 0.3), h / 2.0, _rng.randf_range(-0.3, 0.3)), 4)
		c.material_override = _glow(tint)
		c.rotation_degrees = Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20))
		n.add_child(c)
	if _flames.size() < 6:
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 0.8
		light.omni_range = 4.0
		light.position.y = 0.8
		n.add_child(light)
		_flames.append([light, 0.8, _rng.randf() * TAU, 0.15])
	return n


func _stalagmite() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(0.6, 1.6)
	n.add_child(_cyl(0.0, h * 0.25, h, _vary((data["rock"] as Color).darkened(0.15)), Vector3(0, h / 2.0, 0), 5))
	return n


func _torch() -> Node3D:
	var n := Node3D.new()
	n.add_child(_cyl(0.05, 0.06, 1.4, Color(0.36, 0.24, 0.14), Vector3(0, 0.7, 0), 5))
	var flame := _ball(0.14, Color(1.0, 0.6, 0.2), true)
	flame.position.y = 1.5
	flame.scale.y = 1.6
	n.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position.y = 1.6
	n.add_child(light)
	_flames.append([light, 1.4, _rng.randf() * TAU, 0.3])
	return n


func _brazier() -> Node3D:
	var n := _torch()
	n.get_child(0).queue_free()
	n.add_child(_cyl(0.3, 0.12, 0.5, Color(0.3, 0.28, 0.26), Vector3(0, 1.0, 0), 7))
	n.add_child(_cyl(0.08, 0.1, 0.8, Color(0.3, 0.28, 0.26), Vector3(0, 0.4, 0), 5))
	return n


func _pillar() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(1.2, 4.5)
	var stone: Color = data["rock"]
	n.add_child(_box(Vector3(0.9, 0.3, 0.9), stone.darkened(0.1), Vector3(0, 0.15, 0)))
	var shaft := _cyl(0.3, 0.34, h, _vary(stone, 0.05), Vector3(0, h / 2.0 + 0.3, 0), 8)
	n.add_child(shaft)
	if h > 3.5:
		n.add_child(_box(Vector3(0.85, 0.25, 0.85), stone, Vector3(0, h + 0.42, 0)))
	else:
		shaft.rotation_degrees.z = _rng.randf_range(-6, 6)  # broken off
	if _rng.randf() < 0.5:
		var ivy := _ball(0.35, Color(0.3, 0.48, 0.25))
		ivy.position = Vector3(0.2, _rng.randf_range(0.5, h), 0.2)
		ivy.scale = Vector3(0.8, 1.4, 0.6)
		n.add_child(ivy)
	return n


func _arch() -> Node3D:
	var n := Node3D.new()
	var stone: Color = data["rock"]
	for x in [-1.8, 1.8]:
		n.add_child(_box(Vector3(0.8, 4.5, 0.8), _vary(stone, 0.04), Vector3(x, 2.25, 0)))
	n.add_child(_box(Vector3(4.6, 0.7, 0.9), stone.lightened(0.05), Vector3(0, 4.8, 0)))
	return n


func _rubble() -> Node3D:
	var n := Node3D.new()
	var stone: Color = data["rock"]
	for i in _rng.randi_range(2, 4):
		var s := _rng.randf_range(0.2, 0.45)
		n.add_child(_box(Vector3(s * 1.4, s, s), _vary(stone), Vector3(_rng.randf_range(-0.5, 0.5), s / 2.0, _rng.randf_range(-0.5, 0.5)), Vector3(_rng.randf_range(-15, 15), _rng.randf_range(0, 90), 0)))
	return n


func _floating_rock() -> Node3D:
	var n := Node3D.new()
	var stone: Color = data["rock"]
	var r := _rng.randf_range(0.8, 2.2)
	n.add_child(_cyl(r, r * 0.2, r * 1.8, _vary(stone), Vector3.ZERO, 6))
	var grass := _cyl(r * 1.02, r * 1.02, 0.15, Color(0.4, 0.55, 0.3), Vector3(0, r * 0.9, 0), 6)
	n.add_child(grass)
	return n


func _bent_tree() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(2.2, 3.6)
	var trunk := _cyl(0.1, 0.2, h, Color(0.38, 0.28, 0.2), Vector3(0.25, h / 2.0, 0), 5)
	trunk.rotation_degrees.z = -12
	n.add_child(trunk)
	var leaves := _ball(1.1, _vary(Color(0.3, 0.46, 0.26), 0.05))
	leaves.position = Vector3(0.9, h, 0)
	leaves.scale = Vector3(1.6, 0.6, 1.0)  # swept by the wind
	n.add_child(leaves)
	return n


func _mesa() -> Node3D:
	var n := Node3D.new()
	var h := _rng.randf_range(6.0, 16.0)
	var r := _rng.randf_range(3.0, 7.0)
	var red: Color = data["rock"]
	var layers := 3
	for i in layers:
		var lh := h / layers
		n.add_child(_cyl(r * (0.95 - i * 0.08), r * (1.05 - i * 0.08), lh, red.lightened(0.06 * (i % 2)), Vector3(0, lh * (i + 0.5), 0), 7))
	return n


func _cactus() -> Node3D:
	var n := Node3D.new()
	var green := Color(0.32, 0.5, 0.3)
	var h := _rng.randf_range(1.2, 2.4)
	n.add_child(_cyl(0.18, 0.2, h, green, Vector3(0, h / 2.0, 0), 6))
	for side in [-1.0, 1.0]:
		if _rng.randf() < 0.75:
			var y := _rng.randf_range(h * 0.35, h * 0.6)
			n.add_child(_cyl(0.11, 0.11, 0.4, green, Vector3(side * 0.32, y, 0), 6))
			(n.get_child(n.get_child_count() - 1) as Node3D).rotation_degrees.z = 90
			n.add_child(_cyl(0.11, 0.11, 0.6, green, Vector3(side * 0.5, y + 0.3, 0), 6))
	return n


func _bones() -> Node3D:
	var n := Node3D.new()
	var bone := Color(0.9, 0.86, 0.76)
	var skull := _ball(0.22, bone)
	skull.position = Vector3(0, 0.18, 0)
	n.add_child(skull)
	for i in 3:
		var b := _cyl(0.04, 0.04, 0.6, bone, Vector3(_rng.randf_range(-0.5, 0.5), 0.05, _rng.randf_range(-0.5, 0.5)), 5)
		b.rotation_degrees = Vector3(90, _rng.randf_range(0, 180), 0)
		n.add_child(b)
	return n


func _dummy() -> Node3D:
	var n := Node3D.new()
	var straw := Color(0.86, 0.74, 0.42)
	n.add_child(_cyl(0.06, 0.06, 1.8, Color(0.42, 0.3, 0.2), Vector3(0, 0.9, 0), 5))
	n.add_child(_cyl(0.28, 0.3, 0.8, straw, Vector3(0, 1.2, 0), 7))
	n.add_child(_box(Vector3(1.2, 0.1, 0.1), Color(0.42, 0.3, 0.2), Vector3(0, 1.45, 0)))
	var head := _ball(0.2, straw)
	head.position.y = 1.8
	n.add_child(head)
	n.add_child(_box(Vector3(0.3, 0.06, 0.02), Color(0.6, 0.2, 0.18), Vector3(0, 1.25, 0.3)))  # a target stripe
	return n


func _hay() -> Node3D:
	var n := Node3D.new()
	var bale := _cyl(0.45, 0.45, 0.9, Color(0.86, 0.74, 0.4), Vector3(0, 0.45, 0), 8)
	bale.rotation_degrees.z = 90
	n.add_child(bale)
	return n


func _rack() -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.42, 0.3, 0.2)
	for x in [-0.8, 0.8]:
		n.add_child(_cyl(0.05, 0.05, 1.3, wood, Vector3(x, 0.65, 0), 5))
	n.add_child(_box(Vector3(1.8, 0.08, 0.1), wood, Vector3(0, 1.2, 0)))
	for i in 4:
		var w := _box(Vector3(0.05, 1.3, 0.05), Color(0.75, 0.75, 0.8), Vector3(-0.6 + i * 0.4, 0.7, 0.08), Vector3(0, 0, 8))
		n.add_child(w)
	return n


## The training yard's fence: posts and rails round the floor, an opening at the south.
func _fence() -> void:
	var hx := arena.size.x / 2.0 + 0.8
	var hz := arena.size.y / 2.0 + 0.8
	var wood := Color(0.48, 0.34, 0.22)
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var posts := int(length / 2.0)
		for k in posts + 1:
			var p := a.lerp(b, float(k) / posts)
			if i == 2 and absf(p.x) < 2.0:
				continue  # the gate
			add_child(_cyl(0.07, 0.08, 1.1, wood, p + Vector3(0, 0.55, 0), 5))
		for y in [0.45, 0.85]:
			var rail := _box(Vector3(length, 0.07, 0.07), wood, (a + b) / 2.0 + Vector3(0, y, 0))
			rail.rotation.y = atan2(-(b - a).z, (b - a).x)
			add_child(rail)


## The colosseum: a low wall round the sand, then tiers of seats full of
## spectators (they bob and cheer), banners on poles.
func _stands() -> void:
	var hx := arena.size.x / 2.0 + 1.2
	var hz := arena.size.y / 2.0 + 1.2
	var stone: Color = data["rock"]
	var wall_h := 1.4
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var tiers := 6
	var crowd_spots: Array = []
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var along := (b - a).normalized()
		var out := Vector3(along.z, 0, -along.x)  # away from the middle
		if out.dot((a + b) / 2.0) < 0:
			out = -out
		var length := a.distance_to(b)
		var yaw := atan2(along.z, -along.x)
		var wall := _box(Vector3(length + 0.6, wall_h, 0.5), stone.darkened(0.1), (a + b) / 2.0 + Vector3(0, wall_h / 2.0, 0))
		wall.rotation.y = -yaw
		add_child(wall)
		for t in tiers:
			var step_out := 2.2 + t * 1.3
			var h := wall_h + 0.4 + t * 0.9
			var tier_len := length + 2.0 * step_out + 1.0
			var center := (a + b) / 2.0 + out * step_out + Vector3(0, h / 2.0, 0)
			var tier := _box(Vector3(tier_len, h, 1.3), stone.lightened(0.04 * (t % 2)), center)
			tier.rotation.y = -yaw
			tier.visibility_range_begin = HIDE_NEAR
			add_child(tier)
			var seats := int(tier_len / 0.8)
			for k in seats:
				if _rng.randf() < 0.18:
					continue  # an empty seat
				var p := (a + b) / 2.0 + out * (step_out - 0.2) + along * ((k + 0.5) * tier_len / seats - tier_len / 2.0)
				crowd_spots.append([Vector3(p.x, h, p.z), -yaw])
		# banners on poles at the wall
		for k in 3:
			var p := a.lerp(b, (k + 1) / 4.0) + out * 0.4
			add_child(_cyl(0.05, 0.05, 4.0, Color(0.3, 0.26, 0.22), p + Vector3(0, 2.0, 0), 5))
			var banner := _box(Vector3(0.9, 1.6, 0.04), [Color(0.75, 0.2, 0.2), Color(0.2, 0.35, 0.7), Color(0.85, 0.65, 0.2)][(i + k) % 3], p + Vector3(0, 3.1, 0) - out * 0.05)
			banner.rotation.y = -yaw
			add_child(banner)
	_make_crowd(crowd_spots)


func _make_crowd(spots: Array) -> void:
	var shirts := [Color(0.8, 0.3, 0.25), Color(0.3, 0.45, 0.75), Color(0.85, 0.7, 0.3), Color(0.35, 0.6, 0.35), Color(0.6, 0.4, 0.7), Color(0.9, 0.9, 0.85)]
	var furs := [Color(0.55, 0.4, 0.28), Color(0.75, 0.65, 0.5), Color(0.4, 0.4, 0.42), Color(0.85, 0.82, 0.78), Color(0.6, 0.35, 0.2)]
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.42, 0.55, 0.32)
	bodies.mesh = body_mesh
	bodies.instance_count = spots.size()
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	heads.mesh = head_mesh
	heads.instance_count = spots.size()
	_crowd_base.clear()
	for i in spots.size():
		var at: Vector3 = spots[i][0]
		var basis := Basis(Vector3.UP, float(spots[i][1]))
		var body_tf := Transform3D(basis, at + Vector3(0, 0.3, 0))
		var head_tf := Transform3D(basis, at + Vector3(0, 0.75, 0))
		bodies.set_instance_transform(i, body_tf)
		bodies.set_instance_color(i, mute(shirts[_rng.randi() % shirts.size()]))
		heads.set_instance_transform(i, head_tf)
		heads.set_instance_color(i, mute(furs[_rng.randi() % furs.size()]))
		_crowd_base.append([body_tf, head_tf, _rng.randf() * TAU])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = bodies
	_crowd.material_override = mat
	_crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crowd)
	_crowd_heads = MultiMeshInstance3D.new()
	_crowd_heads.multimesh = heads
	_crowd_heads.material_override = mat
	_crowd_heads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crowd_heads)


## The crowd jumps for a moment (big hits, a Crowd Cheer).
var _cheer := 0.0
func cheer(seconds := 1.5) -> void:
	_cheer = maxf(_cheer, seconds)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_cheer = maxf(_cheer - delta, 0.0)
	for c in _clouds:
		var node: Node3D = c[0]
		if float(c[2]) > 0.0:
			node.position.x += float(c[1]) * delta
			if node.position.x > float(c[2]):
				node.position.x -= float(c[2]) * 2.0
		else:
			node.position.y += sin(_time * float(c[1]) * 3.0) * delta * 0.3
	for f in _flames:
		(f[0] as OmniLight3D).light_energy = float(f[1]) * (1.0 + float(f[3]) * sin(_time * 9.0 + float(f[2])) * sin(_time * 3.7 + float(f[2]) * 2.0))
	if _crowd != null:
		_crowd_tick += delta
		if _crowd_tick >= 1.0 / 15.0:  # a 15 fps bob: cheap, and it suits the PS1
			_crowd_tick = 0.0
			var jump := 0.25 if _cheer > 0.0 else 0.05
			for i in _crowd_base.size():
				var b: Array = _crowd_base[i]
				var up := Vector3(0, maxf(sin(_time * (9.0 if _cheer > 0.0 else 3.0) + float(b[2])), 0.0) * jump, 0)
				_crowd.multimesh.set_instance_transform(i, (b[0] as Transform3D).translated(up))
				_crowd_heads.multimesh.set_instance_transform(i, (b[1] as Transform3D).translated(up))


# --- Textures -----------------------------------------------------------------------

## A 64x64 ground texture, made here (no image files): cobble, tiles, grass,
## dirt, sand, rock or rockgrass, in two colours (light, dark).
static func _texture(kind: String, light: Color, dark: Color) -> ImageTexture:
	var key := "%s:%s:%s" % [kind, light.to_html(), dark.to_html()]
	if _textures.has(key):
		return _textures[key]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = hash(kind)
	noise.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var shades := {}
	for y in size:
		for x in size:
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5  # 0..1, tiles seamlessly enough at 4 m
			var c := light.lerp(dark, n * 0.6)
			match kind:
				"cobble":
					var row := int(y / 8)
					var ox := 4 if row % 2 == 1 else 0
					var cell := Vector2i(int((x + ox) / 8) % 8, row)
					if not shades.has(cell):
						shades[cell] = rng.randf_range(-0.12, 0.08)
					var lx := (x + ox) % 8
					var ly := y % 8
					if lx == 0 or ly == 0:
						c = c.lerp(dark, 0.6)  # mortar: soft, so it doesn't flicker at a distance
					else:
						c = c.lightened(float(shades[cell])) if float(shades[cell]) > 0 else c.darkened(-float(shades[cell]))
						if lx == 1 or ly == 1:
							c = c.lightened(0.04)
				"tiles":
					var cell := Vector2i(x / 16, y / 16)
					if not shades.has(cell):
						shades[cell] = rng.randf_range(-0.1, 0.06)
					if x % 16 == 0 or y % 16 == 0:
						c = c.lerp(dark, 0.7)  # grout: soft, so it doesn't flicker at a distance
					else:
						var s := float(shades[cell])
						c = c.lightened(s) if s > 0 else c.darkened(-s)
				"grass":
					c = light.lerp(dark, n)
					if rng.randf() < 0.12:
						c = c.lightened(0.12)
					elif rng.randf() < 0.1:
						c = c.darkened(0.15)
				"dirt":
					c = light.lerp(dark, n * 0.8)
					if rng.randf() < 0.05:
						c = dark.darkened(0.25)  # pebbles
					elif rng.randf() < 0.04:
						c = light.lightened(0.12)
				"sand":
					var ripple := sin(y * 0.55 + n * 6.0) * 0.5 + 0.5
					c = light.lerp(dark, ripple * 0.35 + n * 0.3)
					if rng.randf() < 0.04:
						c = c.darkened(0.12)
				"rock":
					var n2 := (noise.get_noise_2d(x * 3.1, y * 3.1) + 1.0) * 0.5
					c = light.lerp(dark, n * 0.7 + n2 * 0.3)
					if absf(noise.get_noise_2d(x * 1.7 + 50, y * 1.7)) < 0.03:
						c = dark.darkened(0.35)  # cracks
				"rockgrass":
					var patch := noise.get_noise_2d(x * 0.7 + 100, y * 0.7)
					if patch > 0.1:
						c = light.lerp(Color(0.38, 0.46, 0.28), 0.6).lerp(dark, n * 0.6)
					else:
						c = light.lerp(dark, n)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex
