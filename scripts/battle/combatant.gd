class_name Combatant
extends Node3D
## One fighter in battle: a party member or an enemy.
##
## Every character in the arena uses this script. The variables marked
## @export show up in the Inspector panel on the right side of the editor,
## so you can tweak them per character without touching code.

enum Team { PARTY, ENEMY }

@export var display_name: String = "Unnamed"
@export var team: Team = Team.PARTY
@export var max_hp: int = 100
## How fast this character's icon moves along the timeline.
## Higher speed means more turns.
@export var speed: float = 10.0

@export_group("Combat")
## Damage of a normal Attack. Smash multiplies it.
@export var attack_power: int = 12
## How far this fighter can hit from, in meters between body edges.
## Small for melee, large for ranged fighters.
@export var attack_reach: float = 0.8
## Party only: how much AP of moves fits in this fighter's combo bar.
## A bigger limit means a longer bar and longer combos.
@export var combo_limit: float = 50.0
## Enemies only: the skills it can prepare. Add an element, choose
## "New EnemySkill" and fill it in. Left empty, the enemy uses a basic
## Attack / Smash / Defense / Counter set.
@export var skills: Array[EnemySkill] = []

@export_group("Movement")
## Walking speed in meters per second.
@export var move_speed: float = 5.0
## How fast the fighter can turn, in degrees per second.
## Slow-turning enemies are easier to get behind.
@export var turn_speed_degrees: float = 720.0
## Roughly how wide the fighter is, so bodies don't overlap.
@export var body_radius: float = 0.45
## Enemies only: how fast it can turn while preparing a skill (it can't
## walk then). Slower means it's easier to slip around it.
@export var cast_turn_speed_degrees: float = 40.0

var hp: int
## HP lost while defending. It comes back at this fighter's next turn,
## unless they get hit again before then.
var recoverable: int = 0
## True once HP reaches 0. A downed fighter takes no turns.
var is_down := false
## Extra distance to send this fighter back on the timeline the next time
## they return to the start (from a missed parry or a stagger).
var timeline_penalty: float = 0.0
## Where this fighter is on the timeline. 0 is the start; reaching the
## battle's TIMELINE_LENGTH means it's their turn.
var timeline_pos: float = 0.0
## The fighter's body color, reused for their timeline icon.
var color: Color = Color.GRAY
## The enemy's danger cone, if it has one (party members don't).
var attack_range: AttackRange = null

## Enemies only: the skill being prepared, with its shape, damage and
## rules (null when not preparing or holding a stance).
var loaded_def: EnemySkill = null
## Seconds a Defense/Counter stance stays up after the enemy's turn.
var stance_time_left := 0.0

## The skill being prepared right now, or Skills.NONE.
var loaded_skill: int = Skills.NONE
## False while the skill is still hidden ("..."), true once it's shown.
var skill_revealed := false
## Defense or Counter while that stance is active (the whole casting zone).
var stance: int = Skills.NONE

var _skill_label: Label3D = null
## Party only: gold ring on the floor showing attack reach.
var _reach_ring: MeshInstance3D = null
var _reach_material: StandardMaterial3D = null
var _body_rest_position := Vector3.ZERO
var _lunge_tween: Tween = null

@onready var _name_label: Label3D = $NameLabel


