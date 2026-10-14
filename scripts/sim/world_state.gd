class_name WorldState
extends RefCounted
## The world as plain data. Nothing in here draws anything or touches the scene
## tree: the map view only reads this, and saving is just turning it into a Dictionary.
##
## Tiles are stored as indexes into a palette of tile ids ("grass", "water"...),
## which keeps the data small and keeps save files readable and mod-friendly.

## The id of the player's own lot (Pawn.home_lot of the household).
const HOME_LOT := "home"

var world_seed: int = 0
var width: int = 0
var height: int = 0
## Something on a tile was built, moved or removed (an object or a floor). The views redraw
## and the path finder updates that one cell; see Simulation.
signal tile_changed(tile: Vector2i)

## Tile ids used by this world. Index 0 is the default tile every cell starts as.
var palette: PackedStringArray = PackedStringArray()
## One palette index per cell, row by row.
var tiles: PackedInt32Array = PackedInt32Array()
## Things standing on the map (beds, pots...). Each takes one tile.
var objects: Array[PlacedObject] = []
## The player's home lot: the only place they may build. An empty rect means no lot.
var lot := Rect2i()
## The other lots of the town (see TownGenerator): { "id", "kind", "name", "template", "facing",
## "rect": Rect2i, "public": bool }. Things on a private lot can only be used by the people who
## live there (Pawn.home_lot); public ones (tavern, shop, clinic, green) by anyone. Land outside
## every lot is free to all.
var lots: Array[Dictionary] = []
## The settlements on the map: { "id", "name", "kind" (town, village, hamlet...), "profile", "center":
## Vector2i, "rect": Rect2i (the lots and streets), "home": bool (the one the player lives in) }.
## Every lot above says which it is in with "town".
var towns: Array[Dictionary] = []
## Land the player holds, by lot id, with the kind of title (an id from data/titles.json). The home
## lot ("home") always counts as theirs; a business lot is added when they take it on.
var titles: Dictionary = {}
## The household was evicted from the home lot (see Realm): it is no longer theirs to build on.
var home_lost := false
## Floors laid on the ground (Vector2i -> floor id from data/floors.json). They sit under
## objects, so a bed can stand on planks.
var floors: Dictionary = {}
## How fast people age: an id from data/lifespans.json (see Life). A world from an older save
## goes by the calendar, as it always did.
var lifespan := "calendar"
## What is burning (see Fire): tile -> { "since": tick it caught, "fuel": minutes left }.
var fires: Dictionary = {}
## One entry for each of the dead who lies in a grave (see Mortality): { "name", "look", "grave":
## [x, y], "restless": bool, "haunt_until": tick }.
var spirits: Array[Dictionary] = []

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
	tile_changed.emit(tile)
	return placed


## Takes an object off the map. Returns false if there is no such object. Whoever was using
## it must be told (Simulation does that).
func remove_object(id: int) -> bool:
	var placed := get_object(id)
	if placed == null:
		return false
	objects.erase(placed)
	_object_at_tile.erase(placed.tile)
	tile_changed.emit(placed.tile)
	return true


## Picks an object up and sets it down on another tile (same id). False if the new tile
## cannot take it.
func move_object(id: int, to_tile: Vector2i) -> bool:
	var placed := get_object(id)
	if placed == null or not can_place_object(to_tile):
		return false
	var from_tile := placed.tile
	_object_at_tile.erase(from_tile)
	placed.tile = to_tile
	_object_at_tile[to_tile] = placed
	tile_changed.emit(from_tile)
	tile_changed.emit(to_tile)
	return true


## Which of the four neighbors hold an object of the same `connects` group, as a bitmask:
## 1 north, 2 east, 4 south, 8 west. Walls and doors use it to join up.
func connection_mask(tile: Vector2i, group: String) -> int:
	var mask := 0
	var steps := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in steps.size():
		var neighbor: PlacedObject = _object_at_tile.get(tile + steps[i])
		if neighbor != null and str(neighbor.def().get("connects", "")) == group:
			mask |= 1 << i
	return mask


func in_lot(tile: Vector2i) -> bool:
	return lot.has_point(tile)


## Whether the player may build on this tile: the home lot or any other lot they hold.
func can_build_at(tile: Vector2i) -> bool:
	if lot.has_point(tile):
		return not home_lost
	var here := lot_at(tile)
	return not here.is_empty() and titles.has(str(here["id"]))


## The rectangles of every lot the player holds (the home lot first).
func held_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if lot.size != Vector2i.ZERO and not home_lost:
		rects.append(lot)
	for entry in lots:
		if titles.has(str(entry["id"])):
			rects.append(entry["rect"])
	return rects


