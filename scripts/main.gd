extends Node2D
## Ties the pieces together: the title screen, creating or loading a world, handing it to the
## views, the menus and keyboard shortcuts. Game rules do not belong here; they go in scripts/sim.

const SAVE_PATH := SaveSlots.QUICK
const AUTOSAVE_PATH := SaveSlots.AUTO

var world: WorldState
var sim: Simulation
var _menu_pawn_id := -1     # who the open right-click menu is for
var _menu_tile := Vector2i.ZERO  # and which tile it was opened on
var _loading := false           # true while a save is being put in place (no autosave then)
## False on the title screen, where the town behind is only to look at.
var _in_game := false
var _lot_picker := LotPicker.new()
var _pending := {}   # the new game being set up: seed, start, lifespan, the family drawn
var _speed_before_menu := 1     # the speed to go back to when the menus close
var _to_name: Array[int] = []  # babies of your household still waiting for a name
var _loaded_view: Dictionary = {}  # the camera of the save just loaded

@onready var map_view: MapView = $MapView
@onready var floor_layer: FloorLayer = $FloorLayer
@onready var shadow_layer: ShadowLayer = $ShadowLayer
@onready var smoke_layer: SmokeLayer = $SmokeLayer
@onready var death_layer: DeathLayer = $DeathLayer
@onready var fire_layer: FireLayer = $FireLayer
@onready var town_labels: TownLabels = $TownLabels
@onready var cloud_shadows: CloudShadows = $CloudShadows
@onready var weather: Weather = $Weather
@onready var object_layer: ObjectLayer = $ObjectLayer
@onready var site_layer: SiteLayer = $SiteLayer
@onready var roof_layer: RoofLayer = $RoofLayer
@onready var tree_layer: TreeLayer = $TreeLayer
@onready var build: BuildController = $BuildController
@onready var pawn_layer: PawnLayer = $PawnLayer
@onready var tile_cursor: TileCursor = $TileCursor
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD
@onready var menus: Menus = $Menus
@onready var audio: AudioDirector = $Audio


func _ready() -> void:
	tile_cursor.hovered_changed.connect(_on_tile_hovered)
	pawn_layer.pawn_selected.connect(hud.set_selected)
	pawn_layer.context_menu_requested.connect(_on_context_menu_requested)
	hud.action_chosen.connect(_on_action_chosen)
	hud.pawn_chosen.connect(_on_pawn_chosen)
	hud.build_toggled.connect(build.set_active)
	hud.build_tool_chosen.connect(build.set_tool)
	hud.menu_requested.connect(_open_pause)
	build.mode_changed.connect(hud.set_build_mode)
	build.tool_cleared.connect(hud.clear_build_selection)
	build.message.connect(func(text: String) -> void: hud.show_message(text))
	menus.new_game_requested.connect(_on_new_game_requested)
	menus.land_confirmed.connect(_finish_new_game)
	menus.land_cancelled.connect(_cancel_land)
	menus.land_picked.connect(_on_land_picked)
	_lot_picker.camera = camera
	_lot_picker.visible = false
	_lot_picker.picked.connect(func(lot_id: String) -> void:
		menus.mark_land(lot_id)
		_on_land_picked(lot_id))
	add_child(_lot_picker)
	menus.load_requested.connect(_on_load_requested)
	menus.save_screen_requested.connect(func() -> void: menus.open_save(_default_save_name()))
	menus.save_requested.connect(_on_save_requested)
	menus.title_requested.connect(_show_title)
	menus.quit_requested.connect(func() -> void: get_tree().quit())
	menus.closed.connect(_on_menus_closed)
	menus.baby_named.connect(_on_baby_named)
	menus.families_requested.connect(_open_families)
	menus.play_family_requested.connect(_on_play_family)
	menus.move_house_requested.connect(_on_move_house)
	GameClock.ticked.connect(_on_tick)
	GameClock.motion_ticked.connect(_on_motion_tick)
	GameClock.day_changed.connect(_on_day_changed)
	if _skips_title():
		_begin_game()
		_start_new_world(_pick_seed(), _launch_option("start"), _launch_option("lifespan") if _launch_option("lifespan") != "" else "normal")
		_apply_launch_options()
	else:
		_show_title()
	if _launch_option("screen") != "":
		_open_menu(func() -> void: _open_screen(_launch_option("screen")))
	if _launch_option("shot") != "":
		_take_screenshot(_launch_option("shot"))
	if not DataRegistry.load_errors.is_empty():
		hud.show_message("Data problem: %s" % DataRegistry.load_errors[0], 6.0)


