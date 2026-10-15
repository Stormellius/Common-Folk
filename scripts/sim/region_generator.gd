class_name RegionGenerator
extends RefCounted
## Builds the whole map: terrain from a seed, the player's town in the middle and the other
## settlements round about (data/worldgen.json, "region"), joined by roads that go round the
## forest and lakes and cross water on plank bridges. The same seed always gives the same map.

const ROAD_WIDTH := 2
const ROAD_TILE := "dirt"


## The map size the region asks for.
static func size() -> Vector2i:
	var config := DataRegistry.get_def("worldgen", "region")
	return Vector2i(int(config.get("width", 352)), int(config.get("height", 240)))


## A whole new map. `width` and `height` default to the region's own.
static func generate(world_seed: int, width: int = 0, height: int = 0) -> WorldState:
	var config := DataRegistry.get_def("worldgen", "region")
	if width <= 0 or height <= 0:
		width = size().x
		height = size().y
	var world := MapGenerator.generate(world_seed, width, height)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 7919 + 13
	var jitter := float(config.get("jitter", 0.04))
	var home_done := false
	for entry in config.get("settlements", []):
		var profile := DataRegistry.get_def("worldgen", str(entry.get("profile", "")))
		if profile.is_empty():
			continue
		var at: Array = entry.get("at", [0.5, 0.5])
		var margin := Vector2i(int(profile.get("half_width", 30)) + 8, maxi(int(profile.get("half_height_up", 20)), int(profile.get("half_height_down", 20))) + 8)
		var center := Vector2i(
			clampi(roundi((float(at[0]) + rng.randf_range(-jitter, jitter)) * width), margin.x, width - margin.x),
			clampi(roundi((float(at[1]) + rng.randf_range(-jitter, jitter)) * height), margin.y, height - margin.y))
		var is_home: bool = bool(entry.get("home", false)) and not home_done
		if is_home:
			center = Vector2i(width / 2, height / 2)  # the player's town is always in the middle
			home_done = true
		TownGenerator.generate_town(world, str(entry["profile"]), center, is_home, "")
	_join_towns(world, rng)
	SiteGenerator.place_all(world, rng)
	SiteGenerator.verify(world, PathFinder.new(world))
	var fauna_rng := RandomNumberGenerator.new()
	fauna_rng.seed = world_seed * 6151 + 29
	Fauna.populate(world, fauna_rng)
	Fauna.give_pets(world, fauna_rng)
	return world


# --- roads ---------------------------------------------------------------------------

## Roads from the home town to every other town, and from each town to the nearest other one, so
## the map is a network and not a star.
static func _join_towns(world: WorldState, rng: RandomNumberGenerator) -> void:
	if world.towns.size() < 2:
		return
	var grid := _cost_grid(world)
	var home := world.home_town()
	var pairs: Array = []
	for town in world.towns:
		if town != home:
			pairs.append([home, town])
	for town in world.towns:
		var nearest := {}
		var nearest_distance := INF
		for other in world.towns:
			if other == town or other == home:
				continue
			var distance := Vector2(town["center"]).distance_to(other["center"])
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = other
		if not nearest.is_empty() and town != home and not _paired(pairs, town, nearest):
			pairs.append([town, nearest])
	for pair in pairs:
		_road_between(world, grid, pair[0], pair[1], rng)


static func _paired(pairs: Array, a: Dictionary, b: Dictionary) -> bool:
	for pair in pairs:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


## A grid with the cost of crossing each tile: open ground is cheap, forest dear, a lake dearer
## still (it takes a bridge), rock very dear (it takes a cutting), and the inside of a town costs
## a lot unless it is on a street, so roads leave a town by its main roads.
static func _cost_grid(world: WorldState) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, world.width, world.height)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var cost := {}
	for tile_id in world.palette:
		cost[tile_id] = { "water": 9.0, "stone": 40.0, "forest": 3.0, "dirt": 0.8, "cobble": 0.5, "bridge": 0.8, "bridge_h": 0.8 }.get(tile_id, 1.0)
	var index := 0
	for y in world.height:
		for x in world.width:
			var weight: float = cost[world.palette[world.tiles[index]]]
			index += 1
			if weight != 1.0:
				grid.set_point_weight_scale(Vector2i(x, y), weight)
	for town in world.towns:  # the inside of a town: streets only
		var rect: Rect2i = town["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var tile_id := world.get_tile_id(x, y)
				if tile_id != "cobble" and tile_id != "water":
					grid.set_point_weight_scale(Vector2i(x, y), 7.0)
	for placed in world.objects:
		if placed.blocks_walking():
			grid.set_point_solid(placed.tile, true)
	return grid


static func _road_between(world: WorldState, grid: AStarGrid2D, from_town: Dictionary, to_town: Dictionary, _rng: RandomNumberGenerator) -> void:
	var start := _gate(world, from_town, to_town["center"])
	var goal := _gate(world, to_town, from_town["center"])
	var path := grid.get_id_path(start, goal)
	if path.is_empty():
		return
	for i in path.size():
		var step := Vector2i.ZERO if i == 0 else path[i] - path[i - 1]
		var vertical := absi(step.y) > absi(step.x)
		for brush in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var tile: Vector2i = path[i] + brush
			if not world.in_bounds(tile.x, tile.y) or _in_town(world, tile):
				continue
			var tile_id := world.get_tile_id(tile.x, tile.y)
			if tile_id == "water":
				world.set_tile(tile.x, tile.y, "bridge" if vertical else "bridge_h")
			elif tile_id != "cobble" and tile_id != "bridge" and tile_id != "bridge_h":
				world.set_tile(tile.x, tile.y, ROAD_TILE)
		if world.get_tile_id(path[i].x, path[i].y) != "cobble":
			grid.set_point_weight_scale(path[i], 0.5)  # later roads like to follow this one


## The end of a town's main road that faces `toward`, on the street itself, just inside the town.
static func _gate(world: WorldState, town: Dictionary, toward: Vector2i) -> Vector2i:
	var center: Vector2i = town["center"]
	var rect: Rect2i = town["rect"]
	var ends: Array[Vector2i] = [
		Vector2i(rect.end.x - 1, center.y + 1), Vector2i(rect.position.x, center.y + 1),
		Vector2i(center.x + 1, rect.position.y), Vector2i(center.x + 1, rect.end.y - 1)]
	var best := ends[0]
	for end in ends:
		if Vector2(end).distance_to(toward) < Vector2(best).distance_to(toward):
			best = end
	# Walk in from the tip until the street is there.
	var inward := Vector2i(signi(center.x - best.x), 0) if best.y == center.y + 1 else Vector2i(0, signi(center.y - best.y))
	var tile := best
	for i in 14:
		if world.get_tile_id(tile.x, tile.y) == "cobble":
			return tile
		tile += inward
	return best


static func _in_town(world: WorldState, tile: Vector2i) -> bool:
	for town in world.towns:
		var rect: Rect2i = town["rect"]
		if rect.has_point(tile) and _in_ellipse(town, tile):
			return true
	return false


static func _in_ellipse(town: Dictionary, tile: Vector2i) -> bool:
	var config := DataRegistry.get_def("worldgen", str(town.get("profile", "town")))
	var center: Vector2i = town["center"]
	var half_width := float(config.get("half_width", 44))
	var dx := float(tile.x - center.x) / half_width
	var dy := float(tile.y - center.y) / float(config.get("half_height_up", 26) if tile.y < center.y else config.get("half_height_down", 28))
	return dx * dx + dy * dy <= 1.0