## Tiles in a lot.
func lot_area(lot_id: String) -> int:
	var rect: Rect2i = get_lot(lot_id).get("rect", Rect2i())
	return rect.size.x * rect.size.y


## The lot a tile belongs to: { "id", "public", ... }, or empty if it is open land. The player's
## own lot is { "id": "home", "public": false }.
func lot_at(tile: Vector2i) -> Dictionary:
	if lot.has_point(tile):
		return { "id": HOME_LOT, "kind": "home", "name": "Your lot", "public": false, "rect": lot }
	for entry in lots:
		if (entry["rect"] as Rect2i).has_point(tile):
			return entry
	return {}


## The settlement a tile is in (inside its lots and streets, with a margin), or empty in open country.
func town_at(tile: Vector2i, margin: int = 6) -> Dictionary:
	for entry in towns:
		if (entry["rect"] as Rect2i).grow(margin).has_point(tile):
			return entry
	return {}


func get_town(town_id: String) -> Dictionary:
	for entry in towns:
		if entry["id"] == town_id:
			return entry
	return {}


## The settlement a lot belongs to (the player's lot is in the home town), or empty.
func town_of_lot(lot_id: String) -> Dictionary:
	if lot_id == HOME_LOT:
		return home_town()
	return get_town(str(get_lot(lot_id).get("town", "")))


## The town the player lives in, or empty if the map has none.
func home_town() -> Dictionary:
	for entry in towns:
		if bool(entry.get("home", false)):
			return entry
	return towns[0] if not towns.is_empty() else {}


## The middle of the home town, or of the map if there is none.
func home_center() -> Vector2i:
	var town := home_town()
	if not town.is_empty():
		return town["center"]
	return Vector2i(width / 2, height / 2)


func get_lot(lot_id: String) -> Dictionary:
	if lot_id == HOME_LOT and lot.size != Vector2i.ZERO:
		return { "id": HOME_LOT, "kind": "home", "name": "Your lot", "public": false, "rect": lot }
	for entry in lots:
		if entry["id"] == lot_id:
			return entry
	return {}


# --- floors ----------------------------------------------------------------------

func floor_at(tile: Vector2i) -> String:
	return str(floors.get(tile, ""))


## Lays (or with "" clears) a floor. Only on ground people can stand on.
func set_floor(tile: Vector2i, floor_id: String) -> bool:
	if floor_id == "":
		if not floors.has(tile):
			return false
		floors.erase(tile)
		tile_changed.emit(tile)
		return true
	if not DataRegistry.has_def("floors", floor_id) or not is_ground_walkable(tile.x, tile.y) or floors.get(tile, "") == floor_id:
		return false
	floors[tile] = floor_id
	tile_changed.emit(tile)
	return true


## A lot of the given size centered on the map, kept inside it.
static func centered_lot(map_width: int, map_height: int, lot_width: int = 30, lot_height: int = 20) -> Rect2i:
	var size := Vector2i(mini(lot_width, map_width), mini(lot_height, map_height))
	return Rect2i(Vector2i((map_width - size.x) / 2, (map_height - size.y) / 2), size)


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

## The tiles as compressed bytes in base64, since a big map would make a very long list of numbers.
func _pack_tiles() -> String:
	var bytes := PackedByteArray()
	bytes.resize(tiles.size())
	for i in tiles.size():
		bytes[i] = tiles[i]
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_ZSTD))


func _unpack_tiles(text: String) -> void:
	var bytes := Marshalls.base64_to_raw(text).decompress(tiles.size(), FileAccess.COMPRESSION_ZSTD)
	for i in mini(bytes.size(), tiles.size()):
		tiles[i] = bytes[i]


## Gives a world whose lots came from before there were towns one town around them all.
func _adopt_lots_as_one_town() -> void:
	var bounds := Rect2i()
	for entry in lots:
		bounds = (entry["rect"] as Rect2i) if bounds.size == Vector2i.ZERO else bounds.merge(entry["rect"])
	if lot.size != Vector2i.ZERO:
		bounds = lot if bounds.size == Vector2i.ZERO else bounds.merge(lot)
	var town := { "id": "town_1", "name": "Ashford", "kind": "town", "profile": "town", "center": Vector2i(width / 2, height / 2), "rect": bounds, "home": true }
	towns.append(town)
	for entry in lots:
		entry["town"] = "town_1"

