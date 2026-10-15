class_name NpcGenerator
extends RefCounted
## Fills the town's houses with families: two adults and, if the house has beds to spare, a
## child or two, up to "npc_count" people in all (data/worldgen.json). A family shares a
## surname and lives on one lot; nobody lives in the tavern, shop or clinic yet. The same world
## seed always gives the same people.

const FIRST_ID := 1000  # the town's people are numbered from here, apart from the household's


static func create(world: WorldState) -> Household:
	var town := Household.new(FIRST_ID)
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 15485863 + 7
	var surnames: Array = DataRegistry.get_def("names", "family").get("list", ["Smith"]).duplicate()
	var homes: Array[Dictionary] = []  # { lot, family, spots, used_names, beds, size }
	var wanted := {}  # settlement id -> how many people live there
	var settlements: Array[Dictionary] = world.towns
	if settlements.is_empty():  # a world with no settlements recorded: all the lots are one town
		settlements = [{ "id": "", "profile": "town" }]
	for settlement in settlements:
		wanted[str(settlement["id"])] = int(DataRegistry.get_def("worldgen", str(settlement.get("profile", "town"))).get("npc_count", 12))
	for lot in world.lots:
		if str(lot["kind"]) != "house":
			continue
		var family := "Smith"
		if not surnames.is_empty():
			family = str(surnames.pop_at(rng.randi() % surnames.size()))
		var spots := _free_tiles(world, lot["rect"])
		_shuffle(rng, spots)
		var used_names: Array[String] = []
		homes.append({ "lot": lot, "family": family, "spots": spots, "used_names": used_names, "beds": _bed_count(world, lot), "size": 0 })
	# First every house gets a couple (or one), then spare beds are filled with children until
	# each settlement has the people it should.
	for home in homes:
		var key := _settlement_of(wanted, home)
		var take := mini(int(wanted[key]), mini(2, int(home["beds"])))
		for i in take:
			_add(town, rng, world, home, rng.randi_range(19, 58))
		wanted[key] = int(wanted[key]) - take
	var progress := true
	while progress:
		progress = false
		for home in homes:
			var key := _settlement_of(wanted, home)
			if int(wanted[key]) > 0 and int(home["size"]) < mini(int(home["beds"]), (home["spots"] as Array).size()):
				_add(town, rng, world, home, rng.randi_range(3, 15))
				wanted[key] = int(wanted[key]) - 1
				progress = true
	for pawn in town.pawns:  # the grand houses hold gentry, everyone else starts as a peasant
		pawn.class_id = str(_template(str(world.get_lot(pawn.home_lot).get("template", ""))).get("class", "peasant"))
	for pawn in town.pawns:
		Skills.seed_pawn(pawn, rng)
	_assign_jobs(world, town, rng)
	for pawn in town.pawns:
		if pawn.work_job != "":
			Skills.seed_for_job(pawn, DataRegistry.get_def("jobs", pawn.work_job), rng)
	for home in homes:  # children are heirs to the family's best trade
		var grown: Array[Pawn] = []
		var young: Array[Pawn] = []
		for pawn in town.pawns:
			if pawn.home_lot == str(home["lot"]["id"]):
				(grown if pawn.adult else young).append(pawn)
		for child in young:
			Skills.inherit(child, grown, rng)
	for home in homes:  # a family with someone in trade ranks as burghers
		var in_trade := false
		for pawn in town.pawns:
			if pawn.home_lot == str(home["lot"]["id"]) and pawn.work_job != "" and pawn.class_id == "peasant":
				in_trade = true
		if in_trade:
			for pawn in town.pawns:
				if pawn.home_lot == str(home["lot"]["id"]):
					pawn.class_id = "burgher"
	for home in homes:
		var family_members: Array[Pawn] = []
		for pawn in town.pawns:
			if pawn.home_lot == str(home["lot"]["id"]):
				family_members.append(pawn)
		Relations.make_family(family_members)
	return town


