extends Node3D
## The battle scene's main script.
##
## How a battle flows (see docs/battle-design.md for the reasoning):
##
## Timeline: everyone slides along the bar at their own speed. Reaching the
## end means it's your turn and time stops. In the orange casting zone near
## the end, enemies stand still (turning slowly) and prepare a skill:
## Attack, Smash, Defense or Counter. It stays hidden ("...") until late in
## the zone (reveal_at), then shows on the bar and as a live area on the
## floor. Defense and Counter are active for the whole zone and drop at the
## end of the bar.
##
## Between turns (timeline running): you steer one party member in real
## time with WASD; enemies and AI allies move in real time too. Moving is
## free and earns no AP; AP recharges over time. Tab switches which party
## member you steer, so you can position each of them.
##
## Party turns: the fighter whose turn it is is locked in place and the
## command menu opens: Attack (needs an enemy in reach), Wait (no AP; their
## bar restarts a third of the way along), Abilities, Items. If several
## party members are ready at once, their turns come up back to back.
##
## Max AP: starts at max_ap (100). Every successful Parry or Perfect raises
## it for the rest of the fight; missing either one resets it to max_ap.
## AP is also earned faster the higher max AP is (current / starting), so a
## big bank refills quickly, and it's all on the line with each timed press.
## Letting a combo hit pass without pressing costs a little of the extra.
##
## Strikes: touching a live Attack/Smash area, or an enemy reaching the end
## of the bar, starts a strike. A ring shrinks onto each target in real time.
##   E (Parry)  while the ring is gold: no damage, enemy staggered.
##              Too early: full damage, turn pushed back, half your AP lost.
##   Q (Defend) any time: costs AP, you take part of the damage, and that
##              part comes back at your next turn if you aren't hit again.
##   Nothing:   full damage.
##
## Attacks: J opens the command menu (Attack / Abilities / Items). Attack
## opens the combo bar (Legend of Legaia-style): pick moves to fill a bar as
## long as the fighter's combo limit, paid from party AP, then Space plays
## the combo hit by hit and the turn ends. The skill triangle applies to every
## hit: a Counter stance punishes you and stops the combo, Defense blocks
## normal hits (Thrust pierces it, Overhead Smash breaks it), and an
## Attack-type hit interrupts an enemy preparing Smash.

signal strike_finished

## How many timeline units fill the bar. A fighter acts on reaching it.
const TIMELINE_LENGTH := 100.0
## Fighters can't walk further than this from the center of the arena.

enum Reaction { NONE, PARRY, PARRY_MISSED, DEFEND }

## Multiplies everyone's speed. Raise it to make the whole battle faster.
## The rounds to play (data/boss_rush.tres). Each round sets the arena,
## the party lineup and the enemies.
@export var boss_rush: BossRush
## Which round to start on when you press F5 (1 = the first).
@export var start_round: int = 1

@export var time_scale: float = 3.0
## Overall battle pace between turns: slows the timeline, enemy and ally
## movement, and AP recharge together (1.0 = the original pace, 0.7 = 30%
## slower). The fighter you steer, strike rings and combo timing aren't affected.
@export_range(0.1, 2.0) var battle_speed: float = 0.7
## How long an enemy turn stays on screen after it acts, in seconds.
@export var enemy_turn_seconds: float = 0.8
## Where the casting zone starts on the timeline (the bar is 100 long).
@export_range(0.0, 100.0) var cast_zone_start: float = 75.0
## Where an enemy's prepared skill is revealed. Closer to 100 means less
## time to see it coming.
@export_range(0.0, 100.0) var reveal_at: float = 90.0

@export_group("AP")
## The most AP the party can hold at the start of the fight. Parries and
## Perfects raise it; missing one resets it back to this.
@export var max_ap: float = 100.0
## Max AP can't grow beyond this.
@export var max_ap_ceiling: float = 200.0
## Max AP gained per successful Parry / per Perfect combo hit.
@export var parry_max_ap_gain: float = 10.0
@export var perfect_max_ap_gain: float = 5.0
## Extra max AP lost for each combo hit you let pass without pressing J
## (never drops below max_ap).
@export var skipped_hit_max_ap_loss: float = 5.0
## AP the party starts the battle with.
@export var starting_ap: float = 50.0
## AP gained per second while the timeline is running (between turns).
## Moving is free and earns nothing, so this is the main AP source.
@export var ap_regen_per_second: float = 6.0

@export_group("Reactions")
## How long before impact a Parry still counts, in seconds.
@export var parry_window: float = 0.25
## How far back on the timeline a missed Parry pushes the fighter.
@export var parry_miss_push: float = 30.0
## How far back on the timeline a successful Parry knocks the enemy.
@export var stagger_push: float = 25.0
## AP spent to Defend.
@export var defend_cost: float = 10.0
## Share of the damage you still take when defending against an Attack.
@export_range(0.0, 1.0) var defend_share_vs_attack: float = 0.25
## Share of the damage you still take when defending against a Smash
## (Smash breaks the guard, so it's higher).
@export_range(0.0, 1.0) var defend_share_vs_smash: float = 0.6

@export_group("Attacks")
## When a party turn starts, AP is topped up to at least this much
## (enough for three Slashes).
@export var turn_start_ap: float = 30.0
## Seconds of "READY" lead-in before the combo's first move starts.
@export var combo_lead_in: float = 1.0
## Perfect timing (J in a block's timing box): extra damage on that hit.
@export var perfect_damage_bonus: float = 0.5
## Damage you take when you attack into a Counter stance.
@export var counter_stance_damage: int = 25
## How far an interrupted or guard-broken enemy is knocked back on the timeline.
@export var interrupt_push: float = 30.0
## Seconds a Defense/Counter stance stays up after the enemy's turn
## (counted while the timeline runs), so it's more likely to catch someone.
@export var stance_linger: float = 3.0

## Where on the timeline a fighter restarts after choosing Wait (a third
## of the way along, so the next turn comes sooner).
@export_range(0.0, 99.0) var wait_head_start: float = 33.0

@export_group("Movement phase")
## AI allies try to stand at this share of their attack reach from the
## nearest enemy: close to the edge of their range, but inside it.
@export_range(0.3, 1.0) var ally_range_share: float = 0.8
## Extra space allies keep from dangerous enemy areas, in meters.
@export var ally_danger_margin: float = 0.3
## How quickly the camera catches up with the fighter you control.
@export var camera_follow_speed: float = 4.0
## How far the camera sits from the action, in meters.
@export var camera_distance: float = 12.0


