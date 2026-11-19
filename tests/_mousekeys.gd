extends SceneTree
# 1.0.1 menu bits: mouse buttons as keybinds (middle / side buttons), the
# Renderer option (Windows), and which moves count as hitting several.
var fails := 0
func check(c, l):
	print(("OK   " if c else "FAIL ") + l)
	if not c: fails += 1
func _initialize():
	Keybinds.apply_saved()
	var old_parry := Keybinds.main_key("parry")
	# A side button becomes Parry's main "key".
	var mouse4 := Keybinds.MOUSE_BASE + MOUSE_BUTTON_XBUTTON1
	Keybinds.rebind("parry", mouse4)
	check(Keybinds.main_key("parry") == mouse4 and Keybinds.key_label("parry") == "Mouse 4", "Parry on Mouse 4 (%s)" % Keybinds.key_label("parry"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_XBUTTON1
	click.pressed = true
	check(click.is_action_pressed("parry"), "pressing Mouse 4 is Parry")
	check(Keybinds.fill("Parry: {parry}") == "Parry: Mouse 4", "hints name it")
	# Saved and loaded back.
	Keybinds.save()
	Keybinds._applied = false
	InputMap.load_from_project_settings()
	Keybinds.apply_saved()
	check(Keybinds.main_key("parry") == mouse4, "kept after a restart")
	# Swapping with a key: Defend takes Mouse 4, Parry gets Defend's key.
	var defend_key := Keybinds.main_key("defend")
	Keybinds.rebind("defend", mouse4)
	check(Keybinds.main_key("defend") == mouse4 and Keybinds.main_key("parry") == defend_key, "swaps like a key")
	# Only the middle and side buttons can be bound.
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	check(Keybinds.event_code(left) == 0 and Keybinds.event_code(right) == 0 and Keybinds.event_code(middle) > 0,
			"left / right click stay for menus and the camera; middle can be bound")
	Keybinds.reset_defaults()
	Keybinds._applied = false
	check(Keybinds.main_key("parry") == old_parry, "Reset gives the keys back")
	# The Renderer row (Windows only; switched on here).
	var before := Settings.renderer()
	Settings.renderer_row = true
	var rows := Settings.option_rows()
	check(rows.size() == 11 and rows[10].begins_with("Renderer: "), "Options lists the renderer: %s" % rows[10])
	Settings.set_renderer("vulkan")
	Settings.change_option(10)
	check(Settings.renderer() == "d3d12", "the row switches to Direct3D 12")
	var text := FileAccess.get_file_as_string(Settings.RENDERER_OVERRIDE)
	check(text.contains("rendering_device/driver=\"d3d12\""), "and writes the start-up override")
	check(Settings.option_rows()[10].contains("after a restart"), "the row says it applies after a restart")
	Settings.change_option(10)
	check(Settings.renderer() == "vulkan" and not FileAccess.file_exists(Settings.RENDERER_OVERRIDE), "back to Vulkan: the override is gone")
	check(ProjectSettings.get_setting("application/config/project_settings_override") == Settings.RENDERER_OVERRIDE,
			"the project reads that file at start-up")
	Settings.set_renderer(before)
	Settings.renderer_row = false
	check(Settings.option_rows().size() == 10, "no row off Windows")
	# Single Target / Area icons: which moves hit several.
	var fire = Moves.attacks("mage").filter(func(m): return m["name"] == "Fire")[0]
	var slash = Moves.attacks("knight").filter(func(m): return m["name"] == "Slash")[0]
	var chain = Moves.arts("mage").filter(func(m): return m["name"] == "Chain Lightning")[0]
	check(Moves.hits_many(fire) and Moves.hits_many(chain) and not Moves.hits_many(slash),
			"Fire (a line) and Chain Lightning hit several; Slash hits one")
	print("FAILS: ", fails)
	quit()