func to_dict() -> Dictionary:
	return {
		"seed": world_seed,
		"width": width,
		"height": height,
		"palette": Array(palette),
		"tiles_z": _pack_tiles(),
		"towns": towns.map(func(entry: Dictionary) -> Dictionary:
			var rect: Rect2i = entry["rect"]
			var center: Vector2i = entry["center"]
			var saved: Dictionary = entry.duplicate()
			saved["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
			saved["center"] = [center.x, center.y]
			return saved),
		"objects": objects.map(func(placed: PlacedObject) -> Dictionary: return placed.to_dict()),
		"lot": [lot.position.x, lot.position.y, lot.size.x, lot.size.y],
		"titles": titles.duplicate(),
		"home_lost": home_lost,
		"lots": lots.map(func(entry: Dictionary) -> Dictionary:
			var rect: Rect2i = entry["rect"]
			var saved: Dictionary = entry.duplicate()
			saved["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
			return saved),
		"floors": floors.keys().map(func(cell: Vector2i) -> Array: return [cell.x, cell.y, floors[cell]]),
		"lifespan": lifespan,
		"spirits": spirits.duplicate(true),
		"fires": fires.keys().map(func(tile: Vector2i) -> Array: return [tile.x, tile.y, int(fires[tile]["since"]), int(fires[tile]["fuel"])]),
	}


static func from_dict(data: Dictionary) -> WorldState:
	var world := WorldState.new(int(data.get("width", 0)), int(data.get("height", 0)), int(data.get("seed", 0)))
	world.palette = PackedStringArray()
	for tile_id in data.get("palette", []):
		world.palette.append(str(tile_id))
	world.tiles.resize(world.width * world.height)
	if data.has("tiles_z"):
		world._unpack_tiles(str(data["tiles_z"]))
	else:  # an older save wrote every tile out as a number
		var saved_tiles: Array = data.get("tiles", [])
		for i in mini(saved_tiles.size(), world.tiles.size()):
			world.tiles[i] = int(saved_tiles[i])  # JSON numbers load as floats
	for saved in data.get("objects", []):
		if saved is Dictionary:
			var placed := PlacedObject.from_dict(saved)
			if DataRegistry.has_def("objects", placed.def_id):
				world.objects.append(placed)
				world._object_at_tile[placed.tile] = placed
				world._next_object_id = maxi(world._next_object_id, placed.id + 1)
	var saved_lot: Variant = data.get("lot")
	if saved_lot is Array and saved_lot.size() >= 4:
		world.lot = Rect2i(int(saved_lot[0]), int(saved_lot[1]), int(saved_lot[2]), int(saved_lot[3]))
	else:  # a save from before there were lots
		world.lot = centered_lot(world.width, world.height)
	world.home_lost = bool(data.get("home_lost", false))
	var saved_titles: Variant = data.get("titles")
	if saved_titles is Dictionary:
		for lot_id in saved_titles:
			world.titles[str(lot_id)] = str(saved_titles[lot_id])
	else:  # a save from before land titles: the home lot was simply yours
		world.titles[HOME_LOT] = "freehold"
	for saved in data.get("lots", []):
		if saved is Dictionary and saved.get("rect") is Array and saved["rect"].size() >= 4:
			var rect: Array = saved["rect"]
			var entry: Dictionary = saved.duplicate()
			entry["rect"] = Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
			entry["public"] = bool(saved.get("public", false))
			world.lots.append(entry)
	for saved in data.get("towns", []):
		if saved is Dictionary and saved.get("rect") is Array and saved["rect"].size() >= 4 and saved.get("center") is Array and saved["center"].size() >= 2:
			var rect: Array = saved["rect"]
			var entry: Dictionary = saved.duplicate()
			entry["rect"] = Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
			entry["center"] = Vector2i(int(saved["center"][0]), int(saved["center"][1]))
			entry["home"] = bool(saved.get("home", false))
			world.towns.append(entry)
	if world.towns.is_empty() and not world.lots.is_empty():  # a save from the days of a single town
		world._adopt_lots_as_one_town()
	for saved in data.get("floors", []):
		if saved is Array and saved.size() >= 3 and DataRegistry.has_def("floors", str(saved[2])):
			world.floors[Vector2i(int(saved[0]), int(saved[1]))] = str(saved[2])
	for saved in data.get("fires", []):
		if saved is Array and saved.size() >= 4:
			world.fires[Vector2i(int(saved[0]), int(saved[1]))] = { "since": int(saved[2]), "fuel": int(saved[3]) }
	var saved_lifespan := str(data.get("lifespan", "calendar"))
	world.lifespan = saved_lifespan if DataRegistry.has_def("lifespans", saved_lifespan) else "calendar"
	for saved in data.get("spirits", []):
		if saved is Dictionary and saved.get("grave") is Array and saved["grave"].size() >= 2:
			var look: Variant = saved.get("look", {})
			world.spirits.append({
				"name": str(saved.get("name", "")),
				"look": look.duplicate() if look is Dictionary else {},
				"grave": [int(saved["grave"][0]), int(saved["grave"][1])],
				"restless": bool(saved.get("restless", false)),
				"haunt_until": int(saved.get("haunt_until", -1)),
			})
	return world
