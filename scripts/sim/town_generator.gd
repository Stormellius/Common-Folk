class_name TownGenerator
extends RefCounted
## Turns bare terrain into a town. The same seed always gives the same town.
##
## 1. A rounded clearing is flattened to grass.
## 2. A cobbled main street runs east to west and an avenue north to south, crossing in the middle;
##    bigger towns get dirt side streets as well (data/worldgen.json, "streets").
## 3. At the crossing a market square is paved, with a well, stalls and lanterns.
## 4. The player's lot, in their own town, is set aside beside the square.
## 5. Every building in the profile is placed from a template in data/buildings.json on a lot beside
##    a street, nearest the crossing first (tavern, shop, clinic, chapel, green, then houses, then
##    empty lots). Each template is mirrored at random and turned so its door faces the street.
## 6. A building whose door cannot be reached from the crossing is taken down again.
## 7. Lanterns, flower beds, bushes, woodpiles and carts finish it, so it reads as a town.
##
## Template grids use one character per tile: '#' timber wall, 'S' stone wall, '+' door,
## '.' floor, ' ' nothing, and a letter for an object (see LEGEND).

const LEGEND := {
	"b": "bed", "p": "cooking_pot", "h": "hearth", "w": "wash_basin", "c": "chamber_pot",
	"l": "lute", "j": "harp", "d": "drum", "t": "table", "k": "counter", "s": "shelf", "r": "barrel", "n": "bench", "W": "well",
	"m": "meal_table", "a": "ale_barrel", "f": "food_shelf", "B": "notice_board",
	"A": "altar", "P": "pew", "H": "sickbed", "F": "forge", "K": "workbench", "T": "tool_rack", "Z": "haystack", "Y": "hitching_post", "Q": "quern", "O": "oven", "V": "brew_vat", "U": "tanning_rack",
}
const PRIORITY := ["tavern", "shop", "clinic", "chapel", "smithy", "workshop", "stable", "bakery", "park", "house", "vacant"]
const YARD := 1       # tiles of open ground around a building, inside its lot
const JITTER := 6.0   # how much chance shuffles the order of lots along the streets
const MAIN_WIDTH := 3
const STREET_WIDTH := 2
const STREET_TILE := "cobble"
const SIDE_STREET_TILE := "dirt"
const SLOT_STEP := 2  # lots are tried every this many tiles along a street
const LANTERN_SPACING := 10
const DOOR_FACING := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]  # per rotation
const FACING_NAMES := ["south", "west", "north", "east"]


## Builds the player's town in the middle of `world`. Sets world.lot (the player's) and world.lots.
## Returns a report: { "placed": { kind: count }, "removed": number taken down again, "town": entry }.
static func generate(world: WorldState) -> Dictionary:
	return generate_town(world, "town", Vector2i(world.width / 2, world.height / 2), true, "")


