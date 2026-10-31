class_name Moves
## The party's attack moves, used to build combos in the combo bar
## (inspired by Legend of Legaia).
##
## Each move has an AP cost (how much of the bar it fills), one or more hits
## (each a multiplier of the attacker's attack_power), a place in the skill
## triangle ("kind"), and an optional effect against a Defense stance:
##   NONE   - blocked by Defense
##   PIERCE - damages through Defense (the stance stays up)
##   BREAK  - breaks Defense: cancels the stance and knocks the enemy back
## Attack-kind moves interrupt an enemy preparing Smash.
##
## Timing: "duration" is how long the move's animation takes (seconds), so
## the playhead crosses its block at that speed. Hits land spread across the
## block, the last one at its end. Every hit has its own timing box ending
## where it lands; "window" is the box size in seconds. Press J while the
## playhead is inside a box for a Perfect on that hit.

enum Effect { NONE, PIERCE, BREAK }


## Every move, in menu order. Add a new move by adding a line here.
static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"name": "Slash", "duration": 0.55, "window": 0.16, "cost": 10, "hits": [1.0], "kind": Skills.Kind.ATTACK,
			"effect": Effect.NONE, "desc": "Single hit", "color": Color(0.45, 0.65, 0.95)},
		{"name": "Thrust", "duration": 0.7, "window": 0.14, "cost": 15, "hits": [1.1], "kind": Skills.Kind.ATTACK,
			"effect": Effect.PIERCE, "desc": "Single hit, pierces defense", "color": Color(0.3, 0.8, 0.75)},
		{"name": "Double Slash", "duration": 0.9, "window": 0.16, "cost": 15, "hits": [0.7, 0.7], "kind": Skills.Kind.ATTACK,
			"effect": Effect.NONE, "desc": "Two hits", "color": Color(0.7, 0.5, 0.95)},
		{"name": "Overhead Smash", "duration": 1.2, "window": 0.18, "cost": 30, "hits": [2.2], "kind": Skills.Kind.SMASH,
			"effect": Effect.BREAK, "desc": "Heavy hit, breaks defense", "color": Color(1.0, 0.6, 0.2)},
	]
	return list
