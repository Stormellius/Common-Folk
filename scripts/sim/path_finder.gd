class_name PathFinder
extends RefCounted
## Finds walking routes across the tile map with Godot's AStarGrid2D.
##
## Blocked tiles (water, stone) are solid, forest costs extra because its tiles.json
## move_cost is higher, and diagonal steps are only allowed when they do not cut a corner.
## Call rebuild() whenever walkability changes (for example when something is built).
##
## There is a grid for each level (see Levels). A route between levels goes by the nearest stairs: it ends
## its walk on the one level at the foot of the stairs, steps to the other (the two tiles are the same place
## on the map, one above the other), and walks on from there.

var _grids: Array[AStarGrid2D] = [AStarGrid2D.new(), AStarGrid2D.new()]
var _stairs: Dictionary = {}  # tiles on the ground with stairs on them
var _world_ref: WeakRef  # weak, so that the world's signal and this finder do not keep each other alive


func _init(world: WorldState) -> void:
	_world_ref = weakref(world)
	rebuild(world)
	world.tile_changed.connect(_on_tile_changed)  # keeps itself up to date as things are built


func _on_tile_changed(cell: Vector2i) -> void:
	var world := _world_ref.get_ref() as WorldState
	if world != null:
		update_cell(world, cell)


func rebuild(world: WorldState) -> void:
	for level in _grids.size():
		var grid := _grids[level]
		grid.region = Rect2i(0, 0, world.width, world.height)
		grid.cell_size = Vector2.ONE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
	var grid := _grids[0]
	# Work out each kind of ground once, then go through the map by its palette numbers.
	var open: Array[bool] = []
	var cost: Array[float] = []
	for tile_id in world.palette:
		var def := DataRegistry.get_def("tiles", tile_id)
		open.append(bool(def.get("walkable", true)))
		cost.append(maxf(float(def.get("move_cost", 1.0)), 1.0))
	var index := 0
	for y in world.height:
		for x in world.width:
			var palette_index := world.tiles[index]
			index += 1
			if open[palette_index]:
				if cost[palette_index] != 1.0:
					grid.set_point_weight_scale(Vector2i(x, y), cost[palette_index])
			else:
				grid.set_point_solid(Vector2i(x, y), true)
	# Upstairs there is only floor to walk on.
	var upper := _grids[1]
	for y in world.height:
		for x in world.width:
			upper.set_point_solid(Vector2i(x, y), true)
	for cell in world.floors:
		if Levels.of(cell) == 1:
			update_cell(world, cell)
	_stairs.clear()
	for placed in world.objects:
		if placed.blocks_walking():
			_grids[Levels.of(placed.tile)].set_point_solid(Levels.ground(placed.tile), true)
		if placed.def_id == "stairs":
			_stairs[placed.tile] = true


## Updates one cell after something was built or removed there (much cheaper than rebuild()).
func update_cell(world: WorldState, cell: Vector2i) -> void:
	var level := Levels.of(cell)
	var ground := Levels.ground(cell)
	var grid := _grids[level]
	if not grid.is_in_boundsv(ground):
		return
	if level == 0:
		var placed := world.object_at(cell)
		if placed != null and placed.def_id == "stairs":
			_stairs[cell] = true
		else:
			_stairs.erase(cell)
	if world.is_walkable(cell.x, cell.y):
		grid.set_point_solid(ground, false)
		grid.set_point_weight_scale(ground, maxf(world.get_move_cost(cell.x, cell.y), 1.0))
	else:
		grid.set_point_solid(ground, true)


## Tiles to walk to get from `from` to `to`, not including `from`. Empty if either end
## is blocked or outside the map, or if there is no way through (also empty when
## from == to, because there is nothing left to walk).
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var from_level := Levels.of(from)
	var to_level := Levels.of(to)
	if from_level == to_level:
		return _walk(from, to)
	var best: Array[Vector2i] = []
	for foot: Vector2i in _stairs:
		var enter := Levels.lift(foot, from_level)
		var leave := Levels.lift(foot, to_level)
		var first: Array[Vector2i] = []
		var then: Array[Vector2i] = []
		if enter != from:
			first = _walk(from, enter)
			if first.is_empty():
				continue
		if leave != to:
			then = _walk(leave, to)
			if then.is_empty():
				continue
		var route: Array[Vector2i] = first.duplicate()
		route.append(leave)
		route.append_array(then)
		if best.is_empty() or route.size() < best.size():
			best = route
	return best


## A route on one level.
func _walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var level := Levels.of(from)
	var grid := _grids[level]
	var a := Levels.ground(from)
	var b := Levels.ground(to)
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b):
		return empty
	if grid.is_point_solid(a) or grid.is_point_solid(b):
		return empty
	var ground_route: Array[Vector2i] = grid.get_id_path(a, b)
	if ground_route.is_empty():
		return empty
	ground_route.remove_at(0)
	if level == 0:
		return ground_route
	var route: Array[Vector2i] = []
	for cell in ground_route:
		route.append(Levels.lift(cell, level))
	return route
