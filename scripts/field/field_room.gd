class_name FieldRoom
extends Node3D
## One room (loading area) of the field. Build it in the editor:
##
## - Floors, walls, steps: CSG shapes (CSGBox3D...) with Use Collision on.
##   Give each a StandardMaterial3D in a muted colour: at start-up it's
##   swapped for the PS1 material of the same colour (the wobble).
##   Shapes in the "no_ps1" group keep their own material.
## - Stairs: draw the steps without collision and lay a ramp with
##   collision over them (CSG, invisible: in the "ramp" group, hidden at
##   start-up), so the party walks up smoothly.
## - Walls: put them in the "wall" group. A wall on the camera's side of
##   the room is hidden while it is (cutaway, so it never covers the
##   party); it still blocks the way. Which side a wall is on: from the
##   room's centre (the root's origin) to the wall's centre.
## - Entries: Marker3D nodes under an "Entries" node, where the party
##   arrives (the leader on it, facing the marker's -Z, followers lined up
##   behind it: leave about 3 m of floor behind each entry).
## - Doors: FieldDoor nodes (see field_door.gd).
## - Enemies: FieldEnemy nodes under an "Enemies" node (see field_enemy.gd).
## - Fights: battle_area is the floor they use. Pillars, crates and the like
##   in the "obstacle" group are round obstacles in the fight. Doors are
##   the ways to escape.
## - The camera's set angle for the room: camera_yaw / pitch / distance.
##   Entering the room (or the reset key) puts the camera back to it.

## Shown when you enter (later: the menu's location line).
@export var room_name := ""
## The camera's angle on entering: yaw in degrees (0 looks toward -Z),
## pitch down from level, distance in metres.
@export var camera_yaw := 0.0
@export_range(15.0, 75.0) var camera_pitch := 40.0
@export_range(4.0, 18.0) var camera_distance := 10.0
## Background (beyond the walls) and the light.
@export var background := Color(0.07, 0.07, 0.09)
@export var ambient := Color(0.6, 0.6, 0.66)
@export var ambient_energy := 0.55
## The part of the floor a fight here uses (x, z, width, depth): flat
## ground only (fights don't climb yet). Fighters outside it at the start
## are moved in.
@export var battle_area := Rect2(-6, -6, 12, 12)


func _ready() -> void:
	var enemies_node := get_node_or_null("Enemies")
	for node in find_children("*", "GeometryInstance3D", true, false):
		if enemies_node and enemies_node.is_ancestor_of(node):
			continue  # the enemies' figures have their own materials
		if node.is_in_group("ramp"):
			(node as GeometryInstance3D).visible = false
			continue
		if node.is_in_group("no_ps1"):
			continue
		var mat: Material = null
		if node is CSGShape3D:
			mat = node.get("material")
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh and (node as MeshInstance3D).mesh.get_surface_count() > 0:
			mat = (node as MeshInstance3D).get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var ps1 := Figure.material((mat as StandardMaterial3D).albedo_color)
			if node is CSGShape3D:
				node.set("material", ps1)
			else:
				(node as MeshInstance3D).set_surface_override_material(0, ps1)


## Cutaway: a wall is hidden when its outward side faces the camera more
## than this (1: straight at it).
const CUTAWAY_FACING := 0.3


## Hides the walls on the camera's side (see "Walls" above).
func cut_away(camera_position: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("wall"):
		if not is_ancestor_of(node):
			continue
		var wall := node as Node3D
		var out := wall.global_position - global_position
		out.y = 0.0
		var to_camera := camera_position - wall.global_position
		to_camera.y = 0.0
		if out.length() < 0.01 or to_camera.length() < 0.01:
			continue
		wall.visible = out.normalized().dot(to_camera.normalized()) < CUTAWAY_FACING


## The entry marker with this name (or the first one, or null).
func entry(entry_name: String) -> Marker3D:
	var entries := get_node_or_null("Entries")
	if entries == null:
		return null
	var found := entries.get_node_or_null(entry_name) as Marker3D
	if found == null and entries.get_child_count() > 0:
		found = entries.get_child(0) as Marker3D
	return found


func enemies() -> Array[FieldEnemy]:
	var list: Array[FieldEnemy] = []
	for node in find_children("*", "CharacterBody3D", true, false):
		if node is FieldEnemy:
			list.append(node as FieldEnemy)
	return list


## Every enemy back where it started, unaware (escaping a fight, later).
func reset_enemies() -> void:
	for enemy in enemies():
		if not enemy.gone:
			enemy.reset()


## The fight's obstacles: [[position, radius], ...] (CSG boxes and
## cylinders in the "obstacle" group).
func battle_obstacles() -> Array:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("obstacle"):
		if not is_ancestor_of(node) or not node is Node3D:
			continue
		var r := 0.6
		if node is CSGBox3D:
			var box := (node as CSGBox3D).size
			r = maxf(box.x, box.z) * 0.62
		elif node is CSGCylinder3D:
			r = (node as CSGCylinder3D).radius
		list.append([(node as Node3D).global_position, r])
	return list


## Ways to escape a fight: [{pos, inside, facing, label}] per door.
func exits() -> Array:
	var list: Array = []
	var middle := Vector3(battle_area.get_center().x, 0.0, battle_area.get_center().y) + global_position
	for door in doors():
		var at := door.global_position
		at.y = 0.0
		var inward := middle - at
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 0.01 else Vector3.FORWARD
		list.append({"pos": at, "inside": at + inward * 2.2, "facing": atan2(-inward.x, -inward.z), "label": door.label})
	return list


func doors() -> Array[FieldDoor]:
	var list: Array[FieldDoor] = []
	for node in find_children("*", "Area3D", true, false):
		if node is FieldDoor:
			list.append(node as FieldDoor)
	return list
