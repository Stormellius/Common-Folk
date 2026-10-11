extends Node2D
## Ties the pieces together: creates or loads a world, hands it to the views,
## and handles keyboard shortcuts. Game rules do not belong here; they go in scripts/sim.

const MAP_WIDTH := 128
const MAP_HEIGHT := 96
const SAVE_PATH := "user://savegame.json"

var world: WorldState
var sim: Simulation
var _menu_pawn_id := -1     # who the open right-click menu is for
var _menu_tile := Vector2i.ZERO  # and which tile it was opened on

@onready var map_view: MapView = $MapView
@onready var object_layer: ObjectLayer = $ObjectLayer
@onready var pawn_layer: PawnLayer = $PawnLayer
@onready var tile_cursor: TileCursor = $TileCursor
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	tile_cursor.hovered_changed.connect(_on_tile_hovered)
	pawn_layer.pawn_selected.connect(hud.set_selected)
	pawn_layer.context_menu_requested.connect(_on_context_menu_requested)
	hud.action_chosen.connect(_on_action_chosen)
	hud.pawn_chosen.connect(_on_pawn_chosen)
	GameClock.ticked.connect(_on_tick)
	_start_new_world(_pick_seed())
	_apply_launch_options()
	if not DataRegistry.load_errors.is_empty():
		hud.show_message("Data problem: %s" % DataRegistry.load_errors[0], 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			GameClock.toggle_pause()
		KEY_1, KEY_KP_1:
			GameClock.set_speed(1)
		KEY_2, KEY_KP_2:
			GameClock.set_speed(2)
		KEY_3, KEY_KP_3:
			GameClock.set_speed(3)
		KEY_G:
			tile_cursor.toggle_grid()
		KEY_TAB:
			if sim != null:
				sim.household.cycle_selection(-1 if event.shift_pressed else 1)
				_on_pawn_chosen(sim.household.selected_id)
		KEY_C:
			_center_on_selected()
		KEY_HOME:
			camera.center_on_world()
		KEY_N:
			_start_new_world(randi())
			hud.show_message("New world (seed %d)" % world.world_seed)
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
## zoom = camera zoom, look = tile to center the camera on (x,y), speed = 0 (paused) to 3,
## walk = tile (x,y) to send the selected person to at the start,
## menu = tile (x,y) to open the right-click menu on at the start,
## needs = need values for the selected person, such as rest:10,hunger:30.
## Handy for screenshots and testing.
func _launch_option(name: String) -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _pick_seed() -> int:
	var given := _launch_option("seed")
	if given != "":
		return int(given)
	randomize()
	return randi()


func _apply_launch_options() -> void:
	if _launch_option("day") != "" or _launch_option("hour") != "":
		var hour := int(_launch_option("hour")) if _launch_option("hour") != "" else 6
		GameClock.set_time(int(_launch_option("day")), hour)
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
	if _launch_option("menu") != "" and sim != null:
		var spot := _launch_option("menu").split(",")
		if spot.size() == 2:
			_on_context_menu_requested(Vector2(700, 260), Vector2i(int(spot[0]), int(spot[1])))
	if _launch_option("zoom") != "":
		var zoom_level := clampf(float(_launch_option("zoom")), CameraController.ZOOM_MIN, CameraController.ZOOM_MAX)
		camera.zoom = Vector2(zoom_level, zoom_level)


func _start_new_world(world_seed: int) -> void:
	GameClock.reset()
	var new_world := MapGenerator.generate(world_seed, MAP_WIDTH, MAP_HEIGHT)
	var household := HouseholdGenerator.create(new_world)
	CampGenerator.place(new_world, household)
	_show_world(new_world, household)


func _show_world(new_world: WorldState, household: Household) -> void:
	world = new_world
	sim = Simulation.new(world, household)
	map_view.set_world(world)
	tile_cursor.set_world(world)
	object_layer.bind(sim)
	pawn_layer.bind(sim)
	hud.close_action_menu()
	hud.set_household(household)
	camera.set_world_size(Vector2(world.width, world.height) * MapView.TILE_SIZE)
	_center_on_selected()
	hud.set_info(_describe_tile(Vector2i(-1, -1)))


func _process(_delta: float) -> void:
	if sim != null:
		var chosen := sim.household.selected()
		hud.show_pawn(chosen, sim.describe_activity(chosen) if chosen != null else "")


func _on_tick(_tick: int) -> void:
	if sim != null:
		sim.step()


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
	if not result["ok"] and result["message"] != "":
		hud.show_message(result["message"])
	hud.set_selected(sim.household.selected_id)  # an action may have switched person


func _on_pawn_chosen(id: int) -> void:
	hud.close_action_menu()
	if sim.household.select(id):
		hud.set_selected(id)
		camera.focus_on(pawn_layer.visual_position(id))


func _center_on_selected() -> void:
	var chosen := sim.household.selected() if sim != null else null
	if chosen != null:
		camera.focus_on(pawn_layer.visual_position(chosen.id))
	else:
		camera.center_on_world()


func _save() -> void:
	var err := SaveGame.save(SAVE_PATH, world, sim.household)
	if err == OK:
		hud.show_message("Game saved")
	else:
		hud.show_message("Save failed: %s" % error_string(err))


func _load() -> void:
	var result := SaveGame.load_from(SAVE_PATH)
	if result["ok"]:
		var loaded_world: WorldState = result["world"]
		var household: Household = result["household"]
		if household == null:  # a save from before there were people
			household = HouseholdGenerator.create(loaded_world)
		if loaded_world.objects.is_empty():  # a save from before there were things
			CampGenerator.place(loaded_world, household)
		_show_world(loaded_world, household)
		hud.show_message("Game loaded")
	else:
		hud.show_message("Load failed: %s" % result["error"])


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
	return "Tile (%d, %d): %s, %s\n%s" % [tile.x, tile.y, what, walk, footer]
