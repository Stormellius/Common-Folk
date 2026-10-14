class_name Caravans
extends RefCounted
## Trading caravans (data/caravans.json). Every so often one sets out from a town for another along
## the roads, camps on the market square for a couple of days, and moves on to the next. While it
## camps the household can buy what it carries (cloth, salt, wine, spice, a little iron and leather),
## sell it what the region makes (it pays well for the few goods it is looking for, and something for
## the rest, up to what it needs) and ride with it to its next stop for a fare.

static func config() -> Dictionary:
	return DataRegistry.get_def("caravans", "caravan")


static func _first(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)


# --- the roads ------------------------------------------------------------------------------

static var _grid: AStarGrid2D = null
static var _grid_world: WorldState = null


## A grid for finding the way along roads: roads are cheap, grass dearer, forest dearest, and what
## nobody can walk on is out.
static func _route_grid(world: WorldState) -> AStarGrid2D:
	if _grid != null and _grid_world == world:
		return _grid
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, world.width, world.height)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var cost := {}
	var walkable := {}
	for tile_id in world.palette:
		var def := DataRegistry.get_def("tiles", tile_id)
		walkable[tile_id] = bool(def.get("walkable", true))
		cost[tile_id] = { "dirt": 0.45, "cobble": 0.45, "bridge": 0.45, "bridge_h": 0.45, "grass": 2.2, "forest": 7.0 }.get(tile_id, 2.0)
	var index := 0
	for y in world.height:
		for x in world.width:
			var tile_id: String = world.palette[world.tiles[index]]
			index += 1
			if not bool(walkable[tile_id]):
				grid.set_point_solid(Vector2i(x, y), true)
			else:
				grid.set_point_weight_scale(Vector2i(x, y), float(cost[tile_id]))
	for placed in world.objects:
		if placed.blocks_walking():
			grid.set_point_solid(placed.tile, true)
	_grid = grid
	_grid_world = world
	return grid


## The tiles from `from` (not included) to `to`, or an empty list if there is no way.
static func route(world: WorldState, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var grid := _route_grid(world)
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to) or grid.is_point_solid(to):
		return [] as Array[Vector2i]
	grid.set_point_solid(from, false)  # it may be standing on something the grid took for solid
	var found: Array[Vector2i] = grid.get_id_path(from, to)
	if not found.is_empty():
		found.pop_front()
	return found


