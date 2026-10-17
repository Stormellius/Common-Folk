class_name Fauna
extends RefCounted
## The animals (data/animals.json): what lives in the wilds, what the towns keep, and what the
## player's household can do with them.
##
## Wild animals (rabbits, deer, boar, wolves) graze in the forest and run from people. A hunter with
## a bow stalks one and shoots; a wounded boar turns on its hunter, and wolves come for anyone out
## alone at night. A kill brings meat and hides home. Domestic animals are kept: a horse or donkey
## can be ridden or led and an ox or donkey carries a gatherer's second load; dogs and cats are pets
## (a dog helps a hunt). Your household's animals eat from its stockpile and wander off if they go
## hungry for days. Strays can be taken in and animals bought at a stable's hitching post.

const GRID := 10               # tiles to a cell of the lookup grid of people
const BOW_RANGE := 8
const STALK_PACE := 1.5        # a hunter creeps: each step costs this much more
const HUNT_GIVE_UP := 240      # minutes after which a hunter gives up the trail
const LEAD_DISTANCE := 3       # how close a led animal keeps to its leader
const MAX_KEPT := 6            # animals one household keeps
const PET_MINUTES := 6
const RESTOCK_BELOW := 0.75    # share of a kind's target below which more arrive
const IDLE_DISMOUNT := 15      # minutes standing about after which a rider gets down


# --- data -----------------------------------------------------------------------------

static func def_of(kind: String) -> Dictionary:
	return DataRegistry.get_def("animals", kind)


static func kinds(type: String = "") -> Array[String]:
	var found: Array[String] = []
	for def in DataRegistry.get_list("animals"):
		if type == "" or str(def.get("type", "wild")) == type:
			found.append(str(def["id"]))
	return found


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _first(pawn: Pawn) -> String:
	return pawn.display_name.get_slice(" ", 0)


# --- making animals ------------------------------------------------------------------------

## A new animal on a tile. Pets and mounts are given names.
static func spawn(world: WorldState, kind: String, tile: Vector2i, rng: RandomNumberGenerator, owner: String = "", home_lot: String = "") -> Animal:
	var def := def_of(kind)
	var animal := Animal.new()
	animal.kind = kind
	animal.tile = tile
	animal.step_to = tile
	animal.hp = int(def.get("hp", 1))
	animal.owner = owner
	animal.home_lot = home_lot
	animal.coat = rng.randi() % maxi(1, (def.get("art", {}).get("colors", []) as Array).size())
	animal.facing = [Vector2i(1, 0), Vector2i(-1, 0)][rng.randi() % 2]
	animal.fed_day = GameClock.get_day_number()
	animal.think_at = GameClock.tick + rng.randi_range(0, 8)
	if bool(def.get("pet", false)) or float(def.get("ride", 0.0)) > 0.0 or float(def.get("carry", 0.0)) > 0.0:
		animal.name = _pick_name(world, rng)
	return world.add_animal(animal)


static func _pick_name(world: WorldState, rng: RandomNumberGenerator) -> String:
	var names: Array = DataRegistry.get_def("names", "pet").get("list", ["Pip"])
	var taken := {}
	for animal in world.animals:
		taken[animal.name] = true
	var free: Array = names.filter(func(n: Variant) -> bool: return not taken.has(str(n)))
	var pool: Array = free if not free.is_empty() else names
	return str(pool[rng.randi() % pool.size()])


## Stocks the wilds and puts a stray cat and dog in each town. Called once when a world is made (or an
## older save is first loaded).
static func populate(world: WorldState, rng: RandomNumberGenerator) -> void:
	world.fauna_seeded = true
	for kind in kinds("wild"):
		var wanted := int(def_of(kind).get("target", 0))
		var placed := 0
		for attempt in wanted * 30:
			if placed >= wanted:
				break
			var spot := _wild_spot(world, def_of(kind), rng)
			if spot != Vector2i(-1, -1):
				spawn(world, kind, spot, rng)
				placed += 1
	for town in world.towns:
		for kind in ["cat", "dog"]:
			var spot := _stray_spot(world, town, rng)
			if spot != Vector2i(-1, -1):
				spawn(world, kind, spot, rng)


## Gives some of the town's households a dog or a cat, living in their home.
static func give_pets(world: WorldState, rng: RandomNumberGenerator, chance: float = 0.3) -> void:
	for lot in world.lots:
		if str(lot["kind"]) != "house" or rng.randf() >= chance:
			continue
		var rect: Rect2i = lot["rect"]
		var spots: Array[Vector2i] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var tile := Vector2i(x, y)
				if world.floor_at(tile) != "" and world.is_walkable(x, y) and world.object_at(tile) == null:
					spots.append(tile)
		if spots.is_empty():
			continue
		spawn(world, "dog" if rng.randf() < 0.55 else "cat", spots[rng.randi() % spots.size()], rng, "town", str(lot["id"]))


