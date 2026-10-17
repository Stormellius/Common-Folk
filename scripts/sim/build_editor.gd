class_name BuildEditor
extends RefCounted
## What the hand does in build mode: find what is on a tile, pick things up and set them down, take them
## down, and take it all back with undo. Planning new things is Construction's work; this wraps it so that
## each change is remembered (see BuildHistory) and so that the views need only ask.
##
## A "target" is something a click can mean, as a dictionary:
##   { "type": "object", "id", "tile", "def" }             a built object (furniture, a wall, a door)
##   { "type": "floor",  "tile", "def" }                    a laid floor
##   { "type": "plan",   "id", "tile", "kind", "def" }      something planned that nobody has finished
##   { "type": "roof",   "tile", "def" }                    a roofed tile (taken down a room at a time)
## and every command returns { "ok": bool, "message": String } (an empty message needs no telling).
##
## The operations kept for undo are dictionaries too: "plan", "move", "remove" and "unroof".

const FILL_LIMIT := 400    # the most floor a paint-bucket click will cover
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# --- what is on a tile --------------------------------------------------------------------------

## Everything a click on `tile` could mean, the topmost first: planned objects, objects, planned floors,
## floors, planned roofs and (when `with_roof`) the roof itself.
static func targets_at(sim: Simulation, tile: Vector2i, with_roof: bool = false) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var world := sim.world
	if not world.in_bounds(tile.x, tile.y):
		return found
	var site := world.site_at(tile, "object")
	if site != null:
		found.append(_plan_target(site))
	var placed := world.object_at(tile)
	if placed != null:
		found.append({ "type": "object", "id": placed.id, "tile": tile, "def": placed.def_id })
	site = world.site_at(tile, "floor")
	if site != null:
		found.append(_plan_target(site))
	if world.floor_at(tile) != "":
		found.append({ "type": "floor", "tile": tile, "def": world.floor_at(tile) })
	site = world.site_at(tile, "roof")
	if site != null:
		found.append(_plan_target(site))
	if with_roof and world.roof_at(tile) != "":
		found.append({ "type": "roof", "tile": tile, "def": world.roof_at(tile) })
	return found


## The topmost thing on a tile, or an empty dictionary.
static func target_at(sim: Simulation, tile: Vector2i, with_roof: bool = false) -> Dictionary:
	var found := targets_at(sim, tile, with_roof)
	return found[0] if not found.is_empty() else {}


static func _plan_target(site: BuildSite) -> Dictionary:
	return { "type": "plan", "id": site.id, "tile": site.tile, "kind": site.kind, "def": site.def_id }


## Why a target cannot be picked up and set down somewhere else, or "".
static func move_refusal(target: Dictionary) -> String:
	match str(target.get("type", "")):
		"object":
			var def := DataRegistry.get_def("objects", str(target["def"]))
			if bool(def.get("stairs", false)):
				return "stairs can't be moved, only taken down"
			if not bool(def.get("buildable", true)):
				return "the %s can't be moved" % str(def.get("name", target["def"])).to_lower()
		"floor":
			if Levels.of(target["tile"]) == 1:
				return "an upstairs floor can't be moved, only taken up"
		"plan":
			if str(target["kind"]) == "roof":
				return "a roof can't be moved"
			if str(target["kind"]) == "floor" and Levels.of(target["tile"]) == 1:
				return "an upstairs floor can't be moved, only taken up"
		_:
			return "a roof can't be moved"
	return ""


## Why a target cannot be taken down, or "".
static func remove_refusal(target: Dictionary) -> String:
	if str(target.get("type", "")) == "object":
		var def := DataRegistry.get_def("objects", str(target["def"]))
		if not bool(def.get("buildable", true)):
			return "the %s can't be taken down" % str(def.get("name", target["def"])).to_lower()
	return ""


