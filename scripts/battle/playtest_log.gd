class_name PlaytestLog
extends RefCounted
## Records what happens in one fight and saves a short report when it ends,
## for balancing: how long it took, which enemy skills did the damage, how
## often the party parried, defended, dodged and went down.
##
## Reports go to the "playtests" folder in the game's user data folder
## (on Windows: %APPDATA%\Godot\app_userdata\Prototype JRPG\playtests, both
## from the editor and from an exported build). Press O on the end-of-fight
## screen to open it. Each fight gets its own .md file, and playtests.csv
## gets one line per fight.

const FOLDER := "user://playtests"

## How many times each round has been started since the game was opened.
static var attempts := {}

var round_title := ""
## How the fight was started: "Boss Rush", "Boss Rush (continued from a
## save)" or "Round Select".
var mode := ""
var attempt := 1
var party_names: PackedStringArray = []
var enemy_names: PackedStringArray = []
var start_msec := 0
var saved := false

## Turns taken, per fighter name.
var turns := {}
## Per enemy skill ("Ogre Warrior: Shout"): casts, misses, hits, damage,
## parried, defended.
var skills := {}
## Per party member: {"taken": total HP lost, "sources": {source: HP}, "downs": n}.
var party := {}
## Per party member: damage dealt to enemies.
var dealt := {}


func _init(title: String, members: Array[Combatant], foes: Array[Combatant]) -> void:
	round_title = title
	attempt = int(attempts.get(title, 0)) + 1
	attempts[title] = attempt
	start_msec = Time.get_ticks_msec()
	for member in members:
		party_names.append(member.display_name)
		party[member.display_name] = {"taken": 0, "sources": {}, "downs": 0}
		dealt[member.display_name] = 0
	for foe in foes:
		enemy_names.append(foe.display_name)


func add_member(member: Combatant) -> void:
	if not party.has(member.display_name):
		party_names.append(member.display_name)
		party[member.display_name] = {"taken": 0, "sources": {}, "downs": 0}
		dealt[member.display_name] = 0


func turn(fighter: Combatant) -> void:
	turns[fighter.display_name] = int(turns.get(fighter.display_name, 0)) + 1


func _skill(enemy: Combatant, skill_name: String) -> Dictionary:
	var key := "%s: %s" % [enemy.display_name, skill_name]
	if not skills.has(key):
		skills[key] = {"casts": 0, "misses": 0, "hits": 0, "damage": 0, "parried": 0, "defended": 0, "avoidable": 0}
	return skills[key]


func cast(enemy: Combatant, skill_name: String) -> void:
	_skill(enemy, skill_name)["casts"] += 1


func miss(enemy: Combatant, skill_name: String) -> void:
	_skill(enemy, skill_name)["misses"] += 1


## A strike of this skill landed on someone who could have avoided it.
func avoidable(enemy: Combatant, skill_name: String) -> void:
	_skill(enemy, skill_name)["avoidable"] += 1


func parried(enemy: Combatant, skill_name: String) -> void:
	_skill(enemy, skill_name)["parried"] += 1


func defended(enemy: Combatant, skill_name: String) -> void:
	_skill(enemy, skill_name)["defended"] += 1


## A party member lost HP. source is "Enemy: Skill", "Rock spike", etc.;
## enemy is set when an enemy skill did it.
func hurt(member: Combatant, amount: int, source: String, enemy: Combatant = null, skill_name: String = "") -> void:
	add_member(member)
	var entry: Dictionary = party[member.display_name]
	entry["taken"] = int(entry["taken"]) + amount
	entry["sources"][source] = int(entry["sources"].get(source, 0)) + amount
	if enemy != null:
		var s := _skill(enemy, skill_name)
		s["hits"] += 1
		s["damage"] += amount


func down(member: Combatant) -> void:
	add_member(member)
	party[member.display_name]["downs"] += 1


func deal(attacker: Combatant, amount: int) -> void:
	if attacker == null or attacker.team != Combatant.Team.PARTY:
		return
	add_member(attacker)
	dealt[attacker.display_name] = int(dealt[attacker.display_name]) + amount


