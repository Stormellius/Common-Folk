class_name WorldState
extends RefCounted
## The world as plain data. Nothing in here draws anything or touches the scene
## tree: the map view only reads this, and saving is just turning it into a Dictionary.
##
## Tiles are stored as indexes into a palette of tile ids ("grass", "water"...),
## which keeps the data small and keeps save files readable and mod-friendly.

var world_seed: int = 0
var width: int = 0
var height: int = 0
## Tile ids used by this world. Index 0 is the default tile every cell starts as.
var palette: PackedStringArray = PackedStringArray()
## One palette index per cell, row by row.
var tiles: PackedInt32Array = PackedInt32Array()
## Things standing on the map (beds, pots...). Each takes one tile.
var objects: Array[PlacedObject] = []

var _next_object_id := 1
var _object_at_tile := {}  # Vector2i -> PlacedObject


func _init(p_width: int = 0, p_height: int = 0, p_seed: int = 0, default_tile: String = "grass") -> void:
	width = p_width
	height = p_height
	world_seed = p_seed
	palette.append(default_tile)
	tiles.resize(width * height)  # filled with 0, the default tile


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func index_of(x: int, y: int) -> int:
	return y * width + x


func set_tile(x: int, y: int, tile_id: String) -> void:
	if not in_bounds(x, y):
		return
	tiles[index_of(x, y)] = _palette_index_for(tile_id)


## Returns the tile id at a cell, or "" if the cell is outside the map.
func get_tile_id(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return ""
	return palette[tiles[index_of(x, y)]]


## True if people can walk on this tile: walkable ground with nothing blocking it.
func is_walkable(x: int, y: int) -> bool:
	if not is_ground_walkable(x, y):
		return false
	var blocker: PlacedObject = _object_at_tile.get(Vector2i(x, y))
	return blocker == null or not blocker.blocks_walking()


## Whether the ground itself (ignoring objects) can be walked on.
func is_ground_walkable(x: int, y: int) -> bool:
	var tile_id := get_tile_id(x, y)
	if tile_id == "":
		return false
	return bool(DataRegistry.get_def("tiles", tile_id).get("walkable", true))


# --- objects -------------------------------------------------------------------

func object_at(tile: Vector2i) -> PlacedObject:
	return _object_at_tile.get(tile)


func get_object(id: int) -> PlacedObject:
	for placed in objects:
		if placed.id == id:
			return placed
	return null


## An object can go on any walkable ground that has no object yet.
func can_place_object(tile: Vector2i) -> bool:
	return is_ground_walkable(tile.x, tile.y) and not _object_at_tile.has(tile)


## Puts an object on the map. Returns it, or null if the tile is taken, blocked or the
## definition does not exist. Anything that finds routes must rebuild its map afterwards.
func add_object(def_id: String, tile: Vector2i) -> PlacedObject:
	if not DataRegistry.has_def("objects", def_id) or not can_place_object(tile):
		return null
	var placed := PlacedObject.new()
	placed.id = _next_object_id
	_next_object_id += 1
	placed.def_id = def_id
	placed.tile = tile
	objects.append(placed)
	_object_at_tile[tile] = placed
	return placed


## How slow a tile is to walk across (1.0 is normal). Blocked and unknown tiles give 0.
func get_move_cost(x: int, y: int) -> float:
	var tile_id := get_tile_id(x, y)
	if tile_id == "":
		return 0.0
	return float(DataRegistry.get_def("tiles", tile_id).get("move_cost", 1.0))


func _palette_index_for(tile_id: String) -> int:
	var found := palette.find(tile_id)
	if found == -1:
		palette.append(tile_id)
		found = palette.size() - 1
	return found


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"seed": world_seed,
		"width": width,
		"height": height,
		"palette": Array(palette),
		"tiles": Array(tiles),
		"objects": objects.map(func(placed: PlacedObject) -> Dictionary: return placed.to_dict()),
	}


static func from_dict(data: Dictionary) -> WorldState:
	var world := WorldState.new(int(data.get("width", 0)), int(data.get("height", 0)), int(data.get("seed", 0)))
	world.palette = PackedStringArray()
	for tile_id in data.get("palette", []):
		world.palette.append(str(tile_id))
	var saved_tiles: Array = data.get("tiles", [])
	world.tiles.resize(world.width * world.height)
	for i in mini(saved_tiles.size(), world.tiles.size()):
		world.tiles[i] = int(saved_tiles[i])  # JSON numbers load as floats
	for saved in data.get("objects", []):
		if saved is Dictionary:
			var placed := PlacedObject.from_dict(saved)
			if DataRegistry.has_def("objects", placed.def_id):
				world.objects.append(placed)
				world._object_at_tile[placed.tile] = placed
				world._next_object_id = maxi(world._next_object_id, placed.id + 1)
	return world
