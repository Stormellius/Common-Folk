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
	_test_actions()
	_test_needs()
	_test_building()
	_test_death()
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
	_check(DataRegistry.count("needs") >= 7, "needs.json has at least the seven starting needs")
	_check(DataRegistry.count("traits") >= 6, "traits.json loaded")
	_check(DataRegistry.count("names") == 3 and DataRegistry.count("appearance") == 4 and DataRegistry.count("objects") >= 6, "names, appearance and objects loaded")
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
		if button.tooltip_text == "Timber wall":
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
	_check("social" not in active and "faith" not in active, "needs with nothing to fix them, or optional ones, stay dormant")
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
		if str(entry["id"]).begins_with(PawnActions.INTERACT_PREFIX):
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


func _building_setup() -> Dictionary:
	GameClock.set_time(0, 12)
	var world := WorldState.new(24, 12, 1, "grass")
	world.set_tile(20, 5, "water")
	world.lot = Rect2i(2, 2, 12, 8)
	var household := Household.new()
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
	_check("lot" in sim.build_place("bed", Vector2i(18, 8))["message"], "building outside the lot is refused, and says why")
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
		run_length += 1 if world.object_at(Vector2i(x, 8)) != null else 0
	_check(run_length == 5, "dragging with the wall tool lays a whole row")
	controller.set_tool("place", "bed")
	click.call(Vector2i(4, 4), true)
	drag.call(Vector2i(6, 4))
	click.call(Vector2i(6, 4), false)
	_check(world.object_at(Vector2i(4, 4)) != null and world.object_at(Vector2i(5, 4)) == null, "furniture goes down one per click, even when dragging")
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
	_check(world.floor_at(Vector2i(3, 3)) == "planks" and world.floor_at(Vector2i(5, 3)) == "planks", "the floor tool covers an area")
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
	var ticks := 0
	while household.pawns.size() == 3 and ticks < 10:
		sim.step()
		ticks += 1
	_check(household.pawns.size() == 2 and household.get_pawn(first.id) == null, "after three days empty, a person dies and leaves the household")
	_check(announced.size() == 1 and announced[0][0] == "Builder One" and announced[0][1] == "starved" and announced[0][2] == "Builder Two", "the death is announced with the cause and who you control now")
	_check(household.selected_id == second.id, "control passes to the next person")
	_check(household.dead.size() == 1 and household.dead[0]["name"] == "Builder One", "the dead are remembered")
	var graves := 0
	for placed in world.objects:
		graves += 1 if placed.def_id == "grave" else 0
	_check(graves == 1, "a grave is left behind")
	_check(not sim.is_game_over(), "the others carry on")

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
	hud.show_game_over("The end")
	_check(hud._game_over_panel.visible and hud._game_over_label.text == "The end", "the end screen shows its message")
	hud.show_game_over("")
	_check(not hud._game_over_panel.visible, "and hides again")
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
	_check(same, "household, needs, jobs and walking orders survive a round trip")
	_check(loaded.to_dict()["objects"] == world.to_dict()["objects"] and loaded.objects.size() == world.objects.size(), "objects survive a round trip")
	var reloaded_sim := Simulation.new(loaded, loaded_household)
	_check(loaded.get_object(pot.id).user_id == walker.id and reloaded_sim.household.pawns[0].job_kind == "use", "a person on their way to an object is still reserved for it after loading")
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
