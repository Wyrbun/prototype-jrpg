class_name FieldDoor
extends Area3D
## A way out of a room: walking the leader into it takes the party to
## another room (loading area), arriving at one of that room's entries.
##
## Put one in a room's scene with a CollisionShape3D child (a box across
## the doorway). to_room: the room scene; to_entry: the name of a Marker3D
## in that room's Entries node, where the party arrives (facing the
## marker's -Z, its blue arrow's opposite).

@export_file("*.tscn") var to_room := ""
@export var to_entry := ""
## How escaping a fight this way reads ("Escaping through the north door").
@export var label := "through the door"

signal entered_by_leader(door: FieldDoor)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << (FieldWalker.LEADER_LAYER - 1)
	monitorable = false
	body_entered.connect(func(body: Node3D):
		if body is FieldWalker and (body as FieldWalker).is_leader:
			entered_by_leader.emit(self))
