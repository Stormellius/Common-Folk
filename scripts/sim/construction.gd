class_name Construction
extends RefCounted
## Building as work. The player plans what they want on their land (an object, a floor, a roof over
## a closed room) and pays for it: what they hold of the materials is set aside, what they lack is
## bought at the shop's price. Then somebody has to build it. A builder with a hammer goes to the
## pile (beside the storage crates, or the gate of the lot), loads up what the plans need, hauls it to
## each plan, and works until it is done: carpentry for timber, masonry for stone. Folk of your
## household build when told to; a builder can be hired from a workshop's counter for the day.
##
## The instant commands the simulation has always had (build_place and the rest) still exist for
## tools and tests; the interface plans.

const CAPACITY := 4        # units of material one person carries at a time
const CREW_LIMIT := 2      # hired builders at once
const CREW_HOURS := 8      # how long a hire lasts


# --- what a plan is -------------------------------------------------------------------------

## The minutes an unskilled builder takes: from the object's cost unless the data says.
static func base_minutes(kind: String, def_id: String) -> int:
	match kind:
		"floor":
			return 3 + Economy.floor_cost(def_id) * 2
		"roof":
			return int(DataRegistry.get_def("roofs", def_id).get("minutes", 8))
	var def := DataRegistry.get_def("objects", def_id)
	return int(def.get("build_minutes", clampi(roundi(float(def.get("cost", 4)) * 2.5), 8, 120)))


## The skill a job uses: carpentry for timber, masonry for stone.
static func skill_for(kind: String, def_id: String) -> String:
	match kind:
		"floor":
			return str(DataRegistry.get_def("floors", def_id).get("skill", "carpentry"))
		"roof":
			return str(DataRegistry.get_def("roofs", def_id).get("skill", "carpentry"))
	var def := DataRegistry.get_def("objects", def_id)
	if def.has("build_skill"):
		return str(def["build_skill"])
	var materials: Dictionary = def.get("materials", {})
	return "masonry" if materials.has("stone") and not materials.has("wood") else "carpentry"


static func site_name(site: BuildSite) -> String:
	match site.kind:
		"floor":
			return str(DataRegistry.get_def("floors", site.def_id).get("name", site.def_id)).to_lower()
		"roof":
			return str(DataRegistry.get_def("roofs", site.def_id).get("name", site.def_id)).to_lower()
	return str(DataRegistry.get_def("objects", site.def_id).get("name", site.def_id)).to_lower()


# --- planning -------------------------------------------------------------------------------

static func _reserve(world: WorldState, needs: Dictionary) -> void:
	for resource_id in needs:
		world.reserved[resource_id] = int(world.reserved.get(resource_id, 0)) + int(needs[resource_id])


## Plans an object on a tile of the player's land. { "ok", "message" }.
static func plan_object(sim: Simulation, def_id: String, tile: Vector2i) -> Dictionary:
	var blocker := sim.build_blocker(def_id, tile)
	if blocker != "":
		return { "ok": false, "message": "Can't build here: %s" % blocker }
	if sim.world.site_at(tile, "object") != null:
		return { "ok": false, "message": "Already planned here" }
	var price := Economy.build_price(def_id, sim.household.stock)
	sim.household.coins -= int(price["coins"])
	for resource_id in price["uses"]:
		sim.household.add_stock(str(resource_id), -int(price["uses"][resource_id]))
	var site := BuildSite.new()
	site.kind = "object"
	site.def_id = def_id
	site.tile = tile
	site.needs = Economy.materials(def_id).duplicate()
	site.minutes = base_minutes("object", def_id)
	site.paid = int(price["coins"])
	_reserve(sim.world, site.needs)
	sim.world.add_site(site)
	return { "ok": true, "message": "" }


