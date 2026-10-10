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


func is_walkable(x: int, y: int) -> bool:
	var tile_id := get_tile_id(x, y)
	if tile_id == "":
		return false
	return bool(DataRegistry.get_def("tiles", tile_id).get("walkable", true))


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
	return world
