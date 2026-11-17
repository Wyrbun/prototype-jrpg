class_name Items
extends RefCounted
## The fight's pouch of items. Each item is shaped like an Ability (name,
## target, colour, description) so the Abilities list, targeting and
## _use_skill can carry it; "item": true marks it, and it costs no AP.
## Using one takes the turn's Ability slot.

const POTION := "Potion"
const ETHER := "Ether"
const REVIVE := "Revive"
const ORDER := [POTION, ETHER, REVIVE]

const GREEN := Color(0.45, 0.95, 0.5)
const BLUE := Color(0.45, 0.75, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)


## The item's Ability-like entry (one Potion heals 35% of the target's max
## HP, one Ether restores 40% of max AP, one Revive brings a downed ally back
## with 50% HP).
static func info(item_name: String) -> Dictionary:
	match item_name:
		POTION:
			return {"name": POTION, "item": true, "cost": 0, "target": Moves.Target.ALLY, "color": GREEN,
					"desc": "Heal an ally (or yourself) 35% of their max HP", "heal": 0.35}
		ETHER:
			return {"name": ETHER, "item": true, "cost": 0, "target": Moves.Target.NONE, "color": BLUE,
					"desc": "Restore 40% of the party's max AP", "ap_share": 0.40}
		REVIVE:
			return {"name": REVIVE, "item": true, "cost": 0, "target": Moves.Target.DOWNED_ALLY, "color": GOLD,
					"desc": "A downed ally gets back up with 50% of their max HP", "heal": 0.50}
	return {}


## Every item, in menu order, with "cost_text" showing how many are left.
static func list(pouch: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_name in ORDER:
		var entry := info(item_name)
		entry["count"] = int(pouch.get(item_name, 0))
		entry["cost_text"] = "x%d" % entry["count"]
		out.append(entry)
	return out