## One enemy skill on its way to landing.
class Strike:
	var enemy: Combatant
	var skill: int
	var def: EnemySkill
	var targets: Array[Combatant] = []
	var windup: float = 1.0
	var time_left: float = 1.0
	var reaction: int = 0  # a Reaction value
	## Send the enemy back to the start of the bar when this resolves
	## (true when it strikes during your turn instead of on its own turn).
	var reset_timeline := false
	var rings: Array[MeshInstance3D] = []
	var markers: Array[MeshInstance3D] = []


## The round being played, kept across scene reloads (0-based; -1 = not
## chosen yet, so start_round is used).
static var _round_index := -1

var arena: Arena = null
var encounter: Encounter = null
var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var combatants: Array[Combatant] = []
## Whose turn it is. null means the timeline is running.
var active: Combatant = null
## The party member you're steering. Tab changes it between turns; on a
## party turn it's always the fighter whose turn it is.
var controlled: Combatant = null
## The party's shared AP. Carries over from turn to turn.
var ap: float = 0.0
## The party's AP cap right now (grows with Parries and Perfects).
var current_max_ap: float = 100.0
## The strike currently playing, or null.
var _strike: Strike = null
## True once the battle is decided (victory or defeat).
var _game_over := false
var _result_text := ""

## The command menu / combo bar state (see BattleMenu.Mode).
var _menu_mode: int = BattleMenu.Mode.HIDDEN
var _moves: Array[Dictionary] = Moves.all()
## The enemy the combo will hit, locked when the combo bar opens.
var _combo_target: Combatant = null
## Party AP just before the combo was paid, so the bar keeps showing it.
var _ap_before_combo := 0.0

# Combo playback (runs in _process while the menu is EXECUTING).
enum Timing { NONE, PERFECT, MISS }
var _exec_attacker: Combatant = null
var _exec_slot := 0
var _exec_time := 0.0
var _exec_hits_done := 0
## Timing result for each hit of the current move.
var _exec_timings: Array[int] = []
## Counts down after the last move before the turn ends.
var _exec_outro := -1.0
## Counts down the lead-in before the first move starts.
var _exec_lead_in := 0.0

## True on frames where you moved (so the world moved with you).
var _world_moved := false
var _camera_offset: Vector3
var _flash_message := ""
var _flash_time_left := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var timeline_bar: TimelineBar = $UI/TimelineBar
@onready var turn_label: Label = $UI/TurnLabel
@onready var warning_label: Label = $UI/WarningLabel
@onready var ap_bar: ProgressBar = $UI/APBar
@onready var ap_label: Label = $UI/APBar/APLabel
@onready var controls_label: Label = $UI/ControlsLabel
@onready var party_status: PartyStatus = $UI/PartyStatus
@onready var enemy_status: PartyStatus = $UI/EnemyStatus
@onready var battle_menu: BattleMenu = $UI/BattleMenu


func _ready() -> void:
	_load_round()
	combatants.append_array(party)
	combatants.append_array(enemies)

	timeline_bar.combatants = combatants
	timeline_bar.length = TIMELINE_LENGTH
	timeline_bar.cast_zone_start = cast_zone_start
	party_status.party = party
	enemy_status.party = enemies
	battle_menu.moves = _moves
	battle_menu.commands = PackedStringArray(["Attack", "Wait", "Abilities", "Items"])
	var enabled: Array[bool] = [true, true, false, false]
	battle_menu.command_enabled = enabled
	battle_menu.command_notes = PackedStringArray(["", "", "coming later", "coming later"])
	controlled = party[0]
	controlled.set_highlighted(true)
	ap = starting_ap
	current_max_ap = max_ap
	# The camera keeps its angle from the scene and backs away along its
	# own view direction (+Z is "behind" a camera in Godot).
	_camera_offset = camera.global_basis.z * camera_distance
	camera.global_position = _camera_focus() + _camera_offset
	print("%s! Party: %s  vs  Enemies: %s" % [encounter.title, _names(party), _names(enemies)])
	_flash("%s: %s  vs  %s" % [encounter.title, _names(party), _names(enemies)])


## Builds the current round: its arena, then the party and the enemies
## at their starting spots.
func _load_round() -> void:
	var count := boss_rush.rounds.size()
	if _round_index < 0:
		_round_index = clampi(start_round - 1, 0, count - 1)
	_round_index = posmod(_round_index, count)
	encounter = boss_rush.rounds[_round_index]
	arena = encounter.arena.instantiate() as Arena
	add_child(arena)
	party = _spawn(encounter.party, $Party, false)
	enemies = _spawn(encounter.enemies, $Enemies, true)


func _spawn(scenes: Array[PackedScene], holder: Node3D, enemy_side: bool) -> Array[Combatant]:
	var spots := arena.spawn_points(enemy_side, scenes.size())
	var spawned: Array[Combatant] = []
	var used_names := {}
	for i in scenes.size():
		var fighter := scenes[i].instantiate() as Combatant
		# Two of the same enemy get a letter: Kobold Archer A, Kobold Archer B.
		var copies := 0
		for other in scenes:
			if other == scenes[i]:
				copies += 1
		if copies > 1:
			var n: int = used_names.get(fighter.display_name, 0)
			used_names[fighter.display_name] = n + 1
			fighter.display_name += " " + "ABCD"[n]
		fighter.transform = spots[i]
		holder.add_child(fighter)
		spawned.append(fighter)
	return spawned