## A few words on what a target is, for the label under the mouse.
static func describe(sim: Simulation, target: Dictionary) -> String:
	var def_id := str(target.get("def", ""))
	match str(target.get("type", "")):
		"object":
			return str(DataRegistry.get_def("objects", def_id).get("name", def_id))
		"floor":
			return "%s floor" % str(DataRegistry.get_def("floors", def_id).get("name", def_id))
		"roof":
			return str(DataRegistry.get_def("roofs", def_id).get("name", def_id))
		"plan":
			var site := sim.world.get_site(int(target["id"]))
			var text := "Planned: %s" % Construction.site_name(site) if site != null else "Planned"
			if site != null:
				if site.progress > 0.0:
					text += " (%d%% built)" % roundi(site.progress * 100.0)
				elif not site.materials_ready():
					text += " (waiting for materials)"
				else:
					text += " (waiting for a builder)"
			return text
	return ""


## What picking a target with the eyedropper puts in hand: { "kind": "place" | "floor" | "roof", "id" }, or {}.
static func pick(target: Dictionary) -> Dictionary:
	var def_id := str(target.get("def", ""))
	match str(target.get("type", "")):
		"object":
			if bool(DataRegistry.get_def("objects", def_id).get("buildable", true)):
				return { "kind": "place", "id": def_id }
		"floor":
			return { "kind": "floor", "id": def_id }
		"roof":
			return { "kind": "roof", "id": def_id }
		"plan":
			return { "kind": "place" if str(target["kind"]) == "object" else str(target["kind"]), "id": def_id }
	return {}


## What can be moved among the tiles of `area`: every built thing, floor and plan on land the player holds.
static func movables_in(sim: Simulation, area: Rect2i) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			if not sim.world.can_build_at(tile):
				continue
			for target in targets_at(sim, tile):
				if move_refusal(target) == "":
					found.append(target)
	return found


# --- shapes -------------------------------------------------------------------------------------

## The tiles of the rectangle between two corners (both included): all of them, or just the outline.
static func box_tiles(a: Vector2i, b: Vector2i, hollow: bool) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var high := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if not hollow or x == low.x or x == high.x or y == low.y or y == high.y:
				tiles.append(Vector2i(x, y))
	return tiles


## The tiles a paint-bucket click on `tile` would floor: the closed room it is in, or else the whole
## laid floor it is on. { "tiles": Array[Vector2i], "reason": String }.
static func fill_tiles(sim: Simulation, tile: Vector2i) -> Dictionary:
	var world := sim.world
	var room := Rooms.roomy(world, tile)
	if (room["reason"] as String).is_empty():
		return { "tiles": room["tiles"], "reason": "" }
	var floor_id := world.floor_at(tile)
	if floor_id == "" or not world.can_build_at(tile):
		return room  # open ground: say why it is not a room
	var tiles: Array[Vector2i] = []
	var seen := { tile: true }
	var queue: Array[Vector2i] = [tile]
	while not queue.is_empty() and tiles.size() <= FILL_LIMIT:
		var here: Vector2i = queue.pop_back()
		tiles.append(here)
		for step in SIDES:
			var next := here + step
			if not seen.has(next) and world.floor_at(next) == floor_id and world.can_build_at(next):
				seen[next] = true
				queue.append(next)
	if tiles.size() > FILL_LIMIT:
		return { "tiles": [] as Array[Vector2i], "reason": "too big to fill in one go" }
	return { "tiles": tiles, "reason": "" }


## The roofed tiles joined to `tile`: one room's roof.
static func roof_tiles(sim: Simulation, tile: Vector2i) -> Array[Vector2i]:
	return _joined(tile, func(cell: Vector2i) -> bool: return sim.world.roofs.has(cell))


## The planned roof tiles joined to `tile`.
static func roof_plan_tiles(sim: Simulation, tile: Vector2i) -> Array[Vector2i]:
	return _joined(tile, func(cell: Vector2i) -> bool: return sim.world.site_at(cell, "roof") != null)


