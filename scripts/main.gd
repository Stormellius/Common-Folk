extends Node2D
## Ties the pieces together: creates or loads a world, hands it to the views,
## and handles keyboard shortcuts. Game rules do not belong here; they go in scripts/sim.

const MAP_WIDTH := 128
const MAP_HEIGHT := 96
const SAVE_PATH := "user://savegame.json"

var world: WorldState

@onready var map_view: MapView = $MapView
@onready var tile_cursor: TileCursor = $TileCursor
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	tile_cursor.hovered_changed.connect(_on_tile_hovered)
	_start_new_world(_pick_seed())
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


## A seed can be given on the command line: godot --path . -- --seed=1234
func _pick_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	randomize()
	return randi()


func _start_new_world(world_seed: int) -> void:
	GameClock.reset()
	_show_world(MapGenerator.generate(world_seed, MAP_WIDTH, MAP_HEIGHT))


func _show_world(new_world: WorldState) -> void:
	world = new_world
	map_view.set_world(world)
	tile_cursor.set_world(world)
	camera.set_world_size(Vector2(world.width, world.height) * MapView.TILE_SIZE)
	camera.center_on_world()
	hud.set_info(_describe_tile(Vector2i(-1, -1)))


func _save() -> void:
	var err := SaveGame.save(SAVE_PATH, world)
	if err == OK:
		hud.show_message("Game saved")
	else:
		hud.show_message("Save failed: %s" % error_string(err))


func _load() -> void:
	var result := SaveGame.load_from(SAVE_PATH)
	if result["ok"]:
		_show_world(result["world"])
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
	return "Tile (%d, %d): %s, %s\n%s" % [tile.x, tile.y, tile_name, walk, footer]
