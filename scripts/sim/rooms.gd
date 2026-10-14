class_name Rooms
extends RefCounted
## Rooms are the spaces closed in by walls and doors. A tile belongs to a room when you can reach no
## way out of the map or the land from it without passing a wall or a door. Only a room can be roofed,
## and a roofed tile is indoors (see Shelter). The buildings the towns are born with are roofed when
## they are made; the player roofs their own.

const LIMIT := 240   # a space bigger than this is not a room


## A wall or a door, or ground nobody can stand on (water, rock): somewhere a room ends.
static func barrier(world: WorldState, tile: Vector2i) -> bool:
	var placed := world.object_at(tile)
	if placed != null and str(placed.def().get("connects", "")) == "wall":
		return true
	return not world.is_ground_walkable(tile.x, tile.y)


## The space around `start` that walls close in: { "tiles": Array[Vector2i], "closed": bool }.
## A space that runs off the map or past the size limit is not closed.
static func region(world: WorldState, start: Vector2i, limit: int = LIMIT) -> Dictionary:
	var tiles: Array[Vector2i] = []
	if not world.in_bounds(start.x, start.y) or barrier(world, start):
		return { "tiles": tiles, "closed": false }
	var seen := { start: true }
	var queue: Array[Vector2i] = [start]
	var closed := true
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		tiles.append(tile)
		if tiles.size() > limit:
			closed = false
			break
		for step in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var next: Vector2i = tile + step
			if seen.has(next):
				continue
			seen[next] = true
			if not world.in_bounds(next.x, next.y):
				closed = false
				continue
			if not barrier(world, next):
				queue.append(next)
	return { "tiles": tiles, "closed": closed }


## The tiles of the room around `start` on the player's own land, or an empty list (with the reason
## in `reason`) if it is open to the outside, runs off the land, or is not a space at all.
static func roomy(world: WorldState, start: Vector2i) -> Dictionary:
	if not world.can_build_at(start):
		return { "tiles": [] as Array[Vector2i], "reason": "outside your land" }
	if barrier(world, start):
		return { "tiles": [] as Array[Vector2i], "reason": "that is a wall, not a room" }
	var found := region(world, start)
	if not bool(found["closed"]):
		return { "tiles": [] as Array[Vector2i], "reason": "open to the outside: close the walls first" }
	for tile in found["tiles"]:
		if not world.can_build_at(tile):
			return { "tiles": [] as Array[Vector2i], "reason": "it runs past your land" }
	return { "tiles": found["tiles"], "reason": "" }


## The roof that suits a room: tiles when its walls are mostly stone, thatch otherwise.
static func roof_for(world: WorldState, tiles: Array) -> String:
	var stone := 0
	var timber := 0
	for tile in tiles:
		for step in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var placed := world.object_at((tile as Vector2i) + step)
			if placed != null and str(placed.def().get("connects", "")) == "wall":
				if placed.def_id == "stone_wall":
					stone += 1
				else:
					timber += 1
	return "tile" if stone > timber else "thatch"


## Roofs every closed, floored room inside `rect` (a building the generator has just put up).
static func auto_roof(world: WorldState, rect: Rect2i) -> void:
	var done := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var start := Vector2i(x, y)
			if done.has(start) or world.floor_at(start) == "" or world.roofs.has(start) or barrier(world, start):
				continue
			var found := region(world, start)
			for tile in found["tiles"]:
				done[tile] = true
			if bool(found["closed"]):
				var roof := roof_for(world, found["tiles"])
				for tile in found["tiles"]:
					world.roofs[tile] = roof
