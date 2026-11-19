extends SceneTree
# Title screen: New Game opens a page saying the Prologue is a short story
# set piece (Boss Rush and Round Select are for testing fights); Back
# returns to the main list on New Game; Start the Prologue opens the field.
var m
var t := 0.0
var step := 0
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	m = load("res://scenes/ui/title_menu.tscn").instantiate()
	root.add_child(m)
func _process(d) -> bool:
	t += d
	if t < 0.3: return false
	t = 0.0
	match step:
		0:
			var items: Array = m._main_items()
			check(items.has("New Game") and items.find("New Game") < items.find("Boss Rush"), "New Game is on the title screen, above Boss Rush: %s" % [items])
			check(items.has("Tutorial") and items.has("Round Select"), "Boss Rush, Tutorial and Round Select stay")
			check(m._main_note("New Game") != "", "New Game has a note: %s" % m._main_note("New Game"))
			m.index = items.find("New Game")
			m._select()
			check(m.page == m.Page.NEW_GAME, "choosing it opens its page first")
			check(m._items() == [m.START_PROLOGUE, m.BACK_ROW], "the page offers %s" % [m._items()])
			var lines := " ".join(m.NEW_GAME_LINES)
			check("story" in lines and "Boss Rush" in lines and "Round Select" in lines, "it warns it's a story, and points at Boss Rush / Round Select")
			m.index = 1
			m._select()
			check(m.page == m.Page.MAIN and m._main_items()[m.index] == "New Game", "Back returns to the list, on New Game")
			m._select()
			m.index = 0
			m._select()
		1:
			var field = null
			for c in root.get_children():
				if c is FieldScene: field = c
			check(field != null, "Start the Prologue opens the field")
			check(field != null and field.room != null and field.room.name == "TestHall", "in the Prologue's first room")
			print("FAILS: ", fails)
			quit()
			return true
	step += 1
	return false
