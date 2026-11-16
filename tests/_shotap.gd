extends SceneTree
# Screenshot: a wide AP bar next to an enemy with status tags (the bar must
# stay clear of the enemy's name, HP and tags).
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
	if t < 1.0: return false
	var g = a.enemies[0]
	g.statuses["chilled"] = {"turns": 1}
	g.statuses["exposed"] = {"turns": 2}
	a.current_max_ap = 180
	a.ap = 118
	a.ap_meter.ceiling = 500
	if t < 1.6: return false
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	return true
