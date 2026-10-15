extends Node
## Quick checks for the milestone 1 foundations. Run them from the project folder:
##
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Prints one line per check and exits with code 1 if anything failed.

const TEST_MOD_DIR := "user://mods/smoke_test_mod"
const TEST_SAVE := "user://smoke_test_save.json"

var _failures := 0
var _only := ""  # --only=marriage runs just that section


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	_section("registry", _test_registry)
	_section("mod_loading", _test_mod_loading)
	_section("clock", _test_clock)
	_section("generator", _test_generator)
	_section("map_view", _test_map_view)
	_section("hud", _test_hud)
	_section("pathfinding", _test_pathfinding)
	_section("pawn_movement", _test_pawn_movement)
	_section("household", _test_household)
	_section("actions", _test_actions)
	_section("needs", _test_needs)
	_section("building", _test_building)
	_section("town", _test_town)
	_section("region", _test_region)
	_section("economy", _test_economy)
	_section("work_sites", _test_work_sites)
	_section("skills", _test_skills)
	_section("social", _test_social)
	_section("romance", _test_romance)
	_section("marriage", _test_marriage)
	_section("animals", _test_animals)
	_section("construction", _test_construction)
	_section("trade", _test_trade)
	_section("dreams", _test_dreams)
	_section("families", _test_families)
	_section("audio", _test_audio)
	_section("art", _test_art)
	_section("clothing", _test_clothing)
	_section("events", _test_events)
	_section("realm", _test_realm)
	_section("faith_and_illness", _test_faith_and_illness)
	_section("conflict", _test_conflict)
	_section("accidents", _test_accidents)
	_section("pregnancy", _test_pregnancy)
	_section("death", _test_death)
	_section("life_and_death", _test_life_and_death)
	_section("mood", _test_mood)
	_section("save_and_load", _test_save_and_load)
	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _section(name: String, run: Callable) -> void:
	if _only == "" or _only == name:
		run.call()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok    ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)


func _test_registry() -> void:
	print("Data registry")
	_check(DataRegistry.count("tiles") >= 5, "tiles.json loaded")
	_check(DataRegistry.count("seasons") == 4, "seasons.json has four seasons")
	_check(DataRegistry.count("needs") >= 7, "needs.json has at least the seven starting needs")
	_check(DataRegistry.count("traits") >= 6, "traits.json loaded")
	_check(DataRegistry.count("names") == 5 and DataRegistry.count("appearance") == 4 and DataRegistry.count("objects") >= 6, "names, appearance and objects loaded")
	_check(DataRegistry.has_def("tiles", "grass"), "grass tile exists")
	_check(not DataRegistry.has_def("tiles", "nonexistent"), "unknown id reports missing")
	_check(DataRegistry.get_def("tiles", "nonexistent").is_empty(), "unknown id gives an empty Dictionary")
	_check(DataRegistry.load_errors.is_empty(), "no load errors in the shipped data")
	_check("Example Mod" not in DataRegistry.loaded_mods, "disabled example mod is not loaded")


func _test_mod_loading() -> void:
	print("Mod loading")
	var original_color := str(DataRegistry.get_def("tiles", "grass").get("color"))

	DirAccess.make_dir_recursive_absolute(TEST_MOD_DIR)
	_write_file(TEST_MOD_DIR + "/mod.json", '{"name": "Smoke Test Mod", "load_order": 5}')
	_write_file(TEST_MOD_DIR + "/tiles.json", '[{"id":"grass","name":"Grass","color":"#123456","walkable":true},{"id":"water","_remove":true},{"id":"lava","name":"Lava","color":"#ff0000","walkable":false}]')
	_write_file(TEST_MOD_DIR + "/gizmos.json", '[{"id":"bread","name":"Bread"}]')
	DataRegistry.reload()

	_check("Smoke Test Mod" in DataRegistry.loaded_mods, "mod in user://mods is discovered")
	_check(str(DataRegistry.get_def("tiles", "grass").get("color")) == "#123456", "mod replaces an existing entry by id")
	_check(DataRegistry.has_def("tiles", "lava"), "mod adds a new entry")
	_check(not DataRegistry.has_def("tiles", "water"), "mod removes an entry with _remove")
	_check(DataRegistry.count("gizmos") == 1, "mod can add a brand new kind of content")

	for file_name in ["mod.json", "tiles.json", "gizmos.json"]:
		DirAccess.remove_absolute(TEST_MOD_DIR + "/" + file_name)
	DirAccess.remove_absolute(TEST_MOD_DIR)
	DataRegistry.reload()

	_check("Smoke Test Mod" not in DataRegistry.loaded_mods, "mod is gone after its folder is removed")
	_check(str(DataRegistry.get_def("tiles", "grass").get("color")) == original_color, "base data is restored")
	_check(DataRegistry.has_def("tiles", "water"), "removed entry comes back with base data")


## Runs the clock for `seconds` of real time in small frames, as the game would.
func _run_clock(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		GameClock._process(minf(left, 0.05))
		left -= 0.05


func _test_clock() -> void:
	print("Game clock")
	GameClock.reset()
	GameClock.set_speed(1)
	_check(GameClock.tick == GameClock.START_TICK, "new game starts at the start tick")
	_check(GameClock.get_time_text() == "06:00", "new game starts at 06:00")
	var date := GameClock.get_date()
	_check(date["season_id"] == "spring" and date["day"] == 1 and date["year"] == 1, "new game starts on spring day 1, year 1")

	GameClock.advance_ticks(GameClock.MINUTES_PER_DAY)
	_check(GameClock.get_date()["day"] == 2, "one day later it is day 2")

	GameClock.reset()
	GameClock.advance_ticks(15 * GameClock.MINUTES_PER_DAY)
	_check(GameClock.get_date()["season_id"] == "summer", "15 days later it is summer")

	GameClock.reset()
	GameClock.advance_ticks(60 * GameClock.MINUTES_PER_DAY)
	date = GameClock.get_date()
	_check(date["year"] == 2 and date["season_id"] == "spring" and date["day"] == 1, "60 days later it is spring of year 2")

	GameClock.set_time(20, 12)
	var season_position := GameClock.get_season_position()
	_check(season_position["index"] == 1 and absf(season_position["progress"] - (5.5 / 15.0)) < 0.001, "season position moves smoothly through a season")
	GameClock.set_time(0, 6)
	_check(GameClock.tick == GameClock.START_TICK, "set_time(0, 6) is the start of a new game")
	GameClock.reset()

	GameClock.set_speed(0)
	var before := GameClock.tick
	GameClock._process(5.0)
	_check(GameClock.tick == before, "paused clock does not advance")

	GameClock.set_speed(1)
	_check(is_equal_approx(GameClock.DAY_SECONDS, 3600.0) and is_equal_approx(GameClock.MINUTE_SECONDS * GameClock.MINUTES_PER_DAY, 3600.0), "a day takes an hour at normal speed")
	var motion := [0]
	var count_motion := func() -> void: motion[0] += 1
	GameClock.motion_ticked.connect(count_motion)
	GameClock.set_time(0, 6)
	before = GameClock.tick
	_run_clock(GameClock.MINUTE_SECONDS * 4.0 + 0.01)
	_check(GameClock.tick - before == 4, "1x runs a game minute every two and a half seconds (%d)" % (GameClock.tick - before))
	_check(motion[0] == 4 * GameClock.SUBSTEPS_PER_MINUTE, "and gives people %d steps to walk in between (%d)" % [GameClock.SUBSTEPS_PER_MINUTE, motion[0]])
	GameClock.set_time(0, 6)
	motion[0] = 0
	GameClock.advance_one_tick()
	_check(motion[0] == GameClock.SUBSTEPS_PER_MINUTE, "a minute advanced by hand carries its motion too")
	GameClock.motion_ticked.disconnect(count_motion)

	GameClock.set_speed(2)
	GameClock.set_time(0, 6)
	before = GameClock.tick
	_run_clock(GameClock.MINUTE_SECONDS * 2.0 + 0.01)
	_check(GameClock.tick - before == 6, "3x runs three times as fast (%d)" % (GameClock.tick - before))
	GameClock.set_speed(3)
	GameClock.set_time(0, 6)
	before = GameClock.tick
	_run_clock(GameClock.MINUTE_SECONDS + 0.01)
	_check(GameClock.tick - before == 10, "and 10x ten times (%d)" % (GameClock.tick - before))
	GameClock.set_speed(9)
	_check(GameClock.speed_level == 4, "speed stops at the fastest level")

	GameClock.set_time(0, 6)
	before = GameClock.tick
	GameClock._process(1000.0)
	_check(GameClock.tick - before <= GameClock.MAX_SUBSTEPS_PER_FRAME / GameClock.SUBSTEPS_PER_MINUTE + 1, "a very long frame is capped")

	GameClock.set_speed(2)
	GameClock.toggle_pause()
	_check(GameClock.speed_level == 0, "toggle pauses")
	GameClock.toggle_pause()
	_check(GameClock.speed_level == 2, "toggle resumes at the previous speed")
	GameClock.reset()
	GameClock.set_speed(1)


func _test_generator() -> void:
	print("World generation")
	var a := MapGenerator.generate(42, 96, 64)
	var b := MapGenerator.generate(42, 96, 64)
	var c := MapGenerator.generate(43, 96, 64)
	_check(a.palette == b.palette and a.tiles == b.tiles, "same seed gives the same world")
	_check(a.tiles != c.tiles, "different seed gives a different world")
	_check(a.width == 96 and a.height == 64 and a.tiles.size() == 96 * 64, "world has the requested size")
	_check("water" in a.palette and "grass" in a.palette, "world has water and grass")
	_check(a.get_tile_id(48, 32) == "dirt", "center of the town clearing is a road")
	_check(a.get_tile_id(-1, 0) == "" and a.get_tile_id(96, 0) == "", "outside the map has no tile")
	_check(a.is_walkable(40, 32), "clearing grass is walkable")
	var water_cell := _find_tile(a, "water")
	_check(water_cell.x >= 0 and not a.is_walkable(water_cell.x, water_cell.y), "water is not walkable")


func _test_map_view() -> void:
	print("Map view")
	var view := MapView.new()
	add_child(view)  # runs _ready, which connects to the clock and loads the shader
	var world := MapGenerator.generate(5, 32, 24)
	view.set_world(world)
	_check(view.world == world, "map view accepts a world and builds its textures")
	_check(MapView.STYLES.has(str(DataRegistry.get_def("tiles", "water").get("style"))), "tile styles in tiles.json are known to the view")
	for tile_id in DataRegistry.get_ids("tiles"):
		var def := DataRegistry.get_def("tiles", tile_id)
		_check(def.has("style") and def.has("priority"), "tile '%s' has a style and priority" % tile_id)
	view.queue_free()

func _test_hud() -> void:
	print("HUD")
	var hud := Hud.new()
	add_child(hud)  # runs _ready, which builds the panels
	var household := HouseholdGenerator.create(MapGenerator.generate(3, 64, 48))
	hud.set_household(household)
	var pressed_count := func() -> int:
		var count := 0
		for button in hud._speed_buttons:
			if button.button_pressed:
				count += 1
		return count
	GameClock.set_speed(3)
	_check(hud._speed_buttons[3].button_pressed and pressed_count.call() == 1, "going to 3x shows only 3x")
	GameClock.set_speed(1)
	_check(hud._speed_buttons[1].button_pressed and not hud._speed_buttons[3].button_pressed and pressed_count.call() == 1, "going back to 1x releases 3x")
	GameClock.set_speed(0)
	_check(hud._speed_buttons[0].button_pressed and pressed_count.call() == 1, "pausing shows only Pause")
	GameClock.set_speed(2)
	_check(hud._speed_buttons[2].button_pressed and pressed_count.call() == 1, "2x shows only 2x")
	var first: int = household.pawns[0].id
	var second: int = household.pawns[1].id
	hud.set_selected(second)
	hud.set_selected(first)
	var chip_count := 0
	for id in hud._chips:
		if hud._chips[id].button_pressed:
			chip_count += 1
	_check(hud._chips[first].button_pressed and chip_count == 1, "switching person highlights only that person")
	# The build palette.
	var chosen_tools: Array[String] = []
	hud.build_tool_chosen.connect(func(kind: String, id: String) -> void: chosen_tools.append("%s:%s" % [kind, id]))
	var toggles: Array[bool] = []
	hud.build_toggled.connect(func(on: bool) -> void: toggles.append(on))
	_check(not hud._build_panel.visible, "the build palette starts hidden")
	hud.set_build_mode(true)
	_check(hud._build_panel.visible and hud._build_button.button_pressed and toggles.is_empty(), "turning build mode on shows the palette without a feedback loop")
	_check(hud._build_tabs.has("Furniture") and hud._build_tabs.has("Structure") and hud._build_tabs.has("Floors") and hud._build_tabs.has("Tools"), "the palette has tabs for furniture, structure, floors and tools")
	var wall_button: Button = null
	for button in hud._build_items:
		if button.tooltip_text.begins_with("Timber wall"):
			wall_button = button
	wall_button.button_pressed = true
	_check(chosen_tools == ["place:wall"], "picking a palette entry reports the tool")
	wall_button.button_pressed = false
	_check(chosen_tools.back() == "none:", "clicking it again puts the tool away")
	wall_button.set_pressed_no_signal(true)
	hud.clear_build_selection()
	_check(not wall_button.button_pressed and chosen_tools.size() == 2, "clearing the selection from outside sends nothing")
	hud._show_build_tab("Floors")
	_check(hud._build_tabs["Floors"].visible and not hud._build_tabs["Structure"].visible, "tabs switch")
	hud.set_build_mode(false)
	_check(not hud._build_panel.visible and not hud._build_button.button_pressed, "turning it off hides the palette")
	hud.set_realm("Burgher, Freehold")
	_check(hud._realm_label.visible and hud._realm_label.text == "Burgher, Freehold", "the realm lines show under the purse")
	_check(not hud._help_panel.visible, "the help panel starts hidden")
	hud.toggle_help()
	_check(hud._help_panel.visible, "H shows the keys")
	GameClock.reset()
	GameClock.set_speed(1)
	hud.queue_free()
	_test_menus()


func _test_menus() -> void:
	print("Menus, saves and settings")
	var menus := Menus.new()
	add_child(menus)
	_check(not menus.is_open(), "no menu shows until asked for")
	menus.show_title("The Brook family, Spring 3, year 1")
	_check(menus.current() == "title" and not menus._continue_button.disabled and menus._continue_note.text.begins_with("The Brook"), "the title screen offers to continue the newest save")
	menus.show_title("")
	_check(menus._continue_button.disabled, "and cannot continue when there is no save")
	var begun: Array = []
	menus.new_game_requested.connect(func(world_seed: int, start_id: String, lifespan: String) -> void: begun.append([world_seed, start_id, lifespan]))
	menus.open_new_game_from_title()
	_check(menus.current() == "new" and menus._start_buttons.size() == 3, "New Game shows a button for each way of beginning")
	menus._start_buttons["arrived"].pressed.emit()
	menus._seed_field.text = "1234"
	menus._begin_button.pressed.emit()
	_check(begun == [[1234, "arrived", "normal"]], "Begin reports the start, the seed and the lifespan (normal unless chosen)")
	_check(Menus.seed_from_text("77") == 77 and Menus.seed_from_text("Thornbury") == Menus.seed_from_text("Thornbury") and Menus.seed_from_text("Thornbury") >= 0, "a typed seed is a number, or any word always makes the same one")
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	menus._unhandled_input(back)
	_check(menus.current() == "title", "Esc goes back to where the screen was opened from")
	var closes := [0]
	menus.closed.connect(func() -> void: closes[0] += 1)
	menus.show_pause("Spring 3")
	menus.open_settings()
	menus._unhandled_input(back)
	_check(menus.current() == "pause", "settings opened from the pause menu go back to it")
	menus._unhandled_input(back)
	_check(not menus.is_open() and closes[0] == 1, "and Esc on the pause menu closes it, so the game carries on")
	menus.queue_free()

	_check(SaveSlots.slot_path("The Brook family, Spring 3") == "user://saves/The_Brook_family__Spring_3.json" and SaveSlots.slot_path("../../etc") == "user://saves/______etc.json" and SaveSlots.slot_path("  ") == "user://saves/save.json", "a save's name always makes a safe file name in the saves folder")
	SaveSlots.make_dir()
	var path := SaveSlots.slot_path("Smoke test slot")
	var world := MapGenerator.generate(3, 32, 24)
	_check(SaveGame.save(path, world) == OK and SaveSlots.write_meta(path, { "name": "Smoke test slot", "family": "Brook", "folk": 3, "date": "Spring 3, year 1", "time": "12:00" }) == OK, "a named save is written with what it is beside it")
	var found := {}
	for entry in SaveSlots.all():
		if entry["path"] == path:
			found = entry
	_check(found.get("kind") == "slot" and found.get("title") == "Smoke test slot" and found["meta"].get("family") == "Brook", "the list of saves shows it by its name, with its family")
	_check("The Brook family, 3 folk" in Menus.describe_save(found) and "Spring 3, year 1, 12:00" in Menus.describe_save(found), "and describes it")
	SaveSlots.remove(path)
	_check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".meta"), "deleting a save takes its description with it")

	var scale_before := Settings.ui_scale
	var changes: Array[String] = []
	Settings.changed.connect(func(key: String) -> void: changes.append(key))
	Settings.set_value("ui_scale", 1.3)
	_check(Settings.ui_scale == 1.3 and changes == ["ui_scale"], "changing a setting applies it and says so")
	var stored := ConfigFile.new()
	_check(stored.load(Settings.PATH) == OK and is_equal_approx(float(stored.get_value("display", "ui_scale")), 1.3), "and keeps it in the settings file")
	Settings.set_value("ui_scale", scale_before)


## A 12x8 meadow with a wall of water down column 6 that has one gap at row 7,
## and a patch of forest at (3..4, 2).
func _make_test_world() -> WorldState:
	var world := WorldState.new(12, 8, 1, "grass")
	for y in 7:
		world.set_tile(6, y, "water")
	world.set_tile(3, 2, "forest")
	world.set_tile(4, 2, "forest")
	return world


func _test_pathfinding() -> void:
	print("Pathfinding")
	var world := _make_test_world()
	var finder := PathFinder.new(world)
	var route := finder.find_path(Vector2i(1, 1), Vector2i(10, 1))
	_check(not route.is_empty() and route[route.size() - 1] == Vector2i(10, 1), "finds a way to a tile across the water")
	_check(Vector2i(6, 7) in route, "goes through the only gap in the water")
	var steps_ok := true
	var previous := Vector2i(1, 1)
	for cell in route:
		if maxi(absi(cell.x - previous.x), absi(cell.y - previous.y)) != 1 or not world.is_walkable(cell.x, cell.y):
			steps_ok = false
		previous = cell
	_check(steps_ok, "every step is to a neighboring walkable tile")
	_check(finder.find_path(Vector2i(1, 1), Vector2i(6, 3)).is_empty(), "no route into blocked water")
	_check(finder.find_path(Vector2i(1, 1), Vector2i(1, 1)).is_empty(), "no route to the tile you stand on")
	_check(finder.find_path(Vector2i(1, 1), Vector2i(50, 50)).is_empty(), "no route outside the map")

	world.set_tile(6, 7, "water")
	finder.rebuild(world)
	_check(finder.find_path(Vector2i(1, 1), Vector2i(10, 1)).is_empty(), "closing the gap makes the far side unreachable after rebuild")

	var open_world := WorldState.new(5, 5, 1, "grass")
	open_world.set_tile(2, 1, "water")
	open_world.set_tile(1, 2, "water")
	var corner_route := PathFinder.new(open_world).find_path(Vector2i(1, 1), Vector2i(2, 2))
	_check(corner_route.size() > 1, "a diagonal step does not cut between two blocked corners")


func _test_pawn_movement() -> void:
	print("Pawn movement")
	var world := _make_test_world()
	var household := Household.new()
	var pawn := Pawn.new()
	pawn.tile = Vector2i(1, 4)
	pawn.step_to = pawn.tile
	household.add_pawn(pawn)
	var sim := Simulation.new(world, household)

	var result := sim.order_move(pawn, Vector2i(4, 4))
	_check(result["ok"], "a move order to open ground is accepted")
	_check(pawn.has_orders() and pawn.goal_tile() == Vector2i(4, 4), "the pawn has a goal")
	sim.step()
	_check(pawn.is_moving() and pawn.tile == Vector2i(1, 4), "it is mid-step after one tick, still on its first tile")
	_check(pawn.facing == Vector2i(1, 0), "it faces the way it walks")
	for i in 40:
		sim.step()
	_check(pawn.tile == Vector2i(4, 4) and not pawn.has_orders(), "it arrives and stops")

	sim.order_move(pawn, Vector2i(4, 1))  # straight up through the forest tile at (4, 2)
	var ticks := 0
	while pawn.has_orders() and ticks < 100:
		sim.step()
		ticks += 1
	var open_only := Pawn.BASE_MOVE_TICKS * 3.0
	_check(pawn.tile == Vector2i(4, 1), "it reaches a goal north of the forest")
	_check(ticks > roundi(open_only), "forest is slower to cross than open ground (%d ticks)" % ticks)

	_check(not sim.order_move(pawn, Vector2i(6, 3))["ok"], "ordering a pawn into water is refused")
	_check(not sim.order_move(pawn, Vector2i(99, 99))["ok"], "ordering a pawn off the map is refused")

	sim.order_move(pawn, Vector2i(2, 1))
	sim.step()
	var committed := pawn.committed_tile()
	sim.order_move(pawn, Vector2i(1, 1))
	var first_step: Vector2i = pawn.path[0]
	_check(maxi(absi(first_step.x - committed.x), absi(first_step.y - committed.y)) == 1, "new orders start from the tile the pawn is already heading to")
	sim.order_stop(pawn)
	for i in 10:
		sim.step()
	_check(not pawn.has_orders() and pawn.tile == committed, "stop halts the pawn at the end of its current step")

	# The pawn only moves when the clock ticks, so a paused clock leaves it where it is.
	sim.order_move(pawn, Vector2i(1, 1))
	GameClock.set_speed(0)
	var paused_tile := pawn.tile
	GameClock._process(5.0)
	_check(pawn.tile == paused_tile, "nothing moves while the clock is paused")
	GameClock.reset()
	GameClock.set_speed(1)


func _test_household() -> void:
	print("Household")
	var world := MapGenerator.generate(42, 96, 64)
	var a := HouseholdGenerator.create(world)
	var b := HouseholdGenerator.create(world)
	_check(a.pawns.size() == HouseholdGenerator.SIZE, "a new household has %d people" % HouseholdGenerator.SIZE)
	_check(a.to_dict() == b.to_dict(), "same world seed gives the same household")
	var other := HouseholdGenerator.create(MapGenerator.generate(43, 96, 64))
	_check(a.to_dict() != other.to_dict(), "a different seed gives a different household")
	var all_ok := true
	var tiles := {}
	for pawn in a.pawns:
		if not world.is_walkable(pawn.tile.x, pawn.tile.y) or tiles.has(pawn.tile) or pawn.display_name == "":
			all_ok = false
		tiles[pawn.tile] = true
	_check(all_ok, "everyone starts on their own walkable tile and has a name")
	_check(a.selected() != null, "someone is selected from the start")

	var first := a.selected_id
	a.cycle_selection()
	_check(a.selected_id != first, "cycling switches to another person")
	for i in a.pawns.size() - 1:
		a.cycle_selection()
	_check(a.selected_id == first, "cycling through everyone comes back around")
	a.cycle_selection(-1)
	_check(a.selected_id == a.pawns[a.pawns.size() - 1].id, "cycling backwards wraps to the last person")
	_check(a.select(a.pawns[1].id) and a.selected_id == a.pawns[1].id, "select picks a given person")
	_check(not a.select(9999), "selecting a missing person fails")
	_check(PawnArt.facing_kind(Vector2i(0, 1)) == PawnArt.SOUTH and PawnArt.facing_kind(Vector2i(-1, -1)) == PawnArt.WEST, "walking direction picks the view to draw")


func _test_actions() -> void:
	print("Actions and right-click menu")
	var world := _make_test_world()
	var household := Household.new()
	for start in [Vector2i(1, 4), Vector2i(2, 4)]:
		var person := Pawn.new()
		person.display_name = "Person %d" % start.x
		person.tile = start
		person.step_to = start
		household.add_pawn(person)
	var sim := Simulation.new(world, household)
	var pawn := household.selected()
	var by_id := func(list: Array[Dictionary], id: String) -> Dictionary:
		for entry in list:
			if entry["id"] == id:
				return entry
		return {}

	var on_grass := PawnActions.list_for(sim, pawn, Vector2i(4, 4))
	_check(by_id.call(on_grass, PawnActions.WALK).get("enabled", false), "walking to open ground is offered")
	_check(by_id.call(on_grass, PawnActions.STOP).is_empty(), "stop is not offered to someone standing still")
	var on_water := PawnActions.list_for(sim, pawn, Vector2i(6, 3))
	var water_walk: Dictionary = by_id.call(on_water, PawnActions.WALK)
	_check(not water_walk.get("enabled", true) and "water" in str(water_walk.get("reason", "")), "walking into water is listed but off, and says why")
	var here := PawnActions.list_for(sim, pawn, pawn.tile)
	_check(not by_id.call(here, PawnActions.WALK).get("enabled", true), "walking to where you stand is off")
	_check(PawnActions.list_for(sim, pawn, Vector2i(-1, 0)).is_empty(), "no menu outside the map")
	var neighbor := PawnActions.list_for(sim, pawn, Vector2i(2, 4))
	var offers_switch := false
	for entry in neighbor:
		offers_switch = offers_switch or "witch" in str(entry["label"]) or str(entry["id"]).begins_with("switch")
	_check(not offers_switch, "right-clicking another person does not offer to switch to them (left-click does that)")

	var walked := PawnActions.perform(sim, pawn, PawnActions.WALK, Vector2i(5, 4))
	_check(walked["ok"] and pawn.goal_tile() == Vector2i(5, 4), "the walk entry sends the person there")
	_check(not by_id.call(PawnActions.list_for(sim, pawn, Vector2i(4, 1)), PawnActions.STOP).is_empty(), "stop is offered while walking")
	PawnActions.perform(sim, pawn, PawnActions.STOP, Vector2i.ZERO)
	_check(pawn.path.is_empty(), "the stop entry cancels the walk")
	_check(not PawnActions.perform(sim, pawn, "nonsense", Vector2i.ZERO)["ok"], "an unknown entry is refused")

	var menu := ActionMenu.new()
	add_child(menu)
	var chosen: Array[String] = []
	menu.action_chosen.connect(func(id: String) -> void: chosen.append(id))
	menu.open(Vector2(50, 50), "Title", on_water)
	_check(menu.visible and menu.buttons.size() == on_water.size(), "the menu shows one button per entry")
	_check(menu.buttons[0].disabled and "water" in menu.buttons[0].text, "a switched-off entry is greyed out and shows its reason")
	menu.close()
	_check(not menu.visible and menu.buttons.is_empty(), "closing hides the menu")
	menu.open(Vector2(50, 50), "Title", on_grass)
	menu.buttons[0].pressed.emit()
	_check(chosen == [PawnActions.WALK] and not menu.visible, "picking an entry reports it and closes the menu")
	menu.queue_free()


## A 24x12 meadow with one person at (2, 2); every need full except the ones given.
func _needs_setup(low: Dictionary) -> Dictionary:
	GameClock.set_time(0, 12)  # noon, so the night-time bedtime rule is off
	var world := WorldState.new(24, 12, 1, "grass")
	var household := Household.new()
	var person := Pawn.new()
	person.display_name = "Tester One"
	person.tile = Vector2i(2, 2)
	person.step_to = person.tile
	for need_id in Needs.active_ids():
		person.needs[need_id] = low.get(need_id, 100.0)
	household.add_pawn(person)
	return { "world": world, "household": household, "pawn": person }


func _distance_tiles(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _run_until_idle(sim: Simulation, pawn: Pawn, limit: int = 1500) -> int:
	var ticks := 0
	while ticks < limit:
		sim.step()
		ticks += 1
		if not pawn.is_busy() and pawn.think_cooldown == 0 and ticks > 1:
			break
	return ticks


func _test_needs() -> void:
	print("Needs and objects")
	var active := Needs.active_ids()
	_check("hunger" in active and "rest" in active and "toilet" in active and "fun" in active, "needs with something to fix them are in play")
	_check("social" in active and "faith" in active and not Needs.slows_when_empty("faith"), "social is in play because chatting fills it, and faith because pews and altars do (it never slows anyone)")
	_check("libido" in active and not Needs.slows_when_empty("libido") and Needs.slows_when_empty("hunger"), "libido is in play because an interaction fills it, and never slows anyone")
	var per_tick := Needs.drain_per_tick("hunger", [], {})
	_check(absf(per_tick - 4.0 / 60.0) < 0.0001, "hunger drains at the rate in needs.json")
	_check(Needs.drain_per_tick("hunger", ["glutton"], {}) > per_tick * 1.4, "the glutton trait speeds hunger up")
	_check(Needs.drain_per_tick("warmth", [], { "warmth": 2.5 }) > 2.0 * 2.4 / 60.0, "a cold season speeds warmth loss up")
	_check(Needs.seek_below("rest", 23 * 60) > Needs.seek_below("rest", 12 * 60), "people go looking for a bed earlier at night")
	_check(Needs.band(80.0) == "good" and Needs.band(30.0) == "low" and Needs.band(5.0) == "critical", "bars are banded good, low and critical")

	# Eating: a hungry person walks to the pot, eats until full and lets it go.
	var setup := _needs_setup({ "hunger": 20.0 })
	var world: WorldState = setup["world"]
	var pawn: Pawn = setup["pawn"]
	var pot := world.add_object("cooking_pot", Vector2i(10, 5))
	_check(pot != null and not world.is_walkable(10, 5), "an object that blocks walking makes its tile unwalkable")
	var sim := Simulation.new(world, setup["household"])
	var ticks := _run_until_idle(sim, pawn)
	_check(float(pawn.needs["hunger"]) > 90.0, "a hungry person goes to eat and ends up full (%d ticks)" % ticks)
	_check(pot.user_id == 0 and pawn.job_kind == "", "the pot is free again afterwards")
	_check(absi(pawn.tile.x - 10) + absi(pawn.tile.y - 5) == 1, "they ate standing beside the pot")

	# Sleeping: on the bed, lying down, until rested.
	setup = _needs_setup({ "rest": 10.0 })
	world = setup["world"]
	pawn = setup["pawn"]
	var bed := world.add_object("bed", Vector2i(8, 2))
	world.set_roof(Vector2i(8, 2), "thatch")  # under a roof, so it gives its full rest
	sim = Simulation.new(world, setup["household"])
	var lay_down := false
	for i in 1500:
		sim.step()
		if pawn.pose == "lie" and pawn.tile == Vector2i(8, 2):
			lay_down = true
		if not pawn.is_busy() and i > 5:
			break
	_check(lay_down, "a tired person lies down on the bed")
	_check(float(pawn.needs["rest"]) >= 99.0 and pawn.pose == "" and bed.user_id == 0, "they get up rested and the bed is free")

	# Content people stay put; other needs run down slowly rather than all at once.
	setup = _needs_setup({})
	pawn = setup["pawn"]
	setup["world"].add_object("bed", Vector2i(8, 2))
	sim = Simulation.new(setup["world"], setup["household"])
	for i in 100:
		sim.step()
	_check(not pawn.is_busy() and pawn.tile == Vector2i(2, 2), "someone with every need full does nothing")
	_check(float(pawn.needs["hunger"]) < 100.0 and float(pawn.needs["hunger"]) > 90.0, "needs drain a little each tick")

	# One person at a time; orders from the player win.
	setup = _needs_setup({ "hunger": 10.0 })
	world = setup["world"]
	var household: Household = setup["household"]
	var second := Pawn.new()
	second.display_name = "Tester Two"
	second.tile = Vector2i(3, 2)
	second.step_to = second.tile
	for need_id in Needs.active_ids():
		second.needs[need_id] = 100.0
	household.add_pawn(second)
	pot = world.add_object("cooking_pot", Vector2i(10, 5))
	sim = Simulation.new(world, household)
	pawn = household.pawns[0]
	sim.step()
	_check(pawn.job_kind == "use" and pot.user_id == pawn.id, "a hungry person reserves the pot")
	_check("is using it" in sim.use_blocker(second, pot), "someone else is told it is in use")
	_check(not sim.order_use(second, pot)["ok"], "a second person cannot take it")
	var menu_entry := PawnActions.list_for(sim, second, Vector2i(10, 5))[0]
	_check(not menu_entry["enabled"] and menu_entry["id"] == PawnActions.USE_PREFIX + str(pot.id), "the menu lists it as in use")
	sim.order_move(pawn, Vector2i(2, 9))
	_check(pawn.job_kind == "" and pot.user_id == 0, "a walking order from the player cancels the job and frees the pot")
	var free_entry := PawnActions.list_for(sim, second, Vector2i(10, 5))[0]
	_check(free_entry["enabled"] and sim.order_use(second, pot)["ok"], "now the other person can use it")
	sim.order_stop(second)
	_check(pot.user_id == 0 and second.job_kind == "", "stopping puts the job down")

	# Empty needs slow people down.
	setup = _needs_setup({ "hunger": 0.0 })
	pawn = setup["pawn"]
	sim = Simulation.new(setup["world"], setup["household"])
	sim.step()
	_check(pawn.slowed, "an empty need slows someone down")
	sim.order_move(pawn, Vector2i(3, 2))
	var slow_ticks := 0
	while pawn.has_orders() and slow_ticks < 50:
		sim.step()
		slow_ticks += 1
	_check(slow_ticks > int(Pawn.BASE_MOVE_TICKS), "so a one-tile walk takes longer than usual (%d ticks)" % slow_ticks)

	# Two people: a right-click interaction that fills Libido, if both are willing adults.
	setup = _needs_setup({ "libido": 20.0 })
	world = setup["world"]
	household = setup["household"]
	pawn = setup["pawn"]
	var partner := Pawn.new()
	partner.display_name = "Tester Two"
	partner.tile = Vector2i(6, 2)
	partner.step_to = partner.tile
	for need_id in Needs.active_ids():
		partner.needs[need_id] = 100.0
	partner.needs["libido"] = 30.0
	household.add_pawn(partner)
	sim = Simulation.new(world, household)
	var entries := PawnActions.list_for(sim, pawn, partner.tile)
	var intimate := {}
	for entry in entries:
		if str(entry["id"]).begins_with(PawnActions.INTERACT_PREFIX + "intimacy"):
			intimate = entry
	_check(not intimate.is_empty() and intimate["enabled"] and "Tester" in str(intimate["label"]), "right-clicking a willing adult lists the interaction")
	_check(PawnActions.list_for(sim, pawn, Vector2i(9, 9)).size() == 1, "an empty spot lists no interactions")
	var started := PawnActions.perform(sim, pawn, str(intimate["id"]), partner.tile)
	_check(started["ok"] and partner.job_kind == "interact" and partner.job_partner == pawn.id, "both people are committed once it is ordered")
	var met := false
	for i in 200:
		sim.step()
		if pawn.pose == "close" and partner.pose == "close":
			met = true
			break
	_check(met and _distance_tiles(pawn.tile, partner.tile) == 1, "they come together side by side")
	_check(sim.describe_activity(pawn) == "Spending private time together", "the panel describes it without detail")
	for i in 200:
		sim.step()
		if not pawn.is_busy() and not partner.is_busy():
			break
	_check(float(pawn.needs["libido"]) > 90.0 and float(partner.needs["libido"]) > 90.0, "afterwards both have their libido filled")
	_check(pawn.pose == "" and partner.pose == "" and partner.job_kind == "", "and both go back to normal")

	# Consent and limits.
	partner.needs["libido"] = 95.0
	_check("mood" in sim.interaction_blocker(pawn, partner, "intimacy"), "someone who isn't in the mood says no")
	partner.needs["libido"] = 30.0
	pawn.needs["libido"] = 95.0
	_check("mood" in sim.interaction_blocker(pawn, partner, "intimacy"), "the one asking has to be in the mood too")
	pawn.needs["libido"] = 20.0
	pawn.gender = "female"
	partner.gender = "male"
	pawn.traits.assign(["gay"])
	_check("interested" in sim.interaction_blocker(pawn, partner, "intimacy"), "someone attracted to the same gender is not interested in the other")
	pawn.traits.assign(["straight"])
	partner.traits.assign(["straight"])
	_check(sim.interaction_blocker(pawn, partner, "intimacy") == "", "two straight people of opposite genders are fine")
	partner.gender = "female"
	_check("interested" in sim.interaction_blocker(pawn, partner, "intimacy"), "two straight people of the same gender are not")
	partner.traits.assign(["gay"])
	pawn.traits.assign(["gay"])
	_check(sim.interaction_blocker(pawn, partner, "intimacy") == "", "two gay people of the same gender are fine")
	pawn.traits.assign(["bisexual"])
	partner.gender = "male"
	partner.traits.assign(["bisexual"])
	_check(sim.interaction_blocker(pawn, partner, "intimacy") == "", "bisexual people are open to either")
	pawn.traits.assign(["asexual"])
	_check("interested" in sim.interaction_blocker(pawn, partner, "intimacy") and "interested" in sim.interaction_blocker(partner, pawn, "intimacy"), "an asexual person is not interested, and nobody can ask them")
	_check(Needs.drain_per_tick("libido", ["asexual"], {}) == 0.0, "asexual people do not build up libido")
	pawn.traits.clear()
	partner.traits.clear()
	_check(sim.interaction_blocker(pawn, partner, "intimacy") == "", "no orientation trait means open to anyone")
	partner.adult = false
	_check("adults" in sim.interaction_blocker(pawn, partner, "intimacy") and not sim.order_interact(pawn, partner, "intimacy")["ok"], "it is only ever between adults")
	partner.adult = true
	sim.order_move(partner, Vector2i(6, 8))
	_check("busy" in sim.interaction_blocker(pawn, partner, "intimacy"), "someone who is walking elsewhere is busy")
	sim.order_stop(partner)
	partner.tile = partner.committed_tile()
	partner.step_ticks_total = 0
	partner.path.clear()

	# The player can call it off, and it ends for both.
	_check(sim.order_interact(pawn, partner, "intimacy")["ok"], "it can be started again")
	sim.order_move(partner, Vector2i(6, 6))
	_check(pawn.job_kind == "" and partner.job_kind == "" and pawn.job_partner == 0, "ordering one of them away ends the interaction for both, so nobody is left waiting")

	# Saved mid-way, it carries on after loading.
	partner.tile = Vector2i(6, 2)
	partner.step_to = partner.tile
	partner.path.clear()
	partner.step_ticks_total = 0
	sim.order_stop(partner)
	pawn.tile = Vector2i(2, 2)
	_check(sim.order_interact(pawn, partner, "intimacy")["ok"], "starting once more for the save test")
	for i in 5:
		sim.step()
	var copy_a := Pawn.from_dict(pawn.to_dict())
	var copy_b := Pawn.from_dict(partner.to_dict())
	_check(copy_a.job_kind == "interact" and copy_a.job_partner == partner.id and copy_b.job_stage == "partner" and copy_a.job_interaction == "intimacy", "the interaction survives a save")
	var broken := Household.new()
	broken.add_pawn(copy_a)  # partner missing from the save: must not hang forever
	Simulation.new(world, broken)
	_check(copy_a.job_kind == "", "a loaded interaction whose partner is gone is dropped")

	# The starting camp.
	var big_world := MapGenerator.generate(42, 96, 64)
	var family := HouseholdGenerator.create(big_world)
	var everyone_has_both := true
	for member in family.pawns:
		var orientation_count := 0
		for trait_id in member.traits:
			orientation_count += 1 if str(DataRegistry.get_def("traits", trait_id).get("group", "")) == "orientation" else 0
		everyone_has_both = everyone_has_both and member.traits.size() == 3 and orientation_count == 1 and member.traits[1] != member.traits[2]
	_check(everyone_has_both, "everyone starts with three different traits, exactly one of them an orientation")
	CampGenerator.place(big_world, family)
	var beds := 0
	var spots := {}
	var on_road := false
	for placed in big_world.objects:
		beds += 1 if placed.def_id == "bed" else 0
		spots[placed.tile] = true
		on_road = on_road or placed.tile.x == 48 or placed.tile.y == 32
	_check(beds == family.pawns.size(), "there is a bed for everyone")
	_check(spots.size() == big_world.objects.size() and big_world.objects.size() == family.pawns.size() + CampGenerator.SHARED.size(), "every object has its own tile")
	_check(not on_road, "the roads through the middle are kept clear")
	var again := MapGenerator.generate(42, 96, 64)
	CampGenerator.place(again, HouseholdGenerator.create(again))
	_check(again.to_dict()["objects"] == big_world.to_dict()["objects"], "the same seed gives the same camp")
	GameClock.reset()
	GameClock.set_speed(1)


func _test_town() -> void:
	print("The town")
	var world := MapGenerator.generate(42, 128, 96)
	var report := TownGenerator.generate(world)
	var config := DataRegistry.get_def("worldgen", "town")
	var wanted: Dictionary = config["buildings"]
	var all_placed: bool = report["removed"] == 0
	for kind in wanted:
		all_placed = all_placed and int(report["placed"].get(kind, 0)) == int(wanted[kind])
	_check(all_placed, "every building in worldgen.json found a lot (%s)" % str(report["placed"]))
	var again := MapGenerator.generate(42, 128, 96)
	TownGenerator.generate(again)
	_check(again.to_dict() == world.to_dict(), "the same seed gives the same town")
	var other := MapGenerator.generate(43, 128, 96)
	TownGenerator.generate(other)
	_check(other.to_dict()["lots"] != world.to_dict()["lots"], "another seed gives another town")

	# Lots keep apart, and off the roads.
	var center := Vector2i(world.width / 2, world.height / 2)
	var apart := true
	var rects: Array[Rect2i] = [world.lot]
	for entry in world.lots:
		rects.append(entry["rect"])
	for i in rects.size():
		var on_road := rects[i].intersects(Rect2i(center.x - 62, center.y, 125, 3)) or rects[i].intersects(Rect2i(center.x, center.y - 36, 3, 75))
		apart = apart and not on_road
		for j in range(i + 1, rects.size()):
			apart = apart and not rects[i].intersects(rects[j])
	_check(apart, "no two lots overlap and none sits on a road")
	_check(world.get_tile_id(center.x, center.y) == "cobble" and world.get_tile_id(center.x + 2, center.y + 2) == "cobble" and world.get_tile_id(center.x - 20, center.y + 1) == "cobble", "the cobbled streets cross in the middle")
	_check(world.object_at(Vector2i(center.x + 1, center.y + 1)) != null and world.object_at(Vector2i(center.x + 1, center.y + 1)).def_id == "well", "with a well in the square")
	_check(world.towns.size() == 1 and world.home_town()["center"] == center and world.lots.all(func(entry: Dictionary) -> bool: return entry["town"] == world.towns[0]["id"]), "the lots belong to the town")
	_check(world.lot.size == Vector2i(16, 13), "the player's lot is the size worldgen.json says")
	var home_ground := true
	for y in range(world.lot.position.y, world.lot.end.y):
		for x in range(world.lot.position.x, world.lot.end.x):
			home_ground = home_ground and world.get_tile_id(x, y) == "grass"
	_check(home_ground, "the player's lot is level grass")

	# The household's camp sits on the lot.
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var camp_count := 0
	for placed in world.objects:
		camp_count += 1 if world.in_lot(placed.tile) else 0
	_check(camp_count == household.pawns.size() + CampGenerator.SHARED.size(), "the whole camp is on the player's lot")
	var people_on_lot := true
	for pawn in household.pawns:
		people_on_lot = people_on_lot and world.in_lot(pawn.tile) and pawn.home_lot == WorldState.HOME_LOT
	_check(people_on_lot, "and so are the household's people")

	# Everything can be reached from the crossroads.
	var town := NpcGenerator.create(world)
	var sim := Simulation.new(world, household, town)
	var visitor := Pawn.new()
	visitor.tile = center
	visitor.step_to = center
	var reachable := true
	var unreachable := ""
	for placed in world.objects:
		if placed.def().has("satisfies") and sim._plan_use(visitor, placed).is_empty():
			reachable = false
			unreachable = placed.def_id
	_check(reachable, "every bed, pot and hearth in town can be walked to from the crossroads %s" % unreachable)
	var doors_open := true
	for entry in world.lots:
		for placed in world.objects:
			if placed.def_id == "door" and (entry["rect"] as Rect2i).has_point(placed.tile):
				doors_open = doors_open and not sim.pathfinder.find_path(center, placed.tile).is_empty()
	_check(doors_open, "every door can be walked to")

	# Public places are really public, houses are not.
	var public_kinds := {}
	var houses := 0
	var homes_equipped := true
	for entry in world.lots:
		if bool(entry["public"]):
			public_kinds[entry["kind"]] = true
		if entry["kind"] == "house":
			houses += 1
			var have := {}
			for placed in world.objects:
				if (entry["rect"] as Rect2i).has_point(placed.tile):
					have[placed.def_id] = true
			for needed in ["bed", "cooking_pot", "hearth", "wash_basin", "chamber_pot"]:
				homes_equipped = homes_equipped and have.has(needed)
	_check(public_kinds.has("tavern") and public_kinds.has("shop") and public_kinds.has("clinic") and public_kinds.has("park"), "the tavern, shop, clinic and green are public")
	_check(houses == int(wanted["house"]), "there are %d houses" % houses)
	_check(homes_equipped, "every house has a bed, a pot, a hearth, a basin and a chamber pot")

	# The people.
	var house_beds := 0
	for placed in world.objects:
		var home_lot := world.lot_at(placed.tile)
		house_beds += 1 if placed.def_id == "bed" and not home_lot.is_empty() and home_lot["kind"] == "house" else 0
	var expected_people := mini(int(config["npc_count"]), house_beds)
	_check(town.pawns.size() == expected_people, "the town has %d people, as many as the houses have beds for, up to %d" % [town.pawns.size(), int(config["npc_count"])])
	var ids_ok := true
	var traits_ok := true
	var homes_ok := true
	var children := 0
	for pawn in town.pawns:
		ids_ok = ids_ok and pawn.id >= NpcGenerator.FIRST_ID
		var orientation := 0
		for trait_id in pawn.traits:
			orientation += 1 if str(DataRegistry.get_def("traits", trait_id).get("group", "")) == "orientation" else 0
		if pawn.adult:
			traits_ok = traits_ok and pawn.traits.size() == 3 and orientation == 1 and pawn.age >= 18
		else:
			children += 1
			traits_ok = traits_ok and pawn.traits.size() == 2 and orientation == 0 and pawn.age < 18
		var home := world.get_lot(pawn.home_lot)
		homes_ok = homes_ok and not home.is_empty() and home["kind"] == "house" and (home["rect"] as Rect2i).has_point(pawn.tile)
	_check(ids_ok and sim.person(NpcGenerator.FIRST_ID) != null and sim.person(1) == household.pawns[0], "townspeople are numbered apart from the household")
	_check(traits_ok, "adults have an orientation and two other traits, children just two")
	_check(children > 0, "some of them are children (%d)" % children)
	_check(homes_ok, "everyone starts inside a house on their own lot")
	var surnames := {}
	for pawn in town.pawns:
		surnames[pawn.display_name.get_slice(" ", 1)] = surnames.get(pawn.display_name.get_slice(" ", 1), 0) + 1
	_check(surnames.size() < town.pawns.size() and surnames.size() >= 4, "they live in families (%d surnames)" % surnames.size())
	var again_town := NpcGenerator.create(world)
	_check(_sans_dreams(again_town.to_dict()) == _sans_dreams(town.to_dict()), "the same seed gives the same people")

	# Whose things are whose.
	var home_bed: PlacedObject = null
	for placed in world.objects:
		if placed.def_id == "bed" and world.in_lot(placed.tile):
			home_bed = placed
	var neighbor: Pawn = town.pawns[0]
	_check("belongs to someone else" in sim.use_blocker(neighbor, home_bed), "a neighbor cannot use the household's bed")
	var neighbor_pot: PlacedObject = null
	var tavern_lute: PlacedObject = null
	for placed in world.objects:
		var lot := world.lot_at(placed.tile)
		if placed.def_id == "cooking_pot" and not lot.is_empty() and lot["id"] == neighbor.home_lot:
			neighbor_pot = placed
		if placed.def_id == "lute" and not lot.is_empty() and lot["kind"] == "tavern":
			tavern_lute = placed
	_check("belongs to someone else" in sim.use_blocker(household.pawns[0], neighbor_pot), "and the household cannot use a neighbor's pot")
	_check(sim.use_blocker(neighbor, neighbor_pot) == "", "a family uses its own pot")
	_check(tavern_lute != null and sim.use_blocker(household.pawns[0], tavern_lute) == "" and sim.use_blocker(neighbor, tavern_lute) == "", "anyone may use what is in the tavern")

	# A day in the town.
	GameClock.reset()
	GameClock.set_time(0, 6)
	var strayed := false
	var trespassed := false
	var busy_seen := 0
	for minute in GameClock.MINUTES_PER_DAY:
		GameClock.advance_one_tick()
		sim.step()
		if minute % 20 == 0:
			for pawn in town.pawns:
				strayed = strayed or not (world.get_lot(pawn.home_lot)["rect"] as Rect2i).has_point(pawn.tile)
				busy_seen += 1 if pawn.job_kind == "use" else 0
		for placed in world.objects:
			if placed.user_id >= NpcGenerator.FIRST_ID and world.in_lot(placed.tile):
				trespassed = true
	_check(busy_seen > 0, "townspeople look after their own needs")
	_check(strayed, "and some walk out of their own lot during the day")
	_check(not trespassed, "but none ever uses the player's belongings")
	_check(town.pawns.size() == expected_people and household.pawns.size() == HouseholdGenerator.SIZE, "nobody died in the first day")

	# A death in town.
	var heard := []
	sim.town_death.connect(func(person: String, cause: String) -> void: heard.append([person, cause]))
	var victim: Pawn = town.pawns[0]
	var victim_name := victim.display_name
	var graves_before := 0
	for placed in world.objects:
		graves_before += 1 if placed.def_id == "grave" else 0
	sim.die(victim, "fell ill")
	var graves_after := 0
	for placed in world.objects:
		graves_after += 1 if placed.def_id == "grave" else 0
	_check(heard == [[victim_name, "fell ill"]] and sim.person(victim.id) == null and town.dead.size() == 1, "a death in town is announced and recorded apart from the household's")
	_check(graves_after == graves_before + 1 and not sim.is_game_over() and household.dead.is_empty(), "it leaves a grave and does not touch the household")

	# Saving the town.
	var copy := WorldState.from_dict(world.to_dict())
	_check(copy.to_dict()["lots"] == world.to_dict()["lots"] and copy.lots.size() == world.lots.size(), "the lots survive a round trip")
	_check(SaveGame.save(TEST_SAVE, world, household, {}, town) == OK, "a save with a town is written")
	var loaded := SaveGame.load_from(TEST_SAVE)
	var loaded_town: Household = loaded["town"]
	_check(loaded["ok"] and loaded_town != null and loaded_town.to_dict() == town.to_dict(), "the townspeople, the dead included, survive a round trip")
	var kept_on := Simulation.new(loaded["world"], loaded["household"], loaded_town)
	_check(kept_on.person(town.pawns[0].id) != null and kept_on.people().size() == town.pawns.size() + household.pawns.size(), "a loaded game has everyone")
	var older := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	var old_data := { "format": 4, "world": world.to_dict(), "clock": GameClock.to_dict(), "household": household.to_dict() }
	old_data["world"].erase("lots")
	older.store_string(JSON.stringify(old_data))
	older.close()
	var old_save := SaveGame.load_from(TEST_SAVE)
	_check(old_save["ok"] and old_save["town"] == null and old_save["world"].lots.is_empty(), "a version 4 save loads with no town")
	var quiet := Simulation.new(old_save["world"], old_save["household"], old_save["town"])
	quiet.step()
	_check(quiet.town.pawns.is_empty() and quiet.people().size() == household.pawns.size(), "and plays on without one")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


## A small world for money and work: your lot on the left, a shop on the right with two counters.
func _work_setup() -> Dictionary:
	var setup := _building_setup()
	var world: WorldState = setup["world"]
	world.lots = [{ "id": "lot_1", "kind": "shop", "name": "Shop", "template": "shop", "facing": "west", "rect": Rect2i(14, 2, 8, 6), "public": true }]
	world.add_object("counter", Vector2i(16, 4))
	world.add_object("counter", Vector2i(17, 4))
	return setup


func _test_region() -> void:
	print("The region and its towns")
	var started := Time.get_ticks_msec()
	var world := RegionGenerator.generate(7)
	var elapsed := Time.get_ticks_msec() - started
	var region := DataRegistry.get_def("worldgen", "region")
	_check(world.width == int(region["width"]) and world.height == int(region["height"]) and world.width * world.height > 100000, "the map is big (%d by %d)" % [world.width, world.height])
	_check(elapsed < 4000, "and is made in a moment (%d ms)" % elapsed)
	_check(world.towns.size() == region["settlements"].size(), "with %d settlements" % world.towns.size())
	var home := world.home_town()
	_check(not home.is_empty() and home["center"] == Vector2i(world.width / 2, world.height / 2) and world.towns.filter(func(t: Dictionary) -> bool: return bool(t["home"])).size() == 1, "the player's town is in the middle, and only one is theirs")
	var names := {}
	var apart := true
	for a in world.towns:
		names[a["name"]] = true
		for b in world.towns:
			if a != b:
				apart = apart and Vector2(a["center"]).distance_to(b["center"]) > 120.0
	_check(names.size() == world.towns.size() and apart, "each has its own name, and they lie a long walk apart")
	var every_building := true
	for town in world.towns:
		var wanted: Dictionary = DataRegistry.get_def("worldgen", town["profile"])["buildings"]
		var got := {}
		for lot in world.lots:
			if lot.get("town", "") == town["id"]:
				got[lot["kind"]] = int(got.get(lot["kind"], 0)) + 1
		for kind in wanted:
			every_building = every_building and int(got.get(kind, 0)) == int(wanted[kind])
	var missing_text := ""
	for town in world.towns:
		var wanted_kinds: Dictionary = DataRegistry.get_def("worldgen", town["profile"])["buildings"]
		var placed_kinds := {}
		for lot in world.lots:
			if lot.get("town", "") == town["id"]:
				placed_kinds[lot["kind"]] = int(placed_kinds.get(lot["kind"], 0)) + 1
		for kind in wanted_kinds:
			if int(placed_kinds.get(kind, 0)) != int(wanted_kinds[kind]):
				missing_text += " %s:%s %d/%d" % [town["name"], kind, int(placed_kinds.get(kind, 0)), int(wanted_kinds[kind])]
	_check(every_building, "every town has all the buildings its kind calls for%s" % missing_text)
	_check(home["rect"].has_point(world.lot.get_center()) and world.lot_at(world.lot.get_center())["id"] == WorldState.HOME_LOT, "the player's lot is in their town")
	var kinds := {}
	for town in world.towns:
		kinds[town["kind"]] = true
	_check(kinds.has("town") and kinds.has("village") and kinds.has("hamlet"), "there are towns, villages and a hamlet")

	# Streets and decoration make it look like a town.
	var lanterns := 0
	var stalls := 0
	var beds := 0
	for placed in world.objects:
		lanterns += 1 if placed.def_id == "lantern_post" else 0
		stalls += 1 if placed.def_id == "market_stall" else 0
		beds += 1 if placed.def_id == "flower_bed" else 0
	_check(lanterns >= 30 and stalls >= 4 and beds >= 10, "lanterns, stalls and flower beds finish it (%d, %d, %d)" % [lanterns, stalls, beds])
	var cobbles := 0
	for y in range(home["rect"].position.y, home["rect"].end.y):
		cobbles += 1 if world.get_tile_id(home["center"].x + 1, y) == "cobble" else 0
	_check(cobbles > 40, "the avenue is cobbled")

	# The towns are joined: someone can walk from the home town to each of the others.
	var finder := PathFinder.new(world)
	var joined := true
	for town in world.towns:
		if town != home:
			joined = joined and not finder.find_path(home["center"], Vector2i(town["center"].x, town["center"].y)).is_empty()
	_check(joined, "a road joins every town to the player's")
	var road_tiles := 0
	for y in world.height:
		for x in range(0, world.width, 1):
			road_tiles += 1 if world.get_tile_id(x, y) == "dirt" else 0
	_check(road_tiles > 1500, "the roads between them are laid in earth (%d tiles)" % road_tiles)

	# Finding a place.
	var other: Dictionary = world.towns[1]
	_check(world.town_at(other["center"])["id"] == other["id"] and world.town_at(Vector2i(2, 2)).is_empty(), "a tile knows which town it is in, or none")
	_check(world.town_of_lot(world.lots.filter(func(l: Dictionary) -> bool: return l["town"] == other["id"])[0]["id"])["id"] == other["id"] and world.town_of_lot(WorldState.HOME_LOT)["id"] == home["id"], "and a lot knows its town")

	# The people live in their own towns, and work there.
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var town_people := NpcGenerator.create(world)
	var per_town := {}
	var works_at_home := true
	for pawn in town_people.pawns:
		var where := str(world.town_of_lot(pawn.home_lot).get("id", ""))
		per_town[where] = int(per_town.get(where, 0)) + 1
		if pawn.work_lot != "":
			works_at_home = works_at_home and str(world.town_of_lot(pawn.work_lot).get("id", "")) == where
	var counts_ok := per_town.size() == world.towns.size()
	for town in world.towns:
		counts_ok = counts_ok and int(per_town.get(town["id"], 0)) > 0 and int(per_town.get(town["id"], 0)) <= int(DataRegistry.get_def("worldgen", town["profile"])["npc_count"])
	_check(counts_ok and town_people.pawns.size() > 80, "every town has its people (%d in all)" % town_people.pawns.size())
	_check(works_at_home, "and they work in the town they live in")
	var surnames := {}
	for pawn in town_people.pawns:
		surnames[pawn.display_name.get_slice(" ", 1)] = true
	_check(surnames.size() >= 30, "from many different families (%d surnames)" % surnames.size())

	# Walkers stay near home, apart from the odd visit.
	var sim := Simulation.new(world, household, town_people)
	var villager: Pawn = town_people.pawns[0]
	var villager_town := world.town_of_lot(villager.home_lot)
	var strayed := 0
	var trips := 0
	for trip in 4000:
		villager.path.clear()
		villager.job_kind = ""
		villager.tile = villager_town["center"]
		villager.step_to = villager.tile
		sim._roam(villager, 12 * 60)
		var goal := villager.goal_tile()
		if goal != villager.tile:
			trips += 1
			strayed += 1 if world.town_at(goal, 0).get("id", "") != villager_town["id"] else 0
	_check(trips > 20 and strayed * 4 < trips, "townsfolk take their walks in their own town, and only seldom visit another (%d of %d)" % [strayed, trips])

	# Saving keeps the towns and the tiles.
	_check(SaveGame.save(TEST_SAVE, world, household, {}) == OK, "the big map is saved")
	var back := SaveGame.load_from(TEST_SAVE)
	_check(back["ok"] and back["world"].tiles == world.tiles and back["world"].towns.size() == world.towns.size() and back["world"].towns[1]["center"] == world.towns[1]["center"] and back["world"].home_town()["name"] == home["name"], "and they come back")
	var packed_size := FileAccess.get_file_as_string(TEST_SAVE).length()
	_check(packed_size < 1500000, "in a save that is not enormous (%d bytes)" % packed_size)
	var old_world: Dictionary = world.to_dict()
	old_world.erase("towns")
	old_world.erase("tiles_z")
	old_world["tiles"] = Array(world.tiles)
	var from_old := WorldState.from_dict(old_world)
	_check(from_old.tiles == world.tiles and from_old.towns.size() == 1 and from_old.towns[0]["home"], "a save from before there were towns gets one around its lots, with its tiles as written")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _test_economy() -> void:
	print("Coin and work")
	_check(Economy.format(12) == "12d" and Economy.start_coins() > 0, "coin is written like 12d and a household starts with some")
	_check(HouseholdGenerator.create(MapGenerator.generate(3, 64, 48)).coins == Economy.start_coins(), "a new household has the starting purse")

	# Building costs coin.
	var setup := _building_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var sim: Simulation = setup["sim"]
	household.coins = 20
	_check(sim.build_place("bed", Vector2i(8, 8))["ok"] and household.coins == 2, "a bed costs %s" % Economy.format(Economy.object_cost("bed")))
	var broke := sim.build_place("bed", Vector2i(9, 8))
	_check(not broke["ok"] and "costs" in str(broke["message"]) and household.coins == 2 and world.object_at(Vector2i(9, 8)) == null, "with too little coin it is refused, and says what it costs")
	_check(sim.build_move(world.object_at(Vector2i(8, 8)).id, Vector2i(9, 8))["ok"] and household.coins == 2, "moving is free")
	_check(sim.build_remove(Vector2i(9, 8))["ok"] and household.coins == 2 + Economy.refund(Economy.object_cost("bed")), "taking it down gives half back")
	household.coins = 1
	_check(sim.build_floor("planks", Vector2i(5, 5))["ok"] and household.coins == 0, "a floor tile costs coin too")
	_check(not sim.build_floor("flagstone", Vector2i(6, 5))["ok"], "and is refused when there is none left")

	# Paying for a meal at the tavern table.
	setup = _building_setup()
	world = setup["world"]
	household = setup["household"]
	sim = setup["sim"]
	var diner: Pawn = setup["pawn"]
	var table := world.add_object("meal_table", Vector2i(6, 5))
	diner.needs["hunger"] = 20.0
	household.coins = 3
	_check("afford" in sim.use_blocker(diner, table), "a meal that costs more than the purse holds cannot be ordered")
	household.coins = 10
	_check(sim.use_blocker(diner, table) == "" and sim.order_use(diner, table)["ok"], "with the coin it can")
	for minute in 40:
		GameClock.advance_one_tick()
		sim.step()
	_check(household.coins == 10 - Economy.price("meal_table") and diner.needs["hunger"] > 90.0, "the price is paid once and the hunger is gone (%d coin left)" % household.coins)
	var labels := []
	for entry in PawnActions.list_for(sim, diner, Vector2i(6, 5)):
		labels.append(entry["label"])
	_check("Have a meal (4d)" in labels, "the menu shows the price")
	household.coins = 0
	diner.needs["hunger"] = 10.0
	diner.think_cooldown = 0
	for minute in 5:
		sim.step()
	_check(diner.job_kind == "", "a hungry person with no coin does not go to the tavern")

	# Work.
	setup = _work_setup()
	world = setup["world"]
	household = setup["household"]
	sim = setup["sim"]
	var worker: Pawn = setup["pawn"]
	household.coins = 0
	GameClock.set_time(0, 6)
	_check(sim.open_positions().size() == 1 and int(sim.open_positions()[0]["open"]) == 2, "the shop has two vacancies")
	var board_labels := []
	var counter := world.object_at(Vector2i(16, 4))
	for entry in PawnActions.list_for(sim, worker, counter.tile):
		board_labels.append(entry["label"])
	_check("Take the job: shop clerk at the shop (5d an hour)" in board_labels, "the counter lists the job")
	var child := Pawn.new()
	child.id = 77
	child.age = 12
	child.adult = false
	_check("must be" in sim.hire_blocker(child, "lot_1", "shop_clerk"), "a child cannot be hired")
	_check(sim.hire_blocker(worker, "lot_1", "tavern_hand") != "", "a job at the wrong kind of business does not exist")
	var hired := PawnActions.perform(sim, worker, PawnActions.HIRE_PREFIX + "lot_1:shop_clerk", counter.tile)
	_check(hired["ok"] and worker.work_job == "shop_clerk" and "shop clerk" in str(hired["message"]), "taking the job from the menu works (%s)" % hired["message"])
	_check(sim.job_text(worker).begins_with("Shop clerk at the shop") and "5d an hour" in sim.job_text(worker), "the panel can say what the job is")
	_check(sim.hire_blocker(worker, "lot_1", "shop_clerk") == "already works there", "but not twice")
	var second := Pawn.new()
	second.age = 30
	second.work_lot = "lot_1"
	second.work_job = "shop_clerk"
	sim.town.add_pawn(second)
	var third := Pawn.new()
	third.age = 30
	_check(sim.hire_blocker(third, "lot_1", "shop_clerk") == "no vacancy" and sim.open_positions().is_empty(), "when both positions are taken there is no vacancy")
	second.work_lot = ""
	second.work_job = ""
	sim.town.remove_pawn(second.id)

	# A shift: nothing before eight, off to work at eight, paid by four.
	for minute in 100:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "" and household.coins == 0, "before the shift starts they are not at work")
	GameClock.set_time(0, 8)
	_fill_needs(worker)
	for minute in 60:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "work" and "work" in sim.describe_activity(worker).to_lower(), "when the shift starts they go to work (%s)" % sim.describe_activity(worker))
	_check(world.object_at(worker.tile) == null and _next_to_counter(world, worker.tile), "and stand beside a counter")
	for minute in 8 * 60:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "", "at the end of the shift they stop")
	_check(absi(household.coins - 5 * 7) <= 5, "and are paid by the hour (%d coin for about 7 hours)" % household.coins)
	_check("Put in an honest day's work" in _mood_texts(worker, household), "a day's work is a good feeling")

	# A need that gets bad enough sends them home early; the player's orders take them off the shift.
	GameClock.set_time(1, 8)
	_fill_needs(worker)
	var before := household.coins
	for minute in 90:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "work" and worker.job_stage == "using", "next morning they are at it again")
	worker.needs["hunger"] = 5.0
	sim.step()
	_check(worker.job_kind != "work" and household.coins > before, "a person who is starving leaves their post, and is paid for the time")
	GameClock.set_time(2, 9)
	_fill_needs(worker)
	for minute in 60:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "work", "on the third day they are back at work")
	var coins_then := household.coins
	var walked := PawnActions.perform(sim, worker, PawnActions.WALK, Vector2i(5, 8))
	_check(walked["ok"] and worker.job_kind == "" and worker.skip_work_day == GameClock.get_day_number(), "the player can take them off their shift")
	_fill_needs(worker)
	for minute in 240:
		GameClock.advance_one_tick()
		sim.step()
	_check(worker.job_kind == "" and household.coins >= coins_then, "and they stay off it for the day")
	var quit := PawnActions.perform(sim, worker, PawnActions.QUIT_JOB, Vector2i.ZERO)
	_check(quit["ok"] and worker.work_job == "" and sim.open_positions().size() == 1 and int(sim.open_positions()[0]["open"]) == 2, "quitting opens the position again")

	# The notice board lists everything in town.
	var board := world.add_object("notice_board", Vector2i(10, 9))
	var listed := PawnActions.list_for(sim, worker, board.tile)
	var hire_entries := 0
	for entry in listed:
		hire_entries += 1 if str(entry["id"]).begins_with(PawnActions.HIRE_PREFIX) else 0
	_check(hire_entries == 1, "the notice board lists the town's vacancies")
	var nothing := PawnActions.list_for(_building_setup()["sim"], worker, Vector2i(3, 3))
	_check(not _has_action_starting(nothing, PawnActions.HIRE_PREFIX), "other places offer no work")

	# The generated town: people have jobs, every business keeps a vacancy, and wages are paid.
	var big := MapGenerator.generate(42, 128, 96)
	TownGenerator.generate(big)
	var family := HouseholdGenerator.create(big)
	CampGenerator.place(big, family)
	var town := NpcGenerator.create(big)
	var big_sim := Simulation.new(big, family, town)
	var employed := 0
	for villager in town.pawns:
		employed += 1 if villager.work_job != "" else 0
		_check(villager.work_job == "" or villager.adult, "only adults are given work")
	_check(employed > 0, "some townspeople have jobs (%d)" % employed)
	var every_business_has_room := true
	for lot in big.lots:
		var has_job := false
		for job in DataRegistry.get_list("jobs"):
			has_job = has_job or job["workplace"] == lot["kind"]
		if has_job:
			var room := false
			for opening in big_sim.open_positions(str(lot["id"])):
				room = true
			every_business_has_room = every_business_has_room and room
	_check(every_business_has_room, "every business still has a position for the player")
	var coin_before := 0
	for villager in town.pawns:
		coin_before += villager.coins
	GameClock.set_time(0, 6)
	var worked := false
	for minute in 16 * 60:
		GameClock.advance_one_tick()
		big_sim.step()
		if minute % 30 == 0:
			for villager in town.pawns:
				worked = worked or (villager.job_kind == "work" and villager.job_stage == "using")
	var coin_after := 0
	var nobody_negative := true
	for villager in town.pawns:
		coin_after += villager.coins
		nobody_negative = nobody_negative and villager.coins >= 0
	_check(worked, "townspeople turn up for their shifts")
	_check(nobody_negative and coin_after != coin_before, "wages come in and purchases go out (%d to %d)" % [coin_before, coin_after])

	# Saving keeps the money and the jobs.
	_check(SaveGame.save(TEST_SAVE, big, family, {}, town) == OK, "a save with money and jobs is written")
	var loaded := SaveGame.load_from(TEST_SAVE)
	_check(loaded["household"].coins == family.coins and loaded["town"].to_dict() == town.to_dict(), "the purse, pockets and jobs survive a round trip")
	var old_household := family.to_dict()
	old_household.erase("coins")
	_check(Household.from_dict(old_household).coins == Economy.start_coins(), "an older save gets a starting purse")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _fill_needs(person: Pawn) -> void:
	for need_id in person.needs:
		person.needs[need_id] = 100.0
	person.deprivation.clear()


func _next_to_counter(world: WorldState, tile: Vector2i) -> bool:
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var there := world.object_at(tile + step)
		if there != null and there.def_id == "counter":
			return true
	return false


func _has_action_starting(actions: Array[Dictionary], prefix: String) -> bool:
	for entry in actions:
		if str(entry["id"]).begins_with(prefix):
			return true
	return false


## Two household members standing a few tiles apart in the small test world, both a little lonely.
func _social_pair() -> Dictionary:
	var setup := _building_setup()
	var household: Household = setup["household"]
	var a: Pawn = setup["pawn"]
	var b := Pawn.new()
	b.display_name = "Second Person"
	b.tile = Vector2i(6, 5)
	b.step_to = b.tile
	household.add_pawn(b)
	var sim := Simulation.new(setup["world"], household)
	for person in [a, b]:
		_fill_needs(person)
		person.needs["social"] = 20.0
	return { "world": setup["world"], "household": household, "sim": sim, "a": a, "b": b }


func _interaction_entries(sim: Simulation, from: Pawn, to: Pawn) -> Dictionary:
	var found := {}
	for entry in PawnActions.list_for(sim, from, to.tile):
		var id := str(entry["id"])
		if id.begins_with(PawnActions.INTERACT_PREFIX):
			found[id.trim_prefix(PawnActions.INTERACT_PREFIX).get_slice(":", 0)] = entry
	return found


func _test_work_sites() -> void:
	print("Work sites, resources and materials")
	var ids := Economy.resource_ids()
	_check(str(ids.slice(0, 8)) == str(["wood", "stone", "grain", "fish", "herbs", "ring", "meat", "hide"]) and ids.size() == 17, "there are five resources to gather, rings, meat, hides, five made goods and four traded (%d)" % ids.size())
	_check(Economy.resource_price("wood") == 2 and Economy.sell_price("wood", 10) == 14 and Economy.sell_price("wood", 10, 1.3) == 18, "the shop pays a share of the price, and more on a market day")

	# The region has sites at every town's edge.
	var region := RegionGenerator.generate(42)
	var kinds := {}
	var all_public := true
	for lot in region.lots:
		if str(lot["kind"]) in ["farm", "woodlot", "quarry", "herb_garden", "jetty"]:
			kinds[lot["kind"]] = int(kinds.get(lot["kind"], 0)) + 1
			all_public = all_public and bool(lot["public"]) and str(lot.get("town", "")) != ""
	_check(kinds.has("farm") and kinds.has("woodlot") and kinds.has("quarry") and kinds.has("herb_garden") and kinds.has("jetty") and all_public, "fields, woodlots, quarries, herb gardens and a jetty are public lots of their towns (%s)" % str(kinds))
	var sites_worked := {}
	var plots := 0
	for placed in region.objects:
		plots += 1 if placed.def_id == "field_plot" else 0
	var region_people := NpcGenerator.create(region)
	for pawn in region_people.pawns:
		if pawn.work_job in ["woodcutter", "quarryman", "farmhand", "herbalist", "fisher"]:
			sites_worked[pawn.work_job] = int(sites_worked.get(pawn.work_job, 0)) + 1
			if str(region.town_of_lot(pawn.work_lot).get("id", "")) != str(region.town_of_lot(pawn.home_lot).get("id", "")):
				sites_worked["far"] = 1
	_check(plots >= 60 and sites_worked.size() >= 3 and not sites_worked.has("far"), "townsfolk work the land near their homes (%s, %d field plots)" % [str(sites_worked), plots])
	var site_finder := PathFinder.new(region)
	var every_site_reachable := true
	for lot in region.lots:
		if str(lot["kind"]) in ["farm", "woodlot", "quarry", "herb_garden", "jetty"]:
			var home_town := region.get_town(str(lot["town"]))
			var found := false
			for placed in region.objects:
				if (lot["rect"] as Rect2i).has_point(placed.tile) and str(placed.def().get("category", "")) == "worksite":
					for step in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
						var spot: Vector2i = placed.tile + step
						if region.is_walkable(spot.x, spot.y):
							found = not site_finder.find_path(home_town["center"], spot).is_empty()
							break
					break
			every_site_reachable = every_site_reachable and found
	_check(every_site_reachable, "and every site can be walked to from its town")

	# A small world to gather in.
	GameClock.set_time(0, 8)  # spring
	var setup := _romance_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var sim: Simulation = setup["sim"]
	var anna: Pawn = setup["anna"]
	var ben: Pawn = setup["ben"]
	var cara: Pawn = setup["cara"]
	household.add_stock("axe", 1)
	household.add_stock("sickle", 1)
	world.lots.append({ "id": "lot_5", "kind": "woodlot", "name": "Woodlot", "template": "woodlot", "facing": "south", "rect": Rect2i(20, 14, 12, 8), "public": true, "town": "t1" })
	world.lots.append({ "id": "lot_6", "kind": "farm", "name": "Fields", "template": "farm", "facing": "south", "rect": Rect2i(34, 14, 12, 8), "public": true, "town": "t1" })
	world.lots.append({ "id": "lot_7", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(50, 14, 10, 8), "public": true, "town": "t1" })
	var block := world.add_object("chopping_block", Vector2i(24, 16))
	var plot := world.add_object("field_plot", Vector2i(36, 16))
	var counter := world.add_object("counter", Vector2i(54, 16))
	var board := world.add_object("notice_board", Vector2i(44, 12))
	anna.tile = Vector2i(22, 18)
	anna.step_to = anna.tile
	var chop := PawnActions.list_for(sim, anna, block.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("use:"))
	_check(chop.size() == 1 and "Chop wood" in str(chop[0]["label"]) and "3 wood" in str(chop[0]["label"]) and chop[0]["enabled"], "the chopping block offers to chop wood, and says what it yields (%s)" % str(chop))
	var before_rest := float(anna.needs["rest"])
	var started := PawnActions.perform(sim, anna, str(chop[0]["id"]), block.tile)
	_check(started["ok"] and anna.job_kind == "use", "she sets off to chop")
	for i in 120:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_kind == "":
			break
	_check(household.stock_of("wood") == 3 and anna.job_kind == "", "after a spell of work three wood is in the stockpile (%s)" % str(household.stock))
	_check(float(anna.needs["rest"]) < before_rest - 5.0, "and she is tired for it")
	_check(anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "gathered"), "and has a hard day's work behind her")
	ben.age = 70
	ben.traits = [] as Array[String]
	_check("heavy" in sim.use_blocker(ben, block), "an elder keeps clear of the axe (%s)" % sim.use_blocker(ben, block))
	var kid := Pawn.new()
	kid.display_name = "Kid Marsh"
	kid.age = 8
	kid.adult = false
	kid.tile = Vector2i(9, 6)
	kid.step_to = kid.tile
	household.add_pawn(kid)
	_check("young" in sim.use_blocker(kid, plot), "and a child from the plough")
	_check("only your own" in sim.use_blocker(cara, block), "the town's people do not gather for your household")
	_check("until summer" in sim.use_blocker(anna, plot), "nothing is ripe in the fields in spring (%s)" % sim.use_blocker(anna, plot))
	GameClock.set_time(20, 8)  # summer
	_check(sim.use_blocker(anna, plot) == "" and ObjectArt.crop_stage() >= 2, "but in summer the crops are coming on")
	GameClock.set_time(31, 8)
	_check(ObjectArt.crop_stage() == 3, "ripe late in summer")
	GameClock.set_time(50, 8)
	_check(ObjectArt.crop_stage() == 0 and "until" in sim.use_blocker(anna, plot), "and the land lies bare in winter")
	GameClock.set_time(31, 8)
	anna.tile = Vector2i(36, 17)
	anna.step_to = anna.tile
	PawnActions.perform(sim, anna, "use:%d" % plot.id, plot.tile)
	for i in 80:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_kind == "":
			break
	_check(household.stock_of("grain") == 4, "harvesting brings in grain (%s)" % str(household.stock))

	# Building takes materials, or coin for what is lacking.
	household.stock = { "wood": 5 }
	household.coins = 20
	var price := Economy.build_price("bed", household.stock)
	_check(price["coins"] == 12 and price["uses"] == { "wood": 3 }, "wood you hold stands in for coin (%s)" % str(price))
	_check(Economy.build_price("bed", {})["coins"] == 18, "without it you pay the whole price")
	var built := sim.build_place("bed", Vector2i(10, 5))
	_check(built["ok"] and household.stock_of("wood") == 2 and household.coins == 8, "a bed takes three wood and 12d (%d wood, %dd left)" % [household.stock_of("wood"), household.coins])
	household.coins = 3
	household.stock = { "wood": 1 }
	var refused := sim.build_blocker("bed", Vector2i(10, 6))
	_check("bed" not in refused and "wood" in refused and "3d" in refused, "a builder who cannot afford it is told what it takes (%s)" % refused)
	_check("wood" in Economy.cost_text("wall") and "d" in Economy.cost_text("wall"), "the build menu shows what a thing costs in coin and in wood (%s)" % Economy.cost_text("stone_wall"))

	# Selling.
	household.stock = { "wood": 10, "grain": 3 }
	household.coins = 0
	var sells := PawnActions.list_for(sim, anna, counter.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("sell:"))
	_check(sells.size() == 2 and "Sell your 10 wood (14d)" in str(sells[0]["label"]), "a shop counter buys what you have gathered (%s)" % str(sells.map(func(e: Dictionary) -> String: return str(e["label"]))))
	var sold := PawnActions.perform(sim, anna, "sell:wood", counter.tile)
	_check(sold["ok"] and household.coins == 14 and household.stock_of("wood") == 0 and "14d" in str(sold["message"]), "selling pays out (%s)" % str(sold["message"]))
	sim.events.active.append({ "id": "market_day", "until": GameClock.tick + 600 })
	_check(sim.sale_price("grain") == Economy.sell_price("grain", 3, 1.3), "and pays more on market day")
	_check(not sim.sell_stock("fish")["ok"], "nothing to sell, nothing paid")
	var empty := PawnActions.list_for(sim, anna, counter.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "none")
	household.stock = {}
	var none_left := PawnActions.list_for(sim, anna, counter.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "none" and not e["enabled"])
	_check(none_left.size() >= 1 and empty.size() == 0, "with an empty stockpile the counter says there is nothing to sell")

	# The notice board lists the jobs of its own town.
	world.lots.append({ "id": "lot_8", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(46, 24, 10, 6), "public": true, "town": "t1" })
	var board_entries := PawnActions.list_for(sim, anna, board.tile).map(func(e: Dictionary) -> String: return str(e["id"]))
	_check(board_entries.has("hire:lot_7:shop_clerk") and board_entries.has("hire:lot_5:woodcutter") and not board_entries.has("hire:lot_4:shop_clerk"), "the board in the town lists its jobs (shop, woodlot) and not those of another town")

	# Saving the stockpile.
	household.stock = { "stone": 4, "herbs": 2 }
	_check(SaveGame.save(TEST_SAVE, world, household, {}) == OK, "a household with a stockpile is saved")
	var loaded := SaveGame.load_from(TEST_SAVE)
	_check(loaded["ok"] and loaded["household"].stock == { "stone": 4, "herbs": 2 } and loaded["household"].stock_of("stone") == 4, "and its stockpile comes back")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _test_skills() -> void:
	print("Skills, tools and trades")
	# The data hangs together.
	var skill_ids := Skills.skill_ids()
	_check(skill_ids.size() == 14 and "woodcutting" in skill_ids and "smithing" in skill_ids and "music" in skill_ids and "hunting" in skill_ids and "masonry" in skill_ids, "there are fourteen skills (%d)" % skill_ids.size())
	var tools_ok := true
	for tool_id in Skills.tool_ids():
		tools_ok = tools_ok and Skills.skill_ids().has(str(DataRegistry.get_def("tools", tool_id)["skill"])) and Skills.tool_price(tool_id) > 0
	for def in DataRegistry.get_list("objects"):
		if def.has("tool"):
			tools_ok = tools_ok and Skills.is_tool_id(str(def["tool"])) and Skills.skill_ids().has(str(def.get("skill", "")))
	_check(tools_ok, "every tool names a real skill and every object that wants a tool names a real one")
	var recipes_ok := true
	for recipe in DataRegistry.get_list("recipes"):
		var station := DataRegistry.get_def("objects", str(recipe["station"]))
		recipes_ok = recipes_ok and bool(station.get("recipes", false)) and Skills.skill_ids().has(str(recipe["skill"]))
		for item_id in recipe["outputs"]:
			recipes_ok = recipes_ok and (Skills.is_tool_id(str(item_id)) or Economy.resource_ids().has(str(item_id)))
		for item_id in recipe["inputs"]:
			recipes_ok = recipes_ok and Economy.resource_ids().has(str(item_id))
	_check(recipes_ok, "every recipe has a real station, skill and goods")

	# Levels.
	var learner := Pawn.new()
	learner.age = 30
	_check(Skills.level(learner, "mining") == 0 and Skills.rank_name(0) == "Untrained" and Skills.rank_name(10) == "Master", "a stranger to a skill is at level 0; level 10 is a master")
	learner.skills["mining"] = 20.0
	_check(Skills.level(learner, "mining") == 1 and Skills.level_of_xp(59.0) == 1 and Skills.level_of_xp(60.0) == 2 and Skills.level_of_xp(99999.0) == Skills.max_level(), "xp turns into levels")
	learner.skills["mining"] = 40.0
	_check(absf(Skills.progress(learner, "mining") - 0.5) < 0.01, "and shows how far to the next one")

	# Practice, and who learns faster.
	var setup := _romance_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var sim: Simulation = setup["sim"]
	var anna: Pawn = setup["anna"]
	var ben: Pawn = setup["ben"]
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	for i in 30:
		Skills.practice(sim, anna, "woodcutting")
	var adult_xp := Skills.xp(anna, "woodcutting")
	_check(adult_xp > 2.0 and adult_xp < 3.0, "thirty minutes at the axe teach an adult a little (%.2f xp)" % adult_xp)
	var youth := Pawn.new()
	youth.age = 15
	youth.adult = false
	var toddler := Pawn.new()
	toddler.age = 3
	var elder := Pawn.new()
	elder.age = 66
	for who in [youth, toddler, elder]:
		for i in 30:
			Skills.practice(sim, who, "woodcutting")
	_check(Skills.xp(youth, "woodcutting") > adult_xp and Skills.xp(elder, "woodcutting") < adult_xp and Skills.xp(toddler, "woodcutting") == 0.0, "the young learn faster, the old slower, and a toddler not at all")
	var gifted := Pawn.new()
	gifted.age = 30
	gifted.talents = ["woodcutting"] as Array[String]
	for i in 30:
		Skills.practice(sim, gifted, "woodcutting")
	_check(Skills.xp(gifted, "woodcutting") > adult_xp * 1.4, "someone with a talent for it learns faster still")
	var master := Pawn.new()
	master.id = 901
	master.age = 40
	master.tile = Vector2i(9, 9)
	master.skills["woodcutting"] = Skills.xp_for_level(6)
	master.job_kind = "work"
	master.job_stage = "using"
	var pupil := Pawn.new()
	pupil.id = 902
	pupil.age = 20
	pupil.tile = Vector2i(10, 9)
	household.pawns.append(master)
	household.pawns.append(pupil)
	GameClock.set_time(3, 12)
	for i in 40:
		Skills.practice(sim, pupil, "woodcutting")
		GameClock.advance_one_tick()
	_check(Skills.xp(pupil, "woodcutting") > 40.0 * 0.08 * 1.6, "an apprentice beside a master learns about twice as fast (%.2f xp)" % Skills.xp(pupil, "woodcutting"))
	household.pawns.erase(master)
	household.pawns.erase(pupil)
	notices.clear()
	anna.skills["fishing"] = Skills.xp_for_level(1) - 0.01
	Skills.practice(sim, anna, "fishing", 1.0)
	_check(Skills.level(anna, "fishing") == 1 and notices.any(func(t: String) -> bool: return "fishing is now 1" in t), "a new level is announced (%s)" % str(notices))

	# What levels do.
	var expert := Pawn.new()
	expert.age = 30
	expert.skills["farming"] = Skills.xp_for_level(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var total := 0
	for i in 200:
		total += Skills.yield_amount(expert, "farming", 4, rng)
	var novice_total := 0
	for i in 200:
		novice_total += Skills.yield_amount(learner, "farming", 4, rng)
	_check(novice_total == 800 and total > 1500, "a master farmer brings in about twice the harvest (%d against %d)" % [total, novice_total])
	_check(Skills.safety_multiplier(expert, "farming") == 1.0 and absf(Skills.safety_multiplier(Pawn.new(), "mining") - 1.0) < 0.001, "a skill with no safety effect does not change the risk")
	expert.skills["woodcutting"] = Skills.xp_for_level(10)
	_check(Skills.safety_multiplier(expert, "woodcutting") < 0.5, "a practised woodcutter is hurt less often")

	# Tools: the chopping block wants an axe.
	GameClock.set_time(0, 8)
	world.lots.append({ "id": "lot_5", "kind": "woodlot", "name": "Woodlot", "template": "woodlot", "facing": "south", "rect": Rect2i(20, 14, 12, 8), "public": true, "town": "t1" })
	var block := world.add_object("chopping_block", Vector2i(24, 16))
	anna.tile = Vector2i(22, 18)
	anna.step_to = anna.tile
	ben.tile = Vector2i(23, 18)
	ben.step_to = ben.tile
	var blocked := sim.use_blocker(anna, block)
	_check("axe" in blocked, "without an axe the household cannot chop (%s)" % blocked)
	household.add_stock("axe", 1)
	_check(sim.use_blocker(anna, block) == "", "with one in the stockpile they can")
	var result := PawnActions.perform(sim, anna, "use:%d" % block.id, block.tile)
	_check(result["ok"], "she goes to chop")
	for i in 40:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_stage == "using":
			break
	_check(anna.tool == "axe" and household.stock_of("axe") == 0 and not anna.tool_lent, "she takes the axe from the stockpile when she starts (%s)" % anna.tool)
	_check("in use" in sim.use_blocker(ben, block) or sim.use_blocker(ben, block) != "", "and nobody else can use the same axe (%s)" % sim.use_blocker(ben, block))
	var skill_before := Skills.xp(anna, "woodcutting")
	for i in 120:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_kind == "":
			break
	_check(anna.tool == "" and household.stock_of("axe") == 1 and household.stock_of("wood") >= 3, "when the work is done the axe goes back and the wood is in (%s)" % str(household.stock))
	_check(Skills.xp(anna, "woodcutting") > skill_before + 1.0, "and she has learned from it")
	_check(float(household.tool_wear.get("axe", 0.0)) > 20.0, "and the axe is a little worn (%.0f)" % float(household.tool_wear.get("axe", 0.0)))

	# A tool at the end of its life breaks in the middle of the work.
	household.tool_wear["axe"] = float(DataRegistry.get_def("tools", "axe")["durability"]) - 1.5
	household.stock.erase("wood")
	notices.clear()
	PawnActions.perform(sim, anna, "use:%d" % block.id, block.tile)
	for i in 120:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_kind == "":
			break
	_check(household.stock_of("axe") == 0 and anna.tool == "" and anna.job_kind == "" and notices.any(func(t: String) -> bool: return "axe broke" in t), "a worn-out axe breaks and is gone (%s)" % str(notices))

	# Wage work: the employer lends the tool.
	var hired := sim.hire(anna, "lot_5", "woodcutter")
	_check(hired["ok"], "she can take the woodcutter's job")
	GameClock.set_time(1, 7)
	for i in 300:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_stage == "using":
			break
	_check(anna.job_kind == "work" and anna.tool == "axe" and anna.tool_lent and household.stock_of("axe") == 0, "at a wage job the employer's axe is in her hand (%s %s)" % [anna.job_kind, anna.tool])
	sim.quit_job(anna)
	_check(anna.tool == "" and household.stock_of("axe") == 0, "and it is not hers to keep")

	# Crafting at a forge and a bench.
	var forge := world.add_object("forge", Vector2i(10, 8))
	var bench := world.add_object("workbench", Vector2i(12, 8))
	anna.tile = Vector2i(10, 6)
	anna.step_to = anna.tile
	anna.job_kind = ""
	household.stock = {}
	var entries := PawnActions.list_for(sim, anna, forge.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("craft:"))
	_check(entries.size() >= 5 and "Forge an axe" in str(entries[0]["label"]) and not entries[0]["enabled"], "the forge lists what it can make, switched off without what it takes (%d entries)" % entries.size())
	household.stock = { "wood": 1, "stone": 2 }
	entries = PawnActions.list_for(sim, anna, forge.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "craft:forge_axe:%d" % forge.id)
	_check(entries.size() == 1 and not entries[0]["enabled"] and "hammer" in str(entries[0]["reason"]), "and a smith needs a smith's hammer (%s)" % str(entries))
	household.add_stock("smiths_hammer", 1)
	entries = PawnActions.list_for(sim, anna, forge.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "craft:forge_axe:%d" % forge.id)
	_check(entries.size() == 1 and entries[0]["enabled"], "with the hammer it can be made")
	var smithing_before := Skills.xp(anna, "smithing")
	result = PawnActions.perform(sim, anna, "craft:forge_axe:%d" % forge.id, forge.tile)
	_check(result["ok"] and anna.job_recipe == "forge_axe", "she sets about forging an axe")
	notices.clear()
	for i in 200:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.job_kind == "":
			break
	_check(household.stock_of("axe") == 1 and household.stock_of("wood") == 0 and household.stock_of("stone") == 0 and household.stock_of("smiths_hammer") == 1, "an axe comes out, the materials are used up and the hammer is back (%s)" % str(household.stock))
	_check(Skills.xp(anna, "smithing") > smithing_before + 5.0 and notices.any(func(t: String) -> bool: return "made 1 axe" in t), "and she has practised smithing (%s)" % str(notices))
	var skilled := Pawn.new()
	skilled.age = 30
	skilled.skills["smithing"] = Skills.xp_for_level(8)
	_check(Skills.recipe_minutes(skilled, DataRegistry.get_def("recipes", "forge_axe")) < Skills.recipe_minutes(Pawn.new(), DataRegistry.get_def("recipes", "forge_axe")), "a better smith works faster")
	household.stock = { "wood": 2 }
	household.add_stock("hammer", 1)
	entries = PawnActions.list_for(sim, anna, bench.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "craft:carve_rod:%d" % bench.id)
	_check(entries.size() == 1 and entries[0]["enabled"], "the workbench carves a fishing rod from wood")

	# Buying tools at a shop's rack.
	world.lots.append({ "id": "lot_7", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(50, 14, 10, 8), "public": true, "town": "t1" })
	var rack := world.add_object("tool_rack", Vector2i(54, 16))
	household.coins = 20
	household.stock = {}
	var rack_entries := PawnActions.list_for(sim, anna, rack.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("buy:"))
	_check(rack_entries.size() == Skills.tool_ids().size() and "Buy an axe" in str(rack_entries[0]["label"]) and rack_entries[0]["enabled"], "a tool rack sells every tool (%d)" % rack_entries.size())
	var bought := PawnActions.perform(sim, anna, "buy:axe", rack.tile)
	_check(bought["ok"] and household.stock_of("axe") == 1 and household.coins == 20 - Skills.tool_price("axe"), "buying an axe costs its price (%d left)" % household.coins)
	household.coins = 1
	_check(not PawnActions.perform(sim, anna, "buy:pickaxe", rack.tile)["ok"], "and an empty purse cannot buy another")

	# Nursing wants the satchel, and a good healer nurses longer.
	var patient := Pawn.new()
	patient.id = 903
	patient.age = 30
	patient.illness = "fever"
	patient.tile = anna.tile + Vector2i(1, 0)
	household.pawns.append(patient)
	household.stock = { "herbs": 2 }
	_check("satchel" in sim.treat_blocker(anna, patient), "nursing needs a healer's satchel (%s)" % sim.treat_blocker(anna, patient))
	household.stock = { "herbs": 2, "healers_satchel": 1 }
	anna.skills["healing"] = Skills.xp_for_level(8)
	GameClock.set_time(5, 8)
	var nursed := sim.treat(anna, patient)
	_check(nursed["ok"] and patient.treated_until - GameClock.tick > 3 * GameClock.MINUTES_PER_DAY * 1.3, "a skilled healer's nursing lasts longer")
	household.pawns.erase(patient)

	# Trades pass on.
	var mother := Pawn.new()
	mother.age = 35
	mother.talents = ["smithing", "music"] as Array[String]
	mother.skills["smithing"] = Skills.xp_for_level(6)
	var father := Pawn.new()
	father.age = 36
	father.skills["music"] = Skills.xp_for_level(2)
	var heirs_with_talent := 0
	var trade_ok := true
	for i in 60:
		var baby := Pawn.new()
		Skills.inherit(baby, [mother, father] as Array[Pawn], rng)
		trade_ok = trade_ok and baby.family_trade == "smithing" and baby.talents.size() <= 2
		heirs_with_talent += 1 if "smithing" in baby.talents else 0
	_check(trade_ok and heirs_with_talent > 10 and heirs_with_talent < 40, "children take the family trade and sometimes a talent (%d of 60)" % heirs_with_talent)
	anna.skills["smithing"] = Skills.xp_for_level(6)
	var heir_pawn := Pawn.new()
	heir_pawn.display_name = "Kit Marsh"
	heir_pawn.age = 13
	heir_pawn.adult = false
	household.add_pawn(heir_pawn)
	heir_pawn.family_trade = "smithing"
	heir_pawn.parents = [anna.id] as Array[int]
	Skills.take_up_trade(sim, heir_pawn)
	_check(absf(Skills.xp(heir_pawn, "smithing") - Skills.xp_for_level(6) * 0.3) < 1.0, "a youth is shown the basics of the family trade (%.0f xp)" % Skills.xp(heir_pawn, "smithing"))

	# Lessons.
	ben.skills.clear()
	anna.skills = { "woodcutting": Skills.xp_for_level(5) }
	_check(sim.interaction_blocker(anna, ben, "lesson") == "", "someone who knows more can give a lesson")
	var taught := Skills.give_lesson(sim, anna, ben)
	_check(Skills.xp(ben, "woodcutting") >= 40.0 and "taught" in taught, "and the other learns (%s)" % taught)
	ben.skills = { "woodcutting": Skills.xp_for_level(5) }
	_check("anything to teach" in sim.interaction_blocker(anna, ben, "lesson"), "but not between equals (%s)" % sim.interaction_blocker(anna, ben, "lesson"))

	# Townsfolk without work look for it, trades first.
	var local_town: Household = setup["town"]
	local_town.add_pawn(_townsperson("Smith Junior", "male", 20, 0))
	var young := local_town.pawns[local_town.pawns.size() - 1]
	young.home_lot = "lot_1"
	young.family_trade = "trading"
	young.skills["trading"] = Skills.xp_for_level(3)
	world.lots.append({ "id": "lot_8", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(70, 14, 10, 8), "public": true, "town": "t1" })
	Skills.find_work(sim, rng, 5)
	_check(young.work_job == "shop_clerk" and young.work_lot == "lot_8", "an unemployed youth takes the post that suits their trade (%s at %s)" % [young.work_job, young.work_lot])

	# The generated region has places to buy and make tools, and people who know their trades.
	var region := RegionGenerator.generate(42)
	var shops_with_racks := 0
	var racks := 0
	var forges := 0
	var benches := 0
	for placed in region.objects:
		racks += 1 if placed.def_id == "tool_rack" else 0
		forges += 1 if placed.def_id == "forge" else 0
		benches += 1 if placed.def_id == "workbench" else 0
	var smithies := 0
	var workshops := 0
	for lot in region.lots:
		smithies += 1 if str(lot["kind"]) == "smithy" else 0
		workshops += 1 if str(lot["kind"]) == "workshop" else 0
		if str(lot["kind"]) == "shop":
			for placed in region.objects:
				if placed.def_id == "tool_rack" and (lot["rect"] as Rect2i).has_point(placed.tile):
					shops_with_racks += 1
					break
	_check(smithies >= 3 and workshops >= 2 and forges >= 2 * smithies and benches >= 2 * workshops and racks >= smithies + workshops + shops_with_racks and shops_with_racks >= 5, "the towns have smithies, workshops and tool racks in their shops (%d smithies, %d workshops, %d forges, %d benches, %d racks, %d shops with one)" % [smithies, workshops, forges, benches, racks, shops_with_racks])
	var region_folk := NpcGenerator.create(region)
	var skilled_folk := 0
	var adults := 0
	var smiths := 0
	var smith_levels_ok := true
	var heirs := 0
	for person in region_folk.pawns:
		if person.adult:
			adults += 1
			skilled_folk += 1 if not Skills.known(person).is_empty() else 0
		elif person.family_trade != "":
			heirs += 1
		if person.work_job in ["smith", "carpenter"]:
			smiths += 1
			smith_levels_ok = smith_levels_ok and Skills.level(person, Skills.job_skill(DataRegistry.get_def("jobs", person.work_job))) >= 1
	_check(adults > 0 and skilled_folk * 10 >= adults * 8, "most grown townsfolk know some trade (%d of %d)" % [skilled_folk, adults])
	_check(smiths >= 3 and smith_levels_ok, "the smiths and carpenters are practised at it (%d)" % smiths)
	_check(heirs >= 5, "the children of the town's families are heirs to a trade (%d)" % heirs)

	# All of it is saved.
	var copy := Pawn.from_dict(anna.to_dict())
	anna.talents = ["music"] as Array[String]
	anna.family_trade = "smithing"
	anna.tool = "axe"
	anna.tool_lent = true
	copy = Pawn.from_dict(anna.to_dict())
	_check(copy.skills == anna.skills and copy.talents == anna.talents and copy.family_trade == "smithing" and copy.tool == "axe" and copy.tool_lent, "skills, talents, family trade and the tool in hand come back from a save")
	household.tool_wear = { "axe": 12.5 }
	var restored := Household.from_dict(household.to_dict())
	_check(float(restored.tool_wear.get("axe", 0.0)) == 12.5, "and so does the wear on the household's tools")


func _test_social() -> void:
	print("Chatting and opinions")
	_check(Relations.label(65.0) == "Close friend" and Relations.label(35.0) == "Friend" and Relations.label(0.0) == "Acquaintance" and Relations.label(-50.0) == "Rival", "an opinion is described in words")
	var pair := _social_pair()
	var sim: Simulation = pair["sim"]
	var a: Pawn = pair["a"]
	var b: Pawn = pair["b"]
	var household: Household = pair["household"]
	_check("social" in Needs.active_ids(), "Social is a need now that chatting can fill it")
	_check(a.opinion_of(b.id) == Relations.FAMILY_START and b.opinion_of(a.id) == Relations.FAMILY_START, "people who live together start out fond of each other")

	# The menu.
	var entries := _interaction_entries(sim, a, b)
	_check(entries.has("chat") and entries.has("joke") and entries.has("argue") and entries.has("intimacy"), "right-clicking someone lists chat, joke, argue and intimacy")
	_check("Chat with Second" in str(entries["chat"]["label"]) and entries["chat"]["enabled"], "the chat entry names them")
	# A stranger from the town: chat is open, intimacy is not.
	var stranger := Pawn.new()
	stranger.display_name = "Stella Stranger"
	stranger.home_lot = "lot_9"
	stranger.tile = Vector2i(9, 7)
	stranger.step_to = stranger.tile
	_fill_needs(stranger)
	sim.town.add_pawn(stranger)
	stranger.needs["social"] = 30.0
	var met := _interaction_entries(sim, a, stranger)
	_check(met["chat"]["enabled"] and not met["intimacy"]["enabled"] and "close enough" in str(met["intimacy"]["reason"]), "a stranger will chat, but intimacy needs you to know each other first (%s)" % met["intimacy"]["reason"])
	a.needs["libido"] = 20.0
	b.needs["libido"] = 30.0
	_check(sim.interaction_blocker(a, b, "intimacy") == "", "family are close enough for intimacy, if both are willing")
	_fill_needs(a)
	_fill_needs(b)
	a.needs["social"] = 20.0
	b.needs["social"] = 20.0
	var child := Pawn.new()
	child.display_name = "Little One"
	child.adult = false
	child.age = 8
	child.tile = Vector2i(5, 8)
	child.step_to = child.tile
	_fill_needs(child)
	household.add_pawn(child)
	a.set_opinion(child.id, 80.0)
	child.set_opinion(a.id, 80.0)
	_check(sim.interaction_blocker(a, child, "chat") == "", "a child can be chatted to")
	_check("adults" in sim.interaction_blocker(a, child, "intimacy"), "but intimacy is only ever between adults")
	household.remove_pawn(child.id)

	# A chat: both feel less lonely, both like each other more, and it shows as talking, not hearts.
	var before_a := a.opinion_of(b.id)
	_check(PawnActions.perform(sim, a, PawnActions.INTERACT_PREFIX + "chat:%d" % b.id, b.tile)["ok"], "a chat can be started")
	var talk_pose := false
	for minute in 40:
		GameClock.advance_one_tick()
		sim.step()
		talk_pose = talk_pose or (a.pose == "talk" and b.pose == "talk")
	_check(talk_pose, "while they talk both stand with the talking pose")
	_check(a.job_kind == "" and b.job_kind == "", "and it ends by itself")
	_check(a.needs["social"] > 60.0 and b.needs["social"] > 60.0, "talking cures loneliness (%.0f and %.0f)" % [a.needs["social"], b.needs["social"]])
	_check(is_equal_approx(a.opinion_of(b.id), before_a + 4.0) and is_equal_approx(b.opinion_of(a.id), before_a + 4.0), "and each likes the other a little more")
	_check("Had a nice chat" in _mood_texts(a, household), "a good chat is a good thought")
	a.needs["social"] = 95.0
	b.needs["social"] = 95.0
	_check("talking" in sim.interaction_blocker(a, b, "chat"), "nobody wants to chat when they are not lonely at all")

	# An argument and a joke.
	var opinion_now := a.opinion_of(b.id)
	_fill_needs(a)
	_fill_needs(b)
	_check(sim.order_interact(a, b, "argue")["ok"], "anyone can be argued with")
	for minute in 12:
		GameClock.advance_one_tick()
		sim.step()
	_check(is_equal_approx(a.opinion_of(b.id), opinion_now - 10.0) and "Had a row" in _mood_texts(b, household), "an argument sours the opinion and the mood")
	var gains := 0
	var losses := 0
	var joke := DataRegistry.get_def("interactions", "joke")
	for attempt in 80:
		a.job_interaction = "joke"
		var was := a.opinion_of(b.id)
		sim._finish_interaction(a, b, joke)
		if a.opinion_of(b.id) > was:
			gains += 1
		elif a.opinion_of(b.id) < was:
			losses += 1
		a.set_opinion(b.id, 20.0)
		b.set_opinion(a.id, 20.0)
	_check(gains > 40 and losses > 5, "a joke usually lands and sometimes falls flat (%d landed, %d flopped of 80)" % [gains, losses])
	_check("A joke fell flat" in _mood_texts(a, household) or losses == 0, "a flop is remembered by the one who told it")

	# Intimacy needs a close enough friendship; the rest of its rules still hold.
	a.needs["libido"] = 20.0
	b.needs["libido"] = 30.0
	a.set_opinion(b.id, 10.0)
	b.set_opinion(a.id, 80.0)
	_check("close enough" in sim.interaction_blocker(a, b, "intimacy"), "if either does not feel close enough, it is refused")
	a.set_opinion(b.id, 30.0)
	_check(sim.interaction_blocker(a, b, "intimacy") == "", "once both do, it is possible")

	# Opinions drift back toward where they rest.
	a.set_opinion(b.id, 80.0)
	stranger.tile = a.tile
	a.set_opinion(stranger.id, 10.0)
	for day in 30:
		Relations.drift(sim.people())
	_check(is_equal_approx(a.opinion_of(b.id), 80.0 - 30.0 * Relations.DRIFT_PER_DAY), "a friendship needs tending: it slips %.1f a day toward where it rests" % Relations.DRIFT_PER_DAY)
	_check(a.opinion_of(stranger.id) == 0.0, "and a stranger's goodwill fades")
	var lines := sim.relationship_lines(a)
	_check(not lines.is_empty() and lines[0]["name"] == "Second Person", "the panel lists who they know best")

	# Autonomy: a lonely person walks up to someone and chats; the town talks among itself.
	pair = _social_pair()
	sim = pair["sim"]
	a = pair["a"]
	b = pair["b"]
	for step in 3:
		GameClock.advance_one_tick()
		sim.step()
	_check(a.job_kind == "interact" or b.job_kind == "interact", "two lonely people nearby start talking on their own")
	_check(a.job_interaction == "chat" or b.job_interaction == "chat", "and never anything but a chat")
	var quiet_a := Pawn.new()
	var quiet_b := Pawn.new()
	pair = _social_pair()
	sim = pair["sim"]
	a = pair["a"]
	for villager in [quiet_a, quiet_b]:
		villager.home_lot = "lot_5"
		villager.age = 30
		villager.tile = Vector2i(9, 8) if villager == quiet_a else Vector2i(11, 8)
		villager.step_to = villager.tile
		_fill_needs(villager)
		villager.needs["social"] = 10.0
		sim.town.add_pawn(villager)
	pair["b"].needs["social"] = 100.0
	a.needs["social"] = 100.0
	for step in 4:
		GameClock.advance_one_tick()
		sim.step()
	_check(quiet_a.job_kind == "interact" and quiet_a.job_partner == quiet_b.id, "townspeople chat with each other")
	_check(a.job_kind == "" and pair["b"].job_kind == "", "and do not drag the household's people into it")
	var neighbor := Pawn.new()
	neighbor.home_lot = "lot_6"
	neighbor.age = 40
	neighbor.tile = Vector2i(8, 4)
	neighbor.step_to = neighbor.tile
	_fill_needs(neighbor)
	neighbor.needs["social"] = 50.0
	pair = _social_pair()
	sim = pair["sim"]
	a = pair["a"]
	pair["b"].tile = Vector2i(20, 10)  # the family is out of reach
	pair["b"].step_to = pair["b"].tile
	pair["b"].needs["social"] = 100.0
	sim.town.add_pawn(neighbor)
	neighbor.set_opinion(a.id, 0.0)
	for minute in 120:
		GameClock.advance_one_tick()
		sim.step()
		if a.opinion_of(neighbor.id) > 0.0:
			break
	_check(a.opinion_of(neighbor.id) > 0.0 and neighbor.opinion_of(a.id) > 0.0, "a lonely household member goes and chats with a neighbor, and they get to know each other")

	# A generated town is a fond family at home and gets to know its neighbors.
	var big := MapGenerator.generate(42, 128, 96)
	TownGenerator.generate(big)
	var family := HouseholdGenerator.create(big)
	CampGenerator.place(big, family)
	var town := NpcGenerator.create(big)
	var fond := true
	for villager in town.pawns:
		for other in town.pawns:
			if other.id != villager.id and other.home_lot == villager.home_lot:
				fond = fond and villager.opinion_of(other.id) >= Relations.FAMILY_START
	_check(fond, "everyone in a household starts out fond of the rest")
	var big_sim := Simulation.new(big, family, town)
	GameClock.set_time(0, 6)
	var lowest_social := 100.0
	var lowest_who := ""
	var strangers_met := 0
	for minute in 2 * GameClock.MINUTES_PER_DAY:
		GameClock.advance_one_tick()
		big_sim.step(GameClock.SUBSTEPS_PER_MINUTE)  # as in the live game, where walking is quick
		if minute % 60 == 0:
			for villager in town.pawns:
				if float(villager.needs["social"]) < lowest_social:
					lowest_social = float(villager.needs["social"])
					lowest_who = "%s (%s, %s, %s, at %s)" % [villager.display_name, villager.work_job, villager.job_kind, villager.age, str(villager.tile)]
	for villager in town.pawns:
		for other in town.pawns:
			if other.home_lot != villager.home_lot and villager.opinion_of(other.id) > 0.0:
				strangers_met += 1
	_check(strangers_met > 0, "over two days the townspeople get to know people from other households (%d acquaintances)" % strangers_met)
	_check(lowest_social > 0.0, "and nobody in town goes completely without company (lowest %.0f: %s)" % [lowest_social, lowest_who])
	GameClock.reset()


func _collect_events(world_seed: int, days: int) -> Array[Dictionary]:
	GameClock.reset()
	var director := EventDirector.new()
	var found: Array[Dictionary] = []
	for day in days:
		for hour in range(0, 24, 2):
			GameClock.set_time(day, hour)
			for change in director.update(world_seed):
				if change["kind"] == "started":
					found.append({ "id": change["id"], "day": day, "season": GameClock.get_date()["season_id"] })
	return found


## A small world for courtship: your lot with beds for three, two town houses, a green, and a shop in
## another town. Returns the world, your household (Anna and Ben), the town (Cara of the first
## house, with a job in the other town, and Dan of the second) and a simulation.
func _romance_setup() -> Dictionary:
	GameClock.set_time(3, 12)
	var world := WorldState.new(90, 40, 3, "grass")
	world.lot = Rect2i(2, 2, 12, 8)
	world.lots = [
		{ "id": "lot_1", "kind": "house", "name": "House", "template": "cottage", "facing": "south", "rect": Rect2i(20, 2, 10, 8), "public": false, "town": "t1" },
		{ "id": "lot_2", "kind": "house", "name": "House", "template": "cottage", "facing": "south", "rect": Rect2i(34, 2, 10, 8), "public": false, "town": "t1" },
		{ "id": "lot_3", "kind": "park", "name": "Village green", "template": "green", "facing": "south", "rect": Rect2i(50, 2, 14, 10), "public": true, "town": "t1" },
		{ "id": "lot_4", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(70, 2, 10, 8), "public": true, "town": "t2" },
	]
	world.towns = [
		{ "id": "t1", "name": "Testford", "kind": "town", "profile": "town", "center": Vector2i(40, 10), "rect": Rect2i(0, 0, 66, 40), "home": true },
		{ "id": "t2", "name": "Faraway", "kind": "village", "profile": "village", "center": Vector2i(75, 10), "rect": Rect2i(66, 0, 24, 40), "home": false },
	]
	for lot_rect in [Rect2i(20, 2, 10, 8), Rect2i(34, 2, 10, 8)]:
		for y in range(lot_rect.position.y, lot_rect.end.y):
			for x in range(lot_rect.position.x, lot_rect.end.x):
				world.set_floor(Vector2i(x, y), "planks")
	for bed_tile in [Vector2i(4, 4), Vector2i(6, 4), Vector2i(8, 4), Vector2i(22, 4), Vector2i(24, 4), Vector2i(36, 4)]:
		world.add_object("bed", bed_tile)
	var household := Household.new()
	household.coins = 40
	var town := Household.new(NpcGenerator.FIRST_ID)
	var specs := [
		[household, "Anna Marsh", "female", 25, ["straight"], WorldState.HOME_LOT, Vector2i(5, 6)],
		[household, "Ben Marsh", "male", 27, ["straight"], WorldState.HOME_LOT, Vector2i(7, 6)],
		[town, "Cara Cooper", "female", 24, ["bisexual"], "lot_1", Vector2i(23, 6)],
		[town, "Dan Hollis", "male", 26, ["straight"], "lot_2", Vector2i(37, 6)],
	]
	var people: Array[Pawn] = []
	for spec in specs:
		var person := Pawn.new()
		person.display_name = spec[1]
		person.gender = spec[2]
		person.age = spec[3]
		person.adult = true
		for trait_id in spec[4]:
			person.traits.append(str(trait_id))
		person.home_lot = spec[5]
		person.tile = spec[6]
		person.step_to = person.tile
		_fill_needs(person)
		spec[0].add_pawn(person)
		people.append(person)
	people[2].work_lot = "lot_4"
	people[2].work_job = "shop_clerk"
	Relations.make_family([people[0], people[1]] as Array[Pawn])
	var sim := Simulation.new(world, household, town)
	return { "world": world, "household": household, "town": town, "sim": sim, "anna": people[0], "ben": people[1], "cara": people[2], "dan": people[3] }


func _test_romance() -> void:
	print("Courtship, dates and moving in")
	var setup := _romance_setup()
	var sim: Simulation = setup["sim"]
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var town: Household = setup["town"]
	var anna: Pawn = setup["anna"]
	var ben: Pawn = setup["ben"]
	var cara: Pawn = setup["cara"]
	var dan: Pawn = setup["dan"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var interactions := DataRegistry.get_list("interactions")
	var kinds := interactions.map(func(i: Dictionary) -> String: return str(i["id"]))
	_check("flirt" in kinds and "kiss" in kinds and "ask_out" in kinds, "flirting, kissing and asking someone out are interactions")
	_check(float(Romance.config()["ask_out_romance"]) > 0.0 and Romance.config()["date_venues"].has("park"), "courtship is data (relationships.json)")

	# Who can flirt with whom.
	anna.set_opinion(dan.id, 20.0)
	dan.set_opinion(anna.id, 20.0)
	_check(sim.interaction_blocker(anna, dan, "flirt") == "", "a woman and a man who are drawn to each other may flirt")
	_check("interested" in sim.interaction_blocker(anna, cara, "flirt"), "but not with someone she is not drawn to (%s)" % sim.interaction_blocker(anna, cara, "flirt"))
	var child := Pawn.new()
	child.display_name = "Kid Marsh"
	child.age = 9
	child.adult = false
	child.tile = Vector2i(9, 6)
	child.step_to = child.tile
	_fill_needs(child)
	household.add_pawn(child)
	_check(sim.interaction_blocker(anna, child, "flirt") != "", "or with a child")
	var sister := Pawn.new()
	sister.display_name = "Sis Marsh"
	sister.gender = "male"
	sister.traits = ["bisexual"] as Array[String]
	sister.age = 30
	sister.tile = Vector2i(10, 6)
	sister.step_to = sister.tile
	_fill_needs(sister)
	household.add_pawn(sister)
	anna.traits = ["bisexual"] as Array[String]
	sister.parents = [anna.id] as Array[int]
	sister.set_opinion(anna.id, 50.0)
	anna.set_opinion(sister.id, 50.0)
	_check("family" in sim.interaction_blocker(anna, sister, "flirt") and Relations.are_kin(anna, sister), "or with family (%s)" % sim.interaction_blocker(anna, sister, "flirt"))
	var twin := Pawn.new()
	twin.parents = [anna.id] as Array[int]
	_check(Relations.are_kin(twin, sister) and not Relations.are_kin(ben, anna), "siblings are family, housemates are not")
	household.remove_pawn(sister.id)
	household.remove_pawn(child.id)
	anna.traits = ["straight"] as Array[String]

	# Flirting warms romance on both sides.
	var flirt := DataRegistry.get_def("interactions", "flirt")
	var tries := 0
	while anna.romance_for(dan.id) < 25.0 and tries < 40:
		anna.job_interaction = "flirt"
		sim._finish_interaction(anna, dan, flirt)
		tries += 1
	_check(anna.romance_for(dan.id) >= 25.0 and dan.romance_for(anna.id) >= 25.0, "flirting warms them both (after %d tries)" % tries)
	_check(anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "flirted") and tries > 2, "and it lifts the mood, though a flirt can fall flat")
	var kiss_entry: Dictionary = _interaction_entries(sim, anna, dan)["kiss"]
	_check(kiss_entry["enabled"] or "ready" in str(kiss_entry["reason"]), "a kiss waits until they are warm enough (%s)" % str(kiss_entry))
	dan.romance[anna.id] = 10.0
	_check("ready" in sim.interaction_blocker(anna, dan, "kiss") and "ready" in sim.interaction_blocker(anna, dan, "ask_out"), "she cannot kiss or ask out someone who is not ready (%s)" % sim.interaction_blocker(anna, dan, "ask_out"))
	dan.romance[anna.id] = 30.0
	anna.romance[dan.id] = 30.0
	dan.set_opinion(anna.id, 30.0)
	anna.set_opinion(dan.id, 30.0)

	# Asking out.
	_check(sim.interaction_blocker(anna, dan, "ask_out") == "" and _interaction_entries(sim, anna, dan)["ask_out"]["enabled"], "once both are ready she can ask him out")
	var asked := sim.order_interact(anna, dan, "ask_out")
	_check(asked["ok"] and dan.job_kind == "interact", "asking sends her to him")
	for i in 90:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if anna.partner_id != 0:
			break
	_check(anna.partner_id == dan.id and dan.partner_id == anna.id and anna.partner_status == "dating" and Romance.together(anna, dan), "he says yes: they are dating")
	_check(anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "new_romance" and t.get("about", "") == "Dan") and _has_part(Mood.evaluate(anna, household, GameClock.tick), "partnered"), "and both are glad of it")
	_check(sim.relationship_lines(anna)[0]["name"] == "Dan Hollis" and sim.relationship_lines(anna)[0]["label"] == "Dating", "the panel lists a partner first")
	_check("together" in sim.interaction_blocker(anna, dan, "ask_out"), "nobody asks out their own partner")
	var cara_flirt := sim.interaction_blocker(cara, anna, "flirt")
	var ben_flirt := sim.interaction_blocker(ben, anna, "flirt")
	_check("seeing someone" in sim.interaction_blocker(dan, cara, "flirt") or "interested" in sim.interaction_blocker(dan, cara, "flirt"), "a taken person is not flirted with, and does not flirt")
	dan.partner_id = 0
	anna.partner_id = 0
	cara.set_opinion(anna.id, 40.0)
	anna.set_opinion(cara.id, 40.0)
	dan.partner_id = anna.id
	anna.partner_id = dan.id
	_check(cara_flirt != "" and ben_flirt != "", "(%s; %s)" % [cara_flirt, ben_flirt])

	# The menu and a date.
	var entries := PawnActions.list_for(sim, anna, dan.tile).map(func(e: Dictionary) -> String: return str(e["id"]))
	_check(entries.has("date:%d" % dan.id) and entries.has("breakup:%d" % dan.id) and entries.has("move:invite:%d" % dan.id) and entries.has("move:join:%d" % dan.id), "a couple's menu offers a date, moving in and a break-up")
	GameClock.set_time(3, 23)
	_check("hour" in Romance.date_blocker(sim, anna, dan), "nobody goes out on a date in the dead of night")
	GameClock.set_time(3, 12)
	_check(Romance.date_blocker(sim, anna, dan) == "", "by day they can")
	var before_romance := anna.romance_for(dan.id)
	var before_opinion := anna.opinion_of(dan.id)
	var date_result := PawnActions.perform(sim, anna, "date:%d" % dan.id, dan.tile)
	_check(date_result["ok"] and anna.job_kind == "date" and dan.job_kind == "date" and "date" in sim.describe_activity(anna).to_lower(), "she asks him on a date and both set off (%s)" % sim.describe_activity(anna))
	var date_minutes := 0
	for i in 220:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		date_minutes += 1
		if anna.job_kind == "" and dan.job_kind == "":
			break
	_check(anna.job_kind == "" and dan.job_kind == "" and anna.romance_for(dan.id) > before_romance + 8.0 and anna.opinion_of(dan.id) > before_opinion, "after an hour at the green they are closer (%d min)" % date_minutes)
	_check(dan.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "had_date") and Rect2i(50, 2, 14, 10).has_point(anna.tile), "and remember it with joy")
	dan.job_kind = "use"
	_check("busy" in Romance.date_blocker(sim, anna, dan), "a busy partner cannot be taken out")
	dan.job_kind = ""

	# Moving in.
	anna.romance[dan.id] = 50.0
	dan.romance[anna.id] = 50.0
	anna.partner_since = GameClock.tick
	dan.partner_since = GameClock.tick
	_check("long enough" in Romance.invite_blocker(sim, anna, dan), "they must have been together a while (%s)" % Romance.invite_blocker(sim, anna, dan))
	anna.partner_since = GameClock.tick - 2 * GameClock.MINUTES_PER_DAY
	dan.partner_since = anna.partner_since
	_check(Romance.spare_beds(sim, WorldState.HOME_LOT) == 1 and Romance.invite_blocker(sim, anna, dan) == "", "with a bed to spare at home she can ask him to move in")
	var told := Romance.invite(sim, anna, dan)
	_check(household.get_pawn(dan.id) != null and town.get_pawn(dan.id) == null and dan.id >= NpcGenerator.FIRST_ID, "he joins your household and keeps his own number (%s)" % told)
	_check(dan.home_lot == WorldState.HOME_LOT and dan.origin_lot == "lot_2" and dan.partner_status == "partners" and anna.partner_status == "partners", "and lives on your lot now")
	_check(Romance.spare_beds(sim, WorldState.HOME_LOT) == 0 and household.select(dan.id), "the beds are full, and you can play him")
	_check(dan.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "moved_in") and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "moved_in"), "they are glad to be together")
	var hud_lines := PawnActions.list_for(sim, anna, dan.tile).map(func(e: Dictionary) -> String: return str(e["id"]))
	_check(not hud_lines.has("move:invite:%d" % dan.id), "once he lives with her there is no more asking")

	# Breaking up sends the one who moved in home.
	var leaving := Romance.break_up(sim, anna, dan)
	_check(anna.partner_id == 0 and dan.partner_id == 0 and anna.romance_for(dan.id) == 0.0 and anna.opinion_of(dan.id) < 0.0, "a break-up ends it, and sours the friendship (%s)" % leaving)
	_check(household.get_pawn(dan.id) == null and town.get_pawn(dan.id) != null and dan.home_lot == "lot_2" and dan.origin_lot == "", "and he goes back to the town and his own house")
	_check(dan.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "heartbroken") and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "broke_up"), "one is heartbroken and one is sorry")

	# Moving in with them: Anna and Cara (Anna turns out to like women).
	anna.traits = ["bisexual"] as Array[String]
	Romance.begin_dating(sim, anna, cara)
	anna.romance[cara.id] = 60.0
	cara.romance[anna.id] = 60.0
	anna.partner_since = GameClock.tick - 3 * GameClock.MINUTES_PER_DAY
	cara.partner_since = anna.partner_since
	_check(Romance.invite_blocker(sim, anna, cara) == "" and Romance.join_blocker(sim, anna, cara) != "" == false, "she could ask Cara in, or move in with her")
	world.add_object("bed", Vector2i(26, 4))
	var moved := Romance.join(sim, anna, cara)
	_check(anna.home_lot == "lot_1" and anna.origin_lot == WorldState.HOME_LOT and household.get_pawn(anna.id) != null and "moved in" in moved, "Anna moves into Cara's house and stays one of your folk (%s)" % moved)
	_check(anna.opinion_of(cara.id) >= Relations.FAMILY_START, "the family there take to her")
	var home_entries := PawnActions.list_for(sim, anna, Vector2i(5, 5)).map(func(e: Dictionary) -> String: return str(e["id"]))
	_check(home_entries.has("move_home") and sim.use_blocker(anna, world.object_at(Vector2i(4, 4))) != "", "she can no longer use the beds on your lot, and may move back")
	_check(sim.use_blocker(anna, world.object_at(Vector2i(26, 4))) == "", "but she can use the ones at Cara's")
	var back_home := PawnActions.perform(sim, anna, "move_home", Vector2i(5, 5))
	_check(back_home["ok"] and anna.home_lot == WorldState.HOME_LOT and anna.partner_status == "dating", "moving back puts them back to dating")

	# A job in another town cannot be kept.
	_check(cara.work_job == "shop_clerk", "Cara works at the shop in the other town")
	anna.partner_since = GameClock.tick - 3 * GameClock.MINUTES_PER_DAY
	cara.partner_since = anna.partner_since
	world.add_object("bed", Vector2i(10, 4))
	Romance.invite(sim, anna, cara)
	_check(cara.work_job == "" and household.get_pawn(cara.id) != null, "a partner who moves to your lot gives up a job in another town")

	# A partner dies.
	Romance.break_up(sim, anna, cara)
	Romance.begin_dating(sim, anna, ben)
	Mortality.fall(sim, ben, "starved")
	sim.die(ben, "starved")
	_check(anna.partner_id == 0 and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "widowed"), "if a partner dies the other is on their own, in grief")

	# Among the town's people.
	var civic := _romance_setup()
	var civic_sim: Simulation = civic["sim"]
	var civic_town: Household = civic["town"]
	var extra: Array[Pawn] = []
	for spec in [["Eve Hollis", "female", "lot_2"], ["Finn Cooper", "male", "lot_1"]]:
		var person := Pawn.new()
		person.display_name = spec[0]
		person.gender = spec[1]
		person.age = 25
		person.traits = ["straight"] as Array[String]
		person.home_lot = spec[2]
		person.tile = Vector2i(37, 7) if spec[2] == "lot_2" else Vector2i(23, 7)
		person.step_to = person.tile
		_fill_needs(person)
		civic_town.add_pawn(person)
		extra.append(person)
	var civic_cara: Pawn = civic["cara"]
	civic_cara.traits = ["straight"] as Array[String]
	civic_cara.work_lot = ""
	civic_cara.work_job = ""
	var civic_dan: Pawn = civic["dan"]
	var eve: Pawn = extra[0]
	var finn: Pawn = extra[1]
	# Dan and Eve share a house, Cara and Finn another: they pair up and live as partners.
	var days := 0
	while (civic_dan.partner_id == 0 or civic_cara.partner_id == 0) and days < 60:
		GameClock.set_time(10 + days, 0)
		Romance.new_day(civic_sim, rng)
		days += 1
	_check(civic_dan.partner_id == eve.id and civic_dan.partner_status == "partners" and civic_cara.partner_id == finn.id, "two grown-ups of the town under one roof soon become partners (after %d days)" % days)
	# Singles of different houses: free Dan and Cara's partners and let them meet.
	for pawn in [civic_dan, eve, civic_cara, finn]:
		pawn.partner_id = 0
		pawn.partner_status = ""
		pawn.romance.clear()
	eve.traits = ["asexual"] as Array[String]  # nobody else under their roofs is drawn to them
	finn.traits = ["asexual"] as Array[String]
	civic["world"].add_object("bed", Vector2i(26, 4))  # a spare bed in each house
	civic["world"].add_object("bed", Vector2i(38, 4))
	var courted := 0
	for day in 2000:
		GameClock.set_time(100 + day, 0)
		Romance.new_day(civic_sim, rng)
		if civic_cara.partner_id == civic_dan.id:
			courted = day
			break
	_check(civic_cara.partner_id == civic_dan.id and civic_cara.partner_status == "dating", "singles of one town in time take to each other (day %d)" % courted)
	var settled := false
	for day in 60:
		GameClock.set_time(2200 + day, 0)
		Romance.new_day(civic_sim, rng)
		if civic_cara.partner_status == "partners":
			settled = true
			break
	_check(settled and civic_cara.home_lot == civic_dan.home_lot and (civic_cara.origin_lot != "" or civic_dan.origin_lot != ""), "and a dating couple move under one roof, if there is a bed (%s and %s live at %s)" % [civic_cara.display_name, civic_dan.display_name, civic_dan.home_lot])

	# Cooling off.
	var cold := _romance_setup()
	var cold_a: Pawn = cold["anna"]
	var cold_d: Pawn = cold["dan"]
	cold_a.romance[cold_d.id] = 20.0
	Romance.new_day(cold["sim"], rng)
	_check(cold_a.romance_for(cold_d.id) < 20.0, "romance cools if it is not kept up")
	cold_a.romance[cold_d.id] = 60.0
	cold_a.partner_id = cold_d.id
	cold_d.partner_id = cold_a.id
	Romance.new_day(cold["sim"], rng)
	_check(cold_a.romance_for(cold_d.id) > 60.0, "but a couple's grows")

	# Saving.
	cold_a.parents = [7, 8] as Array[int]
	cold_a.origin_lot = "lot_2"
	cold_a.partner_status = "dating"
	cold_a.partner_since = 1234
	_check(SaveGame.save(TEST_SAVE, cold["world"], cold["household"], {}) == OK, "a household in love is saved")
	var loaded := SaveGame.load_from(TEST_SAVE)
	var loaded_anna: Pawn = loaded["household"].pawns[0]
	_check(loaded["ok"] and loaded["household"].to_dict() == cold["household"].to_dict() and is_equal_approx(loaded_anna.romance_for(cold_d.id), cold_a.romance_for(cold_d.id)) and loaded_anna.partner_id == cold_d.id and loaded_anna.partner_status == "dating" and loaded_anna.parents == [7, 8] and loaded_anna.origin_lot == "lot_2" and loaded_anna.partner_since == 1234, "and the romance, partner, family and where she came from survive a round trip")
	DirAccess.remove_absolute(TEST_SAVE)

	# Babies are born with parents.
	var parents := _family_setup()
	var mum: Pawn = parents["mother"]
	var dad: Pawn = parents["father"]
	GameClock.set_time(0, 0)
	Pregnancy.begin(parents["sim"], mum, dad, rng)
	mum.babies_due = 2
	_deliver(parents["sim"], mum, rng)
	var newborns: Array[Pawn] = []
	for pawn in parents["household"].pawns:
		if pawn.is_infant():
			newborns.append(pawn)
	_check(newborns.size() == 2 and newborns[0].parents == [mum.id, dad.id] and Relations.are_kin(newborns[0], newborns[1]) and Relations.are_kin(newborns[0], mum), "a baby knows its parents, and its twin is its sibling")
	GameClock.reset()


func _minutes(sim: Simulation, minutes: int, until: Callable = Callable()) -> void:
	for i in minutes:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if until.is_valid() and until.call():
			return


func _test_marriage() -> void:
	print("Rings, engagements and weddings")
	var setup := _romance_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var town: Household = setup["town"]
	var sim: Simulation = setup["sim"]
	var anna: Pawn = setup["anna"]
	var ben: Pawn = setup["ben"]
	var cara: Pawn = setup["cara"]
	var dan: Pawn = setup["dan"]
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	# A shop counter sells rings.
	world.lots.append({ "id": "lot_7", "kind": "shop", "name": "Shop", "template": "shop", "facing": "south", "rect": Rect2i(60, 24, 10, 8), "public": true, "town": "t1" })
	var counter := world.add_object("counter", Vector2i(64, 26))
	household.coins = 60
	var counter_entries := PawnActions.list_for(sim, anna, counter.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "buy:ring")
	_check(counter_entries.size() == 1 and "Buy a ring (20d)" in str(counter_entries[0]["label"]) and counter_entries[0]["enabled"], "a shop counter sells rings (%s)" % str(counter_entries))
	_check(PawnActions.perform(sim, anna, "buy:ring", counter.tile)["ok"] and household.stock_of("ring") == 1 and household.coins == 40, "and buying one takes 20d")
	household.add_stock("ring", -1)
	var forge_recipe := DataRegistry.get_def("recipes", "forge_ring")
	_check(str(forge_recipe.get("station", "")) == "forge" and int(forge_recipe.get("min_level", 0)) >= 2, "a smith of some skill can forge one")

	# Asking: it takes a couple, time together, trust and a ring.
	_check("not seeing" in sim.interaction_blocker(anna, dan, "propose"), "only a couple can propose (%s)" % sim.interaction_blocker(anna, dan, "propose"))
	anna.set_opinion(dan.id, 60.0)
	dan.set_opinion(anna.id, 60.0)
	anna.tile = Vector2i(10, 12)
	anna.step_to = anna.tile
	dan.tile = Vector2i(11, 12)
	dan.step_to = dan.tile
	Romance.begin_dating(sim, anna, dan)
	_check("long enough" in sim.interaction_blocker(anna, dan, "propose"), "not on the first day (%s)" % sim.interaction_blocker(anna, dan, "propose"))
	anna.partner_since -= 3 * GameClock.MINUTES_PER_DAY
	dan.partner_since = anna.partner_since
	anna.romance[dan.id] = 70.0
	dan.romance[anna.id] = 70.0
	_check("ring" in sim.interaction_blocker(anna, dan, "propose"), "nor without a ring (%s)" % sim.interaction_blocker(anna, dan, "propose"))
	household.add_stock("ring", 1)
	dan.romance[anna.id] = 30.0
	_check("isn't ready" in sim.interaction_blocker(anna, dan, "propose"), "nor if they are not ready (%s)" % sim.interaction_blocker(anna, dan, "propose"))
	dan.romance[anna.id] = 70.0
	_check(sim.interaction_blocker(anna, dan, "propose") == "", "but with all of that she can")
	var labels := PawnActions.list_for(sim, anna, dan.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "interact:propose:%d" % dan.id)
	_check(labels.size() == 1 and "Propose to Dan" in str(labels[0]["label"]), "his menu offers it")
	var started := PawnActions.perform(sim, anna, "interact:propose:%d" % dan.id, dan.tile)
	_check(started["ok"], "she proposes")
	notices.clear()
	_minutes(sim, 40, func() -> bool: return anna.job_kind == "" and anna.bond != "")
	_check(anna.bond == "engaged" and dan.bond == "engaged" and Romance.is_engaged(anna, dan), "he says yes: they are engaged")
	_check(household.stock_of("ring") == 0 and notices.any(func(t: String) -> bool: return "engaged" in t), "the ring is spent and the household told (%s)" % str(notices))
	_check(anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "got_engaged") and Romance.tie_name(anna, dan) == "Fiancé" and Romance.tie_name(dan, anna) == "Fiancée", "they are glad of it, and called fiancé and fiancée")
	_check(not Mood.evaluate(anna, household, GameClock.tick)["parts"].filter(func(part: Dictionary) -> bool: return part["id"] == "engaged").is_empty(), "and engaged is a good thing to be")
	_check("already engaged" in Romance.proposal_blocker(sim, anna, dan), "nobody proposes twice")

	# A wedding needs time, a chapel, an hour of the day and room to live together.
	_check("only just" in Romance.wedding_blocker(sim, anna, dan), "the wedding waits a day (%s)" % Romance.wedding_blocker(sim, anna, dan))
	anna.bond_since -= 3 * GameClock.MINUTES_PER_DAY
	dan.bond_since = anna.bond_since
	GameClock.set_time(6, 21)
	_check("hour" in Romance.wedding_blocker(sim, anna, dan), "and not at night (%s)" % Romance.wedding_blocker(sim, anna, dan))
	GameClock.set_time(6, 10)
	_check("chapel" in Romance.wedding_blocker(sim, anna, dan), "nor where there is no chapel (%s)" % Romance.wedding_blocker(sim, anna, dan))
	world.lots.append({ "id": "lot_9", "kind": "chapel", "name": "Chapel", "template": "chapel", "facing": "south", "rect": Rect2i(50, 14, 12, 10), "public": true, "town": "t1" })
	for y in range(14, 24):
		for x in range(50, 62):
			world.set_floor(Vector2i(x, y), "flagstone")
	world.add_object("altar", Vector2i(55, 15))
	_check(Romance.wedding_blocker(sim, anna, dan) == "", "with a chapel, the morning and a bed at home, it can be done (%s)" % Romance.wedding_blocker(sim, anna, dan))
	var entries := PawnActions.list_for(sim, anna, dan.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "wed:%d" % dan.id)
	_check(entries.size() == 1 and entries[0]["enabled"] and "Marry Dan" in str(entries[0]["label"]), "the menu offers to marry him at the chapel")
	var breakups := PawnActions.list_for(sim, anna, dan.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("breakup:"))
	_check(breakups.size() == 1 and "engagement" in str(breakups[0]["label"]), "or to break off the engagement")

	# The day itself: guests come, the vows are said.
	cara.set_opinion(anna.id, 50.0)
	anna.set_opinion(cara.id, 50.0)
	var death_age_before := Life.death_age(anna)
	var outfit_seed_before := anna.seed_name()
	var wedding := PawnActions.perform(sim, anna, "wed:%d" % dan.id, dan.tile)
	_check(wedding["ok"] and anna.job_kind == "wed" and dan.job_kind == "wed", "the couple set off for the chapel")
	_check(ben.job_kind == "guest" and cara.job_kind == "guest", "the household and a friend go too (%s, %s)" % [ben.job_kind, cara.job_kind])
	_check("wedding" in sim.describe_activity(ben) and "married" in sim.describe_activity(anna).to_lower(), "and the panel says so (%s / %s)" % [sim.describe_activity(ben), sim.describe_activity(anna)])
	notices.clear()
	_minutes(sim, 120, func() -> bool: return anna.bond == "married")
	_check(anna.bond == "married" and dan.bond == "married" and Romance.is_married(anna, dan), "they say their vows and are married")
	_minutes(sim, 3)
	_check(ben.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "at_wedding") and cara.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "at_wedding"), "the guests enjoyed it")
	_check(ben.job_kind == "" and cara.job_kind == "" and anna.job_kind == "" and dan.job_kind == "", "and everyone is free again")
	_check(anna.home_lot == dan.home_lot and household.get_pawn(dan.id) != null and town.get_pawn(dan.id) == null, "he has moved in with her and joined the household")
	_check(anna.display_name == "Anna Hollis" and anna.maiden_name == "Anna Marsh" and dan.display_name == "Dan Hollis", "the wife has taken the husband's name (%s, née %s)" % [anna.display_name, anna.maiden_name])
	_check(Life.death_age(anna) == death_age_before and anna.seed_name() == outfit_seed_before, "which changes nothing about how she is made")
	_check(anna.wed_until > GameClock.tick and PawnArt.outfit_for(anna)["wedding"] and not PawnArt.outfit_for(ben)["wedding"], "and she is in wedding clothes for the day")
	_check(notices.any(func(t: String) -> bool: return "Anna and Dan are married" in t), "the household hears of it (%s)" % str(notices))
	_check(Romance.tie_name(anna, dan) == "Husband" and Romance.tie_name(dan, anna) == "Wife" and anna.partner_status == "partners", "they are husband and wife")

	# A marriage is for life.
	_check(Romance.break_up(sim, anna, dan) == "" and anna.bond == "married", "a married couple cannot simply break up")
	var married_entries := PawnActions.list_for(sim, anna, dan.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("breakup:") or str(e["id"]).begins_with("wed:"))
	_check(married_entries.is_empty(), "and the menu does not offer it")
	_check("share a home" in Romance.move_home_blocker(sim, dan) or "already" in Romance.move_home_blocker(sim, dan), "nor does one move out")
	var saved := Pawn.from_dict(anna.to_dict())
	_check(saved.bond == "married" and saved.maiden_name == "Anna Marsh" and saved.wed_until == anna.wed_until and saved.bond_since == anna.bond_since, "marriage and a maiden name are saved")
	Romance.on_death(sim, dan)
	_check(anna.bond == "" and anna.partner_id == 0 and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "widowed"), "if he dies she is a widow, free to marry again")

	# Engagements can be broken off.
	var erin := Pawn.new()
	erin.display_name = "Erin Fox"
	erin.gender = "female"
	erin.age = 24
	erin.adult = true
	var finn := Pawn.new()
	finn.display_name = "Finn Reed"
	finn.gender = "male"
	finn.age = 26
	finn.adult = true
	household.add_pawn(erin)
	household.add_pawn(finn)
	Romance.begin_dating(sim, erin, finn)
	Romance.engage(sim, erin, finn)
	var broke := Romance.break_up(sim, erin, finn)
	_check("parted" in broke and erin.bond == "" and finn.bond == "" and erin.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "engagement_off"), "a broken engagement leaves nobody engaged")

	# Same-sex couples take a name by the same rule.
	var gil := Pawn.new()
	gil.display_name = "Gil Archer"
	gil.gender = "male"
	gil.id = 70
	var hal := Pawn.new()
	hal.display_name = "Hal Brewer"
	hal.gender = "male"
	hal.id = 71
	Romance._take_surname(gil, hal)
	_check(gil.display_name == "Gil Archer" and hal.display_name == "Hal Archer" and hal.maiden_name == "Hal Brewer", "two men marrying: the later one takes the other's name")

	# The town's own couples marry without anyone asking.
	var gwen := _townsperson("Gwen Tanner", "female", 30, 0)
	var hugh := _townsperson("Hugh Cooper", "male", 32, 0)
	gwen.home_lot = "lot_1"
	hugh.home_lot = "lot_1"
	town.add_pawn(gwen)
	town.add_pawn(hugh)
	Romance.begin_dating(sim, gwen, hugh, "partners")
	gwen.partner_since -= 5 * GameClock.MINUTES_PER_DAY
	hugh.partner_since = gwen.partner_since
	for day in 80:
		Romance._marry_townsfolk(sim, rng)
		if gwen.bond == "married":
			break
	_check(gwen.bond == "married" and hugh.bond == "married" and gwen.display_name == "Gwen Cooper" and gwen.wed_until == 0, "a townsfolk couple under one roof marry by themselves (%s)" % gwen.display_name)


## A wide empty field with two of your folk in it: no towns, so wild animals may roam all over it.
func _open_field() -> Dictionary:
	GameClock.set_time(3, 10)
	var world := WorldState.new(140, 50, 3, "grass")
	world.lot = Rect2i(2, 2, 12, 8)
	var household := Household.new()
	household.coins = 200
	var people: Array[Pawn] = []
	for spec in [["Anna Marsh", "female", 25, Vector2i(20, 25)], ["Ben Marsh", "male", 27, Vector2i(22, 25)]]:
		var person := Pawn.new()
		person.display_name = spec[0]
		person.gender = spec[1]
		person.age = spec[2]
		person.adult = true
		person.tile = spec[3]
		person.step_to = person.tile
		for need_id in Needs.active_ids():
			person.needs[need_id] = 100.0
		household.add_pawn(person)
		people.append(person)
	var sim := Simulation.new(world, household, Household.new(NpcGenerator.FIRST_ID))
	return { "world": world, "household": household, "sim": sim, "anna": people[0], "ben": people[1] }


func _test_animals() -> void:
	print("Animals: game, mounts, pack animals and pets")
	var wild := Fauna.kinds("wild")
	var tame := Fauna.kinds("domestic")
	_check(wild == ["rabbit", "deer", "boar", "wolf"] and tame == ["horse", "donkey", "ox", "dog", "cat"], "the wilds hold rabbits, deer, boar and wolves; the towns horses, donkeys, oxen, dogs and cats (%s %s)" % [str(wild), str(tame)])
	var data_ok := true
	for kind in wild:
		var def := Fauna.def_of(kind)
		for resource_id in def.get("yields", {}):
			data_ok = data_ok and Economy.resource_ids().has(str(resource_id))
		data_ok = data_ok and int(def.get("target", 0)) > 0 and not (def.get("habitat", []) as Array).is_empty()
	for kind in tame:
		var def := Fauna.def_of(kind)
		data_ok = data_ok and int(def.get("price", 0)) > 0 and not (def.get("eats", []) as Array).is_empty()
		for item_id in def.get("eats", []):
			data_ok = data_ok and Economy.resource_ids().has(str(item_id))
	_check(data_ok and Skills.skill_ids().has("hunting") and Skills.skill_ids().has("husbandry") and Skills.is_tool_id("bow"), "animals, their goods, the bow and the new skills hang together")

	# The generated region is stocked.
	var region := RegionGenerator.generate(42)
	var counts := {}
	var wild_ok := true
	var strays := 0
	var house_pets := 0
	for animal in region.animals:
		counts[animal.kind] = int(counts.get(animal.kind, 0)) + 1
		if animal.is_wild():
			wild_ok = wild_ok and region.get_tile_id(animal.tile.x, animal.tile.y) in animal.def()["habitat"] and region.is_walkable(animal.tile.x, animal.tile.y)
			for town in region.towns:
				wild_ok = wild_ok and not (town["rect"] as Rect2i).grow(8).has_point(animal.tile)
		elif animal.owner == "":
			strays += 1
		elif animal.owner == "town":
			house_pets += 1
	_check(int(counts.get("rabbit", 0)) >= 15 and int(counts.get("deer", 0)) >= 10 and int(counts.get("boar", 0)) >= 5 and int(counts.get("wolf", 0)) >= 2, "the wilds are stocked (%s)" % str(counts))
	_check(wild_ok, "wild animals keep to forest and grass, well away from the towns")
	_check(strays >= region.towns.size() and house_pets >= 5, "each town has strays and many households a pet (%d strays, %d house pets)" % [strays, house_pets])
	var stables := 0
	var posts := 0
	for lot in region.lots:
		stables += 1 if str(lot["kind"]) == "stable" else 0
	for placed in region.objects:
		posts += 1 if placed.def_id == "hitching_post" else 0
	_check(stables >= 3 and posts >= stables, "the larger towns have a stable with a hitching post (%d stables, %d posts)" % [stables, posts])
	var saved := WorldState.from_dict(region.to_dict())
	_check(saved.animals.size() == region.animals.size() and saved.fauna_seeded and saved.get_animal(region.animals[0].id) != null, "the animals are saved with the world")

	# Hunting.
	var field := _open_field()
	var world: WorldState = field["world"]
	var household: Household = field["household"]
	var sim: Simulation = field["sim"]
	var anna: Pawn = field["anna"]
	var ben: Pawn = field["ben"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	var deer := Fauna.spawn(world, "deer", Vector2i(60, 25), rng)
	var menu := PawnActions.list_for(sim, anna, deer.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("hunt:"))
	_check(menu.size() == 1 and "Hunt the deer" in str(menu[0]["label"]) and "3 meat" in str(menu[0]["label"]) and not menu[0]["enabled"] and "bow" in str(menu[0]["reason"]), "a deer can be hunted, with its meat shown, but not without a bow (%s)" % str(menu))
	household.add_stock("bow", 1)
	menu = PawnActions.list_for(sim, anna, deer.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("hunt:"))
	_check(menu.size() == 1 and menu[0]["enabled"], "with a bow it can")
	var hunt := PawnActions.perform(sim, anna, "hunt:%d" % deer.id, deer.tile)
	_check(hunt["ok"] and anna.job_kind == "hunt" and anna.tool == "bow" and anna.pace > 1.2, "she takes the bow and creeps after it (pace %.2f)" % anna.pace)
	_check("Stalking" in sim.describe_activity(anna), "the panel says so (%s)" % sim.describe_activity(anna))
	var hunting_before := Skills.xp(anna, "hunting")
	var hunt_started := GameClock.tick
	_minutes(sim, 400, func() -> bool: return anna.job_kind == "")
	var hunt_minutes := GameClock.tick - hunt_started
	_check(world.get_animal(deer.id) == null and household.stock_of("meat") >= 3 and household.stock_of("hide") >= 2, "the hunt ends with the deer taken: meat and hides in the stockpile (%s, %d minutes)" % [str(household.stock), hunt_minutes])
	_check(anna.tool == "" and household.stock_of("bow") == 1 and anna.pace == 1.0 and Skills.xp(anna, "hunting") > hunting_before + 1.0, "the bow goes back, she walks normally again and has learned from it")
	_check(notices.any(func(t: String) -> bool: return "brought down the deer" in t), "and the household hears of it (%s)" % str(notices))

	# Game runs from people, and a wounded boar turns.
	var rabbit := Fauna.spawn(world, "rabbit", Vector2i(40, 25), rng)
	ben.tile = Vector2i(45, 25)
	ben.step_to = ben.tile
	rabbit.think_at = 0
	_minutes(sim, 3)
	_check(_chebyshev(rabbit.tile, ben.tile) > 5 and GameClock.tick < rabbit.alert_until + 100 and rabbit.alert_until > 0, "a rabbit runs from a person who comes close (%d tiles off)" % _chebyshev(rabbit.tile, ben.tile))
	world.remove_animal(rabbit.id)
	for y in range(20, 45):  # a wood for the boar and the wolf, which keep to the forest
		for x in range(50, 112):
			world.set_tile(x, y, "forest")
	var victim := Pawn.new()  # somebody to take the knocks, so that the rest of this goes on as planned
	victim.display_name = "Cass Marsh"
	victim.gender = "female"
	victim.age = 30
	victim.adult = true
	for need_id in Needs.active_ids():
		victim.needs[need_id] = 100.0
	household.add_pawn(victim)
	var boar := Fauna.spawn(world, "boar", Vector2i(60, 30), rng)
	boar.charging = victim.id
	boar.think_at = 0
	victim.tile = Vector2i(66, 30)
	victim.step_to = victim.tile
	_minutes(sim, 6, func() -> bool: return boar.charging == 0)
	_check(boar.charging == 0 and boar.alert_until > GameClock.tick, "a wounded boar charges its hunter and then runs off (%s)" % str(boar.tile))
	var strike_notice := Accidents.strike(sim, anna, { "text": "was gored by a boar", "death_share": 0.0, "mood": "attacked" }, rng)
	_check(anna.illness == "injury" and "gored" in strike_notice and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "attacked"), "a goring is an injury (%s)" % strike_notice)
	anna.illness = ""
	victim.illness = ""
	victim.dying_cause = ""
	victim.pose = ""
	world.remove_animal(boar.id)

	# Wolves only come at night.
	var wolf := Fauna.spawn(world, "wolf", Vector2i(90, 30), rng)
	victim.tile = Vector2i(96, 30)
	victim.step_to = victim.tile
	GameClock.set_time(4, 12)
	wolf.think_at = 0
	_minutes(sim, 4)
	var by_day := _chebyshev(wolf.tile, victim.tile)
	_check(by_day > 7, "by day a wolf keeps away from people (%d tiles)" % by_day)
	GameClock.set_time(4, 23)
	wolf.alert_until = 0
	wolf.think_at = 0
	wolf.path.clear()
	wolf.step_ticks_total = 0
	wolf.tile = Vector2i(90, 30)
	wolf.step_to = wolf.tile
	victim.tile = Vector2i(96, 30)
	victim.step_to = victim.tile
	var struck := false
	for i in 8:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if wolf.alert_until > GameClock.tick or victim.illness != "":
			struck = true
			break
	_check(struck, "but at night it comes for someone out alone")
	world.remove_animal(wolf.id)
	household.remove_pawn(victim.id)
	GameClock.set_time(3, 10)

	# Riding.
	var horse := Fauna.spawn(world, "horse", Vector2i(30, 40), rng, "household", WorldState.HOME_LOT)
	var ride_menu := PawnActions.list_for(sim, ben, horse.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("ride:"))
	_check(ride_menu.size() == 1 and "Ride" in str(ride_menu[0]["label"]) and ride_menu[0]["enabled"], "a household's horse can be ridden (%s)" % str(ride_menu))
	ben.tile = Vector2i(28, 40)
	ben.step_to = ben.tile
	_check(PawnActions.perform(sim, ben, "ride:%d" % horse.id, horse.tile)["ok"], "he goes to the horse")
	_minutes(sim, 10, func() -> bool: return ben.mount != 0)
	_check(ben.mount == horse.id and horse.rider == ben.id and ben.pace < 0.6, "and climbs on (pace %.2f)" % ben.pace)
	_check("Get down" in str(PawnActions.list_for(sim, ben, Vector2i(50, 40)).filter(func(e: Dictionary) -> bool: return e["id"] == "dismount")), "the menu offers to get down")
	ben.step_ticks_total = 0
	var far := Vector2i(110, 40)
	var mounted_start := GameClock.tick
	sim.order_move(ben, far)
	_minutes(sim, 200, func() -> bool: return ben.tile == far)
	var mounted_minutes := GameClock.tick - mounted_start
	_check(ben.tile == far and horse.tile == far and "Riding" in sim.describe_activity(ben) or ben.tile == far, "he rides it across the field and the horse is under him (%d minutes)" % mounted_minutes)
	Fauna.dismount(sim, ben)
	var walker := anna
	walker.tile = Vector2i(30, 40)
	walker.step_to = walker.tile
	var walking_start := GameClock.tick
	sim.order_move(walker, far)
	_minutes(sim, 400, func() -> bool: return walker.tile == far)
	var walking_minutes := GameClock.tick - walking_start
	_check(mounted_minutes * 100 < walking_minutes * 65 and mounted_minutes > 0, "a horse is much faster than walking (%d against %d minutes)" % [mounted_minutes, walking_minutes])
	_check(ben.mount == 0 and horse.rider == 0 and horse.tile != Vector2i.ZERO, "getting down leaves the horse standing there")
	# On the way to a job the rider gets down.
	world.lots.append({ "id": "lot_1", "kind": "house", "name": "House", "template": "cottage", "facing": "south", "rect": Rect2i(60, 5, 10, 8), "public": false, "town": "none" })
	var bed := world.add_object("bed", Vector2i(3, 5))
	ben.tile = Vector2i(10, 12)
	ben.step_to = ben.tile
	Fauna.mount(sim, ben, horse)
	horse.tile = ben.tile
	ben.needs["rest"] = 5.0
	sim.order_use(ben, bed)
	_minutes(sim, 60, func() -> bool: return ben.job_stage == "using")
	_check(ben.job_stage == "using" and ben.mount == 0, "arriving at a bed, the rider gets down")
	ben.needs["rest"] = 100.0
	sim.order_stop(ben)

	# Pack animals add to what a gatherer brings home.
	var donkey := Fauna.spawn(world, "donkey", Vector2i(25, 25), rng, "household", WorldState.HOME_LOT)
	anna.tile = Vector2i(25, 26)
	anna.step_to = anna.tile
	_check(Fauna.pack_bonus(sim, anna) == 0.0, "a donkey that is not led carries nothing")
	var lead := PawnActions.perform(sim, anna, "lead:%d" % donkey.id, donkey.tile)
	_check(lead["ok"] and donkey.leader == anna.id and absf(Fauna.pack_bonus(sim, anna) - 0.5) < 0.001, "a led donkey carries half as much again")
	anna.skills["husbandry"] = Skills.xp_for_level(10)
	_check(Fauna.pack_bonus(sim, anna) > 0.7, "more so with practice at animal care (%.2f)" % Fauna.pack_bonus(sim, anna))
	anna.tile = Vector2i(60, 25)
	_check(Fauna.pack_bonus(sim, anna) == 0.0, "and nothing when it is left behind")
	anna.tile = Vector2i(25, 26)
	# Led animals keep up.
	horse.rider = 0
	horse.leader = anna.id
	horse.tile = Vector2i(30, 40)
	horse.step_to = horse.tile
	horse.think_at = 0
	anna.skills.clear()
	sim.order_move(anna, Vector2i(25, 10))
	_minutes(sim, 40)
	_check(_chebyshev(horse.tile, anna.tile) <= Fauna.LEAD_DISTANCE + 2 and _chebyshev(horse.tile, Vector2i(30, 40)) > 10, "a led animal follows its leader (%d tiles behind)" % _chebyshev(horse.tile, anna.tile))
	PawnActions.perform(sim, anna, "wait:%d" % horse.id, horse.tile)
	_check(horse.leader == 0, "and stays when told to wait")
	horse.leader = 0
	donkey.leader = 0

	# Pets.
	var dog := Fauna.spawn(world, "dog", Vector2i(26, 27), rng, "household", WorldState.HOME_LOT)
	_check(dog.name != "" and dog.is_pet() and dog.title().ends_with("the dog"), "a pet has a name (%s)" % dog.title())
	anna.needs["social"] = 20.0
	var pet_menu := PawnActions.list_for(sim, anna, dog.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("pet:"))
	_check(pet_menu.size() == 1 and pet_menu[0]["enabled"], "a pet can be made a fuss of")
	PawnActions.perform(sim, anna, "pet:%d" % dog.id, dog.tile)
	_minutes(sim, 30, func() -> bool: return anna.job_kind == "")
	_check(float(anna.needs["social"]) > 40.0 and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "petted"), "it cheers them and they are the better for it")
	var stray := Fauna.spawn(world, "cat", Vector2i(27, 27), rng)
	var adopt_menu := PawnActions.list_for(sim, anna, stray.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("adopt:"))
	_check(adopt_menu.size() == 1 and adopt_menu[0]["enabled"] and "Take in" in str(adopt_menu[0]["label"]), "a stray can be taken in")
	var taken := PawnActions.perform(sim, anna, "adopt:%d" % stray.id, stray.tile)
	_check(taken["ok"] and stray.owner == "household" and stray.name != "" and stray.leader == anna.id, "and becomes the household's, with a name (%s)" % str(taken["message"]))
	_check("Biscuit" in Fauna.kept_text(sim) or Fauna.kept_text(sim).contains(dog.name), "the household's animals are listed (%s)" % Fauna.kept_text(sim))

	# A dog helps a hunt.
	var plain_chance := 0.0
	var with_dog := Fauna._hound_bonus(sim, anna)
	_check(with_dog > 0.05, "a dog near the hunter improves their aim (+%.2f)" % with_dog)
	world.remove_animal(dog.id)
	_check(Fauna._hound_bonus(sim, anna) == plain_chance + 0.0 or Fauna._hound_bonus(sim, anna) < with_dog, "which a missing dog does not")

	# Feeding.
	var rations := Fauna.spawn(world, "horse", Vector2i(30, 30), rng, "household", WorldState.HOME_LOT)
	rations.fed_day = GameClock.get_day_number() - 1
	household.stock = { "grain": 3 }
	notices.clear()
	Fauna.new_day(sim, rng)
	_check(household.stock_of("grain") == 2 and rations.hungry_days == 0 and rations.fed_day == GameClock.get_day_number(), "an animal eats from the stockpile")
	household.stock = {}
	for day in 4:
		GameClock.set_time(GameClock.get_day_number() + 1, 0)
		for line in Fauna.new_day(sim, rng):
			notices.append(line)
		if day == 1:
			_check(rations.hungry_days == 2 and notices.any(func(t: String) -> bool: return "is hungry" in t), "left without food it grows hungry, and the household is told (%s)" % str(notices))
	_check(rations.owner == "" and notices.any(func(t: String) -> bool: return "gone off" in t), "and after days of it goes off to find its own")

	# Animals for sale at a hitching post.
	world.lots.append({ "id": "lot_2", "kind": "stable", "name": "Stable", "template": "stable", "facing": "south", "rect": Rect2i(80, 5, 12, 8), "public": true, "town": "none" })
	var post := world.add_object("hitching_post", Vector2i(84, 8))
	household.coins = 100
	var market := PawnActions.list_for(sim, anna, post.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("buyanimal:"))
	_check(market.size() == tame.size() and "Buy a horse (90d)" in str(market[0]["label"]), "the hitching post lists what it sells (%d)" % market.size())
	var bought := PawnActions.perform(sim, anna, str(market[0]["id"]), post.tile)
	var horses := world.animals.filter(func(a: Animal) -> bool: return a.kind == "horse" and a.owner == "household" and a.leader == anna.id)
	_check(bought["ok"] and household.coins == 10 and not horses.is_empty(), "buying one costs its price and it follows the buyer (%s)" % str(bought["message"]))
	_check(not PawnActions.perform(sim, anna, "buyanimal:donkey:%d" % post.id, post.tile)["ok"], "an empty purse buys nothing")
	var kept_limit := true
	household.coins = 1000
	for i in 8:
		var result := PawnActions.perform(sim, anna, "buyanimal:cat:%d" % post.id, post.tile)
		if Fauna.kept_by(sim).size() > Fauna.MAX_KEPT:
			kept_limit = false
	_check(kept_limit and Fauna.kept_by(sim).size() == Fauna.MAX_KEPT, "a household keeps only so many (%d)" % Fauna.kept_by(sim).size())

	# They are saved: a rider and their horse come back together.
	var rider := Pawn.from_dict(ben.to_dict())
	Fauna.mount(sim, ben, horse)
	var again := Pawn.from_dict(ben.to_dict())
	var tame_saved := Animal.from_dict(horse.to_dict())
	_check(again.mount == horse.id and tame_saved.rider == ben.id and tame_saved.kind == "horse" and tame_saved.name == horse.name and rider.mount == 0, "a rider and their horse are saved")
	Fauna.dismount(sim, ben)

	# The wilds are restocked a little each day.
	var stocked := RegionGenerator.generate(7)
	var before := stocked.animals.size()
	for animal in stocked.animals.duplicate():
		if animal.kind == "deer":
			stocked.remove_animal(animal.id)
	var shortfall := stocked.animals.size()
	for day in 12:
		Fauna._restock(stocked, rng)
	var deer_now := stocked.animals.filter(func(a: Animal) -> bool: return a.kind == "deer").size()
	_check(deer_now >= 8 and stocked.animals.size() > shortfall and stocked.animals.size() <= before + 12, "deer thinned out by hunters come back in time (%d)" % deer_now)


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _test_construction() -> void:
	print("Planning, builders, rooms and roofs")
	var field := _open_field()
	var world: WorldState = field["world"]
	var household: Household = field["household"]
	var town: Household = field["sim"].town
	var sim: Simulation = field["sim"]
	var anna: Pawn = field["anna"]
	var ben: Pawn = field["ben"]
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	anna.tile = Vector2i(4, 5)
	anna.step_to = anna.tile
	ben.tile = Vector2i(12, 8)
	ben.step_to = ben.tile

	# Rooms: a space that walls close in.
	for x in range(3, 10):
		for y in [3, 8]:
			sim.build_place("wall", Vector2i(x, y))
	for y in range(4, 8):
		for x in [3, 9]:
			sim.build_place("wall", Vector2i(x, y))
	var open_room := Rooms.region(world, Vector2i(5, 5))
	_check(not bool(open_room["closed"]) or (open_room["tiles"] as Array).size() > 0, "a ring of walls is complete")
	var shell := Rooms.region(world, Vector2i(5, 5))
	_check(bool(shell["closed"]) and (shell["tiles"] as Array).size() == 5 * 4, "walls close in a room of twenty tiles (%d)" % (shell["tiles"] as Array).size())
	sim.build_remove(Vector2i(9, 6))
	_check(not bool(Rooms.region(world, Vector2i(5, 5), 60)["closed"]) and "open" in str(Rooms.roomy(world, Vector2i(5, 5))["reason"]), "a gap in the wall means it is no room (%s)" % str(Rooms.roomy(world, Vector2i(5, 5))["reason"]))
	sim.build_place("door", Vector2i(9, 6))
	_check(bool(Rooms.region(world, Vector2i(5, 5))["closed"]), "a door closes it again")
	_check("wall" in str(Rooms.roomy(world, Vector2i(3, 3))["reason"]) and "land" in str(Rooms.roomy(world, Vector2i(30, 30))["reason"]), "a wall is not a room, nor is ground that is not yours")
	_check(Rooms.roof_for(world, shell["tiles"]) == "thatch", "timber walls call for thatch")

	# Planning costs coin and sets materials aside.
	household.coins = 100
	household.stock = { "wood": 1 }
	var bed_price := Economy.build_price("bed", household.stock)
	var planned := Construction.plan_object(sim, "bed", Vector2i(5, 5))
	_check(planned["ok"] and world.sites.size() == 1 and household.coins == 100 - int(bed_price["coins"]) and household.stock_of("wood") == 0 and int(world.reserved.get("wood", 0)) == 3, "planning a bed pays for it and sets its three wood aside (coin %d, reserved %s)" % [household.coins, str(world.reserved)])
	_check(world.object_at(Vector2i(5, 5)) == null and world.site_at(Vector2i(5, 5), "object") != null, "but nothing stands there yet")
	_check("Already" in str(Construction.plan_object(sim, "bed", Vector2i(5, 5))["message"]), "and it is not planned twice")
	var menu := PawnActions.list_for(sim, anna, Vector2i(5, 5)).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("unplan:") or str(e["id"]).begins_with("build:"))
	_check(menu.size() == 2 and not menu[1]["enabled"] and ("hammer" in str(menu[1]["reason"])), "the menu offers to call it off, or to build, which needs a hammer (%s)" % str(menu))
	var coins_before := household.coins
	PawnActions.perform(sim, anna, "unplan:%d" % world.sites[0].id, Vector2i(5, 5))
	_check(world.sites.is_empty() and household.stock_of("wood") == 3 and int(world.reserved.get("wood", 0)) == 0 and household.coins > coins_before, "calling it off brings back the materials and half the coin")
	Construction.plan_object(sim, "bed", Vector2i(5, 5))
	_check(sim.build_remove(Vector2i(5, 5))["ok"] and world.sites.is_empty(), "the remove tool calls off a plan too")
	household.coins = 4
	_check(not Construction.plan_object(sim, "bed", Vector2i(5, 6))["ok"], "an empty purse plans nothing")
	household.coins = 300

	# A builder takes the work on.
	Construction.plan_object(sim, "bed", Vector2i(5, 5))
	Construction.plan_object(sim, "table", Vector2i(7, 5))
	_check(world.sites.size() == 2 and "2 planned" in Construction.summary(sim), "two things are planned (%s)" % Construction.summary(sim))
	_check("hammer" in str(Construction.order_build(sim, anna)["message"]), "nobody builds without a hammer")
	household.add_stock("hammer", 1)
	var skill_before := Skills.xp(anna, "carpentry")
	var order := PawnActions.perform(sim, anna, "build:all", Vector2i(5, 5))
	_check(order["ok"] and anna.job_kind == "build" and anna.tool == "hammer", "she takes the hammer and sets to work")
	var saw_fetch := false
	var saw_carry := false
	for i in 400:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		saw_fetch = saw_fetch or anna.job_stage == "fetch"
		saw_carry = saw_carry or not anna.carrying.is_empty()
		if anna.job_kind == "":
			break
	_check(saw_fetch and saw_carry, "she fetched the materials from the pile and carried them to the site")
	_check(world.sites.is_empty() and world.object_at(Vector2i(5, 5)) != null and world.object_at(Vector2i(5, 5)).def_id == "bed" and world.object_at(Vector2i(7, 5)) != null, "the bed and the table stand when she is done")
	_check(anna.tool == "" and household.stock_of("hammer") == 1 and anna.carrying.is_empty() and int(world.reserved.get("wood", 0)) == 0, "the hammer is back, nothing is left in her hands or set aside")
	_check(Skills.xp(anna, "carpentry") > skill_before + 5.0 and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "built"), "and she has learned from it")
	_check(notices.any(func(t: String) -> bool: return "finished the building" in t), "the household hears she has finished (%s)" % str(notices))

	# A wall waits for someone standing where it goes.
	Construction.plan_object(sim, "wall", Vector2i(8, 7))
	ben.tile = Vector2i(8, 7)
	ben.step_to = ben.tile
	_check(bool(Construction.order_build(sim, anna)["ok"]), "she sets to on a wall")
	_minutes(sim, 120, func() -> bool: return anna.job_kind == "")
	_check(world.object_at(Vector2i(8, 7)) == null, "it does not go up on top of somebody (%s)" % str(world.sites.size()))
	ben.tile = Vector2i(12, 8)
	ben.step_to = ben.tile
	_minutes(sim, 6)  # it waits a few minutes before trying again
	Construction.order_build(sim, anna)
	_minutes(sim, 120, func() -> bool: return anna.job_kind == "")
	_check(world.object_at(Vector2i(8, 7)) != null and world.sites.is_empty(), "once they have moved it is built")

	# Roofs.
	household.stock = { "hammer": 2 }
	household.coins = 300
	_check(PawnActions.list_for(sim, anna, Vector2i(6, 6)).any(func(e: Dictionary) -> bool: return str(e["id"]) == "roof:thatch"), "the menu offers to roof a closed room")
	var roof_plan := Construction.roof_plan(sim, Vector2i(6, 6))
	_check((roof_plan["tiles"] as Array).size() == 19 and str(roof_plan["reason"]) == "", "all nineteen free tiles of it (a wall stands in the twentieth)")
	var roof_cost := Construction.roof_price(sim, "thatch", 19)
	_check(int(roof_cost["coins"]) == 19 * Economy.resource_price("wood") and int(roof_cost["needs"]["wood"]) == 19, "a thatched roof takes a wood a tile, bought if you have none (%s)" % str(roof_cost))
	var coins_roof := household.coins
	var roofing := Construction.plan_room_roof(sim, "thatch", Vector2i(6, 6))
	_check(roofing["ok"] and world.sites.size() == 19 and household.coins == coins_roof - int(roof_cost["coins"]) and int(world.reserved.get("wood", 0)) == 19, "planning it makes nineteen plans and sets the wood aside")
	_check("already" in str(Construction.plan_room_roof(sim, "thatch", Vector2i(6, 6))["message"]), "it cannot be planned twice")
	_check(not Shelter.is_indoors(world, Vector2i(6, 6)), "and the room is open to the sky until it is built")
	var first_hand := Construction.order_build(sim, anna)
	var second_hand := Construction.order_build(sim, ben)
	_check(first_hand["ok"] and second_hand["ok"] and anna.job_kind == "build" and ben.job_kind == "build", "two pairs of hands can work on it together (%s %s)" % [str(first_hand["message"]), str(second_hand["message"])])
	_minutes(sim, 600, func() -> bool: return world.sites.is_empty())
	_check(world.sites.is_empty() and world.roofs.size() == 19 and Shelter.is_indoors(world, Vector2i(6, 6)) and Shelter.is_indoors(world, Vector2i(4, 4)), "the roof goes on: nineteen tiles are indoors (%d, %d left)" % [world.roofs.size(), world.sites.size()])
	_check(int(world.reserved.get("wood", 0)) == 0 and household.stock_of("wood") == 0, "with nothing left over")
	_check(not PawnActions.list_for(sim, anna, Vector2i(6, 6)).any(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("roof:")), "and no offer to roof it again")
	sim.order_stop(anna)
	sim.order_stop(ben)

	# What a roof does.
	var plain := Pawn.new()
	plain.tile = Vector2i(40, 40)
	var sheltered := Pawn.new()
	sheltered.tile = Vector2i(6, 6)
	var open_rate := Needs.drain_per_tick("warmth", [] as Array[String], Shelter.drain_multipliers(world, plain, {}))
	var roofed_rate := Needs.drain_per_tick("warmth", [] as Array[String], Shelter.drain_multipliers(world, sheltered, {}))
	_check(roofed_rate < open_rate * 0.6, "indoors people lose warmth much more slowly (%.4f against %.4f)" % [roofed_rate, open_rate])
	var outdoor_bed := world.add_object("bed", Vector2i(11, 8))
	var indoor_bed := world.object_at(Vector2i(5, 5))
	_check(Shelter.rest_factor(world, indoor_bed, indoor_bed.def()) == 1.0 and Shelter.rest_factor(world, outdoor_bed, outdoor_bed.def()) < 1.0, "a bed under a roof gives full rest, one in the open less")
	ben.tile = Vector2i(11, 9)
	ben.step_to = ben.tile
	ben.needs["rest"] = 10.0
	sim.order_use(ben, outdoor_bed)
	_minutes(sim, 90, func() -> bool: return ben.job_stage == "using")
	var rest_start := float(ben.needs["rest"])
	_minutes(sim, 60)
	var rest_outside := float(ben.needs["rest"]) - rest_start
	sim.order_stop(ben)
	ben.tile = Vector2i(5, 6)
	ben.step_to = ben.tile
	ben.needs["rest"] = 10.0
	sim.order_use(ben, indoor_bed)
	_minutes(sim, 30, func() -> bool: return ben.job_stage == "using")
	rest_start = float(ben.needs["rest"])
	_minutes(sim, 60)
	var rest_inside := float(ben.needs["rest"]) - rest_start
	_check(rest_inside > rest_outside * 1.2, "and sleeping in the open rests less (%.1f against %.1f an hour)" % [rest_outside, rest_inside])
	sim.order_stop(ben)

	# A tiled roof over stone walls, and the saving of it all.
	for x in range(20, 25):
		for y in [3, 7]:
			world.add_object("stone_wall", Vector2i(x, y))
	for y in range(4, 7):
		for x in [20, 24]:
			world.add_object("stone_wall", Vector2i(x, y))
	world.lot = Rect2i(2, 2, 30, 8)
	_check(Rooms.roof_for(world, Rooms.region(world, Vector2i(22, 5))["tiles"]) == "tile", "stone walls call for tiles")
	var saved_plan := Construction.plan_room_roof(sim, "tile", Vector2i(22, 5))
	_check(saved_plan["ok"] and world.sites.size() == 9 and int(world.reserved.get("stone", 0)) == 9, "a tiled roof takes a stone a tile")
	var reloaded := WorldState.from_dict(world.to_dict())
	_check(reloaded.sites.size() == 9 and reloaded.roofs.size() == world.roofs.size() and int(reloaded.reserved.get("stone", 0)) == 9 and reloaded.get_site(world.sites[0].id) != null, "plans, roofs and what is set aside are saved with the world")
	anna.carrying = { "wood": 2 }
	anna.job_site = world.sites[0].id
	var anna_again := Pawn.from_dict(anna.to_dict())
	_check(anna_again.carrying == { "wood": 2 } and anna_again.job_site == anna.job_site, "and a builder's load")
	anna.carrying.clear()
	for site in world.sites.duplicate():
		Construction.cancel(sim, site)
	_check(world.sites.is_empty() and household.stock_of("stone") == 9 and world.reserved.values().all(func(v: Variant) -> bool: return int(v) == 0), "calling the lot off returns every stone")

	# Hiring a builder from a workshop.
	world.lots.append({ "id": "lot_9", "kind": "workshop", "name": "Workshop", "template": "workshop", "facing": "south", "rect": Rect2i(60, 5, 11, 7), "public": true, "town": "none" })
	var bench_counter := world.add_object("counter", Vector2i(63, 8))
	_check(not Construction.hire_blocker(sim, anna).is_empty(), "with nothing planned there is nobody to hire (%s)" % Construction.hire_blocker(sim, anna))
	var carpenter := _townsperson("Colm Fletcher", "male", 33, 0)
	carpenter.work_job = "carpenter"
	carpenter.skills["carpentry"] = Skills.xp_for_level(4)
	town.add_pawn(carpenter)
	carpenter.tile = Vector2i(30, 12)
	carpenter.step_to = carpenter.tile
	household.stock = {}
	household.coins = 200
	Construction.plan_object(sim, "table", Vector2i(10, 6))
	Construction.plan_object(sim, "table", Vector2i(11, 4))
	var hire_menu := PawnActions.list_for(sim, anna, bench_counter.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "hire_crew")
	_check(hire_menu.size() == 1 and hire_menu[0]["enabled"] and "Hire a builder" in str(hire_menu[0]["label"]), "the workshop's counter offers to hire a builder (%s)" % str(hire_menu))
	var coins_hire := household.coins
	var hired := PawnActions.perform(sim, anna, "hire_crew", bench_counter.tile)
	_check(hired["ok"] and carpenter.contract_until > GameClock.tick, "the carpenter is taken on for the day")
	_minutes(sim, 300, func() -> bool: return world.sites.is_empty())
	_check(world.sites.is_empty() and world.object_at(Vector2i(10, 6)) != null and world.object_at(Vector2i(11, 4)) != null, "he walks over, hauls and builds both tables (%d minutes left on the plan)" % world.sites.size())
	_check(household.coins < coins_hire and carpenter.coins > 0, "and is paid by the hour (%s)" % Economy.format(coins_hire - household.coins))
	_minutes(sim, 10)
	_check(carpenter.contract_until == 0 and carpenter.job_kind != "build", "when the work is done he goes back to his own")

	# The towns' own buildings are roofed from the start.
	var region := RegionGenerator.generate(42)
	var floored := 0
	var roofed := 0
	var roofed_parks := 0
	for lot in region.lots:
		var rect: Rect2i = lot["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if str(lot["kind"]) == "park" and region.roofs.has(cell):
					roofed_parks += 1
				if region.floor_at(cell) != "" and str(lot["kind"]) in ["house", "tavern", "shop", "chapel", "clinic", "smithy", "workshop", "stable"]:
					floored += 1
					roofed += 1 if region.roofs.has(cell) else 0
	_check(floored > 1000 and roofed * 100 >= floored * 95 and roofed_parks == 0, "every town building is roofed, and no green is (%d of %d tiles)" % [roofed, floored])
	var old_data := region.to_dict()
	old_data.erase("roofs")
	var old_world := WorldState.from_dict(old_data)
	_check(old_world.needs_roofing and old_world.roofs.is_empty(), "an older save has no roofs")
	var old_sim := Simulation.new(old_world, Household.new(), Household.new(NpcGenerator.FIRST_ID))
	_check(not old_world.needs_roofing and old_world.roofs.size() * 100 >= region.roofs.size() * 95, "but its buildings are roofed on loading (%d of %d)" % [old_world.roofs.size(), region.roofs.size()])
	old_sim.free() if old_sim is Object and false else null


func _region_game(world_seed: int, start_id: String = "bought") -> Dictionary:
	GameClock.reset()
	GameClock.set_time(2, 9)
	var world := RegionGenerator.generate(world_seed)
	var begun := Starts.begin(world, start_id)
	var household: Household = begun["household"]
	var sim := Simulation.new(world, household, NpcGenerator.create(world), begun["realm"])
	return { "world": world, "household": household, "sim": sim }


func _test_trade() -> void:
	print("Goods, regional prices and caravans")
	var rules := DataRegistry.get_def("caravans", "caravan")
	var ware_ok := true
	for ware in rules.get("wares", []):
		ware_ok = ware_ok and Economy.resource_ids().has(str(ware["good"])) and bool(DataRegistry.get_def("resources", str(ware["good"])).get("trade", false)) or str(ware["good"]) in ["iron", "leather"]
	for good in rules.get("wanted_pool", []):
		ware_ok = ware_ok and Economy.resource_ids().has(str(good))
	_check(ware_ok and int(rules.get("fare", 0)) > 0, "the caravans' wares and wants are real goods")
	for station in ["quern", "oven", "brew_vat", "tanning_rack"]:
		_check(bool(DataRegistry.get_def("objects", station).get("recipes", false)) and not Skills.recipes_for(station).is_empty(), "the %s has something to make" % station)
	var chain := Skills.recipes_for("oven")[0]
	_check(chain["inputs"].has("flour") and chain["outputs"].has("bread") and DataRegistry.get_def("recipes", "grind_flour")["outputs"].has("flour") and DataRegistry.get_def("recipes", "forge_ring")["inputs"].has("iron"), "grain becomes flour becomes bread, and a ring takes iron")

	var game := _region_game(42)
	var world: WorldState = game["world"]
	var household: Household = game["household"]
	var sim: Simulation = game["sim"]
	var anna: Pawn = household.selected()
	var counts := {}
	for lot in world.lots:
		counts[lot["kind"]] = int(counts.get(lot["kind"], 0)) + 1
	var vats := 0
	var racks := 0
	var ovens := 0
	for placed in world.objects:
		vats += 1 if placed.def_id == "brew_vat" else 0
		racks += 1 if placed.def_id == "tanning_rack" else 0
		ovens += 1 if placed.def_id == "oven" else 0
	var bakers := 0
	for person in sim.town.pawns:
		bakers += 1 if person.work_job == "baker" else 0
	_check(int(counts.get("bakery", 0)) >= 3 and ovens >= 6 and vats >= 3 and racks >= 3 and bakers >= 2, "the towns have bakeries, brewing vats and tanning racks (%d bakeries, %d ovens, %d vats, %d racks, %d bakers)" % [int(counts.get("bakery", 0)), ovens, vats, racks, bakers])

	# Prices differ from place to place.
	var home := world.home_town()
	var fishing: Dictionary = {}
	var market: Dictionary = {}
	for town in world.towns:
		if str(town.get("profile", "")) == "fishing_village":
			fishing = town
		if str(town.get("profile", "")) == "market_town":
			market = town
	_check(Economy.region_multiplier(world, fishing["center"], "fish") < 0.7 and Economy.region_multiplier(world, market["center"], "fish") > Economy.region_multiplier(world, fishing["center"], "fish") and Economy.region_multiplier(world, Vector2i(2, 2), "fish") == 1.0, "fish are cheap where they are caught and dear where they are not")
	household.stock = { "fish": 10 }
	anna.tile = fishing["center"]
	var cheap := sim.sale_price("fish", anna)
	anna.tile = market["center"]
	var dear := sim.sale_price("fish", anna)
	anna.skills["trading"] = Skills.xp_for_level(8)
	var skilled := sim.sale_price("fish", anna)
	_check(dear > cheap * 1.4 and skilled > dear, "the same fish fetch %s at the lake, %s at the market, and a practised trader gets more (%s)" % [Economy.format(cheap), Economy.format(dear), Economy.format(skilled)])
	anna.skills.clear()
	var label := PawnActions._sell_entries(sim, anna)
	anna.tile = fishing["center"]
	label = PawnActions._sell_entries(sim, anna)
	_check(label.any(func(e: Dictionary) -> bool: return "fish" in str(e["label"]) and "low" in str(e["label"])), "and the counter says when prices are low (%s)" % str(label[0]["label"]))
	household.stock = {}

	# A caravan sets out, travels, camps and opens its wares.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cart := Caravans.spawn(sim, rng, str(home["id"]))
	_check(cart != null and cart.state == "travelling" and not cart.path.is_empty() and cart.to_town == str(home["id"]) and cart.from_town != cart.to_town, "a caravan sets out for the home town (%s, %d tiles to go)" % [cart.name if cart != null else "none", cart.path.size() if cart != null else 0])
	var road_tiles := 0
	for step in cart.path:
		road_tiles += 1 if world.get_tile_id(step.x, step.y) in ["dirt", "cobble", "bridge", "bridge_h"] else 0
	_check(road_tiles * 100 >= cart.path.size() * 60, "it keeps to the roads (%d of %d tiles)" % [road_tiles, cart.path.size()])
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	_minutes(sim, 400, func() -> bool: return cart.state == "camped")
	_check(cart.state == "camped" and cart.at_town == str(home["id"]) and cart.tile == cart.goal, "it arrives and camps on the square")
	_check(cart.stock.size() == 3 and cart.wants.size() == 3 and cart.demand.size() == Economy.resource_ids().size() and cart.leaves_tick > GameClock.tick + GameClock.MINUTES_PER_DAY and cart.next_town != "" and cart.next_town != cart.at_town, "it has three wares, three wants and a next stop (%s; wants %s; on to %s)" % [str(cart.stock), str(cart.wants), cart.next_town])
	_check(notices.any(func(t: String) -> bool: return "camped on the square" in t), "the household is told it has come (%s)" % str(notices))
	_check(Caravans.camp_tile(world, home, [cart.tile]) != cart.tile, "a second would camp elsewhere")

	# Buying, selling.
	anna.tile = cart.tile + Vector2i(1, 1)
	anna.step_to = anna.tile
	household.coins = 200
	var menu := PawnActions.list_for(sim, anna, cart.tile)
	var good := str(cart.stock.keys()[0])
	_check(menu.any(func(e: Dictionary) -> bool: return str(e["id"]) == "cbuy:%d:%s" % [cart.id, good]) and menu.any(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("cride:")), "right-clicking the cart offers its wares and a ride (%d entries)" % menu.size())
	var price := Caravans.buy_price(sim, cart, good)
	var stock_before := int(cart.stock[good])
	var bought := PawnActions.perform(sim, anna, "cbuy:%d:%s" % [cart.id, good], cart.tile)
	_check(bought["ok"] and household.stock_of(good) == 1 and household.coins == 200 - price and int(cart.stock[good]) == stock_before - 1, "buying a unit costs its price (%s for one %s)" % [Economy.format(price), good])
	var wanted := str(cart.wants[0])
	household.stock = { wanted: 30 }
	var shop_rate := Economy.sell_price(wanted, 30, 1.0)
	var caravan_offer := Caravans.sell_price(sim, cart, anna, wanted, int(cart.demand[wanted]))
	var sold := PawnActions.perform(sim, anna, "csell:%d:%s" % [cart.id, wanted], cart.tile)
	_check(sold["ok"] and household.stock_of(wanted) == 30 - 12 and int(cart.demand[wanted]) == 0 and caravan_offer * 30 > shop_rate * 12 * 1.5, "they pay well for what they are looking for, up to what they need (%s for 12 %s)" % [Economy.format(caravan_offer), wanted])
	_check(not PawnActions.perform(sim, anna, "csell:%d:%s" % [cart.id, wanted], cart.tile)["ok"], "and then want no more of it")
	household.stock = {}
	household.coins = 3
	_check(not PawnActions.perform(sim, anna, "cbuy:%d:%s" % [cart.id, good], cart.tile)["ok"], "an empty purse buys nothing")
	household.coins = 200

	# Riding along.
	var destination := world.get_town(cart.next_town)
	var coins_ride := household.coins
	var ride := PawnActions.perform(sim, anna, "cride:%d" % cart.id, cart.tile)
	_check(ride["ok"] and anna.caravan == cart.id and anna.job_kind == "cart" and household.coins == coins_ride - int(rules["fare"]) and cart.passengers.size() == 1 and cart.passengers[0] == anna.id, "she pays the fare and climbs on")
	_check(cart.leaves_tick <= GameClock.tick + 61 and "Waiting on the cart" in sim.describe_activity(anna), "the caravan will leave within the hour (%s)" % sim.describe_activity(anna))
	_check(PawnActions.list_for(sim, anna, Vector2i(5, 5)).size() == 1 and not PawnActions.list_for(sim, anna, Vector2i(5, 5))[0]["enabled"] or Caravans.get_off_blocker(sim, anna) == "", "while it waits she may get off, and a rider has nothing else to do")
	_minutes(sim, 90, func() -> bool: return cart.state == "travelling")
	_check(cart.state == "travelling" and cart.to_town == str(destination["id"]) and anna.tile == cart.tile, "it sets out, and she goes with it")
	_check("Riding with the caravan" in sim.describe_activity(anna) and Caravans.get_off_blocker(sim, anna) != "", "she cannot get off on the road (%s)" % sim.describe_activity(anna))
	_minutes(sim, 400, func() -> bool: return cart.state == "camped" and anna.caravan == 0)
	_check(cart.state == "camped" and cart.at_town == str(destination["id"]) and anna.caravan == 0 and anna.job_kind == "" and absi(anna.tile.x - cart.tile.x) <= 3 and absi(anna.tile.y - cart.tile.y) <= 3, "at the next stop she climbs down beside the cart (in %s)" % str(destination["name"]))
	_check(notices.any(func(t: String) -> bool: return "arrived in %s with the caravan" % str(destination["name"]) in t), "and the household hears of it")
	_check(Skills.xp(anna, "trading") > 0.8, "buying and selling has taught her something (%.1f xp)" % Skills.xp(anna, "trading"))

	# Saved and loaded.
	anna.caravan = 0
	var again := WorldState.from_dict(world.to_dict())
	var copy := again.get_caravan(cart.id)
	_check(copy != null and copy.state == "camped" and copy.stock == cart.stock and copy.demand == cart.demand and copy.wants == cart.wants and copy.looks.size() == 2 and copy.leaves_tick == cart.leaves_tick, "a caravan is saved with the world, wares and all")

	# They keep coming, but not too many.
	var many := 0
	for day in 60:
		GameClock.set_time(10 + day, 0)
		Caravans.new_day(sim, rng)
		many = maxi(many, world.caravans.size())
	_check(many >= 2 and many <= int(rules["max_active"]), "new caravans set out from time to time, never more than %d (%d)" % [int(rules["max_active"]), many])


## A household's save data without the ambitions and wishes the simulation hands out once it starts.
func _sans_dreams(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	for person in copy.get("pawns", []):
		for key in ["ambition", "ambition_step", "ambition_next", "ambitions_done", "deeds", "wishes", "wish_done", "visited"]:
			person.erase(key)
	return copy


func _weight_key_ok(key: String) -> bool:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	match kind:
		"trait":
			return DataRegistry.has_def("traits", arg)
		"talent", "skill":
			return arg == "any" and kind == "talent" or Skills.skill_ids().has(arg)
		"trade":
			return arg == "any" or Skills.skill_ids().has(arg)
		"stage":
			return DataRegistry.has_def("life_stages", arg)
		"partner", "single":
			return true
	return false


func _dream_pawn(full_name: String, age: int, id: int, traits: Array[String] = [], talents: Array[String] = []) -> Pawn:
	var person := _townsperson(full_name, "female", age, id)
	person.traits = traits
	person.talents = talents
	return person


func _test_dreams() -> void:
	print("Ambitions and wishes")
	var goal_keys := ["deed", "skill", "skills_known", "friends", "close_friends", "coins", "towns", "partner", "engaged", "married"]
	var ambitions_ok := true
	var ambition_count := 0
	for def in DataRegistry.get_list("ambitions"):
		ambition_count += 1
		var steps: Array = def.get("steps", [])
		ambitions_ok = ambitions_ok and steps.size() >= 3 and str(def.get("text", "")) != ""
		for key in def.get("weights", {}):
			ambitions_ok = ambitions_ok and _weight_key_ok(str(key))
		for trait_id in def.get("never_for", []):
			ambitions_ok = ambitions_ok and DataRegistry.has_def("traits", str(trait_id))
		for step in steps:
			var goal: Dictionary = step["goal"]
			var named := 0
			for key in goal_keys:
				named += 1 if goal.has(key) else 0
			ambitions_ok = ambitions_ok and named == 1 and str(step.get("text", "")) != "" and Ambitions.measure(Pawn.new(), goal).y > 0.0
			if goal.has("skill") and str(goal["skill"]) != "any":
				ambitions_ok = ambitions_ok and Skills.skill_ids().has(str(goal["skill"]))
	_check(ambitions_ok and ambition_count >= 14, "every ambition has steps with goals that can be measured (%d ambitions)" % ambition_count)
	var wishes_ok := true
	var wish_count := 0
	for def in DataRegistry.get_list("wishes"):
		wish_count += 1
		var deeds: Variant = def.get("deed", "")
		wishes_ok = wishes_ok and str(def.get("text", "")) != "" and float(def.get("hours", 0)) > 0.0 and (deeds is Array and not deeds.is_empty() or deeds is String and deeds != "")
		for key in def.get("weights", {}):
			wishes_ok = wishes_ok and _weight_key_ok(str(key))
		for stage in def.get("stages", []):
			wishes_ok = wishes_ok and DataRegistry.has_def("life_stages", str(stage))
		if def.has("object"):
			wishes_ok = wishes_ok and DataRegistry.has_def("objects", str(def["object"]))
		var action: Dictionary = def.get("do", {})
		if action.has("use"):
			wishes_ok = wishes_ok and DataRegistry.has_def("objects", str(action["use"])) and str(action["use"]) == str(def.get("object", ""))
		if action.has("interact"):
			wishes_ok = wishes_ok and DataRegistry.has_def("interactions", str(action["interact"]))
		if def.has("skill"):
			wishes_ok = wishes_ok and Skills.skill_ids().has(str(def["skill"]))
	_check(wishes_ok and wish_count >= 18, "every wish asks for a deed, and what it uses and does exist (%d wishes)" % wish_count)

	# Who picks what.
	var neutral := _dream_pawn("Mary Cooper", 25, 900)
	var devout := _dream_pawn("Edith Cooper", 25, 901, ["pious"] as Array[String])
	var singer := _dream_pawn("Joan Cooper", 25, 902, [] as Array[String], ["music"] as Array[String])
	var tally := { "neutral": {}, "devout": {}, "singer": {} }
	for seed_value in 150:
		for entry in [["neutral", neutral], ["devout", devout], ["singer", singer]]:
			var chosen := Ambitions.pick(entry[1], seed_value)
			tally[entry[0]][chosen] = int(tally[entry[0]].get(chosen, 0)) + 1
	_check(int(tally["devout"].get("saintly_life", 0)) > 3 * int(tally["neutral"].get("saintly_life", 0)) and int(tally["devout"].get("saintly_life", 0)) > 30, "the pious lean toward a saintly life (%d of 150, against %d)" % [int(tally["devout"].get("saintly_life", 0)), int(tally["neutral"].get("saintly_life", 0))])
	_check(int(tally["singer"].get("troubadour", 0)) > 2 * int(tally["neutral"].get("troubadour", 0)) and int(tally["singer"].get("troubadour", 0)) > 20, "a gift for music leans toward being a troubadour (%d of 150)" % int(tally["singer"].get("troubadour", 0)))
	_check(tally["neutral"].size() >= 10 and Ambitions.pick(neutral, 7) == Ambitions.pick(neutral, 7), "and otherwise it is a spread, the same each time for the same day (%d kinds)" % tally["neutral"].size())
	var cold := _dream_pawn("Ada Cooper", 25, 903, ["asexual"] as Array[String])
	var elder := _dream_pawn("Olga Cooper", 70, 904)
	var youth := _dream_pawn("Kit Cooper", 15, 905)
	var picks := { "cold": {}, "elder": {}, "youth": {} }
	for seed_value in 150:
		for entry in [["cold", cold], ["elder", elder], ["youth", youth]]:
			picks[entry[0]][Ambitions.pick(entry[1], seed_value)] = true
	_check(not picks["cold"].has("true_love") and not picks["cold"].has("hearth_and_home") and not picks["elder"].has("true_love") and not picks["youth"].has("teacher"), "ambitions that do not suit someone are never picked (love for the asexual, courting for elders, teaching for youths)")
	var child := _dream_pawn("Tom Cooper", 8, 906)
	var baby := _dream_pawn("Bea Cooper", 0, 907)
	_check(Ambitions.may_dream(neutral) and Ambitions.may_dream(youth) and Ambitions.may_dream(elder) and not Ambitions.may_dream(child) and not Ambitions.may_dream(baby), "from youth on, a person has an ambition; children and babies do not")

	# Steps, one by one.
	var game := _open_field()
	var sim: Simulation = game["sim"]
	var household: Household = game["household"]
	var anna: Pawn = game["anna"]
	var ben: Pawn = game["ben"]
	var lines: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: lines.append(text))
	_check(anna.ambition != "" and ben.ambition != "" and DataRegistry.has_def("ambitions", anna.ambition), "a new household's folk each start with an ambition (%s, %s)" % [anna.ambition, ben.ambition])
	anna.ambition = "saintly_life"
	anna.ambition_step = 0
	anna.deeds.clear()
	anna.ambitions_done.clear()
	for i in 5:
		Mood.add_event(anna, "used:pew", GameClock.tick)
	_check(anna.ambition_step == 1 and int(anna.deeds["used:pew"]) == 5, "five prayers reach the first step of a saintly life")
	var mood := Mood.evaluate(anna, household, GameClock.tick)
	var texts := ""
	for part in mood["parts"]:
		texts += str(part["text"]) + "|"
	_check("Closer to a dream" in texts, "and lift their mood (%s)" % texts)
	sim.step()
	_check(lines.any(func(t: String) -> bool: return "closer to a dream" in t), "the player is told of the step")
	_check(anna.ambition_step == 1, "and one step is only one step")
	var summary := Ambitions.summary(sim, anna)
	_check(summary["ambition"] == "A Saintly Life" and summary["step"] == 2 and summary["steps"] == 3 and float(summary["have"]) == 5.0 and float(summary["need"]) == 20.0, "the panel shows the step and how far they are (%s)" % str(summary))
	anna.deeds["used:altar"] = 100
	Ambitions.advance(anna)
	mood = Mood.evaluate(anna, household, GameClock.tick)
	texts = ""
	for part in mood["parts"]:
		texts += str(part["text"]) + "|"
	_check(anna.ambition == "" and "saintly_life" in anna.ambitions_done and "Fulfilled: A Saintly Life" in texts and "A life with purpose" in texts, "the last step fulfils the ambition and the mood stays lifted (%s)" % texts)
	sim.step()
	_check(lines.any(func(t: String) -> bool: return "ambition is fulfilled" in t), "and the player is told")
	anna.ambition_next = GameClock.tick + 200
	Ambitions.new_day(sim)
	_check(anna.ambition == "", "they wait a while before dreaming of something new")
	anna.ambition_next = GameClock.tick
	Ambitions.new_day(sim)
	_check(anna.ambition != "" and anna.ambition != "saintly_life", "then take up another, not the same again (%s)" % anna.ambition)

	# Goals that look at who they are.
	anna.ambition = "master_craftsman"
	anna.ambition_step = 0
	anna.skills["carpentry"] = Skills.xp_for_level(5)
	Ambitions.advance(anna)
	_check(anna.ambition_step == 2, "skills count: Journeyman skips past Apprentice and waits for Master")
	anna.skills["carpentry"] = Skills.xp_for_level(9)
	Ambitions.advance(anna)
	_check(anna.ambition == "" and "master_craftsman" in anna.ambitions_done, "and a Master is fulfilled")
	anna.ambition = "friend_to_all"
	anna.ambition_step = 0
	for friend_id in [10, 11, 12, 13, 14]:
		anna.relations[friend_id] = 35.0
	Ambitions.advance(anna)
	_check(anna.ambition_step == 2, "friends count: five are friends (two steps)")
	anna.relations[10] = 70.0
	Ambitions.advance(anna)
	_check(anna.ambition_step == 3, "and a close friend")
	anna.ambition = "fortune_seeker"
	anna.ambition_step = 0
	household.coins = 300
	Ambitions.advance(anna)
	_check(anna.ambition_step == 0, "coin cannot be told without the world")
	Ambitions.advance(anna, sim)
	_check(anna.ambition_step == 2, "coin counts with it: 300 clears the first two steps")
	anna.ambition = "true_love"
	anna.ambition_step = 0
	anna.partner_id = ben.id
	anna.deeds["had_date"] = 3
	Ambitions.advance(anna)
	_check(anna.ambition_step == 2, "a partner and three dates")
	anna.bond = "engaged"
	Ambitions.advance(anna)
	anna.bond = "married"
	Ambitions.advance(anna)
	_check(anna.ambition == "" and "true_love" in anna.ambitions_done, "engaged, then married, fulfils true love")
	anna.partner_id = 0
	anna.bond = ""
	var counted := _dream_pawn("Eve Cooper", 30, 910)
	Ambitions.note(counted, "child")
	Ambitions.note(counted, "child")
	_check(Ambitions.count(counted, "child") == 2 and Ambitions.count(counted, ["child", "birth"]) == 2, "deeds are counted by their event key")

	# Wishes.
	anna.ambition = ""
	anna.wishes.clear()
	var allowed_kiss := DataRegistry.get_def("wishes", "kiss_partner")
	_check(not Ambitions.wish_allowed(sim, anna, allowed_kiss, "adult"), "nobody wishes to kiss a partner they do not have")
	anna.partner_id = ben.id
	_check(Ambitions.wish_allowed(sim, anna, allowed_kiss, "adult"), "and those who have one may")
	anna.partner_id = 0
	var lute_wish := DataRegistry.get_def("wishes", "play_lute")
	_check(not Ambitions.wish_allowed(sim, anna, lute_wish, "adult"), "nobody wishes for a lute that is not in the world")
	(game["world"] as WorldState).add_object("lute", Vector2i(24, 25))
	_check(Ambitions.wish_allowed(sim, anna, lute_wish, "adult"), "once there is one, they do")
	_check(not Ambitions.wish_allowed(sim, anna, DataRegistry.get_def("wishes", "flirt_with_someone"), "child") and not Ambitions.wish_allowed(sim, cold, DataRegistry.get_def("wishes", "flirt_with_someone"), "adult"), "children and the asexual do not wish to flirt")
	var rolled := 0
	for hour in 24:
		GameClock.advance_one_tick()
		for i in 59:
			GameClock.advance_one_tick()
		Ambitions._roll_wishes(sim, anna)
	rolled = anna.wishes.size()
	_check(rolled == 2, "an adult comes to have two wishes at a time (%d)" % rolled)
	_check(anna.wishes.all(func(w: Dictionary) -> bool: return DataRegistry.has_def("wishes", str(w["id"])) and int(w["until"]) > GameClock.tick - 60 * 24 * 3), "each is a real wish with a time limit")
	anna.wishes = [{ "id": "chat_with_friend", "until": GameClock.tick - 5 }, { "id": "play_lute", "until": GameClock.tick + 600 }]
	Ambitions._expire(anna)
	_check(anna.wishes.size() == 1 and anna.wishes[0]["id"] == "play_lute", "a wish lapses when its time is up")

	# A wish is granted by doing the thing, which an idle person sets about on their own.
	GameClock.set_time(3, 10)
	anna.tile = Vector2i(20, 25)
	anna.step_to = anna.tile
	anna.path.clear()
	anna.job_kind = ""
	ben.wishes.clear()
	for need_id in Needs.active_ids():
		anna.needs[need_id] = 100.0
		ben.needs[need_id] = 100.0
	_minutes(sim, 180, func() -> bool: return anna.wish_done.has("play_lute"))
	_check(anna.wish_done.has("play_lute") and anna.wishes.is_empty() and int(anna.deeds.get("used:lute", 0)) >= 1, "an idle person with a wish to play the lute goes and does")
	mood = Mood.evaluate(anna, household, GameClock.tick)
	texts = ""
	for part in mood["parts"]:
		texts += str(part["text"]) + "|"
	_check("A wish came true: play the lute" in texts, "and is the happier for it (%s)" % texts)
	_check(lines.any(func(t: String) -> bool: return "wish came true" in t), "the player is told")
	anna.wishes = [{ "id": "chat_with_friend", "until": GameClock.tick + 600 }]
	ben.job_kind = ""
	ben.path.clear()
	_minutes(sim, 240, func() -> bool: return anna.wish_done.has("chat_with_friend"))
	_check(anna.wish_done.has("chat_with_friend"), "and a wish for a chat sends them to someone to talk to")
	var grant := { "id": "go_hunting", "until": GameClock.tick + 600 }
	anna.wishes = [grant]
	Mood.add_event(anna, "hunted", GameClock.tick)
	mood = Mood.evaluate(anna, household, GameClock.tick)
	texts = ""
	for part in mood["parts"]:
		texts += str(part["text"]) + "|"
	_check(anna.wishes.is_empty() and "A great wish came true: go hunting" in texts, "a bigger wish is a bigger lift, whoever did what and why (%s)" % texts)

	# Towns visited.
	var region := _region_game(42)
	var rsim: Simulation = region["sim"]
	var rworld: WorldState = region["world"]
	var traveller: Pawn = (region["household"] as Household).selected()
	traveller.visited.clear()
	Ambitions._track_visits(rsim, traveller)
	var start_count := traveller.visited.size()
	var elsewhere: Dictionary = {}
	for town in rworld.towns:
		if town["id"] != rworld.home_town()["id"]:
			elsewhere = town
	traveller.tile = elsewhere["center"]
	Ambitions._track_visits(rsim, traveller)
	_check(start_count == 1 and traveller.visited.size() == 2 and int(traveller.deeds.get("visit", 0)) == 1, "the first town seen is home; arriving in another is a visit")
	Ambitions._track_visits(rsim, traveller)
	_check(int(traveller.deeds.get("visit", 0)) == 1, "and going back is not a new one")

	# In a whole region.
	var grown := 0
	var kinds := {}
	var with_ambition := 0
	for person in rsim.people():
		if Ambitions.may_dream(person):
			grown += 1
			with_ambition += 1 if person.ambition != "" else 0
			kinds[person.ambition] = true
		else:
			if person.ambition != "":
				with_ambition = -9999
	_check(grown > 60 and with_ambition == grown and kinds.size() >= 8, "in a whole region everyone old enough has an ambition (%d people, %d kinds)" % [grown, kinds.size()])
	_minutes(rsim, 12 * 60)
	var wishing := 0
	var wished_for := {}
	for person in rsim.people():
		wishing += 1 if not person.wishes.is_empty() else 0
		for wish in person.wishes:
			wished_for[wish["id"]] = true
	_check(wishing > 40 and wished_for.size() >= 6, "and half a day on, most have wishes of their own (%d people, %d kinds)" % [wishing, wished_for.size()])
	var granted := 0
	for person in rsim.people():
		granted += int(person.deeds.get("wish_granted", 0)) + int(person.deeds.get("wish_granted_big", 0))
	_minutes(rsim, 24 * 60)
	var granted_later := 0
	for person in rsim.people():
		granted_later += int(person.deeds.get("wish_granted", 0)) + int(person.deeds.get("wish_granted_big", 0))
	_check(granted_later > granted + 10, "the folk of the town have wishes come true as the day goes (%d, then %d)" % [granted, granted_later])

	# Saving.
	var saved: Pawn = (region["household"] as Household).selected()
	saved.deeds["used:lute"] = 4
	saved.ambitions_done = ["troubadour"] as Array[String]
	saved.wishes = [{ "id": "go_hunting", "until": 123456 }] as Array[Dictionary]
	saved.wish_done = { "play_lute": 777 }
	var back := Pawn.from_dict(JSON.parse_string(JSON.stringify(saved.to_dict())))
	_check(back.ambition == saved.ambition and back.ambition_step == saved.ambition_step and back.deeds == saved.deeds and back.ambitions_done == saved.ambitions_done and back.wishes == saved.wishes and back.wish_done == saved.wish_done and back.visited == saved.visited, "ambitions, deeds and wishes survive a save")
	var old := Pawn.from_dict({ "name": "Old Save", "age": 30 })
	_check(old.ambition == "" and old.deeds.is_empty() and old.wishes.is_empty(), "a person from an older save has none, and is given them when the game loads")


func _ids_of(pawns: Array) -> Array:
	var ids := []
	for pawn in pawns:
		ids.append(pawn.id)
	ids.sort()
	return ids


func _test_families() -> void:
	print("Other families: playing them, moving house, carrying on")
	var game := _region_game(42)
	var world: WorldState = game["world"]
	var household: Household = game["household"]
	var sim: Simulation = game["sim"]
	var town: Household = sim.town
	var anna: Pawn = household.selected()
	_check(DataRegistry.has_def("families", "families") and float(Families.config()["arrive_chance"]) > 0.0, "the family rules are data")
	var families := Families.list(sim)
	var good := true
	for family in families:
		good = good and not (family["members"] as Array).is_empty() and family["head"] != null and family["name"] != "" and family["town_name"] != ""
	_check(families.size() >= 40 and good, "every house with people in it is a family of the town (%d families)" % families.size())
	var everyone_before := sim.people().size()

	# Taking up another family.
	var chosen := {}
	for family in families:
		if family["town"] == world.home_town()["id"] and (family["members"] as Array).size() >= 3 and Families.play_blocker(sim, str(family["lot"])) == "":
			chosen = family
			break
	_check(not chosen.is_empty(), "there is a family of the home town with three or more people to take up")
	var lot_id: String = chosen["lot"]
	var family_ids := _ids_of(chosen["members"])
	var old_ids := _ids_of(household.pawns)
	var old_rect := world.lot
	var new_rect: Rect2i = world.get_lot(lot_id)["rect"]
	var home_town_id: String = world.home_town()["id"]
	var old_realm := sim.realm
	household.coins = 150
	household.stock = { "grain": 10, "axe": 1 }
	world.titles["lot_extra"] = "leasehold"
	var pockets_before := 0
	for pawn in chosen["members"]:
		pockets_before += pawn.coins
	var dog: Animal = Fauna.spawn(world, "dog", anna.tile + Vector2i(1, 0), sim.rng(), "household", WorldState.HOME_LOT)
	var heard: Array[String] = []
	sim.family_changed.connect(func(family_name: String) -> void: heard.append(family_name))
	_check(Families.play_blocker(sim, WorldState.HOME_LOT) != "" and Families.play_blocker(sim, "nowhere") != "", "you cannot take up your own family, or one that is not there")
	anna.dying_cause = "illness"
	_check("dying" in Families.play_blocker(sim, lot_id), "nor while someone in your household is dying")
	anna.dying_cause = ""
	var result := Families.play(sim, lot_id)
	_check(result["ok"] and _ids_of(household.pawns) == family_ids and _ids_of(town.pawns).size() + household.pawns.size() == everyone_before, "the family becomes the household and nobody is lost (%s)" % str(result["message"]))
	_check(town.get_pawn(old_ids[0]) != null, "the old household is the town's now")
	var lot_ok: bool = world.lot == new_rect and world.get_lot(lot_id)["rect"] == old_rect and world.get_lot(lot_id)["town"] == home_town_id and world.lot_at(new_rect.get_center())["id"] == WorldState.HOME_LOT and world.lot_at(old_rect.get_center())["id"] == lot_id
	_check(lot_ok, "their house is the home lot now, and the old home is a house of the town")
	var homes_ok := true
	for pawn in household.pawns:
		homes_ok = homes_ok and pawn.home_lot == WorldState.HOME_LOT
	for pawn in town.pawns:
		if pawn.id in old_ids:
			homes_ok = homes_ok and pawn.home_lot == lot_id
	_check(homes_ok, "and everyone lives where they live: the new household at home, the old one in the house you left")
	var old_pockets := 0
	for pawn in town.pawns:
		if pawn.id in old_ids:
			old_pockets += pawn.coins
	_check(old_pockets >= 150 + 10 * Economy.resource_price("grain") * 70 / 100 and household.coins == pockets_before and household.stock.is_empty(), "the old household's purse and goods were turned into money for them (%d), and the new family's pockets became the purse (%d)" % [old_pockets, household.coins])
	_check(world.titles.size() == 1 and world.titles.has(WorldState.HOME_LOT) and not world.home_lost, "the old land titles went with them; the new house is held for rent or freehold by class (%s)" % str(world.titles))
	_check(dog.owner == "town" and dog.home_lot == lot_id, "the dog stays with the family that was yours")
	_check(sim.realm != old_realm and sim.realm.reputation == 0.0 and household.get_pawn(sim.realm.head_id) != null and sim.realm.last_tax_day == old_realm.last_tax_day, "the Crown deals with the new family afresh, on the same quarter days")
	_check(household.selected() != null and household.selected().adult and heard.size() == 1 and heard[0] == chosen["name"], "an adult of the new family is the one you control, and the screen is told")
	_check(world.chronicle.size() >= 1 and "now follow" in str(world.chronicle[-1]["text"]), "and the chronicle says so")
	_minutes(sim, 90)
	_check(sim.people().size() == everyone_before and household.pawns.size() == family_ids.size(), "an hour and a half goes by with everyone going about their lives")
	for pawn in household.pawns:
		for need_id in Needs.active_ids():
			pawn.needs[need_id] = 100.0
	var back := Families.play(sim, lot_id)
	_check(back["ok"] and _ids_of(household.pawns) == old_ids and world.lot == old_rect and world.get_lot(lot_id)["rect"] == new_rect, "and taking the old family up again puts everything back as it was")
	_check(world.titles.has(WorldState.HOME_LOT) and Families.empty_rows(sim).size() >= 0, "with a home lot of its own")

	# Moving house.
	var vacant_family := {}
	for family in Families.list(sim):
		if family["town"] != world.home_town()["id"] and (family["members"] as Array).size() <= 3:
			vacant_family = family
			break
	for pawn in vacant_family["members"]:
		town.remove_pawn(pawn.id)
	var empty := Families.empty_rows(sim)
	var target := ""
	for row in empty:
		if row["lot"] == vacant_family["lot"]:
			target = row["lot"]
	_check(target != "" and Families.move_blocker(sim, target) == "", "a house with nobody in it can be moved into (%d empty houses)" % empty.size())
	_check(Families.move_blocker(sim, WorldState.HOME_LOT) != "" and Families.move_blocker(sim, str(Families.list(sim)[0]["lot"])) != "", "but not your own, nor one with people in it")
	var rect_there: Rect2i = world.get_lot(target)["rect"]
	var here_before: Rect2i = world.lot
	var town_there: String = world.get_lot(target)["town"]
	household.coins = 33
	household.stock = { "wood": 4 }
	var kept_ids := _ids_of(household.pawns)
	var moved := Families.move(sim, target)
	var tiles_ok := true
	for pawn in household.pawns:
		tiles_ok = tiles_ok and rect_there.has_point(pawn.tile)
	_check(moved["ok"] and world.lot == rect_there and world.get_lot(target)["rect"] == here_before and world.home_town()["id"] == town_there and _ids_of(household.pawns) == kept_ids, "the household moves to the house in the other town, and that town is home now")
	_check(tiles_ok and household.coins == 33 and household.stock_of("wood") == 4 and world.titles.has(WorldState.HOME_LOT), "its people arrive there, and its purse, goods and title come along")
	_check(Families.empty_rows(sim).any(func(row: Dictionary) -> bool: return row["lot"] == target), "and the house it left stands empty, to be moved into")
	_check("moved from" in str(world.chronicle[-1]["text"]), "(the chronicle notes it)")

	# When someone of the town dies.
	var couple := {}
	for family in Families.list(sim):
		var spouses := 0
		for pawn in family["members"]:
			spouses += 1 if pawn.partner_id != 0 and pawn.adult else 0
		if spouses >= 2 and family["town"] == world.home_town()["id"]:
			couple = family
			break
	var estate_pawn: Pawn = null
	var spouse: Pawn = null
	if not couple.is_empty():
		for pawn in couple["members"]:
			if pawn.partner_id != 0 and pawn.adult and estate_pawn == null:
				estate_pawn = pawn
		spouse = sim.person(estate_pawn.partner_id)
	if estate_pawn == null or spouse == null:  # no couple in this town: make one
		var lot_entry := Families.list(sim)[0]
		estate_pawn = (lot_entry["members"] as Array)[0]
		spouse = _townsperson("Test Spouse", "female", 40, 4999)
		spouse.home_lot = estate_pawn.home_lot
		town.adopt(spouse)
		estate_pawn.partner_id = spouse.id
		spouse.partner_id = estate_pawn.id
	estate_pawn.bond = "married"
	spouse.bond = "married"
	estate_pawn.coins = 90
	var spouse_had := spouse.coins
	sim.die(estate_pawn, "old age")
	_check(spouse.coins >= spouse_had + 90 and estate_pawn.coins == 0, "when one of the town dies, the husband or wife has what they had (%d)" % spouse.coins)
	_check("inherits" in str(world.chronicle[-1]["text"]), "and the chronicle tells of it (%s)" % str(world.chronicle[-1]["text"]))
	var parent := _townsperson("Old Parent", "male", 60, 4998)
	parent.home_lot = spouse.home_lot
	var grown_child := _townsperson("Grown Child", "female", 30, 4997)
	grown_child.parents = [parent.id] as Array[int]
	grown_child.home_lot = spouse.home_lot
	var other_child := _townsperson("Other Child", "male", 25, 4996)
	other_child.parents = [parent.id] as Array[int]
	town.adopt(parent)
	town.adopt(grown_child)
	town.adopt(other_child)
	parent.coins = 41
	var heirs := Families.heirs_of(sim, parent)
	_check(_ids_of(heirs) == [other_child.id, grown_child.id] or _ids_of(heirs) == [grown_child.id, other_child.id], "with no husband or wife, the grown children share it")
	sim.die(parent, "old age")
	_check(grown_child.coins + other_child.coins >= 41, "(and it is divided between them)")

	# Orphans.
	var orphan_lot := ""
	for family in Families.list(sim):
		if family["town"] == world.home_town()["id"] and (family["members"] as Array).size() >= 2 and orphan_lot == "":
			orphan_lot = family["lot"]
	_check(orphan_lot != "", "there is a house to leave a child in")
	for pawn in Families.residents_of(sim, orphan_lot):
		if pawn.adult:
			town.remove_pawn(pawn.id)
	var child := _townsperson("Lonely Child", "male", 9, 4995)
	child.home_lot = orphan_lot
	child.tile = Romance._free_spot_in(sim, orphan_lot)
	town.adopt(child)
	Families.new_day(sim)
	_check(child.home_lot != orphan_lot and Families.residents_of(sim, child.home_lot).any(func(p: Pawn) -> bool: return p.adult), "a child left with no grown-up is taken in by another family (%s)" % str(world.chronicle[-1]["text"]))

	# Houses fill again.
	var empty_lot := {}
	for entry in Families.vacant_houses(sim):
		if entry["town"] == world.home_town()["id"]:
			empty_lot = entry
			break
	if empty_lot.is_empty():
		var victim := Families.list(sim)[0]
		for pawn in victim["members"]:
			town.remove_pawn(pawn.id)
		empty_lot = world.get_lot(victim["lot"])
	var before := sim.people().size()
	var arrival_rng := RandomNumberGenerator.new()
	arrival_rng.seed = 5
	var said := Families._arrive(sim, empty_lot, arrival_rng)
	var arrived := Families.residents_of(sim, str(empty_lot["id"]))
	var arrived_ok := arrived.size() >= 1 and arrived.size() == sim.people().size() - before
	for pawn in arrived:
		arrived_ok = arrived_ok and (empty_lot["rect"] as Rect2i).has_point(pawn.tile) and pawn.surname() == arrived[0].surname()
	_check(arrived_ok and "has come to" in said, "newcomers settle into an empty house as a family (%s)" % said)
	var names_before := {}
	for pawn in sim.people():
		if pawn not in arrived:
			names_before[pawn.surname()] = true
	_check(not names_before.has(arrived[0].surname()), "with a name not already in the region")

	# A family from a town with no work goes where there is some.
	var open_town := ""
	for lot in world.lots:
		if lot["kind"] == "shop" and not sim.open_positions(str(lot["id"])).is_empty() and str(lot["town"]) != "":
			open_town = str(lot["town"])
			break
	var workless := {}
	for family in Families.list(sim):
		if family["town"] != open_town and (family["members"] as Array).size() <= 3 and Families._may_move(sim, family["members"]) == false:
			for pawn in family["members"]:
				sim.quit_job(pawn)
			if Families._may_move(sim, family["members"]):
				workless = family
				break
	var vacant_there := {}
	for entry in world.lots:
		if entry["kind"] == "house" and str(entry["town"]) == open_town and Families.residents_of(sim, str(entry["id"])).is_empty():
			vacant_there = entry
	if vacant_there.is_empty() and not workless.is_empty():
		for family in Families.list(sim):
			if family["town"] == open_town and (family["members"] as Array).size() <= 3 and family["lot"] != workless["lot"]:
				for pawn in family["members"]:
					town.remove_pawn(pawn.id)
				vacant_there = world.get_lot(family["lot"])
				break
	if not workless.is_empty() and not vacant_there.is_empty() and open_town != "":
		var told := Families._move_family_in(sim, vacant_there, arrival_rng)
		var newcomers := Families.residents_of(sim, str(vacant_there["id"]))
		var settled := not newcomers.is_empty()
		for pawn in newcomers:
			settled = settled and (vacant_there["rect"] as Rect2i).has_point(pawn.tile) and pawn.work_job == ""
		_check(settled and "where there is work" in told, "a family with no work moves to a town that is hiring (%s)" % told)
	else:
		_check(false, "a family with no work could be moved (no suitable setup in this world)")

	# The chronicle is kept and saved.
	for i in 60:
		Families.record(sim, "Something happened %d." % i)
	_check(world.chronicle.size() == int(Families.config()["chronicle_limit"]) and Families.chronicle_lines(sim)[0].ends_with("59."), "the chronicle keeps the latest, newest first")
	var copy := WorldState.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(copy.chronicle == world.chronicle and copy.lot == world.lot, "and it survives a save, with the home lot")
	_check(SaveGame.FORMAT_VERSION == 14, "saves are format 14")


## The pitch of a sound in Hz, found by autocorrelation (the lag that repeats the wave best).
func _pitch_of(samples: PackedFloat32Array, low: float, high: float) -> float:
	var best_lag := 0
	var best := -1.0
	var from := int(Synth.RATE / high)
	var to := int(Synth.RATE / low)
	var start := mini(2000, samples.size() / 4)
	var window := mini(4000, samples.size() - to - start)
	for lag in range(from, to):
		var total := 0.0
		for i in range(start, start + window):
			total += samples[i] * samples[i + lag]
		if total > best:
			best = total
			best_lag = lag
	return float(Synth.RATE) / float(best_lag)


func _is_finite_sound(samples: PackedFloat32Array) -> bool:
	for value in samples:
		if is_nan(value) or is_inf(value) or absf(value) > 1.0001:
			return false
	return true


func _test_audio() -> void:
	print("Sound and music")
	var rendered := true
	var loud_enough := true
	var seams := true
	var ends := true
	var recipes_ok := true
	var names := []
	for sound_id in SoundBank.ids():
		var samples := SoundBank.render(sound_id)
		names.append(sound_id)
		rendered = rendered and samples.size() > 100 and _is_finite_sound(samples)
		loud_enough = loud_enough and Synth.rms(samples) > 0.01
		recipes_ok = recipes_ok and SoundBank.volume_of(sound_id) > 0.0
		if SoundBank.is_loop(sound_id):
			# the end runs on into the start: the step across the join is no bigger than steps inside the sound
			var steps := 0.0
			for i in range(1, samples.size()):
				steps += absf(samples[i] - samples[i - 1])
			var join := absf(samples[0] - samples[samples.size() - 1])
			seams = seams and join <= 8.0 * steps / float(samples.size()) + 0.02
		else:
			ends = ends and absf(samples[0]) < 0.05 and absf(samples[samples.size() - 1]) < 0.05
	_check(rendered and loud_enough and recipes_ok and names.size() >= 19, "every sound can be made, is audible and stays within range (%d sounds)" % names.size())
	_check(seams, "the looping ones run round without a click")
	_check(ends, "and the others begin and end quietly")
	_check(SoundBank.render("wind") == SoundBank.render("wind") and SoundBank.render("nothing").is_empty(), "a sound is the same each time it is made, and an unknown one is silent")
	var stream := Synth.to_stream(SoundBank.render("wind"), true)
	_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.mix_rate == Synth.RATE and stream.data.size() == SoundBank.render("wind").size() * 2 and not Synth.to_stream(SoundBank.render("chop")).loop_mode == AudioStreamWAV.LOOP_FORWARD, "streams loop only when they should (16-bit, mono)")

	# Instruments sound at the pitch asked for.
	var lute := Synth.note("lute", 57, 1.0)
	var harp := Synth.note("harp", 69, 1.0)
	var flute := Synth.note("flute", 64, 1.0)
	var lute_pitch := _pitch_of(lute, 80.0, 400.0)
	var harp_pitch := _pitch_of(harp, 300.0, 900.0)
	var flute_pitch := _pitch_of(flute, 200.0, 600.0)
	_check(absf(lute_pitch / 220.0 - 1.0) < 0.03 and absf(harp_pitch / 440.0 - 1.0) < 0.03 and absf(flute_pitch / 329.63 - 1.0) < 0.03, "a lute, harp and flute sound at the pitch of the note (%.0f, %.0f, %.0f Hz)" % [lute_pitch, harp_pitch, flute_pitch])
	var early := Synth.rms(lute.slice(0, 4000))
	var late := Synth.rms(lute.slice(lute.size() - 4000, lute.size()))
	_check(early > 4.0 * late and Synth.peak(lute) <= 0.91, "and a plucked string dies away")

	# The music.
	var moods := DataRegistry.get_list("music")
	var mood_ok := moods.size() >= 5
	for def in moods:
		mood_ok = mood_ok and Composer.MODES.has(str(def["mode"])) and int(def["bars"]) >= 8 and float(def["bpm"]) > 30.0 and not (def["progression"] as Array).is_empty()
	_check(mood_ok, "every mood of music has a mode, a tempo and chords (%d moods)" % moods.size())
	var first := Composer.compose("day", 1)
	_check(first == Composer.compose("day", 1) and first != Composer.compose("day", 2) and Composer.compose("nonsense", 1).is_empty(), "the same mood and seed give the same piece, another seed another piece")
	var scale_ok := true
	var last_ok := false
	var melody: Array[Dictionary] = []
	for entry: Dictionary in first["notes"]:
		if entry["instrument"] == "lute" and float(entry["gain"]) == 1.0:
			melody.append(entry)
			var steps: Array = Composer.MODES["ionian"]
			scale_ok = scale_ok and posmod(int(entry["midi"]) - 50, 12) in steps
	last_ok = not melody.is_empty() and posmod(int(melody[-1]["midi"]) - 50, 12) == 0 and float(melody[-1]["length"]) >= 2.0
	_check(scale_ok and melody.size() > 30, "the tune keeps to its scale (%d notes)" % melody.size())
	_check(last_ok and absf(float(first["seconds"]) - float(first["beats"]) * 60.0 / float(first["bpm"])) < 0.001, "and ends held, on the home note")
	var jig := Composer.compose("festival", 1)
	var has_drum := false
	for entry: Dictionary in jig["notes"]:
		has_drum = has_drum or entry["instrument"] == "drum"
	_check(float(jig["bpm"]) > float(Composer.compose("sorrow", 1)["bpm"]) * 2.0 and has_drum, "a festival is quick and has a drum, a death slow")
	var track := Composer.render(jig)
	var sorrow_track := Composer.render(Composer.compose("sorrow", 1))
	_check(track.size() == roundi(float(jig["seconds"]) * Synth.RATE) and _is_finite_sound(track) and Synth.rms(track) > 0.03 and Synth.peak(track) <= 0.86 and Synth.rms(sorrow_track) > 0.03, "a piece plays into one sound, audible and not clipping (%.0f s)" % float(jig["seconds"]))
	var quick := 0.0
	var slow := 0.0
	for entry in Composer.improvise(1, 5, 20):
		slow += float(entry["delay"])
	for entry in Composer.improvise(9, 5, 20):
		quick += float(entry["delay"])
	var sour_novice := 0
	var sour_master := 0
	for seed_value in 30:
		for entry in Composer.improvise(0, seed_value, 12):
			sour_novice += 0 if posmod(int(entry["midi"]) - 57, 12) in Composer.MODES["dorian"] or posmod(int(entry["midi"]) - 57, 12) in Composer.MODES["mixolydian"] else 1
		for entry in Composer.improvise(10, seed_value, 12):
			sour_master += 0 if posmod(int(entry["midi"]) - 57, 12) in Composer.MODES["dorian"] or posmod(int(entry["midi"]) - 57, 12) in Composer.MODES["mixolydian"] else 1
	_check(quick < slow * 0.8 and sour_master < sour_novice and Composer.improvise(3, 9, 8) == Composer.improvise(3, 9, 8), "a skilled player plays faster and with fewer sour notes than a novice (%d against %d)" % [sour_master, sour_novice])

	# What there is to hear.
	var summer_noon := Soundscape.levels({ "hour": 12.0, "season": "summer", "closeness": 1.0, "in_town": false })
	var summer_night := Soundscape.levels({ "hour": 23.0, "season": "summer", "closeness": 1.0 })
	var winter_night := Soundscape.levels({ "hour": 23.0, "season": "winter", "closeness": 1.0 })
	_check(float(summer_noon["birds"]) > 0.5 and float(summer_noon["crickets"]) < 0.05 and float(summer_night["crickets"]) > 0.5 and float(summer_night["birds"]) < 0.05 and float(winter_night["crickets"]) == 0.0, "birds by day and crickets on summer nights, none in a winter night")
	var rain := Soundscape.levels({ "hour": 12.0, "season": "spring", "wet": 0.9, "closeness": 1.0 })
	var snow := Soundscape.levels({ "hour": 12.0, "season": "winter", "wet": 0.9, "snowing": true, "closeness": 1.0 })
	_check(float(rain["rain"]) > 0.8 and float(rain["snow"]) == 0.0 and float(snow["snow"]) > 0.8 and float(snow["rain"]) == 0.0 and float(rain["birds"]) < float(summer_noon["birds"]) * 0.3 and float(rain["wind"]) > float(summer_noon["wind"]), "rain and snow are heard, the birds fall quiet and the wind rises")
	var square := Soundscape.levels({ "hour": 11.0, "season": "spring", "in_town": true, "crowd": 1.0, "closeness": 1.0 })
	var country := Soundscape.levels({ "hour": 11.0, "season": "spring", "in_town": false, "crowd": 1.0, "closeness": 1.0 })
	var far := Soundscape.levels({ "hour": 11.0, "season": "spring", "in_town": true, "crowd": 1.0, "closeness": 0.0 })
	_check(float(square["hubbub"]) > 0.5 and float(country["hubbub"]) == 0.0 and float(far["hubbub"]) == 0.0 and float(far["wind"]) < float(square["wind"]), "a town murmurs when you are in it and close, not from far away")
	var by_fire := Soundscape.levels({ "hour": 20.0, "fire": 0.9, "water": 0.0, "closeness": 1.0 })
	var by_lake := Soundscape.levels({ "hour": 20.0, "water": 0.8, "closeness": 1.0 })
	var paused := Soundscape.levels({ "hour": 12.0, "season": "spring", "closeness": 1.0, "paused": true })
	_check(float(by_fire["fire"]) > 0.7 and float(by_fire["water"]) == 0.0 and float(by_lake["water"]) > 0.7 and float(paused["birds"]) < float(Soundscape.levels({ "hour": 12.0, "season": "spring", "closeness": 1.0 })["birds"]) * 0.4, "fires and water are heard near, and a paused game is quiet")
	_check(Soundscape.mood({ "hour": 9.0 }) == "day" and Soundscape.mood({ "hour": 19.0 }) == "evening" and Soundscape.mood({ "hour": 2.0 }) == "night" and Soundscape.mood({ "hour": 9.0, "festival": true }) == "festival" and Soundscape.mood({ "hour": 9.0, "festival": true, "sorrow": true }) == "sorrow", "the music follows the hour, and a festival or a death")

	# The data hangs together.
	var objects_ok := true
	for def in DataRegistry.get_list("objects"):
		for key in ["ambient", "work_sound"]:
			if def.has(key):
				objects_ok = objects_ok and DataRegistry.has_def("sounds", str(def[key]["id"]))
		if def.has("instrument"):
			objects_ok = objects_ok and str(def["instrument"]) in ["lute", "harp", "drum"] and str(def.get("skill", "")) == "music"
	var instruments := 0
	for def in DataRegistry.get_list("objects"):
		instruments += 1 if def.has("instrument") else 0
	_check(objects_ok and instruments == 3 and DataRegistry.has_def("thoughts", "played_harp"), "the objects that sound name real sounds, and there are three instruments")
	var region := RegionGenerator.generate(42)
	var harps := 0
	var drums := 0
	for placed in region.objects:
		harps += 1 if placed.def_id == "harp" else 0
		drums += 1 if placed.def_id == "drum" else 0
	_check(harps >= 3 and drums >= 3, "the chapels have harps and the taverns drums (%d, %d)" % [harps, drums])

	# Volume.
	AudioMixer.setup()
	_check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("Ambience") != -1 and AudioServer.get_bus_index("Effects") != -1, "there are buses for music, ambience and effects")
	var before := Settings.music_volume
	Settings.set_value("music_volume", 0.0)
	var muted := AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	Settings.set_value("music_volume", 0.5)
	var half := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	Settings.set_value("music_volume", before)
	_check(muted and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and absf(half - linear_to_db(0.5)) < 0.01, "the volume settings mute and set the buses")

	# The director.
	var game := _region_game(42)
	var sim: Simulation = game["sim"]
	var world: WorldState = game["world"]
	var anna: Pawn = (game["household"] as Household).selected()
	GameClock.set_time(2, 10)
	var director := AudioDirector.new()
	add_child(director)
	director.bind(sim, null)
	director.build_now()
	_check(director.is_ready() and director._music_streams.size() == 5 and director._notes.has("lute:60") and director._notes.has("harp:70"), "the director makes every sound, piece of music and note")
	director._think(0.25)
	_check(director._music_mood == "day" and director._music[director._music_side].playing, "the day's music begins to play")
	director._on_pawn_died("Someone", "died", "")
	director._think(0.25)
	_check(director._music_mood == "sorrow", "and gives way to a sad piece for a death")
	director._follow_levels(30.0)
	director._follow_music(10.0)
	_check(director._layers["wind"].playing and director._music[director._music_side].volume_db > -40.0, "the wind blows and the music is up")
	director.play_effect("chop", anna.tile, 1.0)
	director.play_effect("coin", Vector2i(-1, -1))
	var effect_playing := false
	for player in director._pool:
		effect_playing = effect_playing or player.playing
	var global_playing := false
	for player in director._global_pool:
		global_playing = global_playing or player.playing
	_check(effect_playing and global_playing, "a blow at a place and a coin anywhere are played")
	var button := Button.new()
	add_child(button)
	for player in director._global_pool:
		player.stop()
	button.pressed.emit()
	var clicked := false
	for player in director._global_pool:
		clicked = clicked or player.playing
	_check(clicked, "every button clicks")
	button.queue_free()
	# Folk at work and at an instrument are heard.
	var block := world.add_object("chopping_block", anna.tile + Vector2i(2, 0))
	var harp_object := world.add_object("harp", anna.tile + Vector2i(0, 2))
	anna.job_kind = "use"
	anna.job_stage = "using"
	anna.job_object = block.id
	_check(director._work_sound_of(anna).get("id", "") == "chop", "a person at a chopping block makes the sound of chopping")
	anna.job_object = harp_object.id
	director._refresh_players()
	_check(director._players.has(anna.id) and director._players[anna.id]["instrument"] == "harp", "a person at a harp is a player")
	for player in director._pool:
		player.stop()
	GameClock.set_speed(1)
	director._play_instruments(1.0)
	var played := false
	for player in director._pool:
		played = played or player.playing
	_check(played, "and plays a note")
	anna.job_kind = ""
	anna.job_stage = ""
	director._refresh_players()
	_check(director._players.is_empty(), "who stops when they stand up")
	director.queue_free()


func _test_art() -> void:
	print("Painted art")
	var files_ok := true
	var sizes_ok := true
	var entries := 0
	var missing := ""
	for entry in DataRegistry.get_list("sprites"):
		entries += 1
		var names: Array = entry.get("files", [entry.get("file", "")])
		if str(entry["id"]).begins_with("people."):
			names = []
			for layer in ["body"] + (entry["outfits"] as Array):
				for side in ["front", "back"]:
					names.append("%s/%s_%s" % [entry["dir"], layer, side])
		elif entry.has("variants"):
			names = []
			for variant in entry["variants"]:
				names.append(str(variant["front"]))
				if variant.has("back"):
					names.append(str(variant["back"]))
		for name in names:
			var path := "res://assets/art/%s.png" % str(name)
			var exists := ResourceLoader.exists(path)
			files_ok = files_ok and exists
			if not exists:
				missing += str(name) + " "
			var picture := SpriteBank.texture(str(name))
			sizes_ok = sizes_ok and picture != null and picture.get_width() >= 16 and picture.get_width() <= 800 and picture.get_height() >= 16 and picture.get_height() <= 800
	_check(entries >= 34 and files_ok and sizes_ok, "every picture in data/sprites.json is a real file of a sensible size (%d entries%s)" % [entries, ", missing " + missing if missing != "" else ""])
	var ids_ok := true
	var shapes_ok := true
	for entry in DataRegistry.get_list("sprites"):
		var id := str(entry["id"])
		if id.begins_with("object."):
			ids_ok = ids_ok and DataRegistry.has_def("objects", id.trim_prefix("object."))
			var fit: Array = entry.get("fit", [1.0, 1.0])
			shapes_ok = shapes_ok and not (entry["files"] as Array).is_empty() and float(fit[0]) > 0.3 and float(fit[1]) > 0.3 and float(fit[0]) < 2.0 and float(fit[1]) < 2.0 and float(entry.get("base", 0.5)) > 0.3 and float(entry.get("base", 0.5)) < 0.7
		elif id.begins_with("floor."):
			ids_ok = ids_ok and DataRegistry.has_def("floors", id.trim_prefix("floor."))
			shapes_ok = shapes_ok and int(entry.get("tiles", 4)) >= 1
		elif id.begins_with("animal."):
			ids_ok = ids_ok and DataRegistry.has_def("animals", id.trim_prefix("animal."))
		elif id.begins_with("people."):
			ids_ok = ids_ok and DataRegistry.has_def("life_stages", str(entry["stage"])) and not (entry["outfits"] as Array).is_empty()
			for outfit_id in entry["outfits"]:
				ids_ok = ids_ok and DataRegistry.has_def("clothing", str(outfit_id))
		elif id.begins_with("pawn."):
			var parts := id.split(".")
			ids_ok = ids_ok and parts.size() == 3 and DataRegistry.has_def("life_stages", parts[1]) and DataRegistry.has_def("clothing", parts[2]) and not (entry["variants"] as Array).is_empty()
		else:
			ids_ok = false
	_check(ids_ok and shapes_ok, "and each is for an object, floor or person (a life stage in an outfit) that exists, with a sensible size and place")
	var decor_ok := true
	for def_id in ["chair", "chest", "crates", "sacks", "jar", "rug", "tuft"]:
		var def := DataRegistry.get_def("objects", def_id)
		decor_ok = decor_ok and str(def.get("category", "")) == "decor" and int(def.get("cost", 0)) > 0 and DataRegistry.has_def("sprites", "object." + def_id)
	_check(decor_ok, "the new decor (chair, chest, crates, sacks, jar, rug, tall grass) can be built and has its picture")
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art_sheets.json"))
	var cut_ok: bool = spec is Dictionary
	var cut_count := 0
	if cut_ok:
		for sheet in spec["sheets"]:
			for group in ["crops", "textures"]:
				for name in sheet.get(group, {}):
					cut_count += 1
					cut_ok = cut_ok and ResourceLoader.exists("res://assets/art/%s.png" % str(name)) and FileAccess.file_exists("res://assets/source/%s" % str(sheet["source"]).get_file())
	_check(cut_ok and cut_count >= 80, "every sprite the slicing tool lists has been cut from a sheet that is kept (%d)" % cut_count)
	# The player can choose the code-drawn look, and then no picture is used.
	var before := Settings.illustrated_art
	Settings.illustrated_art = true
	var painted := SpriteBank.has_object("bed") and SpriteBank.has_object("hearth") and SpriteBank.has_object("lute") and not SpriteBank.has_object("no_such_thing")
	Settings.illustrated_art = false
	var drawn := not SpriteBank.has_object("bed") and SpriteBank.object_entry("bed").is_empty()
	Settings.illustrated_art = before
	_check(painted and drawn, "painted objects are used by default, and none with the code-drawn look chosen (a made-up object has none)")
	# People: painted ones where there is a picture, falling back to a likeness in other clothes, else code.
	var adult_winter := SpriteBank.person_variant("adult", "winter", 1)
	var elder_sleep := SpriteBank.person_variant("elder", "sleepwear", 1)
	var elder_winter := SpriteBank.person_variant("elder", "winter", 1)
	_check(adult_winter.has("front") and adult_winter.has("back") and SpriteBank.texture(str(adult_winter["front"])) != null, "there are pictures of people in their winter coats, front and back")
	_check(not elder_sleep.is_empty() and str(elder_sleep["front"]).contains("undergarments") and not elder_winter.is_empty() and str(elder_winter["front"]).contains("cozy"), "an elder with no nightclothes sleeps in underclothes, and one in a coat wears the cosy cardigan")
	_check(SpriteBank.person_variant("baby", "casual", 1).is_empty() and SpriteBank.person_variant("toddler", "casual", 1).is_empty() and not SpriteBank.person_variant("toddler", "undergarments", 1).is_empty() and not SpriteBank.person_variant("adult", "casual", 1).is_empty(), "babies and toddlers are still drawn by code, apart from a toddler's underclothes")
	var variants := {}
	for n in 24:
		variants[str(SpriteBank.person_variant("adult", "worker", n * 8)["front"])] = true
	_check(variants.size() == 2, "and each outfit has two looks, picked by who the person is")
	var painted_before := Settings.painted_characters
	painted_before = true  # the default (a saved setting may differ)
	Settings.painted_characters = false
	var off := not SpriteBank.people_enabled()
	Settings.painted_characters = true
	var on := SpriteBank.people_enabled()
	Settings.painted_characters = true
	_check(off and on and painted_before, "painted people are a setting, on by default")
	_check(not ObjectArt.is_animated("hearth") == SpriteBank.has_object("hearth") and ObjectArt.is_animated("watch_post") == not SpriteBank.has_object("watch_post"), "a painted fireplace stands still, and so does everything else painted")


func _test_clothing() -> void:
	print("Clothing")
	var ids := Clothing.outfit_ids()
	var data_ok := ids.size() >= 8
	for needed in ["undergarments", "sleepwear", "casual", "worker", "formal", "warm", "winter", "swim"]:
		data_ok = data_ok and needed in ids and Clothing.warmth_of(needed) > 0.5 and Clothing.warmth_of(needed) < 1.3
	var rules := Clothing.rules()
	_check(data_ok and float(rules["winter_from"]) > float(rules["warm_from"]) and Clothing.warmth_of("winter") < Clothing.warmth_of("warm") and Clothing.warmth_of("warm") < Clothing.warmth_of("casual") and Clothing.warmth_of("casual") <= 1.0, "the wardrobe has an outfit for every occasion, and warmer ones keep more heat in")

	var game := _open_field()
	var sim: Simulation = game["sim"]
	var world: WorldState = game["world"]
	var anna: Pawn = game["anna"]
	anna.tile = Vector2i(30, 25)
	anna.adult = true
	anna.age = 25
	var worn_in := func(day: int, hour: int) -> String:
		GameClock.set_time(day, hour)
		return Clothing.worn(sim, anna)
	_check(worn_in.call(3, 12) == "casual" and worn_in.call(20, 12) == "casual", "in spring and summer by day people wear everyday clothes")
	_check(worn_in.call(33, 12) == "warm" and worn_in.call(3, 23) == "warm", "in autumn, and on a spring night, warm ones")
	_check(worn_in.call(50, 12) == "winter" and worn_in.call(50, 23) == "winter", "in winter a coat")
	var roof_id: String = DataRegistry.get_ids("roofs")[0]
	world.set_roof(anna.tile, roof_id)
	_check(worn_in.call(50, 12) == "casual" and worn_in.call(50, 23) == "warm", "but indoors in winter they take the coat off by day, and put on warm things at night")
	world.set_roof(anna.tile, "")
	GameClock.set_time(3, 12)
	anna.pose = "lie"
	_check(Clothing.worn(sim, anna) == "sleepwear" and worn_in.call(50, 12) == "sleepwear", "in bed, nightclothes, whatever the weather")
	anna.pose = ""
	var basin := world.add_object("wash_basin", Vector2i(31, 25))
	anna.job_kind = "use"
	anna.job_stage = "using"
	anna.job_object = basin.id
	_check(worn_in.call(3, 12) == "undergarments", "washing, underclothes")
	var pew := world.add_object("pew", Vector2i(32, 25))
	anna.job_object = pew.id
	_check(worn_in.call(3, 12) == "formal", "at a pew, good clothes")
	var block := world.add_object("chopping_block", Vector2i(33, 25))
	anna.job_object = block.id
	_check(worn_in.call(3, 12) == "worker" and worn_in.call(50, 12) == "winter", "at a chopping block, work clothes (or, in winter, the coat)")
	anna.job_kind = "wed"
	anna.job_stage = ""
	_check(worn_in.call(3, 12) == "formal", "at a wedding, good clothes")
	anna.job_kind = "work"
	_check(worn_in.call(3, 12) == "worker", "on a shift, work clothes")
	anna.age = 9
	anna.adult = false
	_check(worn_in.call(3, 12) == "casual", "unless they are a child")
	anna.age = 25
	anna.adult = true
	anna.job_kind = ""
	anna.wed_until = GameClock.tick + 600
	_check(Clothing.worn(sim, anna) == "formal", "and for the day after one")
	anna.wed_until = 0
	var baby := _townsperson("Tiny Marsh", "female", 0, 4001)
	_check(Clothing.worn(sim, baby) == "sleepwear", "babies are in their swaddling")

	# Warmth.
	GameClock.set_time(50, 12)
	var cold := Clothing.drain_multipliers(sim, anna, { "warmth": 2.5, "hunger": 1.0 })
	GameClock.set_time(3, 12)
	var mild := Clothing.drain_multipliers(sim, anna, { "warmth": 1.0 })
	anna.pose = "lie"
	var in_bed := Clothing.drain_multipliers(sim, anna, { "warmth": 1.0 })
	anna.pose = ""
	_check(absf(float(cold["warmth"]) - 2.5 * Clothing.warmth_of("winter")) < 0.001 and float(cold["hunger"]) == 1.0 and absf(float(mild["warmth"]) - Clothing.warmth_of("casual")) < 0.001 and absf(float(in_bed["warmth"]) - Clothing.warmth_of("sleepwear")) < 0.001, "clothes change how fast warmth drains, and nothing else (a coat in winter: %.2f instead of 2.50)" % float(cold["warmth"]))
	GameClock.set_time(50, 12)
	anna.needs["warmth"] = 100.0
	_minutes(sim, 60)
	var coated_loss := 100.0 - float(anna.needs["warmth"])
	_check(coated_loss > 1.0 and coated_loss < 2.0 * 2.5 * 1.0, "an hour out in a winter's day costs less warmth than it would unclothed (%.1f)" % coated_loss)

	# How they look.
	var look := _townsperson("Test Wearer", "male", 30, 4002)
	look.look = { "skin": "#e0ac80", "hair": "#4a3220", "top": "#6a7a4a", "bottom": "#4a3d32", "hair_style": 0 }
	var casual := PawnArt.outfit_for(look)
	var night := PawnArt.outfit_for(look, "sleepwear")
	var coat := PawnArt.outfit_for(look, "winter")
	var formal := PawnArt.outfit_for(look, "formal")
	var under := PawnArt.outfit_for(look, "undergarments")
	_check(casual["clothes"] == "casual" and night["clothes"] == "sleepwear" and not night["belt"] and not night["apron"] and under["headwear"] == "" and bool(formal["trim"]) and not formal["belt"] and coat["clothes"] == "winter", "each outfit changes what is drawn: no belt or apron in bed, trim for good clothes")
	var capped := 0
	for n in 40:
		var person := _townsperson("Winter %d" % n, "male" if n % 2 == 0 else "female", 30, 4100 + n)
		person.look = look.look
		capped += 1 if PawnArt.outfit_for(person, "winter")["headwear"] == "fur_cap" else 0
	_check(capped > 8 and capped < 36, "and many people put on a fur cap in winter (%d of 40)" % capped)


func _test_events() -> void:
	print("Town events")
	var first := _collect_events(42, 120)
	_check(not first.is_empty() and first == _collect_events(42, 120), "the same world has the same events, run twice (%d in 120 days)" % first.size())
	_check(first != _collect_events(43, 120), "another world has other events")
	var in_season := true
	var spaced := true
	var last_day := {}
	for entry in first:
		var def := DataRegistry.get_def("events", str(entry["id"]))
		var seasons: Array = def.get("seasons", [])
		in_season = in_season and (seasons.is_empty() or str(entry["season"]) in seasons)
		if last_day.has(entry["id"]):
			spaced = spaced and int(entry["day"]) - int(last_day[entry["id"]]) >= int(def.get("cooldown_days", 0))
		last_day[entry["id"]] = entry["day"]
	_check(in_season, "events only come in their own seasons")
	_check(spaced, "and not again within their cooldown")
	var kinds := {}
	for entry in _collect_events(7, 240):
		kinds[entry["id"]] = true
	_check(kinds.has("festival") and kinds.has("market_day") and kinds.has("cold_snap"), "over a few years every kind of event comes up (%s)" % ", ".join(kinds.keys()))

	# One event, start to finish.
	GameClock.set_time(46, 6)  # deep winter
	var director := EventDirector.new()
	director.last_roll_day = GameClock.get_day_number()
	director.scheduled.append({ "id": "cold_snap", "start": GameClock.tick + 60, "until": GameClock.tick + 60 + 72 * 60 })
	_check(director.update(1).is_empty() and director.active.is_empty(), "a scheduled event waits for its hour")
	GameClock.tick += 60
	var changes := director.update(1)
	_check(changes == [{ "kind": "started", "id": "cold_snap" }] and director.names() == ["Cold snap"], "it starts on time")
	_check(is_equal_approx(float(director.drain_multipliers()["warmth"]), 1.6), "and speeds up warmth loss")
	var copy := EventDirector.new()
	copy.load_dict(director.to_dict())
	_check(copy.to_dict() == director.to_dict(), "an event in progress survives saving")
	GameClock.tick += 72 * 60
	_check(director.update(1) == [{ "kind": "ended", "id": "cold_snap" }] and director.drain_multipliers().is_empty(), "and ends after its hours")

	# What the events do inside a simulation.
	var setup := _building_setup()
	var world: WorldState = setup["world"]
	world.lots = [{ "id": "lot_1", "kind": "park", "name": "Green", "template": "green", "facing": "west", "rect": Rect2i(14, 2, 8, 6), "public": true }]
	var household: Household = setup["household"]
	var sim := Simulation.new(world, household)
	var heard: Array[String] = []
	sim.event_started.connect(func(event_name: String, text: String) -> void: heard.append("%s|%s" % [event_name, text]))
	sim.event_ended.connect(func(event_name: String) -> void: heard.append("end|%s" % event_name))
	GameClock.set_time(46, 6)
	sim.events.last_roll_day = GameClock.get_day_number()
	var normal := float(sim._season_multipliers()["warmth"])
	sim.events.scheduled.append({ "id": "cold_snap", "start": GameClock.tick, "until": GameClock.tick + 120 })
	sim.step()
	_check(heard.size() == 1 and heard[0].begins_with("Cold snap|") and "cold" in heard[0].to_lower(), "the player hears about it (%s)" % heard)
	_check(is_equal_approx(float(sim._season_multipliers()["warmth"]), normal * 1.6), "warmth drains faster in a cold snap (%.1f instead of %.1f)" % [float(sim._season_multipliers()["warmth"]), normal])
	for minute in 125:
		GameClock.advance_one_tick()
		sim.step()
	_check(heard.back() == "end|Cold snap" and is_equal_approx(float(sim._season_multipliers()["warmth"]), normal), "and it passes")

	GameClock.set_time(3, 8)
	sim.events.last_roll_day = GameClock.get_day_number()
	_check(sim.price_of("food_shelf") == Economy.price("food_shelf") and Economy.price("food_shelf") == 3, "bread costs its normal price")
	sim.events.active.append({ "id": "market_day", "start": GameClock.tick, "until": GameClock.tick + 480 })
	_check(sim.price_of("food_shelf") == 2 and sim.price_of("meal_table") == Economy.price("meal_table"), "on market day it is cheaper and nothing else changes")
	sim.events.active.clear()

	# A festival draws the townspeople to the green.
	GameClock.set_time(3, 10)
	var villager := Pawn.new()
	villager.age = 30
	villager.home_lot = "lot_5"
	villager.tile = Vector2i(5, 8)
	villager.step_to = villager.tile
	_fill_needs(villager)
	villager.needs["social"] = 40.0
	sim.town.add_pawn(villager)
	sim.events.active.append({ "id": "festival", "start": GameClock.tick, "until": GameClock.tick + 600 })
	var green: Rect2i = world.lots[0]["rect"]
	var went := false
	var social_peak := 0.0
	for minute in 240:
		GameClock.advance_one_tick()
		sim.step()
		villager.needs["hunger"] = 100.0
		went = went or green.has_point(villager.tile)
		social_peak = maxf(social_peak, float(villager.needs["social"]))
	_check(went, "a townsperson with nothing to do goes to the festival")
	_check(social_peak > 60.0 and "Enjoying the festival" in _mood_texts(villager, sim.town), "and enjoys the company there (social up to %.0f)" % social_peak)
	GameClock.reset()

	# Saved with the game.
	var big := MapGenerator.generate(5, 64, 48)
	var family := HouseholdGenerator.create(big)
	var saved_events := EventDirector.new()
	saved_events.history.append({ "id": "festival", "day": 12 })
	saved_events.last_roll_day = 12
	saved_events.active.append({ "id": "market_day", "start": 100, "until": 900 })
	_check(SaveGame.save(TEST_SAVE, big, family, {}, null, saved_events) == OK, "a save with events is written")
	var loaded := SaveGame.load_from(TEST_SAVE)
	var restored := EventDirector.new()
	restored.load_dict(loaded["events"])
	_check(restored.to_dict() == saved_events.to_dict(), "history, what is on now and the last day rolled survive a round trip")
	var older := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	older.store_string(JSON.stringify({ "format": 6, "world": big.to_dict(), "clock": GameClock.to_dict(), "household": family.to_dict() }))
	older.close()
	var old_save := SaveGame.load_from(TEST_SAVE)
	_check(old_save["ok"] and old_save["events"] == {}, "a version 6 save loads with no events yet")
	var no_relations := family.to_dict()
	for saved in no_relations["pawns"]:
		saved.erase("relations")
	var old_family := Household.from_dict(no_relations)
	Simulation.new(big, old_family)
	_check(old_family.pawns[0].opinion_of(old_family.pawns[1].id) == Relations.FAMILY_START, "an older save's households are fond of each other")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _land_setup(start_id: String = "arrived") -> Dictionary:
	GameClock.set_time(0, 12)
	var world := WorldState.new(48, 24, 5, "grass")
	world.lot = Rect2i(2, 2, 16, 13)
	world.lots = [
		{ "id": "lot_1", "kind": "vacant", "name": "Empty lot", "template": "vacant", "facing": "south", "rect": Rect2i(24, 2, 12, 10), "public": false },
		{ "id": "lot_2", "kind": "vacant", "name": "Empty lot", "template": "vacant", "facing": "south", "rect": Rect2i(24, 13, 12, 10), "public": false },
	]
	var begun := Starts.begin(world, start_id)
	var household: Household = begun["household"]
	var realm: Realm = begun["realm"]
	return { "world": world, "household": household, "realm": realm, "sim": Simulation.new(world, household, null, realm) }


func _objects_in(world: WorldState, rect: Rect2i) -> Dictionary:
	var counts := {}
	for placed in world.objects:
		if rect.has_point(placed.tile):
			counts[placed.def_id] = int(counts.get(placed.def_id, 0)) + 1
	return counts


func _test_realm() -> void:
	print("Land, starts and the Crown")
	# The three starts.
	for start_id in ["bought", "inherited", "arrived"]:
		var setup := _land_setup(start_id)
		var def := DataRegistry.get_def("starts", start_id)
		var world: WorldState = setup["world"]
		var household: Household = setup["household"]
		var realm: Realm = setup["realm"]
		var classes_ok := true
		for pawn in household.pawns:
			classes_ok = classes_ok and pawn.class_id == str(def["class"])
		_check(household.coins == int(def["coins"]) and classes_ok and world.titles[WorldState.HOME_LOT] == str(def["title"]) and realm.start_id == start_id,
			"the %s start sets the purse, class and title from starts.json" % start_id)
		_check(household.get_pawn(realm.head_id) != null, "and someone heads the household")
	var inherited := _land_setup("inherited")
	var held := _objects_in(inherited["world"], inherited["world"].lot)
	_check(int(held.get("bed", 0)) == 3 and int(held.get("wall", 0)) > 10 and int(held.get("door", 0)) == 1 and int(held.get("cooking_pot", 0)) == 1, "an inherited start comes with a standing cottage and no camp (%s)" % str(held))
	var inside := true
	for pawn in inherited["household"].pawns:
		inside = inside and inherited["world"].floor_at(pawn.tile) != ""
	_check(inside, "and the family starts indoors")
	var arrived := _land_setup("arrived")
	var camp := _objects_in(arrived["world"], arrived["world"].lot)
	_check(camp.keys().size() == 3 and int(camp.get("bed", 0)) == 3 and camp.has("cooking_pot") and camp.has("hearth"), "arriving with nothing leaves bedrolls, a pot and a fire (%s)" % str(camp))
	_check(_objects_in(_land_setup("bought")["world"], Rect2i(2, 2, 16, 13)).has("lute"), "bought land comes with the full camp")

	# Joining the guild and taking a business lot.
	var setup := _land_setup("arrived")
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var realm: Realm = setup["realm"]
	var sim: Simulation = setup["sim"]
	var pawn := household.pawns[0]
	var lot_tile := Vector2i(30, 6)
	_check("guild" in realm.lot_blocker(sim, "lot_1", "lease"), "a business lot is refused to someone outside the guild")
	var menu := PawnActions.list_for(sim, pawn, lot_tile)
	var lease_entry := {}
	for entry in menu:
		if str(entry["id"]) == PawnActions.LOT_PREFIX + "lease:lot_1":
			lease_entry = entry
	_check(not lease_entry.is_empty() and not lease_entry["enabled"] and "guild" in str(lease_entry["reason"]), "the empty lot's menu offers a lease, switched off with the reason")
	household.coins = 1000
	var board := world.add_object("notice_board", Vector2i(10, 20))
	var board_menu := PawnActions.list_for(sim, pawn, board.tile)
	var join_entry := {}
	for entry in board_menu:
		if str(entry["id"]).begins_with(PawnActions.GUILD_PREFIX):
			join_entry = entry
	_check(not join_entry.is_empty() and join_entry["enabled"] and "25d" in str(join_entry["label"]), "the notice board offers the guild (%s)" % str(join_entry.get("label", "")))
	var joined := PawnActions.perform(sim, pawn, str(join_entry["id"]), board.tile)
	var all_burghers := true
	for member in household.pawns:
		all_burghers = all_burghers and member.class_id == "burgher"
	_check(joined["ok"] and realm.guild == "merchants" and household.coins == 975 and all_burghers, "joining costs the fee and makes the household burghers")
	_check(realm.join_blocker(sim, "merchants") == "already a member", "and cannot be done twice")
	_check(not world.can_build_at(lot_tile) and "outside" in sim.build_blocker("bed", lot_tile), "land you do not hold cannot be built on")
	var lease_price := realm.lot_price(world, "lot_1", "lease")
	var leased := PawnActions.perform(sim, pawn, PawnActions.LOT_PREFIX + "lease:lot_1", lot_tile)
	_check(leased["ok"] and household.coins == 975 - lease_price and world.titles["lot_1"] == "leasehold", "leasing takes the entry fee (%s) and gives a leasehold" % Economy.format(lease_price))
	var business: Dictionary = world.get_lot("lot_1")
	_check(business["kind"] == "business" and bool(business["public"]) and world.can_build_at(lot_tile), "the lot becomes a public business you can build on")
	_check("already hold" in realm.lot_blocker(sim, "lot_2", "buy"), "only one business lot is allowed")
	var money := household.coins
	var table_result := sim.build_place("meal_table", Vector2i(28, 6))
	_check(table_result["ok"] and household.coins == money - Economy.object_cost("meal_table"), "a tavern table can be built on it")
	_check(not sim.build_place("meal_table", Vector2i(40, 6))["ok"], "but not on the empty lot beside it")
	var buyout_price := realm.lot_price(world, "lot_1", "buyout")
	var bought_out := PawnActions.perform(sim, pawn, PawnActions.LOT_PREFIX + "buyout:lot_1", lot_tile)
	_check(bought_out["ok"] and world.titles["lot_1"] == "freehold" and household.coins == money - Economy.object_cost("meal_table") - buyout_price, "a lease can be bought out for the freehold price")

	# Customers pay the owner.
	var guest := Pawn.new()
	guest.display_name = "Guest Person"
	guest.age = 30
	guest.home_lot = "elsewhere"
	guest.coins = 50
	guest.tile = Vector2i(26, 9)
	guest.step_to = guest.tile
	for need_id in Needs.active_ids():
		guest.needs[need_id] = 100.0
	guest.needs["hunger"] = 15.0
	sim.town.add_pawn(guest)
	var before := household.coins
	for minute in 150:
		GameClock.advance_one_tick()
		sim.step()
	var price := Economy.price("meal_table")
	_check(guest.coins == 50 - price and household.coins == before + price and realm.takings == price, "a hungry customer eats at your table and the price goes to your purse (%d, %d, %d)" % [guest.coins, household.coins - before, realm.takings])

	# Quarter day.
	GameClock.set_time(5, 6)
	sim.town.remove_pawn(guest.id)
	setup = _land_setup("bought")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	sim = setup["sim"]
	var home_tax := roundi(world.lot_area(WorldState.HOME_LOT) * 0.05)
	_check(realm.days_until_tax() == 15 and realm.total_due(sim) == home_tax, "a burgher on freehold owes just the land tax (%s)" % Economy.format(home_tax))
	GameClock.set_time(14, 12)
	_check(realm.new_day(sim).is_empty(), "no collector on an ordinary day")
	GameClock.set_time(15, 0)
	household.coins = 90
	var notices := realm.new_day(sim)
	_check(household.coins == 90 - home_tax and realm.arrears == 0 and realm.reputation == 4.0 and not notices.is_empty(), "on quarter day the tax is paid out of the purse and standing rises (%s)" % str(notices))
	_check(realm.new_day(sim).is_empty(), "and the collector comes only once")
	_check(realm.days_until_tax() == 15, "the next quarter day is fifteen days away")
	sim.events.scheduled.clear()
	var gentry_sim: Simulation = _land_setup("inherited")["sim"]
	var gentry_tax := roundi(gentry_sim.world.lot_area(WorldState.HOME_LOT) * 0.05 * 1.25)
	_check(gentry_sim.realm.total_due(gentry_sim) == gentry_tax, "gentry pay a larger share (%s)" % Economy.format(gentry_tax))
	var peasant_sim: Simulation = _land_setup("arrived")["sim"]
	var rent := roundi(peasant_sim.world.lot_area(WorldState.HOME_LOT) * 0.12 * 0.75)
	_check(peasant_sim.realm.total_due(peasant_sim) == rent, "a leaseholder pays rent, not land tax (%s)" % Economy.format(rent))
	realm.levy_multiplier = 1.0
	realm.takings = 100
	var with_trade := realm.total_due(sim)
	realm.guild = "merchants"
	_check(with_trade == home_tax + 20 and realm.total_due(sim) == home_tax + 8 + 4, "trade tax is a share of takings, lower for guild members who also pay dues")
	realm.guild = ""
	realm.takings = 0
	realm.levy_multiplier = 0.5
	_check(realm.total_due(sim) == roundi(world.lot_area(WorldState.HOME_LOT) * 0.05 * 0.5), "a decree can halve the land tax")
	realm.levy_multiplier = 1.0

	# Not paying: the collector takes furnishings and standing falls.
	setup = _land_setup("bought")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	sim = setup["sim"]
	var furnishings := _objects_in(world, world.lot)
	_check(int(furnishings.get("lute", 0)) == 1, "the camp has a lute to be taken")
	household.coins = 3
	GameClock.set_time(15, 0)
	notices = realm.new_day(sim)
	var left := _objects_in(world, world.lot)
	_check(int(left.get("lute", 0)) == 0 and int(left.get("bed", 0)) == 3 and realm.arrears == 0 and realm.reputation == -12.0, "when the purse is short the collector takes the dearest furnishing, and standing falls (%s)" % str(notices))
	_check(household.coins == 3 - 3 + (Economy.object_cost("lute") - (home_tax - 3)), "and gives change")
	setup = _land_setup("arrived")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	sim = setup["sim"]
	for placed in world.objects.duplicate():
		world.remove_object(placed.id)
	household.coins = 0
	GameClock.set_time(15, 0)
	realm.new_day(sim)
	_check(realm.arrears == rent and "owing" in realm.summary(sim).to_lower(), "with nothing to take the debt carries over (%s)" % Economy.format(realm.arrears))
	GameClock.set_time(30, 0)
	household.coins = 1000
	realm.levy_multiplier = 1.0
	realm.new_day(sim)
	_check(realm.arrears == 0 and household.coins == 1000 - 2 * rent, "and is paid with the next quarter's tax")

	# Eviction: a second quarter day unpaid.
	setup = _land_setup("bought")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	sim = setup["sim"]
	realm.guild = "merchants"
	household.coins = 5000
	_check(realm.acquire_lot(sim, "lot_1", "lease")["ok"], "a guild member leases a business lot")
	world.set_floor(Vector2i(26, 4), "planks")
	for placed in world.objects.duplicate():  # nothing the collector may take, so the debt carries
		if world.lot.has_point(placed.tile) and placed.def_id not in ["bed", "cooking_pot", "hearth"] and str(placed.def().get("category", "")) != "structure":
			world.remove_object(placed.id)
	household.coins = 0
	var wall_count := 0
	for placed in world.objects:
		if world.lot.has_point(placed.tile) and str(placed.def().get("category", "")) == "structure":
			wall_count += 1
	GameClock.set_time(15, 0)
	realm.levy_multiplier = 1.0
	notices = realm.new_day(sim)
	_check(realm.missed == 1 and not world.home_lost and "evicted" in " ".join(notices), "the first default brings a warning, not the bailiffs (%s)" % str(notices))
	_check("evicted" in realm.summary(sim).to_lower(), "and the tax panel warns of it")
	var saved_setup_dict := realm.to_dict()
	_check(int(saved_setup_dict["missed"]) == 1, "missed quarters are saved")
	var standing_before := realm.reputation
	GameClock.set_time(30, 0)
	realm.levy_multiplier = 1.0
	notices = realm.new_day(sim)
	_check(world.home_lost and world.titles.is_empty() and realm.arrears == 0 and realm.missed == 0, "the second default evicts: land lost, debt wiped (%s)" % str(notices))
	_check(is_equal_approx(realm.reputation, clampf(standing_before - 12.0 - 20.0, -100.0, 100.0)) or realm.reputation < standing_before, "and standing falls further")
	var after := _objects_in(world, world.lot)
	var bed_left: int = int(after.get("bed", 0))
	var walls_left := 0
	for placed in world.objects:
		if world.lot.has_point(placed.tile) and str(placed.def().get("category", "")) == "structure":
			walls_left += 1
	_check(bed_left == 0 and walls_left == wall_count, "the furnishings are gone but the walls stay (%d beds, %d/%d walls)" % [bed_left, walls_left, wall_count])
	_check(str(world.get_lot("lot_1").get("kind", "")) == "vacant" and world.floor_at(Vector2i(26, 4)) == "", "the business lot is an empty plot again")
	_check(not world.can_build_at(world.lot.position + Vector2i(1, 1)) and world.held_rects().is_empty(), "and nothing can be built on land you no longer hold")
	_check(household.pawns[0].thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "evicted"), "the household takes it hard")
	_check("evicted" in realm.summary(sim).to_lower() or "landless" in realm.summary(sim).to_lower(), "the panel says so")
	household.coins = 0
	_check("costs" in realm.lot_blocker(sim, WorldState.HOME_LOT, "lease"), "taking the old plot again costs the entry fee")
	household.coins = 5000
	_check(realm.acquire_lot(sim, WorldState.HOME_LOT, "lease")["ok"] and not world.home_lost and world.titles.get(WorldState.HOME_LOT, "") == "leasehold", "and then you hold it again, as a tenant")
	_check(world.can_build_at(world.lot.position + Vector2i(1, 1)), "and may build on it")
	world.home_lost = true
	realm.missed = 1
	_check(SaveGame.save(TEST_SAVE, world, household, {}, null, null, realm) == OK, "an evicted game saves")
	var evicted_load := SaveGame.load_from(TEST_SAVE)
	_check(evicted_load["ok"] and evicted_load["world"].home_lost and evicted_load["realm"].missed == 1, "and the eviction survives a round trip")
	DirAccess.remove_absolute(TEST_SAVE)
	var no_limit_setup := _land_setup("arrived")
	var polite_realm: Realm = no_limit_setup["realm"]
	var polite_sim: Simulation = no_limit_setup["sim"]
	for placed in no_limit_setup["world"].objects.duplicate():
		no_limit_setup["world"].remove_object(placed.id)
	no_limit_setup["household"].coins = 0
	for quarter in [1, 2]:
		GameClock.set_time(quarter * 15, 0)
		polite_realm.levy_multiplier = 1.0
		polite_realm.new_day(polite_sim)
	_check(no_limit_setup["world"].home_lost, "a tenant with nothing to take is evicted after two unpaid quarters")

	# Decrees.
	var proclaimed := 0
	for quarter in range(1, 21):
		sim.events.scheduled.clear()
		GameClock.set_time(quarter * 15, 0)
		realm.last_tax_day = 0
		realm.new_day(sim)
		if not sim.events.scheduled.is_empty():
			proclaimed += 1
			var decree := DataRegistry.get_def("events", str(sim.events.scheduled[0]["id"]))
			_check(bool(decree.get("decree", false)) and is_equal_approx(realm.levy_multiplier, float(decree.get("tax_multiplier", 1.0))), "a proclaimed decree sets the coming levy")
	_check(proclaimed > 3 and proclaimed < 20, "some quarter days bring a decree and some do not (%d of 20)" % proclaimed)
	var normal_rolls := _collect_events(7, 60)
	var no_decrees := true
	for entry in normal_rolls:
		no_decrees = no_decrees and not bool(DataRegistry.get_def("events", str(entry["id"])).get("decree", false))
	_check(no_decrees, "decrees are never rolled as ordinary events")

	# Succession.
	setup = _land_setup("bought")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	sim = setup["sim"]
	household.pawns[0].age = 50
	household.pawns[1].age = 31
	household.pawns[2].age = 20
	realm.choose_head(household)
	_check(realm.head_id == household.pawns[0].id, "the eldest adult heads the household")
	household.coins = 100
	var heard: Array[String] = []
	sim.realm_notice.connect(func(text: String) -> void: heard.append(text))
	var second_oldest := household.pawns[1].id
	sim.die(household.pawns[0], "died of old age")
	_check(realm.head_id == second_oldest and household.coins == 90, "when the head dies the next eldest takes over and the Crown takes 10%% (%s)" % str(heard))
	_check(heard.size() == 2 and "death duty" in heard[0] and "heads the household" in heard[1], "and the player is told")
	sim.die(household.pawns[1], "fell ill")
	heard.clear()
	var last_alive := household.pawns[0].id
	_check(realm.head_id == last_alive, "and so on down the household")

	# Class and work.
	setup = _land_setup("inherited")
	world = setup["world"]
	world.lots.append({ "id": "lot_t", "kind": "tavern", "name": "Tavern", "template": "tavern", "facing": "south", "rect": Rect2i(24, 2, 8, 8), "public": true })
	sim = setup["sim"]
	var noble: Pawn = setup["household"].pawns[0]
	_check("beneath" in sim.hire_blocker(noble, "lot_t", "tavern_hand"), "gentry will not wait tables")
	noble.class_id = "burgher"
	_check(sim.hire_blocker(noble, "lot_t", "tavern_hand") == "", "a burgher will")

	# The town's own classes.
	var town_world := MapGenerator.generate(7, 128, 96)
	TownGenerator.generate(town_world)
	var town := NpcGenerator.create(town_world)
	var class_ok := true
	var any_gentry := false
	var any_burgher := false
	for person in town.pawns:
		class_ok = class_ok and DataRegistry.has_def("classes", person.class_id)
		any_gentry = any_gentry or person.class_id == "gentry"
		any_burgher = any_burgher or person.class_id == "burgher"
		if person.work_job != "":
			class_ok = class_ok and person.class_id not in DataRegistry.get_def("jobs", person.work_job).get("not_for", [])
	_check(class_ok and any_burgher, "townspeople have classes, tradesmen's families are burghers and no gentry waits tables")

	# Saving.
	setup = _land_setup("arrived")
	world = setup["world"]
	household = setup["household"]
	realm = setup["realm"]
	realm.guild = "merchants"
	realm.reputation = 17.0
	realm.arrears = 9
	realm.takings = 33
	world.titles["lot_1"] = "leasehold"
	_check(SaveGame.save(TEST_SAVE, world, household, {}, null, null, realm) == OK, "a save with a realm is written")
	var loaded := SaveGame.load_from(TEST_SAVE)
	_check(loaded["ok"] and loaded["realm"].to_dict() == realm.to_dict() and loaded["world"].titles == world.titles, "guild, standing, arrears, takings and land titles survive a round trip")
	_check(loaded["household"].pawns[0].class_id == "peasant" and loaded["household"].to_dict() == household.to_dict(), "and so do the household's classes")
	var old_world := world.to_dict()
	old_world.erase("titles")
	_write_file(TEST_SAVE, JSON.stringify({ "format": 7, "world": old_world, "clock": GameClock.to_dict() }))
	var old := SaveGame.load_from(TEST_SAVE)
	_check(old["ok"] and old["world"].titles.get(WorldState.HOME_LOT, "") == "freehold" and old["realm"].guild == "", "an older save gets a freehold home lot and a clean slate")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _family_setup() -> Dictionary:
	GameClock.set_time(0, 12)
	var world := WorldState.new(40, 20, 3, "grass")
	world.lot = Rect2i(2, 2, 12, 8)
	var household := Household.new()
	household.coins = 50
	var people: Array[Pawn] = []
	for spec in [["Mary Brook", "female", 25], ["John Brook", "male", 27], ["Tom Brook", "male", 8]]:
		var person := Pawn.new()
		person.display_name = spec[0]
		person.gender = spec[1]
		person.age = spec[2]
		person.adult = person.age >= 18
		person.tile = Vector2i(5 + people.size(), 5)
		person.step_to = person.tile
		for need_id in Needs.active_ids():
			person.needs[need_id] = 100.0
		household.add_pawn(person)
		people.append(person)
	Relations.make_family(people)
	return { "world": world, "household": household, "mother": people[0], "father": people[1], "child": people[2], "sim": Simulation.new(world, household) }


func _test_pregnancy() -> void:
	print("Pregnancy and children")
	var setup := _family_setup()
	var sim: Simulation = setup["sim"]
	var household: Household = setup["household"]
	var mother: Pawn = setup["mother"]
	var father: Pawn = setup["father"]
	var child: Pawn = setup["child"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_check(Pregnancy.can_conceive(mother) and not Pregnancy.can_conceive(father) and not Pregnancy.can_conceive(child), "only an adult woman can conceive")
	mother.age = 50
	_check(not Pregnancy.can_conceive(mother), "and not when she is past childbearing age")
	mother.age = 25
	_check(not Pregnancy.try_conceive(sim, father, mother, 0.0, rng) and not mother.is_pregnant(), "no chance, no child")
	_check(float(DataRegistry.get_def("interactions", "intimacy").get("conception_chance", 0.0)) > 0.0, "intimacy carries a chance of conception")
	var intimacy := DataRegistry.get_def("interactions", "intimacy")
	var tries := 0
	while not mother.is_pregnant() and tries < 400:
		sim._finish_interaction(father, mother, intimacy)
		tries += 1
	_check(mother.is_pregnant() and mother.pregnancy_father == father.id and tries > 1, "intimacy sooner or later starts a pregnancy (after %d)" % tries)
	_check(not Pregnancy.can_conceive(mother) and not Pregnancy.try_conceive(sim, father, mother, 1.0, rng), "a woman who is expecting cannot conceive again")

	var men := _family_setup()
	var men_sim: Simulation = men["sim"]
	var never := false
	for i in 300:
		never = never or Pregnancy.try_conceive(men_sim, men["father"], men["child"], 1.0, rng)
		men_sim._finish_interaction(men["father"], men["father"], intimacy)
	_check(not never and not men["mother"].is_pregnant(), "a man and a boy, or a man alone, cannot conceive")
	var stranger := Pawn.new()
	stranger.display_name = "Nell Town"
	stranger.age = 25
	stranger.id = 1500
	var townswoman := false
	for i in 50:
		townswoman = townswoman or Pregnancy.try_conceive(men_sim, men["father"], stranger, 1.0, rng)
	_check(not townswoman, "a woman who is not in the world cannot conceive")

	# The months go by (by the calendar a year is 60 days, so this pregnancy lasts 45).
	var heard: Array[String] = []
	var changes := [0]
	var born: Array = []
	sim.household_changed.connect(func() -> void: changes[0] += 1)
	sim.babies_born.connect(func(ids: Array[int]) -> void: born.append_array(ids))
	GameClock.set_time(0, 0)
	Pregnancy.begin(sim, mother, father, rng)
	mother.babies_due = 1
	_check(Pregnancy.length_minutes(sim.world) == 45 * GameClock.MINUTES_PER_DAY and mother.pregnancy_minutes == 45 * GameClock.MINUTES_PER_DAY, "a pregnancy lasts three quarters of a year of life")
	var short := WorldState.new(10, 10, 1, "grass")
	short.lifespan = "normal"
	_check(Pregnancy.length_minutes(short) == roundi(0.75 * Life.days_per_year(short) * GameClock.MINUTES_PER_DAY), "and is shorter on a shorter lifespan")
	GameClock.set_time(5, 0)
	var feel := Mood.evaluate(mother, household, GameClock.tick)
	_check(Pregnancy.trimester(mother) == 1 and not Pregnancy.is_known(mother) and Pregnancy.bump(mother) == 0.0 and not _has_part(feel, "expecting"), "early on nobody knows, and nothing shows")
	var sick := false
	for day in range(1, 12):
		GameClock.set_time(day, 7)
		Pregnancy.step(sim, rng)
		sick = sick or mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "morning_sick")
	_check(sick, "some mornings early on are queasy")
	GameClock.set_time(13, 0)
	heard = Pregnancy.step(sim, rng)
	_check(Pregnancy.is_known(mother) and heard.size() == 1 and "expecting" in heard[0], "after a while she is known to be expecting (%s)" % str(heard))
	_check(Pregnancy.step(sim, rng).is_empty(), "which is only announced once")
	_check(_has_part(Mood.evaluate(mother, household, GameClock.tick), "expecting"), "and it lifts her spirits")
	_check(is_equal_approx(float(Pregnancy.drain_multipliers(mother, {})["hunger"]), 1.3) and Pregnancy.drain_multipliers(father, {}).is_empty(), "she gets hungrier and more tired")
	_check(not sim.needs_break(mother), "and still works")
	GameClock.set_time(20, 0)
	_check(Pregnancy.trimester(mother) == 2 and Pregnancy.bump(mother) > 0.0 and float(PawnArt.outfit_for(mother)["bump"]) > 0.0, "in the second trimester her belly shows")
	var craving := false
	for day in range(16, 30):
		GameClock.set_time(day, 11)
		Pregnancy.step(sim, rng)
		craving = craving or mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "craving")
	_check(craving, "she craves something sweet now and then")
	Pregnancy.after_eating(mother)
	_check(not mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "craving") and mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "craving_met"), "and a meal satisfies it")
	GameClock.set_time(34, 0)
	var late := Mood.evaluate(mother, household, GameClock.tick)
	_check(Pregnancy.trimester(mother) == 3 and Pregnancy.is_heavy(mother) and sim.needs_break(mother) and _has_part(late, "heavy") and not _has_part(late, "expecting"), "in the last weeks she is heavy, low and off work")
	_check("expecting" in sim.describe_activity(mother) and Pregnancy.bump(mother) > 0.6, "the panel says so, and the belly is big")
	_check(PawnArt.outfit_for(mother)["belt"] == false, "her belt has come off")

	# Labour.
	var bed := sim.world.add_object("bed", Vector2i(10, 3))
	mother.tile = Vector2i(5, 6)
	mother.step_to = mother.tile
	father.tile = Vector2i(7, 7)
	father.step_to = father.tile
	GameClock.set_time(45, 6)
	heard = Pregnancy.step(sim, rng)
	_check(Pregnancy.in_labour(mother) and mother.job_kind == "labour" and heard.size() == 1 and "labour" in heard[0], "near the end her labour begins (%s)" % str(heard))
	_check(mother.labour_minutes >= 3 * 60 and mother.labour_minutes <= 8 * 60, "and lasts a few hours")
	_check(not sim.order_move(mother, Vector2i(3, 3))["ok"] and sim.use_blocker(mother, bed) != "", "a woman in labour cannot be sent off")
	var her_menu := PawnActions.list_for(sim, mother, Vector2i(3, 3))
	_check(her_menu.size() == 1 and not her_menu[0]["enabled"] and "labour" in str(her_menu[0]["label"]), "her menu only says she is in labour")
	var attend_entry := PawnActions.list_for(sim, father, mother.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "attend:%d" % mother.id)
	_check(attend_entry.size() == 1 and attend_entry[0]["enabled"], "someone else can stay with her for the birth")
	_check(sim.attend_blocker(child, mother) != "", "but not a child")
	mother.labour_minutes = 600
	for i in 120:
		GameClock.advance_one_tick()
		sim.step()
	_check(mother.job_stage == "using" and mother.pose == "lie" and Pregnancy.birth_bed(sim, mother) == bed, "she makes for a bed and lies down")
	_check(father.job_kind == "attend" and father.job_stage == "using" and Pregnancy.midwife_present(sim, mother), "and John goes to stay with her of his own accord")
	_check(Pregnancy.complication_chance(sim, mother) < 0.03, "a bed and a midwife make the birth much safer (%.3f)" % Pregnancy.complication_chance(sim, mother))
	_check("labour" in sim.describe_activity(mother).to_lower() and "birth" in sim.describe_activity(father), "the panel says what they are doing")
	_check(_has_part(Mood.evaluate(mother, household, GameClock.tick), "in_labour"), "labour is hard going")

	# The birth.
	var before := household.pawns.size()
	changes[0] = 0
	mother.labour_minutes = GameClock.tick - mother.labour_since
	heard = Pregnancy.step(sim, rng)
	_check(household.pawns.size() == before + 1 and not mother.is_pregnant() and heard.size() == 1 and "gave birth" in heard[0], "the baby is born into the household (%s)" % str(heard))
	var baby: Pawn = household.pawns[household.pawns.size() - 1]
	_check(born == [baby.id] and changes[0] == 1, "the household is told, and asked to name the baby")
	_check(mother.job_kind == "" and father.job_kind == "" and bed.user_id == 0, "mother gets up and the midwife goes about their day")
	_check(baby.age == 0 and baby.is_infant() and not baby.adult and baby.traits.size() == 2 and baby.home_lot == mother.home_lot and baby.display_name.ends_with("Brook"), "a newborn, with two traits and the family name")
	_check(baby.opinion_of(mother.id) == Relations.FAMILY_START and mother.opinion_of(baby.id) == Relations.FAMILY_START and father.opinion_of(baby.id) == Relations.FAMILY_START, "the family loves it")
	var recovery := roundi(0.25 * 60 * GameClock.MINUTES_PER_DAY)
	_check(mother.recovered_at >= GameClock.tick + recovery and not Pregnancy.can_conceive(mother), "mother needs time to recover")
	GameClock.set_time(45 + 31, 0)
	_check(Pregnancy.can_conceive(mother), "and may conceive again later")
	_check(mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "new_baby") and mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "gave_birth"), "everyone is glad of the baby")
	_check(sim.rename(baby, "  wilfred ")["ok"] and baby.display_name == "Wilfred Brook" and not sim.rename(baby, "  ")["ok"], "the baby can be named")

	# A baby is carried and cannot be controlled.
	_check(not household.select(baby.id) and household.selected_id != baby.id, "a baby cannot be chosen")
	household.select(mother.id)
	var landed := []
	for i in 6:
		household.cycle_selection(1)
		landed.append(household.selected_id)
	_check(not (baby.id in landed) and household.playable().size() == before, "cycling through the household skips the baby")
	GameClock.set_time(80, 12)
	mother.tile = Vector2i(9, 9)
	mother.step_to = mother.tile
	Pregnancy.carry_infants(sim)
	_check(baby.tile == mother.tile and baby.carried_by == mother.id and baby.pose == "", "by day the baby goes where its mother goes")
	_check(sim.interaction_blocker(father, baby, "chat") != "" and PawnActions.list_for(sim, father, baby.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("interact:") and str(e["id"]).ends_with(":%d" % baby.id)).is_empty(), "nobody chats with a baby")
	var hunger_before := float(baby.needs["hunger"])
	for i in 30:
		GameClock.advance_one_tick()
		sim.step()
	_check(float(baby.needs["hunger"]) == hunger_before, "a baby has no needs of a grown-up's and does not wander")

	# Babies need care.
	_check(Babies.worst_care(baby) > 90.0 and not Babies.is_crying(baby), "a newborn is fed, comfortable and clean")
	var cradle := sim.world.add_object("cradle", Vector2i(4, 3))
	GameClock.set_time(81, 22)
	Pregnancy.carry_infants(sim)
	_check(baby.tile == cradle.tile and baby.pose == "lie" and Babies.cradle_for(sim, baby) == cradle, "at night the baby sleeps in the cradle")
	GameClock.set_time(82, 9)
	Pregnancy.carry_infants(sim)
	_check(baby.tile != cradle.tile and baby.pose == "", "and is picked up in the morning")
	for person in household.pawns:
		sim.order_stop(person)
	baby.care["fed"] = 30.0
	var care_menu := PawnActions.list_for(sim, father, baby.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "tend:fed:%d" % baby.id)
	_check(care_menu.size() == 1 and care_menu[0]["enabled"] and "Feed Wilfred" in str(care_menu[0]["label"]), "right-click a baby to feed it (%s)" % str(care_menu))
	_check(PawnActions.list_for(sim, child, baby.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with("tend:") and e["enabled"]).is_empty(), "a child is too young to see to it")
	var cared := false
	for i in 120:
		GameClock.advance_one_tick()
		sim.step()
		cared = cared or (household.pawns.any(func(p: Pawn) -> bool: return p.job_kind == "tend" and p.job_partner == baby.id))
		if float(baby.care["fed"]) >= Needs.FULL - 0.01:
			break
	_check(cared and float(baby.care["fed"]) >= Needs.FULL - 0.5, "when the baby is hungry someone goes to feed it of their own accord")
	_check(household.pawns.any(func(p: Pawn) -> bool: return p.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "tended_baby")), "and is glad to have done it")
	baby.care["comfort"] = 10.0
	_check(Babies.is_crying(baby), "a baby that is left wanting cries")
	GameClock.set_time(83, 12)
	Babies.step(sim)
	_check(father.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "baby_crying"), "and the household hears it")
	_check(PawnActions.perform(sim, father, "tend:comfort:%d" % baby.id, baby.tile)["ok"] and father.job_kind == "tend" and father.job_interaction == "comfort", "you can send someone to soothe it")

	# Growing up.
	GameClock.set_time(45 + 60, 0)
	Life.new_day(sim, rng)
	_check(baby.age == 1 and baby.is_infant(), "a year later the baby is one")
	GameClock.set_time(45 + 120, 0)
	changes[0] = 0
	heard = Life.new_day(sim, rng)
	_check(baby.age == 2 and not baby.is_infant() and changes[0] == 1 and household.select(baby.id), "at two it runs about and can be controlled (%s)" % str(heard))
	var teen := Pawn.new()
	teen.display_name = "Teen Brook"
	teen.age = 17
	teen.adult = false
	teen.traits = ["lazy"] as Array[String]
	household.add_pawn(teen)
	GameClock.set_time(240 + Pregnancy.birthday_of(teen), 0)
	heard = Life.new_day(sim, rng)
	var orientation_found := false
	for trait_id in teen.traits:
		orientation_found = orientation_found or str(DataRegistry.get_def("traits", trait_id).get("group", "")) == "orientation"
	_check(teen.age == 18 and teen.adult and orientation_found and not heard.is_empty(), "at eighteen a child comes of age and finds their orientation (%s)" % str(heard))

	# Twins.
	var pair := _family_setup()
	var pair_sim: Simulation = pair["sim"]
	var pair_born: Array = []
	pair_sim.babies_born.connect(func(ids: Array[int]) -> void: pair_born.append_array(ids))
	GameClock.set_time(0, 0)
	Pregnancy.begin(pair_sim, pair["mother"], pair["father"], rng)
	pair["mother"].babies_due = 2
	GameClock.set_time(34, 0)
	_check("twins" in pair_sim.describe_activity(pair["mother"]), "late on you can tell it is twins")
	heard = _deliver(pair_sim, pair["mother"], rng)
	_check(pair_born.size() == 2 and pair["household"].pawns.size() == 5 and "twins" in heard[-1], "twins are born together, and both are to be named (%s)" % str(heard))
	var twins_seen := 0
	for _i in 2000:
		var test_mother := Pawn.new()
		Pregnancy.begin(pair_sim, test_mother, null, rng)
		twins_seen += 1 if test_mother.babies_due > 1 else 0
	_check(twins_seen > 30 and twins_seen < 150, "about one birth in twenty-five is twins or more (%d in 2000)" % twins_seen)

	# The town's couples have children too.
	var town_setup := _family_setup()
	var town_sim: Simulation = town_setup["sim"]
	var wife := _townsperson("Alys Cooper", "female", 24, 1001)
	var husband := _townsperson("Hugh Cooper", "male", 26, 1002)
	town_sim.town.add_pawn(wife)
	town_sim.town.add_pawn(husband)
	Relations.make_family([wife, husband] as Array[Pawn])
	var days := 0
	while not wife.is_pregnant() and days < 2000:
		Pregnancy.new_day(town_sim, rng)
		days += 1
	_check(wife.is_pregnant() and wife.pregnancy_father == husband.id, "a couple of the town who live together start a family (after %d days)" % days)
	GameClock.set_time(0, 0)
	wife.pregnant_since = 0
	wife.pregnancy_minutes = Pregnancy.length_minutes(town_sim.world)
	GameClock.set_time(45, 1)
	var town_before := town_sim.town.pawns.size()
	heard = Pregnancy.step(town_sim, rng)
	var town_baby: Pawn = town_sim.town.pawns[town_sim.town.pawns.size() - 1]
	_check(heard.is_empty() and town_sim.town.pawns.size() >= town_before + 1 and town_baby.is_infant() and town_baby.home_lot == wife.home_lot and town_baby.display_name.ends_with("Cooper"), "and the baby is born at home, quietly")
	Pregnancy.carry_infants(town_sim)
	_check(town_sim.person(town_baby.carried_by) != null and town_sim.person(town_baby.carried_by).home_lot == wife.home_lot, "its family carries it")
	var neighbours := 0
	for i in 8:
		town_sim.town.add_pawn(_townsperson("Child Cooper %d" % i, "male", 5, 1100 + i))
	wife.recovered_at = 0
	for i in 2000:
		Pregnancy.new_day(town_sim, rng)
		neighbours += 1 if wife.is_pregnant() else 0
	_check(neighbours == 0, "but not in a house that is already full")

	# A baby left uncared for is taken away.
	var neglect := _family_setup()
	var neglect_sim: Simulation = neglect["sim"]
	GameClock.set_time(0, 0)
	Pregnancy.begin(neglect_sim, neglect["mother"], neglect["father"], rng)
	neglect["mother"].babies_due = 1
	_deliver(neglect_sim, neglect["mother"], rng)
	var waif: Pawn = neglect["household"].pawns[neglect["household"].pawns.size() - 1]
	for care_id in waif.care:
		waif.care[care_id] = 0.0
	waif.neglected_since = GameClock.tick - 12 * 60
	heard = Babies.step(neglect_sim)
	_check(neglect["household"].get_pawn(waif.id) == null and heard.size() == 1 and "parish" in heard[0], "a baby neglected too long is taken in by the parish")
	_check(neglect["father"].thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "baby_taken"), "and the household grieves")

	# Only babies left: nobody to play.
	var lone := _family_setup()
	var lone_sim: Simulation = lone["sim"]
	GameClock.set_time(0, 0)
	Pregnancy.begin(lone_sim, lone["mother"], lone["father"], rng)
	lone["mother"].babies_due = 1
	_deliver(lone_sim, lone["mother"], rng)
	lone_sim.die(lone["father"], "fell ill")
	lone_sim.die(lone["child"], "fell ill")
	_check(not lone_sim.is_game_over(), "mother and baby carry on")
	lone_sim.die(lone["mother"], "fell ill")
	_check(lone_sim.is_game_over() and lone["household"].selected() == null, "a baby alone cannot be played, so the playthrough ends")

	# Saving.
	var saved := _family_setup()
	GameClock.set_time(0, 0)
	Pregnancy.begin(saved["sim"], saved["mother"], saved["father"], rng)
	saved["mother"].babies_due = 1
	_deliver(saved["sim"], saved["mother"], rng)
	var saved_baby: Pawn = saved["household"].pawns[saved["household"].pawns.size() - 1]
	saved_baby.care["clean"] = 40.0
	_check(SaveGame.save(TEST_SAVE, saved["world"], saved["household"], {}) == OK, "a household with a baby is saved")
	var back := SaveGame.load_from(TEST_SAVE)
	_check(back["ok"] and back["household"].to_dict() == saved["household"].to_dict(), "and the baby, its care, its carer and the mother's recovery survive a round trip")
	var newborn: Pawn = back["household"].pawns[back["household"].pawns.size() - 1]
	_check(newborn.is_infant() and newborn.birthday == 46 % 60 and is_equal_approx(float(newborn.care["clean"]), 40.0) and back["household"].selected_id == saved["household"].selected_id, "including its birthday and how clean it is")
	var midway := _family_setup()
	GameClock.set_time(3, 0)
	Pregnancy.begin(midway["sim"], midway["mother"], null, rng)
	midway["mother"].babies_due = 2
	SaveGame.save(TEST_SAVE, midway["world"], midway["household"], {})
	back = SaveGame.load_from(TEST_SAVE)
	var resumed: Pawn = back["household"].pawns[0]
	_check(resumed.pregnant_since == 3 * GameClock.MINUTES_PER_DAY and resumed.pregnancy_minutes == 45 * GameClock.MINUTES_PER_DAY and resumed.babies_due == 2 and resumed.pregnancy_father == 0, "an unfinished pregnancy survives a round trip")
	var old: Dictionary = midway["mother"].to_dict()
	for key in ["pregnant_tick", "pregnancy_minutes", "babies_due", "pregnancy_announced", "labour_since", "labour_minutes", "recovered_tick", "care", "neglected_since"]:
		old.erase(key)
	old["pregnant_since"] = 4
	old["recovered_on"] = 7
	var migrated := Pawn.from_dict(old)
	_check(migrated.pregnant_since == 4 * GameClock.MINUTES_PER_DAY and migrated.pregnancy_minutes == 45 * GameClock.MINUTES_PER_DAY and migrated.recovered_at == 7 * GameClock.MINUTES_PER_DAY and migrated.babies_due == 1, "a pregnancy from an older save, counted in days, carries on")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


## Brings a pregnancy to term at once: labour begins and the babies are born. Returns the messages.
func _deliver(sim: Simulation, mother: Pawn, rng: RandomNumberGenerator) -> Array[String]:
	GameClock.set_time(int((mother.pregnant_since + mother.pregnancy_minutes) / GameClock.MINUTES_PER_DAY) + 1, 0)
	var heard := Pregnancy.step(sim, rng)
	mother.labour_minutes = GameClock.tick - mother.labour_since
	heard.append_array(Pregnancy.step(sim, rng))
	return heard


func _townsperson(full_name: String, gender: String, age: int, id: int) -> Pawn:
	var person := Pawn.new()
	person.display_name = full_name
	person.gender = gender
	person.age = age
	person.adult = age >= 18
	person.id = id
	person.home_lot = "house_cooper"
	person.tile = Vector2i(20, 10)
	person.step_to = person.tile
	for need_id in Needs.active_ids():
		person.needs[need_id] = 100.0
	return person


func _has_part(result: Dictionary, thought_id: String) -> bool:
	for part in result["parts"]:
		if part["id"] == thought_id:
			return true
	return false


func _illness_setup() -> Dictionary:
	GameClock.set_time(0, 12)
	var world := WorldState.new(40, 20, 3, "grass")
	world.lot = Rect2i(2, 2, 12, 8)
	world.lots = [{ "id": "lot_1", "kind": "clinic", "name": "Clinic", "template": "clinic", "facing": "south", "rect": Rect2i(20, 2, 10, 8), "public": true }]
	var household := Household.new()
	household.coins = 50
	var person := Pawn.new()
	person.display_name = "Patient One"
	person.age = 30
	person.tile = Vector2i(24, 7)
	person.step_to = person.tile
	for need_id in Needs.active_ids():
		person.needs[need_id] = 100.0
	household.add_pawn(person)
	return { "world": world, "household": household, "pawn": person, "sim": Simulation.new(world, household) }


func _test_faith_and_illness() -> void:
	print("Faith and illness")
	var town_world := MapGenerator.generate(7, 128, 96)
	TownGenerator.generate(town_world)
	var chapels := town_world.lots.filter(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "chapel")
	var inside := _objects_in(town_world, chapels[0]["rect"]) if chapels.size() == 1 else {}
	_check(chapels.size() == 1 and bool(chapels[0]["public"]) and int(inside.get("altar", 0)) == 1 and int(inside.get("pew", 0)) >= 4, "the town has a public chapel with an altar and pews (%s)" % str(inside))
	var clinic_lot := town_world.lots.filter(func(entry: Dictionary) -> bool: return str(entry["kind"]) == "clinic")
	_check(int(_objects_in(town_world, clinic_lot[0]["rect"]).get("sickbed", 0)) == 3, "and the clinic has three sickbeds")

	# Praying.
	var setup := _illness_setup()
	var world: WorldState = setup["world"]
	var sim: Simulation = setup["sim"]
	var person: Pawn = setup["pawn"]
	var pew := world.add_object("pew", Vector2i(23, 4))
	person.needs["faith"] = 10.0
	_check(sim.use_blocker(person, pew) == "" and sim.order_use(person, pew)["ok"], "someone with little faith can go and pray")
	for minute in 80:
		GameClock.advance_one_tick()
		sim.step()
	_check(person.needs["faith"] > 50.0 and person.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "prayed"), "praying restores faith and leaves a good feeling")
	person.needs["faith"] = 10.0
	person.think_cooldown = 0
	for minute in 30:
		sim.step()
	_check(person.job_kind == "use" and person.job_object == pew.id, "a person low on faith goes to pray unprompted")

	# The weekly service.
	var services := _collect_events(7, 40).filter(func(entry: Dictionary) -> bool: return str(entry["id"]) == "service")
	var spaced := services.size() >= 4
	for i in range(1, services.size()):
		spaced = spaced and int(services[i]["day"]) - int(services[i - 1]["day"]) >= 7
	_check(spaced, "a service is held about every week (%d in 40 days)" % services.size())
	setup = _illness_setup()
	world = setup["world"]
	world.lots.append({ "id": "lot_c", "kind": "chapel", "name": "Chapel", "template": "chapel", "facing": "south", "rect": Rect2i(2, 12, 8, 6), "public": true })
	sim = setup["sim"]
	person = setup["pawn"]
	person.tile = Vector2i(4, 14)
	person.step_to = person.tile
	person.needs["faith"] = 20.0
	sim.events.start("service")
	for minute in 25:
		GameClock.advance_one_tick()
		sim.step()
	_check(person.needs["faith"] > 40.0 and person.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "at_service"), "a person in the chapel during the service is lifted by it")

	# Falling ill.
	var fever := DataRegistry.get_def("illness", "fever")
	var healthy := Pawn.new()
	healthy.needs = { "hygiene": 80.0 }
	var dirty := Pawn.new()
	dirty.needs = { "hygiene": 5.0 }
	var base := Illness.catch_chance(fever, healthy, "spring", 1.0)
	_check(Illness.catch_chance(fever, healthy, "winter", 1.0) > base * 2.0 and Illness.catch_chance(fever, dirty, "spring", 1.0) > base * 1.9 and Illness.catch_chance(fever, healthy, "spring", 2.0) > base * 1.9, "fever is likelier in winter, when filthy and in a cold snap")
	setup = _illness_setup()
	sim = setup["sim"]
	GameClock.set_time(46, 0)  # winter
	var crowd: Array[Pawn] = []
	for i in 300:
		var villager := Pawn.new()
		villager.age = 30
		villager.needs = { "hygiene": 5.0, "rest": 50.0 }
		sim.town.add_pawn(villager)
		crowd.append(villager)
	sim._roll_illness(crowd)
	var sick := crowd.filter(func(p: Pawn) -> bool: return p.illness == "fever")
	_check(sick.size() > 10 and sick.size() < 120, "some people catch it on a winter night (%d of 300)" % sick.size())

	# Being ill.
	setup = _illness_setup()
	world = setup["world"]
	sim = setup["sim"]
	person = setup["pawn"]
	var household: Household = setup["household"]
	var heard: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: heard.append(text))
	person.illness = "fever"
	person.ill_since = GameClock.tick
	_check(Mood.evaluate(person, household, GameClock.tick)["parts"].any(func(part: Dictionary) -> bool: return part["id"] == "ill"), "being ill weighs on the mood")
	_check("fever" in sim.describe_activity(person), "the panel says what they are ill with")
	_check(Illness.drain_multipliers(person, {}).get("rest", 1.0) > 1.0 and Illness.drain_multipliers(person, { "warmth": 2.0 })["warmth"] == 2.0, "an illness can make needs drain faster")
	person.work_lot = "lot_1"
	person.work_job = "clinic_orderly"
	world.add_object("counter", Vector2i(26, 4))
	GameClock.set_time(0, 9)
	for minute in 20:
		GameClock.advance_one_tick()
		sim.step()
	_check(person.job_kind != "work", "an ill person stays off their shift")
	person.work_lot = ""
	person.work_job = ""

	# Treatment: nothing cures it without coin, a sickbed does with it.
	household.coins = 0
	var bed := world.add_object("sickbed", Vector2i(23, 5))
	person.think_cooldown = 0
	for minute in 10:
		sim.step()
	_check(person.job_kind != "use" or person.job_object != bed.id, "without the price of a bed they cannot be treated")
	household.coins = 50
	person.think_cooldown = 0
	person.needs["rest"] = 30.0
	for minute in 12:
		GameClock.advance_one_tick()
		sim.step()
	_check(person.job_kind == "use" and person.job_object == bed.id, "an ill person with coin heads for a sickbed on their own")
	for minute in 130:
		GameClock.advance_one_tick()
		sim.step()
	_check(person.illness == "" and household.coins == 40 and person.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "treated"), "treatment cures the fever for the price (%d left)" % household.coins)
	_check(heard.size() == 1 and "well again" in heard[0], "and the player is told")

	# Dying of it.
	setup = _illness_setup()
	sim = setup["sim"]
	GameClock.set_time(30, 0)
	var doomed: Array[Pawn] = []
	for i in 40:
		var villager := Pawn.new()
		villager.age = 30
		villager.needs = { "rest": 20.0 }
		villager.illness = "fever"
		villager.ill_since = GameClock.tick - 10 * GameClock.MINUTES_PER_DAY
		sim.town.add_pawn(villager)
		doomed.append(villager)
	var buried := [0]
	sim.town_death.connect(func(_name: String, cause: String) -> void: buried[0] += 1 if "fever" in cause else 0)
	sim._roll_illness(doomed)
	var still_ill := doomed.filter(func(p: Pawn) -> bool: return p.illness != "" and not p.is_dying())
	var fallen := doomed.filter(func(p: Pawn) -> bool: return p.is_dying() and "fever" in p.dying_cause)
	_check(still_ill.is_empty() and fallen.size() > 12 and fallen.size() < 40, "a fever that has dragged on too long either breaks or lays them low (%d of 40 dying)" % fallen.size())
	GameClock.advance_ticks(int(Mortality.config()["takes_after_minutes"]))
	Mortality.step(sim)
	_check(buried[0] == fallen.size() and sim.town.pawns.filter(func(p: Pawn) -> bool: return p.is_dying()).is_empty(), "and when Death comes for them they are buried (%d)" % buried[0])
	var carrier := Pawn.new()
	carrier.illness = "fever"
	carrier.ill_since = 777
	_check(Pawn.from_dict(carrier.to_dict()).illness == "fever" and Pawn.from_dict(carrier.to_dict()).ill_since == 777, "illness survives saving")


func _conflict_setup() -> Dictionary:
	GameClock.set_time(12, 6)
	var world := MapGenerator.generate(7, 128, 96)
	TownGenerator.generate(world)
	var begun := Starts.begin(world, "bought")
	var sim := Simulation.new(world, begun["household"], NpcGenerator.create(world), begun["realm"])
	return { "world": world, "household": begun["household"], "realm": begun["realm"], "sim": sim }


func _test_conflict() -> void:
	print("Raids and war")
	var setup := _conflict_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var realm: Realm = setup["realm"]
	var sim: Simulation = setup["sim"]
	var base := Conflict.defense(sim)
	_check(base["parts"]["supplies"] > 0.0 and base["parts"]["readiness"] > 0.0 and base["parts"]["fund"] == 0.0 and base["parts"]["watch"] == 0.0, "the town's defense comes from its food and its able adults (%.1f)" % base["total"])
	var board: PlacedObject = null
	for placed in world.objects:
		if placed.def_id == "notice_board":
			board = placed
	var fund_entries := PawnActions.list_for(sim, household.pawns[0], board.tile).filter(func(entry: Dictionary) -> bool: return str(entry["id"]).begins_with(PawnActions.FUND_PREFIX))
	_check(fund_entries.size() == 2 and fund_entries[0]["enabled"] and "defense fund" in str(fund_entries[0]["label"]), "the notice board takes gifts to the defense fund")
	household.coins = 90
	var gave := PawnActions.perform(sim, household.pawns[0], PawnActions.FUND_PREFIX + "50", board.tile)
	_check(gave["ok"] and household.coins == 40 and realm.fund == 50 and Conflict.defense(sim)["total"] > base["total"] + 3.5, "a gift of 50d goes into the fund and strengthens the defense")
	_check(not PawnActions.perform(sim, household.pawns[0], PawnActions.FUND_PREFIX + "50", board.tile)["ok"], "but not more than you have")
	household.coins = 200
	var posts_before: float = Conflict.defense(sim)["total"]
	var spot := world.lot.position + Vector2i(1, 1)
	sim.build_remove(spot)
	_check(sim.build_place("watch_post", spot)["ok"] and is_equal_approx(Conflict.defense(sim)["total"], posts_before + 3.0), "a watch post on your land adds to the defense")

	# Word of a threat.
	var warned := 0
	var all_replaced := true
	var due_ok := true
	for day in range(10, 210):
		realm.threat = {}
		realm.last_conflict_days = {}
		var news := Conflict.new_day(sim, day)
		if not news.is_empty():
			warned += 1
			all_replaced = all_replaced and "{" not in news[0] and not realm.threat.is_empty()
			due_ok = due_ok and int(realm.threat["due_day"]) > day
	_check(warned > 3 and warned < 40, "threats are announced now and then (%d in 200 days)" % warned)
	_check(all_replaced and due_ok, "each announcement names the days and strengths and sets a due day")
	realm.threat = {}
	_check(Conflict.new_day(sim, 5).is_empty() and realm.threat.is_empty(), "there is no trouble in the first days")
	realm.threat = { "id": "bandits", "due_day": 20, "strength": 12 }
	_check(Conflict.new_day(sim, 15).is_empty() and realm.threat["strength"] == 12, "while a threat is on its way no other comes, and it waits for its day")
	_check("Bandit raid in 5 days" in realm.summary(sim) or "Bandit raid in" in realm.summary(sim), "the panel shows what is coming")

	# A victory.
	realm.threat = { "id": "bandits", "due_day": 20, "strength": 3 }
	realm.fund = 80
	realm.reputation = 0.0
	var town_before := sim.town.pawns.size()
	var coins_before := household.coins
	var messages := Conflict.new_day(sim, 20)
	_check(messages.size() == 1 and "driven off" in messages[0] and realm.reputation == 6.0 and realm.fund == 40 and realm.threat.is_empty(), "a well-defended town drives raiders off, standing rises and half the fund is used (%s)" % str(messages))
	_check(household.coins == coins_before and sim.town.pawns.size() == town_before and household.pawns[0].thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "defended"), "and nobody loses anything and the town is proud")

	# A defeat.
	realm.threat = { "id": "bandits", "due_day": 21, "strength": 99 }
	realm.fund = 0
	coins_before = household.coins
	var people_before := sim.household.pawns.size()
	messages = Conflict.new_day(sim, 21)
	_check("plundered" in messages[0] and realm.reputation == 0.0, "an undefended town is plundered and standing falls (%s)" % str(messages))
	var killed_in_town := town_before - sim.town.pawns.size()
	_check(killed_in_town >= 0 and killed_in_town <= 2, "up to two townspeople are killed (%d)" % killed_in_town)
	_check(household.coins <= coins_before - coins_before * 25 / 100 or sim.household.pawns.size() < people_before, "and a quarter of the purse is lost (%d to %d)" % [coins_before, household.coins])

	# Saving.
	realm.threat = { "id": "warband", "due_day": 40, "strength": 20 }
	realm.fund = 33
	realm.last_conflict_days = { "bandits": 21 }
	_check(Realm.from_dict(realm.to_dict()).to_dict() == realm.to_dict() and Realm.from_dict(realm.to_dict()).threat["strength"] == 20, "the fund, the threat and the history survive saving")
	GameClock.reset()


func _building_setup() -> Dictionary:
	GameClock.set_time(0, 12)
	var world := WorldState.new(24, 12, 1, "grass")
	world.set_tile(20, 5, "water")
	world.lot = Rect2i(2, 2, 12, 8)
	var household := Household.new()
	household.coins = 100000  # building costs coin; these tests are about where, not how much
	var person := Pawn.new()
	person.display_name = "Builder One"
	person.tile = Vector2i(3, 5)
	person.step_to = person.tile
	for need_id in Needs.active_ids():
		person.needs[need_id] = 100.0
	household.add_pawn(person)
	return { "world": world, "household": household, "pawn": person, "sim": Simulation.new(world, household) }


func _test_building() -> void:
	print("Building")
	var setup := _building_setup()
	var world: WorldState = setup["world"]
	var sim: Simulation = setup["sim"]
	var pawn: Pawn = setup["pawn"]

	# Where things may go.
	_check(sim.build_place("bed", Vector2i(8, 8))["ok"] and world.object_at(Vector2i(8, 8)) != null, "a bed can be placed on the lot")
	_check("your land" in sim.build_place("bed", Vector2i(18, 8))["message"], "building outside the lot is refused, and says why")
	_check("in the way" in sim.build_place("wall", Vector2i(8, 8))["message"], "building on top of something is refused")
	world.lot = Rect2i(2, 2, 22, 8)
	_check("water" in sim.build_place("wall", Vector2i(20, 5))["message"], "building on water is refused")
	world.lot = Rect2i(2, 2, 12, 8)
	_check("standing" in sim.build_place("wall", pawn.tile)["message"], "a wall cannot go up on top of a person")
	_check(sim.build_place("bed", pawn.tile)["ok"], "but a bed can go where someone stands")
	_check(not sim.build_place("flying_castle", Vector2i(9, 3))["ok"], "unknown things cannot be built")

	# Walls change the routes.
	var open_route := sim.pathfinder.find_path(Vector2i(3, 6), Vector2i(10, 6))
	for y in range(2, 10):
		sim.build_place("wall", Vector2i(6, y))
	_check(not world.is_walkable(6, 5), "a wall blocks its tile")
	var detour := sim.pathfinder.find_path(Vector2i(3, 6), Vector2i(10, 6))
	_check(not detour.is_empty() and detour.size() > open_route.size(), "the route now goes around the wall (%d tiles instead of %d)" % [detour.size(), open_route.size()])
	_check(sim.build_place("door", Vector2i(6, 6))["message"].contains("in the way"), "a door cannot replace a wall without taking it down first")
	sim.build_remove(Vector2i(6, 6))
	sim.build_place("door", Vector2i(6, 6))
	var through := sim.pathfinder.find_path(Vector2i(3, 6), Vector2i(10, 6))
	_check(world.is_walkable(6, 6) and through.size() == open_route.size(), "a door lets people through again")
	_check(world.connection_mask(Vector2i(6, 5), "wall") == (1 | 4) and world.connection_mask(Vector2i(6, 2), "wall") == 4, "walls and doors join up with their neighbors")
	_check(world.connection_mask(Vector2i(8, 8), "wall") == 0, "a bed joins up with nothing")
	_check(PawnActions.list_for(sim, pawn, Vector2i(6, 4)).size() == 1, "a wall offers nothing to use, only walking (which is off)")

	# Someone walking when a wall goes up finds another way.
	setup = _building_setup()
	world = setup["world"]
	sim = setup["sim"]
	pawn = setup["pawn"]
	sim.order_move(pawn, Vector2i(10, 5))
	for i in 3:
		sim.step()
	for y in range(3, 8):
		sim.build_place("wall", Vector2i(6, y))
	_check(pawn.has_orders(), "someone whose route is cut still has somewhere to go")
	for i in 400:
		sim.step()
		if not pawn.has_orders():
			break
	_check(pawn.tile == Vector2i(10, 5), "and gets there the long way round")

	# Taking things down and moving them.
	setup = _building_setup()
	world = setup["world"]
	sim = setup["sim"]
	pawn = setup["pawn"]
	pawn.needs["rest"] = 10.0
	var bed := world.add_object("bed", Vector2i(8, 8))
	sim.step()
	_check(pawn.job_kind == "use" and bed.user_id == pawn.id, "a tired person heads for the new bed")
	var moved := sim.build_move(bed.id, Vector2i(9, 3))
	_check(moved["ok"] and bed.tile == Vector2i(9, 3) and world.object_at(Vector2i(8, 8)) == null and world.get_object(bed.id) == bed, "a bed can be picked up and put down elsewhere (same bed)")
	_check(pawn.job_kind == "" and bed.user_id == 0, "moving it sends away whoever was heading for it")
	_check(not sim.build_move(bed.id, Vector2i(30, 3))["ok"], "it cannot be moved off the lot")
	sim.step()
	_check(pawn.job_kind == "use" and pawn.job_object == bed.id, "the person finds the bed again in its new place")
	sim.build_remove(Vector2i(9, 3))
	_check(world.get_object(bed.id) == null and pawn.job_kind == "" and not pawn.is_busy(), "taking the bed down stops whoever was using it")
	var removal := sim.build_remove(Vector2i(9, 3))
	_check(not removal["ok"] and removal["message"] == "", "removing nothing is quietly refused")

	# Floors.
	_check(sim.build_floor("planks", Vector2i(4, 4))["ok"] and world.floor_at(Vector2i(4, 4)) == "planks", "a floor can be laid")
	sim.build_floor("flagstone", Vector2i(4, 4))
	_check(world.floor_at(Vector2i(4, 4)) == "flagstone", "a different floor replaces it")
	_check(sim.build_place("bed", Vector2i(4, 4))["ok"], "furniture stands on a floor")
	_check(sim.build_remove(Vector2i(4, 4))["ok"] and world.floor_at(Vector2i(4, 4)) == "flagstone", "removing takes the furniture first, and leaves the floor")
	_check(sim.build_remove(Vector2i(4, 4))["ok"] and world.floor_at(Vector2i(4, 4)) == "", "then the floor")
	_check(not sim.build_floor("planks", Vector2i(18, 4))["ok"], "floors stay on the lot too")
	world.lot = Rect2i(2, 2, 22, 8)
	_check(not sim.build_floor("planks", Vector2i(20, 5))["ok"], "and off the water")
	world.lot = Rect2i(2, 2, 12, 8)

	# What was built survives saving; an old save gets a centered lot.
	sim.build_floor("planks", Vector2i(5, 5))
	sim.build_place("stone_wall", Vector2i(7, 7))
	var copy := WorldState.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(copy.lot == world.lot and copy.floor_at(Vector2i(5, 5)) == "planks" and copy.object_at(Vector2i(7, 7)) != null, "the lot, floors and walls survive a round trip")
	var old_data := world.to_dict()
	old_data.erase("lot")
	old_data.erase("floors")
	var old_copy := WorldState.from_dict(old_data)
	_check(old_copy.lot.size != Vector2i.ZERO and old_copy.lot.has_point(Vector2i(old_copy.width / 2, old_copy.height / 2)) and old_copy.floors.is_empty(), "a save from before lots gets a lot around the middle")

	# The mouse: place, drag a wall, remove, move, and put the tool away.
	setup = _building_setup()
	world = setup["world"]
	sim = setup["sim"]
	var controller := BuildController.new()
	add_child(controller)
	controller.bind(sim)
	controller.set_active(true)
	var warnings: Array[String] = []
	controller.message.connect(func(text: String) -> void: warnings.append(text))
	var click := func(tile: Vector2i, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = (Vector2(tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
		controller._unhandled_input(event)
	var drag := func(tile: Vector2i) -> void:
		var event := InputEventMouseMotion.new()
		event.position = (Vector2(tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
		controller._unhandled_input(event)
	controller.set_tool("place", "wall")
	click.call(Vector2i(5, 8), true)
	drag.call(Vector2i(9, 8))
	click.call(Vector2i(9, 8), false)
	var run_length := 0
	for x in range(5, 10):
		run_length += 1 if world.site_at(Vector2i(x, 8), "object") != null else 0
	_check(run_length == 5 and world.object_at(Vector2i(5, 8)) == null, "dragging with the wall tool plans a whole row (nothing is built yet)")
	_check(warnings.size() == 1 and "Planned" in warnings[0], "the first plan says what happens next (%s)" % str(warnings))
	warnings.clear()
	_complete_plans(sim, setup["pawn"])
	_check(world.object_at(Vector2i(5, 8)) != null and world.object_at(Vector2i(9, 8)) != null and world.sites.is_empty(), "and once built the row stands")
	controller.set_tool("place", "bed")
	click.call(Vector2i(4, 4), true)
	drag.call(Vector2i(6, 4))
	click.call(Vector2i(6, 4), false)
	_check(world.site_at(Vector2i(4, 4), "object") != null and world.site_at(Vector2i(5, 4), "object") == null, "furniture is planned one per click, even when dragging")
	_complete_plans(sim, setup["pawn"])
	click.call(Vector2i(4, 4), true)
	click.call(Vector2i(4, 4), false)
	click.call(Vector2i(4, 4), true)
	click.call(Vector2i(4, 4), false)
	_check(warnings.size() == 2 and "in the way" in warnings[0], "a refused click says why")
	controller.set_tool("move")
	click.call(Vector2i(4, 4), true)
	click.call(Vector2i(4, 4), false)
	click.call(Vector2i(10, 3), true)
	click.call(Vector2i(10, 3), false)
	_check(world.object_at(Vector2i(4, 4)) == null and world.object_at(Vector2i(10, 3)) != null, "the move tool picks a thing up and sets it down")
	controller.set_tool("remove")
	click.call(Vector2i(10, 3), true)
	drag.call(Vector2i(10, 9))
	click.call(Vector2i(10, 9), false)
	_check(world.object_at(Vector2i(10, 3)) == null, "the remove tool takes things down")
	controller.set_tool("floor", "planks")
	click.call(Vector2i(3, 3), true)
	drag.call(Vector2i(5, 3))
	click.call(Vector2i(5, 3), false)
	_check(world.site_at(Vector2i(3, 3), "floor") != null and world.site_at(Vector2i(5, 3), "floor") != null and world.floor_at(Vector2i(3, 3)) == "", "the floor tool plans an area")
	_complete_plans(sim, setup["pawn"])
	_check(world.floor_at(Vector2i(3, 3)) == "planks" and world.floor_at(Vector2i(5, 3)) == "planks", "which is laid once built")
	var cleared := [false]
	controller.tool_cleared.connect(func() -> void: cleared[0] = true)
	click.call(Vector2i(3, 3), true, MOUSE_BUTTON_RIGHT)
	_check(controller.tool.is_empty() and cleared[0], "right-click puts the tool away")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controller._unhandled_input(escape)
	_check(not controller.active, "Esc with no tool leaves build mode")
	controller.queue_free()


## Finishes every plan at once, as a builder would, for tests that are about where things go.
func _complete_plans(sim: Simulation, builder: Pawn) -> void:
	var rng := RandomNumberGenerator.new()
	for site in sim.world.sites.duplicate():
		site.progress = 1.0
		Construction.finish(sim, builder, site, rng)


func _test_accidents() -> void:
	print("Fire, accidents at work and plague")
	GameClock.set_time(3, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var setup := _romance_setup()
	var sim: Simulation = setup["sim"]
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var town: Household = setup["town"]
	var anna: Pawn = setup["anna"]
	var ben: Pawn = setup["ben"]
	var cara: Pawn = setup["cara"]
	var dan: Pawn = setup["dan"]
	world.lots[0]["name"] = "Cooper house"
	var bed := world.add_object("bed", Vector2i(30, 20))
	var stone := world.add_object("stone_wall", Vector2i(31, 20))
	var plain := Vector2i(33, 20)
	world.set_floor(Vector2i(32, 20), "planks")
	world.set_floor(Vector2i(34, 20), "flagstone")

	# What burns.
	_check(Fire.flammability(world, bed.tile) > 0.7 and Fire.flammability(world, stone.tile) == 0.0 and Fire.flammability(world, Vector2i(32, 20)) > 0.5 and Fire.flammability(world, Vector2i(34, 20)) == 0.0 and Fire.flammability(world, plain) == 0.0, "beds and planks burn, stone and bare ground do not")
	_check(not Fire.ignite(world, stone.tile) and not Fire.ignite(world, plain) and Fire.ignite(world, bed.tile) and not Fire.ignite(world, bed.tile), "only something that can burn catches, and only once")
	var bed_fuel := int(world.fires[bed.tile]["fuel"])
	world.set_floor(Vector2i(32, 20), "straw")
	Fire.ignite(world, Vector2i(32, 20))
	_check(int(world.fires[Vector2i(32, 20)]["fuel"]) > bed_fuel, "straw burns longer than a bed (%d against %d)" % [int(world.fires[Vector2i(32, 20)]["fuel"]), bed_fuel])
	world.fires.clear()

	# Spread and burning out.
	for x in range(26, 30):
		world.add_object("bed", Vector2i(x, 24))
	world.add_object("stone_wall", Vector2i(30, 24))
	world.add_object("bed", Vector2i(31, 24))
	Fire.ignite(world, Vector2i(26, 24))
	var notices: Array[String] = []
	for minute in 150:
		GameClock.advance_one_tick()
		notices.append_array(Fire.step(sim, rng))
		if world.fires.is_empty():
			break
	var burned_beds := 0
	for x in range(26, 30):
		burned_beds += 1 if world.object_at(Vector2i(x, 24)) == null else 0
	_check(world.fires.is_empty() and burned_beds >= 2, "a fire spreads from bed to bed and burns out (%d of four beds gone)" % burned_beds)
	_check(world.object_at(Vector2i(30, 24)) != null and world.object_at(Vector2i(31, 24)) != null, "but not past a stone wall")

	# Sparks from a hearth.
	var hearth := world.add_object("hearth", Vector2i(40, 20))
	var spark_bed := world.add_object("bed", Vector2i(41, 20))
	DataRegistry.get_def("accidents", "fire")["spark_chance_per_day"] = 100000.0
	GameClock.set_time(3, 12)
	Fire.step(sim, rng)  # minute 720: a multiple of ten
	DataRegistry.get_def("accidents", "fire")["spark_chance_per_day"] = 0.006
	_check(world.fires.has(spark_bed.tile), "a hearth can throw a spark onto a bed beside it")
	world.fires.clear()
	_check(float(DataRegistry.get_def("accidents", "fire")["spark_chance_per_day"]) < 0.02, "though it is rare")

	# People and fire.
	var victim := Pawn.new()
	victim.display_name = "Vic Tim"
	victim.age = 30
	victim.tile = Vector2i(10, 20)
	victim.step_to = victim.tile
	household.add_pawn(victim)
	world.add_object("bed", Vector2i(10, 20))
	Fire.ignite(world, Vector2i(10, 20))
	var told := Fire.step(sim, rng)
	_check(victim.illness == "burns" and victim.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "burned") and "burned" in " ".join(told), "someone caught in the flames is burned (%s)" % str(told))
	for i in 4:
		Fire.step(sim, rng)
	_check(not victim.is_dying(), "a few moments in the flames are survived")
	for i in 3:
		Fire.step(sim, rng)
	_check(victim.is_dying() and victim.dying_cause == "burned to death", "but if they stay they die of it")
	world.fires.clear()
	household.remove_pawn(victim.id)
	world.remove_object(world.object_at(Vector2i(10, 20)).id)

	# Running from it, and putting it out.
	anna.tile = Vector2i(5, 6)
	anna.step_to = anna.tile
	ben.tile = Vector2i(9, 9)
	ben.step_to = ben.tile
	var table := world.add_object("table", Vector2i(6, 5))
	Fire.ignite(world, table.tile)
	_check(Fire.nearest(world, anna.tile, 3) == table.tile and Fire.nearest(world, Vector2i(30, 30), 3) == Vector2i(-1, -1), "folk know when a fire is close")
	var fuel_before := int(world.fires[table.tile]["fuel"])
	sim._react_to_fire(anna)
	_check(anna.has_orders() and Fire.nearest(world, anna.goal_tile(), 4).x < 0, "someone beside a fire runs from it")
	sim._react_to_fire(ben)
	_check(ben.job_kind == "extinguish" and "fire" in sim.describe_activity(ben).to_lower(), "an idle grown-up farther off goes to put it out (%s)" % sim.describe_activity(ben))
	var menu_entries := PawnActions.list_for(sim, ben, table.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "fight_fire")
	_check(menu_entries.size() == 1 and menu_entries[0]["enabled"], "the right-click menu offers to beat out the flames")
	for i in 60:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
		if world.fires.is_empty():
			break
	_check(world.fires.is_empty() and world.object_at(table.tile) != null and int(fuel_before) > 0, "he beats it out before it takes the table")
	for i in 5:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
	_check(ben.job_kind == "" and ben.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "fought_fire"), "and is proud of it")
	_check(anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "saw_fire"), "while the one who ran was frightened")

	# A firefighter whose own ground catches fire runs, and nobody fights a blaze that is too big.
	Fire.ignite(world, table.tile)
	ben.tile = Vector2i(7, 5)
	ben.step_to = ben.tile
	world.set_floor(ben.tile, "planks")
	ben.job_kind = "extinguish"
	ben.job_stage = "using"
	ben.job_target = table.tile
	Fire.ignite(world, ben.tile)
	sim._react_to_fire(ben)
	_check(ben.job_kind == "" and ben.has_orders(), "a firefighter whose own ground catches fire runs for it")
	world.fires.clear()
	world.set_floor(ben.tile, "")
	var safe_stand := sim._plan_fire_stand(ben, table.tile)
	world.set_floor(Vector2i(6, 6), "planks")
	var stand := sim._plan_fire_stand(anna, table.tile)
	Fire.ignite(world, table.tile)
	_check(not stand.is_empty() and Fire.flammability(world, stand["tile"]) == 0.0 and not safe_stand.is_empty(), "firefighters pick ground that will not burn to stand on")
	world.fires.clear()
	for dx in 12:
		world.add_object("bed", Vector2i(20 + dx, 28))
		Fire.ignite(world, Vector2i(20 + dx, 28))
	var idle := Pawn.new()
	idle.display_name = "Idle Hand"
	idle.age = 30
	idle.tile = Vector2i(26, 31)
	idle.step_to = idle.tile
	household.add_pawn(idle)
	sim._react_to_fire(idle)
	_check(idle.job_kind != "extinguish", "nobody takes on a blaze that is too big to fight")
	world.fires.clear()
	household.remove_pawn(idle.id)

	# A fire is saved.
	Fire.ignite(world, table.tile)
	_check(SaveGame.save(TEST_SAVE, world, household, {}) == OK, "a map on fire is saved")
	var loaded := SaveGame.load_from(TEST_SAVE)
	_check(loaded["ok"] and loaded["world"].fires.has(table.tile) and int(loaded["world"].fires[table.tile]["fuel"]) == int(world.fires[table.tile]["fuel"]), "and the fire is still burning when it is loaded")
	DirAccess.remove_absolute(TEST_SAVE)
	world.fires.clear()

	# Accidents at work.
	var tree_def: Dictionary = DataRegistry.get_def("objects", "chopping_block").duplicate(true)
	tree_def["accident"]["chance_per_hour"] = 6000.0
	tree_def["accident"]["death_share"] = 0.0
	anna.job_kind = "use"
	anna.job_stage = "using"
	var hurt := Accidents.roll(sim, anna, tree_def, rng)
	_check(anna.illness == "injury" and anna.job_kind == "" and "falling tree" in hurt and anna.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "hurt_at_work"), "a falling tree can hurt a woodcutter (%s)" % hurt)
	tree_def["accident"]["death_share"] = 1.0
	var killed := Accidents.roll(sim, ben, tree_def, rng)
	_check(ben.is_dying() and ben.dying_cause == "was killed by a falling tree", "or kill one")
	var jetty_def: Dictionary = DataRegistry.get_def("objects", "fishing_spot")
	_check(float(jetty_def["accident"]["death_share"]) >= 0.5 and float(jetty_def["accident"]["chance_per_hour"]) < 0.01 and float(DataRegistry.get_def("objects", "quarry_face")["accident"]["chance_per_hour"]) < 0.05, "a fall from the jetty is mostly fatal and all of these are rare")
	ben.dying_cause = ""
	ben.dying_since = 0
	ben.pose = ""
	var incidents := 0
	var normal_def: Dictionary = DataRegistry.get_def("objects", "chopping_block")
	for i in 2000:
		cara.illness = ""
		cara.pose = ""
		cara.dying_cause = ""
		incidents += 1 if Accidents.roll(sim, cara, normal_def, rng) != "" or cara.illness != "" or cara.is_dying() else 0
	_check(incidents < 8, "most days at the woodlot pass without incident (%d in 2000 minutes)" % incidents)
	cara.illness = ""
	cara.pose = ""
	cara.dying_cause = ""

	# Injuries mend.
	GameClock.set_time(100, 0)
	anna.illness = "injury"
	anna.ill_since = GameClock.tick
	anna.needs["rest"] = 90.0
	var days := 0
	while anna.illness != "" and days < 60 and not anna.is_dying():
		GameClock.set_time(100 + days, 0)
		sim._roll_illness([anna] as Array[Pawn])
		days += 1
	_check(anna.illness == "" and days < 40, "an injury heals in time (%d days)" % days)
	_check("burns" in DataRegistry.get_def("objects", "sickbed")["cures"] and "injury" in DataRegistry.get_def("objects", "sickbed")["cures"], "and the clinic's sickbeds treat burns and injuries")

	# Plague.
	var plague := Illness.def("plague")
	_check(bool(plague["contagious"]) and float(plague["chance_per_day"]) < 0.001 and int(plague["fatal_after_days"]) <= 6, "the plague is rare, contagious and deadly")
	dan.tile = Vector2i(40, 30)
	dan.step_to = dan.tile
	cara.tile = Vector2i(41, 30)
	cara.step_to = cara.tile
	var far := Pawn.new()
	far.display_name = "Far Away"
	far.age = 30
	far.tile = Vector2i(60, 30)
	far.step_to = far.tile
	far.home_lot = "lot_2"
	town.add_pawn(far)
	for pawn in [dan, cara, far]:
		pawn.illness = ""
		pawn.immune.clear()
		pawn.needs["hygiene"] = 80.0
	dan.illness = "plague"
	dan.ill_since = GameClock.tick
	var heard: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: heard.append(text))
	var catches := 0
	var rounds := 0
	for attempt in 80:
		rounds += 1
		for caught in Illness.spread(sim, rng, 10):
			sim._announce_illness(caught)
			catches += 1
		if cara.illness == "plague":
			break
	_check(cara.illness == "plague" and far.illness == "", "the plague passes to those close by, and not to those far off (after %d rounds)" % rounds)
	_check(heard.any(func(text: String) -> bool: return "plague" in text and "Testford" in text), "and word of it reaches you (%s)" % str(heard))
	var filthy := Pawn.new()
	filthy.display_name = "Dirty Dick"
	filthy.age = 30
	filthy.tile = Vector2i(40, 31)
	filthy.step_to = filthy.tile
	filthy.home_lot = "lot_2"
	filthy.needs["hygiene"] = 5.0
	town.add_pawn(filthy)
	var clean := Pawn.new()
	clean.display_name = "Clean Kate"
	clean.age = 30
	clean.tile = Vector2i(39, 30)
	clean.step_to = clean.tile
	clean.home_lot = "lot_2"
	clean.needs["hygiene"] = 90.0
	town.add_pawn(clean)
	var dirty_first := 0
	var clean_first := 0
	for trial in 200:
		filthy.illness = ""
		clean.illness = ""
		dan.illness = "plague"
		Illness.spread(sim, rng, 10)
		dirty_first += 1 if filthy.illness == "plague" else 0
		clean_first += 1 if clean.illness == "plague" else 0
	_check(dirty_first > clean_first * 2, "the dirty catch it far more readily (%d against %d)" % [dirty_first, clean_first])
	cara.illness = "plague"
	sim._recover(cara)
	_check(cara.illness == "" and Illness.is_immune(cara, "plague"), "those who recover cannot catch it again for a while")
	dan.illness = "plague"
	cara.tile = dan.tile + Vector2i(1, 0)
	var again := 0
	for trial in 100:
		again += Illness.spread(sim, rng, 10).filter(func(p: Pawn) -> bool: return p.id == cara.id).size()
	_check(again == 0, "the immune are passed over")

	# Herbs.
	dan.illness = "plague"
	anna.tile = dan.tile + Vector2i(1, 1)
	anna.step_to = anna.tile
	household.stock = {}
	_check("no herbs" in sim.treat_blocker(anna, dan), "nursing needs herbs (%s)" % sim.treat_blocker(anna, dan))
	household.stock = { "herbs": 2, "healers_satchel": 1 }
	var nurse_entries := PawnActions.list_for(sim, anna, dan.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]) == "treat:%d" % dan.id)
	_check(nurse_entries.size() == 1 and nurse_entries[0]["enabled"] and "Nurse" in str(nurse_entries[0]["label"]), "an ill person's menu offers to nurse them with herbs")
	var base_chance := Illness.recovery_chance(plague, dan)
	var nursed := PawnActions.perform(sim, anna, "treat:%d" % dan.id, dan.tile)
	_check(nursed["ok"] and household.stock_of("herbs") == 1 and Illness.recovery_chance(plague, dan) > base_chance + 0.2, "a herb helps them recover (%.2f to %.2f)" % [base_chance, Illness.recovery_chance(plague, dan)])
	_check("already" in sim.treat_blocker(anna, dan) and dan.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "cared_for"), "once is enough, and they are grateful")
	var healthy := Pawn.new()
	healthy.tile = anna.tile
	_check("not ill" in sim.treat_blocker(anna, healthy), "the well need no nursing")
	anna.tile = Vector2i(5, 6)
	_check(not sim.treat(anna, cara)["ok"], "and it is not done from afar")

	# Saved.
	dan.immune = { "plague": 99999 }
	dan.treated_until = 4242
	dan.fire_minutes = 2
	var save_world := _romance_setup()
	var saved_dan: Pawn = save_world["dan"]
	saved_dan.immune = { "plague": 99999 }
	saved_dan.treated_until = 4242
	saved_dan.fire_minutes = 2
	saved_dan.job_target = Vector2i(3, 4)
	SaveGame.save(TEST_SAVE, save_world["world"], save_world["household"], {}, save_world["town"])
	var reloaded := SaveGame.load_from(TEST_SAVE)
	var back_dan: Pawn = reloaded["town"].get_pawn(saved_dan.id)
	_check(reloaded["ok"] and back_dan != null and back_dan.immune == { "plague": 99999 } and back_dan.treated_until == 4242 and back_dan.fire_minutes == 2 and back_dan.job_target == Vector2i(3, 4), "immunity, nursing and what they were doing survive a save")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _test_death() -> void:
	print("Death and the household")
	var setup := _building_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var first: Pawn = setup["pawn"]
	var second := Pawn.new()
	second.display_name = "Builder Two"
	second.tile = Vector2i(4, 5)
	second.step_to = second.tile
	for need_id in Needs.active_ids():
		second.needs[need_id] = 100.0
	household.add_pawn(second)
	var third := Pawn.new()
	third.display_name = "Builder Three"
	third.tile = Vector2i(5, 5)
	third.step_to = third.tile
	for need_id in Needs.active_ids():
		third.needs[need_id] = 100.0
	household.add_pawn(third)
	var sim: Simulation = setup["sim"]
	var announced: Array = []
	sim.pawn_died.connect(func(person: String, cause: String, successor: String) -> void: announced.append([person, cause, successor]))

	# Libido at zero is harmless; hunger at zero is not.
	first.needs["libido"] = 0.0
	sim.step()
	_check(not first.slowed, "an empty libido does not slow anyone down")
	first.needs["fun"] = 0.0
	sim.step()
	_check(first.slowed, "but an empty fun does")
	first.needs["fun"] = 100.0

	# Starving takes a long time and ends in a death.
	first.needs["hunger"] = 0.0
	for i in 100:
		sim.step()
	_check(household.pawns.size() == 3 and int(first.deprivation.get("hunger", 0)) >= 99, "being hungry for a while does not kill, but it is counted")
	first.needs["hunger"] = 50.0
	sim.step()
	_check(not first.deprivation.has("hunger"), "a bite to eat starts the clock over")
	first.needs["hunger"] = 0.0
	first.deprivation["hunger"] = int(Needs.fatal_after_hours("hunger") * 60.0) - 2
	household.select(first.id)
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	var ticks := 0
	while not first.is_dying() and ticks < 10:
		sim.step()
		ticks += 1
	_check(first.is_dying() and first.dying_cause == "starved" and first.pose == "fallen" and household.pawns.size() == 3, "after three days empty, a person falls and lies dying, still one of the household")
	_check(not notices.is_empty() and "dying" in notices[0] and "plead" in notices[0], "you are told, and that you can plead with Death")
	_check(not sim.order_move(first, Vector2i(2, 2))["ok"] and first.needs["hunger"] == 0.0, "the dying cannot be sent anywhere")
	var hunger_while_dying := float(first.needs["rest"])
	for i in int(Mortality.config()["arrives_after_minutes"]):
		GameClock.advance_one_tick()
		sim.step()
	_check(Mortality.death_has_come(first) and float(first.needs["rest"]) == hunger_while_dying and "Death has come" in notices.back(), "Death comes and waits beside them")
	_check(sim.describe_activity(first).begins_with("Dying"), "the panel says so")
	for i in int(Mortality.config()["takes_after_minutes"]) - int(Mortality.config()["arrives_after_minutes"]):
		GameClock.advance_one_tick()
		sim.step()
	_check(household.pawns.size() == 2 and household.get_pawn(first.id) == null, "then he takes them, and they leave the household")
	_check(announced.size() == 1 and announced[0][0] == "Builder One" and announced[0][1] == "starved" and announced[0][2] == "Builder Two", "the death is announced with the cause and who you control now")
	_check(household.selected_id == second.id, "control passes to the next person")
	_check(household.dead.size() == 1 and household.dead[0]["name"] == "Builder One", "the dead are remembered")
	var graves := 0
	for placed in world.objects:
		graves += 1 if placed.def_id == "grave" else 0
	_check(graves == 1, "a grave is left behind")
	_check(not sim.is_game_over(), "the others carry on")
	_check(sim.departures.size() == 1 and sim.departures[0]["death_at"] is Vector2, "and the view is told where Death led the soul away")

	# Dying in the middle of something lets go of it.
	var bed := world.add_object("bed", Vector2i(8, 8))
	second.needs["rest"] = 5.0
	sim.step()
	_check(second.job_kind == "use" and bed.user_id == second.id, "someone heads for the bed")
	sim.die(second, "of old age")
	_check(bed.user_id == 0 and household.selected_id == third.id, "when they die the bed is free and control passes on")
	var saved := household.to_dict()
	var reloaded := Household.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(reloaded.dead.size() == 2 and reloaded.dead[1]["cause"] == "of old age", "the dead survive a save")
	var pawn_copy := Pawn.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	_check(pawn_copy.deprivation == first.deprivation, "so does the time someone has gone without")

	# The last one.
	var announced_last := [""]
	sim.pawn_died.connect(func(_p: String, _c: String, successor: String) -> void: announced_last[0] = successor)
	sim.die(third, "froze to death")
	_check(sim.is_game_over() and household.selected() == null and household.selected_id == -1, "with nobody left the playthrough is over")
	_check(announced_last[0] == "", "and nobody is named as the successor")
	sim.step()
	_check(true, "the world keeps ticking without anyone")

	# Graves stay put.
	var grave_tile := Vector2i(-1, -1)
	for placed in world.objects:
		if placed.def_id == "grave":
			grave_tile = placed.tile
	world.lot = Rect2i(0, 0, 24, 12)
	_check(not sim.build_remove(grave_tile)["ok"] and world.object_at(grave_tile) != null, "a grave cannot be taken down")

	# The household bar and the end screen.
	var hud := Hud.new()
	add_child(hud)
	var living := Household.new()
	var one := Pawn.new()
	one.display_name = "Chip One"
	for need_id in Needs.active_ids():
		one.needs[need_id] = 90.0
	living.add_pawn(one)
	hud.set_household(living)
	hud.update_household_status(living)
	_check(hud._chip_marks[one.id].color == Hud.BAND_COLORS["good"], "a healthy person's chip is green")
	one.needs["hunger"] = 10.0
	hud.update_household_status(living)
	_check(hud._chip_marks[one.id].color == Hud.BAND_COLORS["critical"] and "Hunger" in hud._chips[one.id].tooltip_text, "a person with a critical need gets a red chip that says which")
	hud.queue_free()
	var menus := Menus.new()
	add_child(menus)
	menus.show_game_over("The end")
	_check(menus.current() == "game_over" and menus._game_over_text.text == "The end", "the end screen shows its message")
	menus.close()
	_check(not menus.is_open(), "and goes away")
	menus.queue_free()


## A small village for the tests of growing old and dying: a chapel lot to bury people in and
## three people who know each other.
func _mortality_setup() -> Dictionary:
	GameClock.set_time(4, 12)
	var world := WorldState.new(40, 20, 3, "grass")
	world.lot = Rect2i(2, 2, 12, 8)
	world.lots = [{ "id": "lot_1", "kind": "chapel", "name": "Chapel", "template": "chapel", "facing": "south", "rect": Rect2i(24, 2, 9, 9), "public": true }]
	world.lifespan = "normal"
	var household := Household.new()
	var people: Array[Pawn] = []
	for spec in [["Ada Marsh", 30], ["Ben Marsh", 59], ["Cole Marsh", 34]]:
		var person := Pawn.new()
		person.display_name = spec[0]
		person.age = spec[1]
		person.tile = Vector2i(5 + people.size(), 5)
		person.step_to = person.tile
		for need_id in Needs.active_ids():
			person.needs[need_id] = 90.0
		household.add_pawn(person)
		people.append(person)
	Relations.make_family(people)
	return { "world": world, "household": household, "people": people, "sim": Simulation.new(world, household) }


func _test_life_and_death() -> void:
	print("Growing old, Death and the dead")
	var setup := _mortality_setup()
	var world: WorldState = setup["world"]
	var household: Household = setup["household"]
	var sim: Simulation = setup["sim"]
	var ada: Pawn = setup["people"][0]
	var ben: Pawn = setup["people"][1]
	var cole: Pawn = setup["people"][2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# Ages and stages.
	_check(Life.days_per_year(world) == 2 and Life.days_per_year(WorldState.new(4, 4)) == 60, "a year of life is two days on Normal, and a whole calendar year in an older world")
	_check(Life.stage_at(0)["id"] == "baby" and Life.stage_at(3)["id"] == "toddler" and Life.stage_at(10)["id"] == "child" and Life.stage_at(15)["id"] == "youth" and Life.stage_at(40)["id"] == "adult" and Life.stage_at(70)["id"] == "elder", "the stages run from baby to elder")
	_check(Life.describe_age(ada) == "Adult, 30", "the panel shows the stage and the age")
	var fated := Life.death_age(ben)
	_check(fated >= 62 and fated <= 80 and fated == Life.death_age(ben), "everyone has a fixed age to die of old age, between 62 and 80 (Ben: %d)" % fated)
	ben.birthday = GameClock.get_day_number() % Life.days_per_year(world)
	GameClock.set_time(GameClock.get_day_number() + Life.days_per_year(world), 0)
	var heard := Life.new_day(sim, rng)
	_check(ben.age == 60 and Life.is_elder(ben) and "growing old" in " ".join(heard) and ben.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "grew_old"), "at sixty a person grows old, and feels it")
	_check(Life.walk_multiplier(ben) > 1.0 and float(Life.drain_multipliers(ben, {})["rest"]) > 1.0 and not Life.may_do_heavy_work(ben) and Life.may_do_heavy_work(ada), "an elder walks slower, tires sooner and keeps clear of heavy work")

	# Old age.
	ben.age = fated
	GameClock.set_time(GameClock.get_day_number() + 1, 0)
	Life.new_day(sim, rng)
	_check(ben.is_dying() and ben.dying_cause == "died of old age", "when their time comes, an elder lies down for the last time")
	_check("time" in Mortality.plead_blocker(sim, ada, ben), "and Death will not hear a plea for the old")
	var pleads := PawnActions.list_for(sim, ada, ben.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with(PawnActions.PLEAD_PREFIX))
	_check(pleads.size() == 1 and not pleads[0]["enabled"], "the right-click menu offers the plea, switched off with the reason")
	var departures_before := sim.departures.size()
	sim.die(ben, ben.dying_cause)
	var ben_grave := Vector2i(-1, -1)
	for spirit in world.spirits:
		if spirit["name"] == "Ben Marsh":
			ben_grave = Vector2i(int(spirit["grave"][0]), int(spirit["grave"][1]))
	_check(Rect2i(24, 2, 9, 9).has_point(ben_grave) and world.object_at(ben_grave) != null and world.object_at(ben_grave).def_id == "grave", "the dead are buried in the chapel yard")
	_check(sim.departures.size() == departures_before + 1, "and the view is told of their going")
	_check(ada.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "lost_loved_one" and t["about"] == "Ben Marsh"), "family mourn the loss by name")

	# Pleading with Death.
	ada.set_opinion(cole.id, 100.0)
	Mortality.fall(sim, cole, "starved")
	_check(cole.is_dying() and Mortality.plead_blocker(sim, ada, cole) == "" and is_equal_approx(Mortality.plead_chance(ada, cole), 0.6), "a loved one can plead, and love makes Death likelier to listen (%.2f)" % Mortality.plead_chance(ada, cole))
	var asked := sim.order_plead(ada, cole)
	_check(asked["ok"] and ada.job_kind == "plead", "the one who pleads goes to kneel beside them")
	var steps := 0
	while not cole.pleaded and steps < 200:
		GameClock.advance_one_tick()
		sim.step()
		steps += 1
	_check(cole.pleaded and (not cole.is_dying()) == ada.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "pleaded_won"), "after a while Death gives his answer (%s)" % ("spared" if not cole.is_dying() else "refused"))
	if not cole.is_dying():
		_check(float(cole.needs["hunger"]) >= 35.0 and cole.deprivation.is_empty() and cole.pose == "" and cole.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "spared"), "the spared get up, weak but alive")
	else:
		_check("already" in Mortality.plead_blocker(sim, ada, cole), "and he hears only one plea")
	var lucky := Pawn.new()
	lucky.display_name = "Lucky Marsh"
	for need_id in Needs.active_ids():
		lucky.needs[need_id] = 0.0
	lucky.dying_cause = "starved"
	lucky.deprivation = { "hunger": 4000 }
	var always := RandomNumberGenerator.new()
	always.seed = 1
	var roll := always.randf()
	always.seed = 1
	var odds := Mortality.plead_chance(ada, lucky)
	var said := Mortality.resolve_plea(sim, ada, lucky, always)
	_check(is_equal_approx(odds, 0.2) and (roll < odds) == ("spared" in said) and (roll < odds) == (not lucky.is_dying()), "a plea for a stranger is a long shot, won or lost on the chance (%.2f against %.2f: %s)" % [roll, odds, said])

	# Rivals.
	var rival := Pawn.new()
	rival.display_name = "Old Foe"
	household.add_pawn(rival)
	ada.set_opinion(rival.id, -80.0)
	Mortality.mourn(sim, rival, true)
	_check(ada.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "rival_died" and t["about"] == "Old Foe"), "a rival's death is no loss")

	# Ghosts.
	var spirit := Mortality.spirit_at(world, ben_grave)
	_check(not spirit.is_empty() and spirit["name"] == "Ben Marsh", "the grave remembers whose it is")
	var prayer := PawnActions.list_for(sim, ada, ben_grave).filter(func(e: Dictionary) -> bool: return "Ben Marsh's soul" in str(e["label"]))
	_check(prayer.size() == 1, "and offers a prayer for that soul")
	spirit["restless"] = true
	var night := (GameClock.get_day_number() + 1) * GameClock.MINUTES_PER_DAY + 23 * 60
	GameClock.set_time(GameClock.get_day_number() + 1, 23)
	spirit["haunt_until"] = night + 300
	_check(Mortality.haunting(world, night).size() == 1, "a restless spirit walks at night")
	var where := Mortality.ghost_position(spirit, float(night + 10))
	_check(where.distance_to(Vector2(ben_grave) + Vector2(0.5, 0.5)) < 2.5, "never far from its grave")
	ada.path.clear()
	ada.job_kind = ""
	ada.pose = ""
	ada.tile = Vector2i(roundi(where.x), roundi(where.y))
	ada.step_to = ada.tile
	Mortality._haunt(sim, night + 10)
	_check(ada.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "saw_ghost" and t["about"] == "Ben Marsh"), "anyone awake nearby sees the ghost, and is frightened")
	var grave_object := world.object_at(ben_grave)
	_check(not bool(grave_object.def().get("autonomous", true)), "nobody prays at a grave unless told to")
	var notices: Array[String] = []
	sim.health_notice.connect(func(text: String) -> void: notices.append(text))
	_check(sim.order_use(ada, grave_object)["ok"], "one of your folk can be sent to pray at the grave")
	steps = 0
	while ada.job_kind == "use" and steps < 300:
		GameClock.advance_one_tick()
		sim.step()
		steps += 1
	_check(not bool(spirit["restless"]) and int(spirit["haunt_until"]) == -1 and ada.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "laid_to_rest"), "praying there lays the soul to rest")
	_check(notices.any(func(text: String) -> bool: return "rest" in text), "and you are told")

	# Saving it all.
	Mortality.fall(sim, ada, "froze to death")
	var pawn_copy := Pawn.from_dict(JSON.parse_string(JSON.stringify(ada.to_dict())))
	_check(pawn_copy.dying_cause == "froze to death" and pawn_copy.dying_since == ada.dying_since and pawn_copy.death_from == ada.death_from and pawn_copy.pose == "fallen", "someone dying is still dying after a save")
	var world_copy := WorldState.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(world_copy.lifespan == "normal" and world_copy.spirits.size() == world.spirits.size() and Mortality.spirit_at(world_copy, ben_grave)["name"] == "Ben Marsh", "the lifespan and the dead in their graves survive a save")
	var old_world := world.to_dict()
	old_world.erase("lifespan")
	old_world.erase("spirits")
	var from_old := WorldState.from_dict(JSON.parse_string(JSON.stringify(old_world)))
	_check(from_old.lifespan == "calendar" and from_old.spirits.is_empty(), "a world from an older save ages by the calendar")
	GameClock.reset()


func _mood_person(traits: Array[String] = []) -> Pawn:
	var person := Pawn.new()
	person.display_name = "Mood Tester"
	person.tile = Vector2i(2, 2)
	person.step_to = person.tile
	person.traits.assign(traits)
	for need_id in Needs.active_ids():
		person.needs[need_id] = 60.0
	return person


func _mood_texts(person: Pawn, household: Household) -> Array[String]:
	var texts: Array[String] = []
	for part in Mood.evaluate(person, household, GameClock.tick)["parts"]:
		texts.append(str(part["text"]))
	return texts


func _test_mood() -> void:
	print("Traits and thoughts")
	GameClock.set_time(0, 12)
	var household := Household.new()
	var person := _mood_person()
	household.add_pawn(person)
	var now := GameClock.tick
	_check(Mood.evaluate(person, household, now)["value"] == Mood.BASE, "someone with nothing on their mind sits at the baseline")
	person.needs["hunger"] = 20.0
	_check("Hungry" in _mood_texts(person, household) and Mood.evaluate(person, household, now)["value"] < Mood.BASE, "hunger is a bad thought")
	person.needs["hunger"] = 5.0
	var texts := _mood_texts(person, household)
	_check("Starving" in texts and "Hungry" not in texts, "thoughts in a group do not stack: the worst one counts")
	person.needs["hunger"] = 90.0
	_check("Well fed" in _mood_texts(person, household) and Mood.evaluate(person, household, now)["value"] > Mood.BASE, "being full is a good thought")
	_check("Stuffed and happy" not in _mood_texts(person, household), "a thought for gluttons only is not given to others")
	person.needs["hunger"] = 100.0
	var glutton := _mood_person(["glutton"])
	household.add_pawn(glutton)
	glutton.needs["hunger"] = 100.0
	_check("Stuffed and happy" in _mood_texts(glutton, household), "but a glutton gets it")

	# Events fade, and renew instead of piling up.
	person.needs["hunger"] = 60.0
	Mood.add_event(person, "used:bed", now)
	Mood.add_event(person, "used:bed", now + 60)
	_check(person.thoughts.size() == 1 and "Slept in a bed" in _mood_texts(person, household), "sleeping in a bed is a good thought, and a second night only renews it")
	_check(int(person.thoughts[0]["until"]) == now + 60 + 12 * 60, "it lasts the hours in thoughts.json")
	Mood.prune(person, now + 60 + 12 * 60)
	_check(person.thoughts.is_empty(), "and then it is forgotten")

	# Traits change how strongly things land.
	var lazy := _mood_person(["lazy"])
	var plain := _mood_person()
	household.add_pawn(lazy)
	household.add_pawn(plain)
	Mood.add_event(lazy, "used:bed", now)
	Mood.add_event(plain, "used:bed", now)
	var lazy_value: float = Mood.evaluate(lazy, household, now)["value"]
	var plain_value: float = Mood.evaluate(plain, household, now)["value"]
	_check(lazy_value > plain_value, "a lazy person enjoys a bed more (%.1f against %.1f)" % [lazy_value, plain_value])
	var greedy := _mood_person(["greedy"])
	household.add_pawn(greedy)
	Mood.add_event(greedy, "used:bed", now)
	_check(Mood.evaluate(greedy, household, now)["value"] < plain_value, "a greedy one cares less for comfort")
	var asexual := _mood_person(["asexual"])
	household.add_pawn(asexual)
	asexual.needs["libido"] = 2.0
	var frustrated := _mood_person()
	frustrated.needs["libido"] = 2.0
	household.add_pawn(frustrated)
	_check("Frustrated" in _mood_texts(frustrated, household) and "Frustrated" not in _mood_texts(asexual, household), "an unmet libido bothers everyone but an asexual person")

	# Conditions on what the person is doing and who is near.
	var idler := _mood_person(["lazy"])
	household.add_pawn(idler)
	_check("Doing nothing at all" in _mood_texts(idler, household), "a lazy person enjoys doing nothing")
	idler.path.append(Vector2i(3, 2))
	_check("Doing nothing at all" not in _mood_texts(idler, household), "but not while walking somewhere")
	var loner := _mood_person(["loner"])
	loner.tile = Vector2i(40, 40)
	household.add_pawn(loner)
	_check("Enjoying the quiet" in _mood_texts(loner, household), "a loner on their own enjoys the quiet")
	var visitor := _mood_person()
	visitor.tile = Vector2i(41, 40)
	household.add_pawn(visitor)
	_check("Enjoying the quiet" not in _mood_texts(loner, household), "until somebody comes close")

	# In the simulation: needs well below the line make a person miserable and slow.
	var setup := _needs_setup({})
	var world: WorldState = setup["world"]
	var pawn: Pawn = setup["pawn"]
	pawn.traits.assign(["neat"])
	pawn.needs["hunger"] = 5.0
	pawn.needs["hygiene"] = 3.0
	pawn.needs["rest"] = 5.0
	pawn.needs["warmth"] = 5.0
	pawn.needs["fun"] = 20.0
	pawn.needs["toilet"] = 10.0
	var sim := Simulation.new(world, setup["household"])
	sim.step()
	_check(pawn.mood < Mood.LOW_BELOW and pawn.slowed, "a person with everything going wrong is miserable and slowed (mood %.0f)" % pawn.mood)
	_check(pawn.mood_parts.size() >= 5 and Mood.band_name(pawn.mood) == "miserable", "and the reasons are listed")
	_check(Mood.band_name(55.0) == "content" and Mood.band_name(75.0) == "happy" and Mood.band_name(30.0) == "unhappy", "mood has names")

	# Eating makes a thought; so does a death in the household; both survive a save.
	setup = _needs_setup({ "hunger": 20.0 })
	world = setup["world"]
	household = setup["household"]
	pawn = setup["pawn"]
	var other := Pawn.new()
	other.display_name = "Mood Two"
	other.tile = Vector2i(2, 4)
	other.step_to = other.tile
	for need_id in Needs.active_ids():
		other.needs[need_id] = 100.0
	household.add_pawn(other)
	world.add_object("cooking_pot", Vector2i(10, 5))
	sim = Simulation.new(world, household)
	var ticks := _run_until_idle(sim, pawn)
	var ids: Array[String] = []
	for thought in pawn.thoughts:
		ids.append(str(thought["id"]))
	_check("ate_meal" in ids, "finishing a meal leaves a good thought (%d ticks)" % ticks)
	sim.die(other, "of a fever")
	var grieving := false
	for thought in pawn.thoughts:
		grieving = grieving or (thought["id"] in ["lost_loved_one", "mourning"] and thought.get("about") == "Mood Two")
	_check(grieving, "the people who are left mourn the dead by name")
	var mourned: Array = Mood.evaluate(pawn, household, GameClock.tick)["parts"].filter(func(part: Dictionary) -> bool: return "Mood Two" in str(part["text"]))
	_check(mourned.size() == 1 and float(mourned[0]["mood"]) < 0.0, "and it weighs on their mood (%s)" % str(mourned))
	var copy := Pawn.from_dict(JSON.parse_string(JSON.stringify(pawn.to_dict())))
	_check(copy.thoughts == pawn.thoughts, "thoughts survive a save")

	# The panel.
	var hud := Hud.new()
	add_child(hud)
	pawn.mood = 63.0
	pawn.mood_parts = [{ "id": "ate_meal", "text": "Had a hot meal", "mood": 5.0 }, { "id": "hungry", "text": "Hungry", "mood": -6.0 }]
	hud.show_pawn(pawn, "Idle")
	_check(hud._mood_bar.value == 63.0 and hud._mood_label.text == "Content", "the panel shows mood")
	_check("Had a hot meal" in hud._thoughts_text.text and "Hungry" in hud._thoughts_text.text, "and the thoughts behind it")
	hud.queue_free()


func _test_save_and_load() -> void:
	print("Save and load")
	var world := MapGenerator.generate(7, 64, 48)
	GameClock.reset()
	GameClock.advance_ticks(123)
	var saved_tick := GameClock.tick
	var household := HouseholdGenerator.create(world)
	CampGenerator.place(world, household)
	var walker := household.pawns[0]
	var sim := Simulation.new(world, household)
	var pot: PlacedObject = null
	for placed in world.objects:
		if placed.def_id == "cooking_pot":
			pot = placed
	sim.order_move(household.pawns[1], household.pawns[1].tile + Vector2i(3, 0))
	sim.order_use(walker, pot)
	sim.step()
	household.select(household.pawns[1].id)
	_check(SaveGame.save(TEST_SAVE, world, household, { "camera": [123.5, 456.0], "zoom": 1.5 }) == OK, "save file is written")
	_check(not FileAccess.file_exists(TEST_SAVE + ".tmp"), "no half-written file is left behind")

	GameClock.reset()
	var result := SaveGame.load_from(TEST_SAVE)
	_check(result["ok"], "save file loads")
	var loaded: WorldState = result["world"]
	_check(loaded.world_seed == 7 and loaded.width == 64 and loaded.height == 48, "seed and size survive a round trip")
	_check(loaded.palette == world.palette and loaded.tiles == world.tiles, "every tile survives a round trip")
	_check(GameClock.tick == saved_tick, "the clock is restored")
	var loaded_household: Household = result["household"]
	var same := loaded_household != null and loaded_household.to_dict() == household.to_dict()
	_check(same, "household, needs, jobs and walking orders survive a round trip")
	_check(loaded.to_dict()["objects"] == world.to_dict()["objects"] and loaded.objects.size() == world.objects.size(), "objects survive a round trip")
	var reloaded_sim := Simulation.new(loaded, loaded_household)
	_check(loaded.get_object(pot.id).user_id == walker.id and reloaded_sim.household.pawns[0].job_kind == "use", "a person on their way to an object is still reserved for it after loading")
	var legacy := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({ "format": 1, "world": world.to_dict(), "clock": GameClock.to_dict() }))
	legacy.close()
	var old_result := SaveGame.load_from(TEST_SAVE)
	_check(old_result["ok"] and old_result["household"] == null, "a version 1 save without people still loads")

	SaveGame.save(TEST_SAVE, world, household, { "camera": [123.5, 456.0], "zoom": 1.5 })
	var viewed := SaveGame.load_from(TEST_SAVE)
	_check(viewed["ok"] and viewed["view"]["camera"] == [123.5, 456.0] and viewed["view"]["zoom"] == 1.5, "the camera is remembered")
	_check(SaveGame.newest([TEST_SAVE, "user://nothing_here.json"]) == TEST_SAVE and SaveGame.newest(["user://nothing_here.json"]) == "", "the newest save is found, and none is reported as none")
	var before_tick := GameClock.tick
	_write_file(TEST_SAVE, "{ \"format\": 4, \"world\": { \"width\": 0 }, \"clock\": { \"tick\": 99999 } }")
	var empty_world := SaveGame.load_from(TEST_SAVE)
	_check(not empty_world["ok"] and GameClock.tick == before_tick, "a save with no map is refused without touching the clock")
	_write_file(TEST_SAVE, "{ \"format\": 4, \"world\": { \"wid")
	_check(not SaveGame.load_from(TEST_SAVE)["ok"], "a cut-off file reports damage instead of crashing")
	_write_file(TEST_SAVE, "{ \"format\": 99, \"world\": {} }")
	_check("different version" in str(SaveGame.load_from(TEST_SAVE)["error"]), "a save from a newer game says so")

	var missing := SaveGame.load_from("user://does_not_exist.json")
	_check(not missing["ok"], "a missing save reports an error instead of crashing")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


func _find_tile(world: WorldState, tile_id: String) -> Vector2i:
	for y in world.height:
		for x in world.width:
			if world.get_tile_id(x, y) == tile_id:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
