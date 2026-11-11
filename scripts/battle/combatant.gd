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
## Enemies: share of their speed while preparing a skill in the casting zone.
## Fast bosses use 0.5 so they act often but casts stay readable.
@export_range(0.2, 1.0) var cast_zone_speed: float = 1.0
## Enemies: Attack-type hits needed to interrupt a Smash it's preparing
## (bosses: 3). Breaking moves interrupt at once.
@export var interrupt_resist: int = 1

@export_group("Combat")
## Party only: which class's attacks and skills this fighter uses
## ("knight", "archer", "mage", "cleric"; see scripts/battle/moves.gd).
@export var class_id: String = ""
## Party only: whether Defend (Q) and Parry (E) work for this fighter.
@export var can_block: bool = true
@export var can_parry: bool = true
## Damage of a normal Attack. Smash multiplies it.
@export var attack_power: int = 12
## How far this fighter can hit from, in meters between body edges.
## Small for melee, large for ranged fighters.
@export var attack_reach: float = 0.8
## Party only: the class's AP: the most it can spend in one turn (the
## combo bar's length, and the limit for a skill's cost).
@export var combo_limit: float = 50.0
## Monk: the bar lengths its climb steps through ([30, 50, 80, 100]; empty
## = a normal class). It starts on the first; Arts raise it a step at a
## time, mistakes drop it one, Tortoise Special spends it all.
@export var bar_steps: Array[float] = []
## Assassin: while any enemy carries an Assassin's Mark, a strike that can be
## parried is parried automatically, spending one Mark.
@export var auto_parry_with_marks := false
## The letter on the timeline icon (blank = the first letter of the name).
@export var icon_letter := ""
## Party AI: when not steered, walk around behind the focus enemy (Assassin).
@export var flanks := false
## Enemies: no positionals. Every hit counts as "from behind", from anywhere
## (its ring is a plain full circle). Small enemies (Goblin, Kobold).
@export var no_positionals := false
## Enemies only: a boss can't be knocked off the arena or into a hole.
@export var boss := false
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
## Enemies only: how close it walks to its target, in meters between body
## edges. Ranged enemies keep their distance with a bigger number.
@export var preferred_gap: float = 0.3
## Enemies only: when none of its aimed skills reaches anyone, it walks
## close_in_speed times faster to catch up (the Dragon, so kiting it doesn't
## leave it casting only its everyone-hitting skill).
@export var closes_in := false
@export var close_in_speed: float = 2.5
## Enemies only: works together with allies of the same kind (the Kobold
## Archers). They keep apart, a second one picks a different attack from
## what its partner is preparing (one readies Ranged Attack, the other a
## Power Shot), and only one holds a Defense or Counter stance at a time.
@export var team_tactics := false
## Wall bosses (the Gale Maw): set against the middle of the arena's far
## wall at the start, it never walks or turns, and nothing moves it.
@export var anchored := false
## Wall boss: below this share of max HP the arena's lethal sides crumble
## crumble_meters further in, once (0 = never).
@export_range(0.0, 1.0) var crumble_at_share: float = 0.0
@export var crumble_meters: float = 2.5
## Wall boss: its rock-breaking skills crack arena rocks; this many cracks
## crumble one, and it grows back after rock_regrow_turns of its actions
## (0 = rocks never break).
@export var rock_regrow_turns: int = 0
@export var rock_crack_limit: int = 2
## Wall boss: anyone it pushes or pulls is Winded, pushed back this far
## on the timeline (0 = off).
@export var winded_timeline: float = 0.0
## Wall boss: every summon_every of its actions it calls up to summon_count
## of these (topping up the ones still standing).
@export var summon_scene: PackedScene = null
@export var summon_every: int = 4
@export var summon_count: int = 2
## With team_tactics: how far apart partners try to stand, in metres.
@export var tactics_spread := 8.0

var hp: int
## HP lost while defending. It comes back at this fighter's next turn,
## unless they get hit again before then.
var recoverable: int = 0
## True once HP reaches 0. A downed fighter takes no turns.
var is_down := false
## Extra distance to send this fighter back on the timeline the next time
## they return to the start (from a missed parry or a knock-back).
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