## Where a caravan camps in a town: a free open tile near the market square.
static func camp_tile(world: WorldState, town: Dictionary, taken: Array[Vector2i] = []) -> Vector2i:
	var center: Vector2i = town["center"]
	var best := center
	for radius in range(0, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := center + Vector2i(2, -4) + Vector2i(dx, dy)
				if world.is_walkable(tile.x, tile.y) and world.object_at(tile) == null and world.floor_at(tile) == "" and tile not in taken \
						and world.get_tile_id(tile.x, tile.y) in ["cobble", "dirt"]:
					return tile
	return best


static func _taken(world: WorldState) -> Array[Vector2i]:
	var taken: Array[Vector2i] = []
	for caravan in world.caravans:
		taken.append(caravan.goal)
		taken.append(caravan.tile)
	return taken


# --- setting out and arriving -------------------------------------------------------------

## Midnight: a new caravan sets out now and then, if there are fewer than there should be.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> void:
	var rules := config()
	if sim.world.towns.size() < 2 or sim.world.caravans.size() >= int(rules.get("max_active", 2)):
		return
	if GameClock.get_day_number() < int(rules.get("first_day", 1)):
		return
	if rng.randf() < float(rules.get("spawn_chance_per_day", 0.4)):
		spawn(sim, rng)


## A caravan sets out toward one of the towns (the player's home town a little more often) from another.
static func spawn(sim: Simulation, rng: RandomNumberGenerator, to_id: String = "", from_id: String = "") -> Caravan:
	var world := sim.world
	if world.towns.size() < 2:
		return null
	var to_town: Dictionary = world.get_town(to_id) if to_id != "" else {}
	if to_town.is_empty():
		var bag: Array[Dictionary] = []
		for town in world.towns:
			bag.append(town)
			if bool(town.get("home", false)):
				bag.append(town)
		to_town = bag[rng.randi() % bag.size()]
	var from_town: Dictionary = world.get_town(from_id) if from_id != "" else {}
	if from_town.is_empty() or from_town == to_town:
		var others: Array[Dictionary] = []
		for town in world.towns:
			if town != to_town:
				others.append(town)
		from_town = others[rng.randi() % others.size()]
	var start := RegionGenerator._gate(world, from_town, to_town["center"])
	var goal := camp_tile(world, to_town, _taken(world))
	var way := route(world, start, goal)
	if way.is_empty():
		return null
	var caravan := Caravan.new()
	caravan.name = _pick_name(from_town, rng)
	caravan.tile = start
	caravan.step_to = start
	caravan.facing = Vector2i(signi(way[0].x - start.x), signi(way[0].y - start.y))
	caravan.path = way
	caravan.state = "travelling"
	caravan.from_town = str(from_town["id"])
	caravan.to_town = str(to_town["id"])
	caravan.goal = goal
	caravan.coat = rng.randi() % 2
	for i in 2:
		caravan.looks.append({
			"skin": PersonFactory.pick_text(rng, "appearance", "skin", "colors", ["#e0ac80"]),
			"hair": PersonFactory.pick_text(rng, "appearance", "hair", "colors", ["#4a3220"]),
			"top": PersonFactory.pick_text(rng, "appearance", "top", "colors", ["#6a7a4a"]),
			"bottom": PersonFactory.pick_text(rng, "appearance", "bottom", "colors", ["#4a3d32"]),
			"hair_style": rng.randi() % 4,
		})
	return world.add_caravan(caravan)


static func _pick_name(town: Dictionary, rng: RandomNumberGenerator) -> String:
	var names: Array = config().get("names", ["Merchants of {town}"])
	return str(names[rng.randi() % names.size()]).replace("{town}", str(town.get("name", "the road")))


## One minute: a caravan that has reached its camp opens its wares, one that has stayed long enough
## moves on.
static func step(sim: Simulation, rng: RandomNumberGenerator) -> void:
	var world := sim.world
	for caravan in world.caravans.duplicate():
		if caravan.state == "travelling":
			if caravan.path.is_empty() and not caravan.is_moving():
				if caravan.tile == caravan.goal:
					_arrive(sim, caravan, rng)
				else:
					var way := route(world, caravan.tile, caravan.goal)
					if way.is_empty():
						caravan.tile = caravan.goal  # lost: it is put where it was going
						caravan.step_to = caravan.tile
					else:
						caravan.path = way
		elif GameClock.tick >= caravan.leaves_tick:
			_depart(sim, caravan)


static func _arrive(sim: Simulation, caravan: Caravan, rng: RandomNumberGenerator) -> void:
	var rules := config()
	caravan.state = "camped"
	caravan.at_town = caravan.to_town
	caravan.to_town = ""
	caravan.arrived_tick = GameClock.tick
	caravan.leaves_tick = GameClock.tick + int(rules.get("stay_days", 2)) * GameClock.MINUTES_PER_DAY
	_restock(caravan, rng)
	var others: Array[Dictionary] = []
	for town in sim.world.towns:
		if str(town["id"]) != caravan.at_town:
			others.append(town)
	caravan.next_town = str(others[rng.randi() % others.size()]["id"]) if not others.is_empty() else ""
	for passenger_id in caravan.passengers.duplicate():
		var rider := sim.person(passenger_id)
		if rider != null:
			get_off(sim, rider)
			sim.health_notice.emit("%s has arrived in %s with the caravan." % [_first(rider), str(sim.world.get_town(caravan.at_town).get("name", "town"))])
	var town := sim.world.get_town(caravan.at_town)
	if bool(town.get("home", false)):
		sim.health_notice.emit("%s have arrived in %s and camped on the square. They are buying and selling for %d days." % [caravan.name, str(town.get("name", "town")), int(rules.get("stay_days", 2))])


## What a caravan brings to sell, and what it is looking to buy.
static func _restock(caravan: Caravan, rng: RandomNumberGenerator) -> void:
	var rules := config()
	caravan.stock.clear()
	caravan.demand.clear()
	caravan.wants.clear()
	var wares: Array = (rules.get("wares", []) as Array).duplicate()
	for pick in mini(int(rules.get("wares_count", 3)), wares.size()):
		var total := 0.0
		for ware in wares:
			total += float(ware.get("weight", 1.0))
		var roll := rng.randf() * total
		for index in wares.size():
			roll -= float(wares[index].get("weight", 1.0))
			if roll <= 0.0 or index == wares.size() - 1:
				var ware: Dictionary = wares[index]
				var span: Array = ware.get("qty", [2, 5])
				caravan.stock[str(ware["good"])] = rng.randi_range(int(span[0]), int(span[1]))
				wares.remove_at(index)
				break
	var pool: Array = (rules.get("wanted_pool", []) as Array).duplicate()
	for pick in mini(int(rules.get("wants_count", 3)), pool.size()):
		var chosen := str(pool.pop_at(rng.randi() % pool.size()))
		caravan.wants.append(chosen)
	for resource_id in Economy.resource_ids():
		caravan.demand[resource_id] = int(rules.get("wanted_demand", 12)) if resource_id in caravan.wants else int(rules.get("other_demand", 4))


static func _depart(sim: Simulation, caravan: Caravan) -> void:
	var world := sim.world
	var next := world.get_town(caravan.next_town)
	if next.is_empty():
		caravan.leaves_tick = GameClock.tick + GameClock.MINUTES_PER_DAY
		return
	var goal := camp_tile(world, next, _taken(world))
	var way := route(world, caravan.tile, goal)
	if way.is_empty():
		caravan.leaves_tick = GameClock.tick + GameClock.MINUTES_PER_DAY  # no road: it stays another day
		return
	caravan.from_town = caravan.at_town
	caravan.to_town = caravan.next_town
	caravan.at_town = ""
	caravan.next_town = ""
	caravan.path = way
	caravan.goal = goal
	caravan.state = "travelling"
	caravan.stock.clear()
	if not caravan.passengers.is_empty():
		for passenger_id in caravan.passengers:
			var rider := sim.person(passenger_id)
			if rider != null and sim.household.get_pawn(rider.id) != null:
				sim.health_notice.emit("The caravan sets out for %s." % str(next.get("name", "the next town")))
				break


## Motion ticks: the caravans take their steps and their passengers go with them.
static func step_motion(sim: Simulation) -> void:
	for caravan in sim.world.caravans:
		if caravan.state == "travelling" and (caravan.step_ticks_total > 0 or not caravan.path.is_empty()):
			caravan.tick(sim.world)
		for passenger_id in caravan.passengers:
			var rider := sim.person(passenger_id)
			if rider != null:
				rider.tile = caravan.tile
				rider.step_to = caravan.tile
				rider.step_ticks_total = 0
				rider.step_ticks_done = 0
				rider.facing = caravan.facing


# --- trading ------------------------------------------------------------------------------------

## What the caravan asks for a unit of what it sells here.
static func buy_price(sim: Simulation, caravan: Caravan, good: String) -> int:
	var town := sim.world.get_town(caravan.at_town)
	var tile: Vector2i = town["center"] if not town.is_empty() else caravan.tile
	return maxi(1, roundi(float(Economy.resource_price(good)) * float(config().get("sells_markup", 1.1)) * Economy.region_multiplier(sim.world, tile, good)))


## What it pays for `quantity` of a good.
static func sell_price(sim: Simulation, caravan: Caravan, seller: Pawn, good: String, quantity: int) -> int:
	var rules := config()
	var town := sim.world.get_town(caravan.at_town)
	var tile: Vector2i = town["center"] if not town.is_empty() else caravan.tile
	var unit := float(Economy.resource_price(good)) * float(rules.get("buys_markup", 0.85)) * Economy.region_multiplier(sim.world, tile, good)
	if good in caravan.wants:
		unit *= float(rules.get("wanted_bonus", 1.6))
	unit *= 1.0 + Skills.effect(seller, "trading", "price")
	return roundi(unit * float(quantity))


static func trade_blocker(sim: Simulation, pawn: Pawn, caravan: Caravan) -> String:
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk trade for the household"
	if caravan.state != "camped":
		return "the caravan is on the road"
	return ""


static func buy(sim: Simulation, pawn: Pawn, caravan: Caravan, good: String) -> Dictionary:
	var blocker := trade_blocker(sim, pawn, caravan)
	if blocker != "":
		return { "ok": false, "message": "Can't trade: %s" % blocker }
	if int(caravan.stock.get(good, 0)) <= 0:
		return { "ok": false, "message": "They have no more %s" % Economy.resource_name(good).to_lower() }
	var price := buy_price(sim, caravan, good)
	if price > sim.coins_of(pawn):
		return { "ok": false, "message": "Can't afford it (%s)" % Economy.format(price) }
	sim.spend(pawn, price)
	caravan.stock[good] = int(caravan.stock[good]) - 1
	sim.household.add_stock(good, 1)
	Skills.practice(sim, pawn, "trading", 3.0)
	return { "ok": true, "message": "%s bought %s for %s." % [_first(pawn), Economy.item_phrase(good), Economy.format(price)] }


## Sells the caravan as much of a good as it still wants.
static func sell(sim: Simulation, pawn: Pawn, caravan: Caravan, good: String) -> Dictionary:
	var blocker := trade_blocker(sim, pawn, caravan)
	if blocker != "":
		return { "ok": false, "message": "Can't trade: %s" % blocker }
	var amount := mini(sim.household.stock_of(good), int(caravan.demand.get(good, 0)))
	if amount <= 0:
		return { "ok": false, "message": "They want no more %s" % Economy.resource_name(good).to_lower() }
	var earned := sell_price(sim, caravan, pawn, good, amount)
	sim.household.add_stock(good, -amount)
	sim.household.coins += earned
	caravan.demand[good] = int(caravan.demand[good]) - amount
	Skills.practice(sim, pawn, "trading", 10.0)
	return { "ok": true, "message": "Sold %d %s to the caravan for %s." % [amount, Economy.resource_name(good).to_lower(), Economy.format(earned)] }


# --- passengers ------------------------------------------------------------------------------------

static func ride_blocker(sim: Simulation, pawn: Pawn, caravan: Caravan) -> String:
	var rules := config()
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk ride with the caravan"
	if caravan.state != "camped" or caravan.next_town == "":
		return "the caravan is on the road"
	if pawn.caravan != 0:
		return "already riding"
	if pawn.age < 12 or pawn.is_dying() or Pregnancy.in_labour(pawn):
		return "%s cannot go" % _first(pawn)
	if pawn.mount != 0:
		return "get down from the horse first"
	if caravan.passengers.size() >= int(rules.get("max_passengers", 3)):
		return "the cart is full"
	if absi(pawn.tile.x - caravan.tile.x) > 12 or absi(pawn.tile.y - caravan.tile.y) > 12:
		return "too far from the cart"
	if int(rules.get("fare", 12)) > sim.coins_of(pawn):
		return "can't afford the fare (%s)" % Economy.format(int(rules.get("fare", 12)))
	return ""


## Pays the fare and climbs on; the caravan leaves within the hour.
static func board(sim: Simulation, pawn: Pawn, caravan: Caravan) -> Dictionary:
	var blocker := ride_blocker(sim, pawn, caravan)
	if blocker != "":
		return { "ok": false, "message": "Can't ride: %s" % blocker }
	var rules := config()
	sim.spend(pawn, int(rules.get("fare", 12)))
	sim._end_job(pawn)
	pawn.path.clear()
	pawn.caravan = caravan.id
	pawn.job_kind = "cart"
	pawn.job_stage = "riding"
	pawn.tile = caravan.tile
	pawn.step_to = caravan.tile
	pawn.step_ticks_total = 0
	caravan.passengers.append(pawn.id)
	caravan.leaves_tick = mini(caravan.leaves_tick, GameClock.tick + int(rules.get("leave_after_boarding_minutes", 60)))
	var destination := str(sim.world.get_town(caravan.next_town).get("name", "the next town"))
	return { "ok": true, "message": "%s climbs on the cart. It will leave for %s soon." % [_first(pawn), destination] }


static func get_off_blocker(sim: Simulation, pawn: Pawn) -> String:
	var caravan := sim.world.get_caravan(pawn.caravan)
	if caravan == null:
		return ""
	return "" if caravan.state == "camped" else "the caravan is on the road"


## The rider gets down beside the cart.
static func get_off(sim: Simulation, pawn: Pawn) -> void:
	var caravan := sim.world.get_caravan(pawn.caravan)
	if caravan != null:
		caravan.passengers.erase(pawn.id)
	pawn.caravan = 0
	if pawn.job_kind == "cart":
		pawn.job_kind = ""
		pawn.job_stage = ""
	if caravan != null:
		var spot := _free_beside(sim.world, caravan.tile)
		pawn.tile = spot
		pawn.step_to = spot
		pawn.path.clear()


## Called when whatever a rider was doing stops (they fell ill, say): they are no longer aboard.
static func leave(sim: Simulation, pawn: Pawn) -> void:
	var caravan := sim.world.get_caravan(pawn.caravan)
	if caravan != null:
		caravan.passengers.erase(pawn.id)
	pawn.caravan = 0


static func step_ride(sim: Simulation, pawn: Pawn) -> void:
	if sim.world.get_caravan(pawn.caravan) == null:
		pawn.caravan = 0
		sim._end_job(pawn)


static func _free_beside(world: WorldState, tile: Vector2i) -> Vector2i:
	for radius in range(1, 5):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var spot := tile + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and world.is_walkable(spot.x, spot.y) and world.object_at(spot) == null:
					return spot
	return tile