static func _near_town(world: WorldState, tile: Vector2i, margin: int) -> bool:
	for town in world.towns:
		if (town["rect"] as Rect2i).grow(margin).has_point(tile):
			return true
	return false


static func _wild_spot(world: WorldState, def: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var keep_from := int(def.get("hostile", {}).get("keep_from_towns", 14))
	var tile := Vector2i(rng.randi_range(4, world.width - 5), rng.randi_range(4, world.height - 5))
	if _allowed_wild(world, def, tile, keep_from) and not world.lot.grow(keep_from).has_point(tile):
		return tile
	return Vector2i(-1, -1)


static func _stray_spot(world: WorldState, town: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var rect: Rect2i = town["rect"]
	for attempt in 80:
		var tile := rect.position + Vector2i(rng.randi() % rect.size.x, rng.randi() % rect.size.y)
		if world.is_walkable(tile.x, tile.y) and world.object_at(tile) == null and world.floor_at(tile) == "" and _public_ground(world, tile) \
				and world.get_tile_id(tile.x, tile.y) in ["cobble", "dirt", "grass"]:
			return tile
	return Vector2i(-1, -1)


## Open ground that is nobody's house or yard: a street, a green, a market.
static func _public_ground(world: WorldState, tile: Vector2i) -> bool:
	var lot := world.lot_at(tile)
	return lot.is_empty() or bool(lot.get("public", false))


static func _allowed_wild(world: WorldState, def: Dictionary, tile: Vector2i, keep_from_towns: int = 12) -> bool:
	if not world.in_bounds(tile.x, tile.y) or not world.is_walkable(tile.x, tile.y) or world.object_at(tile) != null:
		return false
	if world.get_tile_id(tile.x, tile.y) not in def.get("habitat", ["grass", "forest"]):
		return false
	return not _near_town(world, tile, keep_from_towns)


# --- the passing minutes ---------------------------------------------------------------

## Every animal that is not already on the move decides what to do next, now and then.
static func step(sim: Simulation, rng: RandomNumberGenerator) -> void:
	var world := sim.world
	if world.animals.is_empty():
		return
	var now := GameClock.tick
	var grid := _pawn_grid(sim)
	var hour := GameClock.get_minute_of_day() / 60
	for animal in world.animals:
		if animal.rider != 0 or animal.is_moving() or not animal.path.is_empty() or now < animal.think_at:
			continue
		if animal.is_wild():
			_think_wild(sim, animal, grid, now, hour, rng)
		else:
			_think_tame(sim, animal, now, rng)
	for pawn in sim.household.pawns:
		if pawn.mount != 0:
			_ride_minute(sim, pawn, now)


## Where the people are who are about out of doors, by cell, for animals to look round them.
static func _pawn_grid(sim: Simulation) -> Dictionary:
	var grid := {}
	for pawn in sim.household.pawns:
		_grid_add(grid, pawn)
	for pawn in sim.town.pawns:
		_grid_add(grid, pawn)
	return grid


static func _grid_add(grid: Dictionary, pawn: Pawn) -> void:
	if pawn.is_infant() or pawn.pose == "lie":
		return
	var cell := Vector2i(pawn.tile.x / GRID, pawn.tile.y / GRID)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(pawn)


static func _nearest_pawn(grid: Dictionary, world: WorldState, tile: Vector2i, radius: int, out_of_doors_only: bool = false) -> Pawn:
	var best: Pawn = null
	var best_distance := radius + 1
	var cell := Vector2i(tile.x / GRID, tile.y / GRID)
	var reach := radius / GRID + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var here: Variant = grid.get(cell + Vector2i(dx, dy))
			if here == null:
				continue
			for pawn: Pawn in here:
				var distance := _distance(pawn.tile, tile)
				if distance < best_distance and (not out_of_doors_only or (world.floor_at(pawn.tile) == "" and not _near_town(world, pawn.tile, 3))):
					best = pawn
					best_distance = distance
	return best


static func _think_wild(sim: Simulation, animal: Animal, grid: Dictionary, now: int, hour: int, rng: RandomNumberGenerator) -> void:
	var def := animal.def()
	var world := sim.world
	# Wolves come for people who are out alone in the dark.
	var hostile: Dictionary = def.get("hostile", {})
	if not hostile.is_empty() and _hour_in(hour, int(hostile.get("from_hour", 19)), int(hostile.get("to_hour", 5))) and now >= animal.alert_until:
		var prey := _nearest_pawn(grid, world, animal.tile, int(hostile.get("radius", 10)), true)
		if prey != null:
			_close_in(sim, animal, prey, hostile, now, rng)
			return
	# A wounded animal turns on whoever hurt it.
	if animal.charging != 0:
		var target := sim.person(animal.charging)
		var risk: Dictionary = def.get("fights_back", {})
		if target == null or target.is_dying() or risk.is_empty():
			animal.charging = 0
		else:
			_close_in(sim, animal, target, risk, now, rng)
			return
	var alert := int(def.get("alert", 7))
	var scared := now < animal.alert_until
	var threat := _nearest_pawn(grid, world, animal.tile, alert * (2 if scared else 1))
	if threat != null:
		animal.alert_until = maxi(animal.alert_until, now + int(def.get("flee_minutes", 25)))
		_flee(sim, animal, def, threat.tile, rng)
		animal.think_at = now + 1
		return
	if rng.randf() < float(def.get("wander", 0.08)):
		_wander(sim, animal, def, rng, rng.randi_range(1, 3))
	animal.think_at = now + rng.randi_range(2, 6)


static func _hour_in(hour: int, from_hour: int, to_hour: int) -> bool:
	return hour >= from_hour or hour < to_hour if from_hour > to_hour else (hour >= from_hour and hour < to_hour)


## An animal that means harm goes up to its victim and strikes.
static func _close_in(sim: Simulation, animal: Animal, prey: Pawn, risk: Dictionary, now: int, rng: RandomNumberGenerator) -> void:
	var def := animal.def()
	if _distance(animal.tile, prey.committed_tile()) <= 1:
		var chance := float(risk.get("chance", 0.3)) * Skills.safety_multiplier(prey, "hunting")
		if rng.randf() < chance:
			var notice := Accidents.strike(sim, prey, risk, rng)
			if notice != "":
				sim.health_notice.emit(notice)
		animal.charging = 0
		animal.alert_until = now + int(def.get("flee_minutes", 25))  # it runs off after the attack
		_flee(sim, animal, def, prey.tile, rng)
		animal.think_at = now + 2
		return
	var route := _greedy_path(sim.world, animal, def, prey.committed_tile(), 12, true)
	animal.path = route
	animal.think_at = now + 1


static func _flee(sim: Simulation, animal: Animal, def: Dictionary, from: Vector2i, rng: RandomNumberGenerator) -> void:
	var away := animal.tile - from
	if away == Vector2i.ZERO:
		away = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	var goal := animal.tile + Vector2i(signi(away.x), signi(away.y)) * mini(int(def.get("flee_distance", 16)), 12)
	animal.path = _greedy_path(sim.world, animal, def, goal, mini(int(def.get("flee_distance", 16)), 12), false)


static func _wander(sim: Simulation, animal: Animal, def: Dictionary, rng: RandomNumberGenerator, steps: int) -> void:
	var goal := animal.tile + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
	animal.path = _greedy_path(sim.world, animal, def, goal, steps, false)


## A short path of single steps from the animal toward `goal`, each to an allowed tile: no map search,
## so it costs next to nothing. `onto` lets the last step land on the goal itself.
static func _greedy_path(world: WorldState, animal: Animal, def: Dictionary, goal: Vector2i, max_steps: int, onto: bool) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var at := animal.tile
	for i in max_steps:
		var best := at
		var best_distance := _distance(at, goal) * 8 + (absi(at.x - goal.x) + absi(at.y - goal.y))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var next := at + Vector2i(dx, dy)
				if next == goal and not onto:
					continue
				if not _allowed_for(world, animal, def, next):
					continue
				var distance := _distance(next, goal) * 8 + (absi(next.x - goal.x) + absi(next.y - goal.y))
				if distance < best_distance and (route.is_empty() or next != route[route.size() - 1]) and next not in route:
					best = next
					best_distance = distance
		if best == at:
			break
		route.append(best)
		at = best
		if at == goal:
			break
	return route


## Whether the animal may step onto a tile: wild ones keep to their habitat and away from towns;
## tame ones to their home lot or, if they have none, to open ground.
static func _allowed_for(world: WorldState, animal: Animal, def: Dictionary, tile: Vector2i) -> bool:
	if not world.in_bounds(tile.x, tile.y) or not world.is_walkable(tile.x, tile.y) or world.object_at(tile) != null:
		return false
	if animal.is_wild():
		if world.get_tile_id(tile.x, tile.y) not in def.get("habitat", ["grass", "forest"]):
			return false
		return not _near_town(world, tile, int(def.get("hostile", {}).get("keep_from_towns", 10)) if def.has("hostile") else 8)
	if animal.leader != 0:
		return true
	if animal.home_lot != "":
		var lot := world.get_lot(animal.home_lot)
		return not lot.is_empty() and (lot["rect"] as Rect2i).grow(1).has_point(tile)
	return _public_ground(world, tile) and (_near_town(world, tile, 0) or not animal.is_pet())


static func _think_tame(sim: Simulation, animal: Animal, now: int, rng: RandomNumberGenerator) -> void:
	var def := animal.def()
	var world := sim.world
	if animal.leader != 0:
		var leader := sim.person(animal.leader)
		if leader == null or leader.is_dying():
			animal.leader = 0
		else:
			var distance := _distance(animal.tile, leader.committed_tile())
			if distance > LEAD_DISTANCE:
				var goal := _free_beside(world, leader.committed_tile(), animal.tile)
				var route := sim.pathfinder.find_path(animal.tile, goal) if goal != animal.tile else ([] as Array[Vector2i])
				if not route.is_empty():
					animal.path = route
			animal.think_at = now + (2 if distance > 8 else 4)
			return
	var home := _home_rect(sim, animal)
	if home.size != Vector2i.ZERO and not home.grow(2).has_point(animal.tile):
		var goal := _free_in(world, home, rng, animal.home_lot == "")
		var route := sim.pathfinder.find_path(animal.tile, goal) if goal != Vector2i(-1, -1) else ([] as Array[Vector2i])
		if not route.is_empty():
			animal.path = route
		animal.think_at = now + 30
		return
	if rng.randf() < float(def.get("wander", 0.05)):
		_wander(sim, animal, def, rng, rng.randi_range(1, 3))
	animal.think_at = now + rng.randi_range(2, 8)


## The place a tame animal belongs: its lot, or the town it strays in.
static func _home_rect(sim: Simulation, animal: Animal) -> Rect2i:
	if animal.home_lot != "":
		var lot := sim.world.get_lot(animal.home_lot)
		return lot["rect"] if not lot.is_empty() else Rect2i()
	var town := sim.world.town_at(animal.tile, 4)
	return town["rect"] if not town.is_empty() else Rect2i()


static func _free_beside(world: WorldState, tile: Vector2i, from: Vector2i) -> Vector2i:
	var best := tile
	var best_distance := 9999
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var spot := tile + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and world.is_walkable(spot.x, spot.y) and world.object_at(spot) == null:
				var distance := _distance(spot, from)
				if distance < best_distance:
					best = spot
					best_distance = distance
	return best


## A free tile in a lot or town to head for: out of doors if `outdoors`.
static func _free_in(world: WorldState, rect: Rect2i, rng: RandomNumberGenerator, outdoors: bool) -> Vector2i:
	for attempt in 40:
		var tile := rect.position + Vector2i(rng.randi() % rect.size.x, rng.randi() % rect.size.y)
		if world.is_walkable(tile.x, tile.y) and world.object_at(tile) == null and (not outdoors or (world.floor_at(tile) == "" and _public_ground(world, tile))):
			return tile
	return Vector2i(-1, -1)


## Motion ticks: animals take their steps, and a ridden one keeps beneath its rider.
static func step_motion(sim: Simulation) -> void:
	var world := sim.world
	for animal in world.animals:
		if animal.step_ticks_total > 0 or not animal.path.is_empty():
			if animal.rider == 0:
				animal.tick(world)
	for pawn in sim.household.pawns:
		if pawn.mount != 0:
			var animal := world.get_animal(pawn.mount)
			if animal != null:
				animal.tile = pawn.tile
				animal.step_to = pawn.step_to
				animal.step_ticks_total = pawn.step_ticks_total
				animal.step_ticks_done = pawn.step_ticks_done
				animal.facing = pawn.facing


# --- hunting -----------------------------------------------------------------------------------

static func hunt_blocker(sim: Simulation, pawn: Pawn, animal: Animal) -> String:
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk hunt for the household"
	var def := animal.def()
	if not animal.is_wild() or (def.get("yields", {}) as Dictionary).is_empty():
		return "not game"
	if pawn.age < 14:
		return "too young"
	if not Life.may_do_heavy_work(pawn):
		return "too old to hunt"
	if pawn.is_dying() or Pregnancy.in_labour(pawn):
		return "not able"
	if sim.needs_break(pawn):
		return "%s isn't fit for it" % _first(pawn)
	if pawn.mount != 0:
		return "get down from the horse first"
	return Skills.tool_blocker(sim, pawn, { "tool": "bow" })


static func order_hunt(sim: Simulation, pawn: Pawn, animal: Animal) -> Dictionary:
	var blocker := hunt_blocker(sim, pawn, animal)
	if blocker != "":
		return { "ok": false, "message": "Can't hunt: %s" % blocker }
	sim._end_job(pawn)
	if not Skills.equip(sim, pawn, "bow"):
		return { "ok": false, "message": "Can't hunt: no bow" }
	pawn.path.clear()
	pawn.job_kind = "hunt"
	pawn.job_animal = animal.id
	pawn.job_stage = "walking"
	pawn.job_minutes = 0
	refresh_pace(sim, pawn)
	if not _approach(sim, pawn, animal):
		sim._end_job(pawn)
		return { "ok": false, "message": "Can't get at %s" % animal.title() }
	return { "ok": true, "message": "" }


## Plans the walk toward the quarry, stopping a stone's throw short.
static func _approach(sim: Simulation, pawn: Pawn, animal: Animal) -> bool:
	if _distance(pawn.committed_tile(), animal.tile) <= BOW_RANGE:
		pawn.path.clear()
		return true
	var route := sim.pathfinder.find_path(pawn.committed_tile(), animal.tile)
	if route.is_empty():
		return false
	var keep := maxi(0, route.size() - (BOW_RANGE - 2))
	pawn.path = route.slice(0, keep)
	return true


## One minute of the hunt.
static func step_hunt(sim: Simulation, pawn: Pawn, rng: RandomNumberGenerator) -> void:
	var animal := sim.world.get_animal(pawn.job_animal)
	if animal == null or sim.needs_break(pawn) or pawn.is_dying():
		sim._end_job(pawn)
		return
	pawn.job_minutes += 1
	if pawn.job_minutes > HUNT_GIVE_UP:
		sim.health_notice.emit("%s lost the trail of %s." % [_first(pawn), animal.title()])
		sim._end_job(pawn)
		return
	Skills.practice_deed(sim, pawn, "hunting", "stalk", 1.0)
	var broken := Skills.wear(sim, pawn)
	if broken != "":
		sim.health_notice.emit(broken)
		sim._end_job(pawn)
		return
	var distance := _distance(pawn.tile, animal.tile)
	if distance <= BOW_RANGE:
		pawn.path.clear()
		if pawn.is_moving():
			return
		pawn.job_stage = "using"
		pawn.facing = animal.tile - pawn.tile if animal.tile != pawn.tile else pawn.facing
		_shoot(sim, pawn, animal, distance, rng)
	else:
		pawn.job_stage = "walking"
		if not pawn.is_moving() and (pawn.path.is_empty() or (GameClock.tick + pawn.id) % 3 == 0):
			if not _approach(sim, pawn, animal):
				sim._end_job(pawn)


static func _shoot(sim: Simulation, pawn: Pawn, animal: Animal, distance: int, rng: RandomNumberGenerator) -> void:
	var def := animal.def()
	var skill := Skills.level(pawn, "hunting")
	var chance := 0.60 + 0.045 * float(skill) - 0.035 * float(distance) - float(def.get("evade", 0.0)) + _hound_bonus(sim, pawn)
	var now := GameClock.tick
	if rng.randf() >= clampf(chance, 0.05, 0.92):  # a miss: it bolts
		animal.alert_until = now + int(def.get("flee_minutes", 25))
		animal.think_at = now
		return
	animal.hp -= 1 + (1 if rng.randf() < 0.07 * float(skill) else 0)
	if animal.hp <= 0:
		_kill(sim, pawn, animal, rng)
		return
	animal.alert_until = now + int(def.get("flee_minutes", 25))
	animal.think_at = now
	if def.has("fights_back"):
		animal.charging = pawn.id  # a wounded boar turns on its hunter


## A dog of the household nearby makes a hunt easier.
static func _hound_bonus(sim: Simulation, pawn: Pawn) -> float:
	var best := 0.0
	for animal in sim.world.animals:
		if animal.owner == "household" and _distance(animal.tile, pawn.tile) <= 10:
			best = maxf(best, float(animal.def().get("helps_hunt", 0.0)))
	return best


static func _kill(sim: Simulation, pawn: Pawn, animal: Animal, rng: RandomNumberGenerator) -> void:
	var brought := {}
	var yields: Dictionary = animal.def().get("yields", {})
	for resource_id in yields:
		var amount := Skills.yield_amount(pawn, "hunting", int(yields[resource_id]), rng)
		if amount > 0:
			sim.household.add_stock(str(resource_id), amount)
			brought[str(resource_id)] = amount
	var title := animal.title()
	sim.world.remove_animal(animal.id)
	Mood.add_event(pawn, "hunted", GameClock.tick)
	Skills.practice_deed(sim, pawn, "hunting", "kill", 15.0)
	sim.health_notice.emit("%s brought down %s: %s." % [_first(pawn), title, Economy.stock_text(brought)])
	sim._end_job(pawn)


# --- riding, leading, petting ----------------------------------------------------------------

## Works out how much each of a person's steps costs: less on a horse (a skilled rider goes faster
## still), more when stalking game.
static func refresh_pace(sim: Simulation, pawn: Pawn) -> void:
	var pace := 1.0
	if pawn.mount != 0:
		var animal := sim.world.get_animal(pawn.mount)
		if animal != null:
			pace = float(animal.def().get("ride", 1.0)) * (1.0 - Skills.effect(pawn, "husbandry", "speed"))
	if pawn.job_kind == "hunt":
		pace *= STALK_PACE
	pawn.pace = pace


static func ride_blocker(sim: Simulation, pawn: Pawn, animal: Animal) -> String:
	if sim.household.get_pawn(pawn.id) == null or animal.owner != "household":
		return "not yours to ride"
	if float(animal.def().get("ride", 0.0)) <= 0.0:
		return "%s cannot be ridden" % animal.title()
	if animal.rider != 0:
		return "someone is already riding"
	if pawn.mount != 0:
		return "already riding"
	if pawn.age < 12 or pawn.is_dying() or Pregnancy.in_labour(pawn) or Pregnancy.is_heavy(pawn):
		return "%s cannot ride now" % _first(pawn)
	return ""


static func order_ride(sim: Simulation, pawn: Pawn, animal: Animal) -> Dictionary:
	var blocker := ride_blocker(sim, pawn, animal)
	if blocker != "":
		return { "ok": false, "message": "Can't ride: %s" % blocker }
	sim._end_job(pawn)
	animal.leader = 0
	animal.path.clear()
	if _distance(pawn.committed_tile(), animal.tile) <= 1:
		mount(sim, pawn, animal)
		return { "ok": true, "message": "" }
	var route := sim.pathfinder.find_path(pawn.committed_tile(), animal.tile)
	if route.is_empty():
		return { "ok": false, "message": "Can't get to %s" % animal.title() }
	route.pop_back()
	pawn.path = route
	pawn.job_kind = "mount"
	pawn.job_animal = animal.id
	pawn.job_stage = "walking"
	return { "ok": true, "message": "" }


static func step_mount(sim: Simulation, pawn: Pawn) -> void:
	var animal := sim.world.get_animal(pawn.job_animal)
	if animal == null or animal.rider != 0:
		sim._end_job(pawn)
		return
	if _distance(pawn.tile, animal.tile) <= 1 and not pawn.is_moving():
		pawn.path.clear()
		sim._end_job(pawn)
		mount(sim, pawn, animal)
	elif not pawn.is_moving() and pawn.path.is_empty():
		var route := sim.pathfinder.find_path(pawn.committed_tile(), animal.tile)
		if route.size() > 1:
			route.pop_back()
			pawn.path = route
		else:
			sim._end_job(pawn)


static func mount(sim: Simulation, pawn: Pawn, animal: Animal) -> void:
	pawn.mount = animal.id
	animal.rider = pawn.id
	animal.leader = 0
	animal.path.clear()
	animal.tile = pawn.tile
	animal.step_to = pawn.step_to
	animal.alert_until = GameClock.tick  # when the rider last moved, for getting down after a while
	refresh_pace(sim, pawn)


## Gets a rider down: the animal stands on a free tile out of doors beside them.
static func dismount(sim: Simulation, pawn: Pawn) -> void:
	if pawn.mount == 0:
		return
	var animal := sim.world.get_animal(pawn.mount)
	pawn.mount = 0
	refresh_pace(sim, pawn)
	if animal == null:
		return
	animal.rider = 0
	animal.path.clear()
	animal.step_ticks_total = 0
	animal.step_ticks_done = 0
	var spot := pawn.tile
	if sim.world.floor_at(spot) != "" or sim.world.object_at(spot) != null:
		for radius in range(1, 7):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var tile := pawn.tile + Vector2i(dx, dy)
					if maxi(absi(dx), absi(dy)) == radius and sim.world.is_walkable(tile.x, tile.y) and sim.world.object_at(tile) == null and sim.world.floor_at(tile) == "":
						spot = tile
						break
				if spot != pawn.tile and sim.world.floor_at(spot) == "":
					break
			if spot != pawn.tile and sim.world.floor_at(spot) == "":
				break
	animal.tile = spot
	animal.step_to = spot
	animal.think_at = GameClock.tick + 5


## Each minute a rider is in the saddle they practise, and after a while idle they get down.
static func _ride_minute(sim: Simulation, pawn: Pawn, now: int) -> void:
	var animal := sim.world.get_animal(pawn.mount)
	if animal == null:
		pawn.mount = 0
		refresh_pace(sim, pawn)
		return
	if pawn.has_orders():
		animal.alert_until = now
		Skills.practice_deed(sim, pawn, "husbandry", "ride", 0.6)
	elif pawn.job_kind == "" and now - animal.alert_until >= IDLE_DISMOUNT:
		dismount(sim, pawn)
	refresh_pace(sim, pawn)


static func lead_blocker(sim: Simulation, pawn: Pawn, animal: Animal) -> String:
	if sim.household.get_pawn(pawn.id) == null or animal.owner != "household":
		return "not yours to lead"
	if animal.rider != 0:
		return "someone is riding it"
	return ""


static func lead(animal: Animal, pawn: Pawn) -> void:
	animal.leader = pawn.id
	animal.think_at = GameClock.tick


static func release(animal: Animal) -> void:
	animal.leader = 0
	animal.path.clear()


static func pet_blocker(sim: Simulation, pawn: Pawn, animal: Animal) -> String:
	if animal.is_wild():
		return "it is wild"
	if pawn.is_dying() or Pregnancy.in_labour(pawn) or pawn.age < 3:
		return "not able"
	if animal.rider != 0:
		return "it is being ridden"
	return ""


static func order_pet(sim: Simulation, pawn: Pawn, animal: Animal) -> Dictionary:
	var blocker := pet_blocker(sim, pawn, animal)
	if blocker != "":
		return { "ok": false, "message": "Can't: %s" % blocker }
	sim._end_job(pawn)
	var route := sim.pathfinder.find_path(pawn.committed_tile(), animal.tile) if _distance(pawn.committed_tile(), animal.tile) > 1 else ([] as Array[Vector2i])
	if _distance(pawn.committed_tile(), animal.tile) > 1:
		if route.is_empty():
			return { "ok": false, "message": "Can't get to %s" % animal.title() }
		route.pop_back()
	pawn.path = route
	pawn.job_kind = "pet"
	pawn.job_animal = animal.id
	pawn.job_stage = "walking"
	pawn.job_minutes = 0
	animal.think_at = GameClock.tick + PET_MINUTES + 4  # it stays for the petting
	animal.path.clear()
	return { "ok": true, "message": "" }


static func step_pet(sim: Simulation, pawn: Pawn) -> void:
	var animal := sim.world.get_animal(pawn.job_animal)
	if animal == null:
		sim._end_job(pawn)
		return
	if pawn.job_stage == "walking":
		if pawn.is_moving() or not pawn.path.is_empty():
			return
		if _distance(pawn.tile, animal.tile) > 1:
			sim._end_job(pawn)
			return
		pawn.job_stage = "using"
		pawn.job_minutes = 0
		pawn.facing = animal.tile - pawn.tile if animal.tile != pawn.tile else pawn.facing
		animal.think_at = GameClock.tick + PET_MINUTES + 2
		return
	pawn.job_minutes += 1
	for need_id in ["social", "fun"]:
		if pawn.needs.has(need_id):
			pawn.needs[need_id] = minf(Needs.FULL, float(pawn.needs[need_id]) + 5.0)
	if pawn.job_minutes >= PET_MINUTES:
		Mood.add_event(pawn, "petted", GameClock.tick, animal.display_name())
		Skills.practice_deed(sim, pawn, "husbandry", "pet", 8.0)
		sim._end_job(pawn)


# --- keeping animals -------------------------------------------------------------------------

static func kept_by(sim: Simulation) -> Array[Animal]:
	var kept: Array[Animal] = []
	for animal in sim.world.animals:
		if animal.owner == "household":
			kept.append(animal)
	return kept


static func adopt_blocker(sim: Simulation, pawn: Pawn, animal: Animal) -> String:
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk take animals in"
	if animal.is_wild() or animal.owner != "":
		return "it has an owner"
	if kept_by(sim).size() >= MAX_KEPT:
		return "you already keep %d animals" % MAX_KEPT
	return ""


static func adopt(sim: Simulation, pawn: Pawn, animal: Animal, rng: RandomNumberGenerator) -> String:
	animal.owner = "household"
	animal.home_lot = WorldState.HOME_LOT
	animal.fed_day = GameClock.get_day_number()
	animal.hungry_days = 0
	if animal.name == "":
		animal.name = _pick_name(sim.world, rng)
	lead(animal, pawn)
	return "%s takes in %s." % [_first(pawn), animal.title()]


static func buy_blocker(sim: Simulation, pawn: Pawn, kind: String) -> String:
	var price := int(def_of(kind).get("price", 0))
	if sim.household.get_pawn(pawn.id) == null:
		return "only your own folk buy for the household"
	if price <= 0:
		return "not for sale"
	if kept_by(sim).size() >= MAX_KEPT:
		return "you already keep %d animals" % MAX_KEPT
	if price > sim.coins_of(pawn):
		return "can't afford it"
	return ""


## Buys an animal at a hitching post: it appears beside the post, and follows the buyer.
static func buy(sim: Simulation, pawn: Pawn, post: PlacedObject, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var blocker := buy_blocker(sim, pawn, kind)
	if blocker != "":
		return { "ok": false, "message": "Can't buy it: %s" % blocker }
	var spot := _free_beside(sim.world, post.tile, pawn.tile)
	if spot == post.tile:
		return { "ok": false, "message": "There is no room for it here" }
	var price := int(def_of(kind).get("price", 0))
	sim.spend(pawn, price)
	var animal := spawn(sim.world, kind, spot, rng, "household", WorldState.HOME_LOT)
	lead(animal, pawn)
	return { "ok": true, "message": "%s bought %s the %s for %s." % [_first(pawn), animal.name if animal.name != "" else "a", str(def_of(kind).get("name", kind)).to_lower(), Economy.format(price)] }


## What the animals led by `pawn` and standing near them add to a gatherer's load: a share of it
## again (a donkey carries half as much again, an ox as much again), better with animal care.
static func pack_bonus(sim: Simulation, pawn: Pawn) -> float:
	var bonus := 0.0
	for animal in sim.world.animals:
		if animal.owner == "household" and animal.leader == pawn.id and _distance(animal.tile, pawn.tile) <= 6:
			bonus += float(animal.def().get("carry", 0.0))
	if bonus > 0.0:
		bonus *= 1.0 + Skills.effect(pawn, "husbandry", "carry")
	return minf(bonus, 1.5)


## "Biscuit (dog), Star (horse, led)" for the panel.
static func kept_text(sim: Simulation) -> String:
	var parts: Array[String] = []
	for animal in kept_by(sim):
		var note := str(animal.def().get("name", animal.kind)).to_lower()
		if animal.rider != 0:
			note += ", ridden"
		elif animal.leader != 0:
			note += ", following"
		if animal.hungry_days > 0:
			note += ", hungry"
		parts.append("%s (%s)" % [animal.display_name(), note])
	return ", ".join(parts)


# --- the passing days ------------------------------------------------------------------------

## Midnight: the household's animals eat from the stockpile, or go hungry and in time leave; the
## wilds are restocked a little.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var notices: Array[String] = []
	var today := GameClock.get_day_number()
	for animal: Animal in kept_by(sim).duplicate():
		var def := animal.def()
		if today - animal.fed_day < int(def.get("ration_days", 1)):
			continue
		var ate := ""
		for item_id in def.get("eats", []):
			if sim.household.stock_of(str(item_id)) > 0:
				ate = str(item_id)
				break
		if ate != "":
			sim.household.add_stock(ate, -1)
			animal.fed_day = today
			animal.hungry_days = 0
			continue
		animal.hungry_days += 1
		if animal.hungry_days == 2:
			notices.append("%s is hungry. Keep some %s in the stockpile." % [animal.display_name(), " or ".join(def.get("eats", ["food"]))])
		elif animal.hungry_days >= 4:
			var rider := sim.person(animal.rider) if animal.rider != 0 else null
			if rider != null:
				dismount(sim, rider)
			notices.append("%s has gone off to find something to eat." % animal.display_name())
			animal.owner = ""
			animal.leader = 0
			animal.home_lot = ""
			animal.hungry_days = 0
	_restock(sim.world, rng)
	return notices


## Where the wilds have thinned, a few come back from beyond the map's edge of sight.
static func _restock(world: WorldState, rng: RandomNumberGenerator) -> void:
	var counts := {}
	for animal in world.animals:
		if animal.is_wild():
			counts[animal.kind] = int(counts.get(animal.kind, 0)) + 1
	for kind in kinds("wild"):
		var wanted := int(def_of(kind).get("target", 0))
		if float(int(counts.get(kind, 0))) >= float(wanted) * RESTOCK_BELOW:
			continue
		for attempt in 40:
			var spot := _wild_spot(world, def_of(kind), rng)
			if spot != Vector2i(-1, -1):
				spawn(world, kind, spot, rng)
				break
