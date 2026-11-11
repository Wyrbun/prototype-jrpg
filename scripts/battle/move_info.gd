class_name MoveInfo
## Plain-language details for an attack, Art or Ability: the lines in the
## details box beside the move list (and under an Art's name on Tab).
## Attacks and Arts are described from their fields in moves.gd, so a new
## field only needs a line here to be explained everywhere. Abilities get a
## written explanation each (SKILL_TEXT), since what they do lives in code.

const SKILL_TEXT := {
	"Light Heal": ["Heals you for 20% of your max HP."],
	"Brace": ["You take half damage from every hit.", "Lasts 2 of your turns."],
	"Shield Bash": ["Rush next to an enemy up to 9 m away (it must be in sight).",
			"Your next turn starts a third of the way along the timeline, like Wait."],
	"Taunt": ["Every enemy within 6 m targets you for 3 of your turns.",
			"Meanwhile you guard: allies within 3 m are covered by your Block and Parry, even if their class can't do them."],
	"Jump": ["Move the marker (up to 8 m) and leap there.", "Walls and rocks stop the marker."],
	"Riposte": ["Counter stance for 4 s: the next strike on you that can be parried is countered for 2x your attack.",
			"The enemy is pushed 3 m away and you hop 3 m back."],
	"True Sight": ["Every ally's attack reach grows 25%.",
			"Enemy attacks are revealed as soon as they start preparing.", "Lasts 3 of your turns."],
	"Agility": ["Every attack you play gets one extra hit at half the strength of its first hit.",
			"Lasts 5 of your turns."],
	"Arcane Barrier": ["The next hit on you does nothing."],
	"Concentrate": ["The party's AP recharges twice as fast for 10 s."],
	"Teleport": ["Blink to a spot up to 8 m away (move the marker), or press Tab to appear next to an ally at any distance."],
	"Healing": ["Heals an ally (or you) for 25% of their max HP."],
	"Shielding": ["Every ally gets a shield of 15% of their max HP, at any distance.",
			"Shields soak damage before HP and stack with barriers, up to half of max HP."],
	"Haste": ["An ally's turns come 25% sooner and they run 20% faster.", "Lasts 2 of their own turns."],
	"Full Cure": ["Fully heals an ally (or you)."],
	"Hook": ["An enemy up to 6 m away loses what it was preparing (or its stance) and is pulled 2 m towards you.",
			"Uses up its Marks."],
	"Death Sentence": ["Puts 3 Marks on an enemy up to 6 m away (5 at most)."],
	"Shadow Cloak": ["A Marked enemy's Marks become a shield on you: 10% of your max HP for each.",
			"Works at any distance."],
	"Vanish": ["Enemies stop targeting you (while anyone else is standing) until you attack, or for 2 of your turns."],
	"Provoke": ["One enemy up to 6 m away targets you until your next turn.",
			"Each Parry you make meanwhile gives a Rush token."],
	"Suplex": ["Counter stance for 4 s: the next strike on you that can be parried is countered for 2x your attack and the attacker is thrown 3 m.",
			"Gives a Mountain token."],
	"Deep Breath": ["Heals you for 20% of your max HP.", "Gives back the last bar step you lost."],
}


## The details for a move from the move list (attack or Art) or the
## Abilities list.
static func lines(move: Dictionary) -> PackedStringArray:
	if move.has("target"):
		return _skill_lines(move)
	return _attack_lines(move)


## "20 AP · Hold" style summary for the box's second line.
static func summary(move: Dictionary) -> String:
	var parts: PackedStringArray = ["%d AP" % int(move.get("shown_cost", move.get("cost", 0)))]
	if move.has("target"):
		return parts[0]
	match int(move.get("timing", Moves.TimingType.PRESS)):
		Moves.TimingType.HOLD:
			parts.append("Hold")
		Moves.TimingType.TAP:
			parts.append("Open Tap" if float(move.get("surge", 0.0)) > 0.0 else "Tap x%d" % int(move.get("taps", 0)))
		_:
			parts.append("Press")
	if move.get("finisher", false):
		parts.append("Finisher")
	return "  ·  ".join(parts)


