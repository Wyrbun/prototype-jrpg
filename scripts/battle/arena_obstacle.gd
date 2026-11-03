@tool
class_name ArenaObstacle
extends Node3D
## Something on the battlefield nobody can walk through.
##
## Put these as children of an Arena and drag them around in the editor.
## - Rock: blocks movement and line of sight (attacks can't pass it).
## - Pit: blocks movement only; you can see and attack across it.

enum Kind { ROCK, PIT }

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


func _ready() -> void:
	_rebuild()


func blocks_sight() -> bool:
	return kind == Kind.ROCK


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