## N / P: jump to the next or previous round (restarts the scene).
func _change_round(step: int) -> void:
	_round_index += step
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_world_moved = false
	if not _game_over:
		if _strike != null:
			_update_strike(delta)  # everything else waits while a strike plays
		elif active == null:
			var world_delta := delta * battle_speed
			ap = minf(ap + ap_regen_per_second * _ap_gain_multiplier() * world_delta, current_max_ap)
			_free_roam(delta, world_delta)
			_tick_stances(world_delta)
			_advance_timeline(world_delta)
		elif _party_turn() and _menu_mode == BattleMenu.Mode.EXECUTING:
			_update_combo(delta)
		# On a party turn the fighter is locked in place until a command is chosen.
	# Checked again: the strike above may have just knocked out the last fighter.
	if not _game_over:
		_update_attack_ranges()
	_update_camera(delta)
	_update_ui(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_round") or event.is_action_pressed("previous_round"):
		get_viewport().set_input_as_handled()
		_change_round(1 if event.is_action_pressed("next_round") else -1)
		return
	if _game_over:
		if event.is_action_pressed("restart"):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()  # start the battle over
		return
	if _strike != null:
		if event.is_action_pressed("parry"):
			get_viewport().set_input_as_handled()
			_try_parry()
		elif event.is_action_pressed("defend"):
			get_viewport().set_input_as_handled()
			_try_defend()
		return
	if _party_turn():
		_menu_input(event)
	elif active == null and event.is_action_pressed("swap_character"):
		get_viewport().set_input_as_handled()
		_cycle_control()



# --- Timeline -------------------------------------------------------------

## Moves everyone except the current turn owner along the bar by
## "seconds" worth of timeline time. Used both between turns (real time)
## and during your turn (time paid for by walking).
func _advance_timeline(seconds: float) -> void:
	var during_party_turn := active != null
	var next: Combatant = null
	for c in combatants:
		if c == active or c.is_down:
			continue
		var before := c.timeline_pos
		c.timeline_pos += c.speed * time_scale * seconds

		if c.team == Combatant.Team.ENEMY:
			if before < cast_zone_start and c.timeline_pos >= cast_zone_start:
				_begin_cast(c)
			if c.loaded_skill != Skills.NONE and not c.skill_revealed and c.timeline_pos >= reveal_at:
				_reveal_skill(c)

		if c.timeline_pos < TIMELINE_LENGTH:
			continue
		if not during_party_turn:
			# If several cross the end in the same frame, whoever got
			# furthest goes first; the rest go right after.
			if next == null or c.timeline_pos > next.timeline_pos:
				next = c
		elif c.team == Combatant.Team.ENEMY and _strike == null:
			# You walked long enough for this enemy's turn to arrive.
			_enemy_unleash(c, true)
		else:
			# Waits at the end: a party member until your turn is over,
			# an enemy until the current strike is done.
			c.timeline_pos = TIMELINE_LENGTH

	if next != null:
		_start_turn(next)


func _start_turn(fighter: Combatant) -> void:
	active = fighter
	fighter.timeline_pos = TIMELINE_LENGTH
	_flash_time_left = 0.0  # don't carry old messages into a new turn
	timeline_bar.active = fighter
	print("%s's turn" % fighter.display_name)

	if fighter.team == Combatant.Team.PARTY:
		var recovered := fighter.recover_hp()
		if recovered > 0:
			_flash("%s recovers %d HP" % [fighter.display_name, recovered])
		_set_controlled(fighter)  # locked onto the fighter whose turn it is
		# Every turn starts with enough AP for a few attacks.
		ap = minf(maxf(ap, turn_start_ap), current_max_ap)
		_open_commands()
	else:
		fighter.set_highlighted(true)
		if fighter.loaded_skill == Skills.NONE:
			_begin_cast(fighter)
		_enemy_unleash(fighter, false)
		if _strike != null:
			await strike_finished
		if _game_over:
			return
		# "await" pauses this function until the timer finishes,
		# without freezing the rest of the game.
		await get_tree().create_timer(enemy_turn_seconds).timeout
		_end_turn()


func _end_turn() -> void:
	if active == null:
		return
	if active != controlled:
		active.set_highlighted(false)
	_send_to_start(active)
	active = null
	timeline_bar.active = null
	_menu_mode = BattleMenu.Mode.HIDDEN
	_combo_target = null


## Back to the start of the bar, minus any pending penalty.
func _send_to_start(fighter: Combatant) -> void:
	fighter.timeline_pos = -fighter.timeline_penalty
	fighter.timeline_penalty = 0.0


## Pushes a fighter back on the timeline. If they're about to return to
## the start anyway (it's their turn), the push is saved for that moment.
func _push_back(fighter: Combatant, amount: float) -> void:
	if fighter == active:
		fighter.timeline_penalty += amount
	else:
		fighter.timeline_pos -= amount


# --- Free roam (between turns) ---------------------------------------------

func _party_turn() -> bool:
	return active != null and active.team == Combatant.Team.PARTY


## While the timeline runs: you steer one party member, and enemies and
## AI allies move in real time. Moving is free (no AP either way).
func _free_roam(delta: float, world_delta: float) -> void:
	# get_vector turns four keys into one direction. Forward is -Z in
	# Godot, so "move_forward" maps to the negative Y of this vector.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if controlled != null and not controlled.is_down and input != Vector2.ZERO:
		controlled.step(Vector3(input.x, 0.0, input.y), delta)
		_keep_in_arena(controlled)
	for enemy in enemies:
		_enemy_step(enemy, world_delta)
	for ally in party:
		if ally != controlled and not ally.is_down:
			_ally_step(ally, world_delta)
	_resolve_overlaps()
	_world_moved = true


## Tab (between turns): steer the next standing party member.
func _cycle_control() -> void:
	var standing := _standing(party)
	if standing.size() < 2:
		return
	var index := standing.find(controlled)
	_set_controlled(standing[(index + 1) % standing.size()])


func _set_controlled(fighter: Combatant) -> void:
	if controlled != null:
		controlled.set_highlighted(false)
	controlled = fighter
	controlled.set_highlighted(true)


## Enemy behavior: turn toward the nearest party member and walk forward.
## Enemies only walk when roughly facing their target, so a slow-turning
## enemy can be outmaneuvered. While preparing a skill they stand still and
## can only turn slowly.
func _enemy_step(enemy: Combatant, delta: float) -> void:
	var target := _nearest(enemy, _standing(party))
	if target == null:
		return
	var to_target := target.global_position - enemy.global_position
	to_target.y = 0.0
	if enemy.is_down:
		return
	if enemy.loaded_skill != Skills.NONE or enemy.stance != Skills.NONE:
		# Preparing a skill or holding a stance: stand still, turn slowly.
		enemy.face_toward(to_target, delta, enemy.cast_turn_speed_degrees)
		return
	var stop_distance := enemy.body_radius + target.body_radius + enemy.preferred_gap
	var wants_closer := to_target.length() > stop_distance or not _can_see(enemy, target)
	# Walk around rocks and pits on the way.
	var heading := arena.steer(enemy.global_position, to_target, enemy.body_radius) if wants_closer else to_target
	enemy.face_toward(heading, delta)
	var facing_target := enemy.flat_forward().angle_to(heading) < deg_to_rad(45.0)
	if wants_closer and facing_target:
		enemy.global_position += enemy.flat_forward() * enemy.move_speed * delta
		_keep_in_arena(enemy)


## Ally AI, in priority order:
##   1. Stay out of danger: leave any enemy area that could hit, never walk into one.
##   2. Stand near the edge of its own attack range from the nearest enemy
##      (ally_range_share of its reach): close in if too far, back off if
##      much closer than needed, going around danger either way.
func _ally_step(ally: Combatant, delta: float) -> void:
	var margin := ally.body_radius + ally_danger_margin
	var away := Vector3.ZERO
	for enemy in enemies:
		if _is_danger(enemy) and enemy.attack_range.contains(ally.global_position, margin):
			var from_enemy := ally.global_position - enemy.global_position
			from_enemy.y = 0.0
			away += from_enemy.normalized()
	if away != Vector3.ZERO:
		ally.step(away, delta)
		_keep_in_arena(ally)
		return

	var threat := _nearest(ally, _standing(enemies))
	if threat == null:
		return
	var to_threat := threat.global_position - ally.global_position
	var gap := ally.gap_to(threat)
	var ideal := ally.attack_reach * ally_range_share
	if gap > ideal + 0.15:
		if _safe_step(ally, to_threat, delta):
			return
	elif gap < ideal - 1.0:
		if _safe_step(ally, -to_threat, delta):
			return
	ally.face_toward(to_threat, delta)


## Takes one step toward a direction, or the closest detour (up to 90° off)
## that doesn't enter a dangerous area. Returns false if every option is unsafe.
func _safe_step(fighter: Combatant, direction: Vector3, delta: float) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = arena.steer(fighter.global_position, direction.normalized(), fighter.body_radius)
	var margin := fighter.body_radius + ally_danger_margin
	for degrees in [0.0, 35.0, -35.0, 70.0, -70.0, 90.0, -90.0]:
		var dir := direction.rotated(Vector3.UP, deg_to_rad(degrees))
		var next := fighter.global_position + dir * fighter.move_speed * delta
		if not _in_danger(next, margin):
			fighter.step(dir, delta)
			_keep_in_arena(fighter)
			return true
	return false


## An enemy area worth avoiding: a revealed Attack/Smash, or anything still
## being prepared (allies can't know a hidden skill is harmless).
func _is_danger(enemy: Combatant) -> bool:
	if enemy.attack_range == null or enemy.is_down or enemy.loaded_skill == Skills.NONE:
		return false
	return not enemy.skill_revealed or Skills.is_offensive(enemy.loaded_skill)


func _in_danger(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_danger(enemy) and enemy.attack_range.contains(point, extra_radius):
			return true
	return false


## Pushes apart any two fighters standing inside each other.
## Enemies are heavy: party members get pushed, enemies don't.
func _resolve_overlaps() -> void:
	for i in combatants.size():
		for j in range(i + 1, combatants.size()):
			var a := combatants[i]
			var b := combatants[j]
			var offset := b.global_position - a.global_position
			offset.y = 0.0
			var min_distance := a.body_radius + b.body_radius
			var distance := offset.length()
			if distance >= min_distance:
				continue
			var push_dir := offset.normalized() if distance > 0.001 else Vector3.RIGHT
			var overlap := min_distance - distance
			if a.team == Combatant.Team.ENEMY and b.team == Combatant.Team.PARTY:
				b.global_position += push_dir * overlap
			elif b.team == Combatant.Team.ENEMY and a.team == Combatant.Team.PARTY:
				a.global_position -= push_dir * overlap
			else:
				a.global_position -= push_dir * overlap / 2.0
				b.global_position += push_dir * overlap / 2.0
	for c in combatants:
		_keep_in_arena(c)


## Keeps a fighter inside the arena's edges and out of rocks and pits.
func _keep_in_arena(fighter: Combatant) -> void:
	arena.keep_inside(fighter, fighter.body_radius)


## True if nothing (a rock) stands between two fighters.
func _can_see(a: Combatant, b: Combatant) -> bool:
	return arena.has_line_of_sight(a.global_position, b.global_position)


# --- Enemy skills ---------------------------------------------------------

## An enemy entered the casting zone: it starts preparing a skill, but
## you only see that it's preparing something, not what.
## Defense and Counter take effect right away (still hidden).
func _begin_cast(enemy: Combatant) -> void:
	enemy.loaded_def = enemy.pick_skill()
	enemy.loaded_skill = enemy.loaded_def.kind
	enemy.skill_revealed = false
	enemy.stance_time_left = 0.0
	enemy.stance = Skills.NONE if Skills.is_offensive(enemy.loaded_skill) else enemy.loaded_skill
	enemy.show_skill_text("...", Color(0.75, 0.75, 0.8))
	print("%s is preparing %s (hidden)" % [enemy.display_name, enemy.loaded_def.skill_name])


## Late in the casting zone the prepared skill becomes visible: on the
## bar, above the enemy, and as a live area on the floor.
func _reveal_skill(enemy: Combatant) -> void:
	enemy.skill_revealed = true
	var def := enemy.loaded_def
	var text := def.skill_name.to_upper()
	if enemy.attack_range:
		enemy.attack_range.show_skill(def)
	if not def.is_offensive():
		text += " STANCE"
	enemy.show_skill_text(text, def.color())
	print("%s reveals %s" % [enemy.display_name, def.skill_name])


## The enemy reached the end of the bar (or was triggered). Attack and
## Smash start a strike on whoever is in the area; a Defense or Counter
## stance ends. reset_timeline sends it back to the start of the bar
## afterwards (used when it acts during your turn; on its own turn,
## _end_turn does that).
func _enemy_unleash(enemy: Combatant, reset_timeline: bool) -> void:
	if not enemy.skill_revealed:
		_reveal_skill(enemy)
	var skill_name := enemy.loaded_def.skill_name
	if enemy.loaded_def.is_offensive():
		var targets: Array[Combatant] = []
		for member in _standing(party):
			if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius) \
					and _can_see(enemy, member):
				targets.append(member)
		if targets.is_empty():
			_flash("%s's %s misses!" % [enemy.display_name, skill_name])
			_finish_enemy_skill(enemy, reset_timeline)
		else:
			_begin_strike(enemy, targets, reset_timeline)
		return

	# Defense/Counter: the stance lingers a few seconds after the turn.
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance_time_left = stance_linger
	_flash("%s holds its %s stance!" % [enemy.display_name, skill_name])
	if reset_timeline:
		_send_to_start(enemy)


## Clean-up after an Attack or Smash, hit or miss.
func _finish_enemy_skill(enemy: Combatant, reset_timeline: bool) -> void:
	if enemy.attack_range:
		enemy.attack_range.go_dormant()
	enemy.show_skill_text("")
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance = Skills.NONE
	enemy.stance_time_left = 0.0
	enemy.loaded_def = null
	if reset_timeline:
		_send_to_start(enemy)


## Counts down lingering Defense/Counter stances; drops them at zero.
func _tick_stances(delta: float) -> void:
	for enemy in enemies:
		if enemy.stance == Skills.NONE or enemy.loaded_skill != Skills.NONE or enemy.stance_time_left <= 0.0:
			continue
		enemy.stance_time_left -= delta
		var skill_name: String = enemy.loaded_def.skill_name if enemy.loaded_def else Skills.info(enemy.stance)["name"]
		if enemy.stance_time_left <= 0.0:
			_flash("%s's %s stance ends" % [enemy.display_name, skill_name])
			_finish_enemy_skill(enemy, false)
		else:
			enemy.show_skill_text("%s STANCE %.0fs" % [skill_name.to_upper(), ceilf(enemy.stance_time_left)],
					Skills.info(enemy.stance)["color"])


## Brightens live areas that have someone in them, and during your turn
## makes the enemy strike if you moved into its Attack or Smash area.
func _update_attack_ranges() -> void:
	var warnings: PackedStringArray = []
	for enemy in enemies:
		if enemy.attack_range == null:
			continue
		var targets: PackedStringArray = []
		if _is_live_threat(enemy):
			for member in _standing(party):
				if enemy.attack_range.contains(member.global_position, member.body_radius) and _can_see(enemy, member):
					targets.append(member.display_name)
		enemy.attack_range.set_alert(not targets.is_empty())
		if targets.is_empty():
			continue
		if _world_moved and active == null and _strike == null:
			_enemy_unleash(enemy, true)  # someone touched it: it strikes now
		else:
			var skill_name := enemy.loaded_def.skill_name
			warnings.append("%s's %s will hit: %s" % [enemy.display_name, skill_name, ", ".join(targets)])
	warning_label.text = "\n".join(warnings)


## True if a point is inside any enemy's live Attack/Smash area.
func _in_any_attack_range(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_live_threat(enemy) and enemy.attack_range.contains(point, extra_radius):
			return true
	return false


## An enemy whose revealed Attack or Smash area can hurt you right now.
func _is_live_threat(enemy: Combatant) -> bool:
	return enemy.attack_range != null and enemy.skill_revealed and Skills.is_offensive(enemy.loaded_skill)


# --- Strikes, Parry and Defend --------------------------------------------

func _begin_strike(enemy: Combatant, targets: Array[Combatant], reset_timeline: bool) -> void:
	var s := Strike.new()
	s.enemy = enemy
	s.skill = enemy.loaded_skill
	s.def = enemy.loaded_def
	s.targets = targets
	s.windup = s.def.windup
	s.time_left = s.windup
	s.reset_timeline = reset_timeline
	for target in targets:
		# A fixed white marker shows where the ring will land; the ring
		# shrinks onto it and turns gold when it's time to parry.
		var ring_radius := target.body_radius + 0.3
		var marker := _make_ring(ring_radius, 0.06, Color(1, 1, 1, 0.7))
		var ring := _make_ring(ring_radius, 0.1, Color.WHITE)
		target.add_child(marker)
		target.add_child(ring)
		s.markers.append(marker)
		s.rings.append(ring)
	_strike = s
	print("%s's %s strikes at %s" % [enemy.display_name, s.def.skill_name, _names(targets)])


func _update_strike(delta: float) -> void:
	_strike.time_left -= delta
	var progress := maxf(_strike.time_left, 0.0) / _strike.windup  # 1 at start, 0 at impact
	var color := Color.WHITE
	match _strike.reaction:
		Reaction.PARRY_MISSED:
			color = Color(1.0, 0.25, 0.2)
		Reaction.DEFEND:
			color = Color(0.35, 0.65, 1.0)
		Reaction.PARRY:
			color = Color(1.0, 0.85, 0.2)
		_:
			if _strike.time_left <= parry_window:
				color = Color(1.0, 0.85, 0.2)
	for ring in _strike.rings:
		var scale_factor := 1.0 + 2.0 * progress
		ring.scale = Vector3(scale_factor, 1.0, scale_factor)
		(ring.material_override as StandardMaterial3D).albedo_color = color
	if _strike.time_left <= 0.0:
		_resolve_strike()


## E: a Parry. Only one try per strike.
func _try_parry() -> void:
	if _strike.reaction != Reaction.NONE:
		return
	if _strike.def.cannot_be_parried:
		_flash("%s can't be parried!" % _strike.def.skill_name)
		return
	if _strike.time_left <= parry_window:
		_strike.reaction = Reaction.PARRY
	else:
		_strike.reaction = Reaction.PARRY_MISSED


## Q: Defend. Costs AP, can't be combined with a parry attempt.
func _try_defend() -> void:
	if _strike.reaction != Reaction.NONE:
		return
	if _strike.def.cannot_be_blocked:
		_flash("%s can't be blocked!" % _strike.def.skill_name)
		return
	if ap < defend_cost:
		_flash("Not enough AP to defend (%d needed)" % defend_cost)
		return
	ap -= defend_cost
	_strike.reaction = Reaction.DEFEND


func _resolve_strike() -> void:
	var s := _strike
	_strike = null
	for node in s.rings + s.markers:
		node.queue_free()

	var skill_name := s.def.skill_name
	var damage := s.def.damage
	var who := _names(s.targets)
	var lines: PackedStringArray = []

	match s.reaction:
		Reaction.PARRY:
			s.enemy.timeline_penalty += stagger_push
			lines.append("%s parried %s's %s! %s is staggered" % [who, s.enemy.display_name, skill_name, s.enemy.display_name])
			_popup(s.targets[0], "PARRY!", Color(1.0, 0.85, 0.2))
			lines.append(_grow_max_ap(parry_max_ap_gain, s.targets[0]))
		Reaction.DEFEND:
			var share := defend_share_vs_smash if s.skill == Skills.Kind.SMASH else defend_share_vs_attack
			var taken := ceili(damage * share)
			for target in s.targets:
				target.take_damage(taken, true)
				_popup(target, str(taken), Color(0.6, 0.8, 1.0))
			var guard_note := " Guard broken!" if s.skill == Skills.Kind.SMASH else ""
			lines.append("%s defended:%s -%d HP (recoverable)" % [who, guard_note, taken])
		Reaction.PARRY_MISSED:
			for target in s.targets:
				target.take_damage(damage, false)
				_popup(target, str(damage), Color(1.0, 0.4, 0.3))
				_push_back(target, parry_miss_push)
			ap *= 0.5
			lines.append("Parry too early! %s takes %d, turn delayed, AP halved" % [who, damage])
			var reset_note := _reset_max_ap()
			if reset_note != "":
				lines.append(reset_note)
		_:
			for target in s.targets:
				target.take_damage(damage, false)
				_popup(target, str(damage), Color(1.0, 0.4, 0.3))
			lines.append("%s's %s hits %s for %d!" % [s.enemy.display_name, skill_name, who, damage])

	for target in s.targets:
		if target.is_down:
			lines.append("%s is down!" % target.display_name)

	_finish_enemy_skill(s.enemy, s.reset_timeline)
	_flash("\n".join(lines))
	print(" / ".join(lines))
	_check_party()
	_check_enemies()
	strike_finished.emit()


## Handles knocked-out fighters: hands control back if needed, and ends
## the battle if nobody is left standing.
func _check_party() -> void:
	if _standing(party).is_empty():
		_game_over = true  # _update_ui shows the game-over text from now on
		_result_text = "The party has fallen..."
		print("Game over")
		return
	if active != null and active.team == Combatant.Team.PARTY and active.is_down:
		_end_turn()
	if controlled != null and controlled.is_down:
		_set_controlled(_standing(party)[0])


## Ends the battle in victory once every enemy is down.
func _check_enemies() -> void:
	if _game_over:
		return
	for enemy in enemies:
		if enemy.is_down and enemy.attack_range and enemy.attack_range.visible:
			_finish_enemy_skill(enemy, false)
			enemy.attack_range.visible = false
	if _standing(enemies).is_empty():
		_game_over = true
		_result_text = "Victory!"
		print("Victory")


# --- Party attacks --------------------------------------------------------

## J: open the command menu. Attack needs an enemy within reach.
func _open_commands() -> void:
	_menu_mode = BattleMenu.Mode.COMMANDS
	var can_attack := _attack_target() != null
	battle_menu.command_index = 0 if can_attack else 1  # start on Wait if out of reach
	battle_menu.command_enabled[0] = can_attack
	battle_menu.command_notes[0] = "" if can_attack else "no enemy in reach"


## Keys while a menu is open. W/S move the cursor, J confirms, K goes back,
## and in the combo bar Space starts the combo.
func _menu_input(event: InputEvent) -> void:
	if _menu_mode == BattleMenu.Mode.EXECUTING:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			_judge_timing()
		return
	var up := event.is_action_pressed("move_forward")
	var down := event.is_action_pressed("move_back")
	var confirm := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	var begin := event.is_action_pressed("end_turn")
	if not (up or down or confirm or cancel or begin):
		return
	get_viewport().set_input_as_handled()

	if _menu_mode == BattleMenu.Mode.COMMANDS:
		var count := battle_menu.commands.size()
		if up:
			battle_menu.command_index = (battle_menu.command_index - 1 + count) % count
		elif down:
			battle_menu.command_index = (battle_menu.command_index + 1) % count
		elif confirm:
			var index := battle_menu.command_index
			if not battle_menu.command_enabled[index]:
				_flash("%s: %s" % [battle_menu.commands[index], battle_menu.command_notes[index]])
			elif index == 0:
				_open_combo_bar()
			elif index == 1:
				_wait_command()
		return

	# Combo bar
	if up:
		battle_menu.move_index = (battle_menu.move_index - 1 + _moves.size()) % _moves.size()
	elif down:
		battle_menu.move_index = (battle_menu.move_index + 1) % _moves.size()
	elif confirm:
		_add_to_combo(battle_menu.move_index)
	elif cancel:
		if battle_menu.combo.is_empty():
			_menu_mode = BattleMenu.Mode.COMMANDS
		else:
			battle_menu.combo.pop_back()
	elif begin:
		if battle_menu.combo.is_empty():
			_flash("Add at least one move first (J)")
		else:
			_execute_combo()


## Wait: end the turn without spending AP. The fighter's bar restarts a
## third of the way along, so their next turn comes sooner.
func _wait_command() -> void:
	var fighter := active
	_end_turn()
	fighter.timeline_pos += wait_head_start
	_flash("%s waits" % fighter.display_name)


func _open_combo_bar() -> void:
	_combo_target = _attack_target()
	_menu_mode = BattleMenu.Mode.COMBO
	battle_menu.combo.clear()
	battle_menu.move_index = 0
	battle_menu.executing_slot = -1
	battle_menu.slot_results.clear()


## Adds a move to the bar if it fits both the fighter's combo limit and
## the party's AP.
func _add_to_combo(index: int) -> void:
	var cost := float(_moves[index]["cost"])
	var used := battle_menu.combo_cost()
	if used + cost > controlled.combo_limit:
		_flash("%s's combo bar is full" % controlled.display_name)
	elif used + cost > ap:
		_flash("Not enough AP (%d left)" % floori(ap - used))
	else:
		battle_menu.combo.append(index)


## Starts playing the combo. _update_combo then runs it frame by frame.
func _execute_combo() -> void:
	_menu_mode = BattleMenu.Mode.EXECUTING
	_exec_attacker = controlled
	_ap_before_combo = ap
	ap -= battle_menu.combo_cost()
	_exec_attacker.face_toward(_combo_target.global_position - _exec_attacker.global_position, 1.0, 100000.0)
	battle_menu.slot_results.clear()
	for i in battle_menu.combo.size():
		var hit_count := (_moves[battle_menu.combo[i]]["hits"] as Array).size()
		var per_hit: Array[int] = []
		per_hit.resize(hit_count)
		per_hit.fill(Timing.NONE)
		battle_menu.slot_results.append(per_hit)
	_exec_outro = -1.0
	_start_combo_slot(0)
	# A short lead-in so the player can get ready for the timing.
	_exec_lead_in = combo_lead_in
	battle_menu.lead_in_progress = 0.0


func _start_combo_slot(slot: int) -> void:
	_exec_slot = slot
	_exec_time = 0.0
	_exec_hits_done = 0
	_exec_timings.clear()
	var hit_count := (_moves[battle_menu.combo[slot]]["hits"] as Array).size()
	_exec_timings.resize(hit_count)
	_exec_timings.fill(Timing.NONE)
	battle_menu.executing_slot = slot
	battle_menu.slot_progress = 0.0


## Moves the playhead through the current block at that move's own speed,
## landing its hits along the way (the last one at the end of the block).
func _update_combo(delta: float) -> void:
	if _exec_lead_in > 0.0:
		_exec_lead_in -= delta
		battle_menu.lead_in_progress = clampf(1.0 - _exec_lead_in / combo_lead_in, 0.0, 1.0)
		if _exec_lead_in <= 0.0:
			battle_menu.lead_in_progress = -1.0
		return
	if _exec_outro >= 0.0:
		_exec_outro -= delta
		if _exec_outro < 0.0:
			_menu_mode = BattleMenu.Mode.HIDDEN
			if active != null and not _game_over:
				_end_turn()
		return

	var move := _moves[battle_menu.combo[_exec_slot]]
	var duration: float = move["duration"]
	var hits: Array = move["hits"]
	_exec_time += delta
	battle_menu.slot_progress = clampf(_exec_time / duration, 0.0, 1.0)

	while _exec_hits_done < hits.size() and _exec_time >= duration * (_exec_hits_done + 1) / hits.size():
		var multiplier: float = hits[_exec_hits_done]
		var perfect := _exec_timings[_exec_hits_done] == Timing.PERFECT
		if _exec_timings[_exec_hits_done] == Timing.NONE:
			_shrink_max_ap(skipped_hit_max_ap_loss, _exec_attacker)  # opted out of the timing
		if perfect:
			multiplier *= 1.0 + perfect_damage_bonus
		_exec_attacker.play_lunge()
		var keep_going := _resolve_combo_hit(_exec_attacker, _combo_target, move, multiplier)
		_exec_hits_done += 1
		if perfect:
			_popup(_exec_attacker, "PERFECT!", Color(1.0, 0.85, 0.2))
			_flash(_grow_max_ap(perfect_max_ap_gain, _exec_attacker))
		if not keep_going or _game_over:
			_stop_combo()
			return

	if _exec_hits_done >= hits.size():
		if _exec_slot + 1 < battle_menu.combo.size():
			_start_combo_slot(_exec_slot + 1)
		else:
			battle_menu.executing_slot = battle_menu.combo.size()  # playhead to the end
			_exec_outro = 0.4


## J during the combo: inside the next hit's timing box = Perfect;
## anywhere else = miss, and the chain ends right there. One try per hit.
func _judge_timing() -> void:
	if _exec_outro >= 0.0 or _exec_lead_in > 0.0:  # presses during the lead-in are ignored
		return
	var move := _moves[battle_menu.combo[_exec_slot]]
	var duration: float = move["duration"]
	var window: float = move["window"]
	# The press is judged against the next hit still to land.
	var hit := _exec_hits_done
	if hit >= _exec_timings.size() or _exec_timings[hit] != Timing.NONE:
		return  # one try per hit
	var hit_time := duration * float(hit + 1) / _exec_timings.size()
	if _exec_time >= hit_time - window:
		_exec_timings[hit] = Timing.PERFECT
		battle_menu.slot_results[_exec_slot][hit] = Timing.PERFECT
	else:
		_exec_timings[hit] = Timing.MISS
		battle_menu.slot_results[_exec_slot][hit] = Timing.MISS
		_popup(_exec_attacker, "MISS", Color(1.0, 0.35, 0.3))
		_flash("Missed the timing! The chain ends. " + _reset_max_ap())
		_stop_combo()


## Raises the party's max AP for the rest of the fight. Returns a message.
func _grow_max_ap(amount: float, at: Combatant) -> String:
	var before := current_max_ap
	current_max_ap = minf(current_max_ap + amount, max_ap_ceiling)
	var gained := current_max_ap - before
	if gained <= 0.0:
		return "Max AP is already at its limit (%d)" % int(max_ap_ceiling)
	_popup(at, "+%d MAX AP" % roundi(gained), Color(0.45, 0.85, 1.0))
	return "Max AP +%d (now %d)" % [roundi(gained), int(current_max_ap)]


## AP gain scales with how far max AP has grown: 1.0 at the starting cap,
## 1.5 at 150, 2.0 at 200.
func _ap_gain_multiplier() -> float:
	return current_max_ap / max_ap


## A skipped timed hit: lose a little of the extra max AP (not below max_ap).
func _shrink_max_ap(amount: float, at: Combatant) -> void:
	if current_max_ap <= max_ap:
		return
	var before := current_max_ap
	current_max_ap = maxf(current_max_ap - amount, max_ap)
	ap = minf(ap, current_max_ap)
	_popup(at, "-%d MAX AP" % roundi(before - current_max_ap), Color(0.6, 0.6, 0.7))


## A missed Parry or Perfect: max AP drops back to its starting value,
## and any AP above that is lost. Returns a message.
func _reset_max_ap() -> String:
	if current_max_ap <= max_ap:
		return ""
	current_max_ap = max_ap
	ap = minf(ap, current_max_ap)
	return "Max AP reset to %d" % int(max_ap)


## Ends the combo early: the playhead freezes where it is.
func _stop_combo() -> void:
	_exec_outro = 0.7


## Applies the skill triangle to one hit of a combo. Returns false if the
## combo should stop (countered, or the target is down).
func _resolve_combo_hit(attacker: Combatant, target: Combatant, move: Dictionary, multiplier: float) -> bool:
	if attacker.is_down or target.is_down:
		return false
	var move_name: String = move["name"]

	if target.stance == Skills.Kind.COUNTER:
		# Counter beats every attack: the enemy punishes you, combo over.
		attacker.take_damage(counter_stance_damage, false)
		_popup(target, "COUNTER!", Skills.info(Skills.Kind.COUNTER)["color"])
		_popup(attacker, str(counter_stance_damage), Color(1.0, 0.4, 0.3))
		_flash("%s's Counter stance punishes the %s! Combo stopped" % [target.display_name, move_name])
		_check_party()
		return false

	var note := ""
	if target.stance == Skills.Kind.DEFENSE:
		match move["effect"]:
			Moves.Effect.BREAK:
				note = "Guard broken!"
				_cancel_enemy_skill(target)
			Moves.Effect.PIERCE:
				note = "Pierce!"
			_:
				_popup(target, "BLOCKED", Skills.info(Skills.Kind.DEFENSE)["color"])
				_flash("%s's Defense blocks the %s. Thrust pierces it, Smash breaks it!" % [target.display_name, move_name])
				return true
	elif target.loaded_skill == Skills.Kind.SMASH and move["kind"] == Skills.Kind.ATTACK:
		note = "Smash interrupted!"
		_cancel_enemy_skill(target)

	var damage := ceili(attacker.attack_power * multiplier)
	target.take_damage(damage, false)
	var is_smash: bool = move["kind"] == Skills.Kind.SMASH
	_popup(target, str(damage), Color(1.0, 0.7, 0.3) if is_smash else Color.WHITE)
	if note != "":
		_popup(target, note.to_upper(), Color(1.0, 0.85, 0.2))
		_flash(note)
	if target.is_down:
		_flash("%s is defeated!" % target.display_name)
		_check_enemies()
		return false
	return true


## The enemy loses its prepared skill (and stance) and is knocked back
## out of the casting zone, so it has to prepare again.
func _cancel_enemy_skill(enemy: Combatant) -> void:
	_finish_enemy_skill(enemy, false)
	enemy.timeline_pos = minf(enemy.timeline_pos - interrupt_push, cast_zone_start - 1.0)


## Pushes an enemy back on the timeline; if that takes it out of the
## casting zone, it loses the skill it was preparing.
func _knock_back_enemy(enemy: Combatant, amount: float) -> void:
	enemy.timeline_pos -= amount
	if enemy.loaded_skill != Skills.NONE and enemy.timeline_pos < cast_zone_start:
		_finish_enemy_skill(enemy, false)


## The nearest standing enemy within the controlled fighter's reach.
func _attack_target() -> Combatant:
	var best: Combatant = null
	var best_gap := INF
	for enemy in _standing(enemies):
		var gap := controlled.gap_to(enemy)
		if gap <= controlled.attack_reach and gap < best_gap and _can_see(controlled, enemy):
			best = enemy
			best_gap = gap
	return best


## A floating number or word that rises and fades above a fighter.
func _popup(at: Node3D, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 80
	label.outline_size = 20
	label.modulate = color
	add_child(label)
	label.global_position = at.global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _make_ring(radius: float, width: float, color: Color) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var segments := 48
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

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color

	var node := MeshInstance3D.new()
	node.mesh = ring_mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = 0.06
	return node


# --- Camera and UI --------------------------------------------------------

func _update_camera(delta: float) -> void:
	# This "1 - exp(...)" form makes the smoothing feel the same at any frame rate.
	var weight := 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(_camera_focus() + _camera_offset, weight)


## The point the camera looks at: a bit of the way from the fighter you
## control (or the party, between turns) toward the nearest enemy, so both
## stay on screen.
func _camera_focus() -> Vector3:
	var anchor := controlled.global_position if controlled != null else _party_center()
	var threat := _nearest_to_point(anchor, enemies)
	return anchor.lerp(threat.global_position, 0.35) if threat != null else anchor


func _update_ui(delta: float) -> void:
	party_status.controlled = controlled
	for member in party:
		var in_reach := false
		for enemy in _standing(enemies):
			if member.gap_to(enemy) <= member.attack_reach and _can_see(member, enemy):
				in_reach = true
				break
		member.update_reach_ring(member == controlled, in_reach)
	battle_menu.mode = _menu_mode if _party_turn() and not _game_over else BattleMenu.Mode.HIDDEN
	if controlled != null:
		battle_menu.fighter_name = controlled.display_name
		battle_menu.combo_limit = controlled.combo_limit
		battle_menu.ap_available = _ap_before_combo if _menu_mode == BattleMenu.Mode.EXECUTING else ap
	if _game_over:
		# Placeholder end screen (a proper one is milestone 8).
		# The last message stays on screen so you can see what happened.
		turn_label.text = _result_text
		warning_label.text = _flash_message
		controls_label.visible = true
		var won := _result_text == "Victory!"
		controls_label.text = ("N: next round     R: play again" if won else "R: retry     N / P: next / previous round")
		return
	var party_turn := _party_turn()
	controls_label.visible = (active == null or party_turn) and _strike == null and _menu_mode != BattleMenu.Mode.EXECUTING
	controls_label.text = _controls_hint()

	if _strike != null:
		var skill_name := _strike.def.skill_name
		turn_label.text = "%s: %s!" % [_strike.enemy.display_name, skill_name.to_upper()]
		warning_label.text = _strike_prompt()
	elif active == null:
		turn_label.text = "Positioning: %s" % controlled.display_name if controlled != null else ""
	elif _menu_mode == BattleMenu.Mode.EXECUTING:
		turn_label.text = "%s attacks!" % controlled.display_name
		if _flash_time_left <= 0.0:
			warning_label.text = "J when the playhead hits the box: Perfect!  (a wrong press ends the chain)"
	elif party_turn:
		turn_label.text = "%s's turn" % active.display_name
	else:
		turn_label.text = "%s acts!" % active.display_name

	ap_bar.max_value = current_max_ap
	ap_bar.value = ap
	ap_label.text = "Party AP  %d / %d" % [floori(ap), int(current_max_ap)]

	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _strike == null:
			warning_label.text = _flash_message + ("\n" + warning_label.text if warning_label.text else "")


func _strike_prompt() -> String:
	match _strike.reaction:
		Reaction.PARRY:
			return "Parry!"
		Reaction.PARRY_MISSED:
			return "Too early!"
		Reaction.DEFEND:
			return "Defending..."
	var parry_hint := "E: can't Parry this" if _strike.def.cannot_be_parried else "E: Parry when the ring turns gold"
	var defend_hint := "Q: can't Defend this" if _strike.def.cannot_be_blocked else "Q: Defend (%d AP)" % defend_cost
	var prompt := parry_hint + "     " + defend_hint
	if _flash_time_left > 0.0:
		prompt = _flash_message + "\n" + prompt
	return prompt


func _controls_hint() -> String:
	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
			return "W / S: choose     J: select"
		BattleMenu.Mode.COMBO:
			return "W / S: choose move     J: add to bar     K: remove last     Space: begin combo"
	var standing := _standing(party)
	var next_name := ""
	if standing.size() > 1 and controlled != null:
		next_name = standing[(standing.find(controlled) + 1) % standing.size()].display_name
	var tab_part := "     Tab: switch to %s" % next_name if next_name != "" else ""
	return "WASD: move %s (free)%s     N / P: change round" % [controlled.display_name if controlled else "", tab_part]


## Shows a short message under the turn label for a moment.
func _flash(message: String) -> void:
	_flash_message = message
	_flash_time_left = 2.5


# --- Helpers --------------------------------------------------------------

## The fighters in a list who aren't knocked out.
func _standing(list: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in list:
		if not c.is_down:
			result.append(c)
	return result


func _nearest(from: Combatant, candidates: Array[Combatant]) -> Combatant:
	return _nearest_to_point(from.global_position, candidates)


func _nearest_to_point(point: Vector3, candidates: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_distance := INF
	for c in candidates:
		var d := point.distance_to(c.global_position)
		if d < best_distance:
			best = c
			best_distance = d
	return best


func _party_center() -> Vector3:
	var sum := Vector3.ZERO
	for member in party:
		sum += member.global_position
	return sum / maxf(party.size(), 1)


func _names(list: Array[Combatant]) -> String:
	return ", ".join(list.map(func(c: Combatant) -> String: return c.display_name))