func _ready() -> void:
	hp = max_hp
	_name_label.text = display_name
	# Everyone starts a little way along the bar, so the first turns vary.
	timeline_pos = randf_range(0.0, 25.0)

	var body := get_node_or_null("Body") as MeshInstance3D
	if body and body.get_surface_override_material(0) is StandardMaterial3D:
		color = (body.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	attack_range = get_node_or_null("AttackRange") as AttackRange
	if body:
		_body_rest_position = body.position

	if team == Team.ENEMY:
		# A second floating label, above the name, for the loaded skill.
		_skill_label = Label3D.new()
		_skill_label.position = _name_label.position + Vector3(0.0, 0.55, 0.0)
		_skill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_skill_label.font_size = 64
		_skill_label.outline_size = 16
		add_child(_skill_label)

	if team == Team.PARTY:
		_build_reach_ring()

	# Groups are Godot's way of tagging nodes so other scripts can find them.
	add_to_group("combatants")


## Party only: a thin gold circle on the floor. An enemy is in reach when
## its edge touches the circle.
func _build_reach_ring() -> void:
	var radius := body_radius + attack_reach
	var width := 0.07
	var vertices := PackedVector3Array()
	var segments := 64
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var in0 := Vector3(cos(a0), 0, sin(a0)) * (radius - width)
		var out0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var in1 := Vector3(cos(a1), 0, sin(a1)) * (radius - width)
		var out1 := Vector3(cos(a1), 0, sin(a1)) * radius
		vertices.append_array([in0, out0, out1, in0, out1, in1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_reach_material = StandardMaterial3D.new()
	_reach_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reach_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reach_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_reach_ring = MeshInstance3D.new()
	_reach_ring.mesh = ring_mesh
	_reach_ring.material_override = _reach_material
	_reach_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reach_ring.position.y = 0.04
	add_child(_reach_ring)
	update_reach_ring(false, false)


## Bright for the fighter you control, faint for the others; glows when
## an enemy is close enough to hit. Hidden once knocked out.
func update_reach_ring(is_controlled: bool, enemy_in_reach: bool) -> void:
	if _reach_ring == null:
		return
	_reach_ring.visible = not is_down
	var alpha := 0.85 if is_controlled else 0.25
	if enemy_in_reach:
		alpha = minf(alpha + 0.15, 1.0)
	var gold := Color(1.0, 0.92, 0.45) if enemy_in_reach else Color(0.95, 0.75, 0.25)
	gold.a = alpha
	_reach_material.albedo_color = gold


## Turns the floating name gold for the fighter you're controlling.
func set_highlighted(on: bool) -> void:
	if is_down:
		_name_label.modulate = Color(0.5, 0.5, 0.5)
	else:
		_name_label.modulate = Color(1.0, 0.82, 0.2) if on else Color.WHITE


## Loses HP. If recoverable_hit is true (a defended hit), the HP lost can
## come back later. Any new hit locks in earlier recoverable damage.
func take_damage(amount: int, recoverable_hit: bool) -> void:
	recoverable = 0
	var lost := mini(amount, hp)
	hp -= lost
	if hp <= 0:
		_go_down()
	elif recoverable_hit:
		recoverable = lost


## Gives back recoverable HP. Called when this fighter's turn starts.
## Returns how much came back.
func recover_hp() -> int:
	var amount := recoverable
	hp = mini(hp + recoverable, max_hp)
	recoverable = 0
	return amount


func _go_down() -> void:
	is_down = true
	recoverable = 0
	timeline_pos = 0.0
	# Placeholder "knocked out" look: lay the body down and grey the name.
	var body := get_node_or_null("Body") as Node3D
	if _lunge_tween:
		_lunge_tween.kill()
	if body:
		body.rotation_degrees.x = 90.0
		body.position.y = 0.4
	set_highlighted(false)


## Distance between this fighter's edge and another's (0 = touching).
func gap_to(other: Combatant) -> float:
	var offset := other.global_position - global_position
	offset.y = 0.0
	return offset.length() - body_radius - other.body_radius


## Placeholder attack animation: the body jabs forward and back.
func play_lunge() -> void:
	var body := get_node_or_null("Body") as Node3D
	if body == null or is_down:
		return
	if _lunge_tween:
		_lunge_tween.kill()
	body.position = _body_rest_position
	_lunge_tween = create_tween()
	_lunge_tween.tween_property(body, "position", _body_rest_position + Vector3(0, 0, -0.45), 0.07)
	_lunge_tween.tween_property(body, "position", _body_rest_position, 0.15)


## Enemies only: picks one of its skills at random, by weight.
func pick_skill() -> EnemySkill:
	var pool := skills if not skills.is_empty() else _basic_skills()
	var total := 0
	for skill in pool:
		total += skill.weight
	if total <= 0:
		return pool[0]
	var roll := randi_range(1, total)
	for skill in pool:
		roll -= skill.weight
		if roll <= 0:
			return skill
	return pool[0]


static var _basic_cache: Array[EnemySkill] = []

## The plain skill-triangle set, for enemies with no skills of their own.
static func _basic_skills() -> Array[EnemySkill]:
	if _basic_cache.is_empty():
		var weights := {Skills.Kind.ATTACK: 4, Skills.Kind.SMASH: 2, Skills.Kind.DEFENSE: 2, Skills.Kind.COUNTER: 1}
		for kind in weights:
			var info := Skills.info(kind)
			var shape := EnemySkill.Shape.CIRCLE if info["angle"] >= 360.0 else EnemySkill.Shape.CONE
			_basic_cache.append(EnemySkill.make(info["name"], kind, shape, info["radius"], info["angle"],
					info.get("damage", 0), info.get("windup", 1.0), weights[kind]))
	return _basic_cache


## Enemies only: sets the floating skill text ("" hides it).
func show_skill_text(text: String, color: Color = Color.WHITE) -> void:
	if _skill_label:
		_skill_label.text = text
		_skill_label.modulate = color


## The direction this fighter is facing, flat on the floor.
## In Godot, "forward" is the -Z direction.
func flat_forward() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Walks in a direction for one frame, turning to face it.
func step(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	global_position += direction * move_speed * delta
	face_toward(direction, delta)


## Turns toward a direction, no faster than turn_speed_degrees allows
## (or max_degrees_per_second, if given).
func face_toward(direction: Vector3, delta: float, max_degrees_per_second: float = -1.0) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var forward := flat_forward()
	var current_yaw := atan2(-forward.x, -forward.z)
	var target_yaw := atan2(-direction.x, -direction.z)
	var degrees := turn_speed_degrees if max_degrees_per_second < 0.0 else max_degrees_per_second
	var new_yaw := rotate_toward(current_yaw, target_yaw, deg_to_rad(degrees) * delta)
	basis = Basis(Vector3.UP, new_yaw)
