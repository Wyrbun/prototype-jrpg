class_name BattleSounds
## Which sound goes with what happens in a fight (Sfx plays them). Kept
## here so the arena only says "a hit landed" and the choices stay in one
## place, easy to change.

## Seconds before a melee hit lands that its swing starts.
const SWING_LEAD := 0.13
## Enemy skills that burn: they add a fire sound when they land.
const FIRE_WORDS := ["Fire", "Burning", "Scorch", "flare", "Flame", "Ember"]
## Enemy skills fired from a bow.
const BOW_WORDS := ["Ranged Attack", "Power Shot", "Shot"]


## Just before a party member's hit lands: the weapon's swing or draw.
## (Archers loose the arrow; Mages' spells sound on landing.)
static func swing(attacker: Combatant, move: Dictionary) -> void:
	match attacker.class_id:
		"knight":
			# A sword: a whoosh, sometimes the ring of the blade.
			if randf() < 0.35:
				Sfx.play("draw_blade", -3.0)
			else:
				Sfx.play("swing", -2.0)
		"assassin":
			if randf() < 0.6:
				Sfx.play("draw_blade", -3.0)
			else:
				Sfx.play("swing", -3.0, 1.12)
		"cleric", "monk":
			Sfx.play("swing", -2.0, 0.95 if _heavy(move) else 1.05)
		"archer":
			Sfx.play("bow", -1.0)
		"mage":
			if _elements(move).has("fire"):
				Sfx.play("cast_fire", -2.0)


## A party member's hit lands on an enemy.
static func impact(attacker: Combatant, move: Dictionary, perfect: bool) -> void:
	var boost := 2.0 if perfect else 0.0
	match attacker.class_id:
		"knight":
			if _heavy(move):
				Sfx.play("hit_heavy", boost)
			elif float(move.get("draws_aggro", 0.0)) > 0.0:
				Sfx.play("hit_blunt", boost)  # the shield
			else:
				Sfx.play("hit_blade", boost)
		"assassin":
			Sfx.play("hit_blade", boost - 1.0, 1.08)
		"archer":
			Sfx.play("hit_blade", boost - 3.0, 1.15)
		"cleric", "monk":
			Sfx.play("hit_heavy" if _heavy(move) else "hit_blunt", boost)
		"mage":
			var elements := _elements(move)
			if elements.is_empty():
				Sfx.play("cast_energy", boost)
			for e in elements:
				match e:
					"fire":
						Sfx.play("fire", boost)
					"ice":
						Sfx.play("cast_ice", boost)
					"lightning":
						Sfx.play("cast_lightning", boost)
					_:
						Sfx.play("cast_energy", boost)
	if move.has("element") and attacker.class_id != "mage" and String(move["element"]) == "fire":
		Sfx.play("fire", -4.0)  # an Enchanted weapon


## An enemy's skill goes off (before it's known who it hits).
static func enemy_strike(enemy: Combatant, def: EnemySkill) -> void:
	if def == null:
		return
	for word in BOW_WORDS:
		if def.skill_name.contains(word):
			Sfx.play("bow")
			return
	if _burns(enemy, def):
		Sfx.play("cast_fire", -1.0)
	elif def.skill_name in ["Dark Bolt", "Curse", "Doom Gaze"]:
		Sfx.play("cast_energy", -1.0, 0.8)
	elif enemy.class_id == "" and not enemy.anchored:
		Sfx.play("swing", -3.0, 0.85)


## An enemy's skill reaches a party member. result: "hit", "defend" or
## "parry" (parries have their own sounds: see BattleArena).
static func party_hit(enemy: Combatant, def: EnemySkill, heavy: bool, result: String) -> void:
	match result:
		"hit":
			Sfx.play("hit_heavy" if heavy else "hit_blunt", 0.0, 0.92)
		"defend":
			Sfx.play("hit_blunt", -4.0, 1.1)
	if result != "parry" and def != null and _burns(enemy, def):
		Sfx.play("fire", -2.0)


## An enemy loses HP (died: it just went down).
static func enemy_hurt(enemy: Combatant, died: bool) -> void:
	var kind := enemy.scene_file_path.get_file().get_basename()
	if kind == "gale_maw":
		Sfx.play("gale_maw", 0.0 if died else -4.0, 0.8 if died else 1.0)
		return
	if died:
		match kind:
			"ogre_warrior":
				Sfx.play("ogre_die")
			"dragon_hatchling":
				Sfx.play("hatchling_die")
			"stone_golem":
				Sfx.play("golem_die")
			_:
				if not enemy.boss:
					Sfx.play("enemy_die")
		return
	if not enemy.boss:
		Sfx.play("enemy_hurt", -3.0)


static func _heavy(move: Dictionary) -> bool:
	return int(move.get("kind", Skills.Kind.ATTACK)) == Skills.Kind.SMASH


static func _elements(move: Dictionary) -> Array:
	return SpellFx._elements(move)


static func _burns(enemy: Combatant, def: EnemySkill) -> bool:
	for word in FIRE_WORDS:
		if def.skill_name.contains(word):
			return true
	return def.skill_name == "Breath" and enemy.scene_file_path.contains("dragon")