## Timed effects on this fighter, by name ("brace", "haste", "taunt"...).
## Each counts down on its caster's turns: {"turns": n, "caster": Combatant}.
## Effects without a turn count last until used up (e.g. "arcane_barrier").
var statuses := {}
## Barrier/shield HP: soaks up damage before HP does.
var shield: int = 0
## Archer's Riposte (and the Monk's Suplex): seconds of counter stance left,
## and what the counter is called.
var riposte_left := 0.0
var counter_name := "Riposte"
## Monk: its tokens ({"Triple": 2, "Rush": 1}), kept in the order they
## were earned, and the bar length before its last lost step (Deep Breath
## gives it back; 0 = nothing to recover).
var tokens := {}
var lost_step := 0.0
## Tutorial controls: "hold" freezes this fighter on the timeline (and an
## enemy in place, without striking); "cannot_fall" keeps HP at 1 or more;
## "forced_skill" is prepared every time instead of a random pick.
var hold := false
## Knight's shield blows: seconds this enemy's timeline stays stopped.
var freeze_left := 0.0
## Mage's Fire: damage taken each time this enemy acts, and how many more times.
var burn_damage := 0
var burn_turns := 0
## Turn control (halts, stuns) works once per action of this enemy's own,
## so no class can lock it forever. Cleared when it acts.
var control_used := false
## Tutorial: start holding as soon as this point on the timeline is reached
## (-1 = never).
var hold_at := -1.0
var cannot_fall := false
var forced_skill: EnemySkill = null
## Enemies only: who it locked onto when it started preparing a skill.
var cast_target: Combatant = null
## Enemies only: areas placed on the party for the skill being prepared
## (circles on each member, lines to each member).
var extra_areas: Array[AttackRange] = []
## Enemies only: damage taken since the current cast began (Shadowflare),
## close-range hits taken during it (Healing Ritual), whether a growing
## area was contained, and the last skill used (to avoid repeating it).
var cast_damage_taken := 0
## Stagger: weighted damage dealt head-on to the skill being prepared.
var stagger_fill := 0.0
var interrupt_count := 0
var contained := false
var last_skill: EnemySkill = null

## Enemies only: Assassin's Marks on this enemy (0 to MAX_MARKS).
var marks := 0
const MAX_MARKS := 5

var _skill_label: Label3D = null
var _marks_label: Label3D = null
## Monk: the climb pips over his head (shown on his own turn).
var _climb_label: Label3D = null
var _token_label: Label3D = null
## Party only: gold ring on the floor showing attack reach.
var _reach_ring: MeshInstance3D = null
## Party only: hides the reach ring (while a strike's rings close in).
var hide_reach := false
var _reach_material: StandardMaterial3D = null
var _body_rest_position := Vector3.ZERO
var _lunge_tween: Tween = null

@onready var _name_label: Label3D = $NameLabel


func _ready() -> void:
	hp = max_hp
	if climbs():
		combo_limit = bar_steps[0]
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
	_reach_ring.visible = not is_down and not hide_reach
	var grow := (body_radius + reach()) / (body_radius + attack_reach)
	_reach_ring.scale = Vector3(grow, 1.0, grow)
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
## Returns the HP actually lost. Arcane Barrier ignores the hit entirely,
## Brace halves it, and shields soak up what's left before HP.
func take_damage(amount: int, recoverable_hit: bool) -> int:
	if statuses.has("arcane_barrier"):
		statuses.erase("arcane_barrier")
		return 0
	if statuses.has("brace"):
		amount = ceili(amount * 0.5)
	if shield > 0:
		var absorbed := mini(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if amount <= 0:
		return 0
	recoverable = 0
	var lost := mini(amount, hp)
	if cannot_fall:
		lost = mini(lost, hp - 1)
	hp -= lost
	if team == Team.ENEMY and loaded_def != null:
		cast_damage_taken += lost
	if hp <= 0:
		_go_down()
	elif recoverable_hit:
		recoverable = lost
	return lost


func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, max_hp)
	return hp - before


## Adds barrier HP, up to half of max HP.
func add_shield(amount: int) -> int:
	var before := shield
	shield = mini(shield + amount, max_hp / 2)
	return shield - before


## Monk: true for a class whose bar climbs in steps.
func climbs() -> bool:
	return not bar_steps.is_empty()


## Monk: which step the bar is on (0 = the starting length).
func bar_step() -> int:
	var index := 0
	for i in bar_steps.size():
		if combo_limit >= bar_steps[i]:
			index = i
	return index


