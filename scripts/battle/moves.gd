class_name Moves
## Each class's attacks (built into combos in the combo bar, Legend of
## Legaia-style) and skills (the Abilities menu: one skill, then the turn ends).
##
## All numbers live here, one line per move, so they're easy to tune.
##
## Attack fields:
##   cost      AP: how much of the combo bar it fills (paid from party AP)
##   hits      one multiplier of attack_power per hit
##   kind      its place in the skill triangle (Attack = "basic", Smash)
##   effect    vs an enemy Defense stance: NONE blocked, PIERCE ignores it,
##             BREAK breaks it
##   duration  animation length in seconds (how fast the playhead crosses it)
##   window    size of each timing box, in seconds
##   times     (optional) where each hit lands, as a fraction of the block;
##             without it, hits are spread evenly with the last at the end
##   area      who each hit reaches (see Area); area_size in meters
##   reach     (optional) its own reach in meters; UNLIMITED = anywhere
##   falloff   LINE only: damage share on enemies behind the first one
##   knockback meters each enemy hit is pushed away
##   stun      cancels the target's turn if it's preparing an attack
##   escalating Bash: each new Bash in the chain has one more hit
##   escalate_falloff  escalating only: each hit is this much weaker per
##             earlier Bash in the chain (0.75: 0.8, then 0.6, 0.45...)
##   barrier   share of max HP given as a barrier to allies near the user
##             (barrier_radius meters), once per move
##   Assassin fields (all optional):
##   behind_mult   damage multiplier when the attacker is behind the target
##   front_miss    always misses when not behind the target (Backstab)
##   front_mult    multiplier when the move starts in front of the target
##   teleport_behind  appears behind the target before the hit (Shadowstep)
##   marked_any_range reaches any enemy carrying a Mark, however far
##   marks_from_behind  Marks put on the target by a hit from behind
##   stab_marks    every 3rd of these hits on a Marked enemy adds a Mark
##   mark_discount / min_cost  AP off per Mark on the target, and the floor
##   consume_marks removes all of the target's Marks when it hits
##   random_timing the hit lands at a random point of its block (the first
##                 move of a combo: always in the middle or late part)
##   timing    how the move's (last) hit is timed (see TimingType):
##             PRESS  press inside the box (the default)
##             HOLD   press in the first box (at hold_start, a fraction of the
##                    block), keep holding, let go in the box at the hit.
##                    A bad release only loses the Perfect.
##             TAP    tap the key `taps` times between tap_start and the hit;
##                    each tap adds part of the bonus, all of them = Perfect.
##                    Taps can't be wrong: no miss, no AP lost.
##
## Skill fields: cost, target (see Target), range (meters, for ENEMY / POINT),
## turns (how many of the caster's turns it lasts), and the effect's numbers.

enum Effect { NONE, PIERCE, BREAK }
enum TimingType { PRESS, HOLD, TAP }
enum Area { SINGLE, TARGET_CIRCLE, LINE, SELF_CIRCLE, ALL }
enum Target { SELF, ALLY, OTHER_ALLY, ENEMY, POINT, NONE }

const UNLIMITED := 1000.0

const BLUE := Color(0.45, 0.65, 0.95)
const TEAL := Color(0.3, 0.8, 0.75)
const PURPLE := Color(0.7, 0.5, 0.95)
const ORANGE := Color(1.0, 0.6, 0.2)
const GREEN := Color(0.45, 0.85, 0.45)
const GOLD := Color(1.0, 0.85, 0.4)
const RED := Color(0.95, 0.4, 0.3)
const VIOLET := Color(0.62, 0.35, 0.95)


