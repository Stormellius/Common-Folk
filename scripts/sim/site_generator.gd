class_name SiteGenerator
extends RefCounted
## Work sites at the edge of each settlement, where folk can gather resources (data/resources.json):
##   fields    outside the town, where grain ripens in summer and autumn (a farm: farmhands work them)
##   woodlot   a glade cut into the forest, with chopping blocks
##   quarry    a face of rock, cut back, with places to cut stone
##   herb garden  a small plot of beds
##   jetty     the end of the pier of a settlement on a lake, to fish from
## A site is a public lot of its own kind (so jobs at it are listed on the town's notice board),
## made of objects people use ("gathers" in data/objects.json), joined to the town by a path.
## Placed after the towns and their roads, in the same seeded order every time.

const SITES := [
	{ "kind": "farm",        "name": "Fields",      "size": Vector2i(14, 8), "needs": "open" },
	{ "kind": "woodlot",     "name": "Woodlot",     "size": Vector2i(11, 8), "needs": "forest" },
	{ "kind": "quarry",      "name": "Quarry",      "size": Vector2i(11, 8), "needs": "stone" },
	{ "kind": "herb_garden", "name": "Herb garden", "size": Vector2i(8, 6),  "needs": "open" },
]
const ANGLE_STEPS := 24
const GAP := 4  # tiles between a clearing's edge and a site


## Places every site round every settlement. Returns how many were made.
static func place_all(world: WorldState, rng: RandomNumberGenerator) -> int:
	var made := 0
	var taken: Array[Rect2i] = []
	for town in world.towns:
		var kinds_here: Array = SITES.duplicate()
		if str(town.get("kind", "")) == "hamlet":
			kinds_here = kinds_here.filter(func(site: Dictionary) -> bool: return site["kind"] != "herb_garden")
		for site in kinds_here:
			var entry := _place_site(world, rng, town, site, taken)
			if not entry.is_empty():
				made += 1
		if bool(DataRegistry.get_def("worldgen", str(town["profile"])).get("lake", false)) and not _place_jetty(world, town).is_empty():
			made += 1
	return made


## Takes down any site that nobody can walk to from its town's middle.
static func verify(world: WorldState, finder: PathFinder) -> int:
	var removed := 0
	for index in range(world.lots.size() - 1, -1, -1):
		var entry: Dictionary = world.lots[index]
		if str(entry["kind"]) not in ["farm", "woodlot", "quarry", "herb_garden", "jetty"]:
			continue
		var town := world.get_town(str(entry.get("town", "")))
		var rect: Rect2i = entry["rect"]
		var reachable := false
		for placed in world.objects:  # one route is enough: the first place to work
			if rect.has_point(placed.tile) and str(placed.def().get("category", "")) == "worksite":
				for step in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
					var spot: Vector2i = placed.tile + step
					if world.is_walkable(spot.x, spot.y):
						reachable = not finder.find_path(town["center"], spot).is_empty()
						break
				break
		if not reachable:
			for placed in world.objects.duplicate():
				if rect.has_point(placed.tile):
					world.remove_object(placed.id)
			world.lots.remove_at(index)
			removed += 1
	return removed


# --- placing one site -------------------------------------------------------------------------

static func _place_site(world: WorldState, rng: RandomNumberGenerator, town: Dictionary, site: Dictionary, taken: Array[Rect2i]) -> Dictionary:
	var size: Vector2i = site["size"]
	var profile := DataRegistry.get_def("worldgen", str(town["profile"]))
	var center: Vector2i = town["center"]
	var best := Rect2i()
	var best_score := -INF
	var start := rng.randi() % ANGLE_STEPS
	for gap in [GAP, GAP + 10, GAP + 22]:  # nearer first, then further out
		for step in ANGLE_STEPS:
			var angle := TAU * float((start + step) % ANGLE_STEPS) / ANGLE_STEPS
			var direction := Vector2(cos(angle), sin(angle))
			var reach: float = _boundary(profile, direction) + float(maxi(size.x, size.y)) * 0.5 + float(gap)
			var middle := Vector2(center) + direction * reach
			var rect := Rect2i(Vector2i(roundi(middle.x), roundi(middle.y)) - size / 2, size)
			if not _usable(world, rect, taken, town):
				continue
			var counts := _scan(world, rect, 5)
			var score := -INF
			match str(site["needs"]):
				"open":
					if counts["water"] == 0 and counts["stone"] <= 12:
						score = -float(counts["forest"]) - 3.0 * float(counts["stone"]) - float(counts["road"]) - 0.02 * reach
				"forest":
					if counts["water"] == 0 and counts["stone"] == 0 and counts["near_forest"] >= 24:
						score = float(counts["near_forest"]) - float(counts["road"]) - 0.1 * reach
				"stone":
					if counts["water"] == 0 and counts["near_stone"] >= 12:
						score = float(counts["near_stone"]) - 0.1 * reach
			if score > best_score and _path_is_clear(world, rect, center):
				best_score = score
				best = rect
		if best.size != Vector2i.ZERO:
			break
	if best.size == Vector2i.ZERO:
		return {}
	taken.append(best)
	_lay_out(world, rng, str(site["kind"]), best)
	_carve_path(world, best, center)
	var entry := {
		"id": "lot_%d" % (world.lots.size() + 1), "kind": str(site["kind"]), "name": str(site["name"]), "template": str(site["kind"]),
		"facing": "south", "rect": best, "public": true, "town": str(town["id"]),
	}
	world.lots.append(entry)
	return entry


