extends SceneTree
# Screenshot: Party AI on, mid-fight (AUTO tags, an AI combo's damage).
var a
var t := 0.0
func _initialize():
	BattleArena._round_index = 7
	BattleArena.chosen_for_round = 7
	BattleArena.chosen_party.assign(["res://scenes/characters/knight.tscn", "res://scenes/characters/archer.tscn", "res://scenes/characters/mage.tscn", "res://scenes/characters/cleric.tscn"])
	BattleArena.party_ai_override = 1
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if a._party_turn() and a.active == a.controlled and a._menu_mode == BattleMenu.Mode.COMMANDS:
		a._wait_command()
	if a.stats.get("ai_attacks", 0) >= 2 and a._flash_message.contains("damage") and a._flash_time_left > 2.0:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT")); return true
	return t > 60.0
