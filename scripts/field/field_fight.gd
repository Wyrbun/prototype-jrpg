class_name FieldFight
extends RefCounted
## A fight that starts on the field, in the room where the party met the
## enemy: what the battle needs to set it up (the room, where everyone
## stood, how it started, the exits), and, once it's over, how it went.
## Positions are the room's own coordinates (the field's).

const AMBUSH := "ambush"
const NORMAL := "normal"
const CAUGHT := "caught"

## The room (its scene), and the part of its floor the fight uses.
var room_path := ""
var area := Rect2(-7, -5, 14, 10)
## Round obstacles inside the area: [[position, radius], ...].
var obstacles: Array = []
## Party: [{scene, pos, facing, hp (-1 full)}], the leader first.
var party: Array = []
## Enemies: [{scene, pos, facing, name}] (name: its node in the room).
var enemies: Array = []
## AMBUSH, NORMAL or CAUGHT; for CAUGHT, which enemy (index) touched.
var how := NORMAL
var catcher := -1
var pouch := {}
## Exits to escape by: [{pos, inside, facing, label}] (inside: where the
## party stands after escaping, just in from the doorway).
var exits: Array = []
var can_escape := true
## The soldiers can't be steered yet.
var lock_steering := true
## The field camera's angle when it started (the fight starts from it).
var camera_yaw := 0.0
var camera_pitch := 40.0

## Result, set by the battle: "victory", "defeat" or "escaped".
var outcome := ""
## HP of each party member afterwards (same order as party).
var party_hp: Array = []
## Names of the enemies beaten.
var beaten: Array = []
## Escaped: which exit.
var exit_index := -1
## The leader's position at the end (room coordinates).
var leader_pos := Vector3.ZERO
var leader_facing := 0.0
## Victory: experience and items found.
var experience := 0
var drops: Array = []
