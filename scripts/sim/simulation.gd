class_name Simulation
extends RefCounted
## Everything that changes as the game clock ticks: the world, the household and the
## rules that connect them. Views and input only call the commands here (order_move,
## order_stop, order_use) and read the state; they never change pawns directly.
##
## Each tick, every person: loses a little of each need, takes a step of any walk,
## carries on with the object they are using, and, if they have nothing to do and some
## need is low, goes off to fix it on their own.

const THINK_COOLDOWN_TICKS := 30  # wait this long after finding nothing to fix a need with
const OPTIONS_PER_NEED := 3       # how many nearest objects to try

var world: WorldState
var household: Household
var pathfinder: PathFinder
## Ids of the needs in play; see Needs.
var active_needs: Array[String] = []


func _init(p_world: WorldState, p_household: Household) -> void:
	world = p_world
	household = p_household
	pathfinder = PathFinder.new(world)
	active_needs = Needs.active_ids()
	_repair_after_load()


## One game minute passes. Called from the clock's `ticked` signal.
func step() -> void:
	var season_multipliers := _season_multipliers()
	var minute := GameClock.get_minute_of_day()
	for pawn in household.pawns:
		_drain_needs(pawn, season_multipliers)
		pawn.tick(world)
		_step_job(pawn)
		if pawn.think_cooldown > 0:
			pawn.think_cooldown -= 1
		elif not pawn.is_busy():
			_think(pawn, minute)


# --- orders ----------------------------------------------------------------------

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
	_end_job(pawn)
	pawn.path = route
	return { "ok": true, "message": "" }


## Stops a pawn once it has finished the step it is on, and puts down whatever it was using.
func order_stop(pawn: Pawn) -> void:
	_end_job(pawn)
	pawn.path.clear()


## Why `pawn` cannot use `placed` right now, or "" if it can.
func use_blocker(pawn: Pawn, placed: PlacedObject) -> String:
	if placed.user_id != 0 and placed.user_id != pawn.id:
		var other := household.get_pawn(placed.user_id)
		return "%s is using it" % (other.display_name.get_slice(" ", 0) if other != null else "someone")
	if _plan_use(pawn, placed).is_empty():
		return "can't get there"
	return ""


## Sends a pawn to use an object: walk there, then carry on until the need is full.
func order_use(pawn: Pawn, placed: PlacedObject) -> Dictionary:
	var blocker := use_blocker(pawn, placed)
	if blocker != "":
		return { "ok": false, "message": "Can't use the %s: %s" % [placed.display_name().to_lower(), blocker] }
	var plan := _plan_use(pawn, placed)
	_end_job(pawn)
	pawn.path = plan["route"]
	pawn.job_kind = "use"
	pawn.job_object = placed.id
	pawn.job_stage = "walking"
	pawn.job_tile = plan["tile"]
	pawn.job_minutes = 0
	placed.user_id = pawn.id
	return { "ok": true, "message": "" }


## A short description of what a person is doing, for the interface.
func describe_activity(pawn: Pawn) -> String:
	var text := "Idle"
	var placed := world.get_object(pawn.job_object) if pawn.job_kind == "use" else null
	if placed != null and pawn.job_stage == "using":
		text = str(placed.def().get("doing", "Busy"))
	elif placed != null:
		text = "Heading to the %s" % placed.display_name().to_lower()
	elif pawn.has_orders():
		text = "Walking"
	if pawn.slowed:
		text += " (exhausted)"
	return text


# --- needs and jobs --------------------------------------------------------------

func _season_multipliers() -> Dictionary:
	var season_id := str(GameClock.get_date().get("season_id", ""))
	return DataRegistry.get_def("seasons", season_id).get("need_drain_multipliers", {})


func _drain_needs(pawn: Pawn, season_multipliers: Dictionary) -> void:
	var empty := false
	for need_id in active_needs:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		value = maxf(0.0, value - Needs.drain_per_tick(need_id, pawn.traits, season_multipliers))
		pawn.needs[need_id] = value
		if value <= 0.0:
			empty = true
	pawn.slowed = empty


