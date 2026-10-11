class_name NpcGenerator
extends RefCounted
## Fills the town's houses with families: two adults and, if the house has beds to spare, a
## child or two, up to "npc_count" people in all (data/worldgen.json). A family shares a
## surname and lives on one lot; nobody lives in the tavern, shop or clinic yet. The same world
## seed always gives the same people.

const FIRST_ID := 1000  # the town's people are numbered from here, apart from the household's


static func create(world: WorldState) -> Household:
	var town := Household.new(FIRST_ID)
	var config := DataRegistry.get_def("worldgen", "town")
	var remaining := int(config.get("npc_count", 12))
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 15485863 + 7
	var surnames: Array = DataRegistry.get_def("names", "family").get("list", ["Smith"]).duplicate()
	var homes: Array[Dictionary] = []  # { lot, family, spots, used_names, beds, size }
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
	# the town has the people it should.
	for home in homes:
		var take := mini(remaining, mini(2, int(home["beds"])))
		for i in take:
			_add(town, rng, world, home, rng.randi_range(19, 58))
		remaining -= take
	var progress := true
	while remaining > 0 and progress:
		progress = false
		for home in homes:
			if remaining > 0 and int(home["size"]) < mini(int(home["beds"]), (home["spots"] as Array).size()):
				_add(town, rng, world, home, rng.randi_range(3, 15))
				remaining -= 1
				progress = true
	_assign_jobs(world, town, rng)
	for home in homes:
		var family_members: Array[Pawn] = []
		for pawn in town.pawns:
			if pawn.home_lot == str(home["lot"]["id"]):
				family_members.append(pawn)
		Relations.make_family(family_members)
	return town


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
				if pawn.work_job == "" and pawn.age >= int(job.get("min_age", 16)):
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