## Any option on the command line (a seed, a start, a save to load, a screenshot...) goes straight
## into a game, unless --title=1 asks for the title screen anyway.
func _skips_title() -> bool:
	return not OS.get_cmdline_user_args().is_empty() and _launch_option("title") == ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if not _in_game or menus.is_open():
		return
	match event.keycode:
		KEY_ESCAPE:
			_open_pause()
		KEY_H:
			hud.toggle_help()
		KEY_I:
			hud.toggle_details()
		KEY_SPACE:
			GameClock.toggle_pause()
		KEY_1, KEY_KP_1:
			GameClock.set_speed(1)
		KEY_2, KEY_KP_2:
			GameClock.set_speed(2)
		KEY_3, KEY_KP_3:
			GameClock.set_speed(3)
		KEY_4, KEY_KP_4:
			GameClock.set_speed(4)
		KEY_B:
			build.toggle()
		KEY_G:
			tile_cursor.toggle_grid()
		KEY_R:
			hud.show_message(roof_layer.cycle())
		KEY_TAB:
			if sim != null:
				sim.household.cycle_selection(-1 if event.shift_pressed else 1)
				_on_pawn_chosen(sim.household.selected_id)
		KEY_C:
			_center_on_selected()
		KEY_HOME:
			_center_on_home()
		KEY_T:
			_visit_next_town()
		KEY_M:
			_toggle_overview()
		KEY_F:
			_open_menu(_open_families)
		KEY_N:
			_open_menu(menus.open_new_game)
		KEY_F5:
			_save()
		KEY_F9:
			_load()
		_:
			return
	get_viewport().set_input_as_handled()


## Options can be given after "--" on the command line, for example:
##   godot --path . -- --seed=1234 --day=50 --hour=12 --zoom=0.5 --speed=0
## seed = world seed, day = day number to start on (0 = first), hour = hour of day,
## zoom = camera zoom, look = tile to center the camera on (x,y), speed = 0 (paused) to 4,
## walk = tile (x,y) to send the selected person to at the start,
## menu = tile (x,y) to open the right-click menu on at the start,
## needs = need values for the selected person, such as rest:10,hunger:30,
## build = start in build mode with a tool, such as place:wall, floor:planks, remove or move,
## load = load the newest save right away (as F9 does),
## dying = the selected person is minutes from starving (to see the death and the hand-over),
## start = how to begin (bought, inherited or arrived; without it, and without seed or load, a start screen asks),
## shot = save a screenshot to this path a moment after starting, then quit,
## demohouse = build a small walled room with a door and a floor on the lot, using the real build commands,
## weather = clear, cloudy, rain or snow instead of the seeded weather (only changes the look),
## title = 1 to show the title screen even with other options given,
## lifespan = how fast people age in a new game (an id from data/lifespans.json; normal if not given),
## fall = minutes: the selected person fell that long ago and lies dying (to see Death come),
## ghost = 1: a townsperson has died, and their ghost walks tonight,
## screen = a menu to open at the start: pause, save, load, settings, new, name, families or game_over,
## fire = 1: the nearest thing that can burn to the selected person catches alight,
## dreams = 1: the selected person is partway up an ambition and has two wishes,
## painted = 1: people drawn as painted pictures (a preview), code_art = 1: everything drawn by code, for this run.
## Handy for screenshots and testing.
func _launch_option(name: String) -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


## For --fire=1: sets the nearest thing that can burn, within reach of the selected person, alight.
func _start_demo_fire() -> void:
	var origin := sim.household.selected().tile
	var best: PlacedObject = null
	for placed in world.objects:
		if Fire.flammability(world, placed.tile) > 0.0 and (best == null or Vector2(placed.tile - origin).length() < Vector2(best.tile - origin).length()):
			best = placed
	if best != null:
		Fire.ignite(world, best.tile)


## For looking at a wedding: your selected person engages a townsperson of their town and the two
## go to the chapel, with whoever is free; time runs on until the vows are about to be said.
func _start_demo_wedding() -> void:
	var bride := sim.household.selected()
	var chosen: Pawn = null
	for candidate in sim.town.pawns:
		if candidate.adult and candidate.partner_id == 0 and not candidate.is_infant() and candidate.age < 50 \
				and sim.attracted(bride, candidate) and sim.attracted(candidate, bride) and not Relations.are_kin(bride, candidate) \
				and str(world.town_of_lot(candidate.home_lot).get("id", "")) == str(world.home_town().get("id", "")):
			chosen = candidate
			break
	if chosen == null:
		return
	Romance.begin_dating(sim, bride, chosen)
	Romance.engage(sim, bride, chosen)
	bride.bond_since -= 5 * GameClock.MINUTES_PER_DAY
	chosen.bond_since = bride.bond_since
	bride.set_opinion(chosen.id, 60.0)
	chosen.set_opinion(bride.id, 60.0)
	for member in sim.household.pawns:
		member.needs["rest"] = 90.0
	var bed_spot := Romance._free_spot_in(sim, WorldState.HOME_LOT)
	if bed_spot == Vector2i(-1, -1):
		bed_spot = world.lot.position + Vector2i(2, 2)
	world.add_object("bed", bed_spot)  # somewhere for the new husband or wife to sleep
	var result := Romance.order_wedding(sim, bride, chosen)
	if not bool(result["ok"]):
		push_warning(str(result["message"]))
		return
	for minute in 400:
		if bride.job_stage == "using" and chosen.job_stage == "using":
			break
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
	for person in sim.people():
		person.step_ticks_done = person.step_ticks_total  # everyone is where they were headed
	var chapel := Romance._chapel_for(sim, bride, chosen)
	if not chapel.is_empty():
		camera.position = Vector2((chapel["rect"] as Rect2i).get_center() + Vector2i(0, 0)) * MapView.TILE_SIZE


