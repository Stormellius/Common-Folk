class_name Fire
extends RefCounted
## Fire (data/accidents.json). A hearth or cooking fire can throw a spark that catches something
## flammable beside it: a timber wall, a bed, planks, straw (objects and floors say how much they
## burn: "flammable"). A burning tile spreads to its flammable neighbours, burns for a while
## (longer when there is more to burn) and then what burned is gone. Stone does not burn. Fires
## are kept in WorldState.fires (tile -> { "since", "fuel" in minutes }), so they are saved.
##
## Folk run from a fire close to them, and a grown-up nearby beats it out on their own (each of them
## takes minutes off its fuel); anyone caught standing in the flames is burned, and burns kill.

static func config() -> Dictionary:
	return DataRegistry.get_def("accidents", "fire")


static func _number(key: String, fallback: float) -> float:
	return float(config().get(key, fallback))


## How much a tile burns, 0 (stone, bare ground) to 1 (straw, a haystack).
static func flammability(world: WorldState, tile: Vector2i) -> float:
	var amount := 0.0
	var there := world.object_at(tile)
	if there != null:
		amount = float(there.def().get("flammable", 0.0))
	var floor_id := world.floor_at(tile)
	if floor_id != "":
		amount = maxf(amount, float(DataRegistry.get_def("floors", floor_id).get("flammable", 0.0)))
	return amount


static func is_burning(world: WorldState, tile: Vector2i) -> bool:
	return world.fires.has(tile)


## The burning tile nearest to `tile` within `radius` (Chebyshev), or (-1, -1).
static func nearest(world: WorldState, tile: Vector2i, radius: int) -> Vector2i:
	if world.fires.is_empty():
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for burning in world.fires:
		var distance := float(maxi(absi(burning.x - tile.x), absi(burning.y - tile.y)))
		if distance <= radius and Vector2(burning - tile).length() < best_distance:
			best = burning
			best_distance = Vector2(burning - tile).length()
	return best


## How many tiles burn within `radius` (Chebyshev) of a tile.
static func count_near(world: WorldState, tile: Vector2i, radius: int) -> int:
	var count := 0
	for burning in world.fires:
		if maxi(absi(burning.x - tile.x), absi(burning.y - tile.y)) <= radius:
			count += 1
	return count


## Sets a tile alight if it can burn. Returns true if it caught.
static func ignite(world: WorldState, tile: Vector2i) -> bool:
	var amount := flammability(world, tile)
	if amount <= 0.0 or world.fires.has(tile):
		return false
	var fuel := int(_number("burn_minutes", 12.0) + amount * _number("burn_minutes_per_flammability", 26.0))
	world.fires[tile] = { "since": GameClock.tick, "fuel": fuel }
	return true


## Every minute: sparks from fires that people keep, fire spreading and dying down, and anyone
## standing in it burning. Returns notices for the player.
static func step(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var notices: Array[String] = []
	var world := sim.world
	var minute := GameClock.get_minute_of_day()
	if minute % 10 == 0:
		notices.append_array(_sparks(sim, rng))
	if world.fires.is_empty():
		return notices
	var spread_every := maxi(1, int(_number("spread_every_minutes", 2.0)))
	for tile in world.fires.keys():
		if not world.fires.has(tile):
			continue
		var burning: Dictionary = world.fires[tile]
		burning["fuel"] = int(burning["fuel"]) - 1
		if (GameClock.tick + tile.x + tile.y) % spread_every == 0:
			for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
				var next: Vector2i = tile + step
				if not world.fires.has(next) and rng.randf() < _number("spread_chance", 0.3) * flammability(world, next):
					ignite(world, next)
		if int(burning["fuel"]) <= 0:
			notices.append_array(_burn_out(sim, tile))
	_burn_people(sim, notices)
	return notices


## Things that are alight now and then: a hearth throws a spark onto something beside it.
static func _sparks(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var notices: Array[String] = []
	var chance := _number("spark_chance_per_day", 0.006) * 10.0 / float(GameClock.MINUTES_PER_DAY)
	for placed in sim.world.objects:
		if not bool(placed.def().get("fire_source", false)) or rng.randf() >= chance:
			continue
		var options: Array[Vector2i] = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tile: Vector2i = placed.tile + Vector2i(dx, dy)
				if tile != placed.tile and flammability(sim.world, tile) > 0.0 and not sim.world.fires.has(tile):
					options.append(tile)
		if not options.is_empty() and ignite(sim.world, options[rng.randi() % options.size()]):
			var notice := _start_notice(sim, placed.tile)
			if notice != "":
				notices.append(notice)
	return notices


static func _start_notice(sim: Simulation, tile: Vector2i) -> String:
	var town := sim.world.town_at(tile, 0)
	var home := sim.world.home_town()
	if town.is_empty() or home.is_empty() or town["id"] != home["id"]:
		return ""
	var lot := sim.world.lot_at(tile)
	var place := "at the %s" % str(lot.get("name", "house")).to_lower() if not lot.is_empty() else "in the street"
	return "Fire! Something has caught alight %s." % place


## A tile has burned out: what burned there is gone.
static func _burn_out(sim: Simulation, tile: Vector2i) -> Array[String]:
	var notices: Array[String] = []
	var world := sim.world
	world.fires.erase(tile)
	var there := world.object_at(tile)
	if there != null and float(there.def().get("flammable", 0.0)) > 0.0:
		var name := there.display_name().to_lower()
		sim.seize(there)
		if world.lot_at(tile).get("id", "") == WorldState.HOME_LOT:
			notices.append("The %s has burned down." % name)
	if world.floor_at(tile) != "" and float(DataRegistry.get_def("floors", world.floor_at(tile)).get("flammable", 0.0)) > 0.0:
		world.set_floor(tile, "")
	return notices


## Anyone caught on a burning tile is burned, and burns kill if they stay.
static func _burn_people(sim: Simulation, notices: Array[String]) -> void:
	for pawn in sim.people():
		if pawn.is_infant() and pawn.carried_by != 0:
			continue
		var standing := sim.world.fires.has(pawn.tile) or sim.world.fires.has(pawn.committed_tile())
		if not standing:
			pawn.fire_minutes = maxi(0, pawn.fire_minutes - 1)
			continue
		pawn.fire_minutes += 1
		if pawn.fire_minutes == int(_number("minutes_to_burn", 1.0)) and pawn.illness == "":
			pawn.illness = "burns"
			pawn.ill_since = GameClock.tick
			Mood.add_event(pawn, "burned", GameClock.tick)
			if sim.household.get_pawn(pawn.id) != null:
				notices.append("%s is burned!" % pawn.display_name)
		if pawn.fire_minutes >= int(_number("minutes_to_death", 4.0)) and not pawn.is_dying():
			Mortality.fall(sim, pawn, "burned to death")
