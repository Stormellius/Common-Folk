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

	menus.new_game_requested.emit(4242, "arrived", "short")
	_check(main._in_game and hud.visible and not menus.is_open(), "Begin starts the game and shows the HUD")
	_check(main.world.world_seed == 4242 and main.world.titles.size() > 0 and main.world.lifespan == "short" and GameClock.speed_level == 1, "with the chosen seed, start and lifespan, running")

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

	SaveSlots.remove(path)
	print("")
	print("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