static func _joined(start: Vector2i, member: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not member.call(start):
		return tiles
	var seen := { start: true }
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and tiles.size() <= 600:
		var here: Vector2i = queue.pop_back()
		tiles.append(here)
		for step in SIDES:
			var next := here + step
			if not seen.has(next) and member.call(next):
				seen[next] = true
				queue.append(next)
	return tiles


# --- planning -----------------------------------------------------------------------------------

## Plans an object, a floor or a roof (`kind` "object", "floor" or "roof") and remembers it.
static func plan(sim: Simulation, kind: String, def_id: String, tile: Vector2i) -> Dictionary:
	var world := sim.world
	var before := world.sites.size()
	var coins := sim.household.coins
	var result := { "ok": false, "message": "" }
	match kind:
		"object":
			result = Construction.plan_object(sim, def_id, tile)
		"floor":
			result = Construction.plan_floor(sim, def_id, tile)
		"roof":
			result = Construction.plan_room_roof(sim, def_id, tile)
	if not bool(result["ok"]):
		return result
	var paid := 0
	var made: Array[Dictionary] = []
	for index in range(before, world.sites.size()):
		var site := world.sites[index]
		paid += site.paid
		made.append({ "op": "plan", "kind": site.kind, "def": site.def_id, "tile": site.tile, "id": site.id, "extra": 0 })
	if not made.is_empty():
		made[0]["extra"] = maxi(0, coins - sim.household.coins - paid)  # coin that went on a roof's materials
	for operation in made:
		sim.build_history.add(operation)
	return result


# --- taking down --------------------------------------------------------------------------------

## Takes down one target: calls off a plan, takes down an object or a floor (half the coin comes back).
static func remove(sim: Simulation, target: Dictionary) -> Dictionary:
	var world := sim.world
	var tile: Vector2i = target.get("tile", Vector2i(-1, -1))
	if not world.can_build_at(tile):
		return { "ok": false, "message": "Outside your land" }
	var refusal := remove_refusal(target)
	if refusal != "":
		return { "ok": false, "message": refusal.substr(0, 1).to_upper() + refusal.substr(1) }
	match str(target.get("type", "")):
		"plan":
			var site := world.get_site(int(target["id"]))
			if site == null:
				return { "ok": false, "message": "" }
			if site.kind == "roof":  # a roof is planned a room at a time: call off the room's
				for cell in roof_plan_tiles(sim, site.tile):
					_call_off(sim, world.site_at(cell, "roof"))
			else:
				_call_off(sim, site)
			return { "ok": true, "message": "" }
		"object":
			var placed := world.get_object(int(target["id"]))
			if placed == null:
				return { "ok": false, "message": "" }
			var refund := Economy.refund(Economy.object_cost(placed.def_id))
			sim.build_history.add({ "op": "remove", "type": "object", "def": placed.def_id, "tile": placed.tile, "refund": refund })
			sim.release_object_user(placed)
			sim.household.coins += refund
			world.remove_object(placed.id)
			sim.reroute_blocked_walks()
			return { "ok": true, "message": "" }
		"floor":
			var old_floor := world.floor_at(tile)
			if old_floor == "":
				return { "ok": false, "message": "" }
			var standing := _standing_on(sim, tile)
			if Levels.of(tile) == 1 and standing != "":
				return { "ok": false, "message": "%s is standing on it" % standing }
			var refund := Economy.refund(Economy.floor_cost(old_floor))
			if not world.set_floor(tile, ""):
				return { "ok": false, "message": "" }
			sim.household.coins += refund
			sim.build_history.add({ "op": "remove", "type": "floor", "def": old_floor, "tile": tile, "refund": refund })
			return { "ok": true, "message": "" }
		"roof":
			return unroof(sim, tile)
	return { "ok": false, "message": "" }


static func _call_off(sim: Simulation, site: BuildSite) -> void:
	if site == null:
		return
	sim.build_history.add({ "op": "remove", "type": "plan", "kind": site.kind, "def": site.def_id, "tile": site.tile,
		"saved": Construction.snapshot(site) })
	Construction.cancel(sim, site)


static func _standing_on(sim: Simulation, tile: Vector2i) -> String:
	for pawn in sim.people():
		if pawn.tile == tile or pawn.committed_tile() == tile:
			return pawn.display_name.get_slice(" ", 0)
	return ""


## Takes down whatever is topmost on a tile (not the roof).
static func remove_tile(sim: Simulation, tile: Vector2i) -> Dictionary:
	var target := target_at(sim, tile)
	if target.is_empty():
		return { "ok": false, "message": "" }  # nothing there; not worth a message
	return remove(sim, target)


## Takes the whole roof off the room that `tile` is under. Half the materials come back.
static func unroof(sim: Simulation, tile: Vector2i) -> Dictionary:
	if not sim.world.can_build_at(tile):
		return { "ok": false, "message": "Outside your land" }
	var tiles := roof_tiles(sim, tile)
	if tiles.is_empty():
		return { "ok": false, "message": "There is no roof there" }
	var operation := _take_off_roof(sim, tiles)
	sim.build_history.add(operation)
	return { "ok": true, "message": "" }


static func _take_off_roof(sim: Simulation, tiles: Array[Vector2i]) -> Dictionary:
	var roofs: Array = []
	var materials := {}
	for cell in tiles:
		var roof_id := sim.world.roof_at(cell)
		roofs.append([cell.x, cell.y, roof_id])
		var each: Dictionary = DataRegistry.get_def("roofs", roof_id).get("materials", {})
		for resource_id in each:
			materials[str(resource_id)] = int(materials.get(str(resource_id), 0)) + int(each[resource_id])
		sim.world.set_roof(cell, "")
	var back := {}
	for resource_id in materials:
		var share := Economy.refund(int(materials[resource_id]))
		if share > 0:
			back[resource_id] = share
			sim.household.add_stock(str(resource_id), share)
	return { "op": "unroof", "roofs": roofs, "stock": back }


# --- moving -------------------------------------------------------------------------------------

## Why `items` (targets) cannot all be set down `delta` tiles from where they are, or "". Moving costs nothing.
static func move_blocker(sim: Simulation, items: Array, delta: Vector2i) -> String:
	var world := sim.world
	var objects := {}
	var floors := {}
	var plans := {}
	for item in items:
		match str(item["type"]):
			"object":
				objects[int(item["id"])] = true
			"floor":
				floors[item["tile"]] = true
			"plan":
				plans[int(item["id"])] = true
	for item in items:
		var refusal := move_refusal(item)
		if refusal != "":
			return refusal
		var from: Vector2i = item["tile"]
		var dest := from + delta
		if not world.in_bounds(dest.x, dest.y) or Levels.of(dest) != Levels.of(from):
			return "off the map"
		var kind := str(item["kind"]) if str(item["type"]) == "plan" else str(item["type"])
		var def_id := str(item["def"])
		match kind:
			"object":
				var why := sim.build_blocker(def_id, dest, 0, objects, true)
				if why != "":
					return why
				var planned := world.site_at(dest, "object")
				if planned != null and not plans.has(planned.id):
					return "something is planned there"
			"floor":
				if not world.can_build_at(dest):
					return "outside your land"
				if not world.terrain_walkable(dest.x, dest.y):
					return "not solid ground"
				if str(item["type"]) == "floor":
					if world.floors.has(dest) and not floors.has(dest):
						return "there is a floor there already"
				else:
					var planned_floor := world.site_at(dest, "floor")
					if planned_floor != null and not plans.has(planned_floor.id):
						return "a floor is planned there already"
	return ""


## Picks `items` up and sets them down `delta` tiles away, all together. Whoever was using a thing stops;
## a builder at work on a plan looks for something else.
static func move(sim: Simulation, items: Array, delta: Vector2i) -> Dictionary:
	if delta == Vector2i.ZERO or items.is_empty():
		return { "ok": false, "message": "" }
	var why := move_blocker(sim, items, delta)
	if why != "":
		return { "ok": false, "message": "Can't move it here: %s" % why }
	_set_down(sim, items, delta)
	sim.build_history.add({ "op": "move", "items": items.duplicate(true), "delta": delta })
	return { "ok": true, "message": "" }


static func _set_down(sim: Simulation, items: Array, delta: Vector2i) -> void:
	var world := sim.world
	var objects := {}
	var floors: Array = []
	for item in items:
		var from: Vector2i = item["tile"]
		match str(item["type"]):
			"object":
				var placed := world.get_object(int(item["id"]))
				if placed != null:
					sim.release_object_user(placed)
					objects[placed.id] = from + delta
			"floor":
				floors.append([from, world.floor_at(from)])
			"plan":
				var site := world.get_site(int(item["id"]))
				if site != null:
					Construction.free_builder(sim, site)
					world.move_site(site.id, from + delta)
	if not objects.is_empty():
		world.relocate_objects(objects)
	for laid in floors:
		world.set_floor(laid[0], "")
	for laid in floors:
		world.set_floor((laid[0] as Vector2i) + delta, str(laid[1]))
	sim.reroute_blocked_walks()


## The same items after a move, for moving them back.
static func _moved(items: Array, delta: Vector2i) -> Array:
	var there: Array = []
	for item in items:
		var copy: Dictionary = (item as Dictionary).duplicate()
		copy["tile"] = (item["tile"] as Vector2i) + delta
		there.append(copy)
	return there


# --- undo and redo ------------------------------------------------------------------------------

static func undo(sim: Simulation) -> Dictionary:
	var history := sim.build_history
	history.end()
	if history.done.is_empty():
		return { "ok": false, "message": "Nothing to undo" }
	var step: Array = history.done.pop_back()
	var undone: Array[Dictionary] = []
	var failure := ""
	history.paused = true  # what undoing does is not a new step
	for index in range(step.size() - 1, -1, -1):
		var why := _reverse(sim, step[index])
		if why == "":
			undone.push_front(step[index])
		else:
			failure = why
	history.paused = false
	if undone.is_empty():
		history.done.append(step)  # nothing happened: it can be tried again
		return { "ok": false, "message": "Can't undo that: %s" % failure }
	history.undone.append(undone)
	return { "ok": failure == "", "message": "" if failure == "" else "Couldn't undo all of it: %s" % failure }


static func redo(sim: Simulation) -> Dictionary:
	var history := sim.build_history
	history.end()
	if history.undone.is_empty():
		return { "ok": false, "message": "Nothing to redo" }
	var step: Array = history.undone.pop_back()
	var again: Array[Dictionary] = []
	var failure := ""
	history.paused = true
	for operation in step:
		var why := _forward(sim, operation)
		if why == "":
			again.append(operation)
		else:
			failure = why
	history.paused = false
	if again.is_empty():
		history.undone.append(step)
		return { "ok": false, "message": "Can't do that again: %s" % failure }
	history.done.append(again)
	return { "ok": failure == "", "message": "" if failure == "" else "Couldn't redo all of it: %s" % failure }


## Takes one operation back. Returns why not, or "".
static func _reverse(sim: Simulation, operation: Dictionary) -> String:
	var world := sim.world
	var tile: Vector2i = operation.get("tile", Vector2i.ZERO)
	match str(operation["op"]):
		"plan":
			var site := world.get_site(int(operation["id"]))
			if site != null and site.kind == str(operation["kind"]) and site.def_id == str(operation["def"]):
				Construction.cancel(sim, site, true)  # never started: all the coin comes back
				sim.household.coins += int(operation.get("extra", 0))
				return ""
			# somebody has built it since: take down what stands there
			match str(operation["kind"]):
				"object":
					var placed := world.object_at(tile)
					if placed != null and placed.def_id == str(operation["def"]):
						var result := remove(sim, { "type": "object", "id": placed.id, "tile": tile, "def": placed.def_id })
						return "" if bool(result["ok"]) else str(result["message"])
				"floor":
					if world.floor_at(tile) == str(operation["def"]):
						var result := remove(sim, { "type": "floor", "tile": tile, "def": world.floor_at(tile) })
						return "" if bool(result["ok"]) else str(result["message"])
				"roof":
					world.set_roof(tile, "")
			return ""
		"move":
			var delta: Vector2i = operation["delta"]
			var back := _moved(operation["items"], delta)
			var why := move_blocker(sim, back, -delta)
			if why != "":
				return why
			_set_down(sim, back, -delta)
			return ""
		"remove":
			return _restore(sim, operation)
		"unroof":
			for resource_id in operation["stock"]:
				if sim.household.stock_of(str(resource_id)) < int(operation["stock"][resource_id]):
					return "the materials that came back have been used"
			for resource_id in operation["stock"]:
				sim.household.add_stock(str(resource_id), -int(operation["stock"][resource_id]))
			for saved in operation["roofs"]:
				world.set_roof(Vector2i(int(saved[0]), int(saved[1])), str(saved[2]))
			return ""
	return "unknown"


## Does an operation again after it was undone. Returns why not, or "".
static func _forward(sim: Simulation, operation: Dictionary) -> String:
	var world := sim.world
	var tile: Vector2i = operation.get("tile", Vector2i.ZERO)
	match str(operation["op"]):
		"plan":
			var kind := str(operation["kind"])
			if kind == "roof" and world.site_at(tile, "roof") != null:
				return ""  # the room's other tiles were planned along with this one
			var before := world.sites.size()
			var result := { "ok": false, "message": "" }
			match kind:
				"object":
					result = Construction.plan_object(sim, str(operation["def"]), tile)
				"floor":
					result = Construction.plan_floor(sim, str(operation["def"]), tile)
				"roof":
					result = Construction.plan_room_roof(sim, str(operation["def"]), tile)
			if not bool(result["ok"]):
				return str(result["message"]).trim_prefix("Can't build here: ")
			for index in range(before, world.sites.size()):
				if world.sites[index].tile == tile and world.sites[index].kind == kind:
					operation["id"] = world.sites[index].id
			return ""
		"move":
			var delta: Vector2i = operation["delta"]
			var why := move_blocker(sim, operation["items"], delta)
			if why != "":
				return why
			_set_down(sim, operation["items"], delta)
			return ""
		"remove":
			var result := { "ok": false, "message": "" }
			match str(operation["type"]):
				"object":
					var placed := world.object_at(tile)
					if placed != null and placed.def_id == str(operation["def"]):
						result = remove(sim, { "type": "object", "id": placed.id, "tile": tile, "def": placed.def_id })
				"floor":
					if world.floor_at(tile) == str(operation["def"]):
						result = remove(sim, { "type": "floor", "tile": tile, "def": world.floor_at(tile) })
				"plan":
					var site := world.site_at(tile, str(operation["kind"]))
					if site != null and site.def_id == str(operation["def"]):
						result = remove(sim, _plan_target(site))
			return "" if bool(result["ok"]) else (str(result["message"]) if str(result["message"]) != "" else "it has changed")
		"unroof":
			var cells: Array[Vector2i] = []
			for saved in operation["roofs"]:
				cells.append(Vector2i(int(saved[0]), int(saved[1])))
			var again := _take_off_roof(sim, cells)
			operation["stock"] = again["stock"]
			return ""
	return "unknown"


## Puts back what a "remove" operation took down. Returns why not, or "".
static func _restore(sim: Simulation, operation: Dictionary) -> String:
	var world := sim.world
	var tile: Vector2i = operation["tile"]
	var refund := int(operation.get("refund", 0))
	match str(operation["type"]):
		"object":
			if sim.household.coins < refund:
				return "you have spent what it gave back"
			var why := sim.build_blocker(str(operation["def"]), tile, 0, {}, true)
			if why != "":
				return why
			sim.household.coins -= refund
			world.add_object(str(operation["def"]), tile)
			sim.reroute_blocked_walks()
			return ""
		"floor":
			if sim.household.coins < refund:
				return "you have spent what it gave back"
			if world.floor_at(tile) != "":
				return "there is a floor there now"
			if not world.set_floor(tile, str(operation["def"])):
				return "it can't go back"
			sim.household.coins -= refund
			return ""
		"plan":
			return Construction.restore_plan(sim, operation["saved"])
	return "unknown"
