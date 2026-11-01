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
## - ON_MARKED: one circle (radius) on the party member the enemy locked
##   onto. It follows them while hidden (and after the reveal if always_hits);
##   it hits everyone inside, so the target should stand alone.
enum Special { NONE, ON_EACH_TARGET, LINE_TO_EACH, GROWING, HEAL_ALLIES, ON_MARKED }
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
## Mechanic skills: they can't be dodged, only answered. Revealed with
## "UNAVOIDABLE"; taking one only costs max AP if you failed its answer.
## Circles/lines placed on the party (ON_EACH_TARGET, LINE_TO_EACH,
## ON_MARKED): everyone it was placed on is hit wherever they stand (a rock
## still blocks a line). Spreading out only avoids the overlap rule.
@export var always_hits: bool = false
## The enemy's locked target is always hit, however far it runs, unless a
## rock blocks the enemy's view of it (Breath, Power Shot).
@export var always_hits_target: bool = false
## GROWING: the explosion hits the whole party, for damage scaled by how big
## the circle got (contain it early for low damage).
@export var hits_everyone: bool = false
## While this skill is being cast, the enemy moves along the timeline at
## this share of its speed (below 1 = a slower cast, more time to react).
@export_range(0.2, 2.0) var cast_speed: float = 1.0
## Only the party member closest to the enemy is hit (Lines: the first one
## in the way).
@export var stops_at_first_hit: bool = false
## The enemy keeps facing its target exactly for the whole cast, right up
## to the strike (no slow-down at the end): turning away can't dodge it.
@export var tracks_target: bool = false
## When revealed, the enemy turns at once to face its target, then stays
## locked in that direction until it strikes.
@export var snaps_to_target: bool = false

@export_group("Stance")
## Defense stances: share of a hit's damage that still gets through
## (0 = blocks it completely). Piercing and breaking moves ignore the stance.
@export_range(0.0, 1.0) var let_through: float = 0.0

@export_group("Push and follow-up")
## Pushes everyone inside the area out past its edge (no damage of its own
## unless damage is set above 0).
@export var push_out: bool = false
## A skill used right after this one, revealed at once, striking
## follow_up_delay seconds later (time you can move in). Everyone this skill
## caught is hit by it wherever they end up; anyone else can still dodge it.
@export var follow_up: EnemySkill = null
@export var follow_up_delay: float = 2.0

@export_group("Spikes")
## Leaves this many spikes inside the area; anyone walking into one takes
## spike_damage. They last trail_turns of the enemy's turns.
@export var spikes: int = 0
@export var spike_damage: int = 15

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


## True for mechanic skills (always hit; the answer is a mechanic, not a dodge).
func is_mechanic() -> bool:
	return always_hits or always_hits_target or hits_everyone


## True if the enemy keeps facing its target exactly for the whole cast:
## set by hand (tracks_target), and always for skills that never miss their
## target, so what you see is what hits.
func aims_exactly() -> bool:
	return tracks_target or always_hits_target


## True if circles / lines placed on the party keep following their party
## member after the reveal (unavoidable ones do; others lock in place).
func keeps_following() -> bool:
	return placed_on_party() and always_hits


## Parry (E) works on it: not for skills marked cannot_be_parried, and never
## for unavoidable mechanic skills (they just deal their damage).
func parryable() -> bool:
	return not cannot_be_parried and not is_mechanic()


## Defend (Q) works on it: same rule.
func blockable() -> bool:
	return not cannot_be_blocked and not is_mechanic()


func is_offensive() -> bool:
	return special != Special.HEAL_ALLIES and Skills.is_offensive(kind)


func color() -> Color:
	if special == Special.HEAL_ALLIES:
		return Color(0.4, 0.95, 0.5)
	return Skills.info(kind)["color"]


## True if the skill puts its areas on the party, not in front of the enemy.
func placed_on_party() -> bool:
	return special == Special.ON_EACH_TARGET or special == Special.LINE_TO_EACH \
			or special == Special.ON_MARKED


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
