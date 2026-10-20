extends Node
## The game from the title screen on, the way a player goes through it: start a new game, pause,
## save to a named save, go back to the title screen and load the save again. Runs the real main
## scene, so it takes a few seconds:
##
##   godot --headless --path . res://tests/main_flow.tscn

const SLOT := "Main flow test"

var _failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var menus: Menus = main.menus
	var hud: Hud = main.hud
	print("From the title screen")
	_check(menus.current() == "title" and not main._in_game and not hud.visible, "an ordinary launch opens the title screen, with the HUD hidden")

	# Choosing land with an inherited house: the house is shown on the plot that is picked, and goes back with the plot beside the square.
	menus.new_game_requested.emit(4242, "inherited", "short")
	var home_rect: Rect2i = main.world.lot
	var home_things := _things_in(main.world, home_rect)
	_check(menus.current() == "land" and home_things >= 3, "with an inherited house, the land screen shows it standing on the plot beside the square (%d things there)" % home_things)
	var other := ""
	for option in Starts.land_options(main.world):
		if str(option["id"]) != WorldState.HOME_LOT:
			other = str(option["id"])
			break
	menus.land_picked.emit(other)
	var moved_to: Rect2i = main.world.lot
	_check(other != "" and moved_to != home_rect and _things_in(main.world, moved_to) >= 3 and _things_in(main.world, home_rect) == 0, "picking another plot moves the house with it (%d things there, none left at the old one)" % _things_in(main.world, moved_to))
	_check(main.camera.position.distance_to((Vector2(moved_to.get_center()) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE) < 8.0, "and the camera goes to it")
	menus.land_picked.emit(WorldState.HOME_LOT)
	_check(main.world.lot == home_rect and _things_in(main.world, home_rect) == home_things, "going back to the plot beside the square puts it back there")

	menus.new_game_requested.emit(4242, "arrived", "short")
	_check(menus.current() == "land" and not main._in_game and main._lot_picker.visible, "Begin first lets the player choose their land")
	menus.land_confirmed.emit("home")
	_check(main._in_game and hud.visible and not menus.is_open(), "Begin starts the game and shows the HUD")
	_check(main.world.world_seed == 4242 and main.world.titles.size() > 0 and main.world.lifespan == "short" and GameClock.speed_level == 0 and main.build.active, "with the chosen seed, start and lifespan, paused in build mode on bare land")
	GameClock.set_speed(1)

	# Right-click in build mode never gives one of your folk an order; with build mode off it does.
	var menu_asked := [0]
	main.pawn_layer.context_menu_requested.connect(func(_at: Vector2, _tile: Vector2i) -> void: menu_asked[0] += 1)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = Vector2(576, 120)
	main.get_viewport().push_input(right_click)
	_check(main.build.active and menu_asked[0] == 0 and not hud._action_menu.visible, "right-click in build mode opens no menu for the people")
	main.build.set_active(false)
	main.get_viewport().push_input(right_click)
	_check(menu_asked[0] == 1, "but with build mode off it still does")
	hud.close_action_menu()
	main.build.set_active(true)
	_check(str(main.build.tool["kind"]) == "select" and hud._build_tool_buttons["select"].button_pressed, "build mode opens with the hand in hand, and the toolbar shows it")

	# Time passes slowly, but people walk at a human pace: a walk across the yard takes seconds.
	var walker: Pawn = main.sim.household.selected()
	GameClock.set_speed(1)
	var from := walker.tile
	var goal := Vector2i(-1, -1)
	for offset in [Vector2i(10, 0), Vector2i(-10, 0), Vector2i(0, 10), Vector2i(0, -10), Vector2i(6, 6), Vector2i(-6, -6)]:
		var there: Vector2i = from + offset
		if main.world.is_walkable(there.x, there.y) and not main.sim.pathfinder.find_path(from, there).is_empty():
			goal = there
			break
	var ticks_before := GameClock.tick
	if goal.x >= 0:
		main.sim.order_move(walker, goal)
		var waited := 0.0
		while walker.tile != goal and waited < 8.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		_check(walker.tile == goal and GameClock.tick - ticks_before <= 4, "a ten-tile walk takes a few seconds and only a minute or two of game time (%.1f s, %d min)" % [waited, GameClock.tick - ticks_before])
	GameClock.set_speed(2)
	main._open_pause()
	_check(menus.current() == "pause" and GameClock.speed_level == 0 and not main.camera.input_enabled, "the pause menu stops the clock and the camera")
	menus.close()
	_check(GameClock.speed_level == 2 and main.camera.input_enabled, "closing it carries on at the same speed")

	main._open_pause()
	menus.save_screen_requested.emit()
	_check(menus.current() == "save" and "family" in menus._save_field.text, "Save Game suggests a name after the family")
	menus.save_requested.emit(SLOT)
	var path := SaveSlots.slot_path(SLOT)
	_check(FileAccess.file_exists(path) and SaveSlots.read_meta(path).get("name") == SLOT and not menus.is_open(), "saving writes the named save and goes back to the game")
	var family := str(SaveSlots.read_meta(path).get("family", ""))
	_check(family != "" and family in main._describe_newest_save(), "the title screen will offer to continue it")

	menus.title_requested.emit()
	_check(menus.current() == "title" and not main._in_game and not hud.visible, "Main Menu goes back to the title screen")
	_check(main.world.world_seed != 4242, "with a new town behind it")

	menus.load_requested.emit(path)
	_check(main._in_game and not menus.is_open() and main.world.world_seed == 4242, "loading the save puts the game back")
	menus.load_requested.emit("user://saves/no_such_save.json")
	_check(menus.current() == "load" and menus._load_error.visible, "a save that cannot be loaded says so on the load screen")

	# The families screen: take up another family, and go back.
	menus.close()
	var before: int = main.sim.household.pawns.size()
	var old_name: String = Families.family_name(main.sim.household.pawns)
	main._open_menu(main._open_families)
	_check(menus.current() == "families" and menus._family_list.get_child_count() > 6, "the families screen lists the town's families, the empty houses and what has happened")
	var rows: Array = Families.rows(main.sim)
	var lot_id := ""
	for row in rows:
		if str(row["blocker"]) == "":
			lot_id = str(row["lot"])
			break
	menus.play_family_requested.emit(lot_id)
	var new_name: String = Families.family_name(main.sim.household.pawns)
	_check(lot_id != "" and not menus.is_open() and new_name != old_name and main.sim.household.selected() != null and main.sim.household.selected().home_lot == WorldState.HOME_LOT, "playing one closes the screen and you are that family (%s, then %s; %d folk before)" % [old_name, new_name, before])
	main._open_menu(main._open_families)
	menus.play_family_requested.emit(WorldState.HOME_LOT)
	_check(menus.current() == "families" and "own family" in menus._family_note.text, "asking for your own family says why not")
	menus.close()

	SaveSlots.remove(path)
	print("")
	print("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## How many placed things stand inside a rectangle of the world.
func _things_in(world: WorldState, rect: Rect2i) -> int:
	var count := 0
	for placed in world.objects:
		count += 1 if rect.has_point(placed.tile) else 0
	return count


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