## Plans a floor on a tile.
static func plan_floor(sim: Simulation, floor_id: String, tile: Vector2i) -> Dictionary:
	if not DataRegistry.has_def("floors", floor_id):
		return { "ok": false, "message": "That floor doesn't exist" }
	if not sim.world.can_build_at(tile):
		return { "ok": false, "message": "Can't build here: outside your land" }
	if Levels.of(tile) == 1:
		var upstairs := Levels.floor_blocker(sim.world, tile)
		if upstairs != "" and sim.world.floor_at(tile) == "":
			return { "ok": false, "message": "Can't build here: %s" % upstairs }
	elif not sim.world.is_ground_walkable(tile.x, tile.y):
		return { "ok": false, "message": "Can't build here: not solid ground" }
	if sim.world.floor_at(tile) == floor_id:
		return { "ok": false, "message": "" }
	if sim.world.site_at(tile, "floor") != null:
		return { "ok": false, "message": "Already planned here" }
	var cost := Economy.floor_cost(floor_id)
	if cost > sim.household.coins:
		return { "ok": false, "message": "Can't build here: it costs %s and you have %s" % [Economy.format(cost), Economy.format(sim.household.coins)] }
	sim.household.coins -= cost
	var site := BuildSite.new()
	site.kind = "floor"
	site.def_id = floor_id
	site.tile = tile
	site.minutes = base_minutes("floor", floor_id)
	site.paid = cost
	sim.world.add_site(site)
	return { "ok": true, "message": "" }


## The tiles a roof over the room at `tile` would cover (those not roofed or planned yet), or the
## reason there is nothing to roof: { "tiles": Array, "reason": String }.
static func roof_plan(sim: Simulation, tile: Vector2i) -> Dictionary:
	var room := Rooms.roomy(sim.world, tile)
	if (room["tiles"] as Array).is_empty():
		return room
	var open: Array[Vector2i] = []
	for cell in room["tiles"]:
		if not sim.world.roofs.has(cell) and sim.world.site_at(cell, "roof") == null:
			open.append(cell)
	if open.is_empty():
		return { "tiles": open, "reason": "already roofed" }
	return { "tiles": open, "reason": "" }


## What a roof over `count` tiles takes and costs: { "needs": materials, "uses": from the stock, "coins": for the rest }.
static func roof_price(sim: Simulation, roof_id: String, count: int) -> Dictionary:
	var needs := {}
	var materials: Dictionary = DataRegistry.get_def("roofs", roof_id).get("materials", {})
	for resource_id in materials:
		needs[str(resource_id)] = int(materials[resource_id]) * count
	var uses := {}
	var coins := 0
	for resource_id in needs:
		var take := mini(sim.household.stock_of(str(resource_id)), int(needs[resource_id]))
		if take > 0:
			uses[resource_id] = take
		coins += (int(needs[resource_id]) - take) * Economy.resource_price(str(resource_id))
	return { "needs": needs, "uses": uses, "coins": coins }


## Plans a roof over the whole closed room that `tile` is in.
static func plan_room_roof(sim: Simulation, roof_id: String, tile: Vector2i) -> Dictionary:
	if not DataRegistry.has_def("roofs", roof_id):
		return { "ok": false, "message": "That roof doesn't exist" }
	var plan := roof_plan(sim, tile)
	if not (plan["reason"] as String).is_empty():
		return { "ok": false, "message": "Can't roof it: %s" % str(plan["reason"]) }
	var tiles: Array = plan["tiles"]
	var price := roof_price(sim, roof_id, tiles.size())
	if int(price["coins"]) > sim.household.coins:
		return { "ok": false, "message": "A roof over %d tiles costs %s more than you have" % [tiles.size(), Economy.format(int(price["coins"]) - sim.household.coins)] }
	sim.household.coins -= int(price["coins"])
	for resource_id in price["uses"]:
		sim.household.add_stock(str(resource_id), -int(price["uses"][resource_id]))
	_reserve(sim.world, price["needs"])
	var each: Dictionary = DataRegistry.get_def("roofs", roof_id).get("materials", {})
	for cell in tiles:
		var site := BuildSite.new()
		site.kind = "roof"
		site.def_id = roof_id
		site.tile = cell
		site.needs = each.duplicate()
		site.minutes = base_minutes("roof", roof_id)
		sim.world.add_site(site)
	return { "ok": true, "message": "" }


