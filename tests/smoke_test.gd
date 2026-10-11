extends Node
## Quick checks for the milestone 1 foundations. Run them from the project folder:
##
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Prints one line per check and exits with code 1 if anything failed.

const TEST_MOD_DIR := "user://mods/smoke_test_mod"
const TEST_SAVE := "user://smoke_test_save.json"

var _failures := 0


func _ready() -> void:
	_test_registry()
	_test_mod_loading()
	_test_clock()
	_test_generator()
	_test_map_view()
	_test_hud()
	_test_pathfinding()
	_test_pawn_movement()
	_test_household()
	_test_save_and_load()
	print("")
	if _failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
	_check(DataRegistry.count("needs") == 7, "needs.json has seven needs")
	_check(DataRegistry.count("traits") >= 6, "traits.json loaded")
	_check(DataRegistry.count("names") == 3 and DataRegistry.count("appearance") == 4, "names.json and appearance.json loaded")
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
	_write_file(TEST_MOD_DIR + "/recipes.json", '[{"id":"bread","name":"Bread"}]')
	DataRegistry.reload()

	_check("Smoke Test Mod" in DataRegistry.loaded_mods, "mod in user://mods is discovered")
	_check(str(DataRegistry.get_def("tiles", "grass").get("color")) == "#123456", "mod replaces an existing entry by id")
	_check(DataRegistry.has_def("tiles", "lava"), "mod adds a new entry")
	_check(not DataRegistry.has_def("tiles", "water"), "mod removes an entry with _remove")
	_check(DataRegistry.count("recipes") == 1, "mod can add a brand new kind of content")

	for file_name in ["mod.json", "tiles.json", "recipes.json"]:
		DirAccess.remove_absolute(TEST_MOD_DIR + "/" + file_name)
	DirAccess.remove_absolute(TEST_MOD_DIR)
	DataRegistry.reload()

	_check("Smoke Test Mod" not in DataRegistry.loaded_mods, "mod is gone after its folder is removed")
	_check(str(DataRegistry.get_def("tiles", "grass").get("color")) == original_color, "base data is restored")
	_check(DataRegistry.has_def("tiles", "water"), "removed entry comes back with base data")


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
	before = GameClock.tick
	GameClock._process(1.0)
	_check(absi(GameClock.tick - before - 10) <= 1, "1x runs about 10 ticks per second")

	GameClock.set_speed(3)
	before = GameClock.tick
	GameClock._process(1.0)
	_check(absi(GameClock.tick - before - 30) <= 1, "3x runs about 30 ticks per second")

	before = GameClock.tick
	GameClock._process(10.0)
	_check(GameClock.tick - before == GameClock.MAX_TICKS_PER_FRAME, "a very long frame is capped")

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
	GameClock.reset()
	GameClock.set_speed(1)
	hud.queue_free()


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


func _test_save_and_load() -> void:
	print("Save and load")
	var world := MapGenerator.generate(7, 64, 48)
	GameClock.reset()
	GameClock.advance_ticks(123)
	var saved_tick := GameClock.tick
	var household := HouseholdGenerator.create(world)
	var walker := household.pawns[0]
	var sim := Simulation.new(world, household)
	sim.order_move(walker, walker.tile + Vector2i(3, 0))
	sim.step()
	household.select(household.pawns[1].id)
	_check(SaveGame.save(TEST_SAVE, world, household) == OK, "save file is written")

	GameClock.reset()
	var result := SaveGame.load_from(TEST_SAVE)
	_check(result["ok"], "save file loads")
	var loaded: WorldState = result["world"]
	_check(loaded.world_seed == 7 and loaded.width == 64 and loaded.height == 48, "seed and size survive a round trip")
	_check(loaded.palette == world.palette and loaded.tiles == world.tiles, "every tile survives a round trip")
	_check(GameClock.tick == saved_tick, "the clock is restored")
	var loaded_household: Household = result["household"]
	var same := loaded_household != null and loaded_household.to_dict() == household.to_dict()
	_check(same, "household, selection and walking orders survive a round trip")
	var legacy := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({ "format": 1, "world": world.to_dict(), "clock": GameClock.to_dict() }))
	legacy.close()
	var old_result := SaveGame.load_from(TEST_SAVE)
	_check(old_result["ok"] and old_result["household"] == null, "a version 1 save without people still loads")

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