## Monk: a climb Art raises the bar one step. Returns how much it grew
## (0 at the top).
func climb_step() -> float:
	var before := combo_limit
	if bar_step() < bar_steps.size() - 1:
		combo_limit = bar_steps[bar_step() + 1]
	return combo_limit - before


## Monk: true when the bar is at its last step.
func at_top() -> bool:
	return climbs() and combo_limit >= bar_steps[-1]


## Monk: pips over his head on his own turn: one per step climbed (lit) or
## still to climb, and his tokens under them.
func show_climb(visible_now: bool) -> void:
	if not climbs():
		return
	if _climb_label == null:
		_climb_label = _make_climb_label(0.95, 110)  # the pips, big
		_token_label = _make_climb_label(0.45, 40)   # the tokens under them
	var shown := visible_now and not is_down
	_climb_label.visible = shown
	_token_label.visible = shown
	if not shown:
		return
	var pips: PackedStringArray = []
	for i in range(1, bar_steps.size()):
		pips.append("●" if bar_step() >= i else "○")
	_climb_label.text = " ".join(pips)
	var chips: PackedStringArray = []
	for token in tokens:
		var short := "CHEER" if token == "Crowd Cheer" else String(token).to_upper()
		chips.append(short + (" x%d" % tokens[token] if int(tokens[token]) > 1 else ""))
	_token_label.text = "  ".join(chips)


