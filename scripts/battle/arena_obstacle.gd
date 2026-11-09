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
##   Parry-like save. Marked by a glowing red ring lined with skulls.

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
## Holes: the ring of skulls slowly turns round the drop.
var _skull_ring: Node3D = null
const SKULL_TURN_SPEED := 0.25  # radians per second


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _skull_ring != null and not Engine.is_editor_hint():
		_skull_ring.rotation.y += SKULL_TURN_SPEED * delta


func blocks_sight() -> bool:
	return kind == Kind.ROCK


func is_lethal() -> bool:
	return kind == Kind.HOLE


## A skull lying on the floor (the death wall's marker).
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
	_visual = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if kind == Kind.ROCK:
		var rock := CylinderMesh.new()
		rock.top_radius = radius * 0.8
		rock.bottom_radius = radius
		rock.height = 1.8
		rock.radial_segments = 9  # a bit faceted, so it reads as stone
		_visual.mesh = rock
		_visual.position.y = 0.9
		material.albedo_color = Color(0.45, 0.42, 0.38)
	elif kind == Kind.HOLE:
		# A deep black drop with a glowing red ring and skulls around it.
		var drop := CylinderMesh.new()
		drop.top_radius = radius
		drop.bottom_radius = radius
		drop.height = 0.006
		drop.radial_segments = 48
		_visual.mesh = drop
		_visual.position.y = 0.008
		material.albedo_color = Color(0.0, 0.0, 0.0)
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius + 0.06
		torus.outer_radius = radius + 0.16
		torus.rings = 48
		ring.mesh = torus
		ring.scale = Vector3(1.0, 0.15, 1.0)
		ring.position.y = 0.03
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.18, 0.15)
		ring.material_override = glow
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(ring)
		_skull_ring = Node3D.new()
		_visual.add_child(_skull_ring)
		var count := maxi(int(TAU * (radius + 0.55) / 1.1), 8)
		for i in count:
			var a := TAU * i / count
			_skull_ring.add_child(make_skull(Vector3(cos(a), 0.0, sin(a)) * (radius + 0.55) - Vector3(0, 0.008, 0)))
	else:
		var hole := CylinderMesh.new()
		hole.top_radius = radius
		hole.bottom_radius = radius
		# A thin disc just above the floor, well under the enemy areas (drawn
		# at 3 cm): at the same height they'd flicker over each other.
		hole.height = 0.006
		hole.radial_segments = 48
		_visual.mesh = hole
		_visual.position.y = 0.008
		material.albedo_color = Color(0.02, 0.02, 0.03)
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.material_override = material
	add_child(_visual)
