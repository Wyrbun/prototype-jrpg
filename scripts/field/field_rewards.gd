class_name FieldRewards
extends RefCounted
## What beating an enemy on the field is worth: experience, and the items
## it may drop (enemies don't drop Credits). Placeholder numbers until
## levels exist; by the enemy's name (copies' letters ignored).

## Name -> [experience, [[item, chance 0-1], ...]].
const TABLE := {
	"Ratkin Fighter": [12, [["Potion", 0.35]]],
	"Kobold Archer": [14, [["Potion", 0.3], ["Ether", 0.1]]],
	"Bandit Arcanist": [18, [["Ether", 0.3]]],
	"Living Armor": [40, [["Revive", 0.25], ["Potion", 0.5]]],
	"Stone Golem": [40, [["Potion", 0.5]]],
}
const DEFAULT := [10, [["Potion", 0.2]]]


static func entry(display_name: String) -> Array:
	var base := display_name
	# "Kobold Archer B" -> "Kobold Archer"
	if base.length() > 2 and base[base.length() - 2] == " " and "ABCD".contains(base[base.length() - 1]):
		base = base.substr(0, base.length() - 2)
	return TABLE.get(base, DEFAULT)


static func experience(display_name: String) -> int:
	return int(entry(display_name)[0])


## The items this enemy drops this time (rolled with rng).
static func roll_drops(display_name: String, rng: RandomNumberGenerator) -> Array:
	var found: Array = []
	for drop in entry(display_name)[1]:
		if rng.randf() < float(drop[1]):
			found.append(String(drop[0]))
	return found