func _make_climb_label(height: float, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.position = _name_label.position + Vector3(0.0, height, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = font_size
	label.outline_size = 14
	label.modulate = Color(1.0, 0.78, 0.35)
	add_child(label)
	return label


## Monk: a mistake drops the bar one step and takes the most recent token
## (Crowd Cheer last, so a drop can still leave a cash-out). Returns a short
## note, or "" when there was nothing to lose.
func drop_step() -> String:
	var lost: PackedStringArray = []
	if bar_step() > 0:
		lost_step = combo_limit
		combo_limit = bar_steps[bar_step() - 1]
		lost.append("bar %d" % int(combo_limit))
	var keys := tokens.keys()
	keys.reverse()
	var pick := ""
	for key in keys:
		if key != "Crowd Cheer":
			pick = key
			break
	if pick == "" and not keys.is_empty():
		pick = keys[0]
	if pick != "":
		tokens[pick] = int(tokens[pick]) - 1
		if int(tokens[pick]) <= 0:
			tokens.erase(pick)
		lost.append("-1 " + pick)
	return ", ".join(lost)


## Monk: Tortoise Special spent the climb: back to the first step.
func spend_climb() -> void:
	combo_limit = bar_steps[0]
	lost_step = 0.0


## Monk: everything its climb built (knocked out = back to the start).
func reset_climb() -> void:
	combo_limit = bar_steps[0]
	lost_step = 0.0
	tokens.clear()


func add_status(status_name: String, turns: int, caster: Combatant) -> void:
	statuses[status_name] = {"turns": turns, "caster": caster}


## Sets this enemy's Assassin's Marks (capped) and the "MARK x3" label under
## its name. Returns how many it has now.
func set_marks(count: int) -> int:
	marks = clampi(count, 0, MAX_MARKS)
	if _marks_label == null:
		_marks_label = Label3D.new()
		_marks_label.position = _name_label.position + Vector3(0.0, 1.05, 0.0)  # above the skill label
		_marks_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marks_label.no_depth_test = true
		_marks_label.font_size = 44
		_marks_label.outline_size = 12
		_marks_label.modulate = Color(0.78, 0.45, 1.0)
		add_child(_marks_label)
	_marks_label.text = ("MARK x%d" % marks) if marks > 0 and not is_down else ""
	return marks


## True if a point is behind this fighter: within 60 degrees of its back
## (a 120-degree cone). Assassin moves care about this.
func is_behind(point: Vector3) -> bool:
	if no_positionals:
		return true
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.length() < 0.01:
		return false
	return flat_forward().dot(to_point.normalized()) <= -0.5


## Called at the start of every turn: effects cast by that fighter count
## down by one, and run out at zero. Returns the names that ran out.
func tick_statuses(turn_owner: Combatant) -> PackedStringArray:
	var ended: PackedStringArray = []
	for status_name in statuses.keys():
		var entry: Dictionary = statuses[status_name]
		if entry.get("caster") != turn_owner or int(entry.get("turns", 0)) <= 0:
			continue
		entry["turns"] = int(entry["turns"]) - 1
		if entry["turns"] <= 0:
			statuses.erase(status_name)
			ended.append(status_name)
	return ended


## Attack reach right now (True Sight adds 25%).
func reach() -> float:
	return attack_reach * (1.25 if statuses.has("true_sight") else 1.0)


## Walking speed right now (Haste adds 20%).
func current_move_speed() -> float:
	return move_speed * (1.2 if statuses.has("haste") else 1.0)


## Short tags for the HP panel, e.g. "BRACE 2  SHIELD 26".
## The Stagger bar to draw for the skill being prepared, once it's
## revealed: {fill, max, hits} (hits: counted in hits, not damage), or {}.
## Healing Ritual (close-range hits) and Shadowflare (damage contains it)
## show their own rules as a bar too.
func stagger_view() -> Dictionary:
	var def := loaded_def
	if def == null or not skill_revealed or is_down:
		return {}
	if def.stagger_bar > 0:
		return {"fill": minf(stagger_fill, def.stagger_bar), "max": float(def.stagger_bar), "hits": false}
	if def.special == EnemySkill.Special.HEAL_ALLIES and def.interrupt_hits > 0:
		return {"fill": float(mini(interrupt_count, def.interrupt_hits)), "max": float(def.interrupt_hits), "hits": true}
	if def.special == EnemySkill.Special.GROWING and def.contain_share > 0.0:
		var need := float(ceili(max_hp * def.contain_share))
		return {"fill": need if contained else minf(cast_damage_taken, need), "max": need, "hits": false}
	return {}


func status_text() -> String:
	var tags: PackedStringArray = []
	if climbs():
		# The Monk's climb first, so a long line never cuts it off.
		tags.append("BAR %d" % int(combo_limit))
		for token in tokens:
			var short := "CHEER" if token == "Crowd Cheer" else String(token).to_upper()
			tags.append(short + (" x%d" % tokens[token] if int(tokens[token]) > 1 else ""))
	var labels := {"brace": "BRACE", "true_sight": "SIGHT", "haste": "HASTE", "agility": "AGILITY",
			"taunt": "TAUNTED", "provoking": "PROVOKE", "guarding": "GUARD", "arcane_barrier": "BARRIER", "arcane_cost": "2x COST", "pinned": "PINNED", "chilled": "CHILLED", "exposed": "EXPOSED", "off_balance": "OFF-BALANCE", "staggered": "STAGGERED"}
	for status_name in statuses:
		var turns := int(statuses[status_name].get("turns", 0))
		var label: String = labels.get(status_name, String(status_name).to_upper())
		tags.append("%s %d" % [label, turns] if turns > 0 else label)
	if shield > 0:
		tags.append("SHIELD %d" % shield)
	if riposte_left > 0.0:
		tags.append("%s %.0fs" % [counter_name.to_upper(), ceilf(riposte_left)])
	return "  ".join(tags)


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
	if climbs():
		reset_climb()
	if marks > 0:
		set_marks(0)  # Marks go with the enemy
	timeline_pos = 0.0
	# Placeholder "knocked out" look: lay the body down and grey the name.
	var body := get_node_or_null("Body") as Node3D
	if _lunge_tween:
		_lunge_tween.kill()
	if body:
		body.rotation_degrees.x = 90.0
		body.position.y = 0.4
	set_highlighted(false)
	if team == Team.ENEMY:
		# Defeated enemies sink away after a moment (they no longer block anyone).
		var fade := create_tween()
		fade.tween_interval(2.0)
		fade.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		fade.tween_callback(func(): visible = false)


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
	if forced_skill != null:
		return forced_skill
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
	global_position += direction * current_move_speed() * delta
	face_toward(direction, delta)


## Turns toward a direction, no faster than turn_speed_degrees allows
## (or max_degrees_per_second, if given).
func face_toward(direction: Vector3, delta: float, max_degrees_per_second: float = -1.0) -> void:
	if anchored:
		return  # a wall boss always faces into the arena
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var forward := flat_forward()
	var current_yaw := atan2(-forward.x, -forward.z)
	var target_yaw := atan2(-direction.x, -direction.z)
	var degrees := turn_speed_degrees if max_degrees_per_second < 0.0 else max_degrees_per_second
	var new_yaw := rotate_toward(current_yaw, target_yaw, deg_to_rad(degrees) * delta)
	basis = Basis(Vector3.UP, new_yaw)
