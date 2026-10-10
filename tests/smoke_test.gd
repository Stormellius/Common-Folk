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


func _test_save_and_load() -> void:
	print("Save and load")
	var world := MapGenerator.generate(7, 64, 48)
	GameClock.reset()
	GameClock.advance_ticks(123)
	var saved_tick := GameClock.tick
	_check(SaveGame.save(TEST_SAVE, world) == OK, "save file is written")

	GameClock.reset()
	var result := SaveGame.load_from(TEST_SAVE)
	_check(result["ok"], "save file loads")
	var loaded: WorldState = result["world"]
	_check(loaded.world_seed == 7 and loaded.width == 64 and loaded.height == 48, "seed and size survive a round trip")
	_check(loaded.palette == world.palette and loaded.tiles == world.tiles, "every tile survives a round trip")
	_check(GameClock.tick == saved_tick, "the clock is restored")

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