static func _skill_lines(skill: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for line in SKILL_TEXT.get(skill["name"], [skill["desc"]]):
		out.append(line)
	return out


static func _attack_lines(move: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var hits: Array = move["hits"]
	# Damage
	var total := 0.0
	for h in hits:
		total += float(h)
	if hits.size() == 1:
		out.append("Damage: %sx your attack." % _num(total))
	else:
		out.append("Damage: %d hits, %sx your attack in all." % [hits.size(), _num(total)])
	# How to play it
	match int(move.get("timing", Moves.TimingType.PRESS)):
		Moves.TimingType.HOLD:
			out.append("Hold: press in the first box, keep holding, let go in the last box for a Perfect. A bad let-go only loses the Perfect.")
		Moves.TimingType.TAP:
			if float(move.get("surge", 0.0)) > 0.0:
				out.append("Open Tap: every tap adds %d%% damage, up to %d taps (a Perfect). Extra taps are fine." % [roundi(float(move["surge"]) * 100.0), int(move["taps"])])
			else:
				out.append("Tap exactly %d times before the hit for a Perfect. One tap too many is a miss." % int(move.get("taps", 0)))
		_:
			if String(move.get("timed", "")) != "":
				out.append("Only the %s hit is timed; the others land by themselves." % move["timed"])
	if move.get("random_timing", false):
		out.append("Random timing: the box can appear anywhere in the block.")
	# Where it lands
	var reach := float(move.get("reach", -1.0))
	match int(move.get("area", Moves.Area.SINGLE)):
		Moves.Area.LINE:
			var falloff := float(move.get("falloff", 1.0))
			if falloff < 1.0:
				out.append("Hits a line through the target: full damage to the first enemy, %d%% to those behind." % roundi(falloff * 100.0))
			else:
				out.append("Hits every enemy in a line through the target, at full damage.")
		Moves.Area.TARGET_CIRCLE:
			out.append("Hits everyone within %s m of the target." % _num(float(move["area_size"])))
		Moves.Area.SELF_CIRCLE:
			out.append("Hits every enemy within %s m of you." % _num(float(move["area_size"])))
		Moves.Area.ALL:
			out.append("Hits every enemy, at any distance.")
	if reach > 0.0 and reach < Moves.UNLIMITED and int(move.get("area", Moves.Area.SINGLE)) != Moves.Area.SELF_CIRCLE:
		out.append("Reach: %s m." % _num(reach))
	# Against Defense / Smash
	match int(move.get("effect", Moves.Effect.NONE)):
		Moves.Effect.PIERCE:
			out.append("Ignores Defense.")
		Moves.Effect.BREAK:
			out.append("Breaks Defense: a guarding enemy loses its stance.")
	var last: Dictionary = move.get("last_hit", {})
	if int(last.get("effect", Moves.Effect.NONE)) == Moves.Effect.PIERCE:
		out.append("The last hit ignores Defense.")
	if int(move.get("kind", Skills.Kind.ATTACK)) == Skills.Kind.SMASH:
		out.append("Smash type: it can't interrupt an enemy's Smash.")
	if BattleArena.heavy_move(move):
		out.append("Heavy: fills Stagger bars 1.5x faster.")
	# Control
	if move.get("stun", false):
		out.append("Stun: an enemy about to strike loses its attack. Once per enemy action.")
	if float(move.get("freeze", 0.0)) > 0.0:
		out.append("Halt: the enemy's timeline stops for %s s. Once per enemy action." % _num(float(move["freeze"])))
	if float(move.get("knockback", 0.0)) > 0.0:
		out.append("Pushes enemies %s m away (edges can make them fall)." % _num(float(move["knockback"])))
	if move.get("draws_aggro", false):
		out.append("Draws aggro: the enemy targets you for one of your turns (each more adds a turn, up to 3).")
	if move.get("pin", false):
		out.append("Pins: the enemy can't walk until its next turn.")
	if move.get("chill", false):
		out.append("Chills: the enemy walks at half speed until its next turn.")
	if float(move.get("burn", 0.0)) > 0.0:
		out.append("Burns: %d%% of your attack each time the enemy acts, for its next %d actions." % [roundi(float(move["burn"]) * 100.0), int(move.get("burn_turns", 2))])
	if float(move.get("expose", 0.0)) > 0.0:
		out.append("Exposes: the enemy takes +%d%% damage from everyone until its next turn." % roundi(float(move["expose"]) * 100.0))
	# Support
	if float(move.get("barrier", 0.0)) > 0.0:
		var radius := float(move.get("barrier_radius", 0.0))
		var where := "the whole party" if radius >= Moves.UNLIMITED else "allies within %s m" % _num(radius)
		var line := "Barrier: %d%% of max HP to %s." % [roundi(float(move["barrier"]) * 100.0), where]
		if move.has("perfect_barrier"):
			line += " Perfect: %d%% within %s m." % [roundi(float(move["perfect_barrier"]) * 100.0), _num(float(move.get("perfect_barrier_radius", radius)))]
		out.append(line)
	if float(move.get("heal_allies", 0.0)) > 0.0:
		var heal_radius := float(move.get("heal_radius", 0.0))
		var who := "the whole party" if heal_radius >= Moves.UNLIMITED else "allies within %s m" % _num(heal_radius)
		var heal_line := "Heals %s by %d%% of max HP." % [who, roundi(float(move["heal_allies"]) * 100.0)]
		if move.has("perfect_heal"):
			heal_line += " Perfect: %d%%." % roundi(float(move["perfect_heal"]) * 100.0)
		out.append(heal_line)
	if float(move.get("rally", 0.0)) > 0.0:
		out.append("Rally: the party's max AP grows +%d when it lands (+%d with a Perfect)." % [int(move["rally"]), int(move["rally"]) * 2])
	if float(move.get("flurry", 0.0)) > 0.0:
		out.append("Flurry: each one right after another hits %s harder (up to %sx)." % [_num(float(move["flurry"])), _num(float(move.get("flurry_max", 0.0)))])
	# Assassin
	if move.get("teleport_behind", false):
		out.append("Teleports behind the target first.")
	if float(move.get("front_mult", 1.0)) > 1.0:
		out.append("%sx if it starts in front of the enemy." % _num(float(move["front_mult"])))
	if float(move.get("behind_mult", 1.0)) > 1.0:
		out.append("%sx from behind." % _num(float(move["behind_mult"])))
	if move.get("front_miss", false):
		out.append("Misses from the front.")
	if move.get("marked_any_range", false):
		out.append("Reaches any Marked enemy, however far.")
	if move.get("stab_marks", false):
		out.append("Every 3rd Stab hit on a Marked enemy adds a Mark.")
	if int(move.get("marks_from_behind", 0)) > 0:
		out.append("+%d Mark per hit from behind." % int(move["marks_from_behind"]))
	var add_marks := int(last.get("add_marks", move.get("add_marks", 0)))
	if add_marks > 0:
		out.append("+%d Mark%s." % [add_marks, "" if add_marks == 1 else "s"])
	if int(move.get("mark_discount", 0)) > 0:
		out.append("Costs %d AP less per Mark on the target (at least %d)." % [int(move["mark_discount"]), int(move.get("min_cost", 0))])
	if float(move.get("mark_bonus", 0.0)) > 0.0:
		out.append("+%d%% damage per Mark it spends." % roundi(float(move["mark_bonus"]) * 100.0))
	if move.get("consume_marks", false):
		out.append("Uses up all the target's Marks.")
	# Monk
	if move.get("climb", false):
		out.append("Climbs your bar one step.")
	var consumes: Array = move.get("consumes", [])
	if not consumes.is_empty():
		out.append("Uses %s tokens (+10%% damage each)." % " and ".join(consumes))
	var grants: Dictionary = move.get("grants", {})
	if not grants.is_empty():
		out.append("All Perfect: grants %s." % " and ".join(grants.keys()))
	if String(move.get("needs_token", "")) != "":
		out.append("Needs %s." % move["needs_token"])
	var cashout: Array = move.get("cashout", [])
	for step in cashout:
		out.append("%sx damage at bar %d." % [_num(float(step[1])), int(step[0])])
	if move.get("bar_reset", false):
		out.append("Moves after it start a fresh bar.")
	if move.get("finisher", false):
		out.append("Finisher: the end of a long recipe.")
	return out


## 1.0 -> "1", 1.25 -> "1.25", 0.5 -> "0.5".
static func _num(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