## How far from the middle of a town its clearing reaches in `direction`.
static func _boundary(profile: Dictionary, direction: Vector2) -> float:
	var half_width := float(profile.get("half_width", 44))
	var half_height := float(profile.get("half_height_up", 26) if direction.y < 0.0 else profile.get("half_height_down", 28))
	return 1.0 / sqrt(pow(direction.x / half_width, 2.0) + pow(direction.y / half_height, 2.0))


## Whether a site may go here: on the map, clear of every lot, other site and clearing.
static func _usable(world: WorldState, rect: Rect2i, taken: Array[Rect2i], own_town: Dictionary) -> bool:
	if rect.position.x < 3 or rect.position.y < 3 or rect.end.x > world.width - 3 or rect.end.y > world.height - 3:
		return false
	for other in taken:
		if rect.grow(2).intersects(other):
			return false
	for entry in world.lots:
		if rect.grow(1).intersects(entry["rect"]):
			return false
	if world.lot.size != Vector2i.ZERO and rect.grow(1).intersects(world.lot):
		return false
	for town in world.towns:
		var profile := DataRegistry.get_def("worldgen", str(town["profile"]))
		for point in _outline(rect):
			if _inside(town, profile, point):
				return false
	return true


static func _inside(town: Dictionary, profile: Dictionary, tile: Vector2i) -> bool:
	var center: Vector2i = town["center"]
	var dx := float(tile.x - center.x) / float(profile.get("half_width", 44))
	var dy := float(tile.y - center.y) / float(profile.get("half_height_up", 26) if tile.y < center.y else profile.get("half_height_down", 28))
	return dx * dx + dy * dy <= 1.0


static func _outline(rect: Rect2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x, 2):
		points.append(Vector2i(x, rect.position.y))
		points.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.position.y, rect.end.y, 2):
		points.append(Vector2i(rect.position.x, y))
		points.append(Vector2i(rect.end.x - 1, y))
	return points


## What lies in a rectangle (and for forest and stone, a margin round it): { water, stone, forest,
## road, near_forest, near_stone }.
static func _scan(world: WorldState, rect: Rect2i, margin: int) -> Dictionary:
	var counts := { "water": 0, "stone": 0, "forest": 0, "road": 0, "near_forest": 0, "near_stone": 0 }
	var wide := rect.grow(margin)
	for y in range(wide.position.y, wide.end.y):
		for x in range(wide.position.x, wide.end.x):
			var id := world.get_tile_id(x, y)
			var inside := rect.has_point(Vector2i(x, y))
			if id == "forest":
				counts["near_forest"] += 1
			elif id == "stone":
				counts["near_stone"] += 1
			if not inside:
				continue
			match id:
				"water": counts["water"] += 1
				"stone": counts["stone"] += 1
				"forest": counts["forest"] += 1
				"dirt", "cobble", "bridge", "bridge_h": counts["road"] += 1
	return counts


## A straight line from the site to the town's middle crosses neither water nor rock.
static func _path_is_clear(world: WorldState, rect: Rect2i, center: Vector2i) -> bool:
	var from := Vector2(rect.get_center())
	var to := Vector2(center)
	var length := from.distance_to(to)
	for i in int(length):
		var tile := Vector2i((from + (to - from) * (float(i) / length)).round())
		var id := world.get_tile_id(tile.x, tile.y)
		if id == "water" or id == "stone":
			return false
	return true