## Writes the report. result: "Victory", "Defeat" or "Left early".
## Returns the report's full path ("" if it couldn't be written).
func save(result: String, stats: Dictionary, members: Array[Combatant], foes: Array[Combatant]) -> String:
	if saved:
		return ""
	saved = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var seconds := (Time.get_ticks_msec() - start_msec) / 1000.0
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var total_turns := 0
	for count in turns.values():
		total_turns += int(count)

	var lines: PackedStringArray = []
	lines.append("# %s (attempt %d): %s" % [round_title, attempt, result])
	lines.append("")
	lines.append("- When: %s" % Time.get_datetime_string_from_system().replace("T", " "))
	if mode != "":
		lines.append("- Mode: %s" % mode)
	lines.append("- Length: %d:%02d, %d turns" % [int(seconds) / 60, int(seconds) % 60, total_turns])
	lines.append("- Party: %s" % ", ".join(party_names))
	lines.append("- Enemies: %s" % ", ".join(enemy_names))
	lines.append("")
	lines.append("## Party")
	lines.append("")
	lines.append("| Member | HP left | Turns | Damage dealt | Damage taken | Went down |")
	lines.append("|---|---|---|---|---|---|")
	for member in members:
		var entry: Dictionary = party.get(member.display_name, {"taken": 0, "downs": 0})
		lines.append("| %s | %d / %d | %d | %d | %d | %d |" % [member.display_name, member.hp, member.max_hp,
				int(turns.get(member.display_name, 0)), int(dealt.get(member.display_name, 0)),
				int(entry["taken"]), int(entry["downs"])])
	lines.append("")
	lines.append("## Enemies")
	lines.append("")
	lines.append("| Enemy | HP left | Turns |")
	lines.append("|---|---|---|")
	for foe in foes:
		lines.append("| %s | %d / %d | %d |" % [foe.display_name, maxi(foe.hp, 0), foe.max_hp, int(turns.get(foe.display_name, 0))])
	lines.append("")
	lines.append("## Enemy skills")
	lines.append("")
	lines.append("| Skill | Used | Missed | People hit | Damage | Parried | Defended | Avoidable hits |")
	lines.append("|---|---|---|---|---|---|---|---|")
	var keys := skills.keys()
	keys.sort_custom(func(a, b): return int(skills[a]["damage"]) > int(skills[b]["damage"]))
	for key in keys:
		var s: Dictionary = skills[key]
		lines.append("| %s | %d | %d | %d | %d | %d | %d | %d |" % [key, s["casts"], s["misses"], s["hits"], s["damage"], s["parried"], s["defended"], s["avoidable"]])
	lines.append("")
	# Damage the party took, by source (left out when nothing got through).
	var taken_lines: PackedStringArray = []
	for member in members:
		var entry: Dictionary = party.get(member.display_name, {"sources": {}})
		var sources: Dictionary = entry.get("sources", {})
		if sources.is_empty():
			continue
		var parts: PackedStringArray = []
		var names := sources.keys()
		names.sort_custom(func(a, b): return int(sources[a]) > int(sources[b]))
		for source in names:
			if int(sources[source]) > 0:  # fully absorbed hits (shields, barriers) are left out
				parts.append("%s %d" % [source, sources[source]])
		if parts.is_empty():
			continue
		taken_lines.append("- **%s:** %s" % [member.display_name, ", ".join(parts)])
	if not taken_lines.is_empty():
		lines.append("## Damage taken, by source")
		lines.append("")
		lines.append_array(taken_lines)
		lines.append("")
	lines.append("## Counts")
	lines.append("")
	var stat_keys := stats.keys()
	stat_keys.sort()
	var stat_parts: PackedStringArray = []
	for key in stat_keys:
		stat_parts.append("%s %d" % [String(key).replace("_", " "), stats[key]])
	lines.append(", ".join(stat_parts) if not stat_parts.is_empty() else "(none)")
	lines.append("")

	var file_name := "%s_%s_%s.md" % [stamp, round_title.replace(" ", "-"), result.replace(" ", "-").to_lower()]
	var path := FOLDER + "/" + file_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't write the play-test report to %s" % path)
		return ""
	file.store_string("\n".join(lines))
	file.close()
	_append_csv(stamp, result, seconds, total_turns, stats, members, foes)
	return ProjectSettings.globalize_path(path)


## One line per fight in playtests.csv, easy to open in a spreadsheet.
func _append_csv(stamp: String, result: String, seconds: float, total_turns: int, stats: Dictionary,
		members: Array[Combatant], foes: Array[Combatant]) -> void:
	var path := FOLDER + "/playtests.csv"
	var is_new := not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	if is_new:
		file.store_line("date,round,attempt,result,seconds,turns,party_hp_left,party_max_hp,enemy_hp_left,enemy_max_hp,downs,parries,defends,misses,perfects,interrupts")
	var party_hp := 0
	var party_max := 0
	var downs := 0
	for member in members:
		party_hp += maxi(member.hp, 0)
		party_max += member.max_hp
		downs += int(party.get(member.display_name, {"downs": 0})["downs"])
	var enemy_hp := 0
	var enemy_max := 0
	for foe in foes:
		enemy_hp += maxi(foe.hp, 0)
		enemy_max += foe.max_hp
	file.store_line("%s,%s,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [stamp, round_title, attempt, result, roundi(seconds),
			total_turns, party_hp, party_max, enemy_hp, enemy_max, downs, int(stats.get("parries", 0)),
			int(stats.get("defends", 0)), int(stats.get("misses", 0)), int(stats.get("perfects", 0)),
			int(stats.get("interrupts", 0))])
	file.close()
