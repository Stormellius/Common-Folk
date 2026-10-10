class_name PathFinder
extends RefCounted
## Finds walking routes across the tile map with Godot's AStarGrid2D.
##
## Blocked tiles (water, stone) are solid, forest costs extra because its tiles.json
## move_cost is higher, and diagonal steps are only allowed when they do not cut a corner.
## Call rebuild() whenever walkability changes (for example when something is built).

var _grid := AStarGrid2D.new()


func _init(world: WorldState) -> void:
	rebuild(world)


func rebuild(world: WorldState) -> void:
	_grid.region = Rect2i(0, 0, world.width, world.height)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for y in world.height:
		for x in world.width:
			var cell := Vector2i(x, y)
			if world.is_walkable(x, y):
				_grid.set_point_solid(cell, false)
				_grid.set_point_weight_scale(cell, maxf(world.get_move_cost(x, y), 1.0))
			else:
				_grid.set_point_solid(cell, true)


## Tiles to walk to get from `from` to `to`, not including `from`. Empty if either end
## is blocked or outside the map, or if there is no way through (also empty when
## from == to, because there is nothing left to walk).
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not _grid.is_in_boundsv(from) or not _grid.is_in_boundsv(to):
		return empty
	if _grid.is_point_solid(from) or _grid.is_point_solid(to):
		return empty
	var route: Array[Vector2i] = _grid.get_id_path(from, to)
	if not route.is_empty():
		route.remove_at(0)
	return route