## Moves a family into an empty house: people of the given ages, all with the name `family`, who
## take the house's class (peasants unless it is a grand house) and have skills like the town's
## people do. Returns who they are; they are added to `town`.
static func settle(world: WorldState, town: Household, rng: RandomNumberGenerator, lot: Dictionary, family: String, ages: Array[int]) -> Array[Pawn]:
	var spots := _free_tiles(world, lot["rect"])
	if spots.is_empty():  # a house with no floors (an old camp): anywhere open will do
		for y in range((lot["rect"] as Rect2i).position.y, (lot["rect"] as Rect2i).end.y):
			for x in range((lot["rect"] as Rect2i).position.x, (lot["rect"] as Rect2i).end.x):
				if world.is_walkable(x, y) and world.object_at(Vector2i(x, y)) == null:
					spots.append(Vector2i(x, y))
	var made: Array[Pawn] = []
	if spots.is_empty():
		return made
	_shuffle(rng, spots)
	var used_names: Array[String] = []
	var home := { "lot": lot, "family": family, "spots": spots, "used_names": used_names, "size": 0 }
	for age in ages:
		_add(town, rng, world, home, age)
		made.append(town.pawns.back())
	var class_id := str(_template(str(lot.get("template", ""))).get("class", "peasant"))
	var grown: Array[Pawn] = []
	for pawn in made:
		pawn.class_id = class_id
		Skills.seed_pawn(pawn, rng)
		if pawn.adult:
			grown.append(pawn)
	for pawn in made:
		if not pawn.adult:
			Skills.inherit(pawn, grown, rng)
	Relations.make_family(made)
	return made


## The settlement a home is in, as a key of `wanted` ("" when the world has no settlements).
static func _settlement_of(wanted: Dictionary, home: Dictionary) -> String:
	var key := str(home["lot"].get("town", ""))
	return key if wanted.has(key) else str(wanted.keys()[0])


static func _template(template_id: String) -> Dictionary:
	for def in DataRegistry.get_list("buildings"):
		if str(def["id"]) == template_id:
			return def
	return {}


## Gives some adults work at the town's businesses. Each business keeps its last position open,
## so there is always something for a newcomer to apply for.
static func _assign_jobs(world: WorldState, town: Household, rng: RandomNumberGenerator) -> void:
	for lot in world.lots:
		for job in DataRegistry.get_list("jobs"):
			if str(job.get("workplace", "")) != str(lot["kind"]):
				continue
			var filled := 0
			var unemployed: Array[Pawn] = []
			for pawn in town.pawns:
				if pawn.work_job == "" and pawn.age >= int(job.get("min_age", 16)) and pawn.class_id not in job.get("not_for", []) \
						and str(world.get_lot(pawn.home_lot).get("town", "")) == str(lot.get("town", "")):  # work where you live
					unemployed.append(pawn)
			while filled < int(job.get("positions", 1)) - 1 and not unemployed.is_empty():
				var worker: Pawn = unemployed.pop_at(rng.randi() % unemployed.size())
				worker.work_lot = str(lot["id"])
				worker.work_job = str(job["id"])
				filled += 1


## Adds one person to a home, on the next free spot indoors.
static func _add(town: Household, rng: RandomNumberGenerator, _world: WorldState, home: Dictionary, age: int) -> void:
	var spots: Array = home["spots"]
	var pawn := PersonFactory.make(rng, str(home["family"]), home["used_names"], age)
	pawn.home_lot = str(home["lot"]["id"])
	pawn.coins = Economy.npc_start_coins(rng) if pawn.adult else 0
	pawn.tile = spots[int(home["size"]) % spots.size()]
	pawn.step_to = pawn.tile
	home["size"] = int(home["size"]) + 1
	town.add_pawn(pawn)


static func _bed_count(world: WorldState, lot: Dictionary) -> int:
	var count := 0
	for placed in world.objects:
		if placed.def_id == "bed" and (lot["rect"] as Rect2i).has_point(placed.tile):
			count += 1
	return count


## Floor tiles inside a lot where nothing stands: indoors, since only buildings are floored.
static func _free_tiles(world: WorldState, rect: Rect2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			if world.floor_at(tile) != "" and world.is_walkable(x, y) and world.object_at(tile) == null:
				found.append(tile)
	return found


static func _shuffle(rng: RandomNumberGenerator, list: Array[Vector2i]) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var held := list[i]
		list[i] = list[j]
		list[j] = held