## Calls off a plan: what was carried to it and what was set aside come back to the stockpile, and
## half the coin.
static func cancel(sim: Simulation, site: BuildSite) -> void:
	var builder := sim.person(site.builder) if site.builder != 0 else null
	if builder != null and builder.job_kind == "build":
		builder.job_site = 0
		builder.job_stage = "decide"
	for resource_id in site.delivered:
		sim.household.add_stock(str(resource_id), int(site.delivered[resource_id]))
	var waiting := site.missing()
	for resource_id in waiting:
		var back := mini(int(waiting[resource_id]), int(sim.world.reserved.get(resource_id, 0)))
		sim.world.reserved[resource_id] = int(sim.world.reserved.get(resource_id, 0)) - back
		sim.household.add_stock(str(resource_id), back)
	sim.household.coins += Economy.refund(site.paid)
	sim.world.remove_site(site.id)


## Calls off every plan on a tile. Returns how many there were.
static func cancel_at(sim: Simulation, tile: Vector2i) -> int:
	var found: Array[BuildSite] = []
	for site in sim.world.sites:
		if site.tile == tile:
			found.append(site)
	for site in found:
		cancel(sim, site)
	return found.size()


## "5 planned, 1 builder at work", or "" when nothing is planned.
static func summary(sim: Simulation) -> String:
	var planned := sim.world.sites.size()
	if planned == 0:
		return ""
	var working := 0
	for pawn in sim.people():
		working += 1 if pawn.job_kind == "build" else 0
	return "Building: %d planned%s" % [planned, ", %d at work" % working if working > 0 else ""]


# --- the work --------------------------------------------------------------------------------

## Where the materials are kept: beside the storage crates, or just inside the lot.
static func pile_tile(sim: Simulation) -> Vector2i:
	var lot := sim.world.lot
	var near := lot.position + Vector2i(lot.size.x / 2, 1)
	for placed in sim.world.objects:
		if bool(placed.def().get("pile", false)) and lot.has_point(placed.tile):
			near = placed.tile
			break
	for radius in range(0, 7):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := near + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and lot.has_point(tile) and sim.world.is_walkable(tile.x, tile.y) and sim.world.object_at(tile) == null:
					return tile
	return near


static func has_work(sim: Simulation) -> bool:
	return not sim.world.sites.is_empty()


## Why `pawn` cannot start building now, or "".
static func build_blocker(sim: Simulation, pawn: Pawn) -> String:
	var yours := sim.household.get_pawn(pawn.id) != null
	if not yours and pawn.contract_until <= GameClock.tick:
		return "only your own folk and hired builders build here"
	if not has_work(sim):
		return "nothing is planned"
	if pawn.age < 12:
		return "too young"
	if not Life.may_do_heavy_work(pawn):
		return "too old for heavy work"
	if pawn.is_dying() or Pregnancy.in_labour(pawn) or sim.needs_break(pawn):
		return "%s isn't fit for it" % pawn.display_name.get_slice(" ", 0)
	if yours:
		return Skills.tool_blocker(sim, pawn, { "tool": "hammer" })
	return ""


## Sends a person to work through what is planned.
static func order_build(sim: Simulation, pawn: Pawn) -> Dictionary:
	var blocker := build_blocker(sim, pawn)
	if blocker != "":
		return { "ok": false, "message": "Can't build: %s" % blocker }
	sim._end_job(pawn)
	if not Skills.equip(sim, pawn, "hammer", sim.household.get_pawn(pawn.id) == null):
		return { "ok": false, "message": "Can't build: no hammer" }
	pawn.job_kind = "build"
	pawn.job_stage = "decide"
	pawn.job_site = 0
	pawn.job_minutes = 0
	return { "ok": true, "message": "" }


## A hired builder who has no job in hand starts on the work when there is some. True if they set off.
static func try_contract(sim: Simulation, pawn: Pawn) -> bool:
	if pawn.contract_until <= 0:
		return false
	if pawn.contract_until <= GameClock.tick or not has_work(sim):
		pawn.contract_until = 0  # the day is over, or the work is done
		return false
	return bool(order_build(sim, pawn)["ok"])