## A bare track from the site toward the town, up to where the town's open ground begins.
static func _carve_path(world: WorldState, rect: Rect2i, center: Vector2i) -> void:
	var from := Vector2(rect.get_center())
	var to := Vector2(center)
	var length := from.distance_to(to)
	for i in int(length):
		var tile := Vector2i((from + (to - from) * (float(i) / length)).round())
		var inside_town := false
		for town in world.towns:
			if _inside(town, DataRegistry.get_def("worldgen", str(town["profile"])), tile):
				inside_town = true
		if inside_town:
			break
		if world.get_tile_id(tile.x, tile.y) in ["grass", "forest"] and world.object_at(tile) == null:
			world.set_tile(tile.x, tile.y, "dirt")


# --- what each kind of site holds --------------------------------------------------------------

static func _lay_out(world: WorldState, rng: RandomNumberGenerator, kind: String, rect: Rect2i) -> void:
	match kind:
		"farm":
			_flatten(world, rect, "grass")
			for row in 3:
				for column in 10:
					_put(world, "field_plot", Vector2i(rect.position.x + 2 + column, rect.position.y + 1 + row * 3))
			_put(world, "cart", Vector2i(rect.position.x + 1, rect.end.y - 2))
			_put(world, "haystack", Vector2i(rect.end.x - 2, rect.end.y - 2))
		"woodlot":
			_flatten(world, rect, "grass")
			for i in 3:
				_put(world, "chopping_block", Vector2i(rect.position.x + 3 + i * 3, rect.position.y + 3))
			_put(world, "woodpile", Vector2i(rect.position.x + 1, rect.position.y + 1))
			_put(world, "woodpile", Vector2i(rect.end.x - 2, rect.position.y + 1))
			_put(world, "cart", Vector2i(rect.position.x + 5, rect.end.y - 2))
		"quarry":
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					if world.get_tile_id(x, y) != "stone":
						world.set_tile(x, y, "dirt")
			var faces := 0
			var tiles: Array[Vector2i] = []
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					tiles.append(Vector2i(x, y))
			for tile in tiles:
				if faces >= 3:
					break
				if world.get_tile_id(tile.x, tile.y) == "dirt" and world.object_at(tile) == null and _next_to_stone(world, tile) and _clear_of_faces(world, tile):
					if world.add_object("quarry_face", tile) != null:
						faces += 1
			_put(world, "cart", Vector2i(rect.end.x - 2, rect.end.y - 2))
		"herb_garden":
			_flatten(world, rect, "grass")
			for row in 2:
				for column in 3:
					_put(world, "herb_bed", Vector2i(rect.position.x + 1 + column * 2, rect.position.y + 1 + row * 2))
			_put(world, "bush", Vector2i(rect.end.x - 2, rect.end.y - 2))
			_put(world, "bush", Vector2i(rect.position.x + 1, rect.end.y - 2))


## Clears a site to open grass, leaving any road that crosses it.
static func _flatten(world: WorldState, rect: Rect2i, tile_id: String) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if world.get_tile_id(x, y) in ["forest", "grass", "stone"]:
				world.set_tile(x, y, tile_id)


## Puts something down only on open grass (not on a road that crosses the site).
static func _put(world: WorldState, def_id: String, tile: Vector2i) -> void:
	if world.get_tile_id(tile.x, tile.y) == "grass":
		world.add_object(def_id, tile)


static func _next_to_stone(world: WorldState, tile: Vector2i) -> bool:
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if world.get_tile_id(tile.x + step.x, tile.y + step.y) == "stone":
			return true
	return false


## Quarry faces keep a couple of tiles apart.
static func _clear_of_faces(world: WorldState, tile: Vector2i) -> bool:
	for placed in world.objects:
		if placed.def_id == "quarry_face" and absi(placed.tile.x - tile.x) + absi(placed.tile.y - tile.y) < 3:
			return false
	return true


## The jetty: the far end of the pier of a settlement on a lake.
static func _place_jetty(world: WorldState, town: Dictionary) -> Dictionary:
	var pier: Variant = town.get("pier")
	if not (pier is Array and pier.size() >= 2):
		return {}
	var end := Vector2i(int(pier[0]), int(pier[1]))
	if world.add_object("fishing_spot", end) == null:
		return {}
	var entry := {
		"id": "lot_%d" % (world.lots.size() + 1), "kind": "jetty", "name": "Jetty", "template": "jetty",
		"facing": "south", "rect": Rect2i(end - Vector2i(4, 4), Vector2i(9, 9)), "public": true, "town": str(town["id"]),
	}
	world.lots.append(entry)
	return entry