static func attacks(class_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match class_id:
		"knight":
			list = [
				_attack("Slash", 10, [1.0], 0.55, 0.16, BLUE, "Basic attack"),
				_attack("Thrust", 20, [1.2], 0.7, 0.14, TEAL, "Ignores Defense", {"effect": Effect.PIERCE}),
				_attack("Double Slash", 15, [0.7, 0.7], 0.9, 0.16, PURPLE, "Two hits (basic)"),
				_attack("Smash", 30, [2.2], 1.2, 0.18, ORANGE, "Breaks Defense",
						{"kind": Skills.Kind.SMASH, "effect": Effect.BREAK}),
			]
		"archer":
			list = [
				_attack("Shoot", 10, [1.0], 0.55, 0.16, BLUE, "Basic attack"),
				_attack("Triple Shot", 25, [0.6, 0.6, 0.7], 1.4, 0.14, PURPLE, "3 hits, the last one delayed",
						{"times": [0.2, 0.4, 1.0]}),
				# Hold moves: a slower playhead, and the arrow flies at 85% of the
				# block, so there's a breath after letting go before the next move.
				_attack("Stunning Arrow", 40, [1.0], 1.5, 0.18, GOLD, "Cancels a turn about to strike",
						{"stun": true, "timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
				_attack("Gale Shot", 45, [1.6], 1.8, 0.2, TEAL, "Pushes back, breaks Defense",
						{"effect": Effect.BREAK, "knockback": 4.0, "timing": TimingType.HOLD, "hold_start": 0.3, "times": [0.85]}),
			]
		"mage":
			list = [
				_attack("Energy Blast", 15, [1.0], 0.9, 0.16, BLUE, "Small circle, hits several",
						{"area": Area.TARGET_CIRCLE, "area_size": 1.8, "timing": TimingType.TAP, "taps": 3}),
				_attack("Firebolt", 30, [1.6], 1.3, 0.16, RED, "Line: 100% first, 75% behind",
						{"area": Area.LINE, "area_size": 1.2, "falloff": 0.75, "timing": TimingType.TAP, "taps": 5}),
				_attack("Tempest", 45, [1.2], 1.1, 0.16, TEAL, "Circle on self, pushes far",
						{"area": Area.SELF_CIRCLE, "area_size": 3.5, "reach": 3.5, "knockback": 6.0}),
				_attack("Meteor Strike", 90, [1.8], 1.8, 0.2, ORANGE, "Hits all enemies, breaks Defense",
						{"area": Area.ALL, "reach": UNLIMITED, "effect": Effect.BREAK, "kind": Skills.Kind.SMASH,
						"timing": TimingType.TAP, "taps": 8}),
			]
		"cleric":
			list = [
				_attack("Bash", 10, [0.8], 0.5, 0.15, BLUE, "+1 hit per Bash in the chain, each weaker", {"escalating": true, "escalate_falloff": 0.75}),
				_attack("Divine Barrier", 25, [1.0], 0.9, 0.16, GOLD, "Barrier (10% HP) to allies near you",
						{"barrier": 0.10, "barrier_radius": 4.0}),
				_attack("Holy Light", 30, [1.4], 1.0, 0.16, Color(1.0, 0.95, 0.7), "Long range, breaks Defense",
						{"effect": Effect.BREAK, "reach": 9.0}),
			]
		"assassin":
			# Slower playheads than the Knight's: the timings are random, so the
			# eye needs a moment to find each box.
			list = [
				_attack("Stab", 10, [1.0], 0.8, 0.18, BLUE, "1.5x from behind; 3 Stabs grow a Mark",
						{"behind_mult": 1.5, "stab_marks": true, "random_timing": true}),
				_attack("Shadowstep", 20, [1.0], 1.1, 0.18, VIOLET, "Teleport behind; 1.5x if from the front",
						{"teleport_behind": true, "front_mult": 1.5, "marked_any_range": true, "random_timing": true}),
				_attack("Backstab", 35, [1.0], 1.2, 0.18, RED, "2x + a Mark from behind; misses in front",
						{"behind_mult": 2.0, "front_miss": true, "marks_from_behind": 1, "random_timing": true}),
				_attack("Execute", 100, [1.0], 1.6, 0.2, GOLD, "4x from behind; -15 AP per Mark on it",
						{"behind_mult": 4.0, "mark_discount": 15, "min_cost": 25, "consume_marks": true, "random_timing": true}),
			]
		_:
			list = [_attack("Attack", 10, [1.0], 0.55, 0.16, BLUE, "Basic attack")]
	return list


static func skills(class_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match class_id:
		"knight":
			list = [
				_skill("Light Heal", 25, Target.SELF, GREEN, "Heal 20% of max HP", {"heal": 0.2}),
				_skill("Brace", 20, Target.SELF, TEAL, "Take 50% less damage, 3 turns", {"turns": 3}),
				_skill("Shield Bash", 30, Target.ENEMY, ORANGE, "Rush to an enemy; next turn 33% sooner", {"range": 9.0}),
				_skill("Taunt", 60, Target.NONE, RED, "Enemies nearby target you, 3 turns", {"radius": 6.0, "turns": 3}),
			]
		"archer":
			list = [
				_skill("Jump", 30, Target.POINT, TEAL, "Leap to a spot you choose", {"range": 8.0}),
				_skill("Riposte", 40, Target.SELF, GOLD, "Counter stance for 4 s", {"seconds": 4.0}),
				_skill("True Sight", 50, Target.NONE, BLUE, "Allies' reach +25%, 3 turns", {"turns": 3}),
				_skill("Agility", 70, Target.SELF, PURPLE, "+1 hit on every attack, 5 turns", {"turns": 5}),
			]
		"mage":
			list = [
				_skill("Arcane Barrier", 20, Target.SELF, BLUE, "Ignore the next hit; next attack costs 2x"),
				_skill("Concentrate", 40, Target.NONE, GOLD, "AP recharge +100% for 10 s", {"seconds": 10.0}),
				_skill("Teleport", 60, Target.OTHER_ALLY, PURPLE, "Appear next to an ally"),
			]
		"cleric":
			list = [
				_skill("Healing", 25, Target.ALLY, GREEN, "Heal 25% of the target's max HP", {"heal": 0.25}),
				_skill("Shielding", 40, Target.NONE, BLUE, "Shield of 30% max HP on all allies", {"shield": 0.3}),
				_skill("Haste", 50, Target.ALLY, TEAL, "Run speed +20%, 3 turns", {"turns": 3}),
				_skill("Full Cure", 60, Target.ALLY, GOLD, "Fully heal an ally", {"heal": 1.0}),
			]
		"assassin":
			list = [
				_skill("Hook", 20, Target.ENEMY, ORANGE, "Stop its move, pull it in; uses its Marks",
						{"range": 6.0, "pull": 2.0}),
				_skill("Death Sentence", 40, Target.ENEMY, VIOLET, "Put 3 Marks on an enemy", {"range": 6.0, "marks": 3}),
				_skill("Shadow Cloak", 50, Target.ENEMY, BLUE, "Its Marks become a shield (10% max HP each)",
						{"range": UNLIMITED, "needs_marks": true, "shield": 0.10}),
				_skill("Vanish", 25, Target.SELF, PURPLE, "Enemies lose track of you until you attack", {"turns": 2}),
			]
	return list


static func _attack(move_name: String, cost: int, hits: Array, duration: float, window: float,
		color: Color, desc: String, extra: Dictionary = {}) -> Dictionary:
	var move := {
		"name": move_name, "cost": cost, "hits": hits, "duration": duration, "window": window,
		"color": color, "desc": desc, "kind": Skills.Kind.ATTACK, "effect": Effect.NONE,
		"area": Area.SINGLE, "area_size": 0.0, "reach": -1.0, "falloff": 1.0, "knockback": 0.0,
		"stun": false, "escalating": false, "barrier": 0.0, "barrier_radius": 0.0,
		"timing": TimingType.PRESS, "hold_start": 0.35, "taps": 0, "tap_start": 0.12,
	}
	move.merge(extra, true)
	return move


static func _skill(skill_name: String, cost: int, target: int, color: Color, desc: String,
		extra: Dictionary = {}) -> Dictionary:
	var skill := {"name": skill_name, "cost": cost, "target": target, "color": color, "desc": desc,
			"range": 0.0, "turns": 0}
	skill.merge(extra, true)
	return skill
