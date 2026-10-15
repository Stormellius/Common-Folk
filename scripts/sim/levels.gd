class_name Levels
extends RefCounted
## Two-storey houses. The upstairs is not a second map: a tile upstairs is the tile below it with its y lifted by
## STEP, so (12, 40) is the ground at that spot and (12, 4136) is the upper floor above it. Floors, walls, objects,
## roofs and people upstairs are kept in the same tables as those on the ground, under those lifted tiles, and the
## path finder keeps a second grid for them. Stairs join the two (see PathFinder). The views show one level at a
## time: `view` is the one on screen.

const STEP := 4096
const TOP := 1

## The level on screen: 0 the ground floor, 1 upstairs.
static var view := 0
## Counts every change of `view`, so the views know to redraw.
static var serial := 0


static func of(tile: Vector2i) -> int:
	return 1 if tile.y >= STEP else 0


## The tile on the ground map that this one stands over or on.
static func ground(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x, tile.y - STEP) if tile.y >= STEP else tile


static func lift(tile: Vector2i, level: int) -> Vector2i:
	var base := ground(tile)
	return Vector2i(base.x, base.y + STEP * level)


## Where a tile is drawn, in world pixels (its middle).
static func pixel(tile: Vector2i) -> Vector2:
	return (Vector2(ground(tile)) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE


static func set_view(level: int) -> void:
	level = clampi(level, 0, TOP)
	if level != view:
		view = level
		serial += 1


## Whether a tile can be seen on the level on screen.
static func shown(tile: Vector2i) -> bool:
	return of(tile) == view


## Why an upstairs floor cannot be laid on `tile` (a lifted tile), or "". Floors go over a roofed room below
## and grow outward from the landing of the stairs, so a builder can always stand beside the work.
static func floor_blocker(world: WorldState, tile: Vector2i) -> String:
	if of(tile) != 1:
		return ""
	if not world.terrain_walkable(tile.x, tile.y):
		return "not solid ground below"
	if not world.roofs.has(ground(tile)):
		return "there is no room under it: roof the room below first"
	for step in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if world.floors.has(tile + step) or world.site_at(tile + step, "floor") != null:
			return ""
	return "start from the top of some stairs, and build outward from there"


## Why stairs cannot go on `tile`, or "".
static func stairs_blocker(world: WorldState, tile: Vector2i) -> String:
	if of(tile) != 0:
		return "stairs go up from the ground floor"
	if not world.roofs.has(tile):
		return "stairs belong in a roofed room"
	var top := lift(tile, 1)
	if world.object_at(top) != null or world.site_at(top, "object") != null:
		return "something is in the way upstairs"
	return ""
