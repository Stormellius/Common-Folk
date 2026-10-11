class_name TownGenerator
extends RefCounted
## Turns the bare terrain into a town. The same seed always gives the same town.
##
## 1. A rounded clearing around the middle of the map is flattened to grass.
## 2. Two roads, each two tiles wide, cross at the center: one east-west, one north-south.
## 3. The player's lot is set aside first (south-west of the crossing).
## 4. Every building in data/worldgen.json is placed from a template in data/buildings.json on
##    a lot beside a road, nearest the crossing first (tavern, shop, clinic, green, then houses,
##    then empty lots). Each template is mirrored at random and turned so its door faces the road.
## 5. A building whose door cannot be reached from the crossing is taken down again.
##
## Template grids use one character per tile: '#' timber wall, 'S' stone wall, '+' door,
## '.' floor, ' ' nothing, and a letter for an object (see LEGEND).

const LEGEND := {
	"b": "bed", "p": "cooking_pot", "h": "hearth", "w": "wash_basin", "c": "chamber_pot",
	"l": "lute", "t": "table", "k": "counter", "s": "shelf", "r": "barrel", "n": "bench", "W": "well",
	"m": "meal_table", "a": "ale_barrel", "f": "food_shelf", "B": "notice_board",
	"A": "altar", "P": "pew", "H": "sickbed",
}
const PRIORITY := ["tavern", "shop", "clinic", "chapel", "park", "house", "vacant"]
const YARD := 1       # tiles of open ground around a building, inside its lot
const JITTER := 6.0   # how much chance shuffles the order of lots along the roads
const DOOR_FACING := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]  # per rotation
const FACING_NAMES := ["south", "west", "north", "east"]


## Builds the town on `world`. Sets world.lot (the player's) and world.lots. Returns a report:
## { "placed": { kind: count }, "removed": number taken down again }.
static func generate(world: WorldState) -> Dictionary:
	var report := { "placed": {}, "removed": 0 }
	var config := DataRegistry.get_def("worldgen", "town")
	if config.is_empty():
		return report
	var center := Vector2i(world.width / 2, world.height / 2)
	var half_width := int(config.get("half_width", 44))
	var half_up := int(config.get("half_height_up", 26))
	var half_down := int(config.get("half_height_down", 28))
	_flatten(world, center, half_width, half_up, half_down)
	var road_ew := Rect2i(center.x - half_width, center.y, half_width * 2 + 1, 2)
	var road_ns := Rect2i(center.x, center.y - half_up, 2, half_up + half_down + 1)
	for road in [road_ew, road_ns]:
		for y in range(road.position.y, road.end.y):
			for x in range(road.position.x, road.end.x):
				world.set_tile(x, y, "dirt")

	var home_size: Array = config.get("home_lot_size", [16, 13])
	world.lot = Rect2i(center.x - int(home_size[0]), center.y + 2, int(home_size[0]), int(home_size[1]))
	world.lots.clear()
	var reserved: Array[Rect2i] = [road_ew, road_ns, world.lot]

	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 104729 + 31
	var counts: Dictionary = config.get("buildings", {})
	var order: Array[String] = []
	for kind in PRIORITY:
		if counts.has(kind):
			order.append(kind)
	for kind in counts:
		if str(kind) not in order:
			order.append(str(kind))
	var doors := {}  # lot id -> the tile just inside the building's outside door
	for kind in order:
		for i in int(counts[kind]):
			var entry := _place_one(world, rng, kind, config, center, half_width, half_up, half_down, reserved, doors)
			if not entry.is_empty():
				report["placed"][kind] = int(report["placed"].get(kind, 0)) + 1

	# Anything people cannot walk to from the crossroads comes down again.
	var finder := PathFinder.new(world)
	for entry in world.lots.duplicate():
		if not doors.has(entry["id"]):
			continue
		var door: Vector2i = doors[entry["id"]]
		if finder.find_path(center, door).is_empty():
			_clear_lot(world, entry)
			world.lots.erase(entry)
			report["removed"] += 1
	return report