## One minute of a builder's day.
static func step_build(sim: Simulation, pawn: Pawn, rng: RandomNumberGenerator) -> void:
	var world := sim.world
	if sim.needs_break(pawn) or pawn.is_dying() or not has_work(sim):
		if not has_work(sim) and sim.household.get_pawn(pawn.id) != null:
			sim.health_notice.emit("%s has finished the building work." % pawn.display_name.get_slice(" ", 0))
		sim._end_job(pawn)
		return
	if pawn.contract_until > 0 and pawn.contract_until <= GameClock.tick:
		sim._end_job(pawn)
		return
	if pawn.is_moving() or not pawn.path.is_empty():
		return  # still walking
	var site := world.get_site(pawn.job_site)
	if site == null or pawn.job_stage == "decide":
		if site != null and site.builder == pawn.id:
			site.builder = 0
		site = _pick_site(sim, pawn)
		if site == null:
			if sim.household.get_pawn(pawn.id) != null and not world.sites.is_empty():
				sim.health_notice.emit("%s is waiting on the rest of the building work." % pawn.display_name.get_slice(" ", 0))
			sim._end_job(pawn)
			return
		pawn.job_site = site.id
		site.builder = pawn.id
		if site.materials_ready() or _carries_for(pawn, site):
			pawn.job_stage = "site"
			if not _walk_to_site(sim, pawn, site):
				_give_up_on(sim, pawn, site)
			return
		pawn.job_stage = "fetch"
		if not _walk(sim, pawn, pile_tile(sim)):
			sim._end_job(pawn)
		return
	match pawn.job_stage:
		"fetch":
			if _load_up(sim, pawn, site) == 0:
				sim.health_notice.emit("%s can't find the materials for the %s." % [pawn.display_name.get_slice(" ", 0), site_name(site)])
				sim._end_job(pawn)
				return
			pawn.job_stage = "site"
			if not _walk_to_site(sim, pawn, site):
				_give_up_on(sim, pawn, site)
		"site":
			if _distance(pawn.tile, site.tile) > 1:
				if not _walk_to_site(sim, pawn, site):
					_give_up_on(sim, pawn, site)
				return
			_deliver(pawn, site)
			if site.materials_ready():
				pawn.job_stage = "working"
			else:
				pawn.job_stage = "decide"
				pawn.job_site = site.id  # keep it: the next decision fetches more for it
		"working":
			_work(sim, pawn, site, rng)
		_:
			pawn.job_stage = "decide"


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _walk(sim: Simulation, pawn: Pawn, goal: Vector2i) -> bool:
	if pawn.committed_tile() == goal:
		pawn.path.clear()
		return true
	var route := sim.pathfinder.find_path(pawn.committed_tile(), goal)
	if route.is_empty():
		return false
	pawn.path = route
	return true


## Goes to the tile beside the plan (or onto it, for a floor or a roof).
static func _walk_to_site(sim: Simulation, pawn: Pawn, site: BuildSite) -> bool:
	return _walk(sim, pawn, stand_tile(sim, site, pawn.committed_tile()))


## Where to stand to work on a plan: on a floor or roof tile itself, beside an object that blocks.
static func stand_tile(sim: Simulation, site: BuildSite, from: Vector2i) -> Vector2i:
	if site.kind != "object" or not bool(DataRegistry.get_def("objects", site.def_id).get("blocks_walking", true)):
		if sim.world.is_walkable(site.tile.x, site.tile.y):
			return site.tile
	var best := site.tile
	var best_distance := 99999
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var spot: Vector2i = site.tile + step
		if sim.world.is_walkable(spot.x, spot.y) and sim.world.object_at(spot) == null:
			var distance := _distance(spot, from)
			if distance < best_distance:
				best = spot
				best_distance = distance
	return best


## The nearest plan that nobody else is at work on and that can be worked on now.
static func _pick_site(sim: Simulation, pawn: Pawn) -> BuildSite:
	var best: BuildSite = null
	var best_distance := 99999
	var now := GameClock.tick
	for site in sim.world.sites:
		if (site.builder != 0 and site.builder != pawn.id) or site.wait_until > now:
			continue
		if sim.person(site.builder) == null and site.builder != 0:
			site.builder = 0
		var distance := _distance(pawn.tile, site.tile)
		if site.materials_ready():
			distance -= 3  # prefer to finish what is ready
		if distance < best_distance:
			best = site
			best_distance = distance
	return best


## Whether what the pawn carries is any use to the plan.
static func _carries_for(pawn: Pawn, site: BuildSite) -> bool:
	var lacking := site.missing()
	for resource_id in lacking:
		if int(pawn.carrying.get(resource_id, 0)) > 0:
			return true
	return false