func _step_job(pawn: Pawn) -> void:
	if pawn.job_kind != "use":
		return
	var placed := world.get_object(pawn.job_object)
	if placed == null:
		_end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if pawn.tile != pawn.job_tile:
			_end_job(pawn)  # the route was blocked or cancelled
			return
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.pose = str(placed.def().get("pose", ""))
		if placed.tile != pawn.tile:
			pawn.facing = placed.tile - pawn.tile
		return
	# Using it: refill the needs it satisfies until they are all full or time is up.
	var object_def := placed.def()
	var satisfies: Dictionary = object_def.get("satisfies", {})
	var all_full := true
	for need_id in satisfies:
		if not pawn.needs.has(need_id):
			continue
		var value := minf(Needs.FULL, float(pawn.needs[need_id]) + float(satisfies[need_id]) / 60.0)
		pawn.needs[need_id] = value
		if value < Needs.FULL:
			all_full = false
	pawn.job_minutes += 1
	if all_full or pawn.job_minutes >= int(object_def.get("max_use_minutes", 60)):
		_end_job(pawn)


func _end_job(pawn: Pawn) -> void:
	var placed := world.get_object(pawn.job_object)
	if placed != null and placed.user_id == pawn.id:
		placed.user_id = 0
	pawn.job_kind = ""
	pawn.job_object = 0
	pawn.job_stage = ""
	pawn.job_minutes = 0
	pawn.pose = ""


## Finds where to stand and how to get there. { "tile", "route" }, or empty if unreachable.
func _plan_use(pawn: Pawn, placed: PlacedObject) -> Dictionary:
	var candidates: Array[Vector2i] = []
	if str(placed.def().get("use_position", "beside")) == "on":
		candidates.append(placed.tile)
	else:
		for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			candidates.append(placed.tile + step)
	var origin := pawn.committed_tile()
	var best := {}
	for candidate in candidates:
		if not world.is_walkable(candidate.x, candidate.y):
			continue
		var route: Array[Vector2i] = []
		if candidate != origin:
			route = pathfinder.find_path(origin, candidate)
			if route.is_empty():
				continue
		if best.is_empty() or route.size() < best["route"].size():
			best = { "tile": candidate, "route": route }
	return best


## An idle person with a low need goes to the nearest free thing that fills it.
func _think(pawn: Pawn, minute: int) -> void:
	var wants: Array = []
	for need_id in active_needs:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		if value < Needs.seek_below(need_id, minute):
			wants.append([value, need_id])
	if wants.is_empty():
		return
	wants.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for want in wants:
		var options: Array[PlacedObject] = []
		for placed in world.objects:
			if placed.user_id == 0 and placed.def().get("satisfies", {}).has(want[1]):
				options.append(placed)
		options.sort_custom(func(a: PlacedObject, b: PlacedObject) -> bool:
			return _distance(pawn.tile, a.tile) < _distance(pawn.tile, b.tile))
		for placed in options.slice(0, OPTIONS_PER_NEED):
			if order_use(pawn, placed)["ok"]:
				return
	pawn.think_cooldown = THINK_COOLDOWN_TICKS  # nothing within reach; try again later


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## A loaded save may predate needs or objects, or name things that are gone: make it consistent.
func _repair_after_load() -> void:
	for pawn in household.pawns:
		for need_id in active_needs:
			if not pawn.needs.has(need_id):
				pawn.needs[need_id] = 80.0
		if pawn.job_kind == "use":
			var placed := world.get_object(pawn.job_object)
			if placed == null or (placed.user_id != 0 and placed.user_id != pawn.id):
				pawn.job_kind = ""
				pawn.job_object = 0
				pawn.job_stage = ""
				pawn.pose = ""
			else:
				placed.user_id = pawn.id
	for placed in world.objects:
		var user := household.get_pawn(placed.user_id)
		if user == null or user.job_object != placed.id:
			placed.user_id = 0
