class_name FieldState
extends RefCounted
## The Prologue's progress that outlives a room or a fight: who's in the
## party and their HP, the item pouch, experience, the enemies beaten
## (they stay gone until the party uses a save point), and where a lost
## fight sends the party (the last save point, or the dungeon's entrance).
## Static, so the field and the battle scenes share it. (Saving to disk
## comes with save points.)

## Party members (scene paths), in order: the leader first.
static var party: Array = []
## HP of each member (same order); -1 = full.
static var hp: Array = []
## The item pouch: Items.POTION / ETHER / REVIVE -> count. It carries over
## between fights (save points refill it).
static var pouch := {}
## Experience earned so far (no levels yet).
static var experience := 0
## Enemies beaten: "room path:enemy name" -> true.
static var beaten := {}
## Where a lost fight sends the party.
static var respawn_room := ""
static var respawn_entry := ""
## The soldiers can be steered in fights (once the game has explained it).
static var steer_unlocked := false
## A fight that just ended, for the field to pick up (FieldFight), or null.
static var returning: FieldFight = null

## A new Prologue's pouch.
const START_POUCH := {"Potion": 3, "Ether": 2, "Revive": 1}


static func new_game(members: Array, room: String, entry: String) -> void:
	party = members.duplicate()
	hp = []
	for m in party:
		hp.append(-1)
	pouch = START_POUCH.duplicate()
	experience = 0
	beaten = {}
	respawn_room = room
	respawn_entry = entry
	steer_unlocked = false
	returning = null


static func enemy_id(room_path: String, enemy_name: String) -> String:
	return "%s:%s" % [room_path, enemy_name]


static func is_beaten(room_path: String, enemy_name: String) -> bool:
	return beaten.has(enemy_id(room_path, enemy_name))


## A save point: everyone healed, the pouch refilled, every enemy back.
## (Used by save points, Stage 4.)
static func rest(room: String, entry: String) -> void:
	for i in hp.size():
		hp[i] = -1
	for item in START_POUCH:
		pouch[item] = maxi(int(pouch.get(item, 0)), int(START_POUCH[item]))
	beaten = {}
	respawn_room = room
	respawn_entry = entry