## Builds one settlement from the profile `profile_id` (an entry of data/worldgen.json) around
## `center`. The home town also gets the player's lot. Adds the town to world.towns.
static func generate_town(world: WorldState, profile_id: String, center: Vector2i, is_home: bool, town_name: String) -> Dictionary:
	var report := { "placed": {}, "removed": 0, "town": {} }
	var config := DataRegistry.get_def("worldgen", profile_id)
	if config.is_empty() or not config.has("buildings"):
		return report
	var half_width := int(config.get("half_width", 44))
	var half_up := int(config.get("half_height_up", 26))
	var half_down := int(config.get("half_height_down", 28))
	var town_id := "town_%d" % (world.towns.size() + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 104729 + 31 + world.towns.size() * 7919
	if town_name == "":
		town_name = _pick_name(world, rng)
	_flatten(world, center, half_width, half_up, half_down)
	var roads := _lay_roads(world, config, center, half_width, half_up, half_down)
	var reserved: Array[Rect2i] = []
	for road in roads:
		reserved.append(road["rect"])
	var plaza := Rect2i()
	if bool(config.get("plaza", false)):
		plaza = Rect2i(center.x - 4, center.y - 3, 11, MAIN_WIDTH + 6)
		_pave(world, plaza, center, half_width, half_up, half_down)
		reserved.append(plaza)

	if is_home and config.has("home_lot_size"):
		var home_size: Array = config["home_lot_size"]
		var lot_x := center.x - (4 if plaza.size != Vector2i.ZERO else 0) - int(home_size[0])
		world.lot = Rect2i(lot_x, center.y + MAIN_WIDTH, int(home_size[0]), int(home_size[1]))
		reserved.append(world.lot)
	var first_lot := world.lots.size()

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
			var entry := _place_one(world, rng, kind, config, center, roads, half_width, half_up, half_down, reserved, doors)
			if not entry.is_empty():
				entry["town"] = town_id
				report["placed"][kind] = int(report["placed"].get(kind, 0)) + 1

	# Anything people cannot walk to from the crossing comes down again.
	var finder := PathFinder.new(world)
	for index in range(world.lots.size() - 1, first_lot - 1, -1):
		var entry: Dictionary = world.lots[index]
		if not doors.has(entry["id"]):
			continue
		if finder.find_path(center, doors[entry["id"]]).is_empty():
			_clear_lot(world, entry)
			world.lots.remove_at(index)
			report["removed"] += 1

	var bounds := Rect2i(center.x - half_width, center.y - half_up, half_width * 2 + 1, half_up + half_down + 1).intersection(Rect2i(0, 0, world.width, world.height))
	var town := { "id": town_id, "name": town_name, "kind": str(config.get("kind", "town")), "profile": profile_id, "center": center, "rect": bounds, "home": is_home }
	world.towns.append(town)
	report["town"] = town
	_decorate(world, rng, town_id, roads, plaza, center)
	if bool(config.get("lake", false)):
		var pier := _dig_lake(world, rng, center, half_width, half_up, half_down)
		if pier != Vector2i(-1, -1):
			town["pier"] = [pier.x, pier.y]  # the far end of the pier, for the jetty (see SiteGenerator)
	return report


static func _pick_name(world: WorldState, rng: RandomNumberGenerator) -> String:
	var names: Array = DataRegistry.get_def("names", "town").get("list", ["Ashford"]).duplicate()
	for existing in world.towns:
		names.erase(existing["name"])
	if names.is_empty():
		return "Town %d" % (world.towns.size() + 1)
	return str(names[rng.randi() % names.size()])


static func _flatten(world: WorldState, center: Vector2i, half_width: int, half_up: int, half_down: int) -> void:
	for y in range(center.y - half_up, center.y + half_down + 1):
		for x in range(center.x - half_width, center.x + half_width + 1):
			if _inside_clearing(Vector2i(x, y), center, half_width, half_up, half_down):
				world.set_tile(x, y, "grass")


static func _inside_clearing(cell: Vector2i, center: Vector2i, half_width: int, half_up: int, half_down: int) -> bool:
	var dx := float(cell.x - center.x) / float(half_width)
	var dy := float(cell.y - center.y) / float(half_up if cell.y < center.y else half_down)
	return dx * dx + dy * dy <= 1.0


## Lays the streets and returns them: [{ "rect": Rect2i, "horizontal": bool }]. The main street and
## the avenue are cobbled; side streets (profile "streets": "ns" and "ew" offsets from the centre)
## are packed earth, and stop where the clearing does.
static func _lay_roads(world: WorldState, config: Dictionary, center: Vector2i, half_width: int, half_up: int, half_down: int) -> Array[Dictionary]:
	var roads: Array[Dictionary] = []
	roads.append({ "rect": Rect2i(center.x - half_width, center.y, half_width * 2 + 1, MAIN_WIDTH), "horizontal": true, "tile": STREET_TILE })
	roads.append({ "rect": Rect2i(center.x, center.y - half_up, MAIN_WIDTH, half_up + half_down + 1), "horizontal": false, "tile": STREET_TILE })
	var streets: Dictionary = config.get("streets", {})
	for offset in streets.get("ns", []):
		var x := center.x + int(offset)
		var reach_up := int(half_up * sqrt(maxf(0.0, 1.0 - pow(float(offset) / half_width, 2.0)))) - 2
		var reach_down := int(half_down * sqrt(maxf(0.0, 1.0 - pow(float(offset) / half_width, 2.0)))) - 2
		if reach_up > 4 and reach_down > 4:
			roads.append({ "rect": Rect2i(x, center.y - reach_up, STREET_WIDTH, reach_up + reach_down + 1), "horizontal": false, "tile": SIDE_STREET_TILE })
	for offset in streets.get("ew", []):
		var y := center.y + int(offset)
		var reach_left := int(half_width * sqrt(maxf(0.0, 1.0 - pow(float(offset) / (half_up if offset < 0 else half_down), 2.0)))) - 2
		if reach_left > 6:
			roads.append({ "rect": Rect2i(center.x - reach_left, y, reach_left * 2 + 1, STREET_WIDTH), "horizontal": true, "tile": SIDE_STREET_TILE })
	for road in roads:
		_pave(world, road["rect"], center, half_width, half_up, half_down, str(road["tile"]))
	return roads


static func _pave(world: WorldState, rect: Rect2i, center: Vector2i, half_width: int, half_up: int, half_down: int, tile_id: String = STREET_TILE) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _inside_clearing(Vector2i(x, y), center, half_width, half_up, half_down) and world.in_bounds(x, y):
				world.set_tile(x, y, tile_id)


## Finds the best free spot for one building of `kind` and builds it. Returns its lot entry, or {}.
static func _place_one(world: WorldState, rng: RandomNumberGenerator, kind: String, config: Dictionary, center: Vector2i, roads: Array[Dictionary],
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
	var yard := 0 if kind == "vacant" else YARD
	for rot in 4:  # rot is the side of the street: 0 north of it, 1 east, 2 south, 3 west
		var grid := _oriented(template, mirror, rot)
		var lot_size := _footprint(template, grid) + Vector2i(yard * 2, yard * 2)
		for road in roads:
			if (rot == 0 or rot == 2) != bool(road["horizontal"]):
				continue
			for rect in _slots(road["rect"], rot, lot_size):
				var score := Vector2(rect.get_center() - center).length() + rng.randf() * JITTER
				if score < best_score and _fits(rect, reserved, center, half_width, half_up, half_down, world):
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


## Every lot position on one side of a street for a lot of this size, hugging the street.
## rot 0 is the strip north of a horizontal street (door faces south), 1 east of a vertical street
## (door faces west), 2 south of a horizontal one, 3 west of a vertical one.
static func _slots(road: Rect2i, rot: int, size: Vector2i) -> Array[Rect2i]:
	var slots: Array[Rect2i] = []
	match rot:
		0, 2:
			var y := road.position.y - size.y if rot == 0 else road.end.y
			for x in range(road.position.x - size.x + 1, road.end.x, SLOT_STEP):
				slots.append(Rect2i(Vector2i(x, y), size))
		_:
			var x := road.end.x if rot == 1 else road.position.x - size.x
			for y in range(road.position.y - size.y + 1, road.end.y, SLOT_STEP):
				slots.append(Rect2i(Vector2i(x, y), size))
	return slots


static func _fits(rect: Rect2i, reserved: Array[Rect2i], center: Vector2i, half_width: int, half_up: int, half_down: int, world: WorldState) -> bool:
	for corner in [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		if not _inside_clearing(corner, center, half_width, half_up, half_down) or not world.in_bounds(corner.x, corner.y):
			return false
	for other in reserved:
		if rect.intersects(other):
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


## Puts the building's walls, floor and objects down. Returns the tile just inside the outside
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
				way_in = tile  # on the outside wall, facing the street
				var outside: Vector2i = tile + DOOR_FACING[rot]
				while lot.has_point(outside):
					world.set_tile(outside.x, outside.y, "dirt")  # a bare path across the yard
					outside += DOOR_FACING[rot]
	if floor_id != "":
		Rooms.auto_roof(world, foot)  # the building's closed rooms are roofed
	return way_in


static func _clear_lot(world: WorldState, entry: Dictionary) -> void:
	var rect: Rect2i = entry["rect"]
	for placed in world.objects.duplicate():
		if rect.has_point(placed.tile):
			world.remove_object(placed.id)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			world.set_floor(Vector2i(x, y), "")
			world.set_roof(Vector2i(x, y), "")


# --- the finishing touches -----------------------------------------------------------

## Lanterns, flower beds and the rest, placed where they block nobody.
static func _decorate(world: WorldState, rng: RandomNumberGenerator, town_id: String, roads: Array[Dictionary], plaza: Rect2i, center: Vector2i) -> void:
	if plaza.size != Vector2i.ZERO:
		_put(world, "well", Vector2i(center.x + 1, center.y + 1))
		for stall in [Vector2i(-3, -2), Vector2i(5, -2), Vector2i(-3, 4), Vector2i(5, 4)]:
			_put(world, "market_stall", center + stall)
		for corner in [Vector2i(-4, -3), Vector2i(6, -3), Vector2i(-4, 5), Vector2i(6, 5)]:
			_put(world, "lantern_post", center + corner)
		for bench in [Vector2i(-1, -2), Vector2i(3, -2), Vector2i(-1, 4), Vector2i(3, 4)]:
			_put(world, "bench", center + bench)
	for road in roads:  # lanterns along the cobbled streets, on the edge tiles
		if str(road["tile"]) != STREET_TILE:
			continue
		var rect: Rect2i = road["rect"]
		var horizontal: bool = road["horizontal"]
		var length := rect.size.x if horizontal else rect.size.y
		for along in range(LANTERN_SPACING / 2, length, LANTERN_SPACING):
			for edge in 2:
				var tile := rect.position + (Vector2i(along, 0 if edge == 0 else rect.size.y - 1) if horizontal else Vector2i(0 if edge == 0 else rect.size.x - 1, along))
				if (along / LANTERN_SPACING + edge) % 2 == 0 and not plaza.has_point(tile) and not _door_path_beside(world, tile, horizontal, edge):
					_put(world, "lantern_post", tile)
	for entry in world.lots:
		if str(entry.get("town", "")) == town_id:
			_decorate_lot(world, rng, entry)


## Whether a lot's bare path to its door meets the street at `tile`.
static func _door_path_beside(world: WorldState, tile: Vector2i, horizontal: bool, edge: int) -> bool:
	var outward := (Vector2i(0, -1) if edge == 0 else Vector2i(0, 1)) if horizontal else (Vector2i(-1, 0) if edge == 0 else Vector2i(1, 0))
	return world.get_tile_id(tile.x + outward.x, tile.y + outward.y) == "dirt" or world.get_tile_id(tile.x + outward.x * 2, tile.y + outward.y * 2) == "dirt"


## What a lot gets in its yard, by what stands on it.
static func _decorate_lot(world: WorldState, rng: RandomNumberGenerator, entry: Dictionary) -> void:
	var kind := str(entry["kind"])
	if kind == "vacant" or kind == "park":
		return
	var rect: Rect2i = entry["rect"]
	var ring: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1:
				ring.append(Vector2i(x, y))
	var front_corners: Array[Vector2i] = []
	var back_corners: Array[Vector2i] = []
	var corners: Array[Vector2i] = [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]
	for corner in corners:
		var on_front := false
		match str(entry["facing"]):
			"south": on_front = corner.y == rect.end.y - 1
			"north": on_front = corner.y == rect.position.y
			"east": on_front = corner.x == rect.end.x - 1
			"west": on_front = corner.x == rect.position.x
		(front_corners if on_front else back_corners).append(corner)
	var lanterns := 2 if kind in ["tavern", "chapel"] else (1 if rng.randf() < 0.45 else 0)
	for i in lanterns:
		_put(world, "lantern_post", front_corners[i % front_corners.size()])
	match kind:
		"chapel":
			for corner in back_corners:
				_put(world, "bush", corner)
			for i in 4:
				_put(world, "flower_bed", ring[rng.randi() % ring.size()])
		"tavern", "shop":
			for i in 2:
				_put(world, "barrel", ring[rng.randi() % ring.size()])
			if rng.randf() < 0.4:
				_put(world, "cart", ring[rng.randi() % ring.size()])
			if kind == "shop" and rng.randf() < 0.6:
				_put(world, "market_stall", ring[rng.randi() % ring.size()])
		"clinic":
			for i in 3:
				_put(world, "flower_bed", ring[rng.randi() % ring.size()])
		"smithy", "workshop", "stable", "bakery":
			for i in 3:
				_put(world, "woodpile", ring[rng.randi() % ring.size()])
			_put(world, "cart", ring[rng.randi() % ring.size()])
			if kind == "smithy":
				_put(world, "barrel", ring[rng.randi() % ring.size()])
		_:
			var extras := ["flower_bed", "flower_bed", "bush", "woodpile"]
			if str(entry["template"]) in ["farmhouse", "longhouse"]:
				extras.append_array(["haystack", "cart"])
			for i in rng.randi_range(1, 3):
				_put(world, extras[rng.randi() % extras.size()], ring[rng.randi() % ring.size()])
			if rng.randf() < 0.6:
				_put(world, "bush", back_corners[rng.randi() % back_corners.size()])


## Sets an object down if the tile is free, open grass or street, and not a bare path to a door.
static func _put(world: WorldState, def_id: String, tile: Vector2i) -> void:
	if not DataRegistry.has_def("objects", def_id):
		return
	var ground := world.get_tile_id(tile.x, tile.y)
	if world.floor_at(tile) != "" or ground == "dirt" and def_id != "lantern_post" and def_id != "bench":
		return
	if ground != "grass" and ground != "cobble" and ground != "dirt":
		return
	world.add_object(def_id, tile)


# --- a lake for a fishing village -----------------------------------------------------

## Digs a pond beside the clearing, on the side with the most room, and runs a pier out into it.
## Returns the far end of the pier.
static func _dig_lake(world: WorldState, rng: RandomNumberGenerator, center: Vector2i, half_width: int, half_up: int, half_down: int) -> Vector2i:
	var radius := Vector2i(rng.randi_range(15, 19), rng.randi_range(9, 12))
	var best := Vector2i(1, 0)
	var best_room := -1
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var distance := (half_width if direction.x != 0 else (half_down if direction.y > 0 else half_up)) + (radius.x if direction.x != 0 else radius.y) + 3
		var middle: Vector2i = center + direction * distance
		var room := mini(middle.x - radius.x, world.width - 1 - middle.x - radius.x)
		room = mini(room, mini(middle.y - radius.y, world.height - 1 - middle.y - radius.y))
		if room > best_room:
			best_room = room
			best = direction
	var distance := (half_width if best.x != 0 else (half_down if best.y > 0 else half_up)) + (radius.x if best.x != 0 else radius.y) + 3
	var middle := center + best * distance
	for y in range(middle.y - radius.y - 1, middle.y + radius.y + 2):
		for x in range(middle.x - radius.x - 1, middle.x + radius.x + 2):
			var dx := float(x - middle.x) / float(radius.x)
			var dy := float(y - middle.y) / float(radius.y)
			var wobble := 1.0 + 0.12 * sin(float(x) * 0.7 + float(y) * 0.5)
			var d := (dx * dx + dy * dy) * wobble
			if not world.in_bounds(x, y) or world.get_tile_id(x, y) == "grass" and _near_lot(world, Vector2i(x, y)):
				continue
			if d <= 1.0:
				world.set_tile(x, y, "water")
			elif d <= 1.35 and world.get_tile_id(x, y) != "water":
				world.set_tile(x, y, "dirt")  # a muddy shore
	# A pier from the shore toward the middle of the water.
	var span := radius.x if best.x != 0 else radius.y
	var tile := middle - best * (span + 3)
	var steps := 0
	while steps < span + 8 and world.in_bounds(tile.x, tile.y) and world.get_tile_id(tile.x, tile.y) != "water":
		tile += best
		steps += 1
	var pier_id := "bridge_h" if best.x != 0 else "bridge"
	var far_end := Vector2i(-1, -1)
	for i in 9:
		if world.in_bounds(tile.x, tile.y) and world.get_tile_id(tile.x, tile.y) == "water":
			world.set_tile(tile.x, tile.y, pier_id)
			far_end = tile
		tile += best
	return far_end


static func _near_lot(world: WorldState, tile: Vector2i) -> bool:
	for entry in world.lots:
		if (entry["rect"] as Rect2i).grow(2).has_point(tile):
			return true
	return false
