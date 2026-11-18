class_name BattleArena
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
##   E (Parry)  while the ring is gold: no damage, enemy knocked back.
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

## How fast icons move along the timeline (times each fighter's speed).
## Lower = more time between turns. Walking, AP recharge and combos aren't affected.
@export var time_scale: float = 1.8
## Overall battle pace between turns: slows the timeline, enemy and ally
## movement, and AP recharge together (1.0 = the original pace, 0.7 = 30%
## slower). The fighter you steer, strike rings and combo timing aren't affected.
@export_range(0.1, 2.0) var battle_speed: float = 0.7
## How long an enemy turn stays on screen after it acts, in seconds.
@export var enemy_turn_seconds: float = 0.8
## Where the casting zone starts on the timeline (the bar is 100 long).
@export_range(0.0, 100.0) var cast_zone_start: float = 73.0
## Where an enemy's prepared skill is revealed. Closer to 100 means less
## time to see it coming.
@export_range(0.0, 100.0) var reveal_at: float = 88.0
## Paired enemies (team_tactics): when one readies a Power Shot (a Smash)
## and its partner a normal attack, the normal attack lands this many seconds
## after the Power Shot, so there's time to hide behind a rock and then run
## back in. Counted in real seconds of free movement.
@export var bait_gap_seconds: float = 2.5

@export_group("AP")
## The most AP the party can hold at the start of the fight. Parries and
## Perfects raise it; missing one resets it back to this.
@export var max_ap: float = 100.0
## Max AP grows up to this much per party member, plus one more share
## (200 solo, 300 for two, 400 for three, 500 for four)...
@export var max_ap_ceiling_per_member: float = 100.0
## ...but never past this, so five or six members also stop at 500.
@export var max_ap_limit: float = 500.0
## Extra room above max_ap_limit (for future skills or items that raise it).
var max_ap_limit_bonus := 0.0
## Unavoidable strikes skip the Parry/Defend ring: they land after this
## short beat.
@export var unavoidable_impact_seconds: float = 0.45
## Bonus max AP lost when an enemy strike lands that could have been
## avoided (dodgeable skills, or a mechanic answered wrong); once per strike.
## 0 = no AP penalty (off for now: the hit's damage is penalty enough; it's
## still counted in the stats).
@export var avoidable_hit_max_ap_loss: float = 0.0
## Max AP gained per successful Parry / per Perfect combo hit.
@export var parry_max_ap_gain: float = 10.0
@export var perfect_max_ap_gain: float = 5.0
## Extra max AP lost for each combo hit you let pass without pressing J
## (never drops below max_ap).
@export var skipped_hit_max_ap_loss: float = 0.0  # off for now: a skip is just a normal hit
## AP the party starts the battle with.
@export var starting_ap: float = 50.0
## Items: every fight starts with this pouch (refilled each round). The
## tutorial starts empty until its Items lesson.
@export var pouch_potions: int = 3
@export var pouch_ethers: int = 2
@export var pouch_revives: int = 1
## AI allies drink a Potion under this share of their HP when no Cleric can
## heal them.
@export var ai_potion_below: float = 0.35
## AP gained per second while the timeline is running (between turns).
## Moving is free and earns nothing, so this is the main AP source.
@export var ap_regen_per_second: float = 6.0
## Recharge speeds up with max AP (x1.5 at 150...), but never beyond this.
@export var ap_regen_max_multiplier: float = 2.0

@export_group("Reactions")
## How long before impact a Parry still counts, in seconds (the ring is
## gold for this long).
@export var parry_window: float = 0.15
## The same for an edge save (Off-Balance at a ledge), kept at the old 0.25.
@export var edge_save_window: float = 0.25
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
## AP added when a party member's turn starts, on top of what's there.
@export var turn_start_ap: float = 30.0
## Seconds of "READY" lead-in before the combo's first move starts.
@export var combo_lead_in: float = 1.0
## Perfect timing (J in a block's timing box): extra damage on that hit.
@export var perfect_damage_bonus: float = 0.5
## Looks: on a Perfect, everything freezes this long (real seconds).
@export var hitstop_seconds: float = 0.05
var _anticipated := ""
## Melee attackers whose target was pushed out of reach mid-combo step after
## it so the rest of the hits connect: fighter -> [target, move, seconds].
var _chasers := {}
## Looks: a glowing orb gathering at the caster while a tap move's taps
## come in, growing with each up to the Perfect count (then holding).
var _charge_orb: MeshInstance3D = null
## How fast they close the gap (m/s).
@export var chase_speed: float = 9.0
## Damage you take when you attack into a Counter stance.
@export var counter_stance_damage: int = 33
## Counter-parry: hitting a Counter stance mid-combo freezes the playhead and
## its counter-swing comes at you this many seconds later. Press the hit key
## within counter_parry_window of the swing to parry it: the stance breaks
## and the rest of the combo deals counter_broken_bonus more. Miss it (or
## press early) and you're countered: damage, combo over.
@export var counter_parry_lead: float = 0.6
@export var counter_parry_window: float = 0.12
@export var counter_broken_bonus: float = 0.25
## After a parried counter the playhead waits this long before moving on,
## so you can find the rhythm again (presses meanwhile are ignored).
@export var counter_recover_seconds: float = 0.6
## A press this soon after a timed hit lands counts as that hit's late press
## ("LATE": no Perfect) instead of a too-early press for the next box (a miss
## that ends the chain). Mattered for close hits like Triple Rush's.
@export var late_press_grace: float = 0.2
## Bosses (Combatant.boss) hit this much harder: every hit their skills,
## rocks and blasts deal to the party (summoned sprites don't count).
@export var boss_damage_mult: float = 1.15
## How far an interrupted or guard-broken enemy is knocked back on the timeline.
@export var interrupt_push: float = 30.0
## Seconds a Defense/Counter stance stays up after the enemy's turn
## (counted while the timeline runs), so it's more likely to catch someone.
@export var stance_linger: float = 3.0
## While preparing an attack, an enemy tracks the party member it locked onto
## at full turning speed, and only slows to its casting turn speed this many
## seconds before it strikes: that's the window to get out of the way.
@export var cast_slow_seconds: float = 1.0
## Melee tracking: short cones and lines (regular Attacks and Smashes, up to
## melee_track_radius long; cones under 180 degrees) keep tracking a target in
## melee range (within the cone's length + melee_track_margin) at
## melee_track_turn_speed right up to the strike, and the enemy steps after
## it if it backs off to the edge: up close, Parry or Defend, don't dodge.
@export var melee_track_radius: float = 5.5
@export var melee_track_margin: float = 1.5
@export var melee_track_turn_speed: float = 300.0
@export var melee_chase_share: float = 0.75
## Lines (Attack / Smash, not snapping or placed) turn at least this fast in
## their last second, instead of the enemy's slow cast turn speed: a long line
## keeps up with anyone more than ~3.5 m away. A skill's own
## final_turn_speed wins.
@export var line_final_turn_speed: float = 80.0
## targets_far skills (Crush) pick someone farther than this.
@export var far_target_min_distance: float = 6.0
## AI allies only start dodging an enemy's area this many seconds after its
## skill is revealed (a human-like reaction), not as soon as the grey area
## shows up. Falling rocks, hazards and blasts are still avoided at once.
@export var ally_react_seconds: float = 0.1
## The same for strikes that can't be Parried (Golem Smash): dodging is
## the real answer (Defend only softens it), so they react sooner.
@export var ally_react_unanswerable_seconds: float = 0.05
## Boss threat: a boss locks onto whoever hurt it most lately, not just the
## nearest. Each member scores its share of the threat (0-1) minus
## distance / threat_distance_scale; the best score is the target.
## Threat halves (threat_decay) every time the boss starts a cast.
@export var threat_distance_scale: float = 15.0
@export var threat_decay: float = 0.5


## Where on the timeline a fighter restarts after choosing Wait (a third
## of the way along, so the next turn comes sooner).
@export_range(0.0, 99.0) var wait_head_start: float = 33.0

@export_group("Movement phase")
## AI allies try to stand at this share of their attack reach from the
## nearest enemy: close to the edge of their range, but inside it.
@export_range(0.3, 1.0) var ally_range_share: float = 0.8
## Extra space allies keep from dangerous enemy areas, in meters.
@export var ally_danger_margin: float = 0.3
## AI allies keep at least this far from a lethal edge or hole; while an
## enemy prepares a push, its push distance plus ally_ledge_margin.
@export var ally_ledge_min: float = 1.5
@export var ally_ledge_margin: float = 1.0
## Mage and Cleric (fragile) stand this far off a boss's front, in degrees.
@export var fragile_flank_degrees: float = 70.0
## Switches for the AI positioning rules (tuning and tests).
@export var ally_avoid_grey := true
@export var ally_fragile_flank := true
## How quickly the camera catches up with the fighter you control.
@export var camera_follow_speed: float = 4.0
## How far the camera sits from the action, in meters.
@export var camera_distance: float = 12.0
## Camera controls: Z / C or right-drag to rotate, mouse wheel to zoom, V to reset.
@export var camera_turn_degrees_per_second: float = 100.0
@export var camera_mouse_sensitivity: float = 0.3
## How fast the right stick tilts the camera up and down.
@export var camera_tilt_degrees_per_second: float = 60.0
@export var camera_min_distance: float = 7.0
@export var camera_max_distance: float = 24.0
@export var camera_min_pitch: float = 20.0
@export var camera_max_pitch: float = 75.0
## When a turn comes up, the camera pans to that fighter before the turn
## begins (and back afterwards). Longer distances take longer, up to this.
@export var turn_pan_max_seconds: float = 0.8
## When an enemy strike catches someone off screen, the camera eases out
## (and over) so everyone hit is in view, up to this distance.
@export var strike_frame_max_distance: float = 34.0


## One enemy skill on its way to landing.
class Strike:
	var enemy: Combatant
	var skill: int
	var def: EnemySkill
	## Per target: {"mult": damage multiplier, "unblockable": bool, "one_hp": bool}.
	var mods := {}
	## Hits still to come after this one (multi-hit skills).
	var hits_left := 0
	var targets: Array[Combatant] = []
	var windup: float = 1.0
	var time_left: float = 1.0
	var reaction: int = 0  # a Reaction value
	## Send the enemy back to the start of the bar when this resolves
	## (true when it strikes during your turn instead of on its own turn).
	var reset_timeline := false
	var rings: Array[MeshInstance3D] = []
	var markers: Array[MeshInstance3D] = []
	## Multi-hit skills: one fainter ring per hit still to come, each closing
	## in so it reaches the marker exactly when its own hit lands.
	var future_rings: Array[MeshInstance3D] = []
	## Wind-up of each later hit (shorter than the first).
	var follow_windup := 0.55
	## The Parry press also Defends whoever can't Parry but can block (Cleric).
	var parry_defends := false


## The round being played, kept across scene reloads (0-based; -1 = not
## chosen yet, so start_round is used).
static var _round_index := -1
## True when the title screen started the tutorial instead of a round.
static var tutorial_mode := false
## True in a Boss Rush (from the title screen's Boss Rush or Continue), where
## fights can be saved; false for Round Select and the tutorial.
static var boss_rush_mode := false
## True when this Boss Rush was resumed with Continue (for the reports).
static var continued := false
## Boss rounds (from Round 8, index PICK_PARTY_FROM) let the player choose
## the party: the chosen class scenes, and the round they were chosen for.
## Retrying the same round keeps the pick; a new round asks again.
const PICK_PARTY_FROM := 7
static var chosen_party: Array[String] = []
static var chosen_for_round := -1
## Balance testing: wall-boss features to switch off ("burst", "crumble",
## "rocks", "winded", "sprites", "undertow").
static var maw_off: PackedStringArray = []
## Balance testing: Stagger bars never fill.
static var stagger_off := false

## The tutorial's fight (data/tutorial.tres).
@export var tutorial_encounter: Encounter
## The tutorial's guide, when tutorial_mode is on.
var tutorial: TutorialDirector = null
## The tutorial pauses the whole fight while it explains something.
var tutorial_pause := false
## Counts of things the player has done this fight ("parries", "perfects",
## "combos_mage"...). The tutorial checks its goals against these.
var stats := {}
## The end-of-fight panel (null until the fight is over and it shows).
var end_screen: EndScreen = null
## Seconds after the fight ends before the panel shows (see the last blow).
@export var end_screen_delay: float = 1.2
var _end_wait := -1.0
## The last enemy falls in slow motion: this speed, for this many real
## seconds (0: off). Skipped when the game already runs faster (sims).
@export var victory_slowmo_scale: float = 0.35
@export var victory_slowmo_seconds: float = 2.0
## After the slow motion, the camera stays on the body until it lies still,
## at most this many seconds.
@export var finale_settle_seconds: float = 1.2
var _finale_hold := 0.0
## Unscaled seconds of slow motion left (0: none).
var _slowmo_left := 0.0
## The last enemy's fall (the finale): 0 none, 1 the camera on it in slow
## motion, 2 panning back to the party; then the end panel.
var _finale := 0
var _finale_target: Combatant = null
## Real seconds between the camera getting back to the party and the panel.
@export var finale_pause: float = 0.4
## How close the camera comes in on the falling enemy (share of its distance).
@export var finale_zoom: float = 0.7
var _finale_close := 0.0  # 0..1: how far into that zoom
## The victory theme starts this long after the victory jingle ends.
@export var victory_theme_gap: float = 1.0

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
## The controlled fighter's attacks (combo bar) or skills (Abilities).
var _moves: Array[Dictionary] = []
var _skills: Array[Dictionary] = []
## True while an AI ally's combo plays (_ai_play_plan).
var _ai_playing := false
## Items left this fight: {"Potion": n, "Ether": n, "Revive": n}.
var pouch := {}
## What each combo slot will do (see BattleMenu.plan); also holds "move",
## "hits" and "duration" for playback.
var _plan: Array[Dictionary] = []
## True while a Mage stands still (Focus): AP refills faster.
var _focus_boost := false
const ENCHANTS := ["fire", "ice", "lightning", "energy"]
## Enchant's element menu: the skill waiting for its element.
var _element_skill: Dictionary = {}
## Direction -> element, as her spell codes (Fire up, Ice down, ...).
const ELEMENT_BY_DIR := {"up": "fire", "down": "ice", "left": "lightning", "right": "energy"}
## Playhead speed right now: 1, or exec_fast_forward once nothing is left
## to press.
var _exec_speed := 1.0
## Timing rings already launched this combo ("slot:hit" -> its node).
var _exec_rings: Dictionary = {}
## Attack effects: which hits of the playing block have started their
## approach (a fireball in flight...), so they arrive as the hit lands.
var _exec_launched: Dictionary = {}
## Hits of the current block whose swing sound has started (BattleSounds.swing).
var _exec_swung: Dictionary = {}
## Every hit of the enemy's multi-hit strike so far was parried (the last
## Parry of a fully parried chain is a Perfect Parry).
var _parry_clean := false
## Mage spell codes: how many arrows of the current code are in.
var _exec_code := 0
const CODE_KEYS := {"up": "move_forward", "down": "move_back", "left": "move_left", "right": "move_right"}
## Tab between turns: a tap steers the next party member; holding it for
## steer_hold_seconds stops time and opens the picker (SteerPicker).
@export var steer_hold_seconds: float = 0.3
var steer_picker: SteerPicker
var _tab_down_ms := -1  # Tab went down between turns at this time; -1 = not held
var _picker_open := false
## Teleport targeting: the ally the marker is snapped to (Tab), if any.
var _snap_ally: Combatant = null
var _snap_index := -1
## Abilities: the skill waiting for a target, the choices, and the marker.
var _pending_skill: Dictionary = {}
var _target_choices: Array[Combatant] = []
var _target_index := 0
var _target_marker: MeshInstance3D = null
## Lingering hazards (fire trails): {"area", "owner", "turns", "dps", "acc"}.
var _hazards: Array[Dictionary] = []
## Inferno's marked circles waiting to explode: {pos, radius, left, attacker, move, ring}.
var _blasts: Array[Dictionary] = []
## Ceiling Burst circles still to land: {"area", "owner", "time_left",
## "damage", "warning", "ring"}. They tick in world time (paused on turns).
var _falls: Array[Dictionary] = []
## Rocks Ceiling Burst left behind: {"rock", "time_left"} (world time).
var _debris: Array[Dictionary] = []
## Walking over a lethal edge: a Parry-like save in progress, or empty.
## {"fighter", "time_left", "reacted" (0 none, 1 in time, 2 too early), "ring"}.
var _edge_save: Dictionary = {}
## Party members pushed over an edge while another one is already teetering.
var _edge_queue: Array = []
const FALLING_ROCK_COLOR := Color(1.0, 0.62, 0.25)
## Telegraph arrows being animated: {"node", "base", "dir"}.
var _telegraph_arrows: Array[Dictionary] = []
var _telegraph_time := 0.0

## True while picking which enemy a combo will hit (TARGET mode for Attack).
var _choosing_attack_target := false
## One Ability per turn: used already this turn? (Abilities greys out.)
var _skill_used := false
## Turn head start earned by an Ability this turn (Shield Bash), applied
## when the turn ends.
var _turn_head_start := 0.0
## Arts picked from the Arts list: {start index on the bar: Art name}. That
## group always stays that Art, whatever comes before or after it.
var _combo_locks := {}
## Per combo slot: [first basic move on the bar, how many it covers].
var _plan_spans: Array = []
## Undiscovered Arts waiting in the playing combo (see _find_hidden_arts).
var _pending_reveals := {}
## Seconds left on the "NEW ART!" pause.
var _exec_reveal_left := 0.0
## How long the combo pauses when a new Art reveals itself.
@export var art_reveal_seconds := 1.4
## How fast the playhead crosses the combo bar, in AP of bar per second. The
## same for every move: a block lasts as long as it is wide (Bash's growing
## chains are the one exception, see _plan_slot).
@export var playhead_ap_per_second: float = 15.0
## Monk: how many times a Headbutt can restart the combo bar in one combo.
@export var bar_resets_per_combo: int = 1
## Knight: while their Taunt is up, allies within this many meters of them are
## covered by Block and Parry even if their class can't do them.
@export var guard_radius: float = 3.0
## Knight: how many of their turns stacked shield-blow aggro can reach.
@export var aggro_max_turns: int = 3
## Cleric's Haste: how much faster a hasted ally moves along the timeline.
@export var haste_timeline_bonus: float = 0.25
## Archer's Exposing Shot: extra damage an Exposed enemy takes from everyone.
@export var exposed_bonus: float = 0.15
## Stagger: heavy moves (Smash type, breaking moves, Arts) fill bars this
## much faster; a Staggered enemy takes this much more damage until its
## next turn.
@export var stagger_heavy_mult: float = 1.5
@export var staggered_bonus: float = 0.25
## Stagger: skills with a bar move through the casting zone at this share
## of their usual speed, so the party gets a real chance to fill it.
@export var stagger_cast_speed: float = 0.5
## Stagger: a broken skill knocks the enemy back to this far before the
## casting zone (it loses the skill, not a whole lap of the timeline).
@export var stagger_knockback: float = 25.0
## Command timing "windup" (Settings, prototype): a party member chooses at
## this point of the timeline, then has until the end (plus a short grace)
## to get in reach of the chosen enemy; if not, the turn becomes a Wait.
@export var party_command_at: float = 65.0
@export var windup_grace_seconds: float = 1.5
## Tests / balance runs can force it on without touching the saved setting.
static var windup_override := -1  # -1 = use the setting, 0 = off, 1 = on
static var party_ai_override := -1  # same, for Party AI (tests)
## Party AI: how much of its own combo bar an AI ally aims to spend (good
## damage), how much of the steered fighter's bar it keeps for them, and the
## max AP its timed hits add (a Perfect adds perfect_max_ap_gain).
@export var ai_spend_share: float = 0.75
@export var ai_reserve_share: float = 0.6
@export var ai_max_ap_per_hit: float = 1.5
## AI allies' hits deal this share of a normal (untimed) hit, so Party AI
## doesn't turn into an easy mode.
@export var ai_damage_mult: float = 0.8
## Mage's Ice discount on Fire: per Ice on the bar before it (or in the same
## Art), up to the max; an Ice last turn adds the carry; never past the cap.
## A growing circle that stops growing (contained: Shadowflare's sprites
## all hit; or grown to full size) gives anyone inside time to run out
## before it strikes: its radius at the slowest party member's walking
## speed, plus this many seconds (battle time) to react.
@export var flare_run_out_extra: float = 0.8
@export var ice_discount_per: float = 0.2
@export var ice_discount_max: float = 0.4
@export var ice_discount_carry: float = 0.2
@export var ice_discount_cap: float = 0.5
## Lightweight enemies (Gust Sprites): the least push any hit gives them
## (before their knockback_taken).
@export var lightweight_push: float = 1.5
## A Gust Sprite knocked into a wall boss's open mouth (while it pulls): its
## Detonate goes off inside, this many times the blast's damage, and the
## boss is Staggered. choke_reach: meters past its body that still count.
@export var choke_damage_mult: float = 3.0
@export var choke_reach: float = 0.6
## Timing rings on the enemy start this long before each press hit, and
## close in at a steady speed (so a late start begins smaller).
@export var timing_ring_lead: float = 0.9
## Once a combo has nothing left to press (every timing done or past), the
## rest of it plays this many times faster.
@export var exec_fast_forward: float = 5.0
## Mage spell codes start this far into the block (a share of it).
@export var code_start: float = 0.05
## Mage Focus: a charge every focus_seconds standing still (battle time),
## up to her focus_max; each adds focus_bar_per AP to her bar (combatant).
@export var focus_seconds: float = 2.0
## Walking this far costs one charge (teleports and pushes don't count).
@export var focus_walk_meters: float = 2.0
## While she stands still, the party's AP refills this much faster.
@export var focus_ap_bonus: float = 0.5
## Enchant: the light effects allies' hits carry.
@export var enchant_burn: float = 0.2
@export var enchant_stagger_mult: float = 1.5
@export var enchant_push: float = 1.0
## AI Cleric: Healing on the most hurt ally under this share of max HP, Full
## Cure under ai_full_cure_below (was 0.55 / 0.3).
@export var ai_heal_below: float = 0.7
@export var ai_full_cure_below: float = 0.35
## True while an AI ally builds its combo: every Art merges, found or not
## (it never reveals the ones you haven't found).
var _ai_building := false
## Answer tags: a move on the combo bar will break the target's Defense,
## so whatever comes after it isn't blocked.
var _guard_breaks_in_bar := false
## Bosses: most actions of immunity a cancel can leave (see cancel_every).
## Golem Smash rock blasts: their circles' color.
const ROCK_BLAST_COLOR := Color(1.0, 0.4, 0.15)
const MAX_CANCEL_LOCK := 3
## This party turn is a windup command (choose now, act at the end).
var _command_phase := false
## Windup: the committed attack is playing (reached ACT); the combo bar
## can't be backed out of to the command menu.
var _windup_acting := false
## Windup on for this fight (read once when it starts: the setting applies
## from the next fight or a restart).
var _windup := false
## Archer's Agility: the extra hit deals this share of the move's first hit.
@export var agility_hit_share: float = 0.5
## Archer's Riposte: meters she hops back after countering.
@export var riposte_hop: float = 3.0
## Monk: extra damage on an Art for each token it uses up.
@export var token_damage_bonus: float = 0.10
## Walking over a lethal edge: seconds the save ring takes to close (the
## timing window is the Parry's, parry_window).
@export var edge_save_seconds: float = 1.0
## After a caught fall: for this many of the fighter's own turns, going over
## an edge again is a fall (no save). Then saves work again.
@export var off_balance_turns: int = 3
## Defend against a skill that pushes or pulls: the move is this share as long.
@export var defend_move_share: float = 0.5
## The enemy the combo will hit, locked when the combo bar opens.
var _combo_target: Combatant = null
## Party AP just before the combo was paid, so the bar keeps showing it.
var _ap_before_combo := 0.0
## Monk: the current slot's token result: {"bonus": damage share, "after":
## tokens if every timing is Perfect, "sloppy": tokens otherwise, ...}.
var _exec_tokens := {}
## The bar length when the combo started (the playing bar keeps its scale
## while the Monk's bar grows or is spent mid-combo).
var _exec_limit := 0.0
## After a Headbutt restart: the slot the fresh bar starts on once its
## "READY" lead-in ends (-1 = none waiting).
var _exec_resume_slot := -1

# Combo playback (runs in _process while the menu is EXECUTING).
## PARTIAL: the player went for a Hold or Tap timing but didn't nail it
## (early/late release, too few taps): no Perfect, but no penalty either.
enum Timing { NONE, PERFECT, MISS, PARTIAL }
var _exec_attacker: Combatant = null
var _exec_slot := 0
var _exec_time := 0.0
var _exec_hits_done := 0
## Timing result for each hit of the current move.
var _exec_timings: Array[int] = []
## Hold timings: holding Confirm after a good press in the first box.
var _exec_holding := false
## Tap timings: taps counted so far for the current slot's last hit.
var _exec_taps := 0
## True while a Perfect hit is being applied (Divine Barrier's bigger barrier).
var _exec_hit_perfect := false
## Counts down after the last move before the turn ends.
var _exec_outro := -1.0
## Counts down the lead-in before the first move starts.
var _exec_lead_in := 0.0
## Counter-parry in progress: seconds until the counter-swing lands (< 0: none
## pending), and who swings it. _counter_bonus: the rest of the combo after a
## parried counter.
var _counter_left := -INF
var _counter_from: Combatant = null
var _counter_bonus := 0.0
var _counter_recover := 0.0
## When the last timed hit landed (msec), for late_press_grace.
var _last_landed_ms := -100000

## True on frames where you moved (so the world moved with you).
var _world_moved := false
var _camera_offset: Vector3
## Camera angle around the fighter (yaw), tilt (pitch, degrees down) and zoom.
var _cam_yaw := 0.0
var _cam_pitch := 35.0
var _cam_distance := 12.0
var _cam_start_pitch := 35.0
## The point the camera follows, smoothed so rotating stays steady.
var _cam_focus := Vector3.ZERO
## The party member you were steering before an ally's turn took over;
## control goes back to them when that turn ends.
var _steer_before_turn: Combatant = null
## A smooth camera pan in progress: where it started, its length, and time so far.
var _pan_start := Vector3.ZERO
var _pan_duration := 0.0
var _pan_time := 0.0
## 0..1: how far the camera has eased into framing a strike's targets.
var _strike_view := 0.0
var _strike_framing := false
var _strike_focus := Vector3.ZERO
var _strike_distance := 12.0
## Seconds left before the active fighter's turn actually begins (the camera
## is panning over to them).
var _turn_intro_left := 0.0
var _flash_message := ""
## The fight's opening text (round name and tip): its own slot, so turns and
## other messages don't wipe it before it's read. Counts down only while shown.
var _intro_message := ""
var _intro_left := 0.0
## This fight's play-test report (not kept for the tutorial).
var playtest: PlaytestLog = null
var _flash_time_left := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var timeline_bar: TimelineBar = $UI/TimelineBar
@onready var turn_label: Label = $UI/TurnLabel
@onready var warning_label: Label = $UI/WarningLabel
@onready var ap_bar: ProgressBar = $UI/APBar
@onready var ap_label: Label = $UI/APBar/APLabel
## The segmented AP meter drawn in code (replaces the plain APBar on screen).
var ap_meter: APMeter = null
## Hit count and damage total on the right while a combo plays.
var combo_counter: ComboCounter = null
## Esc during a fight: Resume / Restart fight / Quit to title.
var pause_menu: PauseMenu = null
## While choosing moves for a combo: the highlighted move's area on the
## floor, and a ring under every enemy it would hit.
var _preview_area: AttackRange = null
var _preview_barrier: AttackRange = null
var _preview_marks: Array[MeshInstance3D] = []
## Who the previewed move would hit (also marked on the timeline).
var _preview_hits: Array[Combatant] = []
## The enemy whose floating name is lit up as the target.
var _named_target: Combatant = null
## While the Assassin is steered: each enemy's positional ring (enemy ->
## PositionalRing): front arrow, violet rear arc, or a full ring for enemies
## without positionals.
var _behind_cones := {}
var _preview_key := ""
@onready var controls_label: Label = $UI/ControlsLabel
@onready var party_status: PartyStatus = $UI/PartyStatus
@onready var enemy_status: PartyStatus = $UI/EnemyStatus
@onready var battle_menu: BattleMenu = $UI/BattleMenu


## PS1 look: the 3D view at a low resolution in 15-bit colour, dithered.
## A layer under the HUD, so the HUD stays sharp.
var retro_screen: ColorRect = null
const TEXT_LAYER_BIT := 1 << 19
var _text_view: SubViewport = null
var _text_camera: Camera3D = null

func _add_retro_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RetroScreen"
	layer.layer = 0
	add_child(layer)
	retro_screen = ColorRect.new()
	retro_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retro_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ps1_screen.gdshader")
	retro_screen.material = mat
	layer.add_child(retro_screen)
	apply_screen_filter()
	# Floating text (names, damage numbers, skill names) stays sharp: it's
	# drawn by a second camera on its own layer, over the low-res view.
	for cam in find_children("*", "Camera3D", true, false):
		(cam as Camera3D).cull_mask &= ~TEXT_LAYER_BIT
	_text_view = SubViewport.new()
	_text_view.transparent_bg = true
	_text_view.world_3d = get_viewport().find_world_3d()
	_text_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_text_camera = Camera3D.new()
	_text_camera.cull_mask = TEXT_LAYER_BIT
	_text_view.add_child(_text_camera)
	layer.add_child(_text_view)
	var shown := TextureRect.new()
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.texture = _text_view.get_texture()
	layer.add_child(shown)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_tick_text_view)
	for label in find_children("*", "Label3D", true, false):
		(label as Label3D).layers = TEXT_LAYER_BIT


## Puts the chosen screen filter (Options) on the screen and the figures.
func apply_screen_filter() -> void:
	var look: Dictionary = Settings.SCREEN_FILTER_LOOKS[Settings.screen_filter()]
	Figure.set_snap_lines(float(look["snap"]))
	if retro_screen == null:
		return
	retro_screen.visible = Settings.screen_filter() != "off"
	var mat := retro_screen.material as ShaderMaterial
	if retro_screen.visible:
		mat.set_shader_parameter("lines", float(look["lines"]))
		mat.set_shader_parameter("levels", float(look["levels"]))
		mat.set_shader_parameter("dither_strength", float(look["dither"]))
		mat.set_shader_parameter("smooth_pixels", bool(look["smooth"]))


func _on_node_added(node: Node) -> void:
	if node is Label3D:
		(node as Label3D).layers = TEXT_LAYER_BIT
	elif node is Camera3D and node != _text_camera:
		(node as Camera3D).cull_mask &= ~TEXT_LAYER_BIT


## Keeps the text camera on the view's camera, at the window's size.
func _tick_text_view() -> void:
	if _text_view == null or not is_inside_tree():
		return
	var main := get_viewport().get_camera_3d()
	if main == null or main == _text_camera:
		return
	_text_view.size = get_viewport().get_visible_rect().size
	_text_camera.global_transform = main.global_transform
	_text_camera.fov = main.fov
	_text_camera.near = main.near
	_text_camera.far = main.far
	_text_camera.projection = main.projection
	_text_camera.size = main.size


func _ready() -> void:
	Keybinds.apply_saved()  # the player's own keys (Change Keys on the title screen)
	for label in [turn_label, warning_label, ap_label]:
		HudStyle.style_label(label)  # the HUD's slanted title lettering
	_load_round()
	combatants.append_array(party)
	combatants.append_array(enemies)

	timeline_bar.combatants = combatants
	timeline_bar.length = TIMELINE_LENGTH
	timeline_bar.cast_zone_start = cast_zone_start
	_windup = (windup_override == 1) if windup_override >= 0 else (Settings.command_windup() or tutorial_mode)  # the tutorial teaches Windup
	timeline_bar.party_command_at = party_command_at if _windup else -1.0
	party_status.party = party
	enemy_status.party = enemies
	enemy_status.tags_on_left = true  # keeps the right edge tidy
	battle_menu.commands = PackedStringArray(["Attack", "Abilities", "Wait", "Items"])
	var enabled: Array[bool] = [true, true, true, true]
	battle_menu.command_enabled = enabled
	battle_menu.command_notes = PackedStringArray(["", "", "", ""])
	refill_pouch(not tutorial_mode)
	controlled = party[0]
	controlled.set_highlighted(true)
	ap = starting_ap
	current_max_ap = max_ap
	_add_retro_screen()
	ap_meter = APMeter.new()
	$UI.add_child(ap_meter)
	ap_meter.anchor_left = 0.0
	ap_meter.anchor_right = 1.0
	ap_meter.anchor_top = 1.0
	ap_meter.anchor_bottom = 1.0
	ap_meter.offset_top = -120.0
	ap_meter.offset_bottom = -58.0
	ap_meter.value = ap
	ap_meter.max_value = current_max_ap
	ap_meter.ceiling = max_ap_ceiling()
	ap_bar.visible = false
	combo_counter = ComboCounter.new()
	$UI.add_child(combo_counter)
	steer_picker = SteerPicker.new()
	$UI.add_child(steer_picker)
	steer_picker.party = party
	pause_menu = PauseMenu.new()
	$UI.add_child(pause_menu)
	var command_list := CommandList.new()
	command_list.arena = self
	$UI.add_child(command_list)
	pause_menu.command_list = command_list
	command_list.closed.connect(func(): pause_menu.visible = true)
	pause_menu.restart_requested.connect(func():
		_save_playtest("Left early")
		get_tree().reload_current_scene())
	pause_menu.options_changed.connect(apply_screen_filter)
	pause_menu.progress_saved = boss_rush_mode
	if boss_rush_mode:
		SaveGame.save_round(_round_index)  # auto-save: Continue starts this fight over
	pause_menu.quit_requested.connect(func():
		_save_playtest("Left early")
		get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn"))
	# The camera keeps its angle from the scene and backs away along its
	# own view direction (+Z is "behind" a camera in Godot).
	_cam_pitch = -camera.global_rotation_degrees.x
	_cam_start_pitch = _cam_pitch
	_cam_yaw = camera.global_rotation_degrees.y
	_cam_distance = camera_distance
	_cam_focus = _camera_focus()
	_place_camera()
	if _picks_party() and chosen_for_round != _round_index:
		# A new boss round: choose the party first (the fight waits, paused).
		var picker := PartyPicker.new()
		$UI.add_child(picker)
		var ticked: Array = chosen_party.duplicate() if not chosen_party.is_empty() \
				else encounter.party.map(func(scene): return scene.resource_path)
		picker.open(encounter.title, ticked)
		picker.chosen.connect(func(paths: Array[String]):
			chosen_party = paths
			chosen_for_round = _round_index
			get_tree().reload_current_scene())
		picker.back_requested.connect(func():
			get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn"))
		return
	print("%s! Party: %s  vs  Enemies: %s" % [encounter.title, _names(party), _names(enemies)])
	if tutorial_mode:
		for c in combatants:
			c.cannot_fall = true
		tutorial = TutorialDirector.new()
		tutorial.battle = self
		add_child(tutorial)
	else:
		_intro_message = "%s: %s  vs  %s" % [encounter.title, _names(party), _names(enemies)]
		if encounter.tip != "":
			_intro_message += "\n" + encounter.tip
		# Reading time: about 20 characters a second, 6 to 18 s.
		_intro_left = clampf(4.0 + _intro_message.length() * 0.05, 6.0, 18.0)
		playtest = PlaytestLog.new(encounter.title, party, enemies)
		if boss_rush_mode:
			playtest.mode = "Boss Rush (continued from a save)" if continued else "Boss Rush"
		else:
			playtest.mode = "Round Select"


## Builds the current round: its arena, then the party and the enemies
## at their starting spots.
func _load_round() -> void:
	var count := boss_rush.rounds.size()
	if _round_index < 0:
		_round_index = clampi(start_round - 1, 0, count - 1)
	_round_index = posmod(_round_index, count)
	encounter = tutorial_encounter if tutorial_mode else boss_rush.rounds[_round_index]
	arena = encounter.arena.instantiate() as Arena
	add_child(arena)
	if arena.scenery:
		arena.scenery.apply_environment($WorldEnvironment.environment, $Sun)
	var party_scenes: Array[PackedScene] = encounter.party
	if _picks_party() and chosen_for_round == _round_index and not chosen_party.is_empty():
		party_scenes = []
		for path in chosen_party:
			party_scenes.append(load(path))
	party = _spawn(party_scenes, $Party, false)
	enemies = _spawn(encounter.enemies, $Enemies, true)
	for enemy in enemies:
		if encounter.enemy_hp_mult != 1.0:
			enemy.max_hp = roundi(enemy.max_hp * encounter.enemy_hp_mult)
			enemy.hp = enemy.max_hp
		enemy.speed *= encounter.enemy_speed_mult
		if enemy.anchored:
			_anchor_to_wall(enemy)
			_apply_maw_off(enemy)
	Sfx.duck(false)
	Sfx.music(_round_music())


## The music for this fight: the Living Armor and the Gale Maw have their
## own (when they're the only boss), other bosses share the boss theme,
## everything else the battle theme. The tutorial has its own.
func _round_music() -> String:
	if tutorial_mode:
		return "tutorial"
	var bosses: Array[String] = []
	for enemy in enemies:
		if enemy.boss:
			bosses.append(enemy.scene_file_path.get_file().get_basename())
	if bosses.size() == 1 and bosses[0] in ["living_armor", "gale_maw"]:
		return bosses[0]
	return "boss" if not bosses.is_empty() else "battle"


## Balance testing: strips the wall-boss features listed in maw_off.
func _apply_maw_off(boss: Combatant) -> void:
	if maw_off.is_empty():
		return
	var kept: Array[EnemySkill] = []
	for skill in boss.skills:
		var def := skill
		if maw_off.has("burst") and def.skill_name == "Gale Burst":
			continue
		if maw_off.has("undertow") and def.special == EnemySkill.Special.LINE_TO_EACH:
			def = def.duplicate()
			def.line_extend = 1.0
			def.double_on_off_balance = false
		kept.append(def)
	boss.skills = kept
	if maw_off.has("crumble"):
		boss.crumble_at_share = 0.0
	if maw_off.has("rocks"):
		boss.rock_regrow_turns = 0
	if maw_off.has("winded"):
		boss.winded_timeline = 0.0
	if maw_off.has("sprites"):
		boss.summon_scene = null


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


## True for rounds where the player chooses the party (boss rounds).
func _picks_party() -> bool:
	return not tutorial_mode and _round_index >= PICK_PARTY_FROM


## Starts a round (0-based) or the tutorial. Used by the title screen.
static func start(tree: SceneTree, round_index: int, tutorial: bool, boss_rush: bool = false,
		from_save: bool = false) -> void:
	_round_index = round_index
	tutorial_mode = tutorial
	boss_rush_mode = boss_rush and not tutorial
	continued = from_save and boss_rush_mode
	tree.change_scene_to_file("res://scenes/battle/battle_arena.tscn")


func _count(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


## Adds an amount to a play-test count (HP healed, ...).
func _count_amount(key: String, amount: int) -> void:
	if amount > 0:
		stats[key] = int(stats.get(key, 0)) + amount


## Adds a party member mid-fight (the tutorial's new arrivals), next to the
## party's starting spot.
func add_party_member(scene: PackedScene) -> Combatant:
	var fighter := scene.instantiate() as Combatant
	var spot := arena.spawn_points(false, 1)[0]
	spot.origin += Vector3(2.0 * (party.size() - 2), 0, 1.5)
	fighter.transform = spot
	$Party.add_child(fighter)
	party.append(fighter)
	combatants.append(fighter)
	fighter.cannot_fall = tutorial_mode
	fighter.timeline_pos = randf_range(10.0, 40.0)
	_keep_in_arena(fighter)
	return fighter


## The tutorial: takes a party member out of the fight for a while (hidden,
## off the timeline and the HP panel) without freeing it.
func bench_member(fighter: Combatant) -> void:
	party.erase(fighter)
	combatants.erase(fighter)
	fighter.visible = false
	fighter.process_mode = Node.PROCESS_MODE_DISABLED
	fighter.set_highlighted(false)
	if _steer_before_turn == fighter:
		_steer_before_turn = null
	if controlled == fighter:
		controlled = null


## Brings a benched party member back, near the party's start spot.
func unbench_member(fighter: Combatant) -> void:
	if party.has(fighter):
		return
	party.append(fighter)
	combatants.append(fighter)
	fighter.visible = true
	fighter.process_mode = Node.PROCESS_MODE_INHERIT
	var spot := arena.spawn_points(false, 1)[0]
	fighter.global_position = spot.origin + Vector3(2.0 * (party.size() - 2), 0, 1.5)
	fighter.timeline_pos = randf_range(10.0, 40.0)
	_keep_in_arena(fighter)


## N / P: jump to the next or previous round (restarts the scene).
func _change_round(step: int) -> void:
	_save_playtest("Left early")
	continued = false  # later rounds are plain Boss Rush again
	_round_index += step
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_tick_slowmo(delta)
	_tick_finale(delta)
	_world_moved = false
	_tick_ragdolls(delta)
	_tick_knockdowns(delta)
	_tick_chasers(delta)
	if _charge_orb != null and _menu_mode != BattleMenu.Mode.EXECUTING:
		_end_charge_orb()
	if not _game_over and not tutorial_pause:
		if not _edge_save.is_empty():
			_update_edge_save(delta)  # teetering on the edge: everything waits
		elif _strike != null:
			_update_strike(delta)  # everything else waits while a strike plays
		elif _picker_open:
			# Choosing who to steer: time stands still until Tab is let go.
			if not Input.is_action_pressed("swap_character"):
				_close_steer_picker()
		elif active == null:
			_check_steer_hold()
			var world_delta := delta * battle_speed
			ap = minf(ap + ap_regen_per_second * _ap_gain_multiplier() * _focus_ap_mult() * world_delta, current_max_ap)
			for member in party:
				member.riposte_left = maxf(member.riposte_left - world_delta, 0.0)
			_free_roam(delta, world_delta)
			_tick_focus(world_delta)
			_tick_fuses(world_delta)
			_tick_hazards(world_delta)
			_tick_falls(world_delta)
			_tick_stances(world_delta)
			_advance_timeline(world_delta)
		elif _turn_intro_left > 0.0:
			_turn_intro_left -= delta
			if _turn_intro_left <= 0.0:
				_begin_active_turn()
		elif _party_turn() and _menu_mode == BattleMenu.Mode.EXECUTING:
			_update_combo(delta)
		elif _party_turn() and _menu_mode == BattleMenu.Mode.TARGET:
			_update_target_marker(delta)
		# On a party turn the fighter is locked in place until a command is chosen.
	_update_answer_tags()
	_update_cast_areas()
	_update_mouths()
	_update_move_preview()
	_update_timeline_targets()
	_update_behind_cones()
	_fade_areas_during_strike()
	_animate_telegraphs(delta)
	# Checked again: the strike above may have just knocked out the last fighter.
	if not _game_over:
		_update_attack_ranges()
	if _game_over:
		_tick_end_screen(delta)
	_update_camera(delta)
	_update_ui(delta)


# --- End of the fight -------------------------------------------------------

## Once the fight is over: a short pause, then the end panel; the camera
## turns slowly round the arena behind it.
func _tick_end_screen(delta: float) -> void:
	if _finale == 1:
		return  # the last enemy still falling
	if _finale == 2:
		if _pan_time < _pan_duration:
			return  # the camera on its way back
		_finale = 0
		_end_wait = finale_pause
	if end_screen == null:
		if _end_wait < 0.0:
			_end_wait = end_screen_delay
		_end_wait -= delta
		if _end_wait <= 0.0:
			_show_end_screen()
		return
	_cam_yaw += delta * 6.0


func _show_end_screen() -> void:
	Sfx.stop_music()
	Sfx.play("victory" if _won() else "defeat")
	if _won() and not tutorial_mode:
		# The victory theme, a moment after the jingle.
		var jingle := load("res://audio/sfx/victory.ogg") as AudioStream
		var wait := Timer.new()
		wait.one_shot = true
		wait.ignore_time_scale = true
		wait.wait_time = (jingle.get_length() if jingle else 1.0) + victory_theme_gap
		wait.timeout.connect(func(): Sfx.music("victory", false))  # straight in, no fade
		add_child(wait)
		wait.start()
	if _won():
		for m in _standing(party):
			m.animate("victory")
	end_screen = EndScreen.new()
	$UI.add_child(end_screen)
	end_screen.setup(_end_screen_data())
	end_screen.chosen.connect(_end_choice, CONNECT_DEFERRED)  # after the key press is done


func _won() -> bool:
	return _standing(enemies).is_empty()


## What the end panel shows. Victory: banner, rank, the fight summary;
## Defeat: banner, the enemy's HP left, what went wrong; tutorial: plain.
func _end_screen_data() -> Dictionary:
	var info := {}
	var seconds := 0.0
	if playtest != null:
		seconds = (Time.get_ticks_msec() - playtest.start_msec) / 1000.0
	var clock := "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	info["title"] = encounter.title if encounter != null else ""
	var bosses := enemies.filter(func(e): return not e.has_meta("summoner")).map(func(e): return e.display_name)
	var round_title := String(info["title"])
	if not bosses.is_empty():
		info["title"] = "%s: %s" % [info["title"], ", ".join(bosses)]
	if tutorial_mode:
		info["result"] = "tutorial"
		info["title"] = "Training Golem"
		info["choices"] = [["title", "Back to the title"], ["retry", "Play again"]]
		return info
	var last_round := boss_rush == null or _round_index + 1 >= boss_rush.rounds.size()
	var picks := not tutorial_mode and _round_index >= PICK_PARTY_FROM
	if _won():
		info["result"] = "victory"
		var rank := _fight_rank(seconds)
		info["rank_letter"] = rank["letter"]
		info["rank_total"] = rank["total"]
		info["best_rank"] = Settings.record_rank(round_title, rank["letter"])
		info["subtitle"] = "%s  ·  %d turns" % [clock, _total_turns()]
		var list := [["title", "Back to the title"] if last_round else ["next", "Next round"], ["summary", "Fight summary"], ["retry", "Retry"]]
		if picks or (not last_round and _round_index + 1 >= PICK_PARTY_FROM):
			list.append(["party", "Change party"])
		list.append_array([["report", "Open play-test report"], ["menu", "Back to the menu"]])
		info["choices"] = list
		info["summary"] = _summary_data(rank, seconds)
	else:
		info["result"] = "defeat"
		var foes := _standing(enemies)
		info["subtitle"] = ", ".join(foes.map(func(e): return "%s: %d / %d" % [e.display_name, e.hp, e.max_hp])) + "  ·  " + clock
		var list := [["retry", "Retry"], ["wrong", "What went wrong"]]
		if picks:
			list.append(["party", "Change party"])
		list.append_array([["report", "Open play-test report"], ["menu", "Back to the menu"]])
		info["choices"] = list
		info["wrong"] = _wrong_data()
	info["keys"] = Keybinds.fill("{up} / {down}: choose     {confirm}: select     O: reports     Esc: menu")
	return info


func _total_turns() -> int:
	var n := 0
	if playtest != null:
		for name in playtest.turns:
			n += int(playtest.turns[name])
	return n


## The rank: Health, Timing, Reading and Pace, 25 points each.
## S 85+, A 70+, B 50+, else C.
func _fight_rank(seconds: float) -> Dictionary:
	# Health: the HP still missing at the end (heals count: total damage
	# taken ran past the party's whole max HP in most boss fights).
	var max_total := 0
	var missing := 0
	var taken := 0
	var downs := 0
	for member in party:
		max_total += member.max_hp
		missing += member.max_hp - member.hp
	if playtest != null:
		for name in playtest.party:
			taken += int(playtest.party[name]["taken"])
			downs += int(playtest.party[name]["downs"])
	var health := clampf(25.0 * (1.0 - float(missing) / maxf(max_total, 1.0)) - 10.0 * downs, 0.0, 25.0)
	var perfects := int(stats.get("perfects", 0))
	var chances := int(stats.get("timed_hits", 0)) + int(stats.get("timing_misses", 0))
	var timing := 25.0 if chances == 0 else clampf(25.0 * perfects / float(chances), 0.0, 25.0)
	# Reading: your own mistakes (AI allies standing in things don't count).
	var mistakes := int(stats.get("avoidable_hits_you", 0)) + int(stats.get("parries_too_early", 0)) + int(stats.get("timing_misses", 0))
	var reading := clampf(25.0 - 3.0 * mistakes, 0.0, 25.0)
	var par := encounter.par_seconds if encounter != null else 180.0
	var pace := clampf(25.0 * (2.0 - seconds / maxf(par, 1.0)), 0.0, 25.0)
	var total := health + timing + reading + pace
	var letter := "S" if total >= 85.0 else ("A" if total >= 70.0 else ("B" if total >= 50.0 else "C"))
	return {"letter": letter, "total": roundi(total), "health": health, "timing": timing, "reading": reading, "pace": pace,
			"taken": taken, "missing": missing, "max_hp": max_total, "downs": downs, "perfects": perfects, "chances": chances,
			"mistakes": mistakes, "seconds": seconds, "par": par}


func _summary_data(rank: Dictionary, seconds: float) -> Dictionary:
	var parts := [
		["Health", rank["health"], "%d of %d HP missing%s" % [rank["missing"], rank["max_hp"], (", %d down" % rank["downs"]) if int(rank["downs"]) > 0 else ""]],
		["Timing", rank["timing"], "Perfects %d / %d" % [rank["perfects"], rank["chances"]]],
		["Reading", rank["reading"], "Your mistakes %d" % rank["mistakes"]],
		["Pace", rank["pace"], "%d:%02d (par %d:%02d)" % [int(seconds) / 60, int(seconds) % 60, int(rank["par"]) / 60, int(rank["par"]) % 60]],
	]
	var rows := []
	for member in party:
		var entry: Dictionary = playtest.party.get(member.display_name, {}) if playtest != null else {}
		var downs := int(entry.get("downs", 0))
		var mark := ""
		if downs > 0:
			mark = "went down" if member.is_down else "revived"
		rows.append([member.display_name, "%d / %d" % [member.hp, member.max_hp],
				int(playtest.dealt.get(member.display_name, 0)) if playtest != null else 0,
				int(entry.get("taken", 0)), int(playtest.turns.get(member.display_name, 0)) if playtest != null else 0, mark])
	var items: PackedStringArray = []
	for item_name in Items.ORDER:
		var used := int(stats.get("items_" + item_name.to_lower(), 0))
		if used > 0:
			items.append("%s %d" % [item_name, used])
	var totals := [
		"Time %d:%02d, %d turns" % [int(seconds) / 60, int(seconds) % 60, _total_turns()],
		"Perfects %d" % int(stats.get("perfects", 0)),
		"Parries %d" % int(stats.get("parries", 0)),
		"Highest max AP %d" % maxi(int(stats.get("max_ap_peak", 0)), int(max_ap)),
		"Arts found %d" % int(stats.get("arts_found", 0)),
		"Items used: %s" % (", ".join(items) if not items.is_empty() else "none"),
	]
	return {"parts": parts, "party": rows, "totals": totals}


## Defeat: the enemies' HP left, the 3 sources that hurt most (AVOIDABLE
## where the report counted avoidable strikes), who went down to what, and
## one tip about the worst avoidable one.
func _wrong_data() -> Dictionary:
	var foes := []
	for enemy in enemies:
		if enemy.has_meta("summoner") or enemy.is_down:
			continue  # sprites and the fallen don't need a bar
		foes.append([enemy.display_name, enemy.hp, enemy.max_hp])
	var by_source := {}
	var downs := []
	if playtest != null:
		for name in playtest.party:
			var entry: Dictionary = playtest.party[name]
			for source in entry["sources"]:
				by_source[source] = int(by_source.get(source, 0)) + int(entry["sources"][source])
			for by in entry.get("downed_by", []):
				downs.append([name, String(by) if String(by) != "" else "?"])
	var sources := by_source.keys()
	sources.sort_custom(func(x, y): return by_source[x] > by_source[y])
	var top := []
	var tip := ""
	for source in sources.slice(0, 3):
		var avoidable := playtest != null and playtest.skills.has(source) and int(playtest.skills[source]["avoidable"]) > 0
		avoidable = avoidable or String(source) == "Fell off the arena"
		top.append([source, by_source[source], avoidable])
		if tip == "" and avoidable:
			tip = _tip_for(String(source))
	if tip == "" and not sources.is_empty():
		tip = _tip_for(String(sources[0]))
	return {"enemies": foes, "top": top, "downs": downs, "tip": tip}


## The tip for a damage source ("Enemy: Skill", or a fall): the skill's own
## tip if it has one, otherwise one from its rules.
func _tip_for(source: String) -> String:
	if source == "Fell off the arena":
		return "Keep away from the edge while a push is coming. Defend halves pushes and pulls."
	var def := _skill_def_named(source.get_slice(": ", 1) if source.contains(": ") else source)
	if def == null:
		return ""
	if def.tip != "":
		return def.tip
	if def.lethal:
		return "%s strikes down anyone it can see: hide behind the rock it drops." % def.skill_name
	if def.shared_damage:
		return "%s splits its damage: stack on the one it aims at." % def.skill_name
	if def.special == EnemySkill.Special.GROWING:
		return "Stop %s growing (hit its sprites), then walk out before it lands." % def.skill_name
	if def.launch > 0.0:
		return "%s pushes: stand away from the edge, or Defend to halve it." % def.skill_name
	if not def.parryable():
		return "%s can't be Parried: get out of its area once it's revealed, or Defend." % def.skill_name
	return "%s can be Parried: press Parry as the ring turns gold, or step out of its area." % def.skill_name


func _skill_def_named(skill_name: String) -> EnemySkill:
	for enemy in enemies:
		var todo: Array = enemy.skills.duplicate()
		while not todo.is_empty():
			var def: EnemySkill = todo.pop_back()
			if def == null:
				continue
			if def.skill_name == skill_name:
				return def
			if def.follow_up != null:
				todo.append(def.follow_up)
			if def.stagger_into != null:
				todo.append(def.stagger_into)
	return null


## A choice on the end panel.
func _end_choice(id: String) -> void:
	match id:
		"next":
			_change_round(1)
		"retry":
			get_tree().reload_current_scene()
		"party":
			# The party picker opens for the round: this one after a loss,
			# the next one after a win.
			if _won() and not tutorial_mode:
				_round_index += 1
				continued = false
			chosen_for_round = -1
			get_tree().reload_current_scene()
		"report":
			DirAccess.make_dir_recursive_absolute(PlaytestLog.FOLDER)
			OS.shell_open(ProjectSettings.globalize_path(PlaytestLog.FOLDER))
		"menu", "title":
			get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _picker_open and not event.is_action_pressed("menu"):
		_picker_input(event)  # before the camera: the wheel picks here
		return
	if _camera_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		if _game_over:
			get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")  # the fight is over anyway
		else:
			pause_menu.party = party.duplicate()
			pause_menu.open()  # nothing is lost by accident: quitting is a menu choice
		return
	if tutorial != null and tutorial.wants_input(event):
		get_viewport().set_input_as_handled()
		return
	if tutorial_mode and (event.is_action_pressed("next_round") or event.is_action_pressed("previous_round")):
		return
	if event.is_action_pressed("next_round") or event.is_action_pressed("previous_round"):
		get_viewport().set_input_as_handled()
		_change_round(1 if event.is_action_pressed("next_round") else -1)
		return
	if _game_over and end_screen != null and end_screen.wants(event):
		# Handled first: a choice may load another scene, and then this
		# battle is no longer in the tree to mark the key as used.
		get_viewport().set_input_as_handled()
		end_screen.handle(event)
		return
	if _game_over:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O \
				and playtest != null:
			get_viewport().set_input_as_handled()
			DirAccess.make_dir_recursive_absolute(PlaytestLog.FOLDER)
			OS.shell_open(ProjectSettings.globalize_path(PlaytestLog.FOLDER))
			return
		if event.is_action_pressed("restart"):
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()  # start the battle over
		return
	if not _edge_save.is_empty():
		if event.is_action_pressed("parry"):
			get_viewport().set_input_as_handled()
			_edge_save_press()
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
		_tab_down_ms = -1
		_menu_input(event)
	elif active == null and event.is_action_pressed("swap_character"):
		# Wait for the release: a tap steers the next one, a hold opens the picker.
		get_viewport().set_input_as_handled()
		_tab_down_ms = Time.get_ticks_msec()
	elif active == null and event.is_action_released("swap_character") and _tab_down_ms >= 0:
		get_viewport().set_input_as_handled()
		_tab_down_ms = -1
		_cycle_control()



# --- Timeline -------------------------------------------------------------

## Moves everyone except the current turn owner along the bar by
## "seconds" worth of timeline time. Used both between turns (real time)
## and during your turn (time paid for by walking).
func _advance_timeline(seconds: float) -> void:
	var during_party_turn := active != null
	var next: Combatant = null
	for c in combatants:
		if c == active or c.is_down or c.hold:
			continue
		if c.freeze_left > 0.0:
			c.freeze_left = maxf(0.0, c.freeze_left - seconds)  # Guard Strike: stopped in place
			continue
		var before := c.timeline_pos
		c.timeline_pos += c.speed * time_scale * seconds * _cast_speed(c) * _haste(c)
		if c.team == Combatant.Team.ENEMY and _falls_pending(c):
			c.timeline_pos = minf(c.timeline_pos, TIMELINE_LENGTH - 0.01)  # Ceiling Burst: waits for the last circle

		if c.team == Combatant.Team.ENEMY:
			if before < cast_zone_start and c.timeline_pos >= cast_zone_start:
				_begin_cast(c)
			_tick_bait(c, seconds)
			if c.loaded_skill != Skills.NONE and not c.skill_revealed and (c.timeline_pos >= reveal_at or _true_sight_up()) \
					and not _bait_waiting(c):
				_reveal_skill(c)
			if c.hold_at >= 0.0 and c.timeline_pos >= c.hold_at:
				c.hold = true  # the tutorial keeps it here, skill revealed, without striking

		if c.team == Combatant.Team.PARTY and _windup_on():
			if not c.has_meta("windup_target"):
				if c.timeline_pos < party_command_at:
					continue
				if c.has_meta("knocked"):
					c.timeline_pos = party_command_at  # its turn waits until it's up
					continue
				if during_party_turn:
					c.timeline_pos = party_command_at  # waits at the command point
					continue
				if next == null or c.timeline_pos > next.timeline_pos:
					next = c
				continue
			if c.timeline_pos < TIMELINE_LENGTH:
				continue
			c.timeline_pos = TIMELINE_LENGTH
			if during_party_turn:
				continue  # waits at the end until the current turn is over
			if c.has_meta("knocked"):
				continue  # down: the attack waits (its grace starts once it's up)
			if not _windup_in_reach(c):
				if _lethal_pending():
					# Hiding from a Doom Gaze: the attack waits in cover, and the
					# grace starts once the gaze is over.
					if not c.has_meta("windup_sheltering"):
						c.set_meta("windup_sheltering", true)
						_popup(c, "WAITS IN COVER", Color(0.75, 0.8, 0.95))
					continue
				if _ai_runs(c) and _in_danger(c.global_position, _ally_dangers(c)):
					# An AI ally busy escaping a danger area (falling rocks...):
					# the grace waits until it's out, then it walks in.
					if not c.has_meta("windup_dodging"):
						c.set_meta("windup_dodging", true)
						_popup(c, "DODGING", Color(0.75, 0.8, 0.95))
					continue
				c.remove_meta("windup_dodging")
				var grace := float(c.get_meta("windup_grace", 0.0)) + seconds
				c.set_meta("windup_grace", grace)
				if grace < windup_grace_seconds:
					continue
				var fallback := _windup_fallback(c)
				if fallback == null:
					_windup_missed(c)
					continue
				# The grace is over and the pick is still out of reach: hit the
				# nearest enemy in reach instead of wasting the turn.
				var chosen: Combatant = c.get_meta("windup_target")
				c.set_meta("windup_target", fallback)
				_count("windup_fallbacks")
				_popup(c, "SWITCHES TARGET", Color(0.85, 0.8, 0.6))
				_flash("%s can't reach %s: attacks %s instead" % [c.display_name, chosen.display_name if is_instance_valid(chosen) else "its target", fallback.display_name], 3.0)
			if next == null or c.timeline_pos > next.timeline_pos:
				next = c
			continue
		if c.timeline_pos < TIMELINE_LENGTH:
			continue
		if c.team == Combatant.Team.PARTY and c.has_meta("knocked"):
			c.timeline_pos = TIMELINE_LENGTH  # down: its turn waits until it's up
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
		if _ai_runs(next):
			_ai_turn(next)  # Party AI: an ally you aren't steering plays it, instantly
		else:
			_start_turn(next)


func _start_turn(fighter: Combatant) -> void:
	active = fighter
	# Windup: a party member's turn comes in two parts. The command point
	# (choose) is the turn proper; reaching the end with a target only plays it.
	var acting := fighter.team == Combatant.Team.PARTY and _windup_on() and fighter.has_meta("windup_target")
	_command_phase = fighter.team == Combatant.Team.PARTY and _windup_on() and not acting
	fighter.timeline_pos = party_command_at if _command_phase else TIMELINE_LENGTH
	_flash_time_left = 0.0  # don't carry old messages into a new turn
	timeline_bar.active = fighter
	print("%s's turn" % fighter.display_name)
	if not acting:
		_turn_upkeep(fighter)

	if fighter.team == Combatant.Team.PARTY:
		if _steer_before_turn == null:
			_steer_before_turn = controlled  # remembered, to hand control back afterwards
		_set_controlled(fighter)  # locked onto the fighter whose turn it is
	else:
		fighter.set_highlighted(true)
	# The camera pans over to whoever's turn it is; the turn begins when it arrives.
	_turn_intro_left = _begin_pan()
	if _turn_intro_left <= 0.0:
		_begin_active_turn()


## The start of a turn proper: the play-test log, statuses and hazards this
## fighter cast count down one of its turns.
func _turn_upkeep(fighter: Combatant) -> void:
	if playtest:
		playtest.turn(fighter)
	# Mage: an Ice last turn makes this turn's Fire cheaper (this turn only).
	fighter.set_meta("ice_carry", fighter.get_meta("ice_carry_next", false))
	fighter.remove_meta("ice_carry_next")
	# Effects cast by this fighter count down one of their turns.
	var ended: PackedStringArray = []
	for c in combatants:
		for status_name in c.tick_statuses(fighter):
			ended.append("%s's %s" % [c.display_name, String(status_name).replace("_", " ")])
	if not ended.is_empty():
		_flash("Wore off: " + ", ".join(ended))
	for hazard in _hazards.duplicate():
		if hazard["owner"] == fighter:
			hazard["turns"] = int(hazard["turns"]) - 1
			if hazard["turns"] <= 0:
				_remove_hazard(hazard)


## A party member's turn starts: it recovers HP, and the party gets AP.
func _party_turn_gains(fighter: Combatant) -> void:
	var recovered := fighter.recover_hp()
	if recovered > 0:
		_flash("%s recovers %d HP" % [fighter.display_name, recovered])
	# Every turn starts with enough AP for a few attacks.
	var before := ap
	ap = minf(ap + turn_start_ap, current_max_ap)
	if ap_meter:
		ap_meter.gain(ap - before)


## The camera has arrived: the turn really starts now.
func _begin_active_turn() -> void:
	_turn_intro_left = 0.0
	var fighter := active
	if fighter == null:
		return
	if fighter.team == Combatant.Team.PARTY and fighter.has_meta("windup_target"):
		# Windup: in reach at the end, the combo bar opens on the chosen enemy.
		var target: Combatant = fighter.get_meta("windup_target")
		_clear_windup(fighter)
		if is_instance_valid(target) and not target.is_down and _windup_reaches(fighter, target):
			if not _can_play_on(fighter, target):
				# In reach, but the party can't afford a move that reaches it
				# (others spent the AP): a Wait instead of a stuck combo bar.
				_flash("%s can't afford a move that reaches %s: the turn becomes a Wait" % [fighter.display_name, target.display_name])
				_wait_command()
				return
			_windup_acting = true  # committed: no backing out to the menu
			_open_combo_bar(target)
		else:
			_open_commands()  # its target is gone: choose again
		return
	if fighter.team == Combatant.Team.PARTY:
		_party_turn_gains(fighter)
		_skill_used = false
		_turn_head_start = 0.0
		_open_commands()
	else:
		_run_enemy_turn(fighter)


func _run_enemy_turn(fighter: Combatant) -> void:
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
	_command_phase = false
	_windup_acting = false
	if active.has_meta("ability_badge") and not active.has_meta("windup_target"):
		active.remove_meta("ability_badge")
	battle_menu.used_ability = {}
	if _choosing_attack_target:
		_choosing_attack_target = false
		_clear_target_marker()
	if active != controlled:
		active.set_highlighted(false)
	_send_to_start(active)
	if _turn_head_start > 0.0:
		active.timeline_pos += _turn_head_start  # Shield Bash: next turn comes sooner
		_turn_head_start = 0.0
	active = null
	_hand_back_control()
	_begin_pan()  # glide back to whoever you're steering
	timeline_bar.active = null
	_menu_mode = BattleMenu.Mode.HIDDEN
	_combo_target = null


## Back to the start of the bar, minus any pending penalty.
func _send_to_start(fighter: Combatant) -> void:
	if fighter.has_meta("follow_up_at"):
		# A follow-up (Sword Spin) waits near the end of the bar instead.
		fighter.timeline_pos = fighter.get_meta("follow_up_at")
		fighter.remove_meta("follow_up_at")
		return
	fighter.timeline_pos = -fighter.timeline_penalty
	fighter.timeline_penalty = 0.0


## Pushes a fighter back on the timeline. If they're about to return to
## the start anyway (it's their turn), the push is saved for that moment.
func _push_back(fighter: Combatant, amount: float) -> void:
	if fighter == active:
		fighter.timeline_penalty += amount
	else:
		fighter.timeline_pos -= amount


# --- Party AI ----------------------------------------------------------------
# With Party AI on (pause menu), every party member except the one you steer
# plays its own turns, instantly: no menus, no combo bar, the timeline never
# stops. It may use one Ability, then attacks with a combo of moves and the
# Arts of its class (found or not: an ally you never steer still uses its
# whole kit, but hidden Arts stay hidden: never added to your list, never
# named), spending enough AP for good damage while keeping enough for the
# fighter you steer. Its hits land without timing (no Perfect bonus), never
# reset max AP, and raise it a little (ai_max_ap_per_hit per timed hit).
# Tab (or hold Tab) takes any of them over, as usual.

func _party_ai_on() -> bool:
	if tutorial_mode:
		return false
	return (party_ai_override == 1) if party_ai_override >= 0 else Settings.party_ai()


func _ai_runs(fighter: Combatant) -> bool:
	return fighter.team == Combatant.Team.PARTY and fighter != controlled and _party_ai_on()


## An AI ally's turn (or, with Windup, its act at the end of the bar).
func _ai_turn(fighter: Combatant) -> void:
	_count("ai_turns")
	if _windup_on() and fighter.has_meta("windup_target"):
		# Windup: the act. Attack the chosen enemy if it's in reach.
		var chosen: Combatant = fighter.get_meta("windup_target")
		_clear_windup(fighter)
		var attacked := false
		if is_instance_valid(chosen) and not chosen.is_down and chosen.stance == Skills.Kind.COUNTER:
			# It raised a Counter stance since: back off (a Wait), as you can.
			_flash("%s backs off from the Counter stance" % fighter.display_name)
			_count("ai_counter_backoffs")
		elif is_instance_valid(chosen) and not chosen.is_down and _windup_reaches(fighter, chosen):
			attacked = _ai_attack(fighter, chosen)
		_ai_end(fighter, attacked)
		return
	_turn_upkeep(fighter)
	_party_turn_gains(fighter)
	if _game_over:
		return
	_ai_ability(fighter)
	var target := _ai_pick_target(fighter)
	if target == null:
		_ai_end(fighter, false)
		return
	if _windup_on():
		# Choose now (the command point), act at the end of the bar.
		fighter.set_meta("windup_target", target)
		fighter.set_meta("windup_grace", 0.0)
		fighter.timeline_pos = party_command_at
		_count("windups")
		return
	_ai_end(fighter, _windup_reaches(fighter, target) and _ai_attack(fighter, target))


func _ai_end(fighter: Combatant, attacked: bool) -> void:
	if fighter.has_meta("ability_badge"):
		fighter.remove_meta("ability_badge")
	_send_to_start(fighter)
	if not attacked:
		fighter.timeline_pos += wait_head_start  # a Wait: the next turn comes sooner
		_count("waits")
		_count("ai_waits")
		_count("ai_waits_" + fighter.class_id)


## Who to go after: what allies already focus (a healer mid-ritual, a
## Shadowflare's sprites), skipping enemies in Counter stance and, without
## a push, the tough Gust Sprites. In Classic, it must be in reach now.
func _ai_pick_target(fighter: Combatant) -> Combatant:
	var pushes := _ai_has_push(fighter)
	var choices: Array[Combatant] = []
	for enemy in _standing(enemies):
		if enemy.stance == Skills.Kind.COUNTER:
			continue
		if enemy.damage_taken_share < 0.5 and not pushes and not enemy.lightweight:
			continue  # (Lightweight ones: any hit pushes them)
		if not _windup_on() and not _windup_reaches(fighter, enemy):
			continue
		choices.append(enemy)
	if choices.is_empty():
		return null
	var focus := _ally_focus(fighter)
	if focus != null and choices.has(focus):
		return focus
	return _nearest(fighter, choices)


func _ai_has_push(fighter: Combatant) -> bool:
	for move in Moves.attacks(fighter.class_id):
		if float(move.get("knockback", 0.0)) > 0.0:
			return true
	for art in Moves.arts(fighter.class_id):
		if float(art.get("knockback", 0.0)) > 0.0:
			return true  # found or not: the AI may use it
	return false


## AP the AI keeps for the fighter you steer: part of their combo bar, less
## what the party recharges before their turn comes.
func _ai_reserve(fighter: Combatant) -> float:
	if controlled == null or controlled.is_down or controlled == fighter:
		return 0.0
	var need := minf(controlled.combo_limit, current_max_ap) * ai_reserve_share
	var seconds := _seconds_until_turn(controlled)
	if seconds == INF:
		seconds = 0.0
	return maxf(need - ap_regen_per_second * _ap_gain_multiplier() * seconds, 0.0)


## AI items (one per turn, in place of an Ability; never Ethers): the
## Revive on a downed ally, or a Potion on itself under ai_potion_below HP
## when no Cleric is standing or she can't afford Healing. Returns true if
## one was used.
func _ai_item(fighter: Combatant) -> bool:
	var pick := ""
	var target: Combatant = null
	var downed := party.filter(func(m): return m.is_down)
	if int(pouch.get(Items.REVIVE, 0)) > 0 and not downed.is_empty():
		pick = Items.REVIVE
		target = downed[0]
	elif int(pouch.get(Items.POTION, 0)) > 0 and float(fighter.hp) / maxf(fighter.max_hp, 1.0) < ai_potion_below:
		var healer := false
		for member in _standing(party):
			if member.class_id == "cleric" and ap >= 25.0:
				healer = true
		if not healer:
			pick = Items.POTION
			target = fighter
	if pick == "":
		return false
	var saved_controlled := controlled
	var saved_used := _skill_used
	controlled = fighter
	_use_skill(Items.info(pick), target, fighter.global_position)
	controlled = saved_controlled
	_skill_used = saved_used
	_menu_mode = BattleMenu.Mode.HIDDEN
	_count("ai_items")
	return true


## One Ability, when it clearly helps. Returns true if one was used.
func _ai_ability(fighter: Combatant) -> bool:
	if _ai_item(fighter):
		return true
	var reserve := _ai_reserve(fighter)
	var hurt := func(m: Combatant) -> float: return float(m.hp) / maxf(m.max_hp, 1.0)
	var threatened := false  # a revealed attack is coming at this fighter
	for enemy in _standing(enemies):
		if enemy.skill_revealed and _loaded_offensive(enemy) and enemy.cast_target == fighter:
			threatened = true
	var pick := ""
	var ai_element := ""  # Enchant's element
	var target: Combatant = null
	match fighter.class_id:
		"cleric":
			var lowest: Combatant = null
			for m in _standing(party):
				if lowest == null or hurt.call(m) < hurt.call(lowest):
					lowest = m
			var lifeline := _ai_lifeline_target(fighter)
			if lowest != null and hurt.call(lowest) < ai_full_cure_below:
				pick = "Full Cure"
				target = lowest
			elif lifeline != null:
				pick = "Lifeline"  # caught in something: dash out to an ally, healing both
				target = lifeline
			elif lowest != null and hurt.call(lowest) < ai_heal_below:
				pick = "Healing"
				target = lowest
			else:
				# Shielding: two or more hurt allies who aren't shielded yet (it
				# was recast every turn while HP stayed under 75%).
				var low := _standing(party).filter(func(m): return hurt.call(m) < 0.75 and m.shield <= 0).size()
				if low >= 2:
					pick = "Shielding"
				elif controlled != null and not controlled.is_down and controlled != fighter \
						and not controlled.statuses.has("haste"):
					# Nobody needs healing: speed up the fighter you steer.
					pick = "Haste"
					target = controlled
		"knight":
			if hurt.call(fighter) < 0.4:
				pick = "Light Heal"
			elif threatened and not fighter.statuses.has("brace"):
				pick = "Brace"
		"mage":
			if threatened and not fighter.statuses.has("arcane_barrier"):
				pick = "Arcane Barrier"
			elif not _enchant_running() and ap - _ai_skill_cost("mage", "Enchant") - reserve >= _ai_cheapest_attack("mage"):
				# Only with enough left over for a spell this turn too: an Enchant
				# that leaves her nothing to cast was her whole turn (play-tests:
				# two Enchants, two Waits, no damage of her own).
				ai_element = _ai_enchant_pick()
				pick = "Enchant" if ai_element != "" else ""
		"monk":
			if hurt.call(fighter) < 0.4:
				pick = "Deep Breath"
		"assassin":
			if hurt.call(fighter) < 0.3 and not fighter.statuses.has("vanish"):
				pick = "Vanish"
		"archer":
			# Hurt: Siphon the enemy it's fighting (her hits then heal her).
			var foe := _nearest(fighter, _standing(enemies)) if not _standing(enemies).is_empty() else null
			if hurt.call(fighter) < 0.7 and foe != null and fighter.gap_to(foe) <= 6.0 and not foe.statuses.has("siphoned"):
				pick = "Siphon Shot"
				target = foe
			# Only with AP to spare: after paying for it, it must still have
			# half its bar for this turn's attack (and keep yours).
			elif not fighter.statuses.has("agility") and ap - 60.0 - reserve >= fighter.combo_limit * 0.5:
				pick = "Agility"
	if pick == "":
		return false
	# Heals don't hold back AP for your turn: keeping someone alive comes
	# first. Can't afford Full Cure? Healing, then.
	var saving := pick not in ["Full Cure", "Healing"]
	if pick == "Full Cure" and ap < 60.0:
		pick = "Healing"
	for skill in Moves.skills(fighter.class_id):
		if skill["name"] != pick:
			continue
		if float(skill["cost"]) > ap - (reserve * 0.5 if saving else 0.0):
			if not saving:
				_count("ai_heal_no_ap")
			return false  # can't afford it without leaving you dry
		var saved_controlled := controlled
		var saved_used := _skill_used
		controlled = fighter
		var cast := skill
		if ai_element != "":
			cast = skill.duplicate()
			cast["element"] = ai_element
		_use_skill(cast, target, fighter.global_position)
		controlled = saved_controlled
		_skill_used = saved_used
		_menu_mode = BattleMenu.Mode.HIDDEN
		_count("ai_abilities")
		_count("ai_ability_" + String(skill["name"]).to_lower().replace(" ", "_"))
		return true
	return false


## A class's Ability cost by name (INF if it doesn't have it).
func _ai_skill_cost(class_id: String, skill_name: String) -> float:
	for skill in Moves.skills(class_id):
		if skill["name"] == skill_name:
			return float(skill["cost"])
	return INF


## The cheapest single attack a class has.
func _ai_cheapest_attack(class_id: String) -> float:
	var cheapest := INF
	for move in Moves.attacks(class_id):
		cheapest = minf(cheapest, float(move["cost"]))
	return cheapest


## Builds a combo for this target within the AI's budget and plays it at
## once. Returns false if it couldn't attack (nothing affordable that works).
func _ai_attack(fighter: Combatant, target: Combatant) -> bool:
	var saved_controlled := controlled
	controlled = fighter
	_open_combo_bar(target)
	var reserve := _ai_reserve(fighter)
	var want := minf(fighter.combo_limit, current_max_ap) * ai_spend_share
	var cheapest := INF
	for i in _moves.size():
		if battle_menu.move_usable[i]:
			cheapest = minf(cheapest, float(_moves[i]["cost"]))
	var budget := minf(want, ap - reserve)
	if budget < cheapest:
		# Not enough to spare: a smaller attack that still leaves you most of yours.
		budget = minf(want * 0.5, ap - reserve * 0.5)
	budget = minf(budget, fighter.combo_limit)
	_ai_building = true
	for index in _ai_choose_moves(fighter, target, budget):
		_add_to_combo(index)
	_ai_building = false
	var played := false
	if not _plan.is_empty():
		_ai_play_plan(fighter, target)
		_spend_focus(fighter)
		played = true
	elif budget < cheapest:
		_count("ai_no_ap")  # it would have attacked, but the party's AP was spent
		_count("ai_no_ap_" + fighter.class_id)
	controlled = saved_controlled
	_menu_mode = BattleMenu.Mode.HIDDEN
	battle_menu.combo.clear()
	_plan.clear()
	battle_menu.plan = _plan
	_combo_target = null
	return played


## Greedy pick: the best damage per AP among single moves and the Arts it
## knows, weighed by how they answer the target (a Defense stance needs a
## breaking or piercing move first, a tough Gust Sprite needs a push).
func _ai_choose_moves(fighter: Combatant, target: Combatant, budget: float) -> Array:
	var options: Array = []  # [move indices, cost, move dict]
	for i in _moves.size():
		if battle_menu.move_usable[i]:
			options.append([[i], float(_moves[i]["cost"]), _moves[i]])
	for art in Moves.arts(fighter.class_id):
		if art.has("needs_token") and not fighter.tokens.has(art["needs_token"]):
			continue
		if int(art.get("needs_marks", 0)) > target.marks:
			continue
		var indices: Array = []
		var cost := 0.0
		for move_name in art["recipe"]:
			var index := -1
			for i in _moves.size():
				if _moves[i]["name"] == move_name and battle_menu.move_usable[i]:
					index = i
			if index < 0:
				indices.clear()
				break
			indices.append(index)
			cost += float(_moves[index]["cost"])
		if not indices.is_empty():
			options.append([indices, cost, art])
	var chosen: Array = []
	var left := budget
	var guard_down := target.stance != Skills.Kind.DEFENSE
	for _round in 8:
		var best: Array = []
		var best_score := 0.0
		for option in options:
			if float(option[1]) > left or float(option[1]) <= 0.0:
				continue
			var value := _ai_value(option[2], target, guard_down)
			if value <= 0.0:
				continue
			var score := value / float(option[1])
			if score > best_score:
				best_score = score
				best = option
		if best.is_empty():
			break
		chosen.append_array(best[0])
		left -= float(best[1])
		var move: Dictionary = best[2]
		if int(move.get("effect", Moves.Effect.NONE)) == Moves.Effect.BREAK:
			guard_down = true
	return chosen


## How much a move is worth against this target right now.
func _ai_value(move: Dictionary, target: Combatant, guard_down: bool) -> float:
	var value := 0.0
	for h in move.get("hits", []):
		value += float(h)
	var effect := int(move.get("effect", Moves.Effect.NONE))
	var last: Dictionary = move.get("last_hit", {})
	var pierces := effect == Moves.Effect.PIERCE or int(last.get("effect", Moves.Effect.NONE)) == Moves.Effect.PIERCE
	if not guard_down and effect != Moves.Effect.BREAK and not pierces:
		return 0.0  # blocked by the Defense stance
	if target.damage_taken_share < 0.5:
		# Real pushes send it furthest; on a Lightweight one any hit pushes a little.
		return value * (3.0 if float(move.get("knockback", 0.0)) > 0.0 else (1.0 if target.lightweight else 0.1))
	var answer := _move_answer(move, target)
	if not answer.is_empty():
		match int(answer[1]):
			Answer.GOOD:
				value *= 1.5
			Answer.BAD:
				return 0.0
	if move.has("recipe") and Moves.arts("mage").any(func(a): return a["name"] == move["name"]):
		value = _ai_mage_value(move, target, value)
	return value


## The AI Mage plays her setups: areas by how many they hit, Flare on burning
## enemies, Shatter on the Frozen, Overcharge on an immune boss cast.
func _ai_mage_value(move: Dictionary, target: Combatant, value: float) -> float:
	var near := func(radius: float) -> int:
		return _standing(enemies).filter(func(e): return e.global_position.distance_to(target.global_position) <= radius + e.body_radius).size()
	match int(move.get("area", Moves.Area.SINGLE)):
		Moves.Area.TARGET_CIRCLE:
			value *= float(near.call(float(move["area_size"])))
		Moves.Area.ALL:
			value *= float(_standing(enemies).size())
	if int(move.get("chain", 0)) > 0:
		value *= 1.0 + float(move.get("chain_share", 0.75)) * mini(int(move["chain"]), near.call(float(move.get("chain_range", 5.0))) - 1)
	if move.get("detonate_burns", false):
		for e in _standing(enemies):
			if e.burn_turns > 0:
				value += float(e.burn_damage * maxi(e.burn_stacks, 1) * e.burn_turns) / maxf(_exec_attacker.attack_power if _exec_attacker else 10.0, 1.0)
	if move.has("shatter"):
		var shares: Array = move["shatter"]
		value *= float(shares[0]) if target.statuses.has("frozen") else (float(shares[1]) if target.statuses.has("chilled") else float(shares[2]))
	if move.has("delayed_blast"):
		value += float(move["delayed_blast"]["hit"]) * 0.7 * near.call(float(move["delayed_blast"]["radius"]))
	if move.get("ignore_cancel_lock", false) and _loaded_offensive(target) and _cancel_resisted(target) == "IMMUNE":
		value *= 2.0
	if (float(move.get("deep_freeze", 0.0)) > 0.0 or float(move.get("stasis", 0.0)) > 0.0) and _loaded_offensive(target):
		value *= 1.5
	return value


## Plays the planned combo at once: every hit lands in order (no timing,
## so no Perfect bonus), with the same effects as a played combo.
func _ai_play_plan(fighter: Combatant, target: Combatant) -> void:
	var hp_before := 0
	for enemy in enemies:
		hp_before += enemy.hp
	_exec_attacker = fighter
	_ai_playing = true
	_pay(fighter, battle_menu.combo_cost())
	_note_ice_carry(fighter)
	fighter.statuses.erase("arcane_cost")
	if fighter.statuses.has("vanish"):
		fighter.statuses.erase("vanish")
		_popup(fighter, "REVEALED", Color(0.7, 0.7, 0.8))
	_count("combos")
	_count("combos_" + fighter.class_id)
	_count("ai_attacks")
	_count("ai_attacks_" + fighter.class_id)
	fighter.face_toward(target.global_position - fighter.global_position, 1.0, 100000.0)
	var names: PackedStringArray = []
	var timed_hits := 0
	for slot in _plan.size():
		var entry := _plan[slot]
		var move: Dictionary = entry["move"]
		if move.has("recipe") and not ArtsBook.known(fighter.class_id, move["name"]):
			# Not found yet: it works, but stays nameless (no spoilers in
			# messages or popups), and it isn't added to the Arts list.
			move = move.duplicate()
			move["name"] = "hidden Art"
			_count("ai_hidden_arts")
		names.append(String(move["name"]))
		_exec_slot = slot
		_exec_hits_done = 0
		_exec_timings.clear()
		_exec_timings.resize((entry["hits"] as Array).size())
		_exec_timings.fill(Timing.NONE)
		_exec_tokens = _token_plan(fighter, move)
		if move.has("recipe"):
			_count("arts")
			_count("art_" + String(entry["move"]["name"]).to_lower().replace(" ", "_").replace("'", ""))
			if int(move.get("spend_marks", 0)) > 0 and _combo_target != null and _combo_target.marks > 0:
				_combo_target.set_marks(_combo_target.marks - int(move["spend_marks"]))
		var hits: Array = entry["hits"]
		var stop := false
		for i in hits.size():
			var multiplier := float(hits[i]) * (1.0 + float(_exec_tokens.get("bonus", 0.0))) * ai_damage_mult
			var hit_move := move
			if move.has("last_hit") and i == hits.size() - 1:
				hit_move = move.duplicate()
				hit_move.merge(move["last_hit"], true)
			if not _untimed(entry, i):
				timed_hits += 1
			fighter.play_lunge(entry["move"], i, target, true)
			_chase(fighter, target, entry["move"], 0.35 * hits.size() + 0.5)  # the queued swings play after
			var keep_going := _land_hit(fighter, hit_move, multiplier, i == 0, i == hits.size() - 1)
			_exec_hits_done = i + 1
			if i == hits.size() - 1 and not fighter.is_down:
				_settle_tokens()
			if not keep_going or _game_over:
				stop = true
				break
		if stop:
			break
	var dealt := hp_before
	for enemy in enemies:
		dealt -= enemy.hp
	var gain := ai_max_ap_per_hit * timed_hits
	if gain > 0.0 and not _game_over:
		_grow_max_ap(gain, fighter)
	_flash("%s: %s on %s (%d damage)" % [fighter.display_name, " + ".join(names), target.display_name, dealt], 3.0)
	_exec_attacker = null
	_ai_playing = false


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
		controlled.step(_camera_relative(input), delta)
		_walk_inside(controlled)
	_tick_blasts(world_delta)
	for enemy in enemies:
		if enemy.skill_revealed and enemy.loaded_skill != Skills.NONE:
			enemy.set_meta("revealed_for", float(enemy.get_meta("revealed_for", 0.0)) + world_delta)
		_enemy_step(enemy, world_delta)
	for ally in party:
		if ally != controlled and not ally.is_down:
			_ally_step(ally, world_delta)
	_resolve_overlaps()
	_world_moved = true


## Holding Tab long enough (between turns) opens the picker.
func _check_steer_hold() -> void:
	if _tab_down_ms < 0:
		return
	if not Input.is_action_pressed("swap_character"):
		_tab_down_ms = -1  # let go somewhere the release event didn't reach
		return
	if Time.get_ticks_msec() - _tab_down_ms >= steer_hold_seconds * 1000.0 and _standing(party).size() >= 2:
		_open_steer_picker()


func _open_steer_picker() -> void:
	_tab_down_ms = -1
	_picker_open = true
	steer_picker.selected = controlled
	steer_picker.visible = true


func _close_steer_picker() -> void:
	_picker_open = false
	steer_picker.visible = false


## Picker open: A/D (arrows, wheel) move the pick, 1-6 jump to one, letting
## go of Tab steers whoever is picked. The camera follows the pick.
func _picker_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_released("swap_character"):
		get_viewport().set_input_as_handled()
		_close_steer_picker()
		return
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = 1
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
		var index := int(event.physical_keycode - KEY_1)
		if index < party.size() and not party[index].is_down:
			_pick_to_steer(party[index])
		get_viewport().set_input_as_handled()
		return
	if step == 0:
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()  # nothing else happens while choosing
		return
	get_viewport().set_input_as_handled()
	var index := party.find(steer_picker.selected)
	for i in party.size():
		index = posmod(index + step, party.size())
		if not party[index].is_down:
			_pick_to_steer(party[index])
			return


func _pick_to_steer(member: Combatant) -> void:
	steer_picker.selected = member
	if member != controlled:
		_set_controlled(member)
		_begin_pan()


## Tab (between turns): steer the next standing party member.
func _cycle_control() -> void:
	var standing := _standing(party)
	if standing.size() < 2:
		return
	var index := standing.find(controlled)
	_set_controlled(standing[(index + 1) % standing.size()])
	_begin_pan()


func _set_controlled(fighter: Combatant) -> void:
	if controlled != null:
		controlled.set_highlighted(false)
	controlled = fighter
	controlled.set_highlighted(true)


## How fast a skill turns in its last second (0: the enemy's slow default).
func _final_turn_speed(def: EnemySkill) -> float:
	if def == null:
		return 0.0
	if def.final_turn_speed > 0.0:
		return def.final_turn_speed
	if def.shape == EnemySkill.Shape.LINE and (def.kind == Skills.Kind.ATTACK or def.kind == Skills.Kind.SMASH) \
			and not def.is_mechanic() and not def.placed_on_party() and not def.snaps_to_target:
		return line_final_turn_speed
	return 0.0


## Crush: a random party member who isn't close, unless Taunt holds it.
func _far_target(enemy: Combatant) -> Combatant:
	if enemy.statuses.has("taunt"):
		return null
	var seen := _standing(party).filter(func(m): return not m.statuses.has("vanish"))
	var far := seen.filter(func(m): return enemy.global_position.distance_to(m.global_position) > far_target_min_distance)
	return far.pick_random() if not far.is_empty() else null


## A short cone or line (regular Attack / Smash) whose locked target is in melee
## range: it tracks it to the end (see melee_track_turn_speed).
func _melee_tracking(enemy: Combatant, target: Combatant) -> bool:
	var def := enemy.loaded_def
	if def == null or target == null or target.is_down:
		return false
	if def.kind != Skills.Kind.ATTACK and def.kind != Skills.Kind.SMASH:
		return false
	if def.radius > melee_track_radius:
		return false
	var cone := def.shape == EnemySkill.Shape.CONE and def.angle < 180.0
	var circle := def.shape == EnemySkill.Shape.CIRCLE  # around itself (Rock Stomp): it steps after you
	if not cone and not circle and def.shape != EnemySkill.Shape.LINE:
		return false
	if def.is_mechanic() or def.placed_on_party() or def.aims_exactly() or enemy.get_meta("aim_locked", false):
		return false  # snapped skills (Shield Bash) hold their aim
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	return to.length() - target.body_radius <= def.radius + melee_track_margin


## Backing off to the edge of its reach doesn't save you: the enemy steps
## after you while it winds up (not if pinned or rooted).
func _melee_chase(enemy: Combatant, target: Combatant, delta: float) -> void:
	if enemy.statuses.has("pinned") or enemy.freeze_left > 0.0:
		return
	var to := target.global_position - enemy.global_position
	to.y = 0.0
	if to.length() - target.body_radius <= enemy.loaded_def.radius * melee_chase_share:
		return
	var walk := enemy.move_speed * (0.5 if enemy.statuses.has("chilled") else 1.0)
	enemy.global_position += arena.steer(enemy.global_position, to, enemy.body_radius).normalized() * walk * delta
	_keep_in_arena(enemy)


## Enemy behavior: turn toward the nearest party member and walk forward.
## Enemies only walk when roughly facing their target, so a slow-turning
## enemy can be outmaneuvered. While preparing a skill they stand still and
## can only turn slowly.
func _enemy_step(enemy: Combatant, delta: float) -> void:
	if enemy.anchored:
		return  # a wall boss never moves
	if enemy.statuses.has("frozen") and enemy.freeze_left > 0.0:
		return  # Ice Spear: frozen solid
	var target := _enemy_target(enemy)
	if target == null:
		return
	if enemy.hold:
		var to := target.global_position - enemy.global_position
		enemy.face_toward(to, delta, enemy.cast_turn_speed_degrees)
		return
	var to_target := target.global_position - enemy.global_position
	to_target.y = 0.0
	if enemy.is_down:
		return
	if enemy.loaded_skill != Skills.NONE or enemy.stance != Skills.NONE:
		# Preparing a skill: stand still and track the party member it locked
		# onto at full speed, slowing down only near the end of the cast.
		# A stance held after its turn just turns slowly.
		var locked := target
		if enemy.cast_target != null and not enemy.cast_target.is_down and not enemy.statuses.has("taunt"):
			locked = enemy.cast_target
		var to_locked := locked.global_position - enemy.global_position
		var turn_speed := enemy.cast_turn_speed_degrees
		if enemy.loaded_skill != Skills.NONE and _seconds_until_turn(enemy) > cast_slow_seconds:
			turn_speed = enemy.turn_speed_degrees
		elif enemy.loaded_skill != Skills.NONE:
			turn_speed = maxf(turn_speed, _final_turn_speed(enemy.loaded_def))  # lines keep tracking
		if enemy.loaded_skill != Skills.NONE and _melee_tracking(enemy, locked):
			# Up close, a short cone keeps up: no sidestepping out of it.
			turn_speed = maxf(turn_speed, melee_track_turn_speed)
			_melee_chase(enemy, locked, delta)
		if enemy.loaded_def != null and enemy.loaded_def.aims_exactly() and enemy.loaded_skill != Skills.NONE:
			enemy.face_toward(to_locked, 1.0, 1000000.0)  # locked on exactly (Breath)
		elif not enemy.get_meta("aim_locked", false):  # snapped skills hold their aim
			enemy.face_toward(to_locked, delta, turn_speed)
		return
	var stop_distance := enemy.body_radius + target.body_radius + enemy.preferred_gap
	var wants_closer := to_target.length() > stop_distance or not _can_see(enemy, target)
	# Walk around rocks and pits on the way.
	var heading := arena.steer(enemy.global_position, to_target, enemy.body_radius) if wants_closer else to_target
	# Partners (team_tactics) fan out so the party can't stand safe from both.
	var spread := _tactics_spread(enemy)
	if spread != Vector3.ZERO:
		heading = (heading.normalized() * (1.0 if wants_closer else 0.0) + spread * 1.5)
		wants_closer = true
	enemy.face_toward(heading, delta)
	var facing_target := enemy.flat_forward().angle_to(heading) < deg_to_rad(45.0)
	if enemy.statuses.has("pinned"):
		return  # Arrow Rain: it can turn, but not walk
	if wants_closer and facing_target:
		var walk := enemy.move_speed * (0.5 if enemy.statuses.has("chilled") else 1.0)  # Frost
		if enemy.closes_in and not _reaches_anyone(enemy):
			walk *= enemy.close_in_speed  # the Dragon: nothing reaches, so it hurries in
		enemy.global_position += enemy.flat_forward() * walk * delta
		_keep_in_arena(enemy)


## Slow casts (Shadowflare, Breath) and fast bosses (cast_zone_speed) move
## through the casting zone at a share of the enemy's speed.
## Cleric's Haste: a hasted fighter moves along the timeline faster.
func _haste(fighter: Combatant) -> float:
	return 1.0 + haste_timeline_bonus if fighter.statuses.has("haste") else 1.0


func _cast_speed(fighter: Combatant) -> float:
	var bait := _bait_speed(fighter)
	if bait >= 0.0:
		return bait
	if fighter.loaded_def != null and fighter.loaded_skill != Skills.NONE and fighter.timeline_pos >= cast_zone_start:
		if fighter.has_meta("settle_speed"):
			return float(fighter.get_meta("settle_speed"))  # a growing circle that stopped: the run-out window
		return fighter.loaded_def.cast_speed * fighter.cast_zone_speed * _stagger_slow(fighter.loaded_def) \
				* float(fighter.get_meta("follow_up_slow", 1.0))  # a long follow-up delay on a fast boss
	return 1.0


func _stagger_slow(def: EnemySkill) -> float:
	return stagger_cast_speed if def.stagger_bar > 0 else 1.0


## Real seconds until a fighter reaches the end of the timeline.
func _seconds_until_turn(fighter: Combatant) -> float:
	var rate := fighter.speed * time_scale * battle_speed * _cast_speed(fighter) * _haste(fighter)
	return maxf(TIMELINE_LENGTH - fighter.timeline_pos, 0.0) / rate if rate > 0.0 else INF


## Who an enemy goes after: whoever taunted it, otherwise the nearest.
func _enemy_target(enemy: Combatant) -> Combatant:
	if enemy.statuses.has("taunt"):
		var taunter: Combatant = enemy.statuses["taunt"]["caster"]
		if taunter != null and not taunter.is_down:
			return taunter
	# Vanish: enemies lose track of a hidden Assassin while anyone else stands.
	var seen := _standing(party).filter(func(m): return not m.statuses.has("vanish"))
	var pool: Array[Combatant] = seen if not seen.is_empty() else _standing(party)
	if enemy.boss:
		var by_threat := _threat_target(enemy, pool)
		if by_threat != null:
			return by_threat
	return _nearest(enemy, pool)


## Boss threat: whoever hurt it most lately, weighed against distance (see
## threat_distance_scale). Null while nobody has hurt it yet.
func _threat_target(enemy: Combatant, pool: Array[Combatant]) -> Combatant:
	var threat: Dictionary = enemy.get_meta("threat", {})
	var top := 0.0
	for member in pool:
		top = maxf(top, float(threat.get(member, 0.0)))
	if top <= 0.0:
		return null
	var best: Combatant = null
	var best_score := -INF
	for member in pool:
		var score := float(threat.get(member, 0.0)) / top \
				- enemy.global_position.distance_to(member.global_position) / threat_distance_scale
		if score > best_score:
			best_score = score
			best = member
	return best


func _add_threat(enemy: Combatant, attacker: Combatant, amount: int) -> void:
	if not enemy.boss or attacker == null or attacker.team != Combatant.Team.PARTY or amount <= 0:
		return
	var threat: Dictionary = enemy.get_meta("threat", {})
	threat[attacker] = float(threat.get(attacker, 0.0)) + amount
	enemy.set_meta("threat", threat)


func _decay_threat(enemy: Combatant) -> void:
	var threat: Dictionary = enemy.get_meta("threat", {})
	for member in threat.keys():
		threat[member] = float(threat[member]) * threat_decay


## Ally AI, in priority order:
##   1. Stack up: for a revealed shared-damage skill (Breath), gather on the
##      party member it's aimed at, so the damage is split.
##   2. Stay out of danger: leave any enemy area that could hit, never walk
##      into one. A circle or line that follows this ally while hidden can't
##      be outrun, so it's ignored until revealed; circles that punish
##      overlaps keep allies a full circle apart (spread out).
##   3. Stand near the edge of its own attack range from its focus enemy
##      (ally_range_share of its reach): a healer mid-ritual first (close
##      enough to interrupt it), then a growing circle's caster (so it gets
##      contained), otherwise the nearest enemy.
func _ally_step(ally: Combatant, delta: float) -> void:
	var dangers := _ally_dangers(ally)
	# Doom Gaze first: hiding beats everything, a Windup approach included
	# (its turn waits in cover, then it walks in once the gaze is over).
	var hide_at: Variant = _hide_point(ally)
	if hide_at != null:
		var target: Vector3 = hide_at
		if not arena.has_line_of_sight(ally.global_position, target):
			target = _around_rock(ally, target)  # the rock is in the way: go round its side first
		var to_hide: Vector3 = target - ally.global_position
		to_hide.y = 0.0
		if to_hide.length() > 0.25:
			ally.step(arena.steer(ally.global_position, to_hide, ally.body_radius), delta)
			_keep_in_arena(ally)
		return
	if _keep_off_ledge(ally, delta, dangers):
		return
	if ally.has_meta("windup_target"):
		_retarget_to_sprite(ally)
		# Windup: head for the chosen enemy until it's in reach.
		var goal: Combatant = ally.get_meta("windup_target")
		if is_instance_valid(goal) and not goal.is_down and goal.lightweight \
				and _line_up_push(ally, goal, delta, dangers):
			return  # a Gust Sprite: get on its far side from the drop first
		if is_instance_valid(goal) and not goal.is_down and not _windup_reaches(ally, goal):
			# Out of anything about to hit first (a falling rock landing on
			# its path), then on towards the target.
			if _escape_step(ally, dangers, delta):
				return
			var dest := goal.global_position
			if not arena.has_line_of_sight(ally.global_position, dest):
				# A rock between them (Ceiling Burst): go round its side first,
				# or a ranged ally stays in range with no clear shot.
				dest = _around_rock(ally, dest)
			var to_goal := dest - ally.global_position
			to_goal.y = 0.0
			if to_goal.length() < 0.3:
				to_goal = goal.global_position - ally.global_position
				to_goal.y = 0.0
			_safe_step(ally, to_goal, delta, dangers)
			return
	var stack_at: Variant = _stack_point(ally)
	if stack_at != null:
		var to_stack: Vector3 = stack_at - ally.global_position
		to_stack.y = 0.0
		if to_stack.length() > ally.body_radius + 0.9:
			_safe_step(ally, to_stack, delta, dangers)
		return

	if _escape_step(ally, dangers, delta):
		return

	var threat := _ally_focus(ally)
	if threat == null:
		return
	# Positioning (not attacking): grey areas still being cast aren't walked
	# into either, the way a person keeps out of a shape on the floor before
	# knowing what it is. They aren't fled before the reveal.
	if ally_avoid_grey:
		dangers = dangers + _grey_areas(ally)
	var to_threat := threat.global_position - ally.global_position
	if threat.lightweight and _line_up_push(ally, threat, delta, dangers):
		return
	if ally.flanks and not threat.no_positionals:
		# Assassin: circle round to the enemy's back, within striking reach.
		var spot := threat.global_position - threat.flat_forward() * (threat.body_radius + ally.body_radius + ally.reach() * 0.6)
		var to_spot := spot - ally.global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.35:
			if to_spot.length() > 1.5 and not threat.is_behind(ally.global_position):
				# Go round the side rather than straight through the front.
				var side := to_threat.cross(Vector3.UP).normalized()
				if side.dot(to_spot) < 0.0:
					side = -side
				to_spot = to_spot.normalized() + side * 0.8
			if _safe_step(ally, to_spot, delta, dangers):
				return
		ally.face_toward(to_threat, delta)
		return
	var gap := ally.gap_to(threat)
	var ideal := ally.reach() * ally_range_share
	var ritual := threat.loaded_def
	if ritual != null and ritual.special == EnemySkill.Special.HEAL_ALLIES:
		ideal = minf(ideal, ritual.interrupt_range * 0.8)  # close enough that hits interrupt it
	var far_enough := ideal - 1.0
	if ally.focus_max > 0:
		# Mage: stands still to build Focus. She only walks when the enemy is
		# out of her reach, or right on top of her.
		ideal = ally.reach() * 0.95 - 0.15
		far_enough = minf(1.5, ideal)
	if ally_fragile_flank and _fragile(ally) and threat.boss:
		# Mage / Cleric against a boss: the edge of their reach, off its front.
		ideal = ally.reach() * 0.95 - 0.15
		far_enough = maxf(far_enough, ideal - 0.6)
		if _flank_step(ally, threat, ideal, delta, dangers):
			return
	if gap > ideal + 0.15:
		if _safe_step(ally, to_threat, delta, dangers):
			return
	elif gap < far_enough:
		if _safe_step(ally, -to_threat, delta, dangers):
			return
	ally.face_toward(to_threat, delta)


## Lightweight targets (Gust Sprites): the AI gets on the far side of it
## from the nearest drop, so its hit knocks it toward the drop. Walks round
## the side rather than through it. Returns true while still walking.
func _line_up_push(ally: Combatant, target: Combatant, delta: float, dangers: Array[Dictionary]) -> bool:
	var toward_drop := _drop_direction(target.global_position)
	if toward_drop == Vector3.ZERO:
		return false
	var back_off := minf(ally.reach() * 0.6, 2.0)
	var spot := target.global_position - toward_drop * (target.body_radius + ally.body_radius + back_off)
	var to_spot := spot - ally.global_position
	to_spot.y = 0.0
	if to_spot.length() <= 0.4:
		ally.face_toward(target.global_position - ally.global_position, delta)
		return false  # lined up
	var to_target := target.global_position - ally.global_position
	to_target.y = 0.0
	if to_spot.length() > 1.2 and to_target.normalized().dot(toward_drop) < 0.3:
		# On the drop side of it: go round, not through it.
		var side := to_target.cross(Vector3.UP).normalized()
		if side.dot(to_spot) < 0.0:
			side = -side
		to_spot = to_spot.normalized() + side * 0.8
	return _safe_step(ally, to_spot, delta, dangers)


## Mage and Cleric: little HP and no Parry, so they keep their distance.
func _fragile(ally: Combatant) -> bool:
	return ally.class_id == "mage" or ally.class_id == "cleric"


## A fragile ally in front of a boss steps round to fragile_flank_degrees
## off its facing, at the given gap. Not when the boss is locked on to it
## anyway (it would just turn after her), nor against wall bosses (no sides).
## Returns true while walking.
func _flank_step(ally: Combatant, boss: Combatant, gap: float, delta: float, dangers: Array[Dictionary]) -> bool:
	if boss.no_positionals or boss.cast_target == ally:
		return false
	var fwd := boss.flat_forward()
	var off := ally.global_position - boss.global_position
	off.y = 0.0
	if off.length() < 0.05 or fwd.angle_to(off.normalized()) >= deg_to_rad(fragile_flank_degrees - 15.0):
		return false  # already off its front
	var side := 1.0 if fwd.cross(off).y >= 0.0 else -1.0
	var dir := fwd.rotated(Vector3.UP, side * deg_to_rad(fragile_flank_degrees))
	var spot := boss.global_position + dir * (boss.body_radius + ally.body_radius + gap)
	if not arena.walkable(spot, ally.body_radius):
		dir = fwd.rotated(Vector3.UP, -side * deg_to_rad(fragile_flank_degrees))
		spot = boss.global_position + dir * (boss.body_radius + ally.body_radius + gap)
		if not arena.walkable(spot, ally.body_radius):
			return false
	var to_spot := spot - ally.global_position
	to_spot.y = 0.0
	if to_spot.length() < 0.4:
		return false
	return _safe_step(ally, to_spot, delta, dangers)


## Enemy areas still grey (or just revealed, before the ally reacts) that
## the ally stands outside: positioning steps don't walk into them. One the
## ally already stands in is left out (no fleeing before the reveal; Golem
## Smash's grey covers the whole room).
func _grey_areas(ally: Combatant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var margin := ally.body_radius + ally_danger_margin
	for enemy in enemies:
		if not _is_danger(enemy) or _ally_reacted(enemy):
			continue
		var special := enemy.loaded_def.special
		if special == EnemySkill.Special.HEAL_ALLIES or special == EnemySkill.Special.GROWING:
			continue  # a ritual to break, a Shadowflare's sprites to reach: go in
		for area in _enemy_areas(enemy):
			if area.has_meta("follow") and area.get_meta("follow") == ally:
				continue
			if not area.contains(ally.global_position, margin):
				list.append({"area": area, "margin": margin})
	return list


## An AI ally backing off a drop goes this much further than it has to.
@export var ledge_hysteresis: float = 0.6
## How close an AI ally walking in to attack may get to a drop when no push
## is coming.
@export var ally_ledge_close: float = 0.4


## How far an AI ally keeps from a lethal edge or hole right now: at least
## ally_ledge_min; while an enemy prepares a push (grey or revealed), that
## push plus ally_ledge_margin.
func _ledge_buffer() -> float:
	var buffer := ally_ledge_min
	for enemy in _standing(enemies):
		var def := enemy.loaded_def
		if def == null or enemy.loaded_skill == Skills.NONE:
			continue
		var push := def.launch
		if def.follow_up != null:
			push = maxf(push, def.follow_up.launch)
		if push > 0.0:
			buffer = maxf(buffer, push + ally_ledge_margin)
	return buffer


## Too close to a drop for what's coming: one step away from it (around
## danger areas). Returns true while stepping.
func _keep_off_ledge(ally: Combatant, delta: float, dangers: Array[Dictionary]) -> bool:
	var drop := _nearest_drop(ally.global_position)
	# Once backing off, it keeps going a little past the buffer before it
	# stops: stopping right on the line, it walked straight back over it
	# and stepped off again, over and over (a jittery shuffle).
	var buffer := _ledge_buffer()
	if ally.has_meta("windup_target") and buffer <= ally_ledge_min:
		# Walking in to attack with no push coming: it may go right up to the
		# edge (walkers steer round drops), or with its target standing by
		# one it would walk in, back off, walk in... and never get there.
		buffer = ally_ledge_close
	if ally.get_meta("ledge_stepping", false):
		buffer += ledge_hysteresis
	if drop.is_empty() or float(drop[1]) - ally.body_radius >= buffer:
		ally.set_meta("ledge_stepping", false)
		return false
	var away: Vector3 = -drop[0]
	if not _safe_step(ally, away, delta, dangers):
		return false  # boxed in: the danger areas come first
	if not ally.get_meta("ledge_stepping", false):
		_count("ai_ledge_steps")  # once per time it backs off, not per frame
	ally.set_meta("ledge_stepping", true)
	return true


## Which way the nearest drop (a lethal edge or a hole) lies from a point;
## ZERO with none in the arena.
func _drop_direction(point: Vector3) -> Vector3:
	var drop := _nearest_drop(point)
	return Vector3.ZERO if drop.is_empty() else drop[0]


## [direction, distance] to the nearest drop (a lethal edge or a hole), or
## [] with none in the arena.
func _nearest_drop(point: Vector3) -> Array:
	var best := Vector3.ZERO
	var best_d := INF
	var b: Array = arena._bounds()
	var p := point - arena.global_position
	var sides := [[Arena.SIDE_NORTH, Vector3(0, 0, -1), p.z - float(b[2])], [Arena.SIDE_SOUTH, Vector3(0, 0, 1), float(b[3]) - p.z],
			[Arena.SIDE_WEST, Vector3(-1, 0, 0), p.x - float(b[0])], [Arena.SIDE_EAST, Vector3(1, 0, 0), float(b[1]) - p.x]]
	if arena.shape == Arena.Shape.RECTANGLE:
		for side in sides:
			if arena.lethal_sides & int(side[0]) and float(side[2]) < best_d:
				best_d = float(side[2])
				best = side[1]
	elif arena.lethal_rim and Vector2(p.x, p.z).length() > 0.01:
		best_d = arena.size.x / 2.0 - Vector2(p.x, p.z).length()
		best = Vector3(p.x, 0.0, p.z).normalized()
	for obstacle in arena.obstacles():
		if not obstacle.is_lethal():
			continue
		var off := obstacle.global_position - point
		off.y = 0.0
		var d := off.length() - obstacle.radius
		if d < best_d and off.length() > 0.01:
			best_d = d
			best = off.normalized()
	return [] if best == Vector3.ZERO else [best, best_d]


## If the ally stands in danger, takes one step out of it and returns true.
## It looks for the shortest clear way out: fallen rocks and the arena's edge
## block some directions, and other areas mustn't be walked into on the way
## (before, it pushed straight away from the area's centre, and a rock in
## the way kept it stuck inside).
func _escape_step(ally: Combatant, dangers: Array[Dictionary], delta: float) -> bool:
	var away := _danger_escape(ally, dangers)
	if away == Vector3.ZERO:
		return false
	var best := away.normalized()
	var best_score := INF
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var reach := 0.0
		var clear := false
		var dist := 0.4
		while dist <= ESCAPE_LOOK:
			var at := ally.global_position + dir * dist
			if not arena.walkable(at, ally.body_radius) or _body_in_way(ally, at):
				break
			if not _in_danger(at, dangers):
				clear = true
				reach = dist
				break
			dist += 0.4
		if not clear:
			continue
		# Shortest way out wins; ties lean towards the plain "away" direction.
		var score := reach - 0.3 * dir.dot(best)
		if score < best_score:
			best_score = score
			away = dir
	ally.step(away.normalized(), delta)
	_keep_in_arena(ally)
	return true


const ESCAPE_LOOK := 5.0


## Another fighter standing where this one would be (they'd just push each
## other back: the Monk you're steering, the Golem itself).
func _body_in_way(fighter: Combatant, point: Vector3) -> bool:
	for other in combatants:
		if other == fighter or other.is_down:
			continue
		var off := point - other.global_position
		off.y = 0.0
		if off.length() < other.body_radius + fighter.body_radius:
			return true
	return false


func _in_danger(point: Vector3, dangers: Array[Dictionary]) -> bool:
	for danger in dangers:
		if (danger["area"] as AttackRange).contains(point, danger["margin"]):
			return true
	return false


## Which way out of the dangerous areas the ally stands in (ZERO if none).
func _danger_escape(ally: Combatant, dangers: Array[Dictionary]) -> Vector3:
	var away := Vector3.ZERO
	for danger in dangers:
		var area: AttackRange = danger["area"]
		if area.contains(ally.global_position, danger["margin"]):
			var from_area := ally.global_position - area.global_position
			from_area.y = 0.0
			var out := from_area.normalized() if from_area.length() > 0.05 else Vector3.RIGHT
			if area.shape == EnemySkill.Shape.CONE and area.angle_degrees >= 150.0 and area.angle_degrees < 360.0:
				# Half the room (Golem Smash): away from its center stays inside;
				# the way out is towards its back edge.
				var forward := -area.global_basis.z
				forward.y = 0.0
				out = -forward.normalized()
			if area.shape == EnemySkill.Shape.DONUT \
					and from_area.length() - area.inner_radius < area.radius - from_area.length():
				out = -out  # a ring: its safe middle is closer than its outer edge
			if area.shape == EnemySkill.Shape.BAND:
				# A strip across the arena: sideways into a gap between lanes,
				# otherwise out through its nearer edge (toward or away from the wall).
				var fwd := -area.global_basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var right := fwd.cross(Vector3.UP)
				var depth := from_area.dot(fwd)
				if area.lanes > 1:
					var part := area.width / (2 * area.lanes - 1)
					var across := from_area.dot(right) + area.width / 2.0
					var best := INF
					# Gaps are the odd slots (the even ones when it hits the gaps).
					for k in range(0 if area.lanes_in_gaps else 1, 2 * area.lanes - 1, 2):
						var centre := (k + 0.5) * part
						if absf(centre - across) < absf(best - across):
							best = centre
					out = right * signf(best - across)
				else:
					out = -fwd if depth - area.inner_radius < area.radius - depth else fwd
			away += out
	return away


## The areas an AI ally avoids right now, each with how far to keep from it:
## [{"area": AttackRange, "margin": meters}].
func _ally_dangers(ally: Combatant) -> Array[Dictionary]:
	var base := ally.body_radius + ally_danger_margin
	var list: Array[Dictionary] = []
	for enemy in enemies:
		if not _is_danger(enemy):
			continue
		var def := enemy.loaded_def
		if def.special == EnemySkill.Special.HEAL_ALLIES:
			continue  # a healing ritual can't hurt anyone: go and break it instead
		if enemy.skill_revealed and def.shared_damage and _stack_target(enemy) != null:
			continue  # stacking in it is the answer, not running
		if not _ally_reacted(enemy):
			continue  # still grey, or just revealed: it hasn't reacted yet
		if ally.holds_ground and _melee_tracking(enemy, ally) and (def.parryable() or def.blockable()):
			continue  # Knight / Monk up close: your Parry or Defend covers it
		for area in _enemy_areas(enemy):
			var margin := base
			if area.has_meta("follow") and (not enemy.skill_revealed or def.keeps_following()):
				if area.get_meta("follow") == ally:
					continue  # it follows this ally: moving can't escape it
				if def.special == EnemySkill.Special.ON_EACH_TARGET and def.overlap != EnemySkill.Overlap.NORMAL:
					margin += area.radius  # keep my own circle from overlapping this one
			list.append({"area": area, "margin": margin})
	for hazard in _hazards:
		list.append({"area": hazard["area"], "margin": base})
	for enemy in enemies:
		for blast in enemy.get_meta("rock_blasts", []):
			if is_instance_valid(blast["area"]):
				list.append({"area": blast["area"], "margin": base})
	for fall in _falls:
		# Every circle still to fall: walking into one that lands later is
		# how allies got caught (the about-to-land ones alone weren't enough).
		list.append({"area": fall["area"], "margin": base})
	return list


## AI allies react to an enemy skill only ally_react_seconds after it's
## revealed: no more leaving the grey area before anyone knows what it is.
## Mechanic skills (spread out, stack up) and circles that punish overlaps
## still count from the start: the answer takes time to set up.
func _ally_reacted(enemy: Combatant) -> bool:
	var def := enemy.loaded_def
	if def.is_mechanic() or def.overlap != EnemySkill.Overlap.NORMAL:
		return true
	if not enemy.skill_revealed:
		return false
	var delay := ally_react_seconds
	if not def.parryable():
		delay = ally_react_unanswerable_seconds  # no Parry to answer it (Golem Smash): dodge sooner
	return float(enemy.get_meta("revealed_for", 0.0)) >= delay


## Where allies gather for a revealed shared-damage skill, or null.
func _stack_point(ally: Combatant) -> Variant:
	for enemy in enemies:
		if enemy.is_down or enemy.loaded_def == null or not enemy.skill_revealed:
			continue
		if not enemy.loaded_def.shared_damage:
			continue
		var target := _stack_target(enemy)
		if target != null and target != ally:
			return target.global_position
		if target == ally:
			return ally.global_position  # the others come to it; it holds still
	return null


## Who the party should stack on for a shared-damage skill: its locked
## target if that one is inside the area, otherwise whoever inside is
## closest to the enemy. Null if nobody is in it (then it's just avoided).
func _stack_target(enemy: Combatant) -> Combatant:
	var area := enemy.attack_range
	if area == null:
		return null
	var target := enemy.cast_target
	if target != null and not target.is_down and area.contains(target.global_position, target.body_radius):
		return target
	var best: Combatant = null
	for member in _standing(party):
		if area.contains(member.global_position, member.body_radius) \
				and (best == null or enemy.gap_to(member) < enemy.gap_to(best)):
			best = member
	return best


## The enemy an ally positions itself around: a healer mid-ritual, then the
## caster of a growing circle not yet contained, otherwise the nearest.
func _ally_focus(ally: Combatant) -> Combatant:
	var standing := _standing(enemies)
	var healers: Array[Combatant] = []
	var growers: Array[Combatant] = []
	for enemy in standing:
		var def := enemy.loaded_def
		if def == null:
			continue
		if def.special == EnemySkill.Special.HEAL_ALLIES:
			healers.append(enemy)
		elif def.special == EnemySkill.Special.GROWING and not enemy.contained:
			growers.append(enemy)
	if not healers.is_empty():
		return _nearest(ally, healers)
	var light := standing.filter(func(e): return e.lightweight)
	if not light.is_empty():
		return _nearest(ally, light)  # a Gust Sprite: push it off before it blows
	if not growers.is_empty():
		# Shadowflare: its sprites are what stops it, not the caster.
		var sprites: Array[Combatant] = []
		for grower in growers:
			for sprite in grower.get_meta("orbiters", []):
				if is_instance_valid(sprite) and not sprite.is_down:
					sprites.append(sprite)
		if not sprites.is_empty():
			# One ally per sprite: the nearest that no other ally is already
			# winding up on.
			var free: Array[Combatant] = sprites.filter(func(sp): return not _claimed_by_other(ally, sp))
			return _nearest(ally, free if not free.is_empty() else sprites)
		return _nearest(ally, growers)
	return _nearest(ally, standing)


## Another ally (not this one) is winding up to hit this target.
func _claimed_by_other(ally: Combatant, target: Combatant) -> bool:
	for member in party:
		if member != ally and not member.is_down and member.has_meta("windup_target") \
				and member.get_meta("windup_target") == target:
			return true
	return false


## Windup: Shadowflare's sprites came out after this ally chose its target
## (or its sprite was hit by someone else): it switches to a sprite nobody
## else is going for.
func _retarget_to_sprite(ally: Combatant) -> void:
	var goal: Combatant = ally.get_meta("windup_target")
	if is_instance_valid(goal) and not goal.is_down and goal.has_meta("orbit_angle"):
		return  # already on a sprite
	var focus := _ally_focus(ally)
	if focus == null or not focus.has_meta("orbit_angle") or focus == goal:
		return
	ally.set_meta("windup_target", focus)
	_count("ai_sprite_retargets")


## Takes one step toward a direction, or the closest detour (up to 90° off)
## that doesn't enter a dangerous area. Returns false if every option is unsafe.
func _safe_step(fighter: Combatant, direction: Vector3, delta: float, dangers: Array[Dictionary]) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = arena.steer(fighter.global_position, direction.normalized(), fighter.body_radius)
	for degrees in [0.0, 35.0, -35.0, 70.0, -70.0, 90.0, -90.0]:
		var dir := direction.rotated(Vector3.UP, deg_to_rad(degrees))
		var next := fighter.global_position + dir * fighter.current_move_speed() * delta
		var safe := true
		for danger in dangers:
			if (danger["area"] as AttackRange).contains(next, danger["margin"]):
				safe = false
				break
		if safe:
			fighter.step(dir, delta)
			_keep_in_arena(fighter)
			return true
	return false


## An enemy area worth avoiding: a revealed Attack/Smash, or anything still
## being prepared (allies can't know a hidden skill is harmless).
func _is_danger(enemy: Combatant) -> bool:
	if enemy.attack_range == null or enemy.is_down or enemy.loaded_def == null:
		return false
	return not enemy.skill_revealed or enemy.loaded_def.is_offensive()


## Every area an AI ally should stay out of: enemy areas being prepared or
## revealed as offensive, placed circles and lines, and fire trails.
func _danger_areas() -> Array[AttackRange]:
	var areas: Array[AttackRange] = []
	for enemy in enemies:
		if _is_danger(enemy):
			areas.append_array(_enemy_areas(enemy))
	for hazard in _hazards:
		areas.append(hazard["area"])
	return areas


## The areas a prepared skill will hit: the enemy's own area, or the circles
## and lines it placed on the party.
func _enemy_areas(enemy: Combatant) -> Array[AttackRange]:
	var areas: Array[AttackRange] = []
	if enemy.loaded_def != null and enemy.loaded_def.placed_on_party():
		areas.append_array(enemy.extra_areas)
	elif enemy.attack_range != null:
		areas.append(enemy.attack_range)
	return areas


func _loaded_offensive(enemy: Combatant) -> bool:
	return enemy.loaded_def != null and enemy.loaded_def.is_offensive()


## Preparing a strike whose area is carried by the enemy's body (moves if it
## is pushed): not placed on the party, not pinned to the arena.
func _carries_area(enemy: Combatant) -> bool:
	if not _loaded_offensive(enemy) or enemy.loaded_skill == Skills.NONE:
		return false
	var def := enemy.loaded_def
	return not def.placed_on_party() and not def.arena_aligned


## Pushes apart any two fighters standing inside each other.
## Enemies are heavy: party members get pushed, enemies don't.
func _resolve_overlaps() -> void:
	for i in combatants.size():
		for j in range(i + 1, combatants.size()):
			var a := combatants[i]
			var b := combatants[j]
			if a.is_down or b.is_down:
				continue  # knocked-out bodies don't block anyone
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
			elif a == controlled:
				b.global_position += push_dir * overlap  # allies never shove the one you steer
			elif b == controlled:
				a.global_position -= push_dir * overlap
			else:
				a.global_position -= push_dir * overlap / 2.0
				b.global_position += push_dir * overlap / 2.0
	for c in combatants:
		_keep_in_arena(c)


## Keeps a fighter inside the arena's edges and out of rocks and pits.
## forced: pushed or pulled (knockback, launch, Hook, pulls). Over a lethal
## drop, a forced move makes the fighter fall (bosses hold on); walking never
## does: walkers stop at lethal edges like at walls.
func _keep_in_arena(fighter: Combatant, forced: bool = false) -> void:
	if fighter.anchored:
		return  # set into the wall on purpose
	if forced and arena.has_drops() and _can_fall(fighter):
		# Walls and rocks still stop it; drops don't (bosses get the normal
		# clamp below, so they stop at the brink).
		arena.keep_inside(fighter, fighter.body_radius, true)
		if arena.lethal_at(fighter.global_position):
			_teeter_or_fall(fighter)
		return
	arena.keep_inside(fighter, fighter.body_radius)


## The steered fighter walks right up to a lethal edge; once its middle
## goes over, it teeters: one Parry-like save per character per fight.
func _walk_inside(fighter: Combatant) -> void:
	if not arena.has_drops():
		_keep_in_arena(fighter)
		return
	arena.keep_inside(fighter, fighter.body_radius, true)
	if not arena.lethal_at(fighter.global_position):
		return
	_teeter_or_fall(fighter)


## Bosses never fall; everyone else can (party members and regular enemies).
func _can_fall(fighter: Combatant) -> bool:
	return not fighter.is_down and not fighter.boss


## Over the edge: out of the fight. The body drops away.
func _fall(fighter: Combatant) -> void:
	if fighter.is_down:
		return
	fighter.set_meta("fell", true)
	_popup(fighter, "FELL!", Color(1.0, 0.3, 0.25))
	_count("falls")
	if fighter.team == Combatant.Team.ENEMY:
		_count("enemy_falls")
	fighter.shield = 0
	fighter.statuses.erase("arcane_barrier")
	fighter.cannot_fall = false
	if playtest:
		if fighter.team == Combatant.Team.PARTY:
			playtest.hurt(fighter, fighter.hp, "Fell off the arena")
			playtest.down(fighter)
		else:
			playtest.deal(_exec_attacker if _menu_mode == BattleMenu.Mode.EXECUTING else null, fighter.hp)
	fighter.hp = 0
	fighter._go_down()
	var drop := create_tween()
	drop.tween_property(fighter, "global_position:y", -7.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	drop.tween_callback(func(): fighter.visible = false)
	_flash("%s falls off the arena!" % fighter.display_name)
	print("%s falls off the arena" % fighter.display_name)
	if fighter.team == Combatant.Team.PARTY:
		_check_party()
	else:
		_check_enemies()


## Teetering on a lethal edge: a ring closes on the fighter; Parry as it turns
## gold to catch yourself, otherwise you fall.
func _begin_edge_save(fighter: Combatant) -> void:
	if not _edge_save.is_empty():
		if fighter != _edge_save["fighter"] and not _edge_queue.has(fighter):
			_edge_queue.append(fighter)  # pushed over together: one save at a time
		return
	var ring := _make_ring(fighter.body_radius + 0.3, 0.1, Color.WHITE)
	fighter.add_child(ring)
	_edge_save = {"fighter": fighter, "time_left": edge_save_seconds, "reacted": 0, "ring": ring}
	_popup(fighter, "WHOA!", Color(1.0, 0.75, 0.3))
	_flash(Keybinds.fill("%s is about to fall! {parry} when the ring turns gold to catch yourself" % fighter.display_name))
	for key in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(key)


func _edge_save_press() -> void:
	if int(_edge_save["reacted"]) != 0:
		return
	if float(_edge_save["time_left"]) <= edge_save_window:
		_edge_save["reacted"] = 1
	else:
		_edge_save["reacted"] = 2
		_popup(_edge_save["fighter"], "MISS", Color(1.0, 0.35, 0.3))


func _update_edge_save(delta: float) -> void:
	var fighter: Combatant = _edge_save["fighter"]
	var ring: MeshInstance3D = _edge_save["ring"]
	_edge_save["time_left"] = float(_edge_save["time_left"]) - delta
	var left: float = _edge_save["time_left"]
	var color := Color.WHITE
	match int(_edge_save["reacted"]):
		1:
			color = Color(1.0, 0.85, 0.2)
		2:
			color = Color(1.0, 0.25, 0.2)
		_:
			if left <= edge_save_window:
				color = Color(1.0, 0.85, 0.2)
	var grow := 1.0 + 2.0 * clampf(left / maxf(edge_save_seconds, 0.01), 0.0, 1.0)
	if is_instance_valid(ring):
		ring.scale = Vector3(grow, 1.0, grow)
		(ring.material_override as StandardMaterial3D).albedo_color = color
	if left > 0.0:
		return
	var saved := int(_edge_save["reacted"]) == 1
	_edge_save = {}
	if is_instance_valid(ring):
		ring.queue_free()
	if saved:
		var back := arena.inward(fighter.global_position)
		fighter.global_position += back * (fighter.body_radius + 0.8)
		arena.keep_inside(fighter, fighter.body_radius)
		_popup(fighter, "SAVED!", Color(0.5, 1.0, 0.55))
		fighter.add_status("off_balance", off_balance_turns, fighter)
		_flash("%s catches themselves at the edge: Off-Balance for %d turns (another drop now is a fall)" % [fighter.display_name, off_balance_turns])
		_count("edge_saves")
	else:
		_fall(fighter)
	while not _edge_queue.is_empty() and _edge_save.is_empty():
		var next: Combatant = _edge_queue.pop_front()
		if is_instance_valid(next) and not next.is_down and arena.lethal_at(next.global_position):
			_begin_edge_save(next)


## An area skill reaches someone inside it unless a rock is in the way. A
## wall boss's breath runs straight across the arena, so the rock has to be
## between you and the wall straight ahead (that's where it shelters you).
func _strike_reaches(enemy: Combatant, member: Combatant) -> bool:
	if not enemy.anchored:
		return _can_see(enemy, member)
	var fwd := enemy.flat_forward()
	var depth := (member.global_position - enemy.global_position).dot(fwd)
	var at_wall := member.global_position - fwd * depth
	return arena.has_line_of_sight(at_wall, member.global_position)


## True if nothing (a rock) stands between two fighters.
func _can_see(a: Combatant, b: Combatant) -> bool:
	return arena.has_line_of_sight(a.global_position, b.global_position)


# --- Enemy skills ---------------------------------------------------------

## An enemy entered the casting zone: it starts preparing a skill, but
## you only see that it's preparing something, not what.
## Defense and Counter take effect right away (still hidden).
func _begin_cast(enemy: Combatant) -> void:
	enemy.loaded_def = _choose_enemy_skill(enemy)
	var used: Array = enemy.get_meta("skills_used", [])
	if not used.has(enemy.loaded_def.skill_name):
		used.append(enemy.loaded_def.skill_name)
		enemy.set_meta("skills_used", used)
	enemy.loaded_skill = enemy.loaded_def.kind
	var streak: int = enemy.get_meta("repeat_streak", 0)
	enemy.set_meta("repeat_streak", streak + 1 if enemy.loaded_def == enemy.last_skill else 1)
	enemy.last_skill = enemy.loaded_def
	enemy.cast_target = _enemy_target(enemy)  # locked on for the whole cast
	var far: Combatant = _far_target(enemy) if enemy.loaded_def.targets_far else null
	if far != null:
		enemy.cast_target = far  # Crush: someone who isn't close
		_count("far_targets")
	elif enemy.boss and enemy.cast_target != null and not enemy.statuses.has("taunt") \
			and enemy.cast_target != _nearest(enemy, _standing(party)):
		# Threat picked someone other than the nearest (play-test report).
		_count("threat_targets")
		_count("threat_targets_" + enemy.cast_target.class_id)
	_decay_threat(enemy)
	enemy.skill_revealed = false
	enemy.set_meta("revealed_for", 0.0)
	enemy.stance_time_left = 0.0
	var kind := enemy.loaded_def.kind
	enemy.stance = kind if kind == Skills.Kind.DEFENSE or kind == Skills.Kind.COUNTER else Skills.NONE
	if kind == Skills.Kind.COUNTER:
		Sfx.play("counter_ready")  # it readies a Counter
	enemy.cast_damage_taken = 0
	enemy.stagger_fill = 0.0
	enemy.interrupt_count = 0
	enemy.set_meta("smash_hits", 0)
	enemy.contained = false
	enemy.show_skill_text("...", Color(0.75, 0.75, 0.8))
	if enemy.loaded_def.locks_facing:
		enemy.set_meta("aim_locked", true)  # Golem Smash: it won't turn to follow anyone
	# Its area shows up right away, in grey: where it will land, not what it is.
	_build_cast_areas(enemy)
	if enemy.loaded_def.orbit_sprites > 0:
		_spawn_orbiters(enemy)
	if enemy.loaded_def.ceiling_circles > 0:
		_place_ceiling_circles(enemy)
	if enemy.loaded_def.cover_rock:
		_drop_cover_rock(enemy)
	_link_bait(enemy)
	print("%s is preparing %s (hidden)" % [enemy.display_name, enemy.loaded_def.skill_name])


## Late in the casting zone the prepared skill becomes visible: on the
## bar, above the enemy, and as a live area on the floor.
func _reveal_skill(enemy: Combatant) -> void:
	enemy.skill_revealed = true
	var def := enemy.loaded_def
	var text := def.skill_name.to_upper()
	if def.placed_on_party():
		for area in enemy.extra_areas:
			area.show_skill(def, false, area.radius)  # colored, and locked where it is now
	elif enemy.attack_range:
		enemy.attack_range.show_skill(def, false, _cast_radius(enemy))
	if def.snaps_to_target and enemy.cast_target != null and not enemy.cast_target.is_down:
		# Turns at once to face its target, then holds that aim: step aside!
		enemy.face_toward(enemy.cast_target.global_position - enemy.global_position, 1.0, 1000000.0)
		enemy.set_meta("aim_locked", true)
	if def.kind == Skills.Kind.DEFENSE or def.kind == Skills.Kind.COUNTER:
		text += " STANCE"
	if def.lethal:
		text += "  -  HIDE BEHIND THE ROCK"
	elif def.stagger_bar > 0:
		text += "  -  STAGGER IT"
	elif def.is_mechanic():
		text += "  -  UNAVOIDABLE"
	if def.ceiling_circles > 0:
		_start_falls(enemy)
	if def.smash_blasts_rocks:
		for piece in _debris:
			_mark_rock_blast(enemy, piece["rock"])
		if not enemy.get_meta("rock_blasts", []).is_empty():
			text += "  -  ROCKS EXPLODE"
	if def.lethal:
		_add_skulls(enemy)
	if def.follow_up != null:
		text += "  >  " + def.follow_up.skill_name.to_upper()
	if enemy.contained:
		text += " (CONTAINED)"
	_add_telegraphs(enemy)
	enemy.show_skill_text(text, def.color())
	print("%s reveals %s" % [enemy.display_name, def.skill_name])


## The enemy reached the end of the bar (or was triggered). Attack and
## Smash start a strike on whoever is in the area; a Defense or Counter
## stance ends. reset_timeline sends it back to the start of the bar
## afterwards (used when it acts during your turn; on its own turn,
## _end_turn does that).
func _enemy_unleash(enemy: Combatant, reset_timeline: bool) -> void:
	enemy.control_used = false  # it acted: halts and stuns work on it again
	if enemy.cancel_lock > 0:
		enemy.cancel_lock -= 1  # boss cancel immunity counts its actions
	enemy.freeze_left = 0.0
	enemy.statuses.erase("frozen")
	if enemy.burn_turns > 0:
		# Mage's Fire: it burns as it acts.
		enemy.burn_turns -= 1
		var burnt := enemy.take_damage(enemy.burn_damage * maxi(enemy.burn_stacks, 1), false)
		_popup(enemy, "BURN %d" % burnt, Color(1.0, 0.5, 0.2))
		_count("burn_ticks")
		if enemy.is_down:
			_finish_enemy_skill(enemy, reset_timeline)  # burnt out before it could strike
			_check_enemies()
			return
	if enemy.anchored:
		_wall_boss_acts(enemy)
	if enemy.loaded_def != null and enemy.loaded_def.stagger_bar > 0:
		# Balance numbers: how full Stagger bars get before the skill lands.
		_count("stagger_casts")
		stats["stagger_fill_pct"] = int(stats.get("stagger_fill_pct", 0)) + roundi(100.0 * enemy.stagger_fill / enemy.stagger_need(enemy.loaded_def))
	if not enemy.skill_revealed:
		_reveal_skill(enemy)
	var skill_name := enemy.loaded_def.skill_name
	if enemy.loaded_def.self_destruct:
		enemy.set_meta("detonating", true)  # it goes off once this lands (_finish_enemy_skill)
	if playtest:
		playtest.cast(enemy, skill_name)
	if enemy.loaded_def.special == EnemySkill.Special.HEAL_ALLIES:
		_heal_allies(enemy)
		_finish_enemy_skill(enemy, reset_timeline)
		return
	if enemy.loaded_def.push_out:
		_push_out(enemy, reset_timeline)
		return
	if enemy.loaded_def.ceiling_circles > 0 and enemy.loaded_def.radius <= 0.01:
		# Ceiling Burst alone: the circles did the work; nothing else strikes.
		_finish_enemy_skill(enemy, reset_timeline)
		return
	if enemy.loaded_def.smash_blasts_rocks:
		_blast_rocks(enemy)
	if enemy.loaded_def.is_offensive():
		if enemy.loaded_def.aims_exactly() and enemy.cast_target != null and not enemy.cast_target.is_down:
			enemy.face_toward(enemy.cast_target.global_position - enemy.global_position, 1.0, 1000000.0)
		var mods := _strike_targets(enemy)
		if mods.is_empty():
			_count("misses")
			if playtest:
				playtest.miss(enemy, skill_name)
			_flash("%s's %s misses!" % [enemy.display_name, skill_name])
			_crack_rocks(enemy, enemy.loaded_def)
			_leave_hazards(enemy)
			if enemy.loaded_def.follow_up != null and not enemy.loaded_def.push_out:
				_start_follow_up(enemy, enemy.loaded_def, reset_timeline)
			else:
				_finish_enemy_skill(enemy, reset_timeline)
		else:
			_begin_strike(enemy, mods, reset_timeline)
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
		if enemy.attack_range.top_level:
			# An arena-aligned area goes back onto its caster.
			enemy.attack_range.top_level = false
			enemy.attack_range.transform = enemy.attack_range.get_meta("local_transform", Transform3D.IDENTITY)
		enemy.attack_range.rotation.y = 0.0  # Golem Smash turned it to one side
		enemy.attack_range.clip_half = Vector2.ZERO
		enemy.attack_range.clip_circle = 0.0
		enemy.attack_range.go_dormant()
	for fall in _falls.duplicate():
		if fall["owner"] == enemy:
			_remove_fall(fall)  # interrupted before they all came down
	_clear_rock_blasts(enemy)
	_remove_cover_rock(enemy)
	_remove_orbiters(enemy)
	_clear_cast_extras(enemy)
	enemy.show_skill_text("")
	enemy.cast_target = null
	enemy.remove_meta("follow_up_slow")
	for member in party:
		if member.has_meta("revive_safe"):
			var safe: Array = member.get_meta("revive_safe")
			safe.erase(enemy)  # that cast is over: its next one can hit them
			if safe.is_empty():
				member.remove_meta("revive_safe")
	enemy.remove_meta("settled_radius")
	enemy.remove_meta("settle_speed")
	enemy.set_meta("aim_locked", false)
	enemy.set_meta("forced_targets", [])
	enemy.set_meta("ap_penalty_done", false)
	enemy.set_meta("staggered_chain", false)
	enemy.loaded_skill = Skills.NONE
	enemy.skill_revealed = false
	enemy.stance = Skills.NONE
	enemy.stance_time_left = 0.0
	enemy.loaded_def = null
	enemy.remove_meta("bait_for")
	enemy.remove_meta("bait_left")
	if enemy.get_meta("detonating", false):
		enemy.remove_meta("detonating")
		_self_destruct(enemy)
		return
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
			for area in _enemy_areas(enemy):
				var inside := false
				for member in _standing(party):
					if area.contains(member.global_position, member.body_radius) \
							and (enemy.loaded_def.placed_on_party() or _can_see(enemy, member)):
						inside = true
						if not targets.has(member.display_name):
							targets.append(member.display_name)
				area.set_alert(inside)
		else:
			enemy.attack_range.set_alert(false)
		if targets.is_empty():
			continue
		# Strikes always land when the enemy's icon reaches the end of the bar;
		# until then the area just glows and warns who's standing in it.
		var skill_name := enemy.loaded_def.skill_name
		if enemy.loaded_def.lethal:
			skill_name += " (hide behind the rock!)"
		elif enemy.loaded_def.stagger_bar > 0:
			skill_name += " (stagger it head-on)"
		elif enemy.loaded_def.is_mechanic():
			skill_name += " (unavoidable)"
		var verb := "will push back" if enemy.loaded_def.push_out else "will hit"
		warnings.append("%s's %s %s: %s" % [enemy.display_name, skill_name, verb, ", ".join(targets)])
	warning_label.text = "\n".join(warnings)


## True if a point is inside any enemy's live Attack/Smash area.
func _in_any_attack_range(point: Vector3, extra_radius: float) -> bool:
	for enemy in enemies:
		if _is_live_threat(enemy):
			for area in _enemy_areas(enemy):
				if area.contains(point, extra_radius):
					return true
	return false


## An enemy whose revealed Attack or Smash area can hurt you right now.
func _is_live_threat(enemy: Combatant) -> bool:
	return enemy.attack_range != null and enemy.skill_revealed and _loaded_offensive(enemy)


# --- Special enemy skills ----------------------------------------------------

## Shows a new cast's area(s) in grey: the enemy's own area, or one circle /
## line per party member for skills placed on the party.
func _build_cast_areas(enemy: Combatant) -> void:
	_clear_cast_extras(enemy)
	var def := enemy.loaded_def
	if def.placed_on_party():
		var marked: Array[Combatant] = []
		if def.special == EnemySkill.Special.ON_MARKED:
			if enemy.cast_target != null:
				marked.append(enemy.cast_target)
		else:
			marked = _standing(party)
		for member in marked:
			var area := AttackRange.new()
			add_child(area)
			area.set_meta("follow", member)
			enemy.extra_areas.append(area)
			if def.special == EnemySkill.Special.LINE_TO_EACH and def.double_on_off_balance \
					and member.statuses.has("off_balance"):
				# Off-Balance: a second line, a few degrees off the first.
				var twin := AttackRange.new()
				add_child(twin)
				twin.set_meta("follow", member)
				twin.set_meta("twist", 4.0)
				enemy.extra_areas.append(twin)
		_place_party_areas(enemy, true)
	elif enemy.attack_range:
		enemy.attack_range.rotation.y = -deg_to_rad(def.aim_offset_degrees)  # 90: its right side
		_set_arena_clip(enemy.attack_range, def.fills_arena)
		if def.arena_aligned:
			# On the arena, not on the caster: it stays put while the caster turns.
			enemy.attack_range.set_meta("local_transform", enemy.attack_range.transform)
			enemy.attack_range.top_level = true
			enemy.attack_range.global_transform = Transform3D(Basis.IDENTITY, Vector3(arena.global_position.x,
					enemy.attack_range.global_position.y, arena.global_position.z))
		# Golem Smash: the grey area covers the whole room until the reveal
		# shows which half it hits.
		enemy.attack_range.show_skill(def, true, _cast_radius(enemy), 360.0 if def.hides_side else -1.0)


## Fills-the-arena areas stop at the arena's edges.
func _set_arena_clip(area: AttackRange, on: bool) -> void:
	area.clip_center = arena.global_position
	area.clip_half = Vector2.ZERO
	area.clip_circle = 0.0
	if not on:
		return
	if arena.shape == Arena.Shape.CIRCLE:
		area.clip_circle = arena.size.x / 2.0
	else:
		area.clip_half = arena.size / 2.0


## Moves placed areas onto their party members (circles) or aims them at
## them (lines). Only while the skill is still hidden; once revealed they stay.
func _place_party_areas(enemy: Combatant, hidden: bool) -> void:
	var def := enemy.loaded_def
	for area in enemy.extra_areas:
		var member: Combatant = area.get_meta("follow")
		if member == null or not is_instance_valid(member):
			continue
		if def.special == EnemySkill.Special.ON_EACH_TARGET or def.special == EnemySkill.Special.ON_MARKED:
			area.global_position = Vector3(member.global_position.x, 0.03, member.global_position.z)
			area.show_skill(def, hidden)
		else:
			var from := Vector3(enemy.global_position.x, 0.03, enemy.global_position.z)
			var to := Vector3(member.global_position.x, 0.03, member.global_position.z)
			if area.has_meta("twist"):
				to = from + (to - from).rotated(Vector3.UP, deg_to_rad(float(area.get_meta("twist"))))
			area.global_position = from
			if from.distance_to(to) > 0.05:
				area.look_at(to, Vector3.UP)
			area.show_skill(def, hidden, from.distance_to(to) + def.line_extend)


## How big the prepared skill's own area is right now (growing circles
## grow over the cast, unless contained).
func _cast_radius(enemy: Combatant) -> float:
	var def := enemy.loaded_def
	if def == null or def.special != EnemySkill.Special.GROWING:
		return -1.0
	if enemy.has_meta("settled_radius"):
		return float(enemy.get_meta("settled_radius"))
	if enemy.contained:
		return enemy.get_meta("contained_radius", def.radius)
	var progress := clampf((enemy.timeline_pos - cast_zone_start) / (TIMELINE_LENGTH - cast_zone_start), 0.0, 1.0)
	return lerpf(def.radius, _growing_max(def), progress)


## A growing circle's biggest size (Shadowflare: from the arena's middle to
## its corners).
func _growing_max(def: EnemySkill) -> float:
	if not def.max_radius_fits_arena:
		return def.max_radius
	if arena.shape == Arena.Shape.CIRCLE:
		return arena.size.x / 2.0
	return Vector2(arena.size.x / 2.0, arena.size.y / 2.0).length()


## Every frame: placed areas follow the party until revealed, and growing
## circles grow (or get contained by damage dealt to the caster).
func _update_cast_areas() -> void:
	for enemy in enemies:
		var def := enemy.loaded_def
		if def == null or enemy.is_down:
			continue
		if def.placed_on_party() and (not enemy.skill_revealed or def.keeps_following()):
			_place_party_areas(enemy, not enemy.skill_revealed)  # unavoidable ones follow to the end
		elif def.special == EnemySkill.Special.GROWING:
			var stopped := enemy.cast_damage_taken >= ceili(enemy.max_hp * def.contain_share)
			if def.orbit_sprites > 0:
				stopped = enemy.has_meta("orbiters") and _orbiters_left(enemy) == 0  # every sprite was hit
			if not enemy.contained and stopped:
				enemy.set_meta("contained_radius", _cast_radius(enemy))
				enemy.contained = true
				_count("contained")
				_popup(enemy, "CONTAINED", Color(0.6, 0.9, 1.0))
				_flash("%s's %s is contained: it stops growing" % [enemy.display_name, def.skill_name])
				if enemy.skill_revealed:
					enemy.show_skill_text(def.skill_name.to_upper() + " (CONTAINED)", def.color())
				_settle_growing(enemy)
			elif not enemy.has_meta("settled_radius") and enemy.timeline_pos >= TIMELINE_LENGTH - 0.6:
				_settle_growing(enemy)  # full size: it stops here, then the run-out window
			var radius := _cast_radius(enemy)
			if enemy.attack_range and absf(enemy.attack_range.radius - radius) > 0.05:
				enemy.attack_range.show_skill(def, not enemy.skill_revealed, radius)
			if def.orbit_sprites > 0 and active == null and _strike == null:
				_move_orbiters(enemy, radius, get_process_delta_time() * battle_speed)


## A growing circle stops at its current size, and the rest of its cast
## takes as long as the slowest party member needs to walk out of it from
## its middle (plus flare_run_out_extra), however far along the bar it was.
func _settle_growing(enemy: Combatant) -> void:
	var radius := _cast_radius(enemy)
	enemy.set_meta("settled_radius", radius)
	var slowest := INF
	for member in _standing(party):
		slowest = minf(slowest, member.current_move_speed())
	if slowest == INF or slowest <= 0.1:
		slowest = 4.0
	var seconds := radius / slowest + flare_run_out_extra
	if not enemy.skill_revealed and enemy.timeline_pos < reveal_at:
		enemy.timeline_pos = reveal_at  # stopped while grey: it's revealed now, so the window is all readable
	var left := maxf(TIMELINE_LENGTH - enemy.timeline_pos, 0.01)
	enemy.set_meta("settle_speed", left / (seconds * enemy.speed * time_scale * _haste(enemy)))
	enemy.set_meta("settle_seconds", seconds)
	_count("flare_settles")


## Shadowflare: its sprites appear on the circle's edge, evenly spread.
func _spawn_orbiters(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	if def.orbit_scene == null:
		return
	var list: Array = []
	var radius := maxf(_cast_radius(enemy), def.radius)
	for i in def.orbit_sprites:
		var sprite := def.orbit_scene.instantiate() as Combatant
		$Enemies.add_child(sprite)
		sprite.set_meta("summoner", enemy)  # gone with the caster
		sprite.set_meta("no_timeline", true)  # it never takes a turn
		sprite.set_meta("orbit_angle", TAU * i / def.orbit_sprites)
		sprite.hold = true
		enemies.append(sprite)
		combatants.append(sprite)
		list.append(sprite)
	enemy.set_meta("orbiters", list)
	_move_orbiters(enemy, radius, 0.0)
	_count("orbiters")
	_flash("%s calls %d Shadow Sprites: hit each one once to stop the circle growing!" % [enemy.display_name, list.size()])


func _orbiters_left(enemy: Combatant) -> int:
	var left := 0
	for sprite in enemy.get_meta("orbiters", []):
		if is_instance_valid(sprite) and not sprite.is_down:
			left += 1
	return left


## They circle along the circle's edge (and stay inside the arena).
func _move_orbiters(enemy: Combatant, radius: float, delta: float) -> void:
	var step := enemy.loaded_def.orbit_speed * delta / maxf(radius, 0.5)
	for sprite in enemy.get_meta("orbiters", []):
		if not is_instance_valid(sprite) or sprite.is_down:
			continue
		var angle: float = float(sprite.get_meta("orbit_angle", 0.0)) + step
		sprite.set_meta("orbit_angle", angle)
		var spot := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		sprite.global_position = Vector3(spot.x, enemy.global_position.y, spot.z)
		_keep_in_arena(sprite)


## The skill is over (landed or stopped): the sprites leave.
func _remove_orbiters(enemy: Combatant) -> void:
	for sprite in enemy.get_meta("orbiters", []):
		if not is_instance_valid(sprite):
			continue
		enemies.erase(sprite)
		combatants.erase(sprite)
		sprite.process_mode = Node.PROCESS_MODE_DISABLED
		sprite.visible = false
	if enemy.has_meta("orbiters"):
		enemy.remove_meta("orbiters")


func _clear_cast_extras(enemy: Combatant) -> void:
	for area in enemy.extra_areas:
		if is_instance_valid(area):
			area.queue_free()
	enemy.extra_areas.clear()
	for node in enemy.get_meta("skulls", []):
		if is_instance_valid(node):
			node.queue_free()
	enemy.set_meta("skulls", [])
	for area in enemy.get_meta("ceiling_grey", []):
		if is_instance_valid(area) and not _falls.any(func(f): return f["area"] == area):
			area.queue_free()
	enemy.set_meta("ceiling_grey", [])
	_clear_telegraphs(enemy)


## Who a prepared skill hits, and how: {party member: {"mult", "unblockable", "one_hp"}}.
## preview: just looking (the warning pulse), so nothing is counted.
func _strike_targets(enemy: Combatant, preview: bool = false) -> Dictionary:
	var result := _strike_targets_all(enemy, preview)
	# Someone revived during this cast can't be hit by it.
	for member in result.keys():
		if member.has_meta("revive_safe") and (member.get_meta("revive_safe") as Array).has(enemy):
			result.erase(member)
	return result


func _strike_targets_all(enemy: Combatant, preview: bool = false) -> Dictionary:
	var def := enemy.loaded_def
	var result := {}
	if def.placed_on_party():
		for member in _standing(party):
			var count := 0
			for area in enemy.extra_areas:
				if not area.contains(member.global_position, member.body_radius):
					continue
				if def.special == EnemySkill.Special.LINE_TO_EACH and not _can_see(enemy, member):
					continue  # a rock blocks the line
				count += 1
			if def.always_hits and count == 0:
				for area in enemy.extra_areas:
					if area.get_meta("follow", null) == member:
						if def.special == EnemySkill.Special.LINE_TO_EACH and not _can_see(enemy, member):
							continue  # hiding behind a rock still blocks a line
						count = 1  # its own circle / line finds it wherever it stands
			if count == 0:
				continue
			var mod := {"mult": 1.0, "unblockable": false, "one_hp": false}
			if count >= 2:
				if def.overlap == EnemySkill.Overlap.DOUBLE:
					mod["mult"] = 2.0
				elif def.overlap == EnemySkill.Overlap.ONE_HP:
					mod["one_hp"] = true
				if def.overlap_unblockable:
					mod["unblockable"] = true
			result[member] = mod
	else:
		var shielded := false
		for member in _standing(party):
			if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius):
				if _strike_reaches(enemy, member):
					result[member] = {"mult": 1.0, "unblockable": false, "one_hp": false}
				else:
					shielded = true  # in the area, but a rock was in the way
		if shielded and not preview:
			_count("rock_saves")
		if def.hits_everyone:
			# The whole party is caught; damage depends on how big it grew.
			var size_share := clampf(_cast_radius(enemy) / maxf(def.max_radius, 0.1), 0.25, 1.0) \
					if def.special == EnemySkill.Special.GROWING else 1.0
			result = {}
			for member in _standing(party):
				result[member] = {"mult": size_share, "unblockable": false, "one_hp": false}
		var locked := enemy.cast_target
		if def.always_hits_target and locked != null and not locked.is_down and not result.has(locked) \
				and _can_see(enemy, locked):
			result[locked] = {"mult": 1.0, "unblockable": false, "one_hp": false}  # it never loses its target
		if def.stops_at_first_hit and result.size() > 1:
			# Only the first one in the way is hit; they shield the rest.
			var first: Combatant = null
			for member in result:
				if first == null or enemy.gap_to(member) < enemy.gap_to(first):
					first = member
			result = {first: result[first]}
	for member in enemy.get_meta("forced_targets", []):
		if is_instance_valid(member) and not member.is_down and not result.has(member):
			result[member] = {"mult": 1.0, "unblockable": false, "one_hp": false}  # caught by Shout
	if def.shared_damage and result.size() > 1:
		# Stacking up spreads the damage: 100%, 67%, 50%, 40%...
		var share := 1.0 / (1.0 + 0.5 * (result.size() - 1))
		for mod in result.values():
			mod["mult"] = float(mod["mult"]) * share
	return result


## Healing Ritual: every enemy within the circle (the caster too) heals.
func _heal_allies(caster: Combatant) -> void:
	var def := caster.loaded_def
	var healed: PackedStringArray = []
	for ally in _standing(enemies):
		var distance := ally.global_position.distance_to(caster.global_position) - ally.body_radius
		if ally == caster or distance <= def.radius:
			var share := ceili(ally.max_hp * def.heal_share)
			if def.heal_cap > 0:
				share = mini(share, def.heal_cap)  # Healing Ritual: at most 60 on a boss
			var amount := ally.heal(share)
			if amount > 0:
				SpellFx.heal(self, ally)
				Sfx.play("heal_spell", -3.0)
				Sfx.play_later("hp_number", 0.35, -3.0)
			if amount > 0:
				_popup(ally, "+%d" % amount, Color(0.45, 0.95, 0.5))
				healed.append("%s +%d" % [ally.display_name, amount])
	if healed.is_empty():
		_flash("%s's %s: nobody needed healing" % [caster.display_name, def.skill_name])
	else:
		_flash("%s's %s heals: %s" % [caster.display_name, def.skill_name, ", ".join(healed)])


## Fire Wave / Burning Spike: the skill's area keeps burning for a few of
## the caster's turns (each placed circle burns on its own).
func _spawn_trail(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var sources: Array[AttackRange] = []
	if def.placed_on_party():
		for placed in enemy.extra_areas:
			if is_instance_valid(placed):
				sources.append(placed)
	elif enemy.attack_range != null:
		sources.append(enemy.attack_range)
	var turns := def.trail_turns
	if def.trail_turns_below_half > 0 and enemy.hp <= enemy.max_hp * 0.5:
		turns = def.trail_turns_below_half  # the floor keeps shrinking late in the fight
	for source in sources:
		if def.trail_cap > 0:
			# Too many lines down: the oldest goes out.
			var same := _hazards.filter(func(h): return h["owner"] == enemy and h.get("group", "") == def.trail_group)
			while same.size() >= def.trail_cap:
				_remove_hazard(same.pop_front())
				_count("trails_put_out")
		var area := AttackRange.new()
		add_child(area)
		area.global_transform = source.global_transform
		area.show_hazard(def, Color(1.0, 0.45, 0.1))
		var hazard := {"area": area, "owner": enemy, "turns": turns,
				"dps": def.trail_damage_per_second, "acc": {}, "name": def.skill_name, "group": def.trail_group}
		if def.trail_touch_damage > 0:
			# Stepping in hurts at once; whoever stands in it as it appears doesn't pay that.
			var inside := {}
			for member in _standing(party):
				inside[member] = area.contains(member.global_position, member.body_radius * 0.6)
			hazard["touch"] = def.trail_touch_damage
			hazard["inside"] = inside
		_hazards.append(hazard)
	if not sources.is_empty():
		_flash("The ground keeps burning!")


## Rock Spikes: spikes rise inside the skill's circle and hurt anyone who
## walks into one, for a few of the caster's turns.
func _spawn_spikes(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var center := enemy.global_position
	if not enemy.extra_areas.is_empty() and is_instance_valid(enemy.extra_areas[0]):
		center = enemy.extra_areas[0].global_position
	var spike_def := EnemySkill.make(def.skill_name, Skills.Kind.SPECIAL, EnemySkill.Shape.CIRCLE, 0.5, 360.0, 0, 0.0, 0)
	var turn := randf() * TAU
	for i in def.spikes:
		var a := turn + TAU * i / def.spikes
		var spot := center + Vector3(sin(a), 0.0, cos(a)) * def.radius * 0.55
		spot.y = 0.04
		var area := AttackRange.new()
		add_child(area)
		area.global_position = spot
		area.show_hazard(spike_def, Color(0.75, 0.6, 0.45))
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.32
		mesh.height = 1.0
		spike.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.45, 0.4)
		spike.material_override = material
		area.add_child(spike)
		spike.position = Vector3(0, 0.5, 0)
		# Whoever is already standing there isn't hurt until they walk back in.
		var inside := {}
		for member in _standing(party):
			inside[member] = area.contains(member.global_position, member.body_radius * 0.6)
		_hazards.append({"area": area, "owner": enemy, "turns": def.trail_turns, "dps": 0.0, "acc": {},
				"name": def.skill_name, "touch": def.spike_damage, "inside": inside})
	_flash("Rock spikes burst from the ground!")


## Fire trails and spikes stay behind whether the skill hit anyone or not.
func _leave_hazards(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	if def == null:
		return
	if def.spikes > 0:
		_spawn_spikes(enemy)
	elif def.trail_turns > 0:
		_spawn_trail(enemy)


## Shout: everyone inside is pushed out past the edge, then the follow-up
## (Sword Spin) comes at once and hits everyone who was pushed, wherever
## they landed, plus anyone else standing in its own area.
func _push_out(enemy: Combatant, reset_timeline: bool) -> void:
	var def := enemy.loaded_def
	var caught: Array[Combatant] = []
	for member in _standing(party):
		if enemy.attack_range and enemy.attack_range.contains(member.global_position, member.body_radius):
			caught.append(member)
	for member in caught:
		var offset := member.global_position - enemy.global_position
		offset.y = 0.0
		var needed := def.radius + member.body_radius + 0.4 - offset.length()
		if needed > 0.0:
			_knock_away(member, enemy.global_position, needed)
		_popup(member, "PUSHED", Color(1.0, 0.6, 0.3))
	if caught.is_empty():
		_flash("%s's %s: nobody was close" % [enemy.display_name, def.skill_name])
	else:
		_flash("%s's %s pushes back %s!" % [enemy.display_name, def.skill_name, _names(caught)])
	var next := def.follow_up
	if next == null or enemy.attack_range == null:
		_finish_enemy_skill(enemy, reset_timeline)
		return
	# The follow-up is revealed now and strikes follow_up_delay seconds later:
	# whoever was pushed is marked and will be hit wherever they go; anyone
	# else has that long to get out (into Sword Spin's safe middle).
	_clear_telegraphs(enemy)
	enemy.loaded_def = next
	enemy.loaded_skill = next.kind
	enemy.skill_revealed = true
	enemy.last_skill = def
	enemy.attack_range.show_skill(next)
	enemy.show_skill_text(next.skill_name.to_upper(), next.color())
	var marked: Array = []
	for member in caught:
		if not member.is_down:
			marked.append(member)
	enemy.set_meta("forced_targets", marked)
	_mark_forced(enemy, marked)
	_schedule_follow_up(enemy, def.follow_up_delay)
	if reset_timeline:
		_send_to_start(enemy)  # on its own turn, _end_turn does this


## A strike with a follow_up (Deep Breath: Inhale, then Maw Bite): the next
## skill is revealed at once and strikes follow_up_delay seconds later.
func _start_follow_up(enemy: Combatant, def: EnemySkill, reset_timeline: bool) -> void:
	var next := def.follow_up
	_clear_telegraphs(enemy)
	_clear_cast_extras(enemy)
	enemy.loaded_def = next
	enemy.loaded_skill = next.kind
	enemy.skill_revealed = true
	enemy.last_skill = def
	enemy.set_meta("ap_penalty_done", false)
	enemy.set_meta("staggered_chain", false)
	if enemy.attack_range:
		# Its own aim (Right + Left Golem Smash: now the other side).
		enemy.attack_range.rotation.y = -deg_to_rad(next.aim_offset_degrees)
		_set_arena_clip(enemy.attack_range, next.fills_arena)
		enemy.attack_range.show_skill(next)
	var text := next.skill_name.to_upper()
	if next.smash_blasts_rocks:
		for piece in _debris:
			_mark_rock_blast(enemy, piece["rock"])
		if not enemy.get_meta("rock_blasts", []).is_empty():
			text += "  -  ROCKS EXPLODE"
	enemy.show_skill_text(text, next.color())
	_add_telegraphs(enemy)
	_schedule_follow_up(enemy, def.follow_up_delay)
	if reset_timeline:
		_send_to_start(enemy)


## A follow-up strikes `delay` real seconds from now. Its spot on the bar is
## that far before the end; when that would be before the casting zone (a
## fast boss, a long delay), it starts at the zone's edge and the bar runs
## slower for it (follow_up_slow) so the delay still holds.
func _schedule_follow_up(enemy: Combatant, delay: float) -> void:
	enemy.remove_meta("follow_up_slow")
	var rate := _follow_up_rate(enemy)
	var room := TIMELINE_LENGTH - (cast_zone_start + 0.01)
	var needed := delay * rate
	if needed > room and needed > 0.0:
		enemy.set_meta("follow_up_slow", room / needed)
		needed = room
	enemy.set_meta("follow_up_at", TIMELINE_LENGTH - needed)


## Timeline units per real second for an enemy's loaded follow-up.
func _follow_up_rate(enemy: Combatant) -> float:
	var cast := 1.0
	if enemy.loaded_def != null:
		cast = enemy.loaded_def.cast_speed * enemy.cast_zone_speed * _stagger_slow(enemy.loaded_def)
	return enemy.speed * time_scale * battle_speed * cast * _haste(enemy)


## Real seconds until a pending follow-up strikes (tests, reports).
func _follow_up_seconds(enemy: Combatant) -> float:
	var at := float(enemy.get_meta("follow_up_at", enemy.timeline_pos))
	return (TIMELINE_LENGTH - at) / maxf(_follow_up_rate(enemy) * float(enemy.get_meta("follow_up_slow", 1.0)), 0.001)


## Orange spheres over everyone a follow-up will hit no matter what.
func _mark_forced(enemy: Combatant, marked: Array) -> void:
	var nodes: Array[Node3D] = []
	for member in marked:
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		sphere.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.6, 0.1)
		sphere.material_override = material
		member.add_child(sphere)
		sphere.position = Vector3(0, 2.85, 0)
		sphere.set_meta("bob", true)
		nodes.append(sphere)
	enemy.set_meta("telegraphs", nodes)


## Anyone standing in a fire trail keeps losing HP (in small chunks);
## anyone walking into a spike takes its damage once per step in.
func _tick_hazards(world_delta: float) -> void:
	for hazard in _hazards:
		var area: AttackRange = hazard["area"]
		var acc: Dictionary = hazard["acc"]
		if hazard.has("touch"):
			var inside: Dictionary = hazard["inside"]
			var spike := float(hazard["dps"]) <= 0.0
			for member in _standing(party):
				var now := area.contains(member.global_position, member.body_radius * 0.6)
				if now and not inside.get(member, false):
					var source := "Rock spike" if spike else "%s fire" % hazard["name"]
					var taken := _hurt(member, int(hazard["touch"]), false, source)
					_popup(member, str(taken), Color(0.85, 0.7, 0.5) if spike else Color(1.0, 0.45, 0.15))
					_flash(("%s walks into a rock spike!" if spike else "%s steps into the fire!") % member.display_name)
					_count("fire_step_ins" if not spike else "spike_step_ins")
					if member.is_down:
						_check_party()
				inside[member] = now
			if spike:
				continue
		for member in _standing(party):
			if not area.contains(member.global_position, member.body_radius * 0.5):
				continue
			acc[member] = float(acc.get(member, 0.0)) + float(hazard["dps"]) * world_delta
			if acc[member] >= 4.0:
				var chunk := floori(acc[member])
				acc[member] -= chunk
				var taken := _hurt(member, chunk, false, "%s fire" % hazard["name"])
				_popup(member, str(taken), Color(1.0, 0.55, 0.2))
				if member.is_down:
					_flash("%s burns down in the fire!" % member.display_name)
					_check_party()


func _remove_hazard(hazard: Dictionary) -> void:
	var area: AttackRange = hazard["area"]
	if is_instance_valid(area):
		area.queue_free()
	_hazards.erase(hazard)


# --- Ceiling Burst -----------------------------------------------------------

## Ceiling Burst: picks the spots where the circles will fall (shown in grey
## while the skill is hidden). One lands near each party member, so nobody
## can ignore it; the rest are scattered over the arena, apart from each other.
func _place_ceiling_circles(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var r := def.ceiling_radius
	var spots: Array[Vector3] = []
	for member in _standing(party):
		if spots.size() >= def.ceiling_circles:
			break
		for attempt in 12:
			var spot := member.global_position + Vector3(randf_range(-1.6, 1.6), 0.0, randf_range(-1.6, 1.6))
			if _inside_arena(spot, r * 0.5) and _spot_free(spot, spots, r * 1.1) and not _in_own_area(enemy, spot) \
					and _clear_of_enemies(spot, r):
				spots.append(spot)
				break
	var tries := 0
	while spots.size() < def.ceiling_circles and tries < 400:
		tries += 1
		var spot := _random_arena_point(r * 0.6)
		if _spot_free(spot, spots, r * 1.2) and not _in_own_area(enemy, spot) and _clear_of_enemies(spot, r):
			spots.append(spot)
	var circle := EnemySkill.make(def.skill_name, def.kind, EnemySkill.Shape.CIRCLE, r, 360.0, def.ceiling_damage, 0.0, 0)
	var grey: Array = []
	for spot in spots:
		var area := AttackRange.new()
		add_child(area)
		area.global_position = Vector3(spot.x, 0.035, spot.z)
		area.show_skill(circle, true)
		area.set_meta("circle_def", circle)
		grey.append(area)
	enemy.set_meta("ceiling_grey", grey)


## At the reveal: the circles take the skill's color and start falling, one
## after another in a random order.
func _start_falls(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var areas: Array = enemy.get_meta("ceiling_grey", []).duplicate()
	areas.shuffle()
	enemy.set_meta("ceiling_penalty", false)
	var rock_radius := def.ceiling_rock_radius
	if enemy.max_rock_bursts > 0:
		if enemy.rock_bursts >= enemy.max_rock_bursts:
			rock_radius = 0.0  # enough rocks: the circles still fall, but leave none
		else:
			enemy.rock_bursts += 1
	for i in areas.size():
		var area: AttackRange = areas[i]
		if not is_instance_valid(area):
			continue
		area.show_hazard(area.get_meta("circle_def"), FALLING_ROCK_COLOR)  # its own color: not the smash's
		_falls.append({"area": area, "owner": enemy, "time_left": def.ceiling_lead + i * def.ceiling_interval,
				"damage": def.ceiling_damage, "warning": def.ceiling_warning, "ring": null, "name": def.skill_name,
				"rock_radius": rock_radius, "rock_seconds": def.ceiling_rock_seconds})


func _falls_pending(enemy: Combatant) -> bool:
	for fall in _falls:
		if fall["owner"] == enemy:
			return true
	return false


## Each circle's ring shrinks onto it in its last ceiling_warning seconds;
## when it lands, everyone inside is hit.
func _tick_falls(world_delta: float) -> void:
	for piece in _debris.duplicate():
		piece["age"] = float(piece.get("age", 0.0)) + world_delta
		piece["time_left"] = float(piece["time_left"]) - world_delta
		if float(piece["time_left"]) <= 0.0:
			_debris.erase(piece)
			var old_rock: Node3D = piece["rock"]
			if is_instance_valid(old_rock):
				var sink := create_tween()
				sink.tween_property(old_rock, "global_position:y", -2.2, 0.6)
				sink.tween_callback(old_rock.queue_free)
	for fall in _falls.duplicate():
		var area: AttackRange = fall["area"]
		if not is_instance_valid(area):
			_falls.erase(fall)
			continue
		fall["time_left"] = float(fall["time_left"]) - world_delta
		var left: float = fall["time_left"]
		var warning: float = fall["warning"]
		if left <= warning and fall["ring"] == null:
			var ring := _make_ring(area.radius, 0.12, Color(1.0, 0.45, 0.2, 0.95))
			add_child(ring)
			ring.global_position = Vector3(area.global_position.x, 0.06, area.global_position.z)
			fall["ring"] = ring
		if fall["ring"] != null:
			var grow := 1.0 + 2.0 * clampf(left / maxf(warning, 0.01), 0.0, 1.0)
			(fall["ring"] as Node3D).scale = Vector3(grow, 1.0, grow)
		var someone := false
		for member in _standing(party):
			if area.contains(member.global_position, member.body_radius * 0.6):
				someone = true
		area.set_alert(someone and left <= warning)
		if left > 0.0:
			continue
		_land_fall(fall)


func _land_fall(fall: Dictionary) -> void:
	var area: AttackRange = fall["area"]
	var owner: Combatant = fall["owner"]
	var hit: Array[Combatant] = []
	for member in _standing(party):
		if area.contains(member.global_position, member.body_radius * 0.6):
			var taken := _hurt(member, int(fall["damage"]), false, String(fall["name"]), owner, String(fall["name"]))
			_popup(member, str(taken), Color(1.0, 0.55, 0.3))
			hit.append(member)
	if not hit.is_empty():
		var lines: PackedStringArray = ["%s: a falling rock hits %s" % [fall["name"], _names(hit)]]
		if is_instance_valid(owner) and not owner.get_meta("ceiling_penalty", false):
			owner.set_meta("ceiling_penalty", true)  # one max AP segment per burst, not per rock
			var note := _lose_max_ap_for_hit(hit)
			if note != "":
				lines.append(note)
			if playtest:
				playtest.avoidable(owner, String(fall["name"]))
		_flash("\n".join(lines))
		_check_party()
	if float(fall.get("rock_radius", 0.0)) > 0.0 and _clear_of_enemies(area.global_position, float(fall["rock_radius"])):
		# The rock stays where it fell for a while: it blocks the way (and sight).
		# Never under an enemy (the Golem may have walked into its own circle):
		# no rock there, so it isn't shoved aside by its own skill.
		var rock := ArenaObstacle.new()
		rock.kind = ArenaObstacle.Kind.ROCK
		rock.radius = float(fall["rock_radius"])
		arena.add_child(rock)
		rock.global_position = Vector3(area.global_position.x, 0.0, area.global_position.z)
		rock.scale = Vector3(1.0, 0.75, 1.0)  # a fallen chunk, lower than the arena's rocks
		var lasts := float(fall["rock_seconds"])
		_debris.append({"rock": rock, "time_left": lasts if lasts > 0.0 else INF, "age": 0.0})  # 0: stays
		_mark_rock_blast_on(rock)
		for c in _standing(party):
			_keep_in_arena(c)  # anyone it landed on is pushed out from under it
	_remove_fall(fall)


## Golem Smash revealed: a rock inside its area gets a blast circle.
func _mark_rock_blast(enemy: Combatant, rock: Node3D) -> void:
	if not is_instance_valid(rock) or enemy.attack_range == null:
		return
	var at := Vector3(rock.global_position.x, 0.0, rock.global_position.z)
	if not enemy.attack_range.contains(at, 0.0):
		return
	var blasts: Array = enemy.get_meta("rock_blasts", [])
	for blast in blasts:
		if blast["rock"] == rock:
			return
	var def := enemy.loaded_def
	var circle := EnemySkill.make(def.skill_name + ": rock blast", def.kind, EnemySkill.Shape.CIRCLE, def.rock_blast_radius, 360.0, def.rock_blast_damage, 0.0, 0)
	var area := AttackRange.new()
	add_child(area)
	area.global_position = Vector3(at.x, 0.035, at.z)
	area.show_hazard(circle, ROCK_BLAST_COLOR)
	blasts.append({"rock": rock, "area": area})
	enemy.set_meta("rock_blasts", blasts)


## A rock fell during a revealed Golem Smash: it'll blow up too if it's in
## the Smash's area.
func _mark_rock_blast_on(rock: Node3D) -> void:
	for enemy in _standing(enemies):
		if enemy.loaded_def != null and enemy.loaded_def.smash_blasts_rocks and enemy.skill_revealed:
			_mark_rock_blast(enemy, rock)


## Golem Smash lands: every marked rock explodes, hurting anyone in its circle.
func _blast_rocks(enemy: Combatant) -> void:
	var blasts: Array = enemy.get_meta("rock_blasts", [])
	if blasts.is_empty():
		return
	var hit: Array[Combatant] = []
	var blast_name := enemy.loaded_def.skill_name + ": rock blast"
	for blast in blasts:
		var area: AttackRange = blast["area"]
		for member in _standing(party):
			if member not in hit and area.contains(member.global_position, member.body_radius * 0.6):
				var taken := _hurt(member, enemy.loaded_def.rock_blast_damage, false, blast_name, enemy, blast_name)
				_popup(member, str(taken), ROCK_BLAST_COLOR)
				hit.append(member)
		var rock: Node3D = blast["rock"]
		for piece in _debris.duplicate():
			if piece["rock"] == rock:
				_debris.erase(piece)
		if is_instance_valid(rock):
			rock.queue_free()
		_count("rock_blasts")
	_clear_rock_blasts(enemy)
	var lines: PackedStringArray = ["%s shatters %d rock%s!" % [enemy.loaded_def.skill_name, blasts.size(), "" if blasts.size() == 1 else "s"]]
	if not hit.is_empty():
		lines.append("The blasts hit %s" % _names(hit))
		if playtest:
			playtest.avoidable(enemy, blast_name)
		_count("avoidable_hits")
		if hit.has(controlled):
			_count("avoidable_hits_you")
	_flash("\n".join(lines))
	_check_party()


func _clear_rock_blasts(enemy: Combatant) -> void:
	for blast in enemy.get_meta("rock_blasts", []):
		if is_instance_valid(blast["area"]):
			(blast["area"] as Node).queue_free()
	enemy.set_meta("rock_blasts", [])


func _remove_fall(fall: Dictionary) -> void:
	if fall["ring"] != null and is_instance_valid(fall["ring"]):
		(fall["ring"] as Node).queue_free()
	if is_instance_valid(fall["area"]):
		(fall["area"] as Node).queue_free()
	_falls.erase(fall)


## Ceiling Burst: a falling-rock circle (radius r) keeps clear of every
## standing enemy, so a rock never lands on the Golem or its allies and
## pushes them around.
func _clear_of_enemies(spot: Vector3, r: float) -> bool:
	for enemy in _standing(enemies):
		var flat := Vector2(spot.x - enemy.global_position.x, spot.z - enemy.global_position.z)
		if flat.length() < r + enemy.body_radius + 0.3:
			return false
	return true


## True if a floor point is inside the arena, at least margin from its edge.
func _inside_arena(point: Vector3, margin: float) -> bool:
	var p := point - arena.global_position
	if arena.shape == Arena.Shape.CIRCLE:
		return Vector2(p.x, p.z).length() <= arena.size.x / 2.0 - margin
	return absf(p.x) <= arena.size.x / 2.0 - margin and absf(p.z) <= arena.size.y / 2.0 - margin


func _random_arena_point(margin: float) -> Vector3:
	var half := arena.size / 2.0 - Vector2(margin, margin)
	for attempt in 30:
		var p := arena.global_position + Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y))
		if _inside_arena(p, margin):
			return p
	return arena.global_position


## Not inside a rock, and at least min_gap from the other spots.
## Combined with an area of its own (Golem Smash + Ceiling Burst): the
## circles fall where the smash doesn't, shrinking the safe ground.
func _in_own_area(enemy: Combatant, spot: Vector3) -> bool:
	return enemy.loaded_def.radius > 0.01 and enemy.attack_range != null and enemy.attack_range.contains(spot)


func _spot_free(spot: Vector3, others: Array[Vector3], min_gap: float) -> bool:
	for obstacle in arena.obstacles():
		if Vector2(spot.x - obstacle.global_position.x, spot.z - obstacle.global_position.z).length() < obstacle.radius:
			return false
	for other in others:
		if Vector2(spot.x - other.x, spot.z - other.z).length() < min_gap:
			return false
	return true


# --- Doom Gaze ----------------------------------------------------------------

## Doom Gaze: a rock crashes down at one of the four compass points around
## the enemy, picked so there's room to hide behind it inside the arena.
func _drop_cover_rock(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	var r := def.cover_rock_radius
	var dirs := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	dirs.shuffle()
	# In a corner none of the four may fit: then the diagonals, and last
	# the way to the arena's middle (there must always be a rock to hide behind).
	var diagonals := [Vector3(1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized()]
	diagonals.shuffle()
	dirs.append_array(diagonals)
	var to_middle := arena.global_position - enemy.global_position
	to_middle.y = 0.0
	if to_middle.length() > 0.5:
		dirs.append(to_middle.normalized())
	var chosen := Vector3.ZERO
	var where := Vector3.ZERO
	for distance in [def.cover_rock_distance, def.cover_rock_distance * 0.75, def.cover_rock_distance * 0.55, def.cover_rock_distance * 1.3]:
		for dir in dirs:
			var spot: Vector3 = enemy.global_position + dir * distance
			var hide: Vector3 = spot + dir * (r + 1.8)  # room behind it for the party
			if not _inside_arena(spot, r + 0.4) or not _inside_arena(hide, 0.7):
				continue
			var blocked := false
			for obstacle in arena.obstacles():
				if Vector2(spot.x - obstacle.global_position.x, spot.z - obstacle.global_position.z).length() < obstacle.radius + r + 0.6:
					blocked = true
			if blocked:
				continue
			chosen = dir
			where = spot
			break
		if chosen != Vector3.ZERO:
			break
	if chosen == Vector3.ZERO:
		return  # no room anywhere (shouldn't happen in the boss arena)
	var rock := ArenaObstacle.new()
	rock.kind = ArenaObstacle.Kind.ROCK
	rock.radius = r
	arena.add_child(rock)
	rock.global_position = Vector3(where.x, 9.0, where.z)
	rock.set_meta("hide_dir", chosen)
	var tween := create_tween()
	tween.tween_property(rock, "global_position:y", 0.0, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	enemy.set_meta("cover_rock", rock)
	_flash("A rock crashes down! Hide behind it")


func _remove_cover_rock(enemy: Combatant) -> void:
	if not enemy.has_meta("cover_rock"):
		return
	var rock: Node3D = enemy.get_meta("cover_rock")
	enemy.remove_meta("cover_rock")
	if rock == null or not is_instance_valid(rock):
		return
	var tween := create_tween()
	tween.tween_property(rock, "global_position:y", -2.2, 0.5)
	tween.tween_callback(rock.queue_free)


## Where an AI ally hides from a lethal skill: in the cover rock's shadow,
## side by side (a second row further back), or null.
func _hide_point(ally: Combatant) -> Variant:
	for enemy in enemies:
		if enemy.is_down or enemy.loaded_def == null or not enemy.loaded_def.lethal:
			continue
		if not enemy.has_meta("cover_rock"):
			continue
		var rock: Node3D = enemy.get_meta("cover_rock")
		if rock == null or not is_instance_valid(rock):
			continue
		var away := rock.global_position - enemy.global_position
		away.y = 0.0
		away = away.normalized()
		var side := away.cross(Vector3.UP)
		var slot := _standing(party).find(ally)
		var offsets := [0.0, 0.7, -0.7, 0.35, -0.35, 0.0]
		var row := 0.0 if slot < 3 else 0.9
		var base := Vector3(rock.global_position.x, 0.0, rock.global_position.z)
		return base + away * ((rock as ArenaObstacle).radius + ally.body_radius + 0.45 + row) \
				+ side * float(offsets[clampi(slot, 0, offsets.size() - 1)])
	return null


## A point beside the rock between an ally and where it's heading, on the
## ally's side of it, so the ally walks round instead of into it.
func _around_rock(ally: Combatant, goal: Vector3) -> Vector3:
	var best: ArenaObstacle = null
	for obstacle in arena.obstacles():
		if not obstacle.blocks_sight():
			continue
		var c := Vector2(obstacle.global_position.x, obstacle.global_position.z)
		var a := Vector2(ally.global_position.x, ally.global_position.z)
		var ab := Vector2(goal.x, goal.z) - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < obstacle.radius + ally.body_radius:
			if best == null or ally.global_position.distance_to(obstacle.global_position) \
					< ally.global_position.distance_to(best.global_position):
				best = obstacle
	if best == null:
		return goal
	var center := Vector3(best.global_position.x, 0.0, best.global_position.z)
	var along := goal - ally.global_position
	along.y = 0.0
	var side := along.normalized().cross(Vector3.UP)
	if side.dot(ally.global_position - center) < 0.0:
		side = -side
	return center + side * (best.radius + ally.body_radius + 0.6)


## White skulls scattered over a lethal skill's area, so it reads as death.
func _add_skulls(enemy: Combatant) -> void:
	var nodes: Array = []
	var half := arena.size / 2.0
	var step := 3.4
	var x := -half.x + step * 0.5
	var row := 0
	while x < half.x:
		var z := -half.y + step * (0.5 if row % 2 == 0 else 1.0)
		while z < half.y:
			var spot := arena.global_position + Vector3(x, 0.0, z)
			if enemy.attack_range.contains(spot) and _inside_arena(spot, 0.6) \
					and spot.distance_to(enemy.global_position) > enemy.body_radius + 1.0:
				var skull := Label3D.new()
				skull.text = "☠"
				skull.font_size = 150
				skull.modulate = Color(1, 1, 1, 0.6)
				skull.outline_size = 0
				skull.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				add_child(skull)
				skull.global_position = Vector3(spot.x, 0.06, spot.z)
				nodes.append(skull)
			z += step
		x += step * 0.87
		row += 1
	enemy.set_meta("skulls", nodes)


# --- Telegraphs -------------------------------------------------------------

## Revealed skills that need a specific answer say so on the field:
## - spread out (circles or lines placed on everyone): a red sphere bobs
##   above each party member's head;
## - stack up (damage shared between those hit): arrows around the area's
##   edge point inward.
func _add_telegraphs(enemy: Combatant) -> void:
	_clear_telegraphs(enemy)
	var def := enemy.loaded_def
	var nodes: Array[Node3D] = []
	var marked: Array[Combatant] = []
	if def.special == EnemySkill.Special.ON_MARKED:
		if enemy.cast_target != null and not enemy.cast_target.is_down:
			marked.append(enemy.cast_target)  # keep away from the marked one
	elif def.placed_on_party() and def.overlap != EnemySkill.Overlap.NORMAL:
		marked = _standing(party)
	if not marked.is_empty():
		for member in marked:
			var sphere := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.4
			sphere.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(1.0, 0.15, 0.1)
			sphere.material_override = material
			member.add_child(sphere)
			sphere.position = Vector3(0, 2.85, 0)
			sphere.set_meta("bob", true)
			nodes.append(sphere)
	elif def.shared_damage and enemy.attack_range:
		var area := enemy.attack_range
		var count := 7
		var half := deg_to_rad(area.angle_degrees) / 2.0
		var center := Vector3(0, 0.06, -area.radius * 0.45) if area.angle_degrees < 360.0 else Vector3(0, 0.06, 0)
		for i in count:
			var t := (i + 0.5) / count
			var a := -half + 2.0 * half * t if area.angle_degrees < 360.0 else TAU * t
			var edge := Vector3(sin(a), 0.0, -cos(a)) * area.radius * 0.95
			edge.y = 0.06
			var inward := (center - edge)
			inward.y = 0.0
			inward = inward.normalized()
			var arrow := _make_arrow()
			area.add_child(arrow)
			arrow.position = edge
			arrow.look_at(area.to_global(edge + inward), Vector3.UP)
			_telegraph_arrows.append({"node": arrow, "base": edge, "dir": inward})
			nodes.append(arrow)
	if (def.launch > 0.0 or def.pull > 0.0) and enemy.attack_range and not def.placed_on_party():
		# Red arrows over the area: sliding outward (it throws you away) or
		# towards the enemy (it drags you in). Mind what's behind you.
		var area := enemy.attack_range
		var half := deg_to_rad(area.angle_degrees) / 2.0
		var full := area.angle_degrees >= 360.0
		var count := 8 if full else 5
		if area.shape == EnemySkill.Shape.BAND and area.lanes > 1:
			count = area.lanes - 1 if area.lanes_in_gaps else area.lanes
		for i in count:
			var t := (i + 0.5) / count
			var a := TAU * t if full else -half + 2.0 * half * t
			var radial := Vector3(sin(a), 0.0, -cos(a))
			var straight := area.shape == EnemySkill.Shape.LINE or area.shape == EnemySkill.Shape.BAND or enemy.anchored
			if straight:
				radial = Vector3.FORWARD  # wall bosses push and pull straight across
			var reach := minf(area.radius, 6.0)
			var base := radial * reach * (0.55 if def.pull > 0.0 else 0.35)
			if straight:
				var span := area.width if area.shape != EnemySkill.Shape.CONE else minf(arena.size.x, 2.0 * area.radius)
				var across := (t - 0.5) * span * 0.8
				if area.shape == EnemySkill.Shape.BAND and area.lanes > 1:
					# One arrow down the middle of each lane (count = lanes).
					var part := area.width / (2 * area.lanes - 1)
					across = -area.width / 2.0 + (2 * mini(i, area.lanes - 1) + (1 if area.lanes_in_gaps else 0) + 0.5) * part
				var near := area.inner_radius if area.shape == EnemySkill.Shape.BAND else 0.0
				if enemy.anchored:
					near = maxf(near, enemy.body_radius)  # clear of its body
				base = Vector3(across, 0.0, -near - 2.5)
			base.y = 0.07
			var dir := -radial if def.pull > 0.0 else radial
			var arrow := _make_arrow()
			# Pushes: dark red arrows; pulls: dark teal ones.
			(arrow.material_override as StandardMaterial3D).albedo_color = Color(0.02, 0.4, 0.38, 0.95) if def.pull > 0.0 else Color(0.75, 0.02, 0.02, 0.95)
			area.add_child(arrow)
			arrow.position = base
			arrow.look_at(area.to_global(base + dir), Vector3.UP)
			arrow.scale = Vector3(1.7, 1.0, 1.7)  # big and dark: it has to read over any area color
			_telegraph_arrows.append({"node": arrow, "base": base, "dir": dir})
			nodes.append(arrow)
	nodes.append_array(_follow_up_preview(enemy, def))
	nodes.append_array(_shelter_marks(enemy, def))
	enemy.set_meta("telegraphs", nodes)


## A combo's next part, faintly, under the part being cast (Deep Breath shows
## Maw Bite's zone), once it's revealed. Areas placed on the party (lines,
## circles under you) aren't previewed: they'd follow you anyway.
func _follow_up_preview(enemy: Combatant, def: EnemySkill) -> Array:
	var next := def.follow_up
	if next == null or next.placed_on_party() or enemy.attack_range == null:
		return []
	var ghost := AttackRange.new()
	ghost.preview = true
	enemy.add_child(ghost)
	ghost.transform = enemy.attack_range.transform
	ghost.position.y += 0.01  # just above the area being cast
	ghost.show_skill(next)
	return [ghost]


## Wall bosses: while a whole-arena attack is cast, the floor each rock shelters
## (straight behind it, away from the wall) is drawn clear.
func _shelter_marks(enemy: Combatant, def: EnemySkill) -> Array:
	if not enemy.anchored or not def.fills_arena:
		return []  # only the big whole-arena breaths
	var fwd := enemy.flat_forward()
	var marks: Array = []
	for rock in arena.obstacles():
		if not rock.blocks_sight():
			continue
		var start := rock.global_position
		var depth_left := _depth_to_edge(start, fwd)
		if depth_left <= rock.radius:
			continue
		var quad := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		depth_left -= 0.3  # stop short of the edge line
		plane.size = Vector2(rock.radius * 2.0, depth_left)
		quad.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.72, 0.76, 0.8, 0.82)  # the floor's grey: no colour, no danger
		quad.material_override = mat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)
		var mid := start + fwd * depth_left / 2.0
		quad.global_position = Vector3(mid.x, 0.045, mid.z)
		quad.look_at(quad.global_position + fwd, Vector3.UP)
		marks.append(quad)
	return marks


## How far from a point to the arena's edge, straight along a direction.
func _depth_to_edge(point: Vector3, dir: Vector3) -> float:
	var b: Array = arena._bounds()
	var p := point - arena.global_position
	var best := 100.0
	if dir.x > 0.01:
		best = minf(best, (float(b[1]) - p.x) / dir.x)
	elif dir.x < -0.01:
		best = minf(best, (float(b[0]) - p.x) / dir.x)
	if dir.z > 0.01:
		best = minf(best, (float(b[3]) - p.z) / dir.z)
	elif dir.z < -0.01:
		best = minf(best, (float(b[2]) - p.z) / dir.z)
	return maxf(best, 0.0)


func _clear_telegraphs(enemy: Combatant) -> void:
	for node in enemy.get_meta("telegraphs", []):
		if is_instance_valid(node):
			for entry in _telegraph_arrows.duplicate():
				if entry["node"] == node:
					_telegraph_arrows.erase(entry)
			node.queue_free()
	enemy.set_meta("telegraphs", [])


## A flat gold chevron pointing forward (-Z), lying on the floor.
func _make_arrow() -> MeshInstance3D:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.45), Vector3(0.38, 0, 0.1), Vector3(0.18, 0, 0.1),
		Vector3(0, 0, -0.45), Vector3(0.18, 0, 0.1), Vector3(0, 0, -0.15),
		Vector3(0, 0, -0.45), Vector3(-0.18, 0, 0.1), Vector3(-0.38, 0, 0.1),
		Vector3(0, 0, -0.45), Vector3(0, 0, -0.15), Vector3(-0.18, 0, 0.1),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.9, 0.4, 0.9)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Arrows slide inward and fade, over and over; spheres bob up and down.
func _animate_telegraphs(delta: float) -> void:
	_telegraph_time += delta
	var cycle := fmod(_telegraph_time * 1.3, 1.0)
	for entry in _telegraph_arrows:
		var arrow: MeshInstance3D = entry["node"]
		if not is_instance_valid(arrow):
			continue
		arrow.position = entry["base"] + (entry["dir"] as Vector3) * cycle * 0.9
		(arrow.material_override as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - cycle * 0.8)
	for enemy in enemies:
		for node in enemy.get_meta("telegraphs", []):
			if is_instance_valid(node) and node.has_meta("bob"):
				node.position.y = 2.85 + sin(_telegraph_time * 5.0) * 0.08


# --- Enemy skill choice -----------------------------------------------------

## Picks the skill to prepare. Each skill starts from its weight, then the
## situation adjusts it: skills that can't reach anyone are unlikely, area
## skills placed on the party like a bunched-up party, healing needs hurt
## allies, Defense / Counter like someone standing close, and the skill used
## last time is less likely, so enemies mix their kit up. Partners with
## team_tactics pick something different from each other (see below).
func _choose_enemy_skill(enemy: Combatant) -> EnemySkill:
	if enemy.forced_skill != null:
		return enemy.forced_skill
	var pool: Array[EnemySkill] = enemy.skills if not enemy.skills.is_empty() else Combatant._basic_skills()
	var sure := _sure_hp_skill(enemy, pool)
	if sure != null:
		return sure
	var target := _enemy_target(enemy)
	var members := _standing(party)
	var scores: Array[float] = []
	var total := 0.0
	var hp_share := float(enemy.hp) / maxf(enemy.max_hp, 1)
	for skill in pool:
		var score := float(skill.weight)
		if not skill.allowed_at_hp(hp_share):
			scores.append(0.0)  # another phase's skill (Gale Maw under half HP)
			continue
		match skill.special:
			EnemySkill.Special.HEAL_ALLIES:
				var hurt := 0
				for ally in _standing(enemies):
					if ally.hp < ally.max_hp * 0.75 and ally.global_position.distance_to(enemy.global_position) <= skill.radius + ally.body_radius:
						hurt += 1
				score = 0.0 if hurt == 0 else score * (1.0 + 0.5 * hurt)
			EnemySkill.Special.ON_EACH_TARGET:
				score *= 1.0 + 0.35 * mini(_close_pairs(members, skill.radius * 2.0), 3)
			EnemySkill.Special.LINE_TO_EACH:
				score *= 1.0 + 0.35 * mini(_lined_up_pairs(enemy, members), 3)
			EnemySkill.Special.ON_MARKED:
				# Better when others stand near its target.
				var near := 0
				for member in members:
					if target != null and member != target and member.global_position.distance_to(target.global_position) < skill.radius + member.body_radius:
						near += 1
				score *= 1.0 + 0.5 * mini(near, 3)
			EnemySkill.Special.GROWING:
				pass
			_:
				if skill.kind == Skills.Kind.DEFENSE or skill.kind == Skills.Kind.COUNTER:
					var close := false
					for member in members:
						if enemy.gap_to(member) <= 1.5:
							close = true
					score *= 1.6 if close else 0.5
				elif target != null:
					var reached := 0
					for member in members:
						if _skill_reaches(enemy, skill, member):
							reached += 1
					if skill.ceiling_circles > 0:
						pass  # Ceiling Burst falls all over the arena: always worth it
					elif not _skill_reaches(enemy, skill, target) and reached == 0:
						score *= 0.05  # can't reach anyone: almost never worth preparing
					elif not skill.shared_damage:
						score *= 1.0 + 0.25 * maxi(reached - 1, 0)
		if skill.rock_clear_weight > 0.0:
			# Golem's double Smash: likelier the more rocks have settled.
			var settled := 0
			for piece in _debris:
				if float(piece.get("age", 0.0)) >= skill.rock_settle_seconds:
					settled += 1
			score = score * 0.5 if _debris.is_empty() else score + skill.rock_clear_weight * settled
		score *= _tactics_factor(enemy, skill)
		if skill == enemy.last_skill:
			# Repeats get less likely the longer the streak runs.
			score *= pow(0.35, enemy.get_meta("repeat_streak", 1))
		scores.append(score)
		total += score
	if total <= 0.0:
		var allowed := pool.filter(func(s): return s.allowed_at_hp(hp_share))
		return allowed.pick_random() if not allowed.is_empty() else pool[randi() % pool.size()]
	var roll := randf() * total
	for i in pool.size():
		roll -= scores[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


## A skill with sure_below_hp the enemy has reached (by HP) and not used yet:
## it comes next, once. For a Ceiling Burst, any rocks it has already
## dropped count as used, so a Golem that rolled one early isn't made to
## repeat it.
func _sure_hp_skill(enemy: Combatant, pool: Array[EnemySkill]) -> EnemySkill:
	var done: Array = enemy.get_meta("sure_done", [])
	# Phases first: every threshold reached (and not yet used) is spent by one cast.
	for skill in pool:
		var due := false
		for share in skill.phase_at_hp:
			var key := "%s@%.2f" % [skill.skill_name, share]
			if done.has(key) or enemy.hp > enemy.max_hp * share:
				continue
			done.append(key)
			due = true
		if due:
			enemy.set_meta("sure_done", done)
			_count("phase_casts")
			return skill
	for skill in pool:
		if skill.sure_below_hp <= 0.0 or done.has(skill.skill_name):
			continue
		if enemy.hp > enemy.max_hp * skill.sure_below_hp:
			continue
		done.append(skill.skill_name)
		enemy.set_meta("sure_done", done)
		if skill.ceiling_circles > 0 and enemy.rock_bursts > 0:
			continue
		if (enemy.get_meta("skills_used", []) as Array).has(skill.skill_name):
			continue
		return skill
	return null


## Partners: other standing enemies of the same kind with team_tactics.
func _tactics_partners(enemy: Combatant) -> Array[Combatant]:
	var partners: Array[Combatant] = []
	if not enemy.team_tactics:
		return partners
	for ally in _standing(enemies):
		if ally != enemy and ally.team_tactics and ally.scene_file_path == enemy.scene_file_path:
			partners.append(ally)
	return partners


## team_tactics skill choice. Only the first partner in the fight uses
## Defense / Counter (the others almost never do), and never while another
## partner already holds a stance. While a partner prepares a Power Shot, the
## others favour Ranged Attack (safe only right next to the Kobold), so
## running in to dodge it can leave you in the open for the Power Shot unless
## you use a rock. A second Power Shot at the same time is unlikely, and the
## same Ranged Attack a little less likely, so they mix their threats.
func _tactics_factor(enemy: Combatant, skill: EnemySkill) -> float:
	var factor := 1.0
	var stance_skill := skill.kind == Skills.Kind.DEFENSE or skill.kind == Skills.Kind.COUNTER
	var partners := _tactics_partners(enemy)
	if stance_skill and not partners.is_empty() and enemies.find(partners[0]) < enemies.find(enemy):
		factor *= 0.1  # only the first of the partners uses stances
	for partner in partners:
		if partner.stance != Skills.NONE:
			if stance_skill:
				factor *= 0.1
			continue
		if partner.loaded_def == null or partner.loaded_skill == Skills.NONE:
			continue
		if partner.loaded_def == skill or partner.loaded_def.skill_name == skill.skill_name:
			# Two Power Shots at once would be brutal; two Ranged Attacks are fine.
			factor *= 0.25 if skill.kind == Skills.Kind.SMASH else 0.7
		elif not stance_skill and skill.kind != Skills.Kind.SMASH:
			factor *= 1.6  # partner has a Power Shot coming: add the other threat
	# Power Shots never become more common than usual (Round 2 should stay
	# approachable); the pairing comes from the others leaning away from them.
	return factor


## team_tactics timing: a normal attack prepared alongside a partner's Power
## Shot (either one may have been picked first) waits for it. While the Power
## Shot is still coming, the attack stays grey with a "NEXT" tag and its cast
## slows so it lands bait_gap_seconds after the Power Shot; once the Power
## Shot is done, it's revealed and the gap counts down.
func _link_bait(enemy: Combatant) -> void:
	if not enemy.team_tactics or enemy.loaded_def == null:
		return
	for partner in _tactics_partners(enemy):
		if not _still_casting(partner):
			continue
		if _is_bait_skill(enemy.loaded_def) and partner.loaded_def.kind == Skills.Kind.SMASH:
			_make_bait(enemy, partner)
			return
		if enemy.loaded_def.kind == Skills.Kind.SMASH and _is_bait_skill(partner.loaded_def) \
				and not partner.has_meta("bait_for"):
			_make_bait(partner, enemy)
			return


func _is_bait_skill(def: EnemySkill) -> bool:
	return def != null and def.kind == Skills.Kind.ATTACK and not def.is_mechanic()


func _make_bait(waiter: Combatant, shooter: Combatant) -> void:
	waiter.set_meta("bait_for", shooter)
	if waiter.has_meta("bait_left"):
		waiter.remove_meta("bait_left")
	var text := waiter.loaded_def.skill_name.to_upper() + "  -  NEXT"
	waiter.show_skill_text(text, Color(0.75, 0.75, 0.8) if not waiter.skill_revealed else waiter.loaded_def.color())


## Preparing a skill and not yet striking with it.
func _still_casting(enemy) -> bool:
	if not is_instance_valid(enemy) or enemy.is_down or enemy.loaded_def == null or enemy.loaded_skill == Skills.NONE:
		return false
	return not (_strike != null and _strike.enemy == enemy)


## True while a bait's partner still has its Power Shot coming.
func _bait_waiting(enemy: Combatant) -> bool:
	return enemy.has_meta("bait_for") and not enemy.has_meta("bait_left")


## Moves a bait from "waiting for the Power Shot" to "counting down the gap",
## and drops the link once the gap is over.
func _tick_bait(enemy: Combatant, seconds: float) -> void:
	if not enemy.has_meta("bait_for"):
		return
	if enemy.loaded_def == null or enemy.loaded_skill == Skills.NONE:
		enemy.remove_meta("bait_for")
		enemy.remove_meta("bait_left")
		return
	if not enemy.has_meta("bait_left"):
		if _still_casting(enemy.get_meta("bait_for")):
			return
		# The Power Shot is done (or was stopped): now the gap.
		enemy.set_meta("bait_left", bait_gap_seconds * battle_speed)
		if (enemy.timeline_pos >= reveal_at or _true_sight_up()) and not enemy.skill_revealed:
			_reveal_skill(enemy)
		elif enemy.skill_revealed:
			enemy.show_skill_text(enemy.loaded_def.skill_name.to_upper(), enemy.loaded_def.color())
		return
	enemy.set_meta("bait_left", float(enemy.get_meta("bait_left")) - seconds)


## Cast speed for a bait so it reaches the end of the bar on schedule (never
## faster than it would normally go). -1 when the enemy isn't a bait.
func _bait_speed(enemy: Combatant) -> float:
	if not enemy.has_meta("bait_for") or enemy.loaded_def == null:
		return -1.0
	var normal := 1.0
	if enemy.timeline_pos >= cast_zone_start:
		normal = enemy.loaded_def.cast_speed * enemy.cast_zone_speed * _stagger_slow(enemy.loaded_def)
	var left: float  # world seconds until it should reach the end
	if enemy.has_meta("bait_left"):
		left = float(enemy.get_meta("bait_left"))
	else:
		var shooter = enemy.get_meta("bait_for")
		if not _still_casting(shooter):
			return normal
		var shooter_rate: float = shooter.speed * time_scale * _cast_speed(shooter)
		left = maxf(TIMELINE_LENGTH - shooter.timeline_pos, 0.0) / maxf(shooter_rate, 0.001) + bait_gap_seconds * battle_speed
	var units := maxf(TIMELINE_LENGTH - enemy.timeline_pos, 0.0)
	var needed := units / maxf(left, 0.05) / maxf(enemy.speed * time_scale, 0.001)
	return clampf(needed, 0.02, normal)


## team_tactics movement: a push away from partners closer than
## tactics_spread (zero when none are that close).
func _tactics_spread(enemy: Combatant) -> Vector3:
	var push := Vector3.ZERO
	for partner in _tactics_partners(enemy):
		var away := enemy.global_position - partner.global_position
		away.y = 0.0
		var d := away.length()
		if d < enemy.tactics_spread:
			push += (away / maxf(d, 0.01)) * (1.0 - d / enemy.tactics_spread)
	return push


## Roughly whether a skill aimed at this member could reach them (the enemy
## turns toward its target while casting, so only distance matters).
func _skill_reaches(enemy: Combatant, skill: EnemySkill, member: Combatant) -> bool:
	var offset := member.global_position - enemy.global_position
	offset.y = 0.0
	var d := offset.length()
	match skill.shape:
		EnemySkill.Shape.BAND:
			return true  # wall bosses: strips across the whole arena
		EnemySkill.Shape.DONUT:
			return d >= skill.inner_radius - member.body_radius and d <= skill.radius + member.body_radius
		EnemySkill.Shape.LINE:
			return d <= skill.radius
	var reach := _growing_max(skill) if skill.special == EnemySkill.Special.GROWING else skill.radius
	return d <= reach + member.body_radius * 0.5


## True if one of the enemy's aimed skills (not the ones placed on party
## members) can reach someone from where it stands.
func _reaches_anyone(enemy: Combatant) -> bool:
	for skill in enemy.skills:
		if skill.special != EnemySkill.Special.NONE or skill.kind == Skills.Kind.DEFENSE \
				or skill.kind == Skills.Kind.COUNTER:
			continue
		for member in _standing(party):
			if _skill_reaches(enemy, skill, member):
				return true
	return false


## Pairs of party members standing within `distance` of each other.
func _close_pairs(members: Array[Combatant], distance: float) -> int:
	var pairs := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			if members[i].global_position.distance_to(members[j].global_position) < distance:
				pairs += 1
	return pairs


## Pairs of party members in nearly the same direction from the enemy.
func _lined_up_pairs(enemy: Combatant, members: Array[Combatant]) -> int:
	var pairs := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a := members[i].global_position - enemy.global_position
			var b := members[j].global_position - enemy.global_position
			a.y = 0.0
			b.y = 0.0
			if a.length() > 0.1 and b.length() > 0.1 and rad_to_deg(a.angle_to(b)) < 15.0:
				pairs += 1
	return pairs


# --- Strikes, Parry and Defend --------------------------------------------

## mods: who is hit and how (see Strike.mods). windup < 0 uses the skill's.
func _begin_strike(enemy: Combatant, mods: Dictionary, reset_timeline: bool, windup: float = -1.0,
		hits_left: int = -1) -> void:
	var s := Strike.new()
	s.enemy = enemy
	s.skill = enemy.loaded_skill
	s.def = enemy.loaded_def
	s.mods = mods
	var targets: Array[Combatant] = []
	for target in mods:
		targets.append(target)
	s.targets = targets
	s.hits_left = (s.def.hits - 1) if hits_left < 0 else hits_left
	s.windup = s.def.windup if windup < 0.0 else windup
	if s.def.is_mechanic():
		s.windup = minf(s.windup, unavoidable_impact_seconds)  # nothing to react to: a short beat, then it lands
	s.time_left = s.windup
	s.reset_timeline = reset_timeline
	s.follow_windup = s.def.windup * 0.55
	for target in targets:
		if s.def.is_mechanic():
			# Unavoidable: no timing ring to react to, just a red mark on
			# everyone about to be hit.
			var mark := _make_ring(target.body_radius + 0.3, 0.12, Color(1.0, 0.2, 0.15, 0.85))
			target.add_child(mark)
			s.markers.append(mark)
			continue
		if not (s.def.parryable() and _covered(target, "parry")):
			# Can't Parry this (class or skill): no timing ring to chase, just
			# a mark: blue if Defend works, red if nothing does.
			var can_defend := s.def.blockable() and _covered(target, "block")
			var mark_color := Color(0.35, 0.65, 1.0, 0.85) if can_defend else Color(1.0, 0.2, 0.15, 0.85)
			var plain := _make_ring(target.body_radius + 0.3, 0.12, mark_color)
			target.add_child(plain)
			s.markers.append(plain)
			continue
		# A fixed white marker shows where the ring will land; the ring
		# shrinks onto it and turns gold when it's time to parry.
		var ring_radius := target.body_radius + 0.3
		var marker := _make_ring(ring_radius, 0.06, Color(1, 1, 1, 0.7))
		var ring := _make_ring(ring_radius, 0.1, Color.WHITE)
		target.add_child(marker)
		target.add_child(ring)
		s.markers.append(marker)
		s.rings.append(ring)
		for k in range(1, s.hits_left + 1):
			var later := _make_ring(ring_radius, 0.07, Color(1, 1, 1, 0.45))
			later.set_meta("hit", k)
			later.visible = false
			target.add_child(later)
			s.future_rings.append(later)
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
	# Later hits: each ring shrinks at the speed of its own wind-up, so it
	# lands on the marker exactly when that hit does (rings appear from the
	# outside as they get close).
	for ring in _strike.future_rings:
		var k: int = ring.get_meta("hit")
		var time_to_hit := maxf(_strike.time_left, 0.0) + k * _strike.follow_windup
		var scale_factor := 1.0 + 2.0 * time_to_hit / _strike.follow_windup
		ring.visible = scale_factor <= 5.5
		ring.scale = Vector3(scale_factor, 1.0, scale_factor)
		var later_color := Color(0.35, 0.65, 1.0) if _strike.reaction == Reaction.DEFEND else Color.WHITE
		later_color.a = 0.5 if k == 1 else 0.3
		(ring.material_override as StandardMaterial3D).albedo_color = later_color
	if _strike.time_left <= 0.0:
		_resolve_strike()


## E: a Parry. Only one try per strike.
func _try_parry() -> void:
	if _strike.reaction != Reaction.NONE or _strike.def.is_mechanic():
		return  # unavoidable hits don't ask for a reaction
	var can_parry := _strike.def.parryable() and _strike_targets_can("parry")
	if not can_parry:
		# Nobody here can Parry this, but someone can block (the Cleric):
		# the Parry key Defends instead.
		if _parry_key_defends():
			_try_defend()
			return
		if not _strike.def.parryable():
			_flash("%s can't be parried!" % _strike.def.skill_name)
		else:
			_flash("%s can't parry" % _names(_strike.targets))
		return
	if _parry_key_defends():
		# A mixed group (Knight + Cleric): the Parry is for those who can, a
		# Defend (same AP cost) for those who can only block.
		if ap >= defend_cost and not _strike.parry_defends:
			ap -= defend_cost
			_strike.parry_defends = true
	if _strike.time_left <= parry_window:
		_strike.reaction = Reaction.PARRY
	else:
		_strike.reaction = Reaction.PARRY_MISSED
		Sfx.play("parry_fail")
		for target in _strike.targets:
			if _covered(target, "parry"):
				_popup(target, "MISS", Color(1.0, 0.35, 0.3))  # too early: said at once, over their head


## True if a target can't Parry this strike but can block it.
func _parry_key_defends() -> bool:
	if not _strike.def.blockable():
		return false
	for target in _strike.targets:
		var parries := _covered(target, "parry") and _strike.def.parryable()
		if not parries and _covered(target, "block") and not _strike.mods.get(target, {}).get("unblockable", false):
			return true
	return false


## Q: Defend. Costs AP, can't be combined with a parry attempt.
func _try_defend() -> void:
	# A push or a pull can always be braced against (shorter move), even when
	# its damage can't be blocked.
	var moves := _strike.def.launch > 0.0 or _strike.def.pull > 0.0
	if _strike.reaction != Reaction.NONE or (_strike.def.is_mechanic() and not moves):
		return
	if not _strike.def.blockable() and not moves:
		_flash("%s can't be blocked!" % _strike.def.skill_name)
		return
	if not _strike_targets_can("block"):
		_flash("%s can't block" % _names(_strike.targets))
		return
	if ap < defend_cost:
		_flash("Not enough AP to defend (%d needed)" % defend_cost)
		return
	ap -= defend_cost
	_strike.reaction = Reaction.DEFEND


func _resolve_strike() -> void:
	var s := _strike
	_strike = null
	for node in s.rings + s.markers + s.future_rings:
		node.queue_free()

	var skill_name := s.def.skill_name
	var base_damage := s.def.damage
	var lines: PackedStringArray = []
	var parried := false
	s.enemy.animate("attack")
	var parry_missed := false
	var final_hit := s.hits_left <= 0
	var thrown: Array[Combatant] = []
	var pulled: Array[Combatant] = []
	var avoidable: Array[Combatant] = []  # took a hit they could have avoided
	if s.def.hits > 1:
		lines.append("%s %d/%d" % [skill_name, s.def.hits - s.hits_left, s.def.hits])
	# Looks: a heavy blow sends a shockwave from the enemy as it lands.
	var heavy_blow := s.def.damage >= 40 or s.skill == Skills.Kind.SMASH
	BattleSounds.enemy_strike(s.enemy, s.def)
	if heavy_blow and not s.def.placed_on_party() and not s.def.fills_arena \
			and (s.def.shape == EnemySkill.Shape.CIRCLE or s.def.shape == EnemySkill.Shape.CONE):
		SpellFx.enemy_blow(self, s.enemy, s.def.color(), minf(s.def.radius, 6.0))

	# One Parry/Defend input covers everyone hit, but only those whose class
	# can parry/block get the benefit; the rest take the full hit.
	for target in s.targets:
		var mod: Dictionary = s.mods.get(target, {})
		var damage := ceili(base_damage * float(mod.get("mult", 1.0)))
		if s.def.lethal:
			damage = (target.hp + target.shield) * 2 + 1  # Doom Gaze: through barriers and Brace
		var one_hp: bool = mod.get("one_hp", false)
		if target.riposte_left > 0.0 and s.def.parryable():
			_riposte(target, s.enemy, lines)
			continue
		if target.auto_parry_with_marks and s.def.parryable() and _marks_out() > 0:
			# Assassin: a Mark is spent and the strike is parried for it.
			_spend_mark(s.enemy)
			parried = true
			_count("auto_parries")
			if playtest:
				playtest.parried(s.enemy, skill_name)
			_popup(target, "AUTO-PARRY!", Color(0.78, 0.45, 1.0))
			SpellFx.enemy_hit(self, s.enemy, target, s.def.color(), heavy_blow, "parry")
			lines.append("%s auto-parries %s's %s (a Mark is spent)" % [target.display_name, s.enemy.display_name, skill_name])
			continue
		var can_parry := _covered(target, "parry") and s.def.parryable()
		var can_block: bool = _covered(target, "block") and s.def.blockable() and not mod.get("unblockable", false)
		if s.reaction == Reaction.PARRY and can_parry:
			parried = true
			if playtest:
				playtest.parried(s.enemy, skill_name)
			_popup(target, "PARRY!", Color(1.0, 0.85, 0.2))
			target.animate("parry")
			SpellFx.enemy_hit(self, s.enemy, target, s.def.color(), heavy_blow, "parry")
			lines.append("%s parried %s's %s!" % [target.display_name, s.enemy.display_name, skill_name])
			continue
		if one_hp:
			# Caught where the circles overlap: down to 1 HP (Arcane Barrier still saves).
			if target.statuses.has("arcane_barrier"):
				target.statuses.erase("arcane_barrier")
				lines.append("%s's barrier absorbs it" % target.display_name)
			else:
				target.recoverable = 0
				if playtest and target.hp > 1:
					playtest.hurt(target, target.hp - 1, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
				target.hp = mini(target.hp, 1)
				if _avoidable_hit(s.enemy, s.def, s.mods, target, s.targets):
					avoidable.append(target)
				_popup(target, "1 HP!", Color(1.0, 0.3, 0.2))
				lines.append("%s is caught in the overlap: down to 1 HP!" % target.display_name)
		elif (s.reaction == Reaction.DEFEND or (s.parry_defends and not can_parry)) and can_block:
			_count("defends")
			var share := defend_share_vs_smash if s.skill == Skills.Kind.SMASH else defend_share_vs_attack
			var taken := _hurt(target, ceili(damage * share), true, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
			if playtest:
				playtest.defended(s.enemy, skill_name)
			_popup(target, str(taken), Color(0.6, 0.8, 1.0))
			target.animate("defend")
			SpellFx.enemy_hit(self, s.enemy, target, s.def.color(), heavy_blow, "defend")
			BattleSounds.party_hit(s.enemy, s.def, heavy_blow, "defend")
			var guard_note := " Guard broken!" if s.skill == Skills.Kind.SMASH else ""
			lines.append("%s defended:%s -%d HP (recoverable)" % [target.display_name, guard_note, taken])
		else:
			var taken := _hurt(target, damage, false, "%s: %s" % [s.enemy.display_name, skill_name], s.enemy, skill_name)
			_popup(target, str(taken), Color(1.0, 0.4, 0.3))
			if taken > 0:
				SpellFx.enemy_hit(self, s.enemy, target, s.def.color(), heavy_blow, "hit")
				BattleSounds.party_hit(s.enemy, s.def, heavy_blow, "hit")
			if _avoidable_hit(s.enemy, s.def, s.mods, target, s.targets):
				avoidable.append(target)
			if s.reaction == Reaction.PARRY_MISSED and can_parry:
				parry_missed = true
				_count("parries_too_early")
				_push_back(target, parry_miss_push)
			var extra := ""
			if float(mod.get("mult", 1.0)) > 1.0:
				extra = " (overlap: double damage)"
			elif float(mod.get("mult", 1.0)) < 1.0:
				extra = " (shared)"
			lines.append("%s's %s hits %s for %d!%s%s" % [s.enemy.display_name, skill_name, target.display_name, taken,
					extra, _absorb_note(damage, taken)])
		if final_hit and s.def.launch > 0.0 and not target.is_down:
			thrown.append(target)
		if final_hit and s.def.pull > 0.0 and not target.is_down:
			pulled.append(target)

	for target in thrown:
		var push := s.def.launch * _brace_share(s, target)
		var before := target.global_position
		if not target.is_down and push >= knockdown_push and push >= s.def.launch:  # braced: stays up
			_knock_down(target, s.enemy)  # before the push, so the body flies from here
		if s.enemy.anchored:
			# Wall boss: straight across the arena, away from its wall.
			_knock_away(target, target.global_position - s.enemy.flat_forward(), push)
		else:
			_knock_away(target, s.enemy.global_position, push)
		if not target.is_down and target.has_meta("knocked"):
			_knockdown_flight(target, before)
		if not target.is_down:
			_popup(target, "BRACED" if push < s.def.launch else "LAUNCHED", Color(1.0, 0.6, 0.3))
			_wind(s.enemy, target, lines)
	for target in pulled:
		var drag := s.def.pull * _brace_share(s, target)
		if s.enemy.anchored and s.def.special != EnemySkill.Special.LINE_TO_EACH:
			_pull_to_wall(target, s.enemy, drag)
		else:
			_pull_toward(target, s.enemy.global_position, drag, s.enemy.body_radius + target.body_radius + 0.2)
		if not target.is_down:
			_popup(target, "BRACED" if drag < s.def.pull else "PULLED", Color(1.0, 0.6, 0.3))
			_wind(s.enemy, target, lines)
	if final_hit:
		_crack_rocks(s.enemy, s.def)

	# Parry sounds: a clang per Parry (two notes taking turns along a chain),
	# a Perfect Parry for the last of a fully parried multi-hit strike.
	var step := s.def.hits - s.hits_left
	if s.def.hits <= 1 or step <= 1:
		_parry_clean = true
	if not parried:
		_parry_clean = false
	elif s.def.hits > 1 and final_hit and _parry_clean:
		Sfx.play("parry_perfect")
	else:
		Sfx.play("parry_a" if step % 2 == 1 else "parry_b")
	if parried:
		# Every hit of a multi-hit strike can be parried, and each Parry grows
		# max AP; the enemy is knocked back once per strike.
		_count("parries")
		if not s.enemy.get_meta("staggered_chain", false):
			s.enemy.set_meta("staggered_chain", true)
			s.enemy.timeline_penalty += stagger_push
			lines.append("%s is knocked back" % s.enemy.display_name)
		lines.append(_grow_max_ap(parry_max_ap_gain, s.targets[0]))
		for target in s.targets:
			if target.climbs() and target.statuses.has("provoking") and not target.is_down:
				lines.append(_give_token(target, "Rush", "Provoke Parry"))
	if parry_missed:
		ap = 0.0
		lines.append("Parry too early! Turn delayed, AP lost")
		for target in s.targets:
			if target.climbs() and target.can_parry:
				var slip := _monk_slip(target)
				if slip != "":
					lines.append(slip)
		var reset_note := _reset_max_ap()
		if reset_note != "":
			lines.append(reset_note)

	if not avoidable.is_empty() and not parry_missed and not s.enemy.get_meta("ap_penalty_done", false):
		# Once per strike (a 3-hit Combo costs one segment, not three).
		s.enemy.set_meta("ap_penalty_done", true)
		for member in avoidable:
			if member.climbs():
				var slip := _monk_slip(member)
				if slip != "":
					lines.append(slip)
		var note := _lose_max_ap_for_hit(avoidable)
		if note != "":
			lines.append(note)
		if playtest:
			playtest.avoidable(s.enemy, skill_name)

	for target in s.targets:
		if target.is_down:
			lines.append("%s is down!" % target.display_name)

	# Multi-hit skills: the next hit follows quickly (a Parry doesn't stop
	# it: each hit has its own ring to Parry).
	if s.hits_left > 0 and not s.enemy.is_down:
		var next_mods := {}
		for target in s.targets:
			if not target.is_down:
				next_mods[target] = s.mods.get(target, {})
		if not next_mods.is_empty() and not _standing(party).is_empty():
			_flash("\n".join(lines))
			_check_party()
			_begin_strike(s.enemy, next_mods, s.reset_timeline, s.follow_windup, s.hits_left - 1)
			if s.reaction == Reaction.DEFEND:
				_strike.reaction = Reaction.DEFEND  # one Defend (one AP payment) guards the whole chain
			_strike.parry_defends = s.parry_defends  # so does the Cleric's Defend through the Parry key
			return
	_leave_hazards(s.enemy)
	if s.def.follow_up != null and not s.def.push_out and not s.enemy.is_down and not _standing(party).is_empty():
		_start_follow_up(s.enemy, s.def, s.reset_timeline)  # Deep Breath: the bite comes next
	else:
		_finish_enemy_skill(s.enemy, s.reset_timeline)
	_flash("\n".join(lines))
	print(" / ".join(lines))
	_check_party()
	_check_enemies()
	strike_finished.emit()


## Would taking this hit (no Parry, no Defend) have been avoidable?
## Dodgeable skills: always. Mechanic skills: only if the answer was missed
## (caught in an overlap, not stacked, not alone, not contained).
func _avoidable_hit(enemy: Combatant, def: EnemySkill, mods: Dictionary, target: Combatant, targets: Array) -> bool:
	if not def.is_mechanic():
		return true
	var mod: Dictionary = mods.get(target, {})
	if float(mod.get("mult", 1.0)) > 1.0 or mod.get("one_hp", false):
		return true  # overlap
	if def.shared_damage and targets.size() == 1 and _standing(party).size() > 1:
		return true  # took a stack mechanic alone
	if def.special == EnemySkill.Special.ON_MARKED and targets.size() > 1:
		return true  # the marked one wasn't alone
	if def.hits_everyone and not enemy.contained:
		return true  # never contained
	return false


## An avoidable hit landed: one segment (100) of bonus max AP cracks off.
## Returns a message ("" if there was no bonus to lose).
func _lose_max_ap_for_hit(who: Array) -> String:
	_count("avoidable_hits")
	if who.has(controlled):
		_count("avoidable_hits_you")  # the end screen's Reading score counts these
	if current_max_ap <= max_ap or avoidable_hit_max_ap_loss <= 0.0:
		return ""
	var before := current_max_ap
	if ap_meter:
		ap_meter.loss_text = "AVOIDABLE HIT"
	current_max_ap = maxf(current_max_ap - avoidable_hit_max_ap_loss, max_ap)
	ap = minf(ap, current_max_ap)
	var names: PackedStringArray = []
	for member in who:
		names.append(member.display_name)
	return "Avoidable hit on %s: max AP -%d (now %d)" % [", ".join(names), roundi(before - current_max_ap), int(current_max_ap)]


## True while someone stands where a revealed strike would cost max AP
## (the meter's top segment pulses red as a warning).
func _max_ap_at_risk() -> bool:
	if current_max_ap <= max_ap or avoidable_hit_max_ap_loss <= 0.0:
		return false
	for enemy in enemies:
		if enemy.is_down or not _is_live_threat(enemy):
			continue
		var mods := _strike_targets(enemy, true)
		var targets := mods.keys()
		for target in targets:
			if _avoidable_hit(enemy, enemy.loaded_def, mods, target, targets):
				return true
	return false


## A party member loses HP, recorded for the play-test report.
## Returns the HP actually lost (after barriers and shields).
func _hurt(member: Combatant, amount: int, recoverable: bool, source: String,
		enemy: Combatant = null, skill_name: String = "") -> int:
	var was_down := member.is_down
	if enemy != null and enemy.boss and boss_damage_mult != 1.0:
		amount = ceili(amount * boss_damage_mult)
	var taken := member.take_damage(amount, recoverable)
	if taken > 0 and member.team == Combatant.Team.PARTY:
		member.animate("hit_heavy" if taken >= member.max_hp * 0.2 or (enemy != null and _strong_blow(enemy)) else "hit")
	if playtest:
		playtest.hurt(member, taken, source, enemy, skill_name)
		if member.is_down and not was_down:
			playtest.down(member)
	if member.is_down and not was_down and not member.get_meta("fell", false):
		_start_ragdoll(member, enemy)
	elif taken > 0 and not member.is_down and not recoverable and _crushing_blow(enemy):
		# (Defended damage is recoverable: a Defend keeps you on your feet.)
		_knock_down(member, enemy)
	return taken


# --- Ragdolls ----------------------------------------------------------------

## A downed party member goes limp. A strong blow (a push, a Smash, 40+
## damage, an instant kill) sends the body flying away from the enemy,
## tumbling, bouncing once and sliding to a stop; anything else (small
## hits, burns, hazards) makes it flop over where it stands.
@export var ragdoll_fly_speed: float = 7.5
@export var ragdoll_fly_up: float = 8.0
var _ragdolls: Array[Dictionary] = []


## Knockdowns: a party member hit by a crushing blow (see _crushing_blow) or
## pushed knockdown_push metres or more goes down in a heap for
## knockdown_seconds, then gets up. Meanwhile it can't walk, but its
## timeline runs on: a turn that comes up waits until it's up, and an attack
## it was about to make gets knockdown_grace extra seconds to walk back in.
@export var knockdown_seconds: float = 1.4
@export var knockdown_push: float = 2.5
@export var knockdown_grace: float = 1.5
## The last part of a knockdown: the body eases back up onto its feet.
@export var knockdown_rise: float = 0.4


func _knock_down(member: Combatant, enemy: Combatant) -> void:
	if member.team != Combatant.Team.PARTY or member.is_down or member.get_meta("fell", false):
		return
	if enemy != null and enemy.anchored and enemy.loaded_def != null and enemy.loaded_def.fills_arena:
		return  # a wall boss's whole-arena breath (Inhale, Exhale) shoves, never floors
	if member.has_meta("knocked"):
		member.set_meta("knocked", maxf(float(member.get_meta("knocked")), knockdown_seconds))
		var rig := member.get_node_or_null("Limp") as Ragdoll
		if rig != null and rig.blending():
			rig.launch(Vector3.UP * 2.0, Vector3.ZERO)  # floored again as it got up
		return
	member.set_meta("knocked", knockdown_seconds)
	_popup(member, "KNOCKED DOWN", Color(1.0, 0.6, 0.3))
	_count("knockdowns")
	_start_ragdoll(member, enemy, true)


## A knocked-down member that was also pushed: the push moved it at once
## (the fight goes by where it lands); its ragdoll flies there, a lob that
## lands about where the push put it, higher the further it goes.
func _knockdown_flight(member: Combatant, from: Vector3) -> void:
	if _teetering(member):
		# Pushed to the brink: it's teetering (Parry to catch itself), not lying.
		member.remove_meta("knocked")
		member.unlimp()
		return
	var to := member.global_position
	var meters := Vector2(to.x - from.x, to.z - from.z).length()
	if meters < 0.3:
		return
	var rig := member.get_node_or_null("Limp") as Ragdoll
	if rig == null:
		return
	var seconds := clampf(0.3 + meters * 0.07, 0.4, 0.85)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * Ragdoll.GRAVITY_SCALE
	var across := Vector3(to.x - from.x, 0.0, to.z - from.z) / seconds
	var away := across.normalized()
	rig.launch(across + Vector3.UP * gravity * seconds * 0.5, Vector3.UP.cross(away) * randf_range(5.0, 8.0))
	if meters >= 2.0:
		rig.land_sound = "land_thrown"  # sent far
	member.set_meta("knocked", float(member.get_meta("knocked")) + seconds)


func _tick_knockdowns(delta: float) -> void:
	for member in party:
		if not member.has_meta("knocked"):
			continue
		if member.is_down:
			member.remove_meta("knocked")
			continue
		var left := float(member.get_meta("knocked")) - delta
		if left > 0.0:
			member.set_meta("knocked", left)
			continue
		member.remove_meta("knocked")
		member.unlimp()
		if member.has_meta("windup_target"):
			# It was about to attack: extra time to walk back in.
			member.set_meta("windup_grace", -knockdown_grace)


## A blow that knocks a living party member down by itself: a Smash or 40+
## damage. (Launches knock down by how far they push: see the launch loop.)
func _crushing_blow(enemy: Combatant) -> bool:
	if enemy == null or enemy.loaded_def == null:
		return false
	return enemy.loaded_def.kind == Skills.Kind.SMASH or enemy.loaded_def.damage >= 40


func _strong_blow(enemy: Combatant) -> bool:
	if enemy == null or enemy.loaded_def == null:
		return false
	var def := enemy.loaded_def
	return def.launch > 0.0 or def.kind == Skills.Kind.SMASH or def.damage >= 40 or def.lethal


func _start_ragdoll(member: Combatant, enemy: Combatant, alive := false) -> void:
	for rag in _ragdolls:
		if rag["member"] == member:
			return
	var away := Vector3.ZERO
	if enemy != null:
		away = member.global_position - enemy.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = -member.flat_forward()
	away = away.normalized()
	var fly := _strong_blow(enemy) or alive
	var rig := member.make_limp() as Ragdoll
	if rig == null:
		return
	# Spinning about the axis across the blow tips it over away from it.
	var axis := Vector3.UP.cross(away).normalized()
	if alive:
		# Knocked down: off its feet, about where it stood.
		rig.launch(away * 1.6 + Vector3.UP * 3.5, axis * randf_range(5.0, 7.0))
	elif fly:
		# Knocked out by a big blow: thrown.
		rig.launch(away * ragdoll_fly_speed + Vector3.UP * ragdoll_fly_up, axis * randf_range(7.0, 11.0))
	else:
		# Anything else: it crumples where it stands.
		rig.launch(away * 0.9 + Vector3.UP * 0.6, axis * 5.0)
	rig.land_sound = "land_thrown" if fly and not alive else "land_light"
	_ragdolls.append({"member": member, "pivot": rig, "fly": fly, "alive": alive, "t": 0.0})
	_count("ragdolls_flying" if fly else "ragdolls_flop")


## Ragdolls (physics: see Ragdoll). A knocked-out member's position follows
## its torso (where a Revive finds it); once it lies still it's frozen. A
## knocked-down one eases back up at the end of its knockdown.
func _tick_ragdolls(delta: float) -> void:
	for rag in _ragdolls.duplicate():
		if not is_instance_valid(rag["member"]) or not is_instance_valid(rag["pivot"]):
			_ragdolls.erase(rag)  # gone (or back up: the rig is freed)
			continue
		var member: Combatant = rag["member"]
		var rig: Ragdoll = rag["pivot"]
		if member.get_meta("fell", false):
			member.unlimp()  # over a drop: the whole figure falls (see _fall)
			_ragdolls.erase(rag)
			continue
		rag["t"] = float(rag["t"]) + delta
		if rag["alive"]:
			if member.is_down:
				rag["alive"] = false  # knocked out while down: it stays down
			elif not member.has_meta("knocked"):
				_ragdolls.erase(rag)  # back up
				continue
			else:
				var left := float(member.get_meta("knocked"))
				if left <= knockdown_rise and not rig.blending():
					rig.blend_to_stand(left)
				continue
		if not member.is_down:
			_ragdolls.erase(rag)  # revived
			continue
		var at := rig.torso.global_position
		if arena.walkable(Vector3(at.x, 0.0, at.z), member.body_radius):
			member.global_position = Vector3(at.x, member.global_position.y, at.z)
		if float(rag["t"]) > 0.6 and rig.settled() or float(rag["t"]) > 4.0:
			rig.freeze_all()
			_ragdolls.erase(rag)


## Saves the play-test report once per fight (not in the tutorial).
func _save_playtest(result: String) -> void:
	if playtest == null or playtest.saved:
		return
	if result == "Left early" and playtest.turns.is_empty():
		playtest.saved = true  # left before anything happened: nothing to report
		return
	var path: String = playtest.save(result, stats, party, enemies)
	if path != "":
		print("Play-test report: %s" % path)


## Handles knocked-out fighters: hands control back if needed, and ends
## the battle if nobody is left standing.
## True if anyone caught in the strike can "parry" or "block" it.
func _strike_targets_can(reaction: String) -> bool:
	for target in _strike.targets:
		if _covered(target, reaction):
			return true
	return false


## True if this fighter can "parry" or "block": its own class can, or a
## Knight guarding with Taunt stands within guard_radius of it.
func _covered(target: Combatant, reaction: String) -> bool:
	if target.can_parry if reaction == "parry" else target.can_block:
		return true
	for guard in _standing(party):
		if guard != target and guard.statuses.has("guarding") \
				and (guard.can_parry if reaction == "parry" else guard.can_block) \
				and guard.global_position.distance_to(target.global_position) <= guard_radius:
			return true
	return false


## " (Brace / shield soaked 12)" when less HP was lost than the hit dealt.
func _absorb_note(damage: int, taken: int) -> String:
	return " (%d soaked)" % (damage - taken) if taken < damage else ""


## Archer's Riposte: the hit is countered, the enemy hurt and pushed away.
func _riposte(archer: Combatant, enemy: Combatant, lines: PackedStringArray) -> void:
	var damage := ceili(archer.attack_power * 2.0)
	var dealt := enemy.take_damage(damage, false)
	_add_threat(enemy, archer, dealt)
	if playtest:
		playtest.deal(archer, dealt)
	_popup(archer, archer.counter_name.to_upper() + "!", Color(1.0, 0.85, 0.2))
	_popup(enemy, str(damage), Color.WHITE)
	_knock_away(enemy, archer.global_position, 3.0)
	if archer.counter_name == "Suplex":
		lines.append("%s suplexes %s for %d and throws it" % [archer.display_name, enemy.display_name, damage])
		if archer.climbs():
			lines.append(_give_token(archer, "Mountain", "Suplex"))
	else:
		lines.append("%s ripostes! %s takes %d and is pushed back" % [archer.display_name, enemy.display_name, damage])
		_hop_back(archer, enemy.global_position, riposte_hop)


## Riposte: the Archer springs away from the enemy she countered. Walls,
## rocks and drops stop her (she never hops over an edge).
func _hop_back(fighter: Combatant, from: Vector3, meters: float) -> void:
	var away := fighter.global_position - from
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -fighter.flat_forward()
	for i in 8:
		fighter.global_position += away.normalized() * meters / 8.0
		_keep_in_arena(fighter)


## True Sight: while any standing ally has it, enemy attacks show as soon as
## they start preparing.
func _true_sight_up() -> bool:
	for ally in _standing(party):
		if ally.statuses.has("true_sight"):
			return true
	return false


## Shoves a fighter straight away from a point, stopping at walls and rocks.
func _knock_away(fighter: Combatant, from: Vector3, meters: float) -> void:
	if fighter.anchored:
		return
	meters *= fighter.knockback_taken  # Gust Sprites are light
	var away := fighter.global_position - from
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -fighter.flat_forward()
	SpellFx.dust(self, fighter, away.normalized(), meters)
	if fighter.lightweight:
		_knock_lightweight(fighter, away.normalized(), meters)
		return
	var steps := 8
	for i in steps:
		fighter.global_position += away.normalized() * meters / steps
		_keep_in_arena(fighter, true)
		if fighter.is_down or _teetering(fighter):
			return  # pushed over a drop


## Lightweight knock-back: small steps, so no hole is skipped; a wall,
## corner or rock bounces it off (it never sticks), and touching a hole or
## a drop with any part of its body makes it fall at once.
func _knock_lightweight(fighter: Combatant, dir: Vector3, meters: float) -> void:
	var left := meters
	var bounces := 0
	while left > 0.001 and not fighter.is_down:
		var stride := minf(left, 0.15)
		var want := fighter.global_position + dir * stride
		fighter.global_position = want
		if _check_choke(fighter):
			return  # knocked into an open mouth
		if _can_fall(fighter) and _touches_drop(fighter):
			_count("lightweight_falls")
			_fall(fighter)
			return
		arena.keep_inside(fighter, fighter.body_radius, arena.has_drops() and _can_fall(fighter))
		for wall_boss in _standing(enemies):
			# A wall boss's body is a wall too (its mouth closed).
			if not wall_boss.anchored:
				continue
			var off := fighter.global_position - wall_boss.global_position
			off.y = 0.0
			var need := wall_boss.body_radius + fighter.body_radius
			if off.length() < need and off.length() > 0.001:
				fighter.global_position = wall_boss.global_position + off.normalized() * need + Vector3(0, fighter.global_position.y - wall_boss.global_position.y, 0)
		var pushed_back := fighter.global_position - want
		pushed_back.y = 0.0
		if pushed_back.length() > 0.005:
			# Hit a wall or a rock: bounce off it (reflect over its normal).
			var n := pushed_back.normalized()
			dir = (dir - 2.0 * dir.dot(n) * n).normalized()
			bounces += 1
			if bounces == 1:
				_count("lightweight_bounces")
			if bounces > 6:
				return  # wedged in a corner: stop there
		left -= stride


## Gust Sprite fed to a wall boss: while its pull is being cast (Inhale,
## Deep Breath, Gale Draw: the mouth is open), a Lightweight enemy knocked
## against its body makes it choke: the sprite's Detonate goes off inside
## it (choke_damage_mult x the blast) and the boss is Staggered.
func _check_choke(sprite: Combatant) -> bool:
	if not sprite.lightweight or sprite.is_down:
		return false
	for boss in _standing(enemies):
		if not _mouth_open(boss):
			continue
		var off := sprite.global_position - boss.global_position
		off.y = 0.0
		if off.dot(boss.flat_forward()) <= 0.0 or off.length() > boss.body_radius + sprite.body_radius + choke_reach:
			continue
		_choke(boss, sprite)
		return true
	return false


## A wall boss with its mouth open: casting a whole-arena pull (Inhale,
## Deep Breath, Gale Draw). Shown as a black mouth on its body.
func _mouth_open(boss: Combatant) -> bool:
	return boss.anchored and not boss.is_down and boss.loaded_def != null and boss.loaded_skill != Skills.NONE \
			and boss.loaded_def.pull > 0.0 and boss.loaded_def.fills_arena


## The open mouth: a black disc on the wall boss's front while _mouth_open.
func _update_mouths() -> void:
	for enemy in enemies:
		if not enemy.anchored:
			continue
		var mouth: MeshInstance3D = enemy.get_meta("mouth") if enemy.has_meta("mouth") else null
		if mouth == null:
			mouth = MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 1.5
			disc.bottom_radius = 1.5
			disc.height = 0.12
			mouth.mesh = disc
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.02, 0.02, 0.03)
			mouth.material_override = mat
			mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			enemy.add_child(mouth)
			mouth.rotation_degrees = Vector3(90, 0, 0)  # the disc faces forward (-Z)
			mouth.position = Vector3(0.0, enemy.body_radius * 0.45, -enemy.body_radius - 0.03)
			enemy.set_meta("mouth", mouth)
		mouth.visible = _mouth_open(enemy)
		var nose := enemy.get_node_or_null("Nose") as Node3D
		if nose and not nose.has_meta("figure"):
			nose.visible = not mouth.visible  # the facing marker sits where the mouth opens


func _choke(boss: Combatant, sprite: Combatant) -> void:
	var blast := 0
	for def in sprite.skills:
		if def.self_destruct:
			blast = def.damage
	if sprite.loaded_skill != Skills.NONE:
		_finish_enemy_skill(sprite, false)
	sprite.unkillable = false
	sprite.hp = 0
	sprite._go_down()
	if sprite.attack_range:
		sprite.attack_range.visible = false
	_count("chokes")
	var dealt := boss.take_damage(roundi(blast * choke_damage_mult), false)
	_popup(boss, "CHOKES! %d" % dealt, Color(1.0, 0.55, 0.2))
	_flash("The %s chokes on the %s! It blows up inside it." % [boss.display_name, sprite.display_name], 3.5)
	if not boss.is_down and boss.loaded_def != null:
		_stagger(boss)
	_check_enemies()


## Any part of the body over a hole or a drop (its centre or its rim).
func _touches_drop(fighter: Combatant) -> bool:
	var at := fighter.global_position
	if arena.lethal_at(at):
		return true
	var r := fighter.body_radius * 0.9
	for k in 8:
		var angle := TAU * k / 8.0
		if arena.lethal_at(at + Vector3(cos(angle) * r, 0.0, sin(angle) * r)):
			return true
	return false


## Drags a fighter towards a point (boss pulls), stopping next to whoever is
## there. Being dragged across a hole or a lethal edge means falling.
func _pull_toward(fighter: Combatant, to: Vector3, meters: float, stop_gap: float) -> void:
	if fighter.anchored:
		return
	var toward := to - fighter.global_position
	toward.y = 0.0
	if toward.length() > 0.01:
		SpellFx.dust(self, fighter, toward.normalized(), minf(meters, toward.length() - stop_gap))
	var steps := 8
	for i in steps:
		var dir := to - fighter.global_position
		dir.y = 0.0
		var room := dir.length() - stop_gap
		if room <= 0.0:
			return
		fighter.global_position += dir.normalized() * minf(meters / steps, room)
		_keep_in_arena(fighter, true)
		if fighter.is_down or _teetering(fighter):
			return


## Defend against a push or pull: a Block-capable fighter (or one a
## guarding Knight covers) is moved defend_move_share as far.
func _brace_share(s: Strike, target: Combatant) -> float:
	var defends := s.reaction == Reaction.DEFEND or (s.parry_defends and not (_covered(target, "parry") and s.def.parryable()))
	if defends and _covered(target, "block"):
		_count("braced_moves")
		return defend_move_share
	return 1.0


## Over a drop: a party member teeters (Parry to catch yourself) unless
## Off-Balance from the last save; anyone else falls.
func _teeter_or_fall(fighter: Combatant) -> void:
	if fighter.team == Combatant.Team.PARTY and not fighter.statuses.has("off_balance"):
		_begin_edge_save(fighter)
	else:
		_fall(fighter)


## True while a fighter hangs over an edge waiting for its save.
func _teetering(fighter: Combatant) -> bool:
	return (not _edge_save.is_empty() and _edge_save["fighter"] == fighter) or _edge_queue.has(fighter)


## Wall boss pulls: straight toward its wall, stopping against its body.
func _pull_to_wall(fighter: Combatant, boss: Combatant, meters: float) -> void:
	SpellFx.dust(self, fighter, -boss.flat_forward(), meters)
	var steps := 8
	for i in steps:
		if fighter.gap_to(boss) <= 0.2:
			return
		fighter.global_position -= boss.flat_forward() * meters / steps
		_keep_in_arena(fighter, true)
		if fighter.is_down or _teetering(fighter):
			return


## A wall boss at the start: its centre on the middle of the far wall (half
## its body in the wall), facing into the arena.
func _anchor_to_wall(enemy: Combatant) -> void:
	var toward_party := arena.global_position - enemy.global_position
	toward_party.y = 0.0
	var wall_dir := -toward_party.normalized() if toward_party.length() > 0.1 else Vector3.FORWARD
	var depth := arena.size.y / 2.0 if absf(wall_dir.z) >= absf(wall_dir.x) else arena.size.x / 2.0
	var into := Vector3(0, 0, signf(wall_dir.z)) if absf(wall_dir.z) >= absf(wall_dir.x) else Vector3(signf(wall_dir.x), 0, 0)
	enemy.global_position = arena.global_position + into * depth
	enemy.anchored = false
	enemy.look_at(enemy.global_position - into, Vector3.UP)
	enemy.anchored = true


func _check_party() -> void:
	if _standing(party).is_empty():
		_game_over = true  # _update_ui shows the game-over text from now on
		_result_text = "The party has fallen..."
		_save_playtest("Defeat")
		print("Game over")
		return
	if active != null and active.team == Combatant.Team.PARTY and active.is_down:
		_end_turn()
	if controlled != null and controlled.is_down:
		_set_controlled(_standing(party)[0])


# --- Wall boss extras (the Gale Maw) ------------------------------------------

## Each action of a wall boss: broken rocks count down to growing back, and
## every few actions it calls up its summons.
func _wall_boss_acts(boss: Combatant) -> void:
	for rock in arena.get_children():
		if rock is ArenaObstacle and rock.broken and rock.has_meta("broken_by") and rock.get_meta("broken_by") == boss:
			var left := int(rock.get_meta("regrow_in", 0)) - 1
			rock.set_meta("regrow_in", left)
			if left <= 0:
				rock.regrow()
				_popup(rock, "ROCK REGROWS", Color(0.8, 0.75, 0.6))
				for c in combatants:
					if not c.is_down:
						_keep_in_arena(c)  # squeezed out of where it grew
	if boss.summon_scene == null or boss.summon_every <= 0:
		return
	var acts := int(boss.get_meta("acts", 0)) + 1
	boss.set_meta("acts", acts)
	if acts % boss.summon_every == 0:
		_summon(boss)


## Tops the wall boss's summons back up to summon_count.
func _summon(boss: Combatant) -> void:
	var mine: Array = boss.get_meta("summons", [])
	var standing := 0
	for c in mine:
		if is_instance_valid(c) and not c.is_down:
			standing += 1
	var made := 0
	for i in boss.summon_count - standing:
		var fighter := boss.summon_scene.instantiate() as Combatant
		var side := -1.0 if (standing + i) % 2 == 0 else 1.0
		var spot := boss.global_position + boss.flat_forward() * (boss.body_radius + 2.0) \
				+ boss.flat_forward().cross(Vector3.UP) * side * (boss.body_radius + 1.5)
		$Enemies.add_child(fighter)
		fighter.global_position = Vector3(spot.x, boss.global_position.y, spot.z)
		fighter.look_at(fighter.global_position + boss.flat_forward(), Vector3.UP)
		fighter.timeline_pos = randf_range(0.0, 20.0)
		fighter.set_meta("summoner", boss)
		if fighter.fuse_seconds > 0.0:
			fighter.set_meta("fuse_left", fighter.fuse_seconds)
		# Dead summons leave the lists (hidden, still in the tree).
		for old in mine.duplicate():
			if is_instance_valid(old) and old.is_down:
				mine.erase(old)
				enemies.erase(old)
				combatants.erase(old)
				old.process_mode = Node.PROCESS_MODE_DISABLED
				old.visible = false
		enemies.append(fighter)
		combatants.append(fighter)
		mine.append(fighter)
		_keep_in_arena(fighter)
		# Looks: the paw on that side flings it, and it flies in from there.
		var paw := boss.get_node_or_null("Body/ArmL" if side < 0.0 else "Body/ArmR") as Node3D
		if paw != null and fighter.anim != null:
			fighter.anim.fly_in(paw.global_position)
			boss.animate("throw", {"side": side})
		made += 1
	boss.set_meta("summons", mine)
	if made > 0:
		_count("summons")
		_flash("%s flings %d Gust Sprite%s! Too tough to beat down, but every hit knocks it back: into a hole or off the ledge." % [boss.display_name, made, "" if made == 1 else "s"])


## Fuses (Gust Sprites): counted in battle time from when it appeared. At
## zero its self_destruct skill is forced and cast at once (whatever it was
## preparing is dropped). An interrupt only delays it: it casts again.
func _tick_fuses(world_delta: float) -> void:
	for enemy in enemies:
		if enemy.is_down or not enemy.has_meta("fuse_left"):
			continue
		var left := float(enemy.get_meta("fuse_left"))
		if left <= 0.0:
			continue
		left -= world_delta
		enemy.set_meta("fuse_left", maxf(left, 0.0))
		if left > 0.0:
			if left < 5.0 and left + world_delta >= 5.0:
				_popup(enemy, "5 s!", Color(1.0, 0.45, 0.25))
			continue
		var boom: EnemySkill = null
		for def in enemy.skills:
			if def.self_destruct:
				boom = def
		if boom == null:
			continue
		enemy.forced_skill = boom
		if enemy.loaded_skill != Skills.NONE:
			_finish_enemy_skill(enemy, false)
		enemy.timeline_pos = cast_zone_start - 0.01  # starts casting it next frame
		_popup(enemy, "DETONATING!", Color(1.0, 0.35, 0.2))
		_flash("The %s is about to explode! Get away, or knock it off the edge first." % enemy.display_name)
		_count("fuses_out")


## Detonate landed: the caster is gone.
func _self_destruct(enemy: Combatant) -> void:
	_popup(enemy, "BOOM!", Color(1.0, 0.45, 0.2))
	_count("self_destructs")
	enemy.unkillable = false
	enemy.hp = 0
	enemy._go_down()
	if enemy.attack_range:
		enemy.attack_range.visible = false
	_check_enemies()


## Summons go down with the one who called them.
func _down_orphan_summons() -> void:
	for enemy in enemies:
		if not enemy.has_meta("summoner"):
			continue
		var boss: Combatant = enemy.get_meta("summoner")
		if is_instance_valid(boss) and boss.is_down and not enemy.is_down:
			enemy.hp = 0
			enemy._go_down()
			if enemy.attack_range:
				_finish_enemy_skill(enemy, false)
				enemy.attack_range.visible = false


## Winded: pushed or pulled by a wall boss, a party member loses ground on
## the timeline.
func _wind(boss: Combatant, target: Combatant, lines: PackedStringArray) -> void:
	if boss.winded_timeline <= 0.0 or target.team != Combatant.Team.PARTY or target.is_down:
		return
	_push_back(target, boss.winded_timeline)
	_count("winded")
	_popup(target, "WINDED", Color(0.75, 0.9, 1.0))
	lines.append("%s is winded" % target.display_name)


## A rock-breaking blast cracks every rock in its area; enough cracks and
## the rock crumbles (it grows back later).
func _crack_rocks(boss: Combatant, def: EnemySkill) -> void:
	if def == null or not def.breaks_rocks or boss.rock_regrow_turns <= 0 or boss.attack_range == null:
		return
	for rock in arena.obstacles():
		if rock.kind != ArenaObstacle.Kind.ROCK or not boss.attack_range.contains(rock.global_position, rock.radius):
			continue
		if rock.crack(boss.rock_crack_limit):
			rock.set_meta("broken_by", boss)
			rock.set_meta("regrow_in", boss.rock_regrow_turns)
			_count("rocks_broken")
			_popup(rock, "ROCK SHATTERS", Color(0.9, 0.8, 0.6))
			_flash("The blast shatters a rock!")
		else:
			_popup(rock, "CRACKED", Color(0.85, 0.8, 0.7))


## Below its crumble share, a wall boss's arena loses its lethal edges'
## outer strip (once). Anyone standing there teeters.
func _check_crumble() -> void:
	for boss in enemies:
		if not boss.anchored or boss.crumble_at_share <= 0.0 or boss.is_down or boss.get_meta("crumbled", false):
			continue
		if boss.hp > boss.max_hp * boss.crumble_at_share:
			continue
		boss.set_meta("crumbled", true)
		for bit in [Arena.SIDE_NORTH, Arena.SIDE_EAST, Arena.SIDE_SOUTH, Arena.SIDE_WEST]:
			if arena.lethal_sides & bit:
				arena.crumble(bit, boss.crumble_meters)
		_count("crumbles")
		_flash("The cliff edge crumbles away! The drop is %.1f m closer" % boss.crumble_meters, 4.0)
		for c in combatants:
			if not c.is_down and not c.boss and arena.lethal_at(c.global_position):
				_teeter_or_fall(c)


## Ends the battle in victory once every enemy is down.
func _check_enemies() -> void:
	if _game_over:
		return
	_check_crumble()
	_down_orphan_summons()
	for enemy in enemies:
		if enemy.is_down and enemy.attack_range and (enemy.attack_range.visible or enemy.attack_range.has_meta("faded_for_strike")):
			enemy.attack_range.remove_meta("faded_for_strike")
			_finish_enemy_skill(enemy, false)
			enemy.attack_range.visible = false
			for hazard in _hazards.duplicate():
				if hazard["owner"] == enemy:
					_remove_hazard(hazard)
	if _standing(enemies).is_empty():
		_game_over = true
		_result_text = "Tutorial complete!" if tutorial_mode else "Victory!"
		for enemy in enemies:
			enemy.set_meta("quiet_vanish", true)  # the bodies sink silently once it's won
		_start_victory_slowmo()
		_save_playtest("Victory")
		if boss_rush_mode:
			# Won: Continue picks up at the next round; after the last one the
			# Boss Rush is done and the save is cleared.
			if _round_index + 1 < boss_rush.rounds.size():
				SaveGame.save_round(_round_index + 1)
			else:
				SaveGame.clear()
		print("Victory")


## The last enemy down: the camera locks on it and the world slows while it
## falls; then the camera pans back to the party and the end panel shows.
func _start_victory_slowmo() -> void:
	if victory_slowmo_seconds <= 0.0 or Engine.time_scale > 1.0:
		return
	var last_ms := -1
	_finale_target = null
	for enemy in enemies:
		if enemy.is_down and int(enemy.get_meta("down_ms", 0)) >= last_ms:
			last_ms = int(enemy.get_meta("down_ms", 0))
			_finale_target = enemy
	if _finale_target == null:
		return
	_finale = 1
	_pan_time = _pan_duration  # no pan under way: the camera follows the fall
	_slowmo_left = victory_slowmo_seconds
	Engine.time_scale = victory_slowmo_scale


## Where the camera looks during the finale: the fallen enemy's body as it
## flies and tumbles (its ragdoll), else where it stood.
func _finale_point() -> Vector3:
	if not is_instance_valid(_finale_target):
		return _cam_focus
	var rig := _finale_target.get_node_or_null("Limp") as Ragdoll
	var at := rig.torso.global_position if rig != null and is_instance_valid(rig.torso) else _finale_target.global_position
	return Vector3(at.x, 0.0, at.z)


## Holds the slow motion until its time is up (a Perfect's hit-stop ending
## in the meantime would put the speed back), then lets go.
func _tick_slowmo(delta: float) -> void:
	if _slowmo_left <= 0.0:
		return
	_slowmo_left -= delta / maxf(Engine.time_scale, 0.01)  # unscaled: the slow motion's own clock
	if _slowmo_left > 0.0:
		Engine.time_scale = victory_slowmo_scale
	else:
		_slowmo_left = 0.0
		Engine.time_scale = 1.0
		_finale_hold = finale_settle_seconds


## The finale after the slow motion: once the body lies still (or a moment
## has passed), the camera pans back to the party.
func _tick_finale(delta: float) -> void:
	if _finale != 1 or _slowmo_left > 0.0:
		return
	_finale_hold -= delta
	var rig := _finale_target.get_node_or_null("Limp") as Ragdoll if is_instance_valid(_finale_target) else null
	if _finale_hold <= 0.0 or rig == null or rig.settled():
		_finale = 2
		_begin_pan()  # back to the party


func _exit_tree() -> void:
	if _slowmo_left > 0.0:
		_slowmo_left = 0.0
		Engine.time_scale = 1.0  # left mid slow motion (Restart, Quit)


# --- Party attacks --------------------------------------------------------

## A party turn starts: the command menu opens. Attack needs an enemy that
## at least one of the fighter's attacks can reach.
## The menu's Abilities row shows the Ability used this turn as a chip.
func _show_used_ability() -> void:
	var badge = controlled.get_meta("ability_badge") if controlled != null and controlled.has_meta("ability_badge") else {}
	battle_menu.used_ability = badge if _skill_used else {}


func _open_commands() -> void:
	_menu_mode = BattleMenu.Mode.COMMANDS
	if _command_phase:
		# Windup: choose who to go after; you walk into reach afterwards.
		var any := not _standing(enemies).is_empty()
		battle_menu.command_index = 0 if any else 2
		battle_menu.command_enabled[0] = any
		battle_menu.command_notes[0] = "choose a target, then get in reach" if any else ""
		battle_menu.command_enabled[1] = not _skill_used
		battle_menu.command_notes[1] = "used this turn" if _skill_used else ""
		_update_items_command()
		_show_used_ability()
		return
	var can_attack := _attack_target() != null
	battle_menu.command_index = 0 if can_attack else 2  # start on Wait if out of reach
	battle_menu.command_enabled[0] = can_attack
	var note := ""
	if not can_attack:
		# Something in reach but every attack that reaches it costs too much
		# (Holy Light reaches far, but costs 30 AP)?
		var reachable := false
		for enemy in _standing(enemies):
			for move in Moves.attacks(controlled.class_id):
				if _can_target(controlled, enemy, move):
					reachable = true
		note = "not enough AP" if reachable else "no enemy in reach"
	battle_menu.command_notes[0] = note
	battle_menu.command_enabled[1] = not _skill_used
	battle_menu.command_notes[1] = "used this turn" if _skill_used else ""
	_update_items_command()
	_show_used_ability()


## The Items command: open while the turn's Ability slot is free and the
## pouch isn't empty.
func _update_items_command() -> void:
	var left := 0
	for item_name in pouch:
		left += int(pouch[item_name])
	battle_menu.command_enabled[3] = not _skill_used and left > 0
	battle_menu.command_notes[3] = "used this turn" if _skill_used else ("the pouch is empty" if left == 0 else "")


## A fresh pouch for the fight (empty = nothing until the tutorial hands
## items out).
func refill_pouch(full: bool = true) -> void:
	pouch = {Items.POTION: pouch_potions if full else 0, Items.ETHER: pouch_ethers if full else 0,
			Items.REVIVE: pouch_revives if full else 0}


func _pouch_text() -> String:
	var parts: PackedStringArray = []
	for item_name in Items.ORDER:
		parts.append("%s x%d" % [item_name, int(pouch.get(item_name, 0))])
	return "   ".join(parts)


## Keys while a menu is open. W/S move the cursor, J confirms, K goes back,
## and in the combo bar Space starts the combo.
func _menu_input(event: InputEvent) -> void:
	if _menu_mode == BattleMenu.Mode.EXECUTING:
		if event.is_action_pressed("confirm"):
			get_viewport().set_input_as_handled()
			_judge_timing()
		elif event.is_action_released("confirm"):
			get_viewport().set_input_as_handled()
			_judge_release()
		else:
			# Mage spell codes: WASD while the spell casts.  # (EXECUTING only)
			for dir in CODE_KEYS:
				if event.is_action_pressed(CODE_KEYS[dir]) and not event.is_echo():
					get_viewport().set_input_as_handled()
					_judge_code(dir)
					break
		return
	if battle_menu.element_pick and _menu_mode == BattleMenu.Mode.SKILLS:
		_element_input(event)
		return
	battle_menu.element_pick = false
	var up := event.is_action_pressed("move_forward")
	var down := event.is_action_pressed("move_back")
	var confirm := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	var begin := event.is_action_pressed("end_turn")
	var arts_key := _menu_mode == BattleMenu.Mode.COMBO and event.is_action_pressed("swap_character")
	if _menu_mode == BattleMenu.Mode.COMBO and battle_menu.arts_pages > 1 \
			and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		get_viewport().set_input_as_handled()
		_turn_arts_page(1 if event.is_action_pressed("move_right") else -1)
		return
	if not (up or down or confirm or cancel or begin or arts_key):
		return
	get_viewport().set_input_as_handled()
	if up or down:
		Sfx.play("menu_move")
	elif confirm or begin:
		Sfx.play("menu_confirm")
	elif cancel:
		Sfx.play("timeline_remove" if _menu_mode == BattleMenu.Mode.COMBO and not _plan.is_empty() else "menu_back")
	if _menu_mode == BattleMenu.Mode.COMBO and (battle_menu.arts_focus or arts_key):
		_arts_list_input(up, down, confirm, cancel or (arts_key and battle_menu.arts_focus), arts_key, begin)
		return

	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
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
					_choose_attack_target()
				elif index == 1:
					_open_skills()
				elif index == 2:
					_wait_command()
				elif index == 3:
					_open_items()
		BattleMenu.Mode.SKILLS:
			if up or down:
				var n := _skills.size()
				battle_menu.move_index = (battle_menu.move_index + (1 if down else -1) + n) % n
			elif confirm:
				_choose_skill(battle_menu.move_index)
			elif cancel:
				_menu_mode = BattleMenu.Mode.COMMANDS
		BattleMenu.Mode.TARGET:
			var by_point: bool = _pending_skill["target"] == Moves.Target.POINT
			if by_point and _pending_skill.get("ally_snap", false) and event.is_action_pressed("swap_character"):
				_snap_marker_to_ally()
			elif (up or down) and not by_point and not _target_choices.is_empty():
				var n := _target_choices.size()
				_target_index = (_target_index + (1 if down else -1) + n) % n
			elif confirm:
				_confirm_target()
			elif cancel:
				_clear_target_marker()
				if _choosing_attack_target:
					_choosing_attack_target = false
					_menu_mode = BattleMenu.Mode.COMMANDS
				else:
					_menu_mode = BattleMenu.Mode.SKILLS
		BattleMenu.Mode.COMBO:
			if up:
				battle_menu.move_index = (battle_menu.move_index - 1 + _moves.size()) % _moves.size()
			elif down:
				battle_menu.move_index = (battle_menu.move_index + 1) % _moves.size()
			elif confirm:
				_add_to_combo(battle_menu.move_index)
			elif cancel:
				if not _plan.is_empty():
					_remove_last_move()
				elif _windup_acting and _combo_target != null and _combo_target.stance == Skills.Kind.COUNTER:
					# It went into Counter stance after you committed: back out
					# and the turn becomes a Wait.
					_flash("%s backs off from the Counter stance" % controlled.display_name)
					_wait_command()
				elif _windup_acting:
					if not _can_play_on(controlled, _combo_target):
						_flash("%s can't afford a move that reaches %s: the turn becomes a Wait" % [controlled.display_name, _combo_target.display_name])
						_wait_command()
					else:
						_flash(Keybinds.fill("Committed to the attack: add moves ({confirm}) and play them ({begin})"))
				else:
					_menu_mode = BattleMenu.Mode.COMMANDS
			elif begin:
				if _plan.is_empty():
					_flash(Keybinds.fill("Add at least one move first ({confirm})"))
				else:
					_execute_combo()


# --- Command timing: windup (prototype) -----------------------------------------

func _windup_on() -> bool:
	return _windup


## True if any of the fighter's attacks reaches this enemy from where it stands.
func _windup_reaches(fighter: Combatant, target: Combatant) -> bool:
	for move in Moves.attacks(fighter.class_id):
		if _can_target(fighter, target, move):
			return true
	return false


func _windup_in_reach(fighter: Combatant) -> bool:
	var target: Combatant = fighter.get_meta("windup_target")
	if not is_instance_valid(target) or target.is_down:
		return true  # target gone: the turn starts and the menu opens again
	return _windup_reaches(fighter, target)


func _clear_windup(fighter: Combatant) -> void:
	for key in ["windup_target", "windup_grace", "windup_sheltering", "windup_dodging"]:
		if fighter.has_meta(key):
			fighter.remove_meta(key)


## Attack at the command point: every standing enemy, nearest first.
func _choose_windup_target() -> void:
	var choices: Array[Combatant] = _standing(enemies)
	choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
	if choices.is_empty():
		_open_commands()
		return
	if choices.size() == 1:
		_commit_windup(choices[0])
		return
	_target_choices = choices
	_target_index = 0
	_choosing_attack_target = true
	_begin_targeting({"name": "Attack", "target": Moves.Target.ENEMY, "range": 0.0}, Keybinds.fill("Go after which enemy? ({up} / {down})"))


## The choice is made: time runs again, and this fighter has until its icon
## reaches the end (plus the grace) to get in reach.
func _commit_windup(target: Combatant) -> void:
	var fighter := active
	fighter.set_meta("windup_target", target)
	fighter.set_meta("windup_grace", 0.0)
	_count("windups")
	_command_phase = false
	_flash("%s goes for %s: get in reach before the end of the timeline" % [fighter.display_name, target.display_name], 3.0)
	if _choosing_attack_target:
		_choosing_attack_target = false
		_clear_target_marker()
	active = null
	_hand_back_control()  # it walks there on its own unless you Tab to it
	fighter.set_highlighted(false)
	timeline_bar.active = null
	_menu_mode = BattleMenu.Mode.HIDDEN
	_combo_target = null


## Movement control only changes when the player presses Tab: a party turn
## takes it for its menus, then it goes back to whoever you were steering
## (after back-to-back turns, to whoever you steered before the first).
func _hand_back_control() -> void:
	if _steer_before_turn != null:
		if not _steer_before_turn.is_down and _steer_before_turn != controlled:
			_set_controlled(_steer_before_turn)
		_steer_before_turn = null


## An enemy is preparing a lethal skill (Doom Gaze): everyone may be hiding.
func _lethal_pending() -> bool:
	for enemy in enemies:
		if not enemy.is_down and enemy.loaded_skill != Skills.NONE and enemy.loaded_def != null and enemy.loaded_def.lethal:
			return true
	return false


## Windup, the grace is over: the nearest enemy this fighter can reach
## instead (never one in Counter stance; for an AI ally, never a tough Gust
## Sprite without a push). Null: nobody in reach, the turn becomes a Wait.
func _windup_fallback(fighter: Combatant) -> Combatant:
	var choices: Array[Combatant] = []
	for enemy in _standing(enemies):
		if enemy.stance == Skills.Kind.COUNTER or not _windup_reaches(fighter, enemy):
			continue
		if _ai_runs(fighter) and enemy.damage_taken_share < 0.5 and not enemy.lightweight and not _ai_has_push(fighter):
			continue
		choices.append(enemy)
	return _nearest(fighter, choices) if not choices.is_empty() else null


## Out of reach after the grace: the turn becomes a Wait.
func _windup_missed(fighter: Combatant) -> void:
	_clear_windup(fighter)
	if fighter.has_meta("ability_badge"):
		fighter.remove_meta("ability_badge")
	_send_to_start(fighter)
	fighter.timeline_pos += wait_head_start
	_count("windup_misses")
	_count("windup_misses_" + fighter.class_id)  # who couldn't reach, in the report
	_popup(fighter, "TOO FAR", Color(0.85, 0.8, 0.6))
	_flash("%s couldn't get in reach: the turn becomes a Wait" % fighter.display_name)


## Wait: end the turn without spending AP. The fighter's bar restarts a
## third of the way along, so their next turn comes sooner.
func _wait_command() -> void:
	var fighter := active
	_command_phase = false
	_end_turn()
	fighter.timeline_pos += wait_head_start
	_flash("%s waits" % fighter.display_name)
	_count("waits")
	for enemy in _standing(enemies):
		if enemy.stance == Skills.Kind.COUNTER:
			_count("counter_waits")
			break


## Attack: if more than one enemy is in reach, pick which one the combo hits
## (W / S, nearest first); with only one, go straight to the combo bar.
func _choose_attack_target() -> void:
	if _command_phase:
		_choose_windup_target()
		return
	var first := _attack_target()
	var choices: Array[Combatant] = []
	for enemy in _standing(enemies):
		for move in Moves.attacks(controlled.class_id).filter(_affordable):
			if _can_target(controlled, enemy, move):
				choices.append(enemy)
				break
	choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
	if first != null:
		choices.erase(first)
		choices.push_front(first)  # the default pick: nearest in normal reach
	if first == null and choices.is_empty():
		# Nobody in reach any more (something moved while the menu was open).
		_flash("No enemy in reach")
		_open_commands()
		return
	if choices.size() <= 1:
		_open_combo_bar(first if first != null else choices[0])
		return
	_target_choices = choices
	_target_index = 0
	_choosing_attack_target = true
	_begin_targeting({"name": "Attack", "target": Moves.Target.ENEMY, "range": 0.0}, Keybinds.fill("Attack: choose an enemy ({up} / {down})"))


func _open_combo_bar(target: Combatant = null) -> void:
	_combo_target = target if target != null else _attack_target()
	_moves = Moves.attacks(controlled.class_id)
	var doubled := controlled.statuses.has("arcane_cost")
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for move in _moves:
		if int(move.get("mark_discount", 0)) > 0:
			# Execute: cheaper for every Mark on the target.
			var full := int(move["cost"])
			move["cost"] = maxi(int(move["min_cost"]), full - int(move["mark_discount"]) * _combo_target.marks)
			if _combo_target.marks > 0:
				move["desc"] = "4x from behind; %d Marks: %d AP (not %d)" % [_combo_target.marks, move["cost"], full]
		if doubled:
			move["cost"] = int(move["cost"]) * 2
		var reaches := _can_target(controlled, _combo_target, move)
		usable.append(reaches)
		notes.append("" if reaches else "%s is out of its reach" % _combo_target.display_name)
	_menu_mode = BattleMenu.Mode.COMBO
	_plan.clear()
	battle_menu.moves = _moves
	_refresh_next_costs()
	battle_menu.move_usable = usable
	battle_menu.move_notes = notes
	battle_menu.plan = _plan
	battle_menu.combo.clear()
	_combo_locks.clear()
	battle_menu.arts_focus = false
	_update_arts_list()
	battle_menu.move_index = 0
	battle_menu.executing_slot = -1
	battle_menu.slot_results.clear()
	if doubled:
		_flash("Arcane Barrier: attacks cost double this turn")


## Adds a move to the bar if it fits both the fighter's combo limit and
## the party's AP. The slot's exact hits and timings are worked out now.
func _add_to_combo(index: int) -> void:
	if not battle_menu.move_usable[index]:
		_flash(battle_menu.move_notes[index])
		return
	var cost := _next_cost(index)
	var used := _segment_used()
	var available := _segment_available()
	if used + cost > controlled.combo_limit:
		_flash("%s's combo bar is full" % controlled.display_name)
	elif used + cost > available:
		_flash("Not enough AP (%d left)" % floori(available - used))
	else:
		battle_menu.combo.append(index)
		_rebuild_plan()
		_refresh_combo_reach()


## Turns the basic moves on the bar (battle_menu.combo, in order) into combo
## slots, merging every recipe it finds into its Art: left to right, always
## the longest recipe that fits. Slots that didn't change keep their worked-
## out hits and timings (random timings don't reroll while you build).
func _rebuild_plan() -> void:
	var old := _plan.duplicate()
	_plan.clear()
	_plan_spans.clear()
	for group in _parse_combo(_ai_building):
		var move: Dictionary = group["move"]
		var slot := _plan.size()
		if slot < old.size() and old[slot]["name"] == move["name"] and int(old[slot]["cost"]) == int(move["cost"]):
			_plan.append(old[slot])
		else:
			_plan.append(_plan_slot(move))
		_plan_spans.append([group["start"], group["length"]])
	_apply_flurry()
	_update_arts_list()
	_refresh_next_costs()


# --- Answer tags ------------------------------------------------------------
# While picking moves or Abilities, the ones that answer what the enemy is
# doing right now are tagged: green when they work (INTERRUPTS, BREAKS GUARD,
# STUNS, COUNTERS IT...), red when they'd backfire (BLOCKED, COUNTERED,
# MISSES). Only what the player can already see counts: a skill still
# hidden on the timeline isn't read.

enum Answer { BAD = -1, WARN = 0, GOOD = 1 }


func _update_answer_tags() -> void:
	if not _party_turn() or controlled == null:
		return
	_guard_breaks_in_bar = false
	if _menu_mode == BattleMenu.Mode.COMBO and _combo_target != null and _combo_target.stance == Skills.Kind.DEFENSE:
		# A breaking move already on the bar takes the guard down before
		# anything added after it: those aren't BLOCKED.
		for group in _parse_combo(false):
			var m: Dictionary = group["move"]
			if int(m.get("effect", Moves.Effect.NONE)) == Moves.Effect.BREAK \
					or int((m.get("last_hit", {}) as Dictionary).get("effect", Moves.Effect.NONE)) == Moves.Effect.BREAK:
				_guard_breaks_in_bar = true
	if _menu_mode == BattleMenu.Mode.COMBO:
		var tags: Array = []
		for move in _moves:
			tags.append(_move_answer(move, _combo_target))
		battle_menu.move_tags = tags
		for row in battle_menu.arts:
			var art := _art_named(String(row["name"]))
			row["tag"] = _move_answer(art, _combo_target) if not art.is_empty() else []
	elif _menu_mode == BattleMenu.Mode.SKILLS:
		var tags: Array = []
		for skill in _skills:
			tags.append(_skill_answer(skill))
		battle_menu.move_tags = tags
	else:
		battle_menu.move_tags = []


func _art_named(art_name: String) -> Dictionary:
	for art in Moves.arts(controlled.class_id):
		if art["name"] == art_name:
			return art
	return {}


## [short tag, Answer, one-line explanation] for an attack or Art against
## the target as it stands now; [] when nothing stands out.
func _move_answer(move: Dictionary, target: Combatant) -> Array:
	if target == null or target.is_down or not move.has("hits"):
		return []
	var effect := int(move.get("effect", Moves.Effect.NONE))
	var last: Dictionary = move.get("last_hit", {})
	var pierces := effect == Moves.Effect.PIERCE or int(last.get("effect", Moves.Effect.NONE)) == Moves.Effect.PIERCE
	var who := target.display_name
	if target.stance == Skills.Kind.COUNTER:
		return ["COUNTER: PARRY IT", Answer.WARN, "%s is in Counter stance: your first hit is caught and it swings back. Press the hit key as it swings to break the stance (+%d%% for the rest of the combo); miss and you're countered, combo over. Or Wait it out." % [who, roundi(counter_broken_bonus * 100.0)]]
	if target.stance == Skills.Kind.DEFENSE and not _guard_breaks_in_bar:
		if effect == Moves.Effect.BREAK:
			return ["BREAKS GUARD", Answer.GOOD, "Breaks %s's Defense stance." % who]
		if pierces:
			return ["PIERCES", Answer.GOOD, "Ignores %s's Defense." % who]
		var guard := target.loaded_def
		if guard != null and guard.let_through > 0.0:
			return ["PARTLY BLOCKED", Answer.WARN, "%s's guard lets %d%% through." % [who, roundi(guard.let_through * 100.0)]]
		return ["BLOCKED", Answer.BAD, "%s's Defense blocks it. Piercing or breaking moves get through." % who]
	if target.damage_taken_share < 0.5:
		# Gust Sprites: tough, but a push can send them off the ledge.
		if float(move.get("knockback", 0.0)) > 0.0 or target.lightweight:
			var push := maxf(float(move.get("knockback", 0.0)), lightweight_push if target.lightweight else 0.0)
			return ["PUSHES", Answer.GOOD, "%s takes little damage, but it's light: this pushes it %s m (walls bounce it). Into a hole or off the ledge, it's gone." % [who, _num_m(push * target.knockback_taken)]]
		var how := _push_recipe(controlled)
		var try := ("Try %s: a hidden Art that pushes." % how) if how != "" else "Use a move that pushes."
		return ["TOUGH", Answer.WARN, "%s takes only %d%% damage. Push it off the ledge instead. %s" % [who, roundi(target.damage_taken_share * 100.0), try]]
	if move.get("front_miss", false) and not target.is_behind(controlled.global_position) \
			and not move.get("teleport_behind", false):
		return ["MISSES", Answer.BAD, "Only works from behind, and you're in front of %s." % who]
	if target.team == Combatant.Team.ENEMY and target.skill_revealed and _loaded_offensive(target):
		var attack_name := target.loaded_def.skill_name
		var resisted := _cancel_resisted(target)
		var cancels: bool = move.get("stun", false) or (target.loaded_skill == Skills.Kind.SMASH \
				and (int(move.get("kind", Skills.Kind.ATTACK)) == Skills.Kind.ATTACK or effect == Moves.Effect.BREAK))
		if cancels and resisted != "":
			var why := "its %s can't be cancelled (a signature move). Halts and Stagger still work." % attack_name if resisted == "UNSTOPPABLE" \
					else "it was cancelled recently and resists for %d more of its actions." % target.cancel_lock
			return [resisted, Answer.WARN, "%s: %s" % [who, why]]
		if move.get("stun", false):
			if target.control_used:
				return ["NO STUN", Answer.WARN, "%s was already halted or stunned since it last acted." % who]
			return ["STUNS", Answer.GOOD, "Cancels %s's %s." % [who, attack_name]]
		if target.loaded_skill == Skills.Kind.SMASH:
			var needed := 1 if effect == Moves.Effect.BREAK else target.interrupt_resist
			if int(move.get("kind", Skills.Kind.ATTACK)) == Skills.Kind.ATTACK or effect == Moves.Effect.BREAK:
				if needed <= 1:
					return ["INTERRUPTS", Answer.GOOD, "An Attack-type hit stops %s's Smash (%s)." % [who, attack_name]]
				var done: int = target.get_meta("smash_hits", 0)
				return ["INTERRUPT %d/%d" % [mini(done + (move["hits"] as Array).size(), needed), needed], Answer.GOOD,
						"%s shrugs off single hits: %d Attack-type hits (or one breaking move) stop its Smash." % [who, needed]]
		if float(move.get("freeze", 0.0)) > 0.0:
			if target.control_used:
				return ["NO HALT", Answer.WARN, "%s was already halted or stunned since it last acted." % who]
			return ["HALTS", Answer.GOOD, "Stops %s's timeline for %s s before its %s." % [who, MoveInfo._num(float(move["freeze"])), attack_name]]
	var stagger := _stagger_answer(move, target)
	if not stagger.is_empty():
		return stagger
	if float(move.get("behind_mult", 1.0)) > 1.0 and (target.is_behind(controlled.global_position) or move.get("teleport_behind", false)):
		return ["FROM BEHIND", Answer.GOOD, "%sx from behind %s." % [MoveInfo._num(float(move["behind_mult"])), who]]
	return []


## The same for an Ability: answers to a strike coming at the fighter you're
## steering, or to an enemy preparing something.
func _skill_answer(skill: Dictionary) -> Array:
	var incoming: Combatant = null
	var at_ally: Combatant = null
	var preparing: Combatant = null
	for enemy in _standing(enemies):
		if not enemy.skill_revealed or not _loaded_offensive(enemy):
			continue
		# Who it would hit if it struck now (its area, as the warning shows).
		var hits := _strike_targets(enemy, true)
		if hits.has(controlled) or (hits.is_empty() and enemy.cast_target == controlled):
			incoming = enemy
		elif not hits.is_empty() or (enemy.cast_target != null and enemy.cast_target.team == Combatant.Team.PARTY):
			at_ally = enemy
		if controlled.gap_to(enemy) <= float(skill.get("range", 0.0)):
			preparing = enemy
	match String(skill["name"]):
		"Riposte", "Suplex":
			if incoming != null and incoming.loaded_def.parryable():
				return ["COUNTERS IT", Answer.GOOD, "%s's %s is coming at you: the counter stance hits back." % [incoming.display_name, incoming.loaded_def.skill_name]]
		"Arcane Barrier":
			if incoming != null:
				return ["BLOCKS IT", Answer.GOOD, "Ignores the %s coming at you." % incoming.loaded_def.skill_name]
		"Brace":
			if incoming != null:
				return ["HALVES IT", Answer.GOOD, "Takes half damage from the %s coming at you." % incoming.loaded_def.skill_name]
		"Vanish":
			if incoming != null:
				return ["SHAKES IT", Answer.GOOD, "%s loses track of you before its %s." % [incoming.display_name, incoming.loaded_def.skill_name]]
		"Hook":
			if preparing != null and _cancel_resisted(preparing) != "":
				return [_cancel_resisted(preparing), Answer.WARN, "%s's %s can't be cancelled right now: Hook just pulls it in." % [preparing.display_name, preparing.loaded_def.skill_name]]
			if preparing != null:
				return ["STOPS IT", Answer.GOOD, "Stops %s's %s and pulls it in." % [preparing.display_name, preparing.loaded_def.skill_name]]
		"Taunt", "Provoke":
			# Taunt covers a radius around you, Provoke one enemy in range.
			var reach := float(skill.get("radius", skill.get("range", 0.0)))
			if at_ally != null and controlled.gap_to(at_ally) <= reach:
				return ["DRAWS IT", Answer.GOOD, "%s's %s is aimed at an ally: this pulls it onto you." % [at_ally.display_name, at_ally.loaded_def.skill_name]]
	if skill.has("hits"):
		# A damaging Ability: does it fill a Stagger bar in its reach?
		var reach := float(skill.get("reach", skill.get("range", Moves.UNLIMITED)))
		for enemy in _standing(enemies):
			if controlled.gap_to(enemy) <= reach:
				var answer := _stagger_answer(skill, enemy)
				if not answer.is_empty():
					return answer
	return []


## STAGGERS / STAGGER +40% / NOT HEAD-ON for a damaging move against an
## enemy preparing a skill with a Stagger bar; [] otherwise.
func _stagger_answer(move: Dictionary, target: Combatant) -> Array:
	var def := target.loaded_def
	if def == null or def.stagger_bar <= 0 or not target.skill_revealed or not move.has("hits"):
		return []
	var who := target.display_name
	if not _head_on(controlled, target):
		return ["NOT HEAD-ON", Answer.WARN, "Only hits from in front of %s fill its Stagger bar." % who]
	var total := 0.0
	for h in move["hits"]:
		total += float(h)
	var estimate := controlled.attack_power * total * (stagger_heavy_mult if heavy_move(move) else 1.0)
	var need := target.stagger_need(def)
	var left := need - target.stagger_fill
	if estimate >= left:
		var result := "becomes %s" % def.stagger_into.skill_name if def.stagger_into != null else "breaks"
		return ["STAGGERS", Answer.GOOD, "Should fill %s's Stagger bar: its %s %s." % [who, def.skill_name, result]]
	return ["STAGGER +%d%%" % roundi(estimate / need * 100.0), Answer.GOOD,
			"Fills about %d%% of %s's Stagger bar (%d of %d left)%s." % [roundi(estimate / need * 100.0), who,
			ceili(left), roundi(need), ", heavy: 1.5x" if heavy_move(move) else ""]]


## Cleric's Bash: each Bash right after another hits harder (0.5, 0.6,
## 0.7...), up to flurry_max. Recomputed from each slot's base hits on every
## rebuild, so removing a Bash settles the rest.
func _apply_flurry() -> void:
	var streak := 0
	for entry in _plan:
		var move: Dictionary = entry["move"]
		if not entry.has("base_hits"):
			entry["base_hits"] = (entry["hits"] as Array).duplicate()
		if float(move.get("flurry", 0.0)) <= 0.0:
			streak = 0
			continue
		var base: float = float(move["hits"][0])
		var now := minf(base + float(move["flurry"]) * streak, float(move.get("flurry_max", base)))
		var factor := now / base
		var hits: Array = []
		for h in entry["base_hits"]:
			hits.append(float(h) * factor)
		entry["hits"] = hits
		streak += 1


## What adding this move would cost now.
func _next_cost(index: int) -> float:
	var cost := float(_moves[index]["cost"])
	if controlled != null and controlled.class_id == "mage" and _moves[index]["name"] == "Fire":
		var ices := 0
		for k in battle_menu.combo:
			if _moves[k]["name"] == "Ice":
				ices += 1
		cost -= roundf(cost * _ice_discount_share(ices))
	return cost


## Mage: a combo with Ice in it makes Fire cheaper on her next turn.
func _note_ice_carry(fighter: Combatant) -> void:
	if fighter.class_id != "mage":
		return
	var plain: Array = battle_menu.combo.map(func(k): return _moves[k]["name"])
	if plain.has("Ice"):
		fighter.set_meta("ice_carry_next", true)
		_count("ice_carries")
	var saved := 0
	for entry in _plan:
		saved += int((entry["move"] as Dictionary).get("ice_discount", 0))
	if saved > 0:
		_count_amount("ice_discount_ap", saved)


## AP the fighter can spend (party AP for everyone; the Monk's own is only
## his bar's length).
func _pool(_fighter: Combatant) -> float:
	return ap


func _pay(_fighter: Combatant, amount: float) -> void:
	ap -= amount


## Monk: a mistake costs a step of his climb and his newest token. A missed
## timing on his own combo (keep_step) only costs the token: the climb holds.
func _monk_slip(fighter: Combatant, keep_step := false) -> String:
	var note := fighter.drop_step(keep_step)
	if note == "":
		return ""
	if keep_step:
		_popup(fighter, "-1 TOKEN", Color(1.0, 0.6, 0.35))
		return "%s slips: %s (the climb holds)" % [fighter.display_name, note]
	_popup(fighter, "-1 STEP", Color(1.0, 0.45, 0.35))
	_step_banner("STEP LOST  ·  BAR %d" % int(fighter.combo_limit), Color(1.0, 0.4, 0.35))
	_count("monk_steps_lost")
	return "%s slips: %s" % [fighter.display_name, note]


## Monk: a banner over the field when his climb moves ("STEP 2 · BAR 80").
func _step_banner(text: String, color: Color) -> void:
	if battle_menu:
		battle_menu.banner_text = text
		battle_menu.banner_color = color
		battle_menu.banner_left = BattleMenu.BANNER_SECONDS


## Monk: what the Art at the end of the bar (building) or playing now does
## with his climb: [what it does, what a Perfect adds, Perfect still on?].
func _monk_preview() -> Array:
	var fighter := controlled
	if fighter == null or not fighter.climbs() or _plan.is_empty():
		return ["", "", true]
	var executing := _menu_mode == BattleMenu.Mode.EXECUTING
	var slot := _exec_slot if executing else _plan.size() - 1
	if slot >= _plan.size():
		return ["", "", true]
	if executing and _exec_hits_done >= (_plan[slot]["hits"] as Array).size():
		return ["", "", true]  # landed: the climb has already moved on
	var move: Dictionary = _plan[slot]["move"]
	var plan: Dictionary = _exec_tokens if executing else _token_plan(fighter, move)
	if plan.is_empty():
		return ["", "", true]
	var parts: PackedStringArray = []
	var used := int(plan.get("used", 0))
	if used > 0:
		var consumed: PackedStringArray = []
		for token in move.get("consumes", []):
			consumed.append(String(token))
		parts.append("Uses %s (+%d%%)" % [", ".join(consumed), roundi(token_damage_bonus * 100.0 * used)])
	if move.get("climb", false):
		parts.append("Top: bar 100" if fighter.at_top() else "Step: bar %d" % int(fighter.bar_steps[mini(fighter.bar_step() + 1, fighter.bar_steps.size() - 1)]))
	if move.has("cashout"):
		parts.append("Cash-out x%.1f, back to %d" % [float(plan.get("cashout", 1.0)), int(fighter.bar_steps[0])])
	var gives: PackedStringArray = []
	var after: Dictionary = plan.get("after", {})
	var sloppy: Dictionary = plan.get("sloppy", {})
	for token in after:
		if int(after[token]) > int(sloppy.get(token, 0)):
			gives.append("+" + String(token))
	if move.get("climb", false) and not fighter.tokens.has("Crowd Cheer") \
			and (fighter.at_top() or fighter.bar_step() == fighter.bar_steps.size() - 2):
		gives.append("+Crowd Cheer")
	var perfect_on := true
	if executing:
		var entry := _plan[slot]
		for hit in mini(_exec_hits_done, (entry["hits"] as Array).size()):
			if not _untimed(entry, hit) and _exec_timings[hit] != Timing.PERFECT:
				perfect_on = false
	return ["  ·  ".join(parts), ("Perfect: " + ", ".join(gives)) if not gives.is_empty() else "", perfect_on]


## Monk: a token from tanking (Parry while Provoking, a Suplex counter).
func _give_token(fighter: Combatant, token: String, why: String) -> String:
	fighter.tokens[token] = int(fighter.tokens.get(token, 0)) + 1
	_popup(fighter, "+" + token.to_upper(), Color(1.0, 0.75, 0.35))
	_count("monk_tank_tokens")
	return "%s: +1 %s (%s)" % [fighter.display_name, token, why]


## Plan slots after which the bar starts over (a Headbutt with more moves
## planned after it counts; at most bar_resets_per_combo of them). A reset
## on the last slot counts too while building, since the next move added
## would follow it.
func _reset_slots(include_last: bool) -> Array[int]:
	var slots: Array[int] = []
	for i in _plan.size():
		if slots.size() >= bar_resets_per_combo:
			break
		if _plan[i]["move"].get("bar_reset", false) and (include_last or i < _plan.size() - 1):
			slots.append(i)
	return slots


## AP of the bar used since the last restart (the whole bar without one).
func _segment_start(include_last: bool = true) -> float:
	var resets := _reset_slots(include_last)
	if resets.is_empty():
		return 0.0
	var start := 0.0
	for i in resets[-1] + 1:
		start += float(_plan[i]["cost"])
	return start


func _segment_used() -> float:
	return battle_menu.combo_cost() - _segment_start()


## What the current part of the bar can spend: a bar's worth, and no more
## than the party AP left after the parts before it (a fresh bar after a
## Headbutt is paid too).
func _segment_available() -> float:
	return maxf(minf(controlled.combo_limit, ap - _segment_start()), 0.0)


## The move list shows what each move would cost if added next.
func _refresh_next_costs() -> void:
	for i in _moves.size():
		_moves[i]["shown_cost"] = _next_cost(i)


## Reads the basic moves on the bar into groups: [{start, length, move}],
## where move is an Art (cost = what its moves cost) or the basic move.
## Left to right, longest recipe first; picked Arts stay themselves.
## with_unknown: also match Arts not discovered yet (used when the combo
## plays, so they can reveal themselves); otherwise only known ones merge,
## and undiscovered recipes stay a surprise.
func _parse_combo(with_unknown: bool) -> Array:
	var arts: Array = Moves.arts(controlled.class_id).filter(
			func(art): return (with_unknown or ArtsBook.known(controlled.class_id, art["name"])) \
					and (not art.has("needs_token") or controlled.tokens.has(art["needs_token"])))
	arts.sort_custom(func(x, y): return (x["recipe"] as Array).size() > (y["recipe"] as Array).size())
	var names: Array = battle_menu.combo.map(func(k): return _moves[k]["name"])
	var groups: Array = []
	var i := 0
	# Marks on the target that Arts in this bar can still spend (Thousand
	# Cuts needs 2 and spends them, so 2 Marks allow only one).
	var marks_left := _combo_target.marks if _combo_target != null else 0
	while i < names.size():
		var move: Dictionary = _moves[battle_menu.combo[i]]
		var length := 1
		for art in arts:
			var recipe: Array = art["recipe"]
			if _crosses_lock(i, recipe.size()):
				continue  # an Art picked from the list is never cut in half
			if int(art.get("needs_marks", 0)) > marks_left:
				continue  # not enough Marks on the target
			if i + recipe.size() <= names.size() and _recipe_matches(names.slice(i, i + recipe.size()), recipe, art.get("any_order", false)):
				move = art.duplicate(true)
				var cost := 0
				for k in recipe.size():
					cost += int(_moves[battle_menu.combo[i + k]]["cost"])  # what its moves cost (doubled too)
				move["cost"] = cost
				length = recipe.size()
				marks_left -= int(art.get("needs_marks", 0))
				break
		if length > 1 and int(move.get("timing", 0)) == Moves.TimingType.CODE:
			move["code"] = Moves.spell_code(names.slice(i, i + length))  # the bar's order
		groups.append({"start": i, "length": length, "move": move})
		i += length
	_apply_ice_discount(groups, names)
	return groups


## A recipe on the bar: in its order, or in any order (the Mage's elements).
func _recipe_matches(moves: Array, recipe: Array, any_order: bool) -> bool:
	if not any_order:
		return moves == recipe
	var a := moves.duplicate()
	var b := recipe.duplicate()
	a.sort()
	b.sort()
	return a == b


## Mage: each Ice on the bar makes every Fire after it (and in the same Art)
## cost ice_discount_per less, up to ice_discount_max; an Ice last turn
## takes ice_discount_carry off on top (ice_discount_cap in all).
func _ice_discount_share(ice_count: int) -> float:
	var share := minf(ice_count * ice_discount_per, ice_discount_max)
	if controlled != null and controlled.get_meta("ice_carry", false):
		share += ice_discount_carry
	return minf(share, ice_discount_cap)


func _apply_ice_discount(groups: Array, names: Array) -> void:
	if controlled == null or controlled.class_id != "mage":
		return
	var fire_cost := 0.0
	for m in _moves:
		if m["name"] == "Fire":
			fire_cost = float(m["cost"])
	var ice_seen := 0
	for group in groups:
		var parts: Array = names.slice(int(group["start"]), int(group["start"]) + int(group["length"]))
		ice_seen += parts.count("Ice")
		var fires := parts.count("Fire")
		if fires == 0:
			continue
		var off := roundi(fires * fire_cost * _ice_discount_share(ice_seen))
		if off <= 0:
			continue
		var move: Dictionary = (group["move"] as Dictionary).duplicate(true)
		move["cost"] = int(move["cost"]) - off
		move["ice_discount"] = off
		group["move"] = move


## When the combo starts: finds undiscovered Arts hidden in the bar. Each
## one reveals itself when the playhead reaches its first block (see
## _reveal_art): {first plan slot: {"move": Art, "slots": how many}}.
func _find_hidden_arts() -> void:
	_pending_reveals.clear()
	for group in _parse_combo(true):
		var art: Dictionary = group["move"]
		if not art.has("recipe") or ArtsBook.known(controlled.class_id, art["name"]):
			continue
		# The plan slots that tile exactly this group (basics or smaller Arts).
		var first := -1
		var count := 0
		var covered := 0
		for s in _plan_spans.size():
			var span: Array = _plan_spans[s]
			if span[0] == group["start"]:
				first = s
			if first >= 0 and s >= first and covered < group["length"]:
				covered += span[1]
				count += 1
		if first >= 0 and covered == group["length"]:
			_pending_reveals[first] = {"move": art, "slots": count}


## The playhead reached a hidden Art: its blocks merge into the Art with a
## flash, the combo pauses on a "NEW ART!" banner, then the Art plays.
func _reveal_art(slot: int) -> void:
	var info: Dictionary = _pending_reveals[slot]
	_pending_reveals.erase(slot)
	var count: int = info["slots"]
	var art: Dictionary = info["move"].duplicate(true)
	var cost := 0
	for k in count:
		cost += int(_plan[slot + k]["cost"])
	art["cost"] = cost
	for k in count:
		_plan.remove_at(slot)
		battle_menu.slot_results.remove_at(slot)
	var entry := _plan_slot(art)
	_plan.insert(slot, entry)
	var per_hit: Array[int] = []
	per_hit.resize((entry["hits"] as Array).size())
	per_hit.fill(Timing.NONE)
	battle_menu.slot_results.insert(slot, per_hit)
	# Later hidden Arts move up by the slots that just merged.
	var shifted := {}
	for key in _pending_reveals:
		shifted[key - (count - 1) if key > slot else key] = _pending_reveals[key]
	_pending_reveals = shifted
	if ArtsBook.known(_exec_attacker.class_id, art["name"]):
		return  # found earlier in this same bar: it just forms, no second "NEW ART!"
	_exec_reveal_left = art_reveal_seconds
	battle_menu.reveal_name = String(art["name"]).to_upper()
	battle_menu.reveal_progress = 0.0


## True if a recipe at `start` would take only part of an Art picked from
## the list. Taking a picked Art whole is fine: a bigger Art built on it
## (Palm Strike x2 + Knee Smash = Triple Rush) still forms and reveals.
func _crosses_lock(start: int, length: int) -> bool:
	for lock in _combo_locks:
		var lock_end: int = lock + _art_length(_combo_locks[lock])
		var overlaps: bool = lock < start + length and lock_end > start
		var inside: bool = lock >= start and lock_end <= start + length
		if overlaps and not inside:
			return true
	return false


func _art_length(art_name: String) -> int:
	for art in Moves.arts(controlled.class_id):
		if art["name"] == art_name:
			return (art["recipe"] as Array).size()
	return 1


## K / Backspace in the combo bar: removes the last basic move (an Art
## built from it splits back into its moves; a picked Art loses its lock).
func _remove_last_move() -> void:
	battle_menu.combo.pop_back()
	for lock in _combo_locks.keys():
		var art_len := 0
		for art in Moves.arts(controlled.class_id):
			if art["name"] == _combo_locks[lock]:
				art_len = (art["recipe"] as Array).size()
		if lock + art_len > battle_menu.combo.size():
			_combo_locks.erase(lock)
	_rebuild_plan()
	_refresh_combo_reach()


## The Arts list (Tab in the combo bar): pick a known Art and its whole
## recipe goes on the bar at once.
## A/D: the Arts list's next / previous page (when it has more than one). With
## the list focused, the pick moves to the first known Art on that page.
func _turn_arts_page(step: int) -> void:
	battle_menu.arts_page = (battle_menu.arts_page + step + battle_menu.arts_pages) % battle_menu.arts_pages
	if battle_menu.arts_focus:
		var first := battle_menu.arts_page * battle_menu.arts_per_page
		for i in range(first, mini(first + battle_menu.arts_per_page, battle_menu.arts.size())):
			if battle_menu.arts[i]["known"]:
				battle_menu.arts_index = i
				break


func _arts_list_input(up: bool, down: bool, confirm: bool, back: bool, toggle: bool, begin: bool) -> void:
	var known: Array = []
	for i in battle_menu.arts.size():
		if battle_menu.arts[i]["known"]:
			known.append(i)
	if not battle_menu.arts_focus:
		if known.is_empty():
			_flash("No Arts known yet: put moves in the right order and one may reveal itself")
			return
		battle_menu.arts_focus = true
		if not known.has(battle_menu.arts_index):
			battle_menu.arts_index = known[0]
		return
	if back:
		battle_menu.arts_focus = false
	elif begin:
		battle_menu.arts_focus = false
		if _plan.is_empty():
			_flash(Keybinds.fill("Add at least one move first ({confirm})"))
		else:
			_execute_combo()
	elif up or down:
		var at := known.find(battle_menu.arts_index)
		at = (at + (1 if down else -1) + known.size()) % known.size()
		battle_menu.arts_index = known[at]
		battle_menu.arts_page = battle_menu.arts_index / maxi(battle_menu.arts_per_page, 1)  # the page follows the pick
	elif confirm:
		_add_art(battle_menu.arts_index)


func _add_art(row: int) -> void:
	var art: Dictionary = Moves.arts(controlled.class_id)[int(battle_menu.arts[row]["index"])]
	var indices: Array = []
	var cost := 0.0
	for move_name in art["recipe"]:
		var index := -1
		for k in _moves.size():
			if _moves[k]["name"] == move_name:
				index = k
		if index < 0 or not battle_menu.move_usable[index]:
			_flash("%s: %s can't reach the target" % [art["name"], move_name])
			return
		indices.append(index)
		cost += float(_moves[index]["cost"])
	var used := _segment_used()
	var available := _segment_available()
	if used + cost > controlled.combo_limit:
		_flash("%s needs %d AP of bar: there's room for %d" % [art["name"], cost, controlled.combo_limit - used])
		return
	if used + cost > available:
		_flash("Not enough AP for %s (%d left)" % [art["name"], floori(available - used)])
		return
	_combo_locks[battle_menu.combo.size()] = art["name"]
	for index in indices:
		battle_menu.combo.append(index)
	_count("arts_picked")  # the tutorial's Arts list step
	_rebuild_plan()
	_refresh_combo_reach()


## Fills the Arts panel beside the move list: the Arts already discovered,
## with their recipes and, for any the moves at the end of the bar are
## heading towards, the move that comes next. Undiscovered ones are only
## counted ("2 still hidden").
func _update_arts_list() -> void:
	var rows: Array = []
	var names: Array = battle_menu.combo.map(func(k): return _moves[k]["name"])
	var all := Moves.arts(controlled.class_id)
	var hidden := 0
	var hidden_sizes := {}  # recipe length -> how many hidden
	var hidden_notes: PackedStringArray = []  # "four-move, 35 AP (needs bar 50)"
	for index in all.size():
		var art: Dictionary = all[index]
		if not ArtsBook.known(controlled.class_id, art["name"]):
			hidden += 1  # undiscovered Arts stay a surprise: no name, no recipe
			var length := (art["recipe"] as Array).size()
			hidden_sizes[length] = int(hidden_sizes.get(length, 0)) + 1
			hidden_notes.append(_hidden_note(art))
			continue
		var recipe: Array = art["recipe"]
		# Heading towards it: the last few moves are the start of its recipe,
		# and adding the next one really would end the bar on this Art (an
		# earlier merge can swallow the moves it needs).
		var next := ""
		for start in range(maxi(names.size() - recipe.size() + 1, 0), names.size()):
			var tail: Array = names.slice(start)
			if tail.size() >= recipe.size():
				continue
			var wanted := ""
			if art.get("any_order", false):
				# Any order: the tail is part of the recipe and one element is missing.
				var left := recipe.duplicate()
				for move_name in tail:
					left.erase(move_name)
				if left.size() == recipe.size() - tail.size() and left.size() == 1:
					wanted = left[0]
			elif recipe.slice(0, tail.size()) == tail:
				wanted = recipe[tail.size()]
			if wanted != "" and _would_finish_art(wanted, art["name"]):
				next = wanted
				break
		var art_cost := 0
		for move_name in recipe:
			for m in _moves:
				if m["name"] == move_name:
					art_cost += int(m["cost"])
		var timing_name: String = {Moves.TimingType.HOLD: "Hold & let go", Moves.TimingType.TAP: "Tap x%d" % int(art.get("taps", 0)),
				Moves.TimingType.CODE: "Code " + code_text(art.get("code", []))}.get(
				int(art.get("timing", Moves.TimingType.PRESS)), "Press")
		rows.append({"name": art["name"], "recipe": _recipe_text(art), "known": true, "index": index,
				"desc": art["desc"], "cost": art_cost, "timing": timing_name,
				"next": next, "color": art["color"], "finisher": art.get("finisher", false),
				"effects": MoveInfo.lines(art)})
	battle_menu.arts = rows
	battle_menu.arts_hidden = hidden
	battle_menu.arts_hidden_sizes = hidden_sizes
	battle_menu.arts_hidden_notes = hidden_notes
	battle_menu.arts_any_order = controlled != null and controlled.class_id == "mage"
	var hints: PackedStringArray = []
	for art in all:
		if ArtsBook.known(controlled.class_id, art["name"]):
			continue
		var built := _built_from_known(art)
		if built != "":
			hints.append(built + "  (Arts you know)")
			continue
		var pattern := ArtsBook.hint(controlled.class_id, art["name"])
		if pattern.is_empty():
			continue
		var right := pattern.filter(func(m): return m != "").size()
		hints.append("%s  (%d of %d)" % [" + ".join(pattern.map(func(m): return m if m != "" else "?")), right, pattern.size()])
	battle_menu.arts_hints = hints
	# (The "PUSH IT OFF THE LEDGE" box with a push Art's recipe went when
	# Gust Sprites became Lightweight: every hit knocks them back now.)
	battle_menu.arts_urgent = ""


## The recipe of a pushing Art this fighter hasn't discovered, if it has no
## push it already knows (a basic move or a known Art); "" otherwise.
func _push_recipe(fighter: Combatant) -> String:
	for move in Moves.attacks(fighter.class_id):
		if float(move.get("knockback", 0.0)) > 0.0:
			return ""
	var unknown := ""
	for art in Moves.arts(fighter.class_id):
		if float(art.get("knockback", 0.0)) <= 0.0:
			continue
		if ArtsBook.known(fighter.class_id, art["name"]):
			return ""
		if unknown == "":
			unknown = " + ".join(art["recipe"])
	return unknown


## A hidden Art in the Arts list: its length, AP and what still blocks it
## ("four-move, 35 AP (needs bar 50)"), so the player knows when to try.
func _hidden_note(art: Dictionary) -> String:
	var words := {2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven"}
	var recipe: Array = art["recipe"]
	var cost := 0
	var basics := Moves.attacks(controlled.class_id)
	for move_name in recipe:
		for m in basics:
			if m["name"] == move_name:
				cost += int(m["cost"])
	var blocks: PackedStringArray = []
	if cost > controlled.combo_limit:
		var bar := cost
		for step in controlled.bar_steps:
			if float(step) >= cost:
				bar = int(step)
				break
		blocks.append("needs bar %d" % bar)
	if art.has("needs_token") and not controlled.tokens.has(art["needs_token"]):
		blocks.append("needs %s" % art["needs_token"])
	if int(art.get("needs_marks", 0)) > 0:
		blocks.append("needs %d Marks on the target" % int(art["needs_marks"]))
	var note := "%s-move, %d AP" % [words.get(recipe.size(), str(recipe.size())), cost]
	if not blocks.is_empty():
		note += " (%s)" % ", ".join(blocks)
	return note


## A hidden Art made of Arts the player already knows (the Monk's Triple Rush
## = Palm Strike + Knee Smash): its parts, else "".
func _built_from_known(art: Dictionary) -> String:
	if not art.has("recipe_text"):
		return ""
	var parts := String(art["recipe_text"]).split(" + ")
	var art_names := Moves.arts(controlled.class_id).map(func(x): return x["name"])
	var has_art := false
	for part in parts:
		if art_names.has(part):
			has_art = true
			if not ArtsBook.known(controlled.class_id, part):
				return ""
	return " + ".join(parts) if has_art else ""


## Partial hints: a played bar that gets at least 2 moves of a hidden Art's
## recipe right (in place) adds them to that Art's hint in the Arts list
## ("Thrust + Thrust + ?  (2 of 3)"), never its name. A 2-move Art needs just
## 1 right, inside the bar ("Kick + ?  (1 of 2)").
const HINT_MIN_RIGHT := 2


func _learn_art_hints(names: Array) -> void:
	var cls := _exec_attacker.class_id
	var best_news := ""
	for art in Moves.arts(cls):
		var recipe: Array = art["recipe"]
		var n := recipe.size()
		if n < 2 or ArtsBook.known(cls, art["name"]):
			continue
		var min_right := 1 if n == 2 else HINT_MIN_RIGHT
		# Slide the recipe along the bar (3+ move Arts may hang off either
		# end; a 2-move one stays inside it, or one move would always do).
		var best: Array = []
		var best_right := 0
		var first := 0 if n == 2 else -(n - 1)
		var last := names.size() - n + 1 if n == 2 else names.size()
		for start in range(first, last):
			var pattern: Array = []
			var right := 0
			for j in n:
				var i := start + j
				if i >= 0 and i < names.size() and names[i] == recipe[j]:
					pattern.append(recipe[j])
					right += 1
				else:
					pattern.append("")
			if right > best_right:
				best_right = right
				best = pattern
		if best_right < min_right or best_right >= n:
			continue  # (all of it: the Art itself is about to be found)
		var known_now := ArtsBook.learn_hint(cls, art["name"], best)
		if known_now > 0:
			_count("art_hints")
			best_news = "Close to a hidden Art: %d of its %d moves found" % [known_now, n]
	if best_news != "":
		_flash(best_news, 3.0)


## The Arts list's recipe line. Monk Arts built from smaller ones read
## "Palm Strike + Palm Strike + Knee Smash" once those are all known (no
## spoilers otherwise); long move lists shorten to initials ("P P P P K HK").
func _recipe_text(art: Dictionary) -> String:
	var known_inside := art.has("recipe_text")
	for inner in art.get("contains", []):
		if not ArtsBook.known(controlled.class_id, inner):
			known_inside = false
	if known_inside:
		return art["recipe_text"]
	var recipe: Array = art["recipe"]
	if art.get("any_order", false) and recipe.size() > 1 and recipe.count(recipe[0]) == recipe.size():
		return "%s x%d" % [recipe[0], recipe.size()]  # Fire x3
	var text := " + ".join(recipe)
	if text.length() <= 40:
		return text
	var short: PackedStringArray = []
	for move_name in recipe:
		var initials := ""
		for word in String(move_name).split(" "):
			initials += word.substr(0, 1)
		short.append(initials)
	return " ".join(short)


## True if adding this basic move to the bar would make the bar end on this
## Art (read the same way the bar merges known Arts).
func _would_finish_art(move_name: String, art_name: String) -> bool:
	var move_index := -1
	for i in _moves.size():
		if _moves[i]["name"] == move_name:
			move_index = i
	if move_index < 0:
		return false
	battle_menu.combo.append(move_index)
	var groups := _parse_combo(false)
	battle_menu.combo.pop_back()
	if groups.is_empty():
		return false
	var last: Dictionary = groups[-1]
	return last["move"]["name"] == art_name and int(last["length"]) > 1


## After a Shadowstep on the bar, everything after it reaches the target
## (the Assassin will be standing right behind it).
func _refresh_combo_reach() -> void:
	var stepped := false
	for entry in _plan:
		if entry["move"].get("teleport_behind", false):
			stepped = true
	for i in _moves.size():
		var reaches := stepped or _can_target(controlled, _combo_target, _moves[i])
		battle_menu.move_usable[i] = reaches
		battle_menu.move_notes[i] = "" if reaches else "%s is out of its reach" % _combo_target.display_name


## What one combo slot will do: its hits, where each lands (as a fraction of
## the block), and its timing box. Handles Bash's growing hits, Agility's
## extra hit, and delayed or random timings.
func _plan_slot(move: Dictionary) -> Dictionary:
	var hits: Array = (move["hits"] as Array).duplicate()
	var times: Array = (move.get("times", []) as Array).duplicate()
	# One playhead speed for every move: a block takes as long as it is wide.
	var duration: float = maxf(float(move["cost"]), 1.0) / (playhead_ap_per_second * controlled.playhead_speed)
	var cost := float(move["cost"])
	var agility_hit := -1  # index of Agility's extra arrow, if any
	if controlled.statuses.has("agility"):
		if times.is_empty():
			agility_hit = hits.size()
			duration *= float(hits.size() + 1) / hits.size()
			hits.append(float(hits[0]) * agility_hit_share)
		else:
			var last: float = times[-1]
			var before: float = times[-2] if times.size() > 1 else 0.0
			agility_hit = hits.size() - 1
			hits.insert(hits.size() - 1, float(hits[0]) * agility_hit_share)
			times.insert(times.size() - 1, (before + last) / 2.0)
	if move.get("random_timing", false) and hits.size() == 1:
		# Assassin: the hit comes at a random moment. The first move of a
		# combo always lands in the middle or late part, so the opener is
		# never a surprise.
		var earliest := maxf(float(move["window"]) / duration + 0.05, 0.25)
		times = [randf_range(0.5 if _plan.is_empty() else earliest, 0.95)]
	elif move.get("random_timing", false):
		# Multi-hit Assassin Arts: the block is cut into one stretch per hit,
		# and each hit lands somewhere in its own stretch (boxes never overlap).
		# An opener starts a little later, so its first hit isn't a surprise.
		var box := float(move["window"]) / duration
		var start := maxf(box + 0.05, 0.35 if _plan.is_empty() else 0.2)
		var stretch := (0.95 - start) / hits.size()
		times = []
		for i in hits.size():
			var lo := start + stretch * i + box * 0.5
			var hi := maxf(start + stretch * (i + 1) - box * 0.5, lo)
			times.append(randf_range(lo, hi))
	if times.is_empty():
		for i in hits.size():
			times.append(float(i + 1) / hits.size())
	# Monk's Punch / Kick: only one hit is timed, the others land by themselves.
	var untimed: Array[bool] = []
	var code_timing := int(move.get("timing", Moves.TimingType.PRESS)) == Moves.TimingType.CODE
	for i in hits.size():
		if code_timing:
			untimed.append(i != hits.size() - 1)  # one code, due before the last hit
			continue
		match String(move.get("timed", "all")):
			"last":
				untimed.append(i != hits.size() - 1)
			"first":
				untimed.append(i != 0)
			"none":
				untimed.append(true)
			_:
				untimed.append(false)
	if agility_hit >= 0 and int(move.get("timing", Moves.TimingType.PRESS)) != Moves.TimingType.PRESS:
		# During a Hold or Tap the key is busy: Agility's extra arrow flies
		# by itself instead of asking for a press in the middle of it.
		untimed[agility_hit] = true
	return {
		"untimed": untimed,
		"move": move, "name": move["name"], "color": move["color"], "cost": cost,
		"hits": hits, "times": times, "duration": duration,
		"window": float(move["window"]) / duration,
		"timing": int(move.get("timing", Moves.TimingType.PRESS)),
		"hold_start": float(move.get("hold_start", 0.35)),
		"taps": int(move.get("taps", 0)), "tap_start": float(move.get("tap_start", 0.12)),
		"code": (move.get("code", []) as Array).duplicate(), "code_start": float(move.get("code_start", code_start)),
	}


## Starts playing the combo. _update_combo then runs it frame by frame.
func _execute_combo() -> void:
	_exec_rings.clear()
	_menu_mode = BattleMenu.Mode.EXECUTING
	_exec_attacker = controlled
	_last_landed_ms = -100000  # no late-press grace carried over from another combo
	_ap_before_combo = _pool(controlled)
	_pay(controlled, battle_menu.combo_cost())  # a Headbutt's fresh bar included
	_note_ice_carry(controlled)
	_exec_limit = controlled.combo_limit
	_spend_focus(controlled)  # the bar keeps its size while it plays (_exec_limit)
	_exec_resume_slot = -1
	if combo_counter:
		combo_counter.begin(controlled.display_name)
	_exec_attacker.statuses.erase("arcane_cost")  # Arcane Barrier's cost lasts until the next attack
	if _exec_attacker.statuses.has("vanish"):
		_exec_attacker.statuses.erase("vanish")  # attacking gives a hidden Assassin away
		_popup(_exec_attacker, "REVEALED", Color(0.7, 0.7, 0.8))
	_count("combos")
	_count("combos_" + _exec_attacker.class_id)
	_learn_art_hints(battle_menu.combo.map(func(k): return _moves[k]["name"]))
	_exec_attacker.face_toward(_combo_target.global_position - _exec_attacker.global_position, 1.0, 100000.0)
	battle_menu.slot_results.clear()
	battle_menu.consumed_slots = 0
	for entry in _plan:
		var per_hit: Array[int] = []
		per_hit.resize((entry["hits"] as Array).size())
		per_hit.fill(Timing.NONE)
		battle_menu.slot_results.append(per_hit)
	_exec_outro = -1.0
	_exec_reveal_left = 0.0
	battle_menu.reveal_name = ""
	_pending_reveals.clear()
	_start_combo_slot(0)
	_find_hidden_arts()  # an Art hidden at the very start reveals when the lead-in ends
	# A short lead-in so the player can get ready for the timing.
	_exec_lead_in = combo_lead_in
	battle_menu.lead_in_progress = 0.0


## Keeps a melee attacker after its target for `seconds` (refreshed while
## its combo plays): if a push carries the target out of the move's reach,
## the attacker steps after it. Ranged moves don't chase.
func _chase(fighter: Combatant, target: Combatant, move: Dictionary, seconds: float) -> void:
	if target == null or float(move.get("reach", -1.0)) >= 0.0:
		return
	_chasers[fighter] = [target, move, seconds]


## Closes the gap for every chaser, steering round rocks, never onto a hole
## or over an edge, and only up to the move's reach.
func _tick_chasers(delta: float) -> void:
	for key in _chasers.keys():
		var fighter: Combatant = key
		var entry: Array = _chasers[fighter]
		var target: Combatant = entry[0]
		entry[2] = float(entry[2]) - delta
		if entry[2] <= 0.0 or not is_instance_valid(fighter) or not is_instance_valid(target) \
				or fighter.is_down or target.is_down:
			_chasers.erase(fighter)
			continue
		var need: float = fighter.gap_to(target) - (_move_reach(fighter, entry[1]) - 0.15)
		if need <= 0.02:
			continue
		var dir: Vector3 = arena.steer(fighter.global_position, target.global_position - fighter.global_position, fighter.body_radius)
		if dir.length_squared() < 0.0001:
			continue
		var next: Vector3 = fighter.global_position + dir.normalized() * minf(need, chase_speed * delta)
		if arena.lethal_at(next) or arena.lethal_at(next + dir.normalized() * fighter.body_radius):
			_chasers.erase(fighter)  # not into a hole or over the edge
			continue
		fighter.global_position = next
		_keep_in_arena(fighter)
		fighter.face_toward(target.global_position - fighter.global_position, 1.0, 100000.0)


## How full the current tap charge is (0-1; capped at the Perfect count).
func _charge_fraction() -> float:
	if _exec_slot >= _plan.size():
		return 0.0
	return clampf(float(_exec_taps) / maxf(float(_plan[_exec_slot]["taps"]), 1.0), 0.0, 1.0)


## A tap came in: the orb appears (first tap) or grows, with a pop.
## Tortoise Special's taps: a punch each, a small shockwave on the target.
func _flurry_tap() -> void:
	if _exec_attacker == null or _exec_attacker.anim == null:
		return
	_exec_attacker.anim.flurry_punch()
	if _combo_target != null and not _combo_target.is_down:
		var at := SpellFx._contact(_exec_attacker, _combo_target) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), 0)
		var facing := _combo_target.global_position - _exec_attacker.global_position
		facing.y = 0.0
		SpellFx.punch_wave(self, at, facing, SpellFx.KI, 0.5)


func _charge_tap(entry: Dictionary) -> void:
	if _exec_attacker == null:
		return
	if _charge_orb == null:
		var cls := _exec_attacker.class_id
		var color: Color = SpellFx.ENERGY if cls == "mage" else SpellFx.CLASS_COLORS.get(cls, Color.WHITE)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.lightened(0.2), 0.8)
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		_charge_orb = MeshInstance3D.new()
		_charge_orb.mesh = sphere
		_charge_orb.material_override = mat
		_charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_charge_orb)
	var r := 0.1 + 0.4 * _charge_fraction()
	_charge_orb.scale = Vector3.ONE * r * 1.35
	var pop := _charge_orb.create_tween()
	pop.tween_property(_charge_orb, "scale", Vector3.ONE * r, 0.12)
	_tick_charge_orb()


## Keeps the orb at the caster's staff tip (Mage, Cleric) or in front of
## their hands.
func _tick_charge_orb() -> void:
	if _charge_orb == null or _exec_attacker == null or not is_instance_valid(_exec_attacker):
		return
	var tip := _exec_attacker.get_node("Body").find_child("TrailTip", true, false) as Node3D \
			if _exec_attacker.class_id in ["mage", "cleric"] and _exec_attacker.has_node("Body") else null
	if tip != null:
		_charge_orb.global_position = tip.global_position
	else:
		var h := float(Figure.HEIGHTS.get(_exec_attacker.class_id, 1.0))
		_charge_orb.global_position = _exec_attacker.global_position + _exec_attacker.flat_forward() * 0.7 + Vector3(0, 1.1 * h, 0)


func _end_charge_orb() -> void:
	if _charge_orb != null:
		var orb := _charge_orb
		_charge_orb = null
		var t := orb.create_tween()
		t.tween_property(orb, "scale", Vector3.ONE * 0.01, 0.08)
		t.tween_callback(orb.queue_free)


## A Perfect lands: a few frames of freeze, so it hits harder. Not while
## the game runs at another speed (sims, a hit-stop already on).
func _hitstop() -> void:
	if hitstop_seconds <= 0.0 or Engine.time_scale != 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(hitstop_seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _start_combo_slot(slot: int) -> void:
	if _pending_reveals.has(slot):
		_reveal_art(slot)
	_exec_slot = slot
	_exec_time = 0.0
	_exec_hits_done = 0
	_exec_timings.clear()
	_exec_timings.resize((_plan[slot]["hits"] as Array).size())
	_exec_timings.fill(Timing.NONE)
	_exec_holding = false
	_exec_taps = 0
	_exec_code = 0
	_exec_launched.clear()
	_exec_swung.clear()
	battle_menu.exec_holding = false
	battle_menu.exec_taps = 0
	battle_menu.exec_code = 0
	battle_menu.executing_slot = slot
	battle_menu.slot_progress = 0.0
	var art_move: Dictionary = _plan[slot]["move"]
	_exec_tokens = _token_plan(_exec_attacker, art_move)
	if art_move.has("recipe"):
		# An Art: its name pops up, and the first time it's discovered.
		_count("arts")
		_count("art_" + String(art_move["name"]).to_lower().replace(" ", "_").replace("'", ""))
		if not ArtsBook.discover(_exec_attacker.class_id, art_move["name"]):
			_popup(_exec_attacker, String(art_move["name"]).to_upper(), art_move["color"])
		else:
			_count("arts_found")
		if int(art_move.get("spend_marks", 0)) > 0 and _combo_target != null and _combo_target.marks > 0:
			# Thousand Cuts pays its Marks up front, so its cuts (Stabs) can't
			# grow them back on the way.
			_combo_target.set_marks(_combo_target.marks - int(art_move["spend_marks"]))
			_popup(_combo_target, "-%d MARKS" % int(art_move["spend_marks"]), Color(0.78, 0.45, 1.0))
		# (a newly found Art already has its "NEW ART!" banner)


## Moves the playhead through the current block at that move's own speed,
## landing its hits at their planned moments.
func _update_combo(delta: float) -> void:
	if _exec_lead_in > 0.0:
		_launch_timing_rings(_exec_lead_in)  # the first hits' rings already close in
		_exec_lead_in -= delta
		battle_menu.lead_in_progress = clampf(1.0 - _exec_lead_in / combo_lead_in, 0.0, 1.0)
		if _exec_lead_in <= 0.0:
			battle_menu.lead_in_progress = -1.0
			if _exec_resume_slot >= 0:
				var resume := _exec_resume_slot
				_exec_resume_slot = -1
				_start_combo_slot(resume)  # the fresh bar starts now
			elif _pending_reveals.has(0):
				_start_combo_slot(0)
		return
	if _exec_reveal_left > 0.0:
		_exec_reveal_left -= delta
		battle_menu.reveal_progress = clampf(1.0 - _exec_reveal_left / art_reveal_seconds, 0.0, 1.0)
		if _exec_reveal_left <= 0.0:
			battle_menu.reveal_name = ""
		return
	if _exec_outro >= 0.0:
		_exec_outro -= delta
		if _exec_outro < 0.0:
			_menu_mode = BattleMenu.Mode.HIDDEN
			if active != null and not _game_over:
				_end_turn()
		return

	if _counter_recover > 0.0:
		# Just parried: a breather before the playhead moves on.
		_counter_recover -= delta
		battle_menu.recover_progress = clampf(1.0 - _counter_recover / counter_recover_seconds, 0.0, 1.0)
		if _counter_recover <= 0.0:
			battle_menu.recover_progress = -1.0
		return
	if _counter_from != null:
		# The playhead waits while the counter-swing comes.
		_counter_left -= delta
		battle_menu.counter_progress = clampf(1.0 - _counter_left / counter_parry_lead, 0.0, 1.0)
		if _counter_left <= -counter_parry_window:
			_counter_failed("Too late!")
		return

	var entry := _plan[_exec_slot]
	var duration: float = entry["duration"]
	var hits: Array = entry["hits"]
	var times: Array = entry["times"]
	# Nothing left to press in the whole combo: the rest plays fast; except
	# the lead-up of a Mage signature Art (Meteor's sky), which plays out.
	_exec_speed = 1.0 if _inputs_left() or _signature_ahead(entry) else exec_fast_forward
	delta *= _exec_speed
	_exec_time += delta
	battle_menu.slot_progress = clampf(_exec_time / duration, 0.0, 1.0)
	_launch_approaches(entry)
	_launch_timing_rings(0.0)
	_chase(_exec_attacker, _combo_target, entry["move"], 0.35)
	_tick_charge_orb()
	# Looks: the figure's build-up for the next hit fills the time until it
	# lands (FigureAnim.anticipate).
	if _exec_hits_done < hits.size():
		var key := "%d:%d" % [_exec_slot, _exec_hits_done]
		var until := (duration * float(times[_exec_hits_done]) - _exec_time) / maxf(_exec_speed, 0.01)
		if key != _anticipated:
			_anticipated = key
			_exec_attacker.anticipate(entry["move"], _exec_hits_done, _combo_target, maxf(until, 0.0))

	while _exec_hits_done < hits.size() and _exec_time >= duration * float(times[_exec_hits_done]):
		var multiplier: float = hits[_exec_hits_done]
		multiplier *= 1.0 + _settle_special_timing(entry, _exec_hits_done)
		var untimed := _untimed(entry, _exec_hits_done)
		var perfect := _exec_timings[_exec_hits_done] == Timing.PERFECT
		if _exec_timings[_exec_hits_done] == Timing.NONE and not untimed and skipped_hit_max_ap_loss > 0.0 \
				and int(entry["timing"]) != Moves.TimingType.CODE:  # an unfinished code costs nothing
			_shrink_max_ap(skipped_hit_max_ap_loss, _exec_attacker)  # opted out of the timing
		if perfect:
			multiplier *= 1.0 + perfect_damage_bonus
		multiplier *= 1.0 + _counter_bonus  # after a parried counter
		# Monk: the tokens the Art uses up, and Tortoise Special's cash-out.
		multiplier *= 1.0 + float(_exec_tokens.get("bonus", 0.0))
		_exec_attacker.play_lunge(entry["move"], _exec_hits_done, _combo_target)
		if perfect:
			_hitstop()
		_exec_hit_perfect = perfect  # Divine Barrier grows on a Perfect
		var hit_move: Dictionary = entry["move"]
		if hit_move.has("last_hit") and _exec_hits_done == hits.size() - 1:
			# Triple Shot's piercing last arrow, the Marks an Assassin Art leaves.
			hit_move = hit_move.duplicate()
			hit_move.merge(hit_move["last_hit"], true)
		if not untimed:
			_last_landed_ms = Time.get_ticks_msec()  # late presses for it are forgiven
			_count("timed_hits")
		var keep_going := _land_hit(_exec_attacker, hit_move, multiplier, _exec_hits_done == 0, _exec_hits_done == hits.size() - 1)
		_exec_hit_perfect = false
		if _exec_hits_done == hits.size() - 1 and not _exec_attacker.is_down:
			_settle_tokens()  # the Art's last hit landed: tokens and the bar
		if combo_counter:
			combo_counter.hit(perfect)
		_exec_hits_done += 1
		if perfect:
			_popup(_exec_attacker, "PERFECT!", Color(1.0, 0.85, 0.2))
			_count("perfects")
			var kind_name: String = {Moves.TimingType.HOLD: "perfects_hold", Moves.TimingType.TAP: "perfects_tap",
					Moves.TimingType.CODE: "perfects_code"}.get(
					entry["timing"] if _special_hit(entry, _exec_hits_done - 1) else -1, "")
			if kind_name != "":
				_count(kind_name)
			_flash(_grow_max_ap(perfect_max_ap_gain, _exec_attacker))
		if not keep_going or _game_over:
			_stop_combo()
			return
		if _counter_from != null:
			return  # a counter-swing is coming: the playhead waits for it

	# The playhead always crosses the whole block, even when its last hit
	# lands early (Hold moves at 85%, the Assassin's random hits): the next
	# block starts on time, so its boxes come exactly where they're drawn.
	if _exec_hits_done >= hits.size() and _exec_time >= duration:
		if _exec_slot + 1 < _plan.size():
			var overshoot := _exec_time - duration
			if _reset_slots(false).has(_exec_slot):
				# Headbutt: the bar starts over, after the same "READY" lead-in
				# a combo starts with, so the player can read the fresh bar.
				battle_menu.consumed_slots = _exec_slot + 1
				battle_menu.executing_slot = _exec_slot + 1
				_popup(_exec_attacker, "FRESH BAR!", Color(1.0, 0.75, 0.35))
				_exec_resume_slot = _exec_slot + 1
				_exec_lead_in = combo_lead_in
				battle_menu.lead_in_progress = 0.0
				return
			_start_combo_slot(_exec_slot + 1)
			if _exec_reveal_left <= 0.0:
				_exec_time = overshoot  # keep the rhythm frame-exact
		else:
			battle_menu.executing_slot = _plan.size()  # playhead to the end
			_exec_outro = 0.4
			if _flawless_combo():
				Sfx.play("combo_perfect")
			if combo_counter:
				combo_counter.finish()


## The whole bar played with every timing a Perfect (no misses, no late ones).
func _flawless_combo() -> bool:
	var any := false
	for results in battle_menu.slot_results:
		for result in results:
			if result == Timing.PERFECT:
				any = true
			elif result != Timing.NONE:
				return false
	return any


## True while the combo still has something the player can press: a timing
## box ahead, a Hold to let go, a code to type, Energy's or Tortoise
## Special's taps still adding damage. False = the rest plays by itself, so
## it's fast-forwarded (exec_fast_forward).
func _inputs_left() -> bool:
	for slot in range(_exec_slot, _plan.size()):
		var e := _plan[slot]
		var hits: Array = e["hits"]
		var timing := int(e["timing"])
		var surge := float(e["move"].get("surge", 0.0)) > 0.0
		for h in range(_exec_hits_done if slot == _exec_slot else 0, hits.size()):
			if _untimed(e, h):
				continue
			if slot != _exec_slot:
				return true  # a later move: its timing is still ahead
			var special := _special_hit(e, h)
			if special and timing == Moves.TimingType.HOLD and _exec_holding:
				return true  # still to let go
			var result: int = _exec_timings[h]
			if result == Timing.NONE:
				return true
			if result == Timing.PERFECT and special and surge:
				if e["move"].get("surge_uncapped", false) or _exec_taps < int(e["taps"]):
					return true  # more taps still add damage
	return false


## Starts each upcoming hit's approach effect so it arrives exactly when the
## playhead lands that hit (SpellFx.approach_lead seconds ahead).
## True while the next hit is a Mage signature Art within its lead-up.
func _signature_ahead(entry: Dictionary) -> bool:
	if _exec_attacker == null or _exec_attacker.class_id != "mage":
		return false
	var lead := float(SpellFx.SIGNATURE_LEADS.get(String(entry["move"].get("name", "")), 0.0))
	if lead <= 0.0 or _exec_hits_done >= (entry["hits"] as Array).size():
		return false
	var hit_time: float = float(entry["duration"]) * float(entry["times"][_exec_hits_done])
	return hit_time - _exec_time <= lead + 0.05


func _launch_approaches(entry: Dictionary) -> void:
	if _combo_target == null or _combo_target.is_down or _exec_attacker == null:
		return
	var hits: Array = entry["hits"]
	var times: Array = entry["times"]
	var duration: float = entry["duration"]
	# Swing sounds, just before each melee hit lands (moves with an approach
	# effect, arrows and spells, sound when it starts: below).
	for h in range(_exec_hits_done, hits.size()):
		if _exec_swung.has(h):
			continue
		if _exec_time < duration * float(times[h]) - BattleSounds.SWING_LEAD * _exec_speed:
			break
		_exec_swung[h] = true
		if SpellFx.approach_lead(_exec_attacker, entry["move"]) <= 0.0:
			BattleSounds.swing(_exec_attacker, entry["move"])
	for h in range(_exec_hits_done, hits.size()):
		if _exec_launched.has(h):
			continue
		var move: Dictionary = entry["move"]
		if move.has("last_hit") and h == hits.size() - 1:
			move = move.duplicate()
			move.merge(move["last_hit"], true)
		var lead := SpellFx.approach_lead(_exec_attacker, move)
		var hit_time := duration * float(times[h])
		if lead <= 0.0:
			_exec_launched[h] = true
			continue
		if _exec_time < hit_time - lead:
			break  # later hits start later still
		_exec_launched[h] = true
		SpellFx.approach(self, _exec_attacker, _combo_target, move, maxf((hit_time - _exec_time) / _exec_speed, 0.04))
		BattleSounds.swing(_exec_attacker, move)


## Timing rings on the enemy: for every press hit, a ring closes in on the
## target at a steady speed, starting timing_ring_lead seconds before the
## hit (also across into the next block, and during the lead-in); a fixed
## gold ring marks the timing box: press while the closing ring is inside
## it. extra: seconds still to wait before the current block starts.
func _launch_timing_rings(extra: float) -> void:
	if _combo_target == null or _combo_target.is_down or _exec_slot >= _plan.size():
		return
	var into := 0.0 if extra > 0.0 else _exec_time  # where the playhead is in the current block
	var offset := extra
	for slot in range(_exec_slot, mini(_exec_slot + 2, _plan.size())):
		var e := _plan[slot]
		var duration: float = e["duration"]
		var times: Array = e["times"]
		var first := _exec_hits_done if slot == _exec_slot and extra <= 0.0 else 0
		for h in range(first, (e["hits"] as Array).size()):
			if _untimed(e, h) or _special_hit(e, h):
				continue  # Holds, Taps and codes have their own cues
			var key := "%d:%d" % [slot, h]
			if _exec_rings.has(key):
				continue
			var until := offset + duration * float(times[h]) - (into if slot == _exec_slot else 0.0)
			if until > timing_ring_lead or until <= 0.0:
				continue
			var window := battle_menu.box_fraction(e) * duration
			_exec_rings[key] = SpellFx.timing_ring(self, _combo_target, until, window, timing_ring_lead)
		offset += duration - (into if slot == _exec_slot else 0.0)


## A press judged: its ring flashes gold (Perfect) or red (miss).
func _ring_result(slot: int, hit: int, perfect: bool) -> void:
	var key := "%d:%d" % [slot, hit]
	if _exec_rings.has(key):
		SpellFx.timing_ring_done(_exec_rings[key], perfect)


## The hint under the bar while a combo plays, for the current move's timing.
func _timing_prompt() -> String:
	if _exec_slot < _plan.size() and _exec_lead_in <= 0.0:
		var entry := _plan[_exec_slot]
		if _special_hit(entry, _next_timed(entry)):
			if int(entry["timing"]) == Moves.TimingType.CODE:
				var code_line := "TYPE %s with WASD before the hit: Perfect!  (a wrong arrow starts it over)" % code_text(entry["code"])
				if float(entry["move"].get("surge", 0.0)) > 0.0:
					code_line = "TYPE %s with WASD, then TAP {confirm} freely: every tap adds damage" % code_text(entry["code"])
				return Keybinds.fill(code_line)
			if int(entry["timing"]) == Moves.TimingType.HOLD:
				return Keybinds.fill("HOLD {confirm} in the first box, LET GO in the last one: Perfect!  (a bad let-go only loses the Perfect)")
			if entry["move"].get("surge_uncapped", false):
				return Keybinds.fill("TAP {confirm} as fast as you can: every tap adds damage, no limit (%d is a Perfect)" % int(entry["taps"]))
			if float(entry["move"].get("surge", 0.0)) > 0.0:
				return Keybinds.fill("TAP {confirm} as fast as you can: every tap adds damage, %d is a Perfect  (extra taps are fine)" % int(entry["taps"]))
			return Keybinds.fill("TAP {confirm} exactly %d times before the hit: Perfect!  (a tap too many is a miss)" % int(entry["taps"]))
	return Keybinds.fill("{confirm} when the playhead hits the box: Perfect!  (a wrong press ends the chain)")


## Monk's Punch / Kick: hits that land by themselves (no timing box).
func _untimed(entry: Dictionary, hit: int) -> bool:
	var list: Array = entry.get("untimed", [])
	return hit < list.size() and bool(list[hit])


## The next hit a press is judged against (skipping hits that land by
## themselves); the hit count when none is left.
func _next_timed(entry: Dictionary) -> int:
	var hit := _exec_hits_done
	while hit < (entry["hits"] as Array).size() and _untimed(entry, hit):
		hit += 1
	return hit


## Monk Arts: works out what this slot does with tokens before it plays.
## The smaller Arts inside it give their tokens first (in order, each
## using up what it consumes), then this Art uses up its own. Every token
## used up anywhere in it adds token_damage_bonus to its damage.
## Returns {} for moves without token fields.
func _token_plan(fighter: Combatant, move: Dictionary) -> Dictionary:
	if not fighter.climbs() or not (move.has("grants") or move.has("consumes") or move.has("contains") or move.get("climb", false)):
		return {}
	var arts := {}
	for art in Moves.arts(fighter.class_id):
		arts[art["name"]] = art
	var held: Dictionary = fighter.tokens.duplicate()
	var used := [0]
	_apply_art_tokens(move, held, used, arts, true)
	# Not all Perfect: the Art still uses its tokens up, but leaves none.
	var sloppy: Dictionary = fighter.tokens.duplicate()
	_apply_art_tokens(move, sloppy, [0], arts, false)
	var bonus: float = token_damage_bonus * int(used[0])
	var cashout := 1.0
	for entry in move.get("cashout", []):
		if fighter.combo_limit >= float(entry[0]):
			cashout = float(entry[1])
	bonus = (1.0 + bonus) * cashout - 1.0
	return {"bonus": bonus, "after": held, "sloppy": sloppy, "used": used[0], "cashout": cashout}


## True while landing the last hit of the move playing now (or outside a
## combo): effects meant once per move, not once per hit.
func _last_hit_of_slot() -> bool:
	if _menu_mode != BattleMenu.Mode.EXECUTING or _exec_slot >= _plan.size():
		return true
	return _exec_hits_done >= (_plan[_exec_slot]["hits"] as Array).size() - 1


func _apply_art_tokens(art: Dictionary, held: Dictionary, used: Array, arts: Dictionary, grant: bool) -> void:
	for inner in art.get("contains", []):
		if arts.has(inner):
			_apply_art_tokens(arts[inner], held, used, arts, grant)
	for token in art.get("consumes", []):
		used[0] += int(held.get(token, 0))
		held.erase(token)
	if not grant:
		return
	var grants: Dictionary = art.get("grants", {})
	for token in grants:
		held[token] = int(held.get(token, 0)) + int(grants[token])


## The Art's last hit landed. Every timing Perfect: the Monk keeps the
## tokens it left; otherwise only what it didn't use up. Either way its
## step raises the bar (right there on screen), and Tortoise Special
## spends the climb.
func _settle_tokens() -> void:
	var move: Dictionary = _plan[_exec_slot]["move"]
	var fighter := _exec_attacker
	if _exec_tokens.is_empty() or not fighter.climbs():
		return
	var entry := _plan[_exec_slot]
	var all_perfect := true
	for hit in (entry["hits"] as Array).size():
		if not _untimed(entry, hit) and _exec_timings[hit] != Timing.PERFECT:
			all_perfect = false
	var before: Dictionary = fighter.tokens.duplicate()
	fighter.tokens = _exec_tokens["after"] if all_perfect else _exec_tokens["sloppy"]
	var notes: PackedStringArray = []
	if not all_perfect and move.has("grants"):
		notes.append("not all Perfect: no tokens")
		_popup(fighter, "NO TOKEN", Color(0.75, 0.75, 0.8))
	for token in fighter.tokens:
		if int(fighter.tokens[token]) > int(before.get(token, 0)):
			_popup(fighter, String(token).to_upper(), move["color"])
			notes.append("+" + String(token))
	if int(_exec_tokens["used"]) > 0:
		notes.append("%d tokens used (+%d%%)" % [_exec_tokens["used"], roundi(token_damage_bonus * 100.0 * int(_exec_tokens["used"]))])
	if move.get("climb", false):
		var grown := fighter.climb_step()
		if grown > 0.0:
			_step_banner("STEP %d  ·  BAR %d" % [fighter.bar_step(), int(fighter.combo_limit)], Color(1.0, 0.78, 0.35))
			notes.append("bar %d" % int(fighter.combo_limit))
			_count("monk_steps")
		if fighter.at_top() and all_perfect and not fighter.tokens.has("Crowd Cheer"):
			# The top, reached (or held) all Perfect: the cash-out is ready.
			fighter.tokens["Crowd Cheer"] = 1
			if arena.scenery:
				arena.scenery.cheer(2.5)
			_popup(fighter, "CROWD CHEER", Color(1.0, 0.85, 0.3))
			notes.append("+Crowd Cheer")
		elif fighter.at_top() and not all_perfect and not fighter.tokens.has("Crowd Cheer"):
			notes.append("not all Perfect at the top: no Crowd Cheer yet")
	if move.has("cashout"):
		notes.append("cash-out x%.1f, bar back to %d" % [_exec_tokens["cashout"], int(fighter.bar_steps[0])])
		fighter.spend_climb()
		_count("monk_cashouts")
	if not notes.is_empty():
		# The buff is earned. Its blocks stay on the bar (dimmed, like every
		# played block): removing them mid-combo shrank and shifted the rest
		# of the bar under the playhead and threw the Monk's timing off.
		_flash("%s: %s" % [move["name"], ", ".join(notes)])
		print("%s: %s" % [move["name"], ", ".join(notes)])


## True for the hit that uses the move's Hold or Tap timing (its last hit;
## any earlier hits, like Agility's extra one, are normal presses).
func _special_hit(entry: Dictionary, hit: int) -> bool:
	return int(entry["timing"]) != Moves.TimingType.PRESS and hit == (entry["hits"] as Array).size() - 1


## Called as a Hold / Tap hit lands: settles its result and returns its
## extra damage share (on top of the Perfect bonus, used for partial taps).
func _settle_special_timing(entry: Dictionary, hit: int) -> float:
	if not _special_hit(entry, hit):
		return 0.0
	match int(entry["timing"]):
		Moves.TimingType.CODE:
			if float(entry["move"].get("surge", 0.0)) > 0.0 and _exec_taps > 0:
				# Energy: the taps after the code add damage.
				_popup(_exec_attacker, "SURGE x%d" % _exec_taps, Color(0.75, 0.55, 1.0))
				return float(entry["move"]["surge"]) * float(_exec_taps)
		Moves.TimingType.HOLD:
			if _exec_holding:
				# Still holding when the arrow flies: let go too late.
				_exec_holding = false
				battle_menu.exec_holding = false
				_mark_timing(hit, Timing.PARTIAL)
				_popup(_exec_attacker, "LATE", Color(0.85, 0.8, 0.6))
		Moves.TimingType.TAP:
			var needed: int = maxi(int(entry["taps"]), 1)
			if float(entry["move"].get("surge", 0.0)) > 0.0:
				# Arcane Surge: every tap adds its share; the cap is a Perfect.
				_mark_timing(hit, Timing.PERFECT if _exec_taps >= needed else Timing.PARTIAL)
				if _exec_taps > 0:
					_popup(_exec_attacker, "SURGE x%d" % _exec_taps, Color(0.75, 0.55, 1.0))
				return float(entry["move"]["surge"]) * float(_exec_taps)
			if _exec_taps >= needed:
				_mark_timing(hit, Timing.PERFECT)
			elif _exec_taps > 0:
				_mark_timing(hit, Timing.PARTIAL)
				_popup(_exec_attacker, "%d / %d" % [_exec_taps, needed], Color(0.85, 0.8, 0.6))
				return perfect_damage_bonus * float(_exec_taps) / needed
	return 0.0


func _mark_timing(hit: int, result: int) -> void:
	_exec_timings[hit] = result
	battle_menu.slot_results[_exec_slot][hit] = result


## Party AP refill: faster while a Mage stands still (Focus).
func _focus_ap_mult() -> float:
	return 1.0 + focus_ap_bonus if _focus_boost else 1.0


## Mage Focus, every free-roam frame: standing still builds a charge every
## focus_seconds (up to focus_max), walking focus_walk_meters loses one.
## Jumps (teleports, pushes) aren't walking and cost nothing.
func _tick_focus(world_delta: float) -> void:
	var still_any := false
	for member in party:
		if member.focus_max <= 0:
			continue
		var last: Vector3 = member.get_meta("focus_pos", member.global_position)
		member.set_meta("focus_pos", member.global_position)
		if member.is_down:
			if member.focus > 0:
				member.set_focus(0)
			continue
		var moved := Vector2(member.global_position.x - last.x, member.global_position.z - last.z).length()
		if moved > 0.002 and moved < 0.5:
			member.focus_clock = 0.0
			member.focus_walked += moved
			while member.focus_walked >= focus_walk_meters:
				member.focus_walked -= focus_walk_meters
				if member.focus > 0:
					member.set_focus(member.focus - 1)
					_count("focus_walked_off")
					_popup(member, "-FOCUS", Color(0.7, 0.65, 0.9))
			continue
		if moved >= 0.5:
			continue  # a jump: not walking, not standing still either
		still_any = true
		member.focus_clock += world_delta
		if member.focus_clock >= focus_seconds:
			member.focus_clock -= focus_seconds
			if member.focus < member.focus_max:
				member.set_focus(member.focus + 1)
				if member.focus == 1:
					Sfx.play("focus", -4.0)  # Focus switches on
				_count("focus_charges")
				if member.focus == member.focus_max:
					_popup(member, "FOCUS MAX", Color(0.75, 0.55, 1.0))
	_focus_boost = still_any


## She attacks: Focus is spent (the bar back to its base), then rebuilds.
func _spend_focus(fighter: Combatant) -> void:
	if fighter == null or fighter.focus_max <= 0:
		return
	if fighter.focus > 0:
		_count_amount("focus_spent", fighter.focus)
	fighter.set_focus(0)
	fighter.focus_clock = 0.0
	fighter.focus_walked = 0.0


## Enchant: every ally but the Mage carries the element for `turns` of her
## turns. One at a time: a new one replaces the old.
func _enchant(user: Combatant, element: String, turns: int) -> void:
	for member in party:
		for e in ENCHANTS:
			member.statuses.erase("enchant_" + e)
	for ally in _standing(party):
		if ally != user:
			ally.add_status("enchant_" + element, turns, user)
			_popup(ally, element.to_upper(), Color(0.75, 0.55, 1.0))
	_count("enchants")
	_count("enchant_" + element)


func _enchant_running() -> bool:
	for member in party:
		for e in ENCHANTS:
			if member.statuses.has("enchant_" + e):
				return true
	return false


## AI Cleric's Lifeline: she stands in a danger area she can't walk out of
## in time (or is hurt along with an ally), and an ally within reach stands
## clear of it. The most hurt such ally; null if none.
func _ai_lifeline_target(cleric: Combatant) -> Combatant:
	var dangers := _ally_dangers(cleric)
	var caught := _in_danger(cleric.global_position, dangers)
	var best: Combatant = null
	for ally in _standing(party):
		if ally == cleric or cleric.gap_to(ally) > 8.0 or _in_danger(ally.global_position, dangers):
			continue
		var low := float(ally.hp) / maxf(ally.max_hp, 1.0)
		var both_hurt := low < 0.6 and float(cleric.hp) / maxf(cleric.max_hp, 1.0) < 0.6
		if not caught and not both_hurt:
			continue
		if best == null or low < float(best.hp) / maxf(best.max_hp, 1.0):
			best = ally
	return best


## AI Mage's Enchant: Lightning while a Stagger bar is up (a boss move to
## break), Ice against a crowd, Fire otherwise. "" with nobody to carry it.
func _ai_enchant_pick() -> String:
	if _standing(party).size() < 2:
		return ""
	var foes := _standing(enemies)
	for enemy in foes:
		var view: Dictionary = enemy.stagger_view()
		if not view.is_empty() and not view.get("hits", false):
			return "lightning"
	if foes.size() >= 3:
		return "ice"
	return "fire"


## Siphon Shot: a hit on an enemy she Siphoned heals the Archer 3% of her
## max HP (6% on a Perfect). Only her own hits.
func _siphon(attacker: Combatant, move: Dictionary) -> void:
	var target := _combo_target
	if target == null or target.is_down or not target.statuses.has("siphoned"):
		return
	if target.statuses["siphoned"].get("caster") != attacker or attacker.is_down:
		return
	var share := 0.03 * (2.0 if _exec_hit_perfect and attacker == _exec_attacker else 1.0)
	var healed: int = attacker.heal(maxi(roundi(attacker.max_hp * share), 1))
	if healed > 0:
		_count_amount("siphon_healed", healed)
		_popup(attacker, "+%d" % healed, Color(0.45, 1.0, 0.55))
		SpellFx.sparks(self, attacker.global_position + Vector3(0, 1.0, 0), Color(0.45, 1.0, 0.55), 6)


## An ally's hit under Enchant: the move with the element's light effect
## added (a copy; moves that already do more keep theirs).
func _enchanted(attacker: Combatant, move: Dictionary) -> Dictionary:
	if attacker.team != Combatant.Team.PARTY:
		return move
	for e in ENCHANTS:
		if not attacker.statuses.has("enchant_" + e):
			continue
		var out := move.duplicate()
		match e:
			"fire":
				if float(out.get("burn", 0.0)) <= 0.0:
					out["burn"] = enchant_burn
					out["burn_turns"] = 1
			"ice":
				out["chill"] = true
			"lightning":
				out["stagger_mult"] = float(out.get("stagger_mult", 1.0)) * enchant_stagger_mult
			"energy":
				out["knockback"] = maxf(float(out.get("knockback", 0.0)), enchant_push)
		_count("enchanted_hits")
		return out
	return move


## A WASD direction during a Mage spell: the next arrow of its code moves
## the code on, done = Perfect (before the hit lands); a wrong one starts it
## over. Never a miss.
func _judge_code(dir: String) -> void:
	if _exec_outro >= 0.0 or _exec_lead_in > 0.0 or _exec_reveal_left > 0.0 \
			or _counter_recover > 0.0 or _counter_from != null or _exec_slot >= _plan.size():
		return
	var entry := _plan[_exec_slot]
	var code: Array = entry.get("code", [])
	if int(entry["timing"]) != Moves.TimingType.CODE or code.is_empty():
		return
	var hit := (entry["hits"] as Array).size() - 1
	if _exec_hits_done > hit or _exec_code >= code.size():
		return  # landed, or already typed
	if _exec_time < float(entry["duration"]) * float(entry["code_start"]):
		return
	if String(code[_exec_code]) == dir:
		_exec_code += 1
		if _exec_code >= code.size():
			_mark_timing(hit, Timing.PERFECT)
	else:
		_exec_code = 0
		_count("code_restarts")
		_popup(_exec_attacker, "RESTART", Color(0.85, 0.8, 0.6))
	battle_menu.exec_code = _exec_code


## "W S A" for a code (the keys to press).
static func code_text(code: Array) -> String:
	var keys := {"up": "W", "down": "S", "left": "A", "right": "D"}
	var parts: PackedStringArray = []
	for dir in code:
		parts.append(keys.get(dir, "?"))
	return " ".join(parts)


## Confirm let go during the combo: ends a Hold. Inside the release box =
## Perfect; too early = no Perfect (the hit still lands, nothing lost).
func _judge_release() -> void:
	if not _exec_holding or _exec_outro >= 0.0:
		return
	_exec_holding = false
	battle_menu.exec_holding = false
	var entry := _plan[_exec_slot]
	var hit := _next_timed(entry)
	if not _special_hit(entry, hit):
		return
	var duration: float = entry["duration"]
	var window: float = battle_menu.box_fraction(entry) * duration
	var hit_time := duration * float(entry["times"][hit])
	if _exec_time >= hit_time - window:
		_mark_timing(hit, Timing.PERFECT)
	else:
		_mark_timing(hit, Timing.PARTIAL)
		_popup(_exec_attacker, "EARLY", Color(0.85, 0.8, 0.6))


## J during the combo: inside the next hit's timing box = Perfect;
## anywhere else = miss, and the chain ends right there. One try per hit.
## Hold hits: the press goes in the first box, then _judge_release judges
## the let-go. Tap hits: every press inside the tap stretch counts, and
## presses outside it are simply ignored.
func _judge_timing() -> void:
	if _exec_outro >= 0.0 or _exec_lead_in > 0.0 or _exec_reveal_left > 0.0:  # presses during the lead-in / reveal are ignored
		return
	if _counter_recover > 0.0:
		return  # the breather after a parried counter: presses are ignored
	if _counter_from != null:
		if absf(_counter_left) <= counter_parry_window:
			_counter_parried()
		else:
			_counter_failed("Too early!")
		return
	var entry := _plan[_exec_slot]
	var duration: float = entry["duration"]
	var window: float = battle_menu.box_fraction(entry) * duration
	var hit := _next_timed(entry)
	if hit < _exec_timings.size() and _special_hit(entry, hit) and int(entry["timing"]) == Moves.TimingType.CODE:
		# A spell code: the key does nothing (never a miss), except Energy's
		# free taps once the code is in.
		if float(entry["move"].get("surge", 0.0)) > 0.0 and _exec_code >= (entry["code"] as Array).size() \
				and _exec_taps < int(entry["taps"]):
			_exec_taps += 1
			battle_menu.exec_taps = _exec_taps
			_charge_tap(entry)
		return
	if hit < _exec_timings.size() and _special_hit(entry, hit):
		if int(entry["timing"]) == Moves.TimingType.TAP:
			if _exec_time < duration * float(entry["tap_start"]):
				return  # before the tap stretch: ignored
			if _exec_taps >= int(entry["taps"]) and float(entry["move"].get("surge", 0.0)) > 0.0 \
					and not entry["move"].get("surge_uncapped", false):
				return  # Arcane Surge: past the cap, taps are just ignored
			if entry["move"].get("surge_uncapped", false):
				# Tortoise Special: no ceiling, every tap adds damage, and
				# every tap is a punch.
				_exec_taps += 1
				battle_menu.exec_taps = _exec_taps
				_charge_tap(entry)
				_flurry_tap()
				if _exec_taps == int(entry["taps"]):
					_mark_timing(hit, Timing.PERFECT)
				return
			if _exec_taps >= int(entry["taps"]):
				# One tap too many: a miss, like any wrong press.
				_timing_miss(hit, "Too many taps!")
				return
			_exec_taps += 1
			battle_menu.exec_taps = _exec_taps
			_charge_tap(entry)
			if _exec_taps >= int(entry["taps"]):
				_mark_timing(hit, Timing.PERFECT)
				Sfx.play("timing_hit")
			return
		# Hold: the press must start in the first box.
		if _exec_timings[hit] != Timing.NONE or _exec_holding:
			return
		var start_time := duration * float(entry["hold_start"])
		if _exec_time >= start_time - window and _exec_time <= start_time:
			_exec_holding = true
			battle_menu.exec_holding = true
			return
		if _exec_time > start_time:
			# Started late: no Perfect this time, but no harm done.
			_mark_timing(hit, Timing.PARTIAL)
			_popup(_exec_attacker, "LATE", Color(0.85, 0.8, 0.6))
			return
		# Too early: a normal miss (below).
	if hit >= _exec_timings.size() or _exec_timings[hit] != Timing.NONE:
		return  # one try per hit
	var hit_time := duration * float(entry["times"][hit])
	if _exec_time >= hit_time - window:
		_exec_timings[hit] = Timing.PERFECT
		battle_menu.slot_results[_exec_slot][hit] = Timing.PERFECT
		_ring_result(_exec_slot, hit, true)
		Sfx.play("timing_hit")
	elif Time.get_ticks_msec() - _last_landed_ms <= late_press_grace * 1000.0:
		# A press just after a hit landed is that hit's late press, not an
		# early one for the next box: no Perfect for it, but no miss either.
		_popup(_exec_attacker, "LATE", Color(0.85, 0.8, 0.6))
	else:
		_timing_miss(hit, "Missed the timing!")


## A missed timing (a wrong press, or a tap too many): the chain ends, the
## party loses all its AP and max AP resets.
func _timing_miss(hit: int, why: String) -> void:
	_mark_timing(hit, Timing.MISS)
	_count("timing_misses")
	_ring_result(_exec_slot, hit, false)
	_popup(_exec_attacker, "MISS", Color(1.0, 0.35, 0.3))
	if _exec_slot == 0 and _exec_hits_done == 0:
		Sfx.play("attack_whiff")  # the very first input failed: the attack misses entirely
	var reset_note := _reset_max_ap()
	ap = 0.0  # a missed timing costs all the party's AP
	if _exec_attacker != null and _exec_attacker.climbs():
		var slip := _monk_slip(_exec_attacker, true)
		if slip != "":
			why += " " + slip + "."
	_flash("%s The chain ends, AP lost. %s" % [why, reset_note])
	_stop_combo()


## The highest max AP can grow to: 100 per party member plus 100, capped at
## max_ap_limit (500), plus any bonus from skills or items.
func max_ap_ceiling() -> float:
	return minf(max_ap_ceiling_per_member * (party.size() + 1), max_ap_limit) + max_ap_limit_bonus


## Raises the party's max AP for the rest of the fight. Returns a message.
func _grow_max_ap(amount: float, at: Combatant) -> String:
	var before := current_max_ap
	current_max_ap = minf(current_max_ap + amount, max_ap_ceiling())
	stats["max_ap_peak"] = maxi(int(stats.get("max_ap_peak", 0)), int(current_max_ap))
	var gained := current_max_ap - before
	if gained <= 0.0:
		return "Max AP is already at its limit (%d)" % int(max_ap_ceiling())
	_popup(at, "+%d MAX AP" % roundi(gained), Color(0.45, 0.85, 1.0))
	return "Max AP +%d (now %d)" % [roundi(gained), int(current_max_ap)]


## AP gain scales with how far max AP has grown: 1.0 at the starting cap,
## 1.5 at 150, 2.0 at 200.
func _ap_gain_multiplier() -> float:
	return minf(current_max_ap / max_ap, ap_regen_max_multiplier)


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
## Parried the counter-swing: the stance breaks, the rest of the combo hits
## harder, and the playhead moves on.
func _counter_parried() -> void:
	var enemy := _counter_from
	_counter_left = -INF
	_counter_from = null
	battle_menu.counter_progress = -1.0
	_counter_bonus = counter_broken_bonus
	_counter_recover = counter_recover_seconds
	battle_menu.recover_progress = 0.0
	if enemy != null and not enemy.is_down:
		_cancel_enemy_skill(enemy)  # breaks the Counter stance
		_popup(enemy, "COUNTER BROKEN!", Color(1.0, 0.85, 0.3))
		_flash("Countered the counter! %s is open: the rest of the combo deals +%d%%" % [enemy.display_name, roundi(counter_broken_bonus * 100.0)])
	_count("counter_parries")
	if combo_counter:
		combo_counter.hit(true)


## Missed the counter-swing (too early or too late): countered, combo over.
func _counter_failed(why: String) -> void:
	var enemy := _counter_from
	_counter_left = -INF
	_counter_from = null
	battle_menu.counter_progress = -1.0
	if enemy != null and _exec_attacker != null and not _exec_attacker.is_down:
		var taken := _hurt(_exec_attacker, counter_stance_damage, false, "%s: Counter stance" % enemy.display_name, enemy, "Counter stance")
		_popup(_exec_attacker, str(taken), Color(1.0, 0.4, 0.3))
		_flash("%s %s's counter lands! Combo stopped" % [why, enemy.display_name])
		_check_party()
	_stop_combo()


func _stop_combo() -> void:
	_counter_left = -INF
	_counter_from = null
	_counter_bonus = 0.0
	_counter_recover = 0.0
	battle_menu.counter_progress = -1.0
	battle_menu.recover_progress = -1.0
	_exec_outro = 0.7
	if combo_counter:
		combo_counter.finish()


## One hit of a move lands: works out everyone it reaches (by the move's
## area), applies it to each, and handles barriers. Returns false if the
## combo should stop (countered, attacker down, nobody left to hit).
func _land_hit(attacker: Combatant, move: Dictionary, multiplier: float, first_hit: bool, last_hit: bool = true) -> bool:
	if attacker.is_down:
		return false
	move = _enchanted(attacker, move)
	_siphon(attacker, move)
	if attacker.team == Combatant.Team.PARTY and _combo_target != null and not _combo_target.is_down:
		var fx_move := move
		if not last_hit:
			fx_move = move.duplicate()
			fx_move["_not_last"] = true  # a finisher's big effect waits for its last hit
		if _charge_orb != null and last_hit:
			fx_move = move.duplicate()
			fx_move["fx_charge"] = _charge_fraction()  # a full charge lands bigger
			_end_charge_orb()
		SpellFx.impact(self, attacker, _combo_target, fx_move, _exec_hit_perfect)  # looks only
		BattleSounds.impact(attacker, fx_move, _exec_hit_perfect)
	# Support effects come with the last hit (a Hold's Perfect is known by then).
	if last_hit and float(move["barrier"]) > 0.0:
		_give_barrier(attacker, move)
	if last_hit and float(move.get("heal_allies", 0.0)) > 0.0:
		_art_heal(attacker, move)
	if first_hit and move.get("teleport_behind", false) and _combo_target != null and not _combo_target.is_down:
		# Shadowstep: 1.5x if it started in front, then appear behind.
		if _combo_target.no_positionals or not _combo_target.is_behind(attacker.global_position):
			multiplier *= float(move.get("front_mult", 1.0))  # no positionals: every bonus applies
		_step_behind(attacker, _combo_target)
		_count("shadowsteps")
	if last_hit and move.get("detonate_burns", false):
		_detonate_burns(attacker)
	if last_hit and move.has("delayed_blast") and _combo_target != null and not _combo_target.is_down:
		_add_blast(attacker, move, _combo_target.global_position)
	if last_hit and float(move.get("ap_refund", 0.0)) > 0.0:
		ap = minf(ap + float(move["ap_refund"]), current_max_ap)
		_popup(attacker, "+%d AP" % int(move["ap_refund"]), Color(0.75, 0.55, 1.0))
		_count("ap_refunds")
	var keep_going := true
	for victim in _hit_victims(attacker, move):
		var enemy: Combatant = victim[0]
		if not _resolve_combo_hit(attacker, enemy, move, multiplier * float(victim[1])):
			keep_going = false
			break
	_check_enemies()
	if _game_over or not keep_going:
		return false
	if _combo_target.is_down:
		# The target fell: carry on against the nearest enemy still in reach.
		_combo_target = _attack_target(false)
		if _combo_target == null:
			return false
		_flash("%s turns to %s" % [attacker.display_name, _combo_target.display_name])
	return true


## Ice Spear: a regular enemy freezes (no moving, its timeline stopped) and
## its turn is pushed back; a boss only loses turn time, halved each time.
func _deep_freeze(target: Combatant, move: Dictionary) -> void:
	var push := float(move.get("turn_push", 0.0))
	if target.boss:
		var times := int(target.get_meta("freeze_resist", 0))
		target.set_meta("freeze_resist", times + 1)
		push *= pow(0.5, times)
		_knock_back_enemy(target, push)
		_popup(target, "CHILLED TO THE BONE  -%d" % roundi(push), Color(0.6, 0.85, 1.0))
		_count("boss_freezes")
		return
	target.freeze_left = maxf(target.freeze_left, float(move["deep_freeze"]))
	target.add_status("frozen", 1, target)
	_knock_back_enemy(target, push)
	_popup(target, "FROZEN", Color(0.6, 0.9, 1.0))
	_count("deep_freezes")


## Stasis: a regular enemy's timeline stops; a boss only loses turn time,
## halved each time.
func _stasis(target: Combatant, move: Dictionary) -> void:
	if target.boss:
		var times := int(target.get_meta("stasis_resist", 0))
		target.set_meta("stasis_resist", times + 1)
		var push := float(move.get("turn_push", 0.0)) * pow(0.5, times)
		_knock_back_enemy(target, push)
		_popup(target, "SLOWED  -%s" % MoveInfo._num(push), Color(0.7, 0.75, 1.0))
		return
	target.freeze_left = maxf(target.freeze_left, float(move["stasis"]))
	_popup(target, "STASIS %ss" % MoveInfo._num(float(move["stasis"])), Color(0.7, 0.75, 1.0))
	_count("stasis_holds")


## Flare: every burning enemy takes all its Burn left at once.
func _detonate_burns(attacker: Combatant) -> void:
	for enemy in _standing(enemies):
		if enemy.burn_turns <= 0:
			continue
		var total := enemy.burn_damage * maxi(enemy.burn_stacks, 1) * enemy.burn_turns
		enemy.burn_turns = 0
		enemy.burn_stacks = 1
		var dealt := enemy.take_damage(total, false)
		_add_threat(enemy, attacker, dealt)
		if playtest:
			playtest.deal(attacker, dealt)
		_popup(enemy, "FLARE %d" % dealt, Color(1.0, 0.55, 0.15))
		_count("flares")
	_check_enemies()


## Inferno: a marked circle that explodes after `seconds` of running time.
func _add_blast(attacker: Combatant, move: Dictionary, at: Vector3) -> void:
	var info: Dictionary = move["delayed_blast"]
	var ring := _make_ring(float(info["radius"]), 0.18, Color(1.0, 0.35, 0.1, 0.9))
	add_child(ring)
	ring.global_position = Vector3(at.x, 0.06, at.z)
	_blasts.append({"pos": at, "radius": float(info["radius"]), "left": float(info["seconds"]),
			"attacker": attacker, "move": move, "ring": ring, "hit": float(info["hit"])})
	_flash("%s's %s: the circle explodes in %s s" % [attacker.display_name, move["name"], MoveInfo._num(float(info["seconds"]))])


func _tick_blasts(seconds: float) -> void:
	for blast in _blasts.duplicate():
		blast["left"] = float(blast["left"]) - seconds
		var ring: Node3D = blast["ring"]
		if is_instance_valid(ring):
			ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(float(blast["left"]) * 12.0))  # pulses as it counts down
		if float(blast["left"]) > 0.0:
			continue
		_blasts.erase(blast)
		if is_instance_valid(ring):
			ring.queue_free()
		var attacker: Combatant = blast["attacker"]
		var move: Dictionary = blast["move"]
		var hit_any := false
		for enemy in _standing(enemies):
			var gap := Vector2(enemy.global_position.x - blast["pos"].x, enemy.global_position.z - blast["pos"].z).length() - enemy.body_radius
			if gap > float(blast["radius"]):
				continue
			hit_any = true
			var mult := float(blast["hit"]) * (1.0 + staggered_bonus if enemy.statuses.has("staggered") else 1.0)
			var dealt := enemy.take_damage(ceili(attacker.attack_power * mult), false)
			_add_threat(enemy, attacker, dealt)
			_fill_stagger(attacker, enemy, dealt, move)
			if playtest:
				playtest.deal(attacker, dealt)
			_popup(enemy, str(dealt), Color(1.0, 0.5, 0.15))
			if float(move.get("burn", 0.0)) > 0.0 and not enemy.is_down:
				enemy.burn_damage = maxi(enemy.burn_damage if enemy.burn_turns > 0 else 0, ceili(attacker.attack_power * float(move["burn"])))
				enemy.burn_stacks = maxi(enemy.burn_stacks if enemy.burn_turns > 0 else 1, int(move.get("burn_stacks", 1)))
				enemy.burn_turns = int(move.get("burn_turns", 2))
		_count("blasts_hit" if hit_any else "blasts_missed")
		_flash("%s explodes%s" % [move["name"], "" if hit_any else ": nobody in it"])
		_check_enemies()


## Puts a fighter right behind an enemy, facing it (Shadowstep).
func _step_behind(mover: Combatant, enemy: Combatant) -> void:
	var back := -enemy.flat_forward()
	if enemy.anchored:
		# Nothing behind a wall: appear at its side (its "cheek") instead.
		var side := enemy.flat_forward().cross(Vector3.UP)
		back = side if side.dot(mover.global_position - enemy.global_position) >= 0.0 else -side
	SpellFx.shadow_puff(self, mover.global_position)
	mover.global_position = enemy.global_position + back * (enemy.body_radius + mover.body_radius + 0.25)
	_keep_in_arena(mover)
	SpellFx.shadow_puff(self, mover.global_position)
	mover.face_toward(enemy.global_position - mover.global_position, 1.0, 100000.0)
	_popup(mover, "SHADOWSTEP", Color(0.78, 0.45, 1.0))


## Everyone one hit reaches, each with a damage share: [[enemy, share], ...].
func _hit_victims(attacker: Combatant, move: Dictionary) -> Array:
	var result := []
	var size: float = move["area_size"]
	match move["area"]:
		Moves.Area.TARGET_CIRCLE:
			for enemy in _standing(enemies):
				var d := enemy.global_position.distance_to(_combo_target.global_position) - enemy.body_radius
				if enemy == _combo_target or d <= size:
					result.append([enemy, 1.0])
		Moves.Area.LINE:
			# From the attacker through the target and beyond: full damage on
			# the first enemy, falloff on everyone behind.
			var dir := _combo_target.global_position - attacker.global_position
			dir.y = 0.0
			var length := dir.length() + 6.0
			dir = dir.normalized()
			var in_line := []
			for enemy in _standing(enemies):
				var offset := enemy.global_position - attacker.global_position
				offset.y = 0.0
				var along := offset.dot(dir)
				var side := (offset - dir * along).length()
				if along >= 0.0 and along <= length and side <= size / 2.0 + enemy.body_radius and _can_see(attacker, enemy):
					in_line.append([enemy, along])
			in_line.sort_custom(func(a, b): return a[1] < b[1])
			for i in in_line.size():
				result.append([in_line[i][0], 1.0 if i == 0 else float(move["falloff"])])
		Moves.Area.SELF_CIRCLE:
			for enemy in _standing(enemies):
				if attacker.gap_to(enemy) <= size:
					result.append([enemy, 1.0])
		Moves.Area.ALL:
			for enemy in _standing(enemies):
				result.append([enemy, 1.0])
		_:
			result.append([_combo_target, 1.0])
	if int(move.get("chain", 0)) > 0 and _combo_target != null:
		# Chain Lightning: jumps to the nearest others within chain_range.
		var others := _standing(enemies).filter(func(e): return e != _combo_target \
				and e.global_position.distance_to(_combo_target.global_position) <= float(move.get("chain_range", 5.0)))
		others.sort_custom(func(x, y): return x.global_position.distance_to(_combo_target.global_position) \
				< y.global_position.distance_to(_combo_target.global_position))
		for e in others.slice(0, int(move["chain"])):
			result.append([e, float(move.get("chain_share", 0.75))])
	return result


## While building a combo, shows what the highlighted move would hit: its
## area on the floor (a circle on the target, a line through it, a circle
## around the attacker) in the move's colour, and a ring under each enemy it
## reaches (fainter for reduced-damage hits). Divine Barrier also shows who
## gets the barrier. Rebuilt only when the highlighted move changes.
func _update_move_preview() -> void:
	var showing := _menu_mode == BattleMenu.Mode.COMBO and _party_turn() and controlled != null \
			and _combo_target != null and not _moves.is_empty()
	var key := ""
	if showing:
		key = "%d|%s|%s" % [battle_menu.move_index, controlled.get_instance_id(), _combo_target.get_instance_id()]
	if key == _preview_key:
		return
	_preview_key = key
	_clear_move_preview()
	if not showing:
		return
	var move: Dictionary = _moves[clampi(battle_menu.move_index, 0, _moves.size() - 1)]
	var color: Color = move["color"]
	var usable := battle_menu.move_index < battle_menu.move_usable.size() and battle_menu.move_usable[battle_menu.move_index]
	var size: float = move["area_size"]
	var shape_def: EnemySkill = null
	var place := Vector3.ZERO
	var aim := Vector3.ZERO
	match move["area"]:
		Moves.Area.TARGET_CIRCLE:
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, size + _combo_target.body_radius, 360.0, 0, 0.0, 0)
			place = _combo_target.global_position
		Moves.Area.SELF_CIRCLE:
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, size + controlled.body_radius, 360.0, 0, 0.0, 0)
			place = controlled.global_position
		Moves.Area.LINE:
			var dir := _combo_target.global_position - controlled.global_position
			dir.y = 0.0
			shape_def = EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.LINE, dir.length() + 6.0, 0.0, 0, 0.0, 0)
			shape_def.width = size
			place = controlled.global_position
			aim = _combo_target.global_position
	if shape_def != null:
		_preview_area = AttackRange.new()
		add_child(_preview_area)
		_preview_area.global_position = Vector3(place.x, 0.05, place.z)
		if aim != Vector3.ZERO and Vector2(aim.x - place.x, aim.z - place.z).length() > 0.05:
			_preview_area.look_at(Vector3(aim.x, 0.05, aim.z), Vector3.UP)
		_preview_area.show_hazard(shape_def, color if usable else Color(0.6, 0.6, 0.65))
		_preview_area.set_alert(usable)  # brighter, so it reads through the menu
	if float(move["barrier_radius"]) > 0.0 and float(move["barrier_radius"]) < Moves.UNLIMITED:
		var barrier_def := EnemySkill.make("", Skills.Kind.ATTACK, EnemySkill.Shape.CIRCLE, float(move["barrier_radius"]), 360.0, 0, 0.0, 0)
		_preview_barrier = AttackRange.new()
		add_child(_preview_barrier)
		_preview_barrier.global_position = Vector3(controlled.global_position.x, 0.04, controlled.global_position.z)
		_preview_barrier.show_hazard(barrier_def, Color(0.55, 0.8, 1.0))
		for ally in _standing(party):
			if ally.global_position.distance_to(controlled.global_position) <= float(move["barrier_radius"]):
				_add_preview_mark(ally, Color(0.55, 0.8, 1.0, 0.9))
		if move.has("perfect_barrier_radius"):
			# A faint outer ring: how far a Perfect barrier reaches.
			var reach := _make_ring(float(move["perfect_barrier_radius"]), 0.08, Color(0.55, 0.8, 1.0, 0.45))
			add_child(reach)
			reach.global_position = Vector3(controlled.global_position.x, 0.05, controlled.global_position.z)
			_preview_marks.append(reach)
	if not usable:
		return
	for victim in _hit_victims(controlled, move):
		var enemy: Combatant = victim[0]
		var share: float = victim[1]
		var mark_color := color.lightened(0.3)
		mark_color.a = 0.95 if share >= 1.0 else 0.5
		_add_preview_mark(enemy, mark_color)


func _add_preview_mark(fighter: Combatant, color: Color) -> void:
	var mark := _make_ring(fighter.body_radius + 0.45, 0.12, color)
	fighter.add_child(mark)
	mark.position.y = 0.08
	_preview_marks.append(mark)
	_preview_hits.append(fighter)


## While a strike you can react to plays (its rings closing in for a Parry
## or Defend), enemy areas and the party's gold reach rings fade out so the
## strike's rings are all you need to read.
## They come back the moment it's over. Unavoidable strikes keep them.
func _fade_areas_during_strike() -> void:
	# (visible, not GeometryInstance3D.transparency: the Compatibility
	# renderer used by some exports ignores transparency.)
	var hide := _strike != null and not _strike.def.is_mechanic()
	for member in party:
		member.hide_reach = hide
	for enemy in enemies:
		var areas: Array = enemy.extra_areas.duplicate()
		if enemy.attack_range and not enemy.is_down:
			areas.append(enemy.attack_range)
		for area in areas:
			if not is_instance_valid(area):
				continue
			if hide and area.visible:
				area.visible = false
				area.set_meta("faded_for_strike", true)
			elif not hide and area.has_meta("faded_for_strike"):
				area.remove_meta("faded_for_strike")
				area.visible = not (area == enemy.attack_range and enemy.is_down)


## Shows each enemy's positional ring (see PositionalRing) while a fighter
## that strikes from behind (flanks: the Assassin) is steered, so the player
## can see where to stand. Hidden for everyone else.
func _update_behind_cones() -> void:
	var show := controlled != null and controlled.flanks and not controlled.is_down and not _game_over
	for enemy in enemies:
		var ring: PositionalRing = _behind_cones.get(enemy)
		var wanted := show and not enemy.is_down
		if not wanted:
			if ring != null:
				ring.visible = false
			continue
		if ring == null:
			ring = PositionalRing.new()
			enemy.add_child(ring)
			ring.build(enemy.body_radius + 0.9, enemy.no_positionals)
			_behind_cones[enemy] = ring
		ring.visible = true
		ring.set_lit(enemy.is_behind(controlled.global_position))  # brighter when you're in it


## Tells the timeline who the player is aiming at (the chosen target while
## picking one, the combo's target while building or playing a combo) and
## who the previewed move would also hit, so twins like Kobold Archer A and
## B can be told apart on the bar.
func _update_timeline_targets() -> void:
	var target: Combatant = null
	if _party_turn():
		if _menu_mode == BattleMenu.Mode.TARGET and _pending_skill.get("target", -1) != Moves.Target.POINT \
				and not _target_choices.is_empty():
			target = _target_choices[clampi(_target_index, 0, _target_choices.size() - 1)]
		elif (_menu_mode == BattleMenu.Mode.COMBO or _menu_mode == BattleMenu.Mode.EXECUTING) and _combo_target != null:
			target = _combo_target
	timeline_bar.target = target
	timeline_bar.also_hit = _preview_hits
	# The targeted enemy's floating name turns gold too, to match the bar.
	var named: Combatant = target if target != null and target.team == Combatant.Team.ENEMY else null
	if named != _named_target:
		if is_instance_valid(_named_target):
			_named_target.set_highlighted(false)
		if named != null:
			named.set_highlighted(true)
		_named_target = named


func _clear_move_preview() -> void:
	for node in [_preview_area, _preview_barrier]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_preview_area = null
	_preview_barrier = null
	for mark in _preview_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_preview_marks.clear()
	_preview_hits.clear()


## Cleric's Divine Barrier: allies near the user get barrier HP.
func _give_barrier(user: Combatant, move: Dictionary) -> void:
	var share := float(move["barrier"])
	var radius := float(move["barrier_radius"])
	if _exec_hit_perfect and move.has("perfect_barrier"):
		# A perfect Hold: a stronger barrier over a wider circle.
		share = float(move["perfect_barrier"])
		radius = float(move.get("perfect_barrier_radius", radius))
		_popup(user, "BIG BARRIER", Color(0.55, 0.8, 1.0))
	for ally in _standing(party):
		if ally.global_position.distance_to(user.global_position) <= radius:
			var gained := ally.add_shield(ceili(ally.max_hp * share), user)
			SpellFx.shield(self, ally)
			if gained > 0:
				_popup(ally, "+%d BARRIER" % gained, Color(0.55, 0.8, 1.0))


## Blessed Strike / Divine Judgment: heals allies near the user (or the whole
## party), more on a Perfect.
func _art_heal(user: Combatant, move: Dictionary) -> void:
	var share := float(move["heal_allies"])
	if _exec_hit_perfect and move.has("perfect_heal"):
		share = float(move["perfect_heal"])
	var radius := float(move.get("heal_radius", Moves.UNLIMITED))
	for ally in _standing(party):
		if ally.global_position.distance_to(user.global_position) <= radius:
			var healed := ally.heal(ceili(ally.max_hp * share))
			if healed > 0:
				SpellFx.heal(self, ally)
				Sfx.play("heal_spell")
				Sfx.play_later("hp_number", 0.35)
			_count_amount("hp_healed", healed)
			if healed > 0:
				_popup(ally, "+%d" % healed, Color(0.5, 1.0, 0.55))
				_count("art_healing")


## Assassin's Marks from one hit: Backstab from behind adds one, every 3rd
## Stab on a Marked enemy adds one, Execute uses them all up.
func _apply_mark_effects(attacker: Combatant, target: Combatant, move: Dictionary, behind: bool) -> void:
	if target.is_down:
		return
	if int(move.get("marks_from_behind", 0)) > 0 and behind:
		_add_marks(target, int(move["marks_from_behind"]))
	if move.get("stab_marks", false) and target.marks > 0:
		var stabs: int = target.get_meta("marked_stabs", 0) + 1
		target.set_meta("marked_stabs", stabs)
		if stabs % 3 == 0:
			_add_marks(target, 1)
	if int(move.get("add_marks", 0)) > 0:
		_add_marks(target, int(move["add_marks"]))  # Ambush, Phantom Rush, Thousand Cuts
	if move.get("consume_marks", false) and target.marks > 0:
		_count("executes")
		target.set_marks(0)
		_popup(target, "MARKS SPENT", Color(0.78, 0.45, 1.0))


func _add_marks(target: Combatant, count: int) -> void:
	var before := target.marks
	var now := target.set_marks(target.marks + count)
	if now > before:
		_popup(target, "+%d MARK" % (now - before), Color(0.78, 0.45, 1.0))
		_count("marks")


## Marks on all standing enemies (the Assassin's auto-parry needs one).
func _marks_out() -> int:
	var total := 0
	for enemy in _standing(enemies):
		total += enemy.marks
	return total


## Spends one Mark for an auto-parry: from the attacking enemy if it has
## one, otherwise from the enemy with the most.
func _spend_mark(prefer: Combatant) -> void:
	var source: Combatant = prefer if prefer != null and prefer.marks > 0 else null
	if source == null:
		for enemy in _standing(enemies):
			if source == null or enemy.marks > source.marks:
				source = enemy
	if source != null and source.marks > 0:
		source.set_marks(source.marks - 1)


## Applies the skill triangle to one hit on one enemy, then the move's extra
## effects (stun, knockback). Returns false only if a Counter stance
## punished the attacker (the combo stops).
func _resolve_combo_hit(attacker: Combatant, target: Combatant, move: Dictionary, multiplier: float) -> bool:
	if attacker.is_down or target.is_down:
		return true
	# If this beats it, its ragdoll flies away from here, harder for pushes
	# and finishers.
	target.set_meta("hit_from", attacker.global_position)
	target.set_meta("hit_power", 1.5 + float(move.get("knockback", 0.0)) + (3.0 if move.get("finisher", false) else 0.0))
	var move_name: String = move["name"]

	if target.stance == Skills.Kind.COUNTER and _menu_mode == BattleMenu.Mode.EXECUTING \
			and attacker == _exec_attacker and _counter_from == null:
		# The blow is caught and the counter-swing comes: parry it with the
		# hit key (_judge_timing) or take it (_update_combo).
		_counter_left = counter_parry_lead
		_counter_from = target
		battle_menu.counter_progress = 0.0
		_popup(target, "COUNTER!", Skills.info(Skills.Kind.COUNTER)["color"])
		_flash(Keybinds.fill("%s's Counter stance catches the %s: press {confirm} as it swings back!" % [target.display_name, move_name]))
		_count("counter_parry_tries")
		return true
	if target.stance == Skills.Kind.COUNTER:
		# Counter beats every attack: the enemy punishes you, combo over.
		var taken := _hurt(attacker, counter_stance_damage, false, "%s: Counter stance" % target.display_name, target, "Counter stance")
		_popup(target, "COUNTER!", Skills.info(Skills.Kind.COUNTER)["color"])
		_popup(attacker, str(taken), Color(1.0, 0.4, 0.3))
		_flash("%s's Counter stance punishes the %s! Combo stopped" % [target.display_name, move_name])
		_check_party()
		return false

	var note := ""
	# Assassin: where the attacker stands matters.
	var behind := target.is_behind(attacker.global_position)
	if move.get("front_miss", false) and not behind:
		_popup(target, "MISS", Color(0.7, 0.7, 0.75))
		_flash("%s misses: it only works from behind" % move_name)
		return true
	if behind and float(move.get("behind_mult", 1.0)) > 1.0:
		multiplier *= float(move["behind_mult"])
		_popup(attacker, "FROM BEHIND", Color(0.78, 0.45, 1.0))
		_count("behind_hits")
	if float(move.get("mark_bonus", 0.0)) > 0.0 and target.marks > 0:
		# Execute: each Mark it spends adds 15% (0.6x on its 4x from behind).
		multiplier *= 1.0 + float(move["mark_bonus"]) * target.marks
	var was_guarding := target.stance == Skills.Kind.DEFENSE
	var was_chilled := target.statuses.has("chilled")  # Static Frost freezes the Chilled
	if target.stance == Skills.Kind.DEFENSE:
		match move["effect"]:
			Moves.Effect.BREAK:
				note = "Guard broken!"
				_count("guard_breaks")
				_cancel_enemy_skill(target)
			Moves.Effect.PIERCE:
				note = "Pierce!"
				_count("guard_breaks")
			_:
				var guard := target.loaded_def
				if guard != null and guard.let_through > 0.0:
					# A partial guard: the hit lands, softened.
					multiplier *= guard.let_through
					note = "Guarded: %d%% gets through" % roundi(guard.let_through * 100.0)
					Sfx.play("enemy_defend")
				else:
					_popup(target, "BLOCKED", Skills.info(Skills.Kind.DEFENSE)["color"])
					Sfx.play("enemy_defend")
					_flash("%s's Defense blocks the %s. Piercing or breaking moves get through!" % [target.display_name, move_name])
					return true
	elif target.loaded_skill == Skills.Kind.SMASH and (move["kind"] == Skills.Kind.ATTACK \
			or (move["effect"] == Moves.Effect.BREAK and target.interrupt_resist > 1)):
		# Bosses shrug off single hits: it takes interrupt_resist Attack-type
		# hits (or one breaking move) to stop their Smash.
		var needed := 1 if move["effect"] == Moves.Effect.BREAK else target.interrupt_resist
		var hits: int = target.get_meta("smash_hits", 0) + 1
		target.set_meta("smash_hits", hits)
		if hits >= needed:
			target.set_meta("smash_hits", 0)
			if _try_cancel(target):
				note = "Smash interrupted!"
				_count("interrupts")
		else:
			_popup(target, "%d / %d" % [hits, needed], Color(1.0, 0.75, 0.4))

	if move.has("shatter") and target.team == Combatant.Team.ENEMY:
		# Shatter: Frozen 2.5x (ends the Freeze), Chilled 1.6x, else 0.6x.
		var shares: Array = move["shatter"]
		if target.statuses.has("frozen"):
			multiplier *= float(shares[0])
			target.statuses.erase("frozen")
			target.freeze_left = 0.0
			note = "Shattered!"
			_count("shatters")
		elif target.statuses.has("chilled"):
			multiplier *= float(shares[1])
			_popup(target, "CRACKED", Color(0.6, 0.85, 1.0))
		else:
			multiplier *= float(shares[2])
	if target.statuses.has("exposed"):
		multiplier *= 1.0 + exposed_bonus  # Archer's Exposing Shot
	if target.statuses.has("staggered"):
		multiplier *= 1.0 + staggered_bonus
	var damage := ceili(attacker.attack_power * multiplier)
	var dealt := target.take_damage(damage, false)
	_add_threat(target, attacker, dealt)
	if _fill_stagger(attacker, target, dealt, move):
		note = "Staggered!"
	if playtest:
		playtest.deal(attacker, dealt)
	if combo_counter and _menu_mode == BattleMenu.Mode.EXECUTING and attacker == _exec_attacker:
		combo_counter.damage(dealt)
	var is_smash: bool = move["kind"] == Skills.Kind.SMASH
	_popup(target, str(damage), Color(1.0, 0.7, 0.3) if is_smash else Color.WHITE)
	_apply_mark_effects(attacker, target, move, behind)

	var ritual := target.loaded_def
	if ritual != null and ritual.special == EnemySkill.Special.HEAL_ALLIES and not target.is_down \
			and attacker.gap_to(target) <= ritual.interrupt_range:
		# Close-range hits break a healing ritual.
		target.interrupt_count += 1
		if target.interrupt_count >= ritual.interrupt_hits and _try_cancel(target):
			_count("interrupts")
			note = "%s interrupted!" % ritual.skill_name
		else:
			_popup(target, "%d / %d" % [target.interrupt_count, ritual.interrupt_hits], Color(0.5, 1.0, 0.6))
	if move["stun"] and not target.is_down and _loaded_offensive(target) \
			and not (move.get("stun_not_bosses", false) and target.boss):
		# Stunning Arrow / Crusader's Edge: an enemy about to strike loses the
		# attack and drops back out of the casting zone. Once per action of
		# its own (shared with the Knight's halt), so it can't be locked.
		if target.control_used and not move.get("ignore_cancel_lock", false):
			_popup(target, "NO STUN", Color(0.7, 0.7, 0.7))
		elif _try_cancel(target, move.get("ignore_cancel_lock", false)):
			target.control_used = true
			note = "Stunned! Attack cancelled"
			_count("stuns")
	if target.lightweight and not target.is_down and float(move["knockback"]) < lightweight_push:
		# Lightweight (Gust Sprites): any hit knocks it back.
		move = move.duplicate()
		move["knockback"] = lightweight_push
	if _ai_playing and float(move["knockback"]) > 0.0 and _carries_area(target) and not target.lightweight:
		# An AI ally doesn't push an enemy whose area moves with it while it
		# prepares: the area would land on the party (a Golem Smash pushed
		# onto the side everyone had just run to). You still can.
		move = move.duplicate()
		move["knockback"] = 0.0
		_count("ai_pushes_held")
	# Smash: breaking a guard spends the blow, so no knock-back that hit.
	if float(move["knockback"]) > 0.0 and not target.is_down \
			and not (was_guarding and move.get("knockback_unguarded", false)):
		var before := target.global_position
		_knock_away(target, attacker.global_position, move["knockback"])
		if move.get("follow", false) and not attacker.is_down:
			# Crusader's Edge: the Knight presses after it, staying in reach.
			var moved := target.global_position - before
			moved.y = 0.0
			attacker.global_position += moved
			_keep_in_arena(attacker)
	if move.get("pin", false) and not target.is_down and target.team == Combatant.Team.ENEMY:
		# Arrow Rain: rooted until its own next turn starts.
		if not target.statuses.has("pinned"):
			_popup(target, "PINNED", Color(0.55, 0.9, 0.5))
		target.add_status("pinned", 1, target)
		_count("pins")
	if float(move.get("burn", 0.0)) > 0.0 and not target.is_down and target.team == Combatant.Team.ENEMY:
		# Fire: burns each time it acts, for burn_turns of its actions (refreshed, not stacked).
		if target.burn_turns <= 0:
			_popup(target, "BURNING", Color(1.0, 0.5, 0.2))
		target.burn_damage = maxi(target.burn_damage if target.burn_turns > 0 else 0, ceili(attacker.attack_power * float(move["burn"])))
		# Fireball / Inferno: Burn x2 / x3 (each tick that many times over).
		var stacks := int(move.get("burn_stacks", 1))
		target.burn_stacks = maxi(target.burn_stacks if target.burn_turns > 0 else 1, stacks)
		if stacks > 1:
			_popup(target, "BURN x%d" % target.burn_stacks, Color(1.0, 0.5, 0.2))
		target.burn_turns = int(move.get("burn_turns", 2))
		_count("burns")
	if float(move.get("expose", 0.0)) > 0.0 and not target.is_down and target.team == Combatant.Team.ENEMY:
		# Exposing Shot: everyone hits it harder until its own next turn starts.
		if not target.statuses.has("exposed"):
			_popup(target, "EXPOSED", Color(1.0, 0.9, 0.4))
		target.add_status("exposed", 1, target)
		_count("exposes")
	if move.get("chill", false) and not target.is_down and target.team == Combatant.Team.ENEMY:
		# Frost / Blizzard: half walking speed until its own next turn starts.
		if not target.statuses.has("chilled"):
			_popup(target, "CHILLED", Color(0.6, 0.85, 1.0))
		target.add_status("chilled", 1, target)
		_count("chills")
	if float(move.get("deep_freeze", 0.0)) > 0.0 and not target.is_down and target.team == Combatant.Team.ENEMY:
		_deep_freeze(target, move)
	if move.has("freeze_if_chilled") and was_chilled and not target.is_down and target.team == Combatant.Team.ENEMY:
		_deep_freeze(target, move["freeze_if_chilled"])
	if float(move.get("stasis", 0.0)) > 0.0 and not target.is_down and target.team == Combatant.Team.ENEMY:
		_stasis(target, move)
	if float(move.get("freeze", 0.0)) > 0.0 and not target.is_down and target.team == Combatant.Team.ENEMY \
			and _last_hit_of_slot():
		# Guard Strike / Shield Rush: its timeline stops for a moment. Once per
		# enemy action: until it acts again, more shield blows don't refreeze it.
		if target.control_used:
			_popup(target, "NO HALT", Color(0.7, 0.7, 0.7))
		else:
			target.control_used = true
			target.freeze_left = maxf(target.freeze_left, float(move["freeze"]))
			_popup(target, "HALTED %.1fs" % float(move["freeze"]), Color(0.6, 0.95, 0.7))
			_count("freezes")
	if move.get("draws_aggro", false) and not target.is_down and target.team == Combatant.Team.ENEMY \
			and _last_hit_of_slot():
		# Knight's shield blows: the enemy comes for them for one of their turns;
		# each more shield blow adds a turn, up to aggro_max_turns (a Taunt of
		# his own is never shortened). Once per move, however many hits.
		var held: Dictionary = target.statuses.get("taunt", {})
		var turns := 1
		if held.get("caster") == attacker:
			turns = maxi(int(held.get("turns", 0)), mini(int(held.get("turns", 0)) + 1, aggro_max_turns))
		else:
			_popup(target, "AGGRO", Color(1.0, 0.45, 0.35))
		target.add_status("taunt", turns, attacker)
		_count("aggro_hits")
	if float(move.get("rally", 0.0)) > 0.0 and target.team == Combatant.Team.ENEMY:
		# Cleric's Bash: the party's max AP grows (a Perfect adds its own +5).
		_flash(_grow_max_ap(float(move["rally"]), attacker))
		_count("rallies")

	if note != "":
		_popup(target, note.to_upper(), Color(1.0, 0.85, 0.2))
		_flash(note)
	if target.is_down:
		_flash("%s is defeated!" % target.display_name)
	return true


# --- Stagger -------------------------------------------------------------------

## True for Smash-type moves, breaking moves and Arts: they fill Stagger
## bars faster.
static func heavy_move(move: Dictionary) -> bool:
	return int(move.get("kind", Skills.Kind.ATTACK)) == Skills.Kind.SMASH \
			or int(move.get("effect", Moves.Effect.NONE)) == Moves.Effect.BREAK or move.has("recipe")


## Head-on: in front of it (its front half), or any side of a boss
## without positionals.
func _head_on(attacker: Combatant, target: Combatant) -> bool:
	if target.no_positionals:
		return true
	var to := attacker.global_position - target.global_position
	to.y = 0.0
	return to.length() < 0.01 or target.flat_forward().dot(to.normalized()) >= 0.0


## A hit fills the target's Stagger bar if it's preparing a skill with one
## and the hit came head-on. Returns true when it Staggers.
func _fill_stagger(attacker: Combatant, target: Combatant, dealt: int, move: Dictionary) -> bool:
	var def := target.loaded_def
	if def == null or def.stagger_bar <= 0 or target.is_down or dealt <= 0 or stagger_off:
		return false
	if not _head_on(attacker, target):
		if target.skill_revealed:
			_popup(target, "NOT HEAD-ON", Color(0.7, 0.7, 0.75))
		return false
	target.stagger_fill += dealt * (stagger_heavy_mult if heavy_move(move) else 1.0) * float(move.get("stagger_mult", 1.0))
	if target.stagger_fill < target.stagger_need(def):
		return false
	_stagger(target)
	return true


## A full Stagger bar: the skill breaks (or turns into its stagger_into
## form), the enemy is knocked back to just before the casting zone unless
## its skill only changed, and it takes extra damage until its next turn.
## Each Stagger makes that enemy's bars bigger (resistance).
func _stagger(enemy: Combatant) -> void:
	var def := enemy.loaded_def
	_count("staggers")
	enemy.staggers_taken += 1  # resistance: its next bars are bigger
	enemy.add_status("staggered", 1, enemy)
	_popup(enemy, "STAGGERED", Color(1.0, 0.8, 0.25))
	SpellFx.stagger(self, enemy)
	if def.stagger_into != null:
		var revealed := enemy.skill_revealed
		_clear_cast_extras(enemy)
		enemy.loaded_def = def.stagger_into
		enemy.loaded_skill = enemy.loaded_def.kind
		enemy.stagger_fill = 0.0
		enemy.skill_revealed = false
		_build_cast_areas(enemy)
		if revealed:
			_reveal_skill(enemy)
		_flash("%s is Staggered! Its %s becomes %s" % [enemy.display_name, def.skill_name, enemy.loaded_def.skill_name], 3.5)
		return
	if enemy.has_meta("follow_up_at"):
		enemy.remove_meta("follow_up_at")
	_finish_enemy_skill(enemy, false)
	enemy.timeline_pos = minf(enemy.timeline_pos, cast_zone_start - stagger_knockback)
	enemy.timeline_penalty = 0.0
	_flash("%s is Staggered! Its %s breaks, and it takes +%d%% damage until its next turn" % [enemy.display_name, def.skill_name, roundi(staggered_bonus * 100.0)], 3.5)


## The enemy loses its prepared skill (and stance) and is knocked back
## out of the casting zone, so it has to prepare again.
func _num_m(meters: float) -> String:
	return str(snappedf(meters, 0.1)).trim_suffix(".0")


## Bosses: why its current skill can't be cancelled right now ("" = it can).
## Breaking a Defense / Counter stance isn't a cancel and always works.
func _cancel_resisted(enemy: Combatant) -> String:
	var def := enemy.loaded_def
	if def != null and def.uncancellable:
		return "UNSTOPPABLE"
	if enemy.cancel_lock > 0:
		return "IMMUNE"
	return ""


## Cancels a boss's skill if it isn't resisted; shows why when it is.
## Returns true if the skill was cancelled.
func _try_cancel(enemy: Combatant, ignore_lock := false) -> bool:
	var why := _cancel_resisted(enemy)
	if ignore_lock and why == "IMMUNE":
		why = ""  # Overcharge: through the cancel immunity (not UNSTOPPABLE)
		_count("overcharge_cancels")
	if why != "":
		_popup(enemy, why, Color(0.75, 0.8, 0.95))
		_count("cancels_resisted")
		return false
	_cancel_enemy_skill(enemy)
	if enemy.cancel_every > 0:
		enemy.cancels_taken += 1
		enemy.cancel_lock = mini(enemy.cancel_every - 1 + enemy.cancels_taken - 1, MAX_CANCEL_LOCK)
	return true


func _cancel_enemy_skill(enemy: Combatant) -> void:
	_finish_enemy_skill(enemy, false)
	enemy.timeline_pos = minf(enemy.timeline_pos - interrupt_push, cast_zone_start - 1.0)


## Pushes an enemy back on the timeline; if that takes it out of the
## casting zone, it loses the skill it was preparing.
func _knock_back_enemy(enemy: Combatant, amount: float) -> void:
	enemy.timeline_pos -= amount
	if enemy.loaded_skill != Skills.NONE and enemy.timeline_pos < cast_zone_start:
		_finish_enemy_skill(enemy, false)


## How far a move reaches for this fighter (its own reach, or the fighter's;
## True Sight extends both).
func _move_reach(fighter: Combatant, move: Dictionary) -> float:
	var own: float = move["reach"]
	if own >= Moves.UNLIMITED:
		return INF
	var sight := fighter.reach() / fighter.attack_reach if fighter.attack_reach > 0.0 else 1.0
	return own * sight if own >= 0.0 else fighter.reach()


func _can_target(fighter: Combatant, enemy: Combatant, move: Dictionary) -> bool:
	if move.get("marked_any_range", false) and enemy.marks > 0:
		return true  # Shadowstep reaches any Marked enemy
	var move_reach := _move_reach(fighter, move)
	if fighter.gap_to(enemy) > move_reach:
		return false
	return move_reach == INF or _can_see(fighter, enemy)


## The enemy the controlled fighter's attacks go after: the nearest one in
## its normal reach, or else the nearest one a long-range attack (Holy Light)
## can reach.
## check_cost: only count attacks the party can pay for right now (off
## mid-combo, when the moves are already paid).
func _attack_target(check_cost: bool = true) -> Combatant:
	var attacks: Array[Dictionary] = Moves.attacks(controlled.class_id)
	if check_cost:
		attacks = attacks.filter(_affordable)
	var normal: Array[Dictionary] = attacks.filter(func(m): return float(m["reach"]) < 0.0)
	for pool in [normal, attacks]:
		var best: Combatant = null
		var best_gap := INF
		for enemy in _standing(enemies):
			var gap := controlled.gap_to(enemy)
			if gap >= best_gap:
				continue
			for move in pool:
				if _can_target(controlled, enemy, move):
					best = enemy
					best_gap = gap
					break
		if best != null:
			return best
	return null


## True if the controlled fighter could put this attack on the bar now
## (its cost fits both the party's AP and the class's combo bar).
## Windup at ACT: is there a move the party can afford that reaches this
## enemy? If not, the committed attack can't happen.
func _can_play_on(fighter: Combatant, target: Combatant) -> bool:
	if target == null or target.is_down:
		return false
	for move in Moves.attacks(fighter.class_id).filter(_affordable):
		if _can_target(fighter, target, move):
			return true
	return false


func _affordable(move: Dictionary) -> bool:
	var cost := float(move["cost"]) * (2.0 if controlled.statuses.has("arcane_cost") else 1.0)
	return cost <= minf(_pool(controlled), controlled.combo_limit)


# --- Skills (Abilities) ----------------------------------------------------

func _open_skills() -> void:
	_skills = Moves.skills(controlled.class_id)
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for skill in _skills:
		var note := ""
		if int(skill["cost"]) > _pool(controlled):
			note = "Not enough AP"
		elif int(skill["cost"]) > controlled.combo_limit:
			note = "Costs more than %s's AP limit" % controlled.display_name
		elif skill["target"] == Moves.Target.ENEMY and _skill_choices(skill).is_empty():
			note = "No enemy has a Mark" if skill.get("needs_marks", false) else "No enemy in range"
		elif skill["target"] == Moves.Target.OTHER_ALLY and _skill_choices(skill).is_empty():
			note = "No ally to choose"
		usable.append(note == "")
		notes.append(note)
	if _skills.is_empty():
		_flash("%s has no skills" % controlled.display_name)
		return
	_menu_mode = BattleMenu.Mode.SKILLS
	battle_menu.element_pick = false
	battle_menu.moves = _skills
	battle_menu.move_usable = usable
	battle_menu.move_notes = notes
	battle_menu.move_index = 0


## Items: the pouch as a list shaped like the Abilities list (count instead
## of AP). Greyed out: none left, or nothing to use it on.
func _open_items() -> void:
	_skills = Items.list(pouch)
	var usable: Array[bool] = []
	var notes: PackedStringArray = []
	for item in _skills:
		var note := ""
		if int(item["count"]) <= 0:
			note = "None left"
		elif item["name"] == Items.POTION and not _standing(party).any(func(m): return m.hp < m.max_hp):
			note = "Everyone is at full HP"
		elif item["name"] == Items.ETHER and ap >= current_max_ap - 0.5:
			note = "AP is already full"
		elif item["name"] == Items.REVIVE and _skill_choices(item).is_empty():
			note = "Nobody is down"
		usable.append(note == "")
		notes.append(note)
	_menu_mode = BattleMenu.Mode.SKILLS
	battle_menu.element_pick = false
	battle_menu.moves = _skills
	battle_menu.move_usable = usable
	battle_menu.move_notes = notes
	battle_menu.move_index = 0


## An item from the pouch takes effect (already counted down).
func _use_item(item: Dictionary, user: Combatant, target: Combatant) -> String:
	var item_name := String(item["name"])
	_count("items_" + item_name.to_lower())
	match item_name:
		Items.POTION:
			var who := target if target != null else user
			var healed := who.heal(ceili(who.max_hp * float(item["heal"])))
			if healed > 0:
				SpellFx.heal(self, who)
			Sfx.play("item_use")
			Sfx.play_later("hp_number", 0.4)
			_count_amount("hp_healed", healed)
			_popup(who, "+%d" % healed, Color(0.45, 0.95, 0.5))
			return "%s uses a Potion: %s recovers %d HP" % [user.display_name, who.display_name, healed]
		Items.ETHER:
			var before := ap
			ap = minf(ap + current_max_ap * float(item["ap_share"]), current_max_ap)
			var gained := roundi(ap - before)
			SpellFx.burst(self, user.global_position + Vector3(0, 1.0, 0), item["color"], 0.7)
			Sfx.play("item_use")
			Sfx.play_later("hp_number", 0.4)
			_popup(user, "+%d AP" % gained, item["color"])
			return "%s uses an Ether: +%d AP" % [user.display_name, gained]
		Items.REVIVE:
			Sfx.play("item_use")
			_revive(target, float(item["heal"]))
			return "%s uses a Revive: %s is back up" % [user.display_name, target.display_name]
	return "%s uses %s" % [user.display_name, item_name]


## A downed party member gets back up with this share of their max HP,
## where they fell (or at the party's start, after a fall off the arena).
## Whatever enemies are casting right now can't hit them with that cast.
func _revive(member: Combatant, share: float) -> void:
	if member.has_meta("windup_target"):
		_clear_windup(member)
	var at := member.global_position
	if member.get_meta("fell", false) or not arena.walkable(Vector3(at.x, 0.0, at.z), member.body_radius):
		var spawn := arena.spawn_points(false, 1)[0].origin
		at = spawn
	member.revive(ceili(member.max_hp * share))
	member.global_position = Vector3(at.x, 0.0, at.z)
	_keep_in_arena(member)
	var casting: Array = []
	for enemy in _standing(enemies):
		if enemy.loaded_def != null and enemy.loaded_skill != Skills.NONE:
			casting.append(enemy)
	if not casting.is_empty():
		member.set_meta("revive_safe", casting)
	SpellFx.heal(self, member)
	SpellFx.ring(self, Vector3(member.global_position.x, 0.05, member.global_position.z), Items.GOLD, 1.6)
	Sfx.play("revive")
	_popup(member, "REVIVED", Items.GOLD)
	_count("revives")


## Enchant's element menu: a direction picks the element and casts it;
## back closes the menu (the skills list stays).
func _element_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		battle_menu.element_pick = false
		_element_skill = {}
		return
	for dir in CODE_KEYS:
		if event.is_action_pressed(CODE_KEYS[dir]):
			get_viewport().set_input_as_handled()
			_cast_element(ELEMENT_BY_DIR[dir])
			return


func _cast_element(element: String) -> void:
	var skill := _element_skill.duplicate()
	skill["element"] = element
	battle_menu.element_pick = false
	_element_skill = {}
	_use_skill(skill, controlled, controlled.global_position)


## Who a skill can be used on, nearest first.
func _skill_choices(skill: Dictionary) -> Array[Combatant]:
	var choices: Array[Combatant] = []
	match skill["target"]:
		Moves.Target.ALLY:
			choices = _standing(party)
			choices.erase(controlled)
			choices.push_front(controlled)
		Moves.Target.DOWNED_ALLY:
			choices = party.filter(func(m): return m.is_down)
		Moves.Target.OTHER_ALLY:
			choices = _standing(party)
			choices.erase(controlled)
			if skill.has("range"):
				choices = choices.filter(func(m): return controlled.gap_to(m) <= float(skill["range"]))
				choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
		Moves.Target.ENEMY:
			for enemy in _standing(enemies):
				if skill.get("needs_marks", false):
					if enemy.marks > 0:
						choices.append(enemy)  # any Marked enemy, however far
				elif controlled.gap_to(enemy) <= float(skill["range"]) and _can_see(controlled, enemy):
					choices.append(enemy)
			choices.sort_custom(func(a, b): return controlled.gap_to(a) < controlled.gap_to(b))
	return choices


func _choose_skill(index: int) -> void:
	var skill := _skills[index]
	if not battle_menu.move_usable[index]:
		_flash("%s: %s" % [skill["name"], battle_menu.move_notes[index]])
		return
	if skill.get("choose_element", false):
		# Enchant: a small menu of four directions picks the element.
		_element_skill = skill
		battle_menu.element_pick = true
		return
	match skill["target"]:
		Moves.Target.SELF, Moves.Target.NONE:
			_use_skill(skill, controlled, controlled.global_position)
		Moves.Target.POINT:
			var hint := "%s: move the marker with {move}" % skill["name"]
			if skill.get("ally_snap", false):
				hint += "  ({swap}: next to an ally)"
			_begin_targeting(skill, Keybinds.fill(hint))
			_target_marker.global_position = controlled.global_position + controlled.flat_forward() * 3.0
			_keep_marker_in_range()
		_:
			_target_choices = _skill_choices(skill)
			_target_index = 0
			var what := "an enemy" if skill["target"] == Moves.Target.ENEMY else ("a downed ally" if skill["target"] == Moves.Target.DOWNED_ALLY else "an ally")
			_begin_targeting(skill, Keybinds.fill("%s: choose %s ({up} / {down})" % [skill["name"], what]))


func _begin_targeting(skill: Dictionary, prompt: String) -> void:
	_pending_skill = skill
	_snap_ally = null
	_snap_index = -1
	_menu_mode = BattleMenu.Mode.TARGET
	battle_menu.target_prompt = prompt
	_clear_target_marker()
	_target_marker = _make_ring(0.75, 0.12, Color(1.0, 0.85, 0.3))
	add_child(_target_marker)
	_update_target_marker(0.0)


## Keeps the marker on the chosen fighter, or moves it with WASD for Jump.
func _update_target_marker(delta: float) -> void:
	if _target_marker == null:
		return
	if _pending_skill["target"] == Moves.Target.POINT:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input != Vector2.ZERO and _snap_ally != null:
			# Walking the marker leaves the ally: back to a spot near you.
			_target_marker.global_position = _snap_ally.global_position
			_snap_ally = null
			battle_menu.target_prompt = Keybinds.fill("%s: move the marker with {move}  ({swap}: next to an ally)" % _pending_skill["name"])
		if _snap_ally != null:
			_target_marker.global_position = _snap_ally.global_position + Vector3(0, 0.05, 0)
			return
		_target_marker.global_position += _camera_relative(input) * 7.0 * delta
		_keep_marker_in_range()
	elif not _target_choices.is_empty():
		var chosen := _target_choices[_target_index]
		_target_marker.global_position = chosen.global_position + Vector3(0, 0.05, 0)
		var label := "%s: %s" % [_pending_skill["name"], chosen.display_name]
		battle_menu.target_prompt = label + Keybinds.fill("   ({up} / {down} to change)")


## Teleport: Tab puts the marker on the next ally (any distance).
func _snap_marker_to_ally() -> void:
	var allies := _standing(party)
	allies.erase(controlled)
	if allies.is_empty():
		return
	_snap_index = (_snap_index + 1) % allies.size()
	_snap_ally = allies[_snap_index]
	battle_menu.target_prompt = Keybinds.fill("%s: next to %s  ({swap}: next ally, {move}: pick a spot)" % [_pending_skill["name"], _snap_ally.display_name])
	_update_target_marker(0.0)


func _keep_marker_in_range() -> void:
	var from := controlled.global_position
	var offset := _target_marker.global_position - from
	offset.y = 0.0
	var limit: float = _pending_skill["range"]
	if offset.length() > limit:
		offset = offset.normalized() * limit
	_target_marker.global_position = from + offset
	arena.keep_inside(_target_marker, controlled.body_radius)
	_target_marker.global_position.y = 0.05


func _confirm_target() -> void:
	var point := _target_marker.global_position
	var chosen: Combatant = null
	if not _target_choices.is_empty() and _pending_skill["target"] != Moves.Target.POINT:
		chosen = _target_choices[_target_index]
	elif _snap_ally != null and _pending_skill["target"] == Moves.Target.POINT:
		chosen = _snap_ally
	_clear_target_marker()
	if _choosing_attack_target:
		_choosing_attack_target = false
		if _command_phase:
			_commit_windup(chosen)
		else:
			_open_combo_bar(chosen)
		return
	_use_skill(_pending_skill, chosen, point)


func _clear_target_marker() -> void:
	if _target_marker != null:
		_target_marker.queue_free()
		_target_marker = null


## Carries out a skill. One per turn: afterwards the command menu comes
## back with Abilities greyed out, so you can still Attack or Wait.
func _use_skill(skill: Dictionary, target: Combatant, point: Vector3) -> void:
	var user := controlled
	battle_menu.element_pick = false  # Enchant's menu only lives while she's picking
	var head_start := 0.0
	var message := "%s uses %s" % [user.display_name, skill["name"]]
	var turns := int(skill.get("turns", 0))
	var anim_move := skill.duplicate()
	anim_move["_target"] = target  # a dash to someone (Shield Bash)
	user.animate("item" if skill.get("item", false) else "cast", anim_move)
	if skill.get("item", false):
		# Items: no AP; one less in the pouch; same one-per-turn slot.
		pouch[skill["name"]] = maxi(int(pouch.get(skill["name"], 0)) - 1, 0)
		_count("items")
		message = _use_item(skill, user, target)
	else:
		_pay(user, float(skill["cost"]))
		_count("skills")
		_count("skills_" + user.class_id)
	match "" if skill.get("item", false) else String(skill["name"]):
		"Light Heal", "Healing", "Full Cure":
			var who := target if target != null else user
			var healed := who.heal(ceili(who.max_hp * float(skill["heal"])))
			if user.class_id == "cleric" and who != user:
				SpellFx.beam(self, SpellFx.staff_top(user), who.global_position + Vector3(0, 1.0, 0), SpellFx.HOLY_GREEN, 0.1)
			if skill["name"] == "Full Cure":
				SpellFx.pillar(self, who.global_position, SpellFx.HOLY, 0.9)
			if healed > 0:
				SpellFx.heal(self, who)
				Sfx.play("heal_spell")
				Sfx.play_later("hp_number", 0.35)
			_count_amount("hp_healed", healed)
			_popup(who, "+%d" % healed, Color(0.45, 0.95, 0.5))
			message += ": %s recovers %d HP" % [who.display_name, healed]
		"Lifeline":
			# Cleric: dash beside an ally (out of any area she stood in), both heal.
			var from := user.global_position
			user.global_position = _spot_next_to(target, user)
			SpellFx.streak(self, from, user.global_position, SpellFx.HOLY_GREEN)
			var dir := user.global_position - from
			dir.y = 0.0
			if dir.length() > 0.1:
				user.face_toward(dir, 1.0, 100000.0)
				SpellFx.dust(self, user, -dir.normalized(), minf(dir.length(), 3.0))
			var total := 0
			for who in [user, target]:
				var healed: int = who.heal(ceili(who.max_hp * float(skill["heal"])))
				if healed > 0:
					SpellFx.heal(self, who)
					Sfx.play("heal_spell")
					Sfx.play_later("hp_number", 0.35)
				_popup(who, "+%d" % healed, Color(0.45, 0.95, 0.5))
				total += healed
			_count_amount("hp_healed", total)
			message += " to %s: both recover HP (%d in all)" % [target.display_name, total]
		"Brace", "Agility":
			user.add_status(String(skill["name"]).to_lower(), turns, user)
			_popup(user, String(skill["name"]).to_upper(), skill["color"])
		"Shield Bash":
			var dir := target.global_position - user.global_position
			dir.y = 0.0
			user.global_position = target.global_position - dir.normalized() * (target.body_radius + user.body_radius + 0.15)
			_keep_in_arena(user)
			user.face_toward(dir, 1.0, 100000.0)
			head_start = wait_head_start
			message += " on %s: next turn comes sooner" % target.display_name
		"Taunt":
			var taunted: Array[Combatant] = []
			for enemy in _standing(enemies):
				if user.gap_to(enemy) <= float(skill["radius"]):
					enemy.add_status("taunt", turns, user)
					taunted.append(enemy)
					_popup(enemy, "TAUNTED", skill["color"])
			message += ": " + (_names(taunted) + " now target " + user.display_name if not taunted.is_empty() else "nobody is close enough")
			# While it lasts, his Blocks and Parries also cover allies near him.
			user.add_status("guarding", turns, user)
			message += "; allies within %d m share his Block and Parry" % int(guard_radius)
		"Jump":
			user.global_position = Vector3(point.x, user.global_position.y, point.z)
			_keep_in_arena(user)
		"Riposte", "Suplex":
			user.riposte_left = float(skill["seconds"])
			user.counter_name = skill["name"]
			if skill["name"] == "Suplex":
				SpellFx.ring(self, Vector3(user.global_position.x, 0, user.global_position.z), SpellFx.KI, 1.8)
			_popup(user, String(skill["name"]).to_upper(), skill["color"])
		"Provoke":
			target.add_status("taunt", turns, user)
			user.add_status("provoking", turns, user)
			SpellFx.provoke(self, target)
			_popup(target, "PROVOKED", skill["color"])
			message += ": %s now targets %s" % [target.display_name, user.display_name]
		"Deep Breath":
			SpellFx.rings_up(self, user, Color(0.6, 1.0, 0.7))
			var healed := user.heal(ceili(user.max_hp * float(skill["heal"])))
			if healed > 0:
				SpellFx.heal(self, user)
				Sfx.play("heal_spell")
				Sfx.play_later("hp_number", 0.35)
			_count_amount("hp_healed", healed)
			_popup(user, "+%d" % healed, Color(0.45, 0.95, 0.5))
			message += ": recovers %d HP" % healed
			if user.climbs() and user.lost_step > user.combo_limit:
				user.combo_limit = user.lost_step  # the step he lost comes back
				user.lost_step = 0.0
				_popup(user, "BAR %d" % int(user.combo_limit), Color(1.0, 0.7, 0.3))
				message += "; bar back to %d" % int(user.combo_limit)
		"True Sight":
			for ally in _standing(party):
				ally.add_status("true_sight", turns, user)
			message += ": everyone's reach +25%, enemy attacks show early"
		"Arcane Barrier":
			user.add_status("arcane_barrier", 0, user)
			_popup(user, "BARRIER", skill["color"])
		"Enchant":
			var element := String(skill.get("element", "fire"))
			_enchant(user, element, int(skill["turns"]))
			message = "%s uses Enchant: %s on every ally" % [user.display_name, element.capitalize()]
		"Teleport":
			Sfx.play("teleport")
			if target != null and target != user:
				user.global_position = _spot_next_to(target, user)
				message += " next to %s" % target.display_name
			else:
				user.global_position = Vector3(point.x, user.global_position.y, point.z)
				_keep_in_arena(user)
		"Shielding":
			SpellFx.dome(self, user.global_position, SpellFx.HOLY_BLUE, 3.0)
			for ally in _standing(party):
				var gained := ally.add_shield(ceili(ally.max_hp * float(skill["shield"])), user)
				SpellFx.shield(self, ally)
				_popup(ally, "+%d SHIELD" % gained, Color(0.55, 0.8, 1.0))
		"Hook":
			if target.stance != Skills.NONE:
				_cancel_enemy_skill(target)  # breaks a Defense / Counter stance
				message += ": %s's stance is broken" % target.display_name
			elif _loaded_offensive(target):
				if _try_cancel(target):
					message += ": %s's move is stopped" % target.display_name
				else:
					message += ": %s resists" % target.display_name
			else:
				message += " on %s" % target.display_name
			SpellFx.chain(self, user.global_position + Vector3(0, 1.0, 0), target.global_position + Vector3(0, 1.0, 0))
			var dir := user.global_position - target.global_position
			dir.y = 0.0
			var room := maxf(dir.length() - user.body_radius - target.body_radius - 0.2, 0.0)
			if target.anchored and room > 0.0:
				# A wall boss can't be moved: the chain pulls the Assassin to it.
				user.global_position -= dir.normalized() * minf(float(skill["pull"]), room)
				_keep_in_arena(user)
				message += " (it doesn't budge: he's pulled to it)"
			elif room > 0.0:
				target.global_position += dir.normalized() * minf(float(skill["pull"]), room)
				_keep_in_arena(target, true)  # dragged over a hole: it falls
			if target.marks > 0:
				target.set_marks(0)
				message += " (its Marks are used up)"
			_popup(target, "HOOKED", skill["color"])
		"Siphon Shot":
			target.add_status("siphoned", int(skill["turns"]), user)
			_popup(target, "SIPHONED", skill["color"])
			SpellFx.ring(self, Vector3(target.global_position.x, 0, target.global_position.z), Color(0.45, 1.0, 0.55), 1.8)
			message += ": %s is Siphoned; her hits on it heal her" % target.display_name
		"Death Sentence":
			_add_marks(target, int(skill["marks"]))
			SpellFx.sentence(self, target)
			message += ": %s has %d Marks" % [target.display_name, target.marks]
		"Shadow Cloak":
			var count := target.marks
			target.set_marks(0)
			var gained := user.add_shield(ceili(user.max_hp * float(skill["shield"]) * count), user)
			SpellFx.rings_up(self, user, SpellFx.SHADOW)
			SpellFx.shield(self, user)
			_popup(user, "+%d SHIELD" % gained, Color(0.55, 0.8, 1.0))
			message += ": %d Marks become a %d shield" % [count, gained]
		"Vanish":
			user.add_status("vanish", turns, user)
			SpellFx.shadow_puff(self, user.global_position)
			for enemy in _standing(enemies):
				if enemy.cast_target == user:
					enemy.cast_target = _enemy_target(enemy)  # it loses its lock
			_popup(user, "VANISH", skill["color"])
			message += ": enemies lose track of %s" % user.display_name
		"Haste":
			target.add_status("haste", turns, target)  # counts the hasted ally's own turns
			SpellFx.haste(self, target)
			_popup(target, "HASTE", skill["color"])
			message += " on %s" % target.display_name
	_flash(message)
	print(message)
	_skill_used = true
	_turn_head_start += head_start
	# One Ability per turn: it stays shown as a chip on the menu and a badge
	# on the fighter's timeline icon until the turn (or the windup) ends.
	user.set_meta("ability_badge", {"name": String(skill["name"]), "color": skill["color"]})
	if user.is_down or _game_over or active != user:
		_menu_mode = BattleMenu.Mode.HIDDEN
		if active == user:
			_end_turn()
		return
	_open_commands()


## A free spot right beside a fighter (for Teleport).
func _spot_next_to(fighter: Combatant, mover: Combatant) -> Vector3:
	var distance := fighter.body_radius + mover.body_radius + 0.2
	for i in 8:
		var spot := fighter.global_position + Vector3.BACK.rotated(Vector3.UP, TAU * i / 8.0) * distance
		var free := true
		for c in combatants:
			if c != mover and not c.is_down and c.global_position.distance_to(spot) < c.body_radius + mover.body_radius:
				free = false
				break
		if free:
			mover.global_position = spot
			_keep_in_arena(mover)
			if mover.global_position.distance_to(spot) < 0.05:
				return spot
	return fighter.global_position + Vector3.BACK * distance


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
	var turn := Input.get_axis("camera_left", "camera_right")
	_cam_yaw -= turn * _camera_turn_sign() * camera_turn_degrees_per_second * Settings.camera_speed() / 100.0 * delta
	if InputMap.has_action("camera_tilt_up"):
		# The right stick tilts too (up: look up, as the mouse does).
		var tilt := Input.get_axis("camera_tilt_up", "camera_tilt_down")
		_cam_pitch = clampf(_cam_pitch + tilt * _camera_tilt_sign() * camera_tilt_degrees_per_second * Settings.camera_speed() / 100.0 * delta,
				camera_min_pitch, camera_max_pitch)
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_finale_close = move_toward(_finale_close, 1.0 if _finale == 1 else 0.0, real_delta * 1.5)
	if _finale == 1:
		# Locked on the falling enemy, at real speed (the world is slowed).
		_cam_focus = _cam_focus.lerp(_finale_point(), 1.0 - exp(-6.0 * real_delta))
	elif _pan_time < _pan_duration:
		# A pan: ease in and out from where the camera was to its new subject.
		_pan_time += delta
		var t := clampf(_pan_time / _pan_duration, 0.0, 1.0)
		_cam_focus = _pan_start.lerp(_camera_focus(), t * t * (3.0 - 2.0 * t))
	else:
		# This "1 - exp(...)" form makes the smoothing feel the same at any frame rate.
		var weight := 1.0 - exp(-camera_follow_speed * delta)
		_cam_focus = _cam_focus.lerp(_camera_focus(), weight)
	# Strikes that catch someone off screen: ease out so they're all in view.
	if _strike != null and not _strike_framing:
		_start_strike_framing()
	elif _strike == null:
		_strike_framing = false
	_strike_view = move_toward(_strike_view, 1.0 if _strike_framing else 0.0, delta * 3.0)
	_place_camera()


## Decides whether the current strike needs the camera to pull out, and
## where to: the middle of the enemy and everyone it hits, far enough back
## to fit them all.
func _start_strike_framing() -> void:
	var points: Array[Vector3] = [_strike.enemy.global_position]
	for target in _strike.targets:
		points.append(target.global_position)
	var all_seen := true
	for point in points:
		for height in [0.2, 1.6]:
			if not camera.is_position_in_frustum(point + Vector3(0, height, 0)):
				all_seen = false
	if all_seen:
		return
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	var spread := 0.0
	for point in points:
		spread = maxf(spread, Vector2(point.x - center.x, point.z - center.z).length())
	var half_fov := deg_to_rad(camera.fov) * 0.5
	_strike_focus = center
	_strike_distance = clampf((spread + 2.5) / tan(half_fov) * 1.1, _cam_distance, strike_frame_max_distance)
	_strike_framing = true


## Starts a smooth pan from the current view to the camera's new subject.
## Returns how long it takes (0 when it's already there).
func _begin_pan() -> float:
	_pan_start = _cam_focus
	var distance := _pan_start.distance_to(_camera_focus())
	_pan_time = 0.0
	_pan_duration = 0.0 if distance < 0.6 else clampf(0.3 + distance * 0.04, 0.3, turn_pan_max_seconds)
	return _pan_duration


func _place_camera() -> void:
	camera.global_rotation_degrees = Vector3(-_cam_pitch, _cam_yaw, 0.0)
	var t := _strike_view * _strike_view * (3.0 - 2.0 * _strike_view)  # smooth in and out
	var focus := _cam_focus.lerp(_strike_focus, t)
	var distance := lerpf(_cam_distance, _strike_distance, t)
	var close := _finale_close * _finale_close * (3.0 - 2.0 * _finale_close)
	distance *= lerpf(1.0, finale_zoom, close)
	_camera_offset = camera.global_basis.z * distance
	camera.global_position = focus + _camera_offset


## -1 when the camera's left / right is mirrored (Invert camera: X or both).
func _camera_turn_sign() -> float:
	return -1.0 if Settings.invert_x() else 1.0


## -1 when the camera's up / down is mirrored (Invert camera: Y or both).
func _camera_tilt_sign() -> float:
	return -1.0 if Settings.invert_y() else 1.0


## Mouse: hold the right button and drag to rotate and tilt, wheel to zoom.
## V puts the camera back to its starting angle.
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		var mouse := camera_mouse_sensitivity * Settings.mouse_sensitivity() / 100.0
		_cam_yaw -= event.relative.x * mouse * _camera_turn_sign()
		_cam_pitch = clampf(_cam_pitch + event.relative.y * mouse * _camera_tilt_sign(), camera_min_pitch, camera_max_pitch)
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = maxf(_cam_distance * 0.9, camera_min_distance)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = minf(_cam_distance * 1.1, camera_max_distance)
			return true
	if event.is_action_pressed("camera_reset"):
		_cam_yaw = 0.0
		_cam_pitch = _cam_start_pitch
		_cam_distance = camera_distance
		return true
	return false


## Turns WASD into a direction on the floor relative to the camera, so W
## always moves away from the screen, whichever way the camera faces.
func _camera_relative(input: Vector2) -> Vector3:
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return right.normalized() * input.x - forward.normalized() * input.y


## The point the camera looks at: the fighter whose turn it is (or, between
## turns, the one you steer), a bit of the way toward the nearest opponent so
## both stay on screen.
func _camera_focus() -> Vector3:
	if _finale == 1:
		return _finale_point()
	if _menu_mode == BattleMenu.Mode.COMBO and _party_turn() and active != null and _combo_target != null:
		# Building a combo: frame the attacker and the target, nudged so they
		# sit above the move list (which covers the middle of the screen).
		var center := active.global_position.lerp(_combo_target.global_position, 0.5)
		var toward_camera := camera.global_basis.z
		toward_camera.y = 0.0
		return center + toward_camera.normalized() * _cam_distance * 0.18
	# During anyone's turn the camera is on them; otherwise on who you steer.
	var subject := active if active != null else controlled
	var anchor := subject.global_position if subject != null else _party_center()
	var others := enemies if subject == null or subject.team == Combatant.Team.PARTY else _standing(party)
	var threat := _nearest_to_point(anchor, others)
	return anchor.lerp(threat.global_position, 0.35) if threat != null else anchor


func _update_ui(delta: float) -> void:
	party_status.controlled = controlled
	party_status.auto = _party_ai_on()
	if ap_meter:
		# Keep the AP bar between the two HP panels (tags and long names included).
		var origin := ap_meter.global_position.x
		ap_meter.limit_left = party_status.global_position.x + party_status.drawn_right - origin
		ap_meter.limit_right = enemy_status.global_position.x + enemy_status.drawn_left - origin
	for member in party:
		var in_reach := false
		for enemy in _standing(enemies):
			if member.gap_to(enemy) <= member.reach() and _can_see(member, enemy):
				in_reach = true
				break
		member.update_reach_ring(member == controlled, in_reach)
	battle_menu.mode = _menu_mode if _party_turn() and not _game_over else BattleMenu.Mode.HIDDEN
	for member in party:
		if member.climbs():
			member.show_climb(_party_turn() and active == member and not _game_over)
	if controlled != null:
		battle_menu.fighter_name = controlled.display_name
		battle_menu.target_name = _combo_target.display_name if _combo_target != null else ""
		battle_menu.show_defend = controlled.can_block
		battle_menu.show_parry = controlled.can_parry
		battle_menu.combo_limit = _exec_limit if _menu_mode == BattleMenu.Mode.EXECUTING and _exec_limit > 0.0 else controlled.combo_limit
		battle_menu.ap_available = _ap_before_combo if _menu_mode == BattleMenu.Mode.EXECUTING else _pool(controlled)
		var building := _menu_mode == BattleMenu.Mode.COMBO or _menu_mode == BattleMenu.Mode.EXECUTING
		battle_menu.segment_start = _segment_start(_menu_mode == BattleMenu.Mode.COMBO) if building else 0.0
		battle_menu.segment_available = _segment_available() if building and battle_menu.segment_start > 0.0 else battle_menu.ap_available
		battle_menu.reset_slots = _reset_slots(_menu_mode == BattleMenu.Mode.COMBO) if building else ([] as Array[int])
		var preview := _monk_preview() if building else ["", "", true]
		battle_menu.preview_main = preview[0]
		battle_menu.preview_perfect = preview[1]
		battle_menu.preview_perfect_on = preview[2]
		# The bar's next steps, shown past its end while building.
		battle_menu.step_marks.clear()
		if controlled.climbs() and _menu_mode == BattleMenu.Mode.COMBO:
			for length in controlled.bar_steps:
				if length > controlled.combo_limit:
					battle_menu.step_marks.append(length)
	if _game_over and end_screen != null:
		# The end panel has the stage.
		turn_label.text = ""
		warning_label.text = ""
		controls_label.visible = false
		battle_menu.visible = false
		return
	if _game_over:
		# The last blow, before the end panel shows: the last message stays.
		turn_label.text = _result_text
		warning_label.text = _flash_message
		controls_label.visible = true
		var won := _result_text == "Victory!"
		if tutorial_mode:
			controls_label.text = Keybinds.fill("Esc: back to the menu     {restart}: play the tutorial again")
		else:
			controls_label.text = Keybinds.fill("{next}: next round     {restart}: play again     Esc: menu" if won else "{restart}: retry     {next} / {prev}: next / previous round     Esc: menu")
			if playtest != null and playtest.saved:
				controls_label.text += "\nPlay-test report saved     O: open the reports folder"
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
		if battle_menu.reveal_name != "":
			warning_label.text = ""  # the NEW ART! banner has the stage
		elif _flash_time_left <= 0.0:
			warning_label.text = _timing_prompt()
	elif party_turn:
		turn_label.text = "%s's turn" % active.display_name
	else:
		turn_label.text = "%s acts!" % active.display_name

	ap_bar.max_value = current_max_ap
	ap_bar.value = ap
	ap_label.text = "Party AP  %d / %d" % [floori(ap), int(current_max_ap)]
	if ap_meter:
		ap_meter.pouch_text = _pouch_text() if pouch.values().any(func(n): return int(n) > 0) or not tutorial_mode else ""
		ap_meter.value = ap
		ap_meter.max_value = current_max_ap
		ap_meter.ceiling = max_ap_ceiling()
		ap_meter.flow_speed = _ap_gain_multiplier() * _focus_ap_mult()
		ap_meter.boost_left = 1.0 if _focus_boost else 0.0
		ap_meter.ghost_cost = battle_menu.combo_cost() if _menu_mode == BattleMenu.Mode.COMBO and _party_turn() else 0.0
		ap_meter.at_risk = _max_ap_at_risk()

	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		if _strike == null:
			warning_label.text = _flash_message + ("\n" + warning_label.text if warning_label.text else "")
	if _intro_left > 0.0 and _strike == null and _menu_mode != BattleMenu.Mode.EXECUTING:
		_intro_left -= delta
		warning_label.text = _intro_message + ("\n" + warning_label.text if warning_label.text else "")


func _strike_prompt() -> String:
	match _strike.reaction:
		Reaction.PARRY:
			return "Parry!"
		Reaction.PARRY_MISSED:
			return "Too early!"
		Reaction.DEFEND:
			return "Defending..."
	var parry_hint := Keybinds.fill("{parry}: Parry when the ring turns gold" if _strike.def.parryable() else "{parry}: can't Parry this")
	var defend_hint := Keybinds.fill("{defend}: Defend (%d AP)" % defend_cost if _strike.def.blockable() else "{defend}: can't Defend this")
	if not _strike_targets_can("parry"):
		parry_hint = Keybinds.fill("{parry}: ") + "%s can't parry" % _names(_strike.targets)
	var auto := _strike.targets.filter(func(t): return t.auto_parry_with_marks)
	if not auto.is_empty() and _strike.def.parryable():
		parry_hint = ("%s auto-parries (a Mark is spent)" % _names(auto)) if _marks_out() > 0 \
				else ("%s: no Marks out, can't parry" % _names(auto))
	if not _strike_targets_can("block"):
		defend_hint = Keybinds.fill("{defend}: ") + "%s can't block" % _names(_strike.targets)
	var parry_defends_only := (not _strike.def.parryable() or not _strike_targets_can("parry")) and _parry_key_defends()
	if parry_defends_only and _strike.targets.filter(func(t): return t.auto_parry_with_marks).is_empty():
		# Only blockers here (the Cleric): either key Defends.
		parry_hint = Keybinds.fill("{parry} / {defend}: Defend (%d AP)" % defend_cost)
		defend_hint = ""
	if _strike.def.is_mechanic():
		# No prompt: there's nothing to press.
		return _flash_message if _flash_time_left > 0.0 else ""
	var prompt := parry_hint + "     " + defend_hint
	if _flash_time_left > 0.0:
		prompt = _flash_message + "\n" + prompt
	return prompt


func _controls_hint() -> String:
	if _turn_intro_left > 0.0:
		return ""  # the camera is still panning to the fighter
	match _menu_mode:
		BattleMenu.Mode.COMMANDS:
			return Keybinds.fill("{up} / {down}: choose     {confirm} / Enter: select")
		BattleMenu.Mode.COMBO:
			if battle_menu.arts_focus:
				return Keybinds.fill("{up} / {down}: choose Art     {confirm} / Enter: add it     {swap} / {cancel}: back to moves")
			var arts_hint := Keybinds.fill("     {swap}: Arts list") if not Moves.arts(controlled.class_id).is_empty() else ""
			return Keybinds.fill("{up} / {down}: choose move     {confirm} / Enter: add     {cancel} / Backspace: remove last     {begin}: begin") + arts_hint
		BattleMenu.Mode.SKILLS:
			var what := "item" if not _skills.is_empty() and _skills[0].get("item", false) else "Ability"
			return Keybinds.fill("{up} / {down}: choose %s     {confirm} / Enter: use (one Ability or item per turn)     {cancel} / Backspace: back" % what)
		BattleMenu.Mode.TARGET:
			return ""
	var standing := _standing(party)
	var next_name := ""
	if standing.size() > 1 and controlled != null:
		next_name = standing[(standing.find(controlled) + 1) % standing.size()].display_name
	var tab_part := (Keybinds.fill("     {swap}: switch to ") + next_name + " (hold: choose)") if next_name != "" else ""
	return Keybinds.fill("{move}: move %s (free)%s     {cam_l} / {cam_r} or right-drag: camera     Esc: pause") % [controlled.display_name if controlled else "", tab_part]


## Shows a short message under the turn label for a moment.
func _flash(message: String, seconds: float = 2.5) -> void:
	_flash_message = message
	_flash_time_left = seconds


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
