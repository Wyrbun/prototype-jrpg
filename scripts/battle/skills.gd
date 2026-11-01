class_name Skills
## The skill triangle, inspired by Mabinogi.
##
## Enemies load one of these when their icon enters the casting zone of the
## timeline, and everyone can see which one it is. Later the party will use
## the same skills. Each skill has its own area shape, so you can read what
## is coming from the floor as well as from the bar.
##
## Planned matchups (see docs/battle-design.md):
##   Attack  beats Smash (interrupts the slow wind-up)
##   Smash   beats Defense (breaks the guard)
##   Defense beats Attack (blocks it)
##   Counter beats Attack and Smash, but only if timed right

## SPECIAL: enemy skills outside the triangle (Fireball-like spells, curses,
## rituals). They don't interrupt or get interrupted by the triangle rules.
enum Kind { ATTACK, SMASH, DEFENSE, COUNTER, SPECIAL }

## Means "no skill loaded".
const NONE := -1


## Everything the battle needs to know about a skill, in one place.
## Change the numbers here to reshape a skill's area, or to change how much
## it hurts ("damage") and how long its strike takes to land ("windup",
## in seconds). A longer windup gives you more time to read and react.
static func info(kind: int) -> Dictionary:
	match kind:
		Kind.ATTACK:
			return {"name": "Attack", "color": Color(1.0, 0.3, 0.2), "offensive": true, "radius": 3.7, "angle": 120.0, "damage": 20, "windup": 1.0}
		Kind.SMASH:
			return {"name": "Smash", "color": Color(1.0, 0.6, 0.1), "offensive": true, "radius": 4.4, "angle": 50.0, "damage": 35, "windup": 1.4}
		Kind.DEFENSE:
			return {"name": "Defense", "color": Color(0.3, 0.6, 1.0), "offensive": false, "radius": 1.9, "angle": 360.0, "damage": 0, "windup": 0.0}
		Kind.COUNTER:
			return {"name": "Counter", "color": Color(0.75, 0.4, 1.0), "offensive": false, "radius": 2.2, "angle": 360.0, "damage": 0, "windup": 0.0}
		Kind.SPECIAL:
			return {"name": "Special", "color": Color(1.0, 0.35, 0.75), "offensive": true, "radius": 3.0, "angle": 360.0, "damage": 20, "windup": 1.4}
	return {"name": "", "color": Color.WHITE, "offensive": false, "radius": 0.0, "angle": 0.0, "damage": 0, "windup": 0.0}


static func is_offensive(kind: int) -> bool:
	return kind != NONE and info(kind)["offensive"]
