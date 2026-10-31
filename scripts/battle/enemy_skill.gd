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
## Defend (Q) does nothing against this skill (it also ignores Defense).
@export var cannot_be_blocked: bool = false


func is_offensive() -> bool:
	return Skills.is_offensive(kind)


func color() -> Color:
	return Skills.info(kind)["color"]


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
