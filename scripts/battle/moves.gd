class_name Moves
## Each class's attacks (built into combos in the combo bar, Legend of
## Legaia-style) and skills (the Abilities menu: one skill per turn, and you
## can still Attack or Wait after it).
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
##   pin       the enemy hit can't walk until its next turn (Pinning Shot)
##   heal_allies  share of max HP healed on allies within heal_radius of the
##             user, once per move (perfect_heal replaces it on a Perfect)
##   chill     the enemy hit walks at half speed until its next turn (Frost)
##   last_hit  (optional) fields that change on the last hit only, e.g.
##             {"effect": PIERCE} (Triple Shot) or {"add_marks": 2}
##   add_marks Assassin's Marks this hit puts on the target
##   stun      cancels the target's turn if it's preparing an attack
##   escalating Bash: each Bash in a row has one more hit and costs one
##             more step of its AP (10, 20, 30)
##   escalate_falloff  escalating only: each hit is this much weaker per
##             earlier Bash in the chain (0.75: 0.8, then 0.6, 0.45...)
##   barrier   share of max HP given as a barrier to allies near the user
##             (barrier_radius meters), once per move; perfect_barrier and
##             perfect_barrier_radius replace them on a Perfect (given on
##             the move's last hit)
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
				# Basic moves: in the right order they become Arts (see arts()).
				_attack("Slash", 10, [1.0], 0.55, 0.16, BLUE, "Basic attack"),
				_attack("Thrust", 15, [1.1], 0.7, 0.14, TEAL, "Ignores Defense", {"effect": Effect.PIERCE}),
				_attack("Guard Strike", 15, [0.9], 0.6, 0.16, GREEN, "Shield blow: delays the enemy's turn",
						{"delay": 8.0}),
			]
		"archer":
			list = [
				# Basic moves: in the right order they become Arts (see arts()).
				_attack("Shoot", 10, [1.0], 0.55, 0.16, BLUE, "Basic attack"),
				# Hold move: a slower playhead, and the arrow flies at 85% of the
				# block, so there's a breath after letting go before the next move.
				_attack("Power Draw", 20, [1.4], 1.2, 0.18, GOLD, "Strong shot (Hold)",
						{"timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
				_attack("Pinning Shot", 15, [0.9], 0.6, 0.16, GREEN, "Can't walk until its next turn",
						{"pin": true}),
			]
		"mage":
			list = [
				# Basic moves (three elements): in the right order they become
				# Arts (see arts()).
				# Reach 4.5 m (the Mage's own is 3): enough to cast from a safe
				# spot, still well short of the Archer's 6.
				_attack("Fire", 20, [1.1], 1.1, 0.16, RED, "Line: 100% first, 75% behind; reach 4.5 m",
						{"reach": 4.5, "area": Area.LINE, "area_size": 1.2, "falloff": 0.75, "timing": TimingType.TAP, "taps": 4}),
				_attack("Frost", 20, [0.9], 1.0, 0.16, BLUE, "Small circle; chills (half walking speed)",
						{"area": Area.TARGET_CIRCLE, "area_size": 1.8, "chill": true, "timing": TimingType.TAP, "taps": 3}),
				_attack("Gust", 15, [0.8], 0.6, 0.16, TEAL, "Circle on self, pushes 3 m",
						{"area": Area.SELF_CIRCLE, "area_size": 3.0, "reach": 3.0, "knockback": 3.0}),
			]
		"cleric":
			list = [
				# Basic moves: in the right order they become Arts (see arts()).
				# No Art is Bash + Bash, so Bash chains keep growing: each Bash in a
				# row adds a hit and costs 10 AP more (10, 20, 30).
				_attack("Bash", 10, [0.8], 0.5, 0.15, BLUE, "Each Bash in a row: +1 hit, +10 AP", {"escalating": true, "escalate_falloff": 0.9}),
				_attack("Holy Light", 20, [1.2], 1.0, 0.16, Color(1.0, 0.95, 0.7), "Long range, breaks Defense",
						{"effect": Effect.BREAK, "reach": 9.0}),
				_attack("Divine Barrier", 20, [1.0], 1.5, 0.18, GOLD, "Barrier to allies near you; Perfect: bigger",
						{"barrier": 0.10, "barrier_radius": 4.0, "perfect_barrier": 0.15, "perfect_barrier_radius": 5.5,
						"timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
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


## Arts: named attacks made from basic moves in a set order (Legend of
## Legaia style). When the moves on the combo bar spell a recipe, those
## blocks merge into the Art. An Art costs what its moves cost, but hits
## harder (+25-50%), and longer ones add effects. The bar reads left to
## right and always takes the longest recipe it can.
## Extra fields: recipe (move names in order), and "delay" (pushes the
## enemy back on the timeline, like Guard Strike).
static func arts(class_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match class_id:
		"knight":
			list = [
				_art(["Slash", "Slash"], "Double Slash", [1.25, 1.25], 0.9, 0.16, PURPLE, "Two strong hits"),
				_art(["Slash", "Thrust"], "Lunge", [2.6], 0.8, 0.15, TEAL, "Piercing lunge: ignores Defense",
						{"effect": Effect.PIERCE}),
				_art(["Guard Strike", "Slash"], "Shield Rush", [1.2, 1.2], 0.9, 0.16, GREEN, "Two hits; pushes its turn far back",
						{"delay": 18.0}),
				_art(["Thrust", "Thrust", "Slash"], "Smash", [4.2], 1.2, 0.18, ORANGE, "Heavy blow: Smash type, breaks Defense",
						{"kind": Skills.Kind.SMASH, "effect": Effect.BREAK}),
				_art(["Slash", "Slash", "Thrust", "Guard Strike"], "Crusader's Edge", [1.4, 1.4, 3.2], 1.8, 0.18, GOLD,
						"Finisher: breaks Defense, cancels its turn, knocks it back",
						{"effect": Effect.BREAK, "stun": true, "knockback": 3.0, "times": [0.3, 0.55, 1.0], "finisher": true}),
			]
		"archer":
			list = [
				_art(["Shoot", "Shoot"], "Double Shot", [1.25, 1.25], 0.9, 0.16, PURPLE, "Two strong arrows"),
				_art(["Shoot", "Shoot", "Shoot"], "Triple Shot", [1.1, 1.1, 1.8], 1.4, 0.15, PURPLE, "3 arrows; the delayed last one ignores Defense",
						{"times": [0.2, 0.4, 1.0], "last_hit": {"effect": Effect.PIERCE}}),
				_art(["Shoot", "Power Draw"], "Piercing Arrow", [3.0], 1.5, 0.18, TEAL, "Hold: flies through every enemy in a line",
						{"area": Area.LINE, "area_size": 1.2, "falloff": 1.0, "effect": Effect.PIERCE,
						"timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
				_art(["Pinning Shot", "Power Draw"], "Stunning Arrow", [2.6], 1.5, 0.18, GOLD, "Hold: cancels a turn about to strike",
						{"stun": true, "timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
				_art(["Power Draw", "Power Draw"], "Gale Shot", [3.4], 1.8, 0.2, TEAL, "Hold: breaks Defense, pushes back 4 m",
						{"effect": Effect.BREAK, "knockback": 4.0, "timing": TimingType.HOLD, "hold_start": 0.3, "times": [0.85]}),
				_art(["Pinning Shot", "Shoot", "Shoot", "Power Draw"], "Arrow Rain", [1.4, 1.4, 2.2], 1.8, 0.18, ORANGE,
						"Finisher: 3 volleys on a circle; breaks Defense, pins all it hits",
						{"area": Area.TARGET_CIRCLE, "area_size": 2.5, "effect": Effect.BREAK, "pin": true,
						"times": [0.3, 0.55, 1.0], "finisher": true}),
			]
		"mage":
			list = [
				_art(["Fire", "Fire"], "Fireball", [3.0], 1.5, 0.18, ORANGE, "Tap: big blast on a circle at the target",
						{"reach": 4.5, "area": Area.TARGET_CIRCLE, "area_size": 2.2, "timing": TimingType.TAP, "taps": 6}),
				_art(["Frost", "Frost"], "Blizzard", [2.4], 1.5, 0.18, BLUE, "Tap: wide circle, chills everyone hit",
						{"area": Area.TARGET_CIRCLE, "area_size": 3.0, "chill": true, "timing": TimingType.TAP, "taps": 6}),
				_art(["Fire", "Frost"], "Steam Burst", [2.8], 1.3, 0.18, Color(0.85, 0.85, 0.95), "Tap: small circle, breaks Defense",
						{"area": Area.TARGET_CIRCLE, "area_size": 1.8, "effect": Effect.BREAK, "timing": TimingType.TAP, "taps": 5}),
				_art(["Gust", "Fire"], "Firestorm", [2.6], 0.9, 0.16, RED, "Fire whirl around you, pushes 4 m",
						{"area": Area.SELF_CIRCLE, "area_size": 3.5, "reach": 3.5, "knockback": 4.0}),
				_art(["Gust", "Gust"], "Tempest", [2.0], 0.9, 0.16, TEAL, "Wide circle around you, pushes 7 m",
						{"area": Area.SELF_CIRCLE, "area_size": 4.5, "reach": 4.5, "knockback": 7.0}),
				_art(["Fire", "Frost", "Fire", "Gust"], "Meteor Strike", [4.8], 1.9, 0.2, ORANGE,
						"Finisher: hits every enemy, breaks Defense, Smash type",
						{"area": Area.ALL, "reach": UNLIMITED, "effect": Effect.BREAK, "kind": Skills.Kind.SMASH,
						"timing": TimingType.TAP, "taps": 8, "finisher": true}),
			]
		"assassin":
			# Execute is never part of a recipe: its Mark discount stays its own.
			# Multi-hit Arts keep random timings, one hit per stretch of the block.
			list = [
				_art(["Stab", "Stab"], "Twin Fangs", [1.25, 1.25], 1.4, 0.18, BLUE, "2 hits, 1.5x each from behind; both count as Stabs",
						{"behind_mult": 1.5, "stab_marks": true, "random_timing": true}),
				_art(["Shadowstep", "Stab"], "Ambush", [2.4], 1.2, 0.18, VIOLET, "Teleport behind, strike 1.5x, +1 Mark",
						{"teleport_behind": true, "behind_mult": 1.5, "marked_any_range": true, "random_timing": true,
						"last_hit": {"add_marks": 1}}),
				_art(["Shadowstep", "Shadowstep"], "Phantom Rush", [1.8, 1.8], 1.6, 0.18, PURPLE, "Teleport behind, 2 hits, +1 Mark",
						{"teleport_behind": true, "marked_any_range": true, "random_timing": true, "last_hit": {"add_marks": 1}}),
				_art(["Stab", "Backstab"], "Cutthroat", [1.3, 1.3], 1.6, 0.18, RED, "2 hits, 2x + a Mark each from behind; misses in front",
						{"behind_mult": 2.0, "front_miss": true, "marks_from_behind": 1, "random_timing": true}),
				_art(["Stab", "Shadowstep", "Stab"], "Thousand Cuts", [0.8, 0.8, 0.8, 0.8, 0.8, 0.8], 2.6, 0.16, GOLD,
						"Finisher: teleport behind, 6 cuts at 1.5x, +2 Marks",
						{"teleport_behind": true, "behind_mult": 1.5, "marked_any_range": true, "random_timing": true,
						"last_hit": {"add_marks": 2}, "finisher": true}),
			]
		"cleric":
			list = [
				_art(["Bash", "Holy Light"], "Smite", [2.4], 0.9, 0.16, Color(1.0, 0.95, 0.7), "Holy blow up close, breaks Defense",
						{"effect": Effect.BREAK}),
				_art(["Holy Light", "Holy Light"], "Judgment", [3.2], 1.3, 0.18, GOLD, "Long range circle, breaks Defense",
						{"effect": Effect.BREAK, "reach": 9.0, "area": Area.TARGET_CIRCLE, "area_size": 2.0}),
				_art(["Bash", "Divine Barrier"], "Blessed Strike", [2.2], 1.5, 0.18, GREEN, "Hold: heals allies near you 8% (Perfect 12%)",
						{"heal_allies": 0.08, "heal_radius": 4.0, "perfect_heal": 0.12,
						"timing": TimingType.HOLD, "hold_start": 0.35, "times": [0.85]}),
				_art(["Divine Barrier", "Divine Barrier"], "Sanctuary", [1.5], 1.7, 0.2, Color(0.55, 0.8, 1.0), "Hold: big barrier 15% in 5 m (Perfect 22% in 6.5 m)",
						{"barrier": 0.15, "barrier_radius": 5.0, "perfect_barrier": 0.22, "perfect_barrier_radius": 6.5,
						"timing": TimingType.HOLD, "hold_start": 0.3, "times": [0.85]}),
				_art(["Bash", "Holy Light", "Bash", "Divine Barrier"], "Divine Judgment", [1.2, 1.2, 2.6], 1.8, 0.18, GOLD,
						"Finisher: breaks Defense; whole party healed 15% + 10% barrier",
						{"effect": Effect.BREAK, "heal_allies": 0.15, "heal_radius": UNLIMITED,
						"barrier": 0.10, "barrier_radius": UNLIMITED, "times": [0.3, 0.55, 1.0], "finisher": true}),
			]
	return list


static func _art(recipe: Array, art_name: String, hits: Array, duration: float, window: float,
		color: Color, desc: String, extra: Dictionary = {}) -> Dictionary:
	var art := _attack(art_name, 0, hits, duration, window, color, desc, extra)
	art["recipe"] = recipe
	return art


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
