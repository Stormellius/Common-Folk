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
	_test_town()
	_test_economy()
	_test_social()
	_test_events()
	_test_realm()
	_test_faith_and_illness()
	_test_conflict()
	_test_pregnancy()
	_test_death()
	_test_mood()
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
	# The start screen.
	var picked: Array[String] = []
	hud.start_chosen.connect(func(id: String) -> void: picked.append(id))
	_check(not hud.is_start_choice_open(), "the start screen is hidden until asked for")
	hud.show_start_choice(DataRegistry.get_list("starts"))
	_check(hud.is_start_choice_open() and hud._start_buttons.size() == 3, "it shows a button for each way of beginning")
	hud._start_buttons["arrived"].pressed.emit()
	_check(picked == ["arrived"], "picking one reports it")
	hud.hide_start_choice()
	_check(not hud.is_start_choice_open(), "and it can be put away")
	hud.set_realm("Burgher, Freehold")
	_check(hud._realm_label.visible and hud._realm_label.text == "Burgher, Freehold", "the realm lines show under the purse")
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
		var on_road := rects[i].intersects(Rect2i(center.x - 44, center.y, 89, 2)) or rects[i].intersects(Rect2i(center.x, center.y - 26, 2, 55))
		apart = apart and not on_road
		for j in range(i + 1, rects.size()):
			apart = apart and not rects[i].intersects(rects[j])
	_check(apart, "no two lots overlap and none sits on a road")
	_check(world.get_tile_id(center.x, center.y) == "dirt" and world.get_tile_id(center.x + 1, center.y + 1) == "dirt", "the roads cross in the middle")
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
	_check(again_town.to_dict() == town.to_dict(), "the same seed gives the same people")

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
	var strangers_met := 0
	for minute in 2 * GameClock.MINUTES_PER_DAY:
		GameClock.advance_one_tick()
		big_sim.step()
		if minute % 60 == 0:
			for villager in town.pawns:
				lowest_social = minf(lowest_social, float(villager.needs["social"]))
	for villager in town.pawns:
		for other in town.pawns:
			if other.home_lot != villager.home_lot and villager.opinion_of(other.id) > 0.0:
				strangers_met += 1
	_check(strangers_met > 0, "over two days the townspeople get to know people from other households (%d acquaintances)" % strangers_met)
	_check(lowest_social > 0.0, "and nobody in town goes completely without company (lowest %.0f)" % lowest_social)
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
	_check(not townswoman, "townswomen never conceive")

	# The months go by.
	var heard: Array[String] = []
	var changes := [0]
	sim.household_changed.connect(func() -> void: changes[0] += 1)
	mother.pregnant_since = 0
	GameClock.set_time(5, 0)
	var feel := Mood.evaluate(mother, household, GameClock.tick)
	_check(not Pregnancy.is_known(mother) and Pregnancy.new_day(sim, rng).is_empty() and not _has_part(feel, "expecting"), "early on nobody knows")
	GameClock.set_time(12, 0)
	heard = Pregnancy.new_day(sim, rng)
	_check(Pregnancy.is_known(mother) and heard.size() == 1 and "expecting" in heard[0], "after a while she is known to be expecting (%s)" % str(heard))
	_check(_has_part(Mood.evaluate(mother, household, GameClock.tick), "expecting"), "and it lifts her spirits")
	_check(is_equal_approx(float(Pregnancy.drain_multipliers(mother, {})["hunger"]), 1.3) and Pregnancy.drain_multipliers(father, {}).is_empty(), "she gets hungrier and more tired")
	_check(not sim._needs_break(mother), "and still works")
	GameClock.set_time(34, 0)
	_check(Pregnancy.is_heavy(mother) and sim._needs_break(mother) and _has_part(Mood.evaluate(mother, household, GameClock.tick), "heavy") and not _has_part(Mood.evaluate(mother, household, GameClock.tick), "expecting"), "in the last weeks she is heavy, low and off work")
	_check("expecting" in sim.describe_activity(mother), "and the panel says so")

	# The birth.
	GameClock.set_time(45, 0)
	var before := household.pawns.size()
	heard = Pregnancy.new_day(sim, rng)
	_check(household.pawns.size() == before + 1 and not mother.is_pregnant() and heard.size() == 1 and "gave birth" in heard[0], "the baby is born into the household (%s)" % str(heard))
	var baby: Pawn = household.pawns[household.pawns.size() - 1]
	_check(baby.age == 0 and baby.is_infant() and not baby.adult and baby.traits.size() == 2 and baby.home_lot == mother.home_lot and baby.display_name.ends_with("Brook"), "a newborn, with two traits and the family name")
	_check(baby.opinion_of(mother.id) == Relations.FAMILY_START and mother.opinion_of(baby.id) == Relations.FAMILY_START and father.opinion_of(baby.id) == Relations.FAMILY_START, "the family loves it")
	_check(changes[0] == 1 and mother.recovered_on == 45 + 15 and not Pregnancy.can_conceive(mother), "the household was told, and mother needs time to recover")
	GameClock.set_time(60, 0)
	_check(Pregnancy.can_conceive(mother), "and may conceive again later")
	_check(mother.thoughts.any(func(t: Dictionary) -> bool: return t["id"] == "new_baby"), "everyone is glad of the baby")

	# A baby is carried and cannot be controlled.
	_check(not household.select(baby.id) and household.selected_id != baby.id, "a baby cannot be chosen")
	household.select(mother.id)
	var landed := []
	for i in 6:
		household.cycle_selection(1)
		landed.append(household.selected_id)
	_check(not (baby.id in landed) and household.playable().size() == before, "cycling through the household skips the baby")
	mother.tile = Vector2i(9, 9)
	mother.step_to = mother.tile
	Pregnancy.carry_infants(sim)
	_check(baby.tile == mother.tile and baby.carried_by == mother.id, "the baby goes where its mother goes")
	_check(sim.interaction_blocker(father, baby, "chat") != "" and PawnActions.list_for(sim, father, baby.tile).filter(func(e: Dictionary) -> bool: return str(e["id"]).ends_with(":%d" % baby.id)).is_empty(), "nobody chats with a baby")
	var hunger_before := float(baby.needs["hunger"])
	for i in 30:
		GameClock.advance_one_tick()
		sim.step()
	_check(float(baby.needs["hunger"]) == hunger_before, "a baby does not go hungry or wander")
	sim.die(mother, "fell ill")
	Pregnancy.carry_infants(sim)
	_check(household.get_pawn(baby.carried_by) != null and baby.carried_by != mother.id and not sim.is_game_over(), "if mother dies someone else carries the baby, and the household carries on")

	# Growing up.
	GameClock.set_time(45 + 60, 0)
	Pregnancy.new_day(sim, rng)
	_check(baby.age == 1 and baby.is_infant(), "a year later the baby is one")
	GameClock.set_time(45 + 120, 0)
	changes[0] = 0
	heard = Pregnancy.new_day(sim, rng)
	_check(baby.age == 2 and not baby.is_infant() and changes[0] == 1 and household.select(baby.id), "at two it runs about and can be controlled (%s)" % str(heard))
	var teen := Pawn.new()
	teen.display_name = "Teen Brook"
	teen.age = 17
	teen.adult = false
	teen.traits = ["lazy"] as Array[String]
	household.add_pawn(teen)
	GameClock.set_time(240 + Pregnancy.birthday_of(teen), 0)
	heard = Pregnancy.new_day(sim, rng)
	var orientation_found := false
	for trait_id in teen.traits:
		orientation_found = orientation_found or str(DataRegistry.get_def("traits", trait_id).get("group", "")) == "orientation"
	_check(teen.age == 18 and teen.adult and orientation_found and not heard.is_empty(), "at eighteen a child comes of age and finds their orientation (%s)" % str(heard))

	# Only babies left: nobody to play.
	var lone := _family_setup()
	var lone_sim: Simulation = lone["sim"]
	GameClock.set_time(45, 0)
	lone["mother"].pregnant_since = 0
	Pregnancy.new_day(lone_sim, rng)
	lone_sim.die(lone["father"], "fell ill")
	lone_sim.die(lone["child"], "fell ill")
	_check(not lone_sim.is_game_over(), "mother and baby carry on")
	lone_sim.die(lone["mother"], "fell ill")
	_check(lone_sim.is_game_over() and lone["household"].selected() == null, "a baby alone cannot be played, so the playthrough ends")

	# Saving.
	var saved := _family_setup()
	saved["mother"].pregnant_since = 0
	saved["mother"].pregnancy_father = saved["father"].id
	saved["mother"].recovered_on = 7
	GameClock.set_time(45, 0)
	Pregnancy.new_day(saved["sim"], rng)
	_check(SaveGame.save(TEST_SAVE, saved["world"], saved["household"], {}) == OK, "a household with a baby is saved")
	var back := SaveGame.load_from(TEST_SAVE)
	_check(back["ok"] and back["household"].to_dict() == saved["household"].to_dict(), "and the baby, its carer and the mother's recovery survive a round trip")
	var newborn: Pawn = back["household"].pawns[back["household"].pawns.size() - 1]
	_check(newborn.is_infant() and newborn.birthday == 45 % 60 and back["household"].selected_id == saved["household"].selected_id, "including its birthday")
	var midway := _family_setup()
	midway["mother"].pregnant_since = 4
	SaveGame.save(TEST_SAVE, midway["world"], midway["household"], {})
	back = SaveGame.load_from(TEST_SAVE)
	_check(back["household"].pawns[0].pregnant_since == 4 and back["household"].pawns[0].pregnancy_father == 0, "an unfinished pregnancy survives a round trip")
	DirAccess.remove_absolute(TEST_SAVE)
	GameClock.reset()


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
	_check(chapels.size() == 1 and bool(chapels[0]["public"]) and int(inside.get("altar", 0)) == 1 and int(inside.get("pew", 0)) == 8, "the town has a public chapel with an altar and eight pews (%s)" % str(inside))
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
	var still_ill := doomed.filter(func(p: Pawn) -> bool: return p.illness != "" and sim.town.get_pawn(p.id) != null)
	_check(still_ill.is_empty() and buried[0] > 12 and buried[0] < 40, "a fever that has dragged on too long either breaks or kills (%d of 40 died)" % buried[0])
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
		grieving = grieving or thought["id"] == "grief"
	_check(grieving, "a death in the household is a bad thought for the people who are left")
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