func _pick_seed() -> int:
	var given := _launch_option("seed")
	if given != "":
		return int(given)
	randomize()
	return randi()


func _apply_launch_options() -> void:
	if _launch_option("load") != "":
		_load()
	if _launch_option("day") != "" or _launch_option("hour") != "":
		var hour := int(_launch_option("hour")) if _launch_option("hour") != "" else 6
		GameClock.set_time(int(_launch_option("day")), hour)
	if _launch_option("fire") != "" and sim != null and sim.household.selected() != null:
		_start_demo_fire()
	if _launch_option("caravan") != "" and sim != null:
		_start_demo_caravan()
	if _launch_option("plans") != "" and sim != null:
		_start_demo_plans(int(_launch_option("plans")))
	if _launch_option("painted") != "":
		Settings.painted_characters = _launch_option("painted") == "1"  # for this run only
	if _launch_option("code_art") != "":
		Settings.illustrated_art = _launch_option("code_art") != "1"
	if _launch_option("dreams") != "" and sim != null and sim.household.selected() != null:
		_start_demo_dreams(sim.household.selected())
	if _launch_option("wedding") != "" and sim != null and sim.household.selected() != null:
		_start_demo_wedding()
	if _launch_option("speed") != "":
		GameClock.set_speed(int(_launch_option("speed")))
	if _launch_option("look") != "":
		var cell := _launch_option("look").split(",")
		if cell.size() == 2:
			camera.position = Vector2(float(cell[0]) + 0.5, float(cell[1]) + 0.5) * MapView.TILE_SIZE
	if _launch_option("walk") != "" and sim != null:
		var goal := _launch_option("walk").split(",")
		if goal.size() == 2 and sim.household.selected() != null:
			sim.order_move(sim.household.selected(), Vector2i(int(goal[0]), int(goal[1])))
	if _launch_option("needs") != "" and sim != null and sim.household.selected() != null:
		for pair in _launch_option("needs").split(","):
			var parts := pair.split(":")
			if parts.size() == 2:
				sim.household.selected().needs[parts[0]] = float(parts[1])
	if _launch_option("skills") != "" and sim != null and sim.household.selected() != null:
		for pair in _launch_option("skills").split(","):
			var parts := pair.split(":")
			if parts.size() == 2:
				sim.household.selected().skills[parts[0]] = Skills.xp_for_level(int(parts[1]))
	if _launch_option("tool") != "" and sim != null and sim.household.selected() != null:
		Skills.equip(sim, sim.household.selected(), _launch_option("tool"), true)
	if _launch_option("spawn") != "" and sim != null and sim.household.selected() != null:
		var around := sim.household.selected().tile
		var index := 0
		for kind in _launch_option("spawn").split(","):
			index += 1
			var spot := around + Vector2i((index - 1) % 5 * 3 - 5, 2 + (index - 1) / 5 * 3)
			var animal := Fauna.spawn(world, kind, spot, sim.rng(), "household" if not Fauna.def_of(kind).get("type", "wild") == "wild" else "", WorldState.HOME_LOT)
			animal.think_at = GameClock.tick + 100000  # stand still for the picture
		camera.position = (Vector2(around) + Vector2(1.5, 3.5)) * MapView.TILE_SIZE
	if _launch_option("together") != "" and sim != null and sim.household.pawns.size() >= 2:
		for person in sim.household.pawns:
			person.needs["libido"] = 10.0
		sim.order_interact(sim.household.pawns[0], sim.household.pawns[1], "intimacy")
	if _launch_option("dying") != "" and sim != null and sim.household.selected() != null:
		var doomed := sim.household.selected()
		doomed.needs["hunger"] = 0.0
		doomed.deprivation["hunger"] = int(Needs.fatal_after_hours("hunger") * 60.0) - 4
	if _launch_option("fall") != "" and sim != null and sim.household.selected() != null:
		var fallen := sim.household.selected()
		Mortality.fall(sim, fallen, "starved")
		fallen.dying_since -= int(_launch_option("fall"))
	if _launch_option("ghost") != "" and sim != null and not sim.town.pawns.is_empty():
		var departed: Pawn = sim.town.pawns[0]
		sim.die(departed, "died of a fever")
		for spirit in world.spirits:
			if spirit["name"] == departed.display_name:
				spirit["restless"] = true
				spirit["haunt_until"] = GameClock.tick + 600
				camera.position = (Vector2(int(spirit["grave"][0]), int(spirit["grave"][1])) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	if _launch_option("demohouse") != "" and sim != null:
		_build_demo_house()
	if _launch_option("build") != "" and sim != null:
		build.set_active(true)
		var spec := _launch_option("build").split(":")
		build.set_tool(spec[0], spec[1] if spec.size() > 1 else "")
	if _launch_option("menu") != "" and sim != null:
		var spot := _launch_option("menu").split(",")
		if spot.size() == 2:
			_on_context_menu_requested(Vector2(700, 260), Vector2i(int(spot[0]), int(spot[1])))
	if _launch_option("weather") != "":
		weather.force(_launch_option("weather"))
	if _launch_option("zoom") != "":
		var zoom_level := clampf(float(_launch_option("zoom")), CameraController.ZOOM_MIN, CameraController.ZOOM_MAX)
		camera.zoom = Vector2(zoom_level, zoom_level)


## Saves the picture after a few frames and quits (for documentation and checking the look).
func _take_screenshot(path: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_demo_house() -> void:
	sim.household.coins += 1000  # building costs coin now
	var origin := world.lot.position + Vector2i(world.lot.size.x - 11, 2)
	for dy in 7:
		for dx in 9:
			sim.build_remove(origin + Vector2i(dx, dy))  # clear the camp's things out of the way
			sim.build_floor("planks" if dx < 5 else "flagstone", origin + Vector2i(dx, dy))
	for dx in 9:
		for dy in [0, 6]:
			sim.build_place("wall" if dx < 5 else "stone_wall", origin + Vector2i(dx, dy))
	for dy in range(1, 6):
		for dx in [0, 8]:
			sim.build_place("wall" if dx == 0 else "stone_wall", origin + Vector2i(dx, dy))
	sim.build_remove(origin + Vector2i(4, 6))
	sim.build_place("door", origin + Vector2i(4, 6))
	sim.build_place("wall", origin + Vector2i(5, 3))
	sim.build_place("bed", origin + Vector2i(2, 2))
	sim.build_place("hearth", origin + Vector2i(7, 2))


## For screenshots: the selected person is on the way to mastering a craft, and has two wishes.
func _start_demo_dreams(pawn: Pawn) -> void:
	pawn.ambition = "master_craftsman"
	pawn.ambition_step = 1
	pawn.skills["carpentry"] = Skills.xp_for_level(4) + 40.0
	pawn.wishes = [{ "id": "play_lute", "until": GameClock.tick + 20 * 60 }, { "id": "kiss_partner", "until": GameClock.tick + 30 * 60 }]
	pawn.ambitions_done = ["friend_to_all"] as Array[String]


## For looking at building work: the demo house gets a roof planned, a bed and a table, and two of
## your folk set to building it; time runs on `minutes` before the picture is taken.
func _start_demo_plans(minutes: int) -> void:
	_build_demo_house()
	var origin := world.lot.position + Vector2i(world.lot.size.x - 11, 2)
	sim.household.add_stock("hammer", 2)
	Construction.plan_object(sim, "table", origin + Vector2i(2, 4))
	Construction.plan_object(sim, "bench", origin + Vector2i(6, 4))
	Construction.plan_object(sim, "bed", origin + Vector2i(1, 4))
	var roofed := Construction.plan_room_roof(sim, "thatch", origin + Vector2i(2, 3))
	if not bool(roofed["ok"]):
		push_warning(str(roofed["message"]))
	for member in sim.household.pawns:
		if not member.is_infant():
			Construction.order_build(sim, member)
	for minute in minutes:
		GameClock.advance_one_tick()
		sim.step(GameClock.SUBSTEPS_PER_MINUTE)
	camera.position = (Vector2(origin) + Vector2(4.5, 3.5)) * MapView.TILE_SIZE


## For looking at a caravan: one sets out for the home town and the time runs on until it has made
## camp on the square; the camera goes to it.
func _start_demo_caravan() -> void:
	var cart := Caravans.spawn(sim, sim.rng(), str(world.home_town().get("id", "")))
	if cart == null:
		return
	for minute in 3000:
		if cart.state == "camped":
			break
		GameClock.advance_one_tick()
		for step in GameClock.SUBSTEPS_PER_MINUTE:
			Caravans.step_motion(sim)
		Caravans.step(sim, sim.rng())
	camera.position = (Vector2(cart.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE


# --- the title screen and the menus ----------------------------------------------

## The title screen, over a town to look at: a fresh world at dusk, its people going about their
## evening while the camera drifts slowly over the rooftops.
func _show_title() -> void:
	_in_game = false
	audio.listening = false
	build.set_active(false)
	hud.close_action_menu()
	_start_new_world(randi(), "bought", "normal")
	GameClock.set_time(randi() % 60, 20)
	GameClock.set_speed(1)
	hud.visible = false
	tile_cursor.visible = false
	camera.zoom = Vector2(0.8, 0.8)
	camera.center_on_world()
	camera.drift = Vector2(16, 6)
	camera.input_enabled = false
	menus.show_title(_describe_newest_save())


## From the title screen (or the end screen) into a game: the HUD comes back and the camera is
## the player's again.
func _begin_game() -> void:
	_in_game = true
	audio.listening = true
	hud.visible = true
	tile_cursor.visible = true
	camera.drift = Vector2.ZERO
	camera.input_enabled = true
	camera.zoom = Vector2.ONE


## Opens a menu over the game: the clock stops and the camera is left alone until it closes.
func _open_menu(open: Callable) -> void:
	if not menus.is_open():
		_speed_before_menu = GameClock.speed_level
		GameClock.set_speed(0)
		camera.input_enabled = false
		hud.close_action_menu()
		build.set_active(false)
	open.call()


func _open_pause() -> void:
	var date := GameClock.get_date()
	var note := "%s %d, year %d  ·  %s" % [date["season_name"], date["day"], date["year"], GameClock.get_time_text()]
	_open_menu(func() -> void: menus.show_pause(note))


## For --screen: one of the menus by name.
func _open_screen(screen: String) -> void:
	match screen:
		"save":
			menus.open_save(_default_save_name())
		"load":
			menus.open_load()
		"settings":
			menus.open_settings()
		"new":
			menus.open_new_game()
		"create":
			menus.open_new_game()
			menus.open_create()
		"land":
			menus.open_new_game()
			_on_new_game_requested(42, "bought", "normal")
		"name":
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var baby := PersonFactory.make(rng, "Brook", [], 0)
			menus.open_naming(baby, "A baby %s for the Brook family, born to Maud." % ("girl" if baby.gender == "female" else "boy"), baby.display_name.get_slice(" ", 0), [])
		"families":
			_open_families()
		"game_over":
			menus.show_game_over("Gisela Brook starved.\n\nYour folk have all passed on, after 12 days.")
		_:
			_open_pause()


## The families screen: who the player could be, the empty houses, and what has happened in the towns.
func _open_families() -> void:
	if sim == null:
		return
	var who := "You follow the %s family." % Families.family_name(sim.household.pawns) if not sim.household.pawns.is_empty() else "Your line has ended; take up another family."
	menus.open_families(Families.rows(sim), Families.empty_rows(sim), Families.chronicle_lines(sim), who)


func _on_play_family(lot_id: String) -> void:
	var result := Families.play(sim, lot_id)
	if not bool(result["ok"]):
		menus.show_families_note(str(result["message"]))
		return
	_after_family_change(str(result["message"]))


func _on_move_house(lot_id: String) -> void:
	var result := Families.move(sim, lot_id)
	if not bool(result["ok"]):
		menus.show_families_note(str(result["message"]))
		return
	_after_family_change(str(result["message"]))


## The household changed hands or homes: look at it afresh.
func _after_family_change(message: String) -> void:
	menus.close()
	hud.set_household(sim.household)
	_on_pawn_chosen(sim.household.selected_id)
	_center_on_selected()
	hud.show_message(message, 6.0)


func _on_menus_closed() -> void:
	if _in_game:
		camera.input_enabled = true
		GameClock.set_speed(_speed_before_menu)


func _on_new_game_requested(world_seed: int, start_id: String, lifespan: String) -> void:
	# The world is made and shown first, so that the player can look about and choose where to settle.
	_pending = { "seed": world_seed, "start": start_id, "lifespan": lifespan, "design": menus.family_design.duplicate(true) }
	_in_game = false
	audio.listening = false
	build.set_active(false)
	hud.close_action_menu()
	hud.visible = false
	tile_cursor.visible = false
	_start_new_world(world_seed, start_id, lifespan, _pending["design"])
	GameClock.set_speed(0)
	var options := Starts.land_options(world)
	_lot_picker.show_options(options, WorldState.HOME_LOT)
	camera.drift = Vector2.ZERO
	camera.input_enabled = true
	camera.zoom = Vector2(0.5, 0.5)
	camera.focus_on((Vector2(world.lot.get_center()) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE)
	var start_def := DataRegistry.get_def("starts", start_id)
	var funds := int(start_def.get("coins", Economy.start_coins()))
	var homed := str(start_def.get("house", "")) != ""
	menus.open_land(options, WorldState.HOME_LOT, funds, "A house is waiting on your plot." if homed else "Your land is bare ground and a camp.")


func _on_land_picked(lot_id: String) -> void:
	for option in Starts.land_options(world):
		if str(option["id"]) == lot_id:
			camera.focus_on((Vector2(option["rect"].get_center()) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE)


func _cancel_land() -> void:
	_lot_picker.hide_picker()
	camera.input_enabled = false
	camera.drift = Vector2(16, 6)
	menus.back_to_create()


## The plot is chosen: the world is made again with the player on it, and the game begins.
func _finish_new_game(lot_id: String) -> void:
	_lot_picker.hide_picker()
	_begin_game()
	_start_new_world(int(_pending.get("seed", randi())), str(_pending.get("start", "")), str(_pending.get("lifespan", "normal")), _pending.get("design", {}), lot_id)
	menus.close()
	var builds := str(DataRegistry.get_def("starts", str(_pending.get("start", ""))).get("house", "")) == ""
	GameClock.set_speed(0 if builds else 1)
	if builds:
		build.set_active(true)
		hud.show_message("Raise a home with your %s. Press Space when you are ready for time to pass." % Economy.format(sim.household.coins), 9.0)
	else:
		hud.show_message("A new life begins. The world's seed is %d." % world.world_seed, 4.0)


func _on_load_requested(path: String) -> void:
	var error := _load_path(path)
	if error != "":
		menus.show_load_error(error)
		return
	_begin_game()
	menus.close()
	_restore_view_after_load()
	if sim.is_game_over():
		_open_menu(func() -> void: menus.show_game_over("This household has died out."))
		return
	GameClock.set_speed(1)


func _on_save_requested(slot_name: String) -> void:
	SaveSlots.make_dir()
	var err := _write_save(SaveSlots.slot_path(slot_name), slot_name)
	if err != OK:
		menus.show_save_error("Could not save: %s" % error_string(err))
		return
	menus.close()
	hud.show_message("Saved \"%s\"" % slot_name)


## "The Brook family, Spring 3, year 1", as a name for a new save.
func _default_save_name() -> String:
	var date := GameClock.get_date()
	return "The %s family, %s %d, year %d" % [_family_name(), date["season_name"], date["day"], date["year"]]


func _family_name() -> String:
	var head := sim.household.get_pawn(sim.realm.head_id) if sim != null else null
	if head == null and sim != null:
		head = sim.household.selected()
	return head.display_name.get_slice(" ", 1) if head != null else "Nobody's"


## What a save says about itself in the load list: whose it is and when in the game.
func _save_meta(slot_name: String) -> Dictionary:
	var date := GameClock.get_date()
	return {
		"name": slot_name,
		"family": _family_name(),
		"folk": sim.household.playable().size(),
		"date": "%s %d, year %d" % [date["season_name"], date["day"], date["year"]],
		"time": GameClock.get_time_text(),
		"seed": world.world_seed,
	}


## For the title screen's Continue button: the newest save, described.
func _describe_newest_save() -> String:
	var path := SaveSlots.newest()
	if path == "":
		return ""
	var meta := SaveSlots.read_meta(path)
	if meta.has("family"):
		return "The %s family, %s" % [str(meta["family"]), str(meta.get("date", ""))]
	return "Your last save"


func _start_new_world(world_seed: int, start_id: String = "", lifespan: String = "normal", design: Dictionary = {}, lot_id: String = "") -> void:
	GameClock.reset()
	var new_world := RegionGenerator.generate(world_seed)  # terrain, the towns, their roads, the player's lot
	new_world.lifespan = lifespan if DataRegistry.has_def("lifespans", lifespan) else "normal"
	if new_world.lot.size == Vector2i.ZERO:  # no town described in the data
		new_world.lot = WorldState.centered_lot(new_world.width, new_world.height)
	Starts.choose_lot(new_world, lot_id)
	var begun := Starts.begin(new_world, start_id, design)  # the household, its land and its camp
	_show_world(new_world, begun["household"], NpcGenerator.create(new_world), begun["realm"])


func _show_world(new_world: WorldState, household: Household, town: Household = null, realm: Realm = null) -> void:
	world = new_world
	sim = Simulation.new(world, household, town, realm)
	sim.realm_notice.connect(_on_realm_notice)
	sim.health_notice.connect(_on_realm_notice)
	sim.pawn_died.connect(_on_pawn_died)
	sim.household_changed.connect(func() -> void: hud.set_household(sim.household))
	sim.babies_born.connect(_on_babies_born)
	_to_name.clear()
	sim.town_death.connect(_on_town_death)
	sim.event_started.connect(_on_event_started)
	sim.event_ended.connect(_on_event_ended)
	map_view.set_world(world)
	tile_cursor.set_world(world)
	floor_layer.bind(world)
	shadow_layer.bind(world)
	smoke_layer.bind(sim)
	cloud_shadows.set_world(world)
	weather.bind(world)
	object_layer.bind(sim)
	site_layer.bind(sim)
	roof_layer.bind(world)
	pawn_layer.bind(sim)
	death_layer.bind(sim)
	fire_layer.bind(sim)
	town_labels.bind(world)
	build.bind(sim)
	audio.bind(sim, camera)
	tree_layer.bind(world, camera, map_view)
	hud.close_action_menu()
	hud.set_household(household)
	camera.set_world_size(Vector2(world.width, world.height) * MapView.TILE_SIZE)
	_center_on_selected()
	hud.set_info(_describe_tile(Vector2i(-1, -1)))


func _process(_delta: float) -> void:
	if sim != null and _in_game:
		hud.update_household_status(sim.household)
		var chosen := sim.household.selected()
		hud.show_pawn(chosen, sim.describe_activity(chosen) if chosen != null else "", sim.job_text(chosen) if chosen != null else "", sim.relationship_lines(chosen) if chosen != null else [], Ambitions.summary(sim, chosen) if chosen != null else {}, Clothing.worn(sim, chosen) if chosen != null else "")
		hud.set_events(sim.events.names())
		hud.set_purse(sim.household.coins, sim.household.stock)
		hud.set_animals(Fauna.kept_text(sim))
		hud.set_building(Construction.summary(sim))
		hud.set_realm(sim.realm.summary(sim))
		var here := world.town_at(chosen.tile) if chosen != null else {}
		hud.set_place(str(here["name"]) if not here.is_empty() else ("Open country" if chosen != null and not world.towns.is_empty() else ""))


func _on_pawn_died(person: String, cause: String, successor: String) -> void:
	if not _in_game:
		return  # the town behind the title screen
	hud.set_household(sim.household)
	if successor != "":
		hud.show_message("%s %s. You now control %s." % [person, cause, successor], 6.0)
		_on_pawn_chosen(sim.household.selected_id)
	else:
		var days := GameClock.get_day_number() + 1
		_open_menu(func() -> void: menus.show_game_over("%s %s.\n\nYour folk have all passed on, after %d days." % [person, cause, days]))


## Babies born into your household are named one at a time, in a pop-up that stops the clock.
func _on_babies_born(ids: Array[int]) -> void:
	if not _in_game:
		return
	_to_name.append_array(ids)
	if not menus.is_open():
		_name_next_baby()


func _name_next_baby() -> void:
	while not _to_name.is_empty():
		var baby := sim.person(_to_name.pop_front())
		if baby == null or not baby.is_infant():
			continue
		var mother := sim.person(baby.carried_by)
		var family := baby.display_name.get_slice(" ", 1)
		var what := "girl" if baby.gender == "female" else "boy"
		var intro := "A baby %s for the %s family" % [what, family] if family != "" else "A baby %s" % what
		if mother != null and mother.gender == "female":
			intro += ", born to %s." % mother.display_name.get_slice(" ", 0)
		else:
			intro += "."
		var twin := false
		for other in sim.household.pawns:
			twin = twin or (other.id != baby.id and other.is_infant() and other.birthday == baby.birthday and other.age == 0)
		if twin:
			intro += " A twin!"
		var used: Array[String] = []
		for other in sim.people():
			used.append(other.display_name.get_slice(" ", 0))
		_open_menu(func() -> void: menus.open_naming(baby, intro, baby.display_name.get_slice(" ", 0), used))
		return


func _on_baby_named(baby_id: int, given: String) -> void:
	var baby := sim.person(baby_id) if sim != null else null
	if baby != null:
		sim.rename(baby, given)
		hud.set_household(sim.household)
	_name_next_baby()


func _on_town_death(person: String, cause: String) -> void:
	if _in_game:
		hud.show_message("%s of the town %s." % [person, cause], 5.0)


func _on_event_started(_event_name: String, text: String) -> void:
	if _in_game:
		hud.show_message(text, 5.0)


func _on_realm_notice(text: String) -> void:
	if _in_game:
		hud.show_message(text, 6.0)


func _on_event_ended(event_name: String) -> void:
	if _in_game:
		hud.show_message("%s is over." % event_name, 3.0)


func _on_tick(_tick: int) -> void:
	if sim != null:
		sim.step(0)  # the people have been walking in between, on motion_ticked


func _on_motion_tick() -> void:
	if sim != null:
		sim.step_motion()


func _on_context_menu_requested(screen_position: Vector2, tile: Vector2i) -> void:
	var pawn := sim.household.selected()
	if pawn == null:
		return
	var actions := PawnActions.list_for(sim, pawn, tile)
	if actions.is_empty():
		return
	_menu_pawn_id = pawn.id
	_menu_tile = tile
	var tile_name := str(DataRegistry.get_def("tiles", world.get_tile_id(tile.x, tile.y)).get("name", ""))
	hud.open_action_menu(screen_position, "%s  -  %s" % [pawn.display_name.get_slice(" ", 0), tile_name], actions)


func _on_action_chosen(action_id: String) -> void:
	var pawn := sim.household.get_pawn(_menu_pawn_id)
	if pawn == null:
		return
	var result := PawnActions.perform(sim, pawn, action_id, _menu_tile)
	if result["message"] != "":
		hud.show_message(result["message"])
	hud.set_selected(sim.household.selected_id)  # an action may have switched person


func _on_pawn_chosen(id: int) -> void:
	hud.close_action_menu()
	if sim.household.select(id):
		hud.set_selected(id)
		camera.focus_on(pawn_layer.visual_position(id))


## The camera goes to the player's own town.
func _center_on_home() -> void:
	if world != null and not world.towns.is_empty():
		camera.focus_on(Vector2(world.home_center()) * MapView.TILE_SIZE)
	else:
		camera.center_on_world()


## The camera goes to the next town along, starting from whichever is nearest now.
func _visit_next_town() -> void:
	if world == null or world.towns.is_empty():
		return
	var nearest := 0
	for i in world.towns.size():
		var here := Vector2(world.towns[i]["center"]) * MapView.TILE_SIZE
		if here.distance_to(camera.position) < (Vector2(world.towns[nearest]["center"]) * MapView.TILE_SIZE).distance_to(camera.position):
			nearest = i
	var current: Vector2 = Vector2(world.towns[nearest]["center"]) * MapView.TILE_SIZE
	var next := nearest
	if camera.position.distance_to(current) < MapView.TILE_SIZE * 12.0:
		next = (nearest + 1) % world.towns.size()
	camera.focus_on(Vector2(world.towns[next]["center"]) * MapView.TILE_SIZE)
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x, 0.45, 1.5)
	hud.show_message("%s" % str(world.towns[next]["name"]), 2.0)


var _overview_return := {}

## Pulls the camera right back to see the whole map, and back again.
func _toggle_overview() -> void:
	if world == null:
		return
	if _overview_return.is_empty():
		_overview_return = { "position": camera.position, "zoom": camera.zoom }
		var view := get_viewport().get_visible_rect().size
		var fit := minf(view.x / (world.width * MapView.TILE_SIZE), view.y / (world.height * MapView.TILE_SIZE))
		camera.zoom = Vector2.ONE * maxf(CameraController.ZOOM_MIN, fit)
		camera.position = Vector2(world.width, world.height) * MapView.TILE_SIZE / 2.0
	else:
		camera.zoom = _overview_return["zoom"]
		camera.focus_on(_overview_return["position"])
		_overview_return = {}


func _center_on_selected() -> void:
	var chosen := sim.household.selected() if sim != null else null
	if chosen != null:
		camera.focus_on(pawn_layer.visual_position(chosen.id))
	else:
		camera.center_on_world()


## F5: the quick save.
func _save() -> void:
	var err := _write_save(SAVE_PATH, "Quick save")
	if err == OK:
		hud.show_message("Game saved")
	else:
		hud.show_message("Save failed: %s" % error_string(err))


## A new day: keep a spare copy in case something goes wrong (unless turned off in Settings).
## Skipped when nobody is left, and on the title screen.
func _on_day_changed(_day: int) -> void:
	if sim == null or not _in_game or sim.is_game_over() or _loading or not Settings.autosave:
		return
	if _write_save(AUTOSAVE_PATH, "Autosave") == OK:
		hud.show_message("Autosaved", 1.5)


func _write_save(path: String, slot_name: String) -> Error:
	var view := { "camera": [camera.position.x, camera.position.y], "zoom": camera.zoom.x }
	var err := SaveGame.save(path, world, sim.household, view, sim.town, sim.events, sim.realm)
	if err == OK:
		SaveSlots.write_meta(path, _save_meta(slot_name))
	return err


## F9: loads the newest save of any kind.
func _load() -> void:
	var path := SaveSlots.newest()
	var error := _load_path(path) if path != "" else "no save file found"
	if error != "":
		hud.show_message("Load failed: %s" % error)
		return
	_begin_game()
	_restore_view_after_load()
	if sim.is_game_over():
		_open_menu(func() -> void: menus.show_game_over("This household has died out."))
	var date := GameClock.get_date()
	hud.show_message("Loaded %s: %s %d, %s" % [SaveSlots.read_meta(path).get("name", "your save"), date["season_name"], date["day"], GameClock.get_time_text()])


## Puts a saved game in place. Returns "" or what went wrong.
func _load_path(path: String) -> String:
	var result := SaveGame.load_from(path)
	if not result["ok"]:
		return str(result["error"])
	var loaded_world: WorldState = result["world"]
	var household: Household = result["household"]
	if household == null:  # a save from before there were people
		household = HouseholdGenerator.create(loaded_world)
	if loaded_world.objects.is_empty():  # a save from before there were things
		CampGenerator.place(loaded_world, household)
	_loading = true
	_show_world(loaded_world, household, result["town"], result["realm"])
	sim.events.load_dict(result["events"])
	_loading = false
	_loaded_view = result["view"]
	return ""



## The camera where it was when the game was saved.
func _restore_view_after_load() -> void:
	var view := _loaded_view
	if view.has("camera") and view["camera"] is Array and view["camera"].size() == 2:
		camera.position = Vector2(float(view["camera"][0]), float(view["camera"][1]))
		var saved_zoom := clampf(float(view.get("zoom", 1.0)), CameraController.ZOOM_MIN, CameraController.ZOOM_MAX)
		camera.zoom = Vector2(saved_zoom, saved_zoom)


func _on_tile_hovered(tile: Vector2i) -> void:
	hud.set_info(_describe_tile(tile))


func _describe_tile(tile: Vector2i) -> String:
	var footer := "Seed %d    Mods loaded: %d" % [world.world_seed, DataRegistry.loaded_mods.size()]
	if tile.x < 0:
		return footer
	var tile_id := world.get_tile_id(tile.x, tile.y)
	var tile_name := str(DataRegistry.get_def("tiles", tile_id).get("name", tile_id))
	var walk := "walkable" if world.is_walkable(tile.x, tile.y) else "blocked"
	var placed := world.object_at(tile)
	var what := tile_name if placed == null else "%s with %s" % [tile_name, placed.display_name().to_lower()]
	var town := world.town_at(tile)
	var place := "%s: " % str(town["name"]) if not town.is_empty() else ""
	return "%sTile (%d, %d): %s, %s\n%s" % [place, tile.x, tile.y, what, walk, footer]
