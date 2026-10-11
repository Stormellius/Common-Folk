class_name PawnActions
extends RefCounted
## What the selected person can be told to do at a spot on the map. The right-click menu
## shows whatever list_for() returns, and perform() carries out the one that was chosen.
##
## Today that is walking, stopping and switching to a neighbor. Later, objects in the world
## (a bed, a stove, a notice board) will add their own entries here, such as "Sleep" or "Cook".
## An entry that cannot be used right now is still listed, switched off, with the reason.

const WALK := "walk"
const STOP := "stop"
const SWITCH_PREFIX := "switch:"


## One entry: { "id": String, "label": String, "enabled": bool, "reason": String }.
static func _entry(id: String, label: String, enabled: bool = true, reason: String = "") -> Dictionary:
	return { "id": id, "label": label, "enabled": enabled, "reason": reason }


## The menu for `pawn` when the player right-clicks `tile`. Empty outside the map.
static func list_for(sim: Simulation, pawn: Pawn, tile: Vector2i) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not sim.world.in_bounds(tile.x, tile.y):
		return actions
	actions.append(_walk_entry(sim, pawn, tile))
	if pawn.has_orders():
		actions.append(_entry(STOP, "Stop"))
	for other in sim.household.pawns:
		if other.id != pawn.id and other.tile == tile:
			actions.append(_entry(SWITCH_PREFIX + str(other.id), "Switch to %s" % other.display_name))
	return actions


## Carries out a chosen entry. Returns { "ok": bool, "message": String }.
static func perform(sim: Simulation, pawn: Pawn, action_id: String, tile: Vector2i) -> Dictionary:
	if action_id == WALK:
		return sim.order_move(pawn, tile)
	if action_id == STOP:
		sim.order_stop(pawn)
		return { "ok": true, "message": "" }
	if action_id.begins_with(SWITCH_PREFIX):
		var switched := sim.household.select(int(action_id.trim_prefix(SWITCH_PREFIX)))
		return { "ok": switched, "message": "" if switched else "That person is not here" }
	return { "ok": false, "message": "Unknown action" }


static func _walk_entry(sim: Simulation, pawn: Pawn, tile: Vector2i) -> Dictionary:
	if not sim.world.is_walkable(tile.x, tile.y):
		var tile_id := sim.world.get_tile_id(tile.x, tile.y)
		var tile_name := str(DataRegistry.get_def("tiles", tile_id).get("name", tile_id))
		return _entry(WALK, "Walk here", false, "can't walk on %s" % tile_name.to_lower())
	var origin := pawn.committed_tile()
	if tile == origin:
		return _entry(WALK, "Walk here", false, "already there")
	if sim.pathfinder.find_path(origin, tile).is_empty():
		return _entry(WALK, "Walk here", false, "no way to get there")
	return _entry(WALK, "Walk here")
