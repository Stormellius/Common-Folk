class_name HouseholdGenerator
extends RefCounted
## Creates the starting household for a new world: a family of three standing near the
## player's lot (or the crossroads when there is none), each with an orientation trait and two
## other traits (see PersonFactory). The same world seed always gives the same people.

const SIZE := 3
const SEARCH_RADIUS := 12


## `design` (see FamilyDesign) is the family the player drew up, when they did: their names, looks and traits are used.
static func create(world: WorldState, size: int = SIZE, design: Dictionary = {}) -> Household:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 7919 + 17
	var household := Household.new()
	household.coins = Economy.start_coins()
	var family := PersonFactory.pick_text(rng, "names", "family", "list", ["Smith"])
	var members: Array = design.get("members", [])
	if not members.is_empty():
		family = str(design.get("family", family)).strip_edges()
		size = members.size()
	var used_names: Array[String] = []
	var index := 0
	for spot in _spawn_tiles(world, size):
		var pawn := PersonFactory.make(rng, family, used_names)
		if index < members.size():
			FamilyDesign.apply(pawn, members[index], family)
		index += 1
		pawn.home_lot = WorldState.HOME_LOT
		pawn.tile = spot
		pawn.step_to = spot
		household.add_pawn(pawn)
	Relations.make_family(household.pawns)
	return household


## Walkable tiles around the map center, nearest first, on a checkerboard so that the
## starting pawns do not stand shoulder to shoulder.
static func _spawn_tiles(world: WorldState, count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var center := Vector2i(world.width / 2, world.height / 2)
	if world.lot.size != Vector2i.ZERO:
		center = world.lot.get_center()  # the home lot, when there is one
	for radius in SEARCH_RADIUS + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := center + Vector2i(dx, dy)
				if (cell.x + cell.y) % 2 == 0 and world.is_walkable(cell.x, cell.y) and world.object_at(cell) == null:
					found.append(cell)
					if found.size() >= count:
						return found
	return found