static func _capacity(sim: Simulation, pawn: Pawn) -> int:
	return CAPACITY + roundi(float(CAPACITY) * Fauna.pack_bonus(sim, pawn))


## Loads up at the pile with what this plan lacks and then what the nearest others lack, as much as
## can be carried. Returns the units picked up.
static func _load_up(sim: Simulation, pawn: Pawn, site: BuildSite) -> int:
	var room := _capacity(sim, pawn) - _carried(pawn)
	var taken := 0
	var ordered: Array[BuildSite] = [site]
	var others: Array[BuildSite] = []
	for other in sim.world.sites:
		if other != site and (other.builder == 0 or other.builder == pawn.id):
			others.append(other)
	others.sort_custom(func(a: BuildSite, b: BuildSite) -> bool: return _distance(a.tile, site.tile) < _distance(b.tile, site.tile))
	ordered.append_array(others)
	var wanted_total := {}
	for plan in ordered:
		var lacking := plan.missing()
		for resource_id in lacking:
			wanted_total[resource_id] = int(wanted_total.get(resource_id, 0)) + int(lacking[resource_id])
	for plan in ordered:
		var lacking := plan.missing()
		for resource_id in lacking:
			var want := mini(int(lacking[resource_id]), room)
			var held := int(pawn.carrying.get(resource_id, 0))
			want = maxi(0, mini(want, int(wanted_total[resource_id]) - held))
			var there := int(sim.world.reserved.get(resource_id, 0))
			var grab := mini(want, there)
			if grab > 0:
				pawn.carrying[resource_id] = held + grab
				sim.world.reserved[resource_id] = there - grab
				room -= grab
				taken += grab
		if room <= 0:
			break
	return taken


static func _carried(pawn: Pawn) -> int:
	var total := 0
	for resource_id in pawn.carrying:
		total += int(pawn.carrying[resource_id])
	return total


## Hands over what the plan lacks of what the pawn carries.
static func _deliver(pawn: Pawn, site: BuildSite) -> void:
	var lacking := site.missing()
	for resource_id in lacking:
		var give := mini(int(lacking[resource_id]), int(pawn.carrying.get(resource_id, 0)))
		if give > 0:
			site.delivered[resource_id] = int(site.delivered.get(resource_id, 0)) + give
			pawn.carrying[resource_id] = int(pawn.carrying[resource_id]) - give
			if int(pawn.carrying[resource_id]) <= 0:
				pawn.carrying.erase(resource_id)


static func _give_up_on(sim: Simulation, pawn: Pawn, site: BuildSite) -> void:
	site.builder = 0
	site.wait_until = GameClock.tick + 30  # try again later, and do something else meanwhile
	pawn.job_site = 0
	pawn.job_stage = "decide"


static func _minutes_for(pawn: Pawn, site: BuildSite) -> float:
	var skill_id := skill_for(site.kind, site.def_id)
	return maxf(2.0, float(site.minutes) * (1.0 - Skills.effect(pawn, skill_id, "speed")))


static func _work(sim: Simulation, pawn: Pawn, site: BuildSite, rng: RandomNumberGenerator) -> void:
	var skill_id := skill_for(site.kind, site.def_id)
	site.progress += 1.0 / _minutes_for(pawn, site)
	pawn.pose = ""
	pawn.facing = site.tile - pawn.tile if site.tile != pawn.tile else pawn.facing
	Skills.practice(sim, pawn, skill_id)
	pawn.job_minutes += 1
	var broken := Skills.wear(sim, pawn)
	if broken != "":
		sim.health_notice.emit(broken)
		sim._end_job(pawn)
		return
	if pawn.contract_until > 0:  # a hired builder is paid by the hour they work
		pawn.pay_carry += float(DataRegistry.get_def("jobs", "carpenter").get("wage", 5)) / 60.0
		if pawn.pay_carry >= 1.0:
			var due := floori(pawn.pay_carry)
			if sim.household.coins < due:
				sim.health_notice.emit("You can't pay the builder: they go home.")
				pawn.contract_until = 0
				sim._end_job(pawn)
				return
			sim.household.coins -= due
			pawn.coins += due
			pawn.pay_carry -= float(due)
	if site.progress >= 1.0:
		finish(sim, pawn, site, rng)


