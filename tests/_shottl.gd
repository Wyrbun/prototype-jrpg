extends SceneTree
# Screenshot of the timeline bar with fighters spread along it.
var a
var t := 0.0
var done := false
const D := "/tmp/claude-0/-home-claude/05b81194-2749-584d-a628-b8b7ec5f1f2b/scratchpad/"
func _initialize():
	BattleArena._round_index = int(OS.get_environment("R")) if OS.get_environment("R") != "" else 2
	a = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(a)
func _process(d):
	t += d
	if t < 0.6 or done: return false
	if t < 0.7:
		var spots := [12.0, 30.0, 47.0, 58.0, 66.0, 40.0, 84.0, 22.0]
		var i := 0
		for c in a.combatants:
			c.hold = true; c.timeline_pos = spots[i % spots.size()]; i += 1
		var e = a.enemies[0]
		e.forced_skill = e.skills[0]; e.timeline_pos = a.cast_zone_start + 6; a._begin_cast(e); a._reveal_skill(e)
		e.timeline_pos = a.cast_zone_start + 9
		if a.enemies.size() > 1:
			var e2 = a.enemies[1]; e2.forced_skill = e2.skills[0]; e2.timeline_pos = a.cast_zone_start + 2; a._begin_cast(e2)
		a.timeline_bar.target = e
		if OS.get_environment("W") != "": a.timeline_bar.party_command_at = 70.0
		return false
	if t < 1.2: return false
	done = true
	var img = root.get_texture().get_image()
	img.save_png(D + "tl_full.png")
	img.get_region(Rect2i(0, 0, img.get_width(), 200)).save_png(D + "tl.png")
	return true
