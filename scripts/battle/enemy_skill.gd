class_name EnemySkill
extends Resource
## One skill an enemy can prepare in the casting zone.
##
## Enemies keep a list of these in their "Skills" property (select the enemy
## and look under Combat in the Inspector). Each entry is edited right there:
## add a new element, pick "New EnemySkill", and fill it in. Duplicating an
## enemy node and changing its skills is how you design a new enemy.

## The area's shape on the floor. A half-circle is a Cone with a 180 angle;
## a circle around the enemy is a Cone with a 360 angle (or Circle).
enum Shape { CONE, CIRCLE, LINE, DONUT }
## How the skill works beyond "one area in front of the enemy":
## - ON_EACH_TARGET: a circle (radius) dropped on every party member.
##   It follows them while hidden and stays put once revealed.
## - LINE_TO_EACH: a line (width) from the enemy to every party member,
##   aimed while hidden and locked once revealed.
## - GROWING: a circle around the enemy that grows from radius to
##   max_radius over the cast, unless the party contains it by dealing
##   contain_share of the enemy's max HP during the cast.
## - HEAL_ALLIES: heals every enemy within radius (no damage); interrupted
##   by interrupt_hits party hits from within interrupt_range meters.
enum Special { NONE, ON_EACH_TARGET, LINE_TO_EACH, GROWING, HEAL_ALLIES }
## What happens to someone caught in two or more of the areas.
enum Overlap { NORMAL, DOUBLE, ONE_HP }

## Shown above the enemy and on the timeline once revealed.
@export var skill_name: String = "Attack"
## Its place in the skill triangle. Attack/Smash hit; Defense/Counter are
## stances that last through the casting zone and linger after the turn.
@export var kind: Skills.Kind = Skills.Kind.ATTACK
## How often this skill is picked compared to the enemy's other skills.
@export_range(0, 10) var weight: int = 1

@export_group("Area")
@export var shape: Shape = Shape.CONE
## Reach in meters: cone/circle radius, line length, donut outer edge.
@export var radius: float = 3.7
## Cone width in degrees (Cone only).
@export_range(10.0, 360.0) var angle: float = 120.0
## Line width in meters (Line only).
@export var width: float = 1.2
## Size of the safe hole in the middle, in meters (Donut only).
@export var inner_radius: float = 1.5

@export_group("Hit")
## Damage of a hit that isn't Parried or Defended.
@export var damage: int = 20
## Seconds from the start of the strike until the hit lands. Longer gives
## more time to read and react.
@export var windup: float = 1.0
## Parry (E) does nothing against this skill.
@export var cannot_be_parried: bool = false
## Defend (Q) does nothing against this skill.
@export var cannot_be_blocked: bool = false
## Strikes several times in a row (one ring per hit); a Parry stops the rest.
@export_range(1, 5) var hits: int = 1
## The last hit throws its targets this many meters away (0 = no throw).
@export var launch: float = 0.0
## Damage shrinks when several are hit together: 100%, 67%, 50%, 40%...
@export var shared_damage: bool = false
## Leaves its area burning for this many of the enemy's turns (0 = none);
## anyone standing in it loses trail_damage_per_second.
@export var trail_turns: int = 0
@export var trail_damage_per_second: float = 0.0

@export_group("Special")
@export var special: Special = Special.NONE
## ON_EACH_TARGET / LINE_TO_EACH: the rule for anyone in 2+ areas.
@export var overlap: Overlap = Overlap.NORMAL
## ON_EACH_TARGET / LINE_TO_EACH: overlaps also can't be blocked.
@export var overlap_unblockable: bool = false
## GROWING: the size it grows to, and the damage (share of max HP) that stops it.
@export var max_radius: float = 8.0
@export_range(0.0, 1.0) var contain_share: float = 0.1
## HEAL_ALLIES: share of each ally's max HP healed.
@export_range(0.0, 1.0) var heal_share: float = 0.2
@export var interrupt_hits: int = 3
@export var interrupt_range: float = 1.5


func is_offensive() -> bool:
	return special != Special.HEAL_ALLIES and Skills.is_offensive(kind)


func color() -> Color:
	if special == Special.HEAL_ALLIES:
		return Color(0.4, 0.95, 0.5)
	return Skills.info(kind)["color"]


## True if the skill puts its areas on the party, not in front of the enemy.
func placed_on_party() -> bool:
	return special == Special.ON_EACH_TARGET or special == Special.LINE_TO_EACH


## A skill built in code, for enemies that have no skills set in the scene.
static func make(p_name: String, p_kind: int, p_shape: int, p_radius: float, p_angle: float,
		p_damage: int, p_windup: float, p_weight: int) -> EnemySkill:
	var skill := EnemySkill.new()
	skill.skill_name = p_name
	skill.kind = p_kind
	skill.shape = p_shape
	skill.radius = p_radius
	skill.angle = p_angle
	skill.damage = p_damage
	skill.windup = p_windup
	skill.weight = p_weight
	return skill