## A plan is done: the thing stands, the floor is laid, the roof is on.
static func finish(sim: Simulation, pawn: Pawn, site: BuildSite, rng: RandomNumberGenerator) -> void:
	var world := sim.world
	if site.kind == "object" and bool(DataRegistry.get_def("objects", site.def_id).get("blocks_walking", true)):
		for person in sim.people():
			if person.tile == site.tile or person.committed_tile() == site.tile:
				site.wait_until = GameClock.tick + 5  # somebody is standing in the way: back later
				site.builder = 0
				pawn.job_site = 0
				pawn.job_stage = "decide"
				return
	match site.kind:
		"object":
			world.add_object(site.def_id, site.tile)
			sim._reroute_blocked_walks()
		"floor":
			world.set_floor(site.tile, site.def_id)
		"roof":
			world.set_roof(site.tile, site.def_id)
	world.remove_site(site.id)
	pawn.job_site = 0
	pawn.job_stage = "decide"
	Mood.add_event(pawn, "built", GameClock.tick)
	Skills.practice(sim, pawn, skill_for(site.kind, site.def_id), 6.0)


## A builder stops: the plan they were at is free again and what they carry goes back to the pile.
static func release(sim: Simulation, pawn: Pawn) -> void:
	var site := sim.world.get_site(pawn.job_site)
	if site != null and site.builder == pawn.id:
		site.builder = 0
	pawn.job_site = 0
	for resource_id in pawn.carrying:
		sim.world.reserved[resource_id] = int(sim.world.reserved.get(resource_id, 0)) + int(pawn.carrying[resource_id])
	pawn.carrying.clear()


# --- hired builders ---------------------------------------------------------------------------

## The townsperson to hire: free, grown, from the home town, the most practised at building first.
static func _pick_crew(sim: Simulation) -> Pawn:
	var home := str(sim.world.home_town().get("id", ""))
	var best: Pawn = null
	var best_score := -1.0
	for candidate in sim.town.pawns:
		if candidate.age < 16 or candidate.age > 58 or candidate.is_infant() or candidate.is_dying() or candidate.is_busy() or candidate.class_id == "gentry":
			continue
		if candidate.contract_until > GameClock.tick or candidate.is_pregnant() or sim.needs_break(candidate):
			continue
		if str(sim.world.town_of_lot(candidate.home_lot).get("id", "")) != home:
			continue
		var score := float(Skills.level(candidate, "carpentry") + Skills.level(candidate, "masonry")) + (4.0 if candidate.work_job == "carpenter" else 0.0) + (1.0 if candidate.work_job == "" else 0.0)
		if score > best_score:
			best = candidate
			best_score = score
	return best


static func crew_count(sim: Simulation) -> int:
	var count := 0
	for pawn in sim.town.pawns:
		count += 1 if pawn.contract_until > GameClock.tick else 0
	return count


## Why a builder cannot be hired now, or "".
static func hire_blocker(sim: Simulation, pawn: Pawn) -> String:
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk hire builders"
	if not has_work(sim):
		return "nothing is planned"
	if crew_count(sim) >= CREW_LIMIT:
		return "you already have %d builders" % CREW_LIMIT
	var wage := int(DataRegistry.get_def("jobs", "carpenter").get("wage", 5))
	if sim.household.coins < wage * 2:
		return "can't afford the wages (%s an hour)" % Economy.format(wage)
	if _pick_crew(sim) == null:
		return "nobody is free to work"
	return ""


static func hire(sim: Simulation, pawn: Pawn) -> Dictionary:
	var blocker := hire_blocker(sim, pawn)
	if blocker != "":
		return { "ok": false, "message": "Can't hire a builder: %s" % blocker }
	var crew := _pick_crew(sim)
	crew.contract_until = GameClock.tick + CREW_HOURS * 60
	crew.think_cooldown = 0
	return { "ok": true, "message": "%s will build for you for the day (%s an hour)." % [crew.display_name, Economy.format(int(DataRegistry.get_def("jobs", "carpenter").get("wage", 5)))] }