static func _flatten(world: WorldState, center: Vector2i, half_width: int, half_up: int, half_down: int) -> void:
	for y in range(center.y - half_up, center.y + half_down + 1):
		for x in range(center.x - half_width, center.x + half_width + 1):
			if _inside_clearing(Vector2i(x, y), center, half_width, half_up, half_down):
				world.set_tile(x, y, "grass")


static func _inside_clearing(cell: Vector2i, center: Vector2i, half_width: int, half_up: int, half_down: int) -> bool:
	var dx := float(cell.x - center.x) / float(half_width)
	var dy := float(cell.y - center.y) / float(half_up if cell.y < center.y else half_down)
	return dx * dx + dy * dy <= 1.0


## Finds the best free spot for one building of `kind` and builds it. Returns its lot entry, or {}.
static func _place_one(world: WorldState, rng: RandomNumberGenerator, kind: String, config: Dictionary, center: Vector2i,
		half_width: int, half_up: int, half_down: int, reserved: Array[Rect2i], doors: Dictionary) -> Dictionary:
	var template := {}
	var candidates_for_kind: Array[Dictionary] = []
	for def in DataRegistry.get_list("buildings"):
		if str(def.get("kind", "")) == kind:
			candidates_for_kind.append(def)
	if kind == "vacant":
		var size: Array = config.get("vacant_lot_size", [12, 10])
		template = { "id": "vacant", "name": "Empty lot", "kind": "vacant", "grid": [] , "size": size }
	elif candidates_for_kind.is_empty():
		return {}
	else:
		template = candidates_for_kind[rng.randi() % candidates_for_kind.size()]
	var mirror := rng.randf() < 0.5
	var best_rect := Rect2i()
	var best_rot := 0
	var best_score := INF
	for rot in 4:  # rot is also the side of the road: 0 north of it, 1 east, 2 south, 3 west
		var grid := _oriented(template, mirror, rot)
		var foot := _footprint(template, grid)
		var yard := 0 if kind == "vacant" else YARD
		var lot_size := foot + Vector2i(yard * 2, yard * 2)
		for rect in _slots(rot, lot_size, center, half_width, half_up, half_down):
			if not _fits(rect, reserved, center, half_width, half_up, half_down, world):
				continue
			var score := Vector2(rect.get_center() - center).length() + rng.randf() * JITTER
			if score < best_score:
				best_score = score
				best_rect = rect
				best_rot = rot
	if best_rect.size == Vector2i.ZERO:
		return {}
	reserved.append(best_rect)
	var entry := {
		"id": "lot_%d" % (world.lots.size() + 1), "kind": kind, "name": str(template.get("name", kind)),
		"template": str(template["id"]), "facing": FACING_NAMES[best_rot], "rect": best_rect,
		"public": bool(template.get("public", false)),
	}
	world.lots.append(entry)
	if kind != "vacant":
		var grid := _oriented(template, mirror, best_rot)
		var door := _build(world, template, grid, best_rect.position + Vector2i(YARD, YARD), best_rect, best_rot)
		if door != Vector2i(-1, -1):
			doors[entry["id"]] = door
	return entry


## Every lot position on one side of the crossroads for a lot of this size, hugging the road.
## rot 0 is the strip north of the east-west road (door faces south), 1 east of the north-south
## road (door faces west), 2 south of the east-west road, 3 west of the north-south road.
static func _slots(rot: int, size: Vector2i, center: Vector2i, half_width: int, half_up: int, half_down: int) -> Array[Rect2i]:
	var slots: Array[Rect2i] = []
	match rot:
		0, 2:
			var y := center.y - size.y if rot == 0 else center.y + 2
			for x in range(center.x - half_width, center.x + half_width - size.x + 2):
				slots.append(Rect2i(Vector2i(x, y), size))
		_:
			var x := center.x + 2 if rot == 1 else center.x - size.x
			for y in range(center.y - half_up, center.y + half_down - size.y + 2):
				slots.append(Rect2i(Vector2i(x, y), size))
	return slots


