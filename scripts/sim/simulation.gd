class_name Simulation
extends RefCounted
## Everything that changes as the game clock ticks: the world, the household and the
## rules that connect them. Views and input only call the commands here (order_move,
## order_stop) and read the state; they never change pawns directly.

var world: WorldState
var household: Household
var pathfinder: PathFinder


func _init(p_world: WorldState, p_household: Household) -> void:
	world = p_world
	household = p_household
	pathfinder = PathFinder.new(world)


## One game minute passes. Called from the clock's `ticked` signal.
func step() -> void:
	for pawn in household.pawns:
		pawn.tick(world)


## Sends a pawn to a tile. Returns { "ok": bool, "message": String }; the message
## says why not when the order cannot be carried out.
func order_move(pawn: Pawn, target: Vector2i) -> Dictionary:
	if not world.in_bounds(target.x, target.y):
		return { "ok": false, "message": "That is outside the map" }
	if not world.is_walkable(target.x, target.y):
		return { "ok": false, "message": "Can't walk there" }
	var origin := pawn.committed_tile()
	var route := pathfinder.find_path(origin, target)
	if route.is_empty() and origin != target:
		return { "ok": false, "message": "There is no way to get there" }
	pawn.path = route
	return { "ok": true, "message": "" }


## Stops a pawn once it has finished the step it is on.
func order_stop(pawn: Pawn) -> void:
	pawn.path.clear()