static func _fits(rect: Rect2i, reserved: Array[Rect2i], center: Vector2i, half_width: int, half_up: int, half_down: int, world: WorldState) -> bool:
	for other in reserved:
		if rect.intersects(other):
			return false
	for corner in [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		if not _inside_clearing(corner, center, half_width, half_up, half_down) or not world.in_bounds(corner.x, corner.y):
			return false
	return true


## The template's grid, mirrored left to right if asked and then turned clockwise `rot` quarter turns
## (a canonical template has its door in the bottom wall; one turn puts the door on the west side).
static func _oriented(template: Dictionary, mirror: bool, rot: int) -> Array[String]:
	var rows: Array[String] = []
	var width := 0
	for row in template.get("grid", []):
		width = maxi(width, str(row).length())
	for row in template.get("grid", []):
		var text := str(row).rpad(width, " ")
		if mirror:
			var flipped := ""
			for i in range(text.length() - 1, -1, -1):
				flipped += text[i]
			text = flipped
		rows.append(text)
	for turn in rot:
		var turned: Array[String] = []
		var old_height := rows.size()
		for i in width:
			var line := ""
			for j in old_height:
				line += rows[old_height - 1 - j][i]
			turned.append(line)
		rows = turned
		width = old_height
	return rows


## For code outside the generator (a start that comes with a house): the template turned `rot` quarter turns.
static func oriented(template: Dictionary, mirror: bool, rot: int) -> Array[String]:
	return _oriented(template, mirror, rot)


## Puts a template's walls, floor and objects down with its top-left corner at `origin`.
static func stamp(world: WorldState, template: Dictionary, grid: Array[String], origin: Vector2i, lot: Rect2i, rot: int) -> void:
	_build(world, template, grid, origin, lot, rot)


static func _footprint(template: Dictionary, grid: Array[String]) -> Vector2i:
	if template.has("size"):
		return Vector2i(int(template["size"][0]), int(template["size"][1]))
	return Vector2i(grid[0].length() if not grid.is_empty() else 0, grid.size())


## Puts the building's walls, floor and objects down. Returns the tile just inside its outside
## door (where the way in starts), or (-1, -1) if it has none.
static func _build(world: WorldState, template: Dictionary, grid: Array[String], origin: Vector2i, lot: Rect2i, rot: int) -> Vector2i:
	var floor_id := str(template.get("floor", ""))
	var foot := Rect2i(origin, Vector2i(grid[0].length() if not grid.is_empty() else 0, grid.size()))
	var way_in := Vector2i(-1, -1)
	for gy in grid.size():
		for gx in grid[gy].length():
			var ch := grid[gy][gx]
			if ch == " ":
				continue
			var tile := origin + Vector2i(gx, gy)
			var def_id := ""
			var wants_floor := floor_id != ""
			match ch:
				"#":
					def_id = "wall"
					wants_floor = false
				"S":
					def_id = "stone_wall"
					wants_floor = false
				"+":
					def_id = "door"
				".":
					pass
				_:
					def_id = str(LEGEND.get(ch, ""))
			if wants_floor:
				world.set_floor(tile, floor_id)
			if def_id != "":
				world.add_object(def_id, tile)
			if ch == "+" and not foot.has_point(tile + DOOR_FACING[rot]):
				way_in = tile  # on the outside wall, facing the road
				var outside: Vector2i = tile + DOOR_FACING[rot]
				while lot.has_point(outside):
					world.set_tile(outside.x, outside.y, "dirt")  # a bare path across the yard
					outside += DOOR_FACING[rot]
	return way_in


static func _clear_lot(world: WorldState, entry: Dictionary) -> void:
	var rect: Rect2i = entry["rect"]
	for placed in world.objects.duplicate():
		if rect.has_point(placed.tile):
			world.remove_object(placed.id)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			world.set_floor(Vector2i(x, y), "")
