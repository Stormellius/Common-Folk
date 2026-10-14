class_name Starts
extends RefCounted
## The three ways of beginning (data/starts.json): bought land, an inherited house, or arriving
## with nothing. A start decides the title to the home lot, the purse, the household's class, a
## house already standing (or not) and what the camp holds.

const DEFAULT := "bought"


static func ids() -> Array[String]:
	var found: Array[String] = []
	for def in DataRegistry.get_list("starts"):
		found.append(str(def["id"]))
	return found


## Sets up the household on the home lot as `start_id` says. Returns { "household", "realm" }.
static func begin(world: WorldState, start_id: String) -> Dictionary:
	var def := DataRegistry.get_def("starts", start_id)
	if def.is_empty():
		def = DataRegistry.get_def("starts", DEFAULT)
		start_id = DEFAULT
	var house_id := str(def.get("house", ""))
	if house_id != "" and world.lot.size != Vector2i.ZERO:
		var template := _template(house_id)
		if not template.is_empty():
			var grid := TownGenerator.oriented(template, false, 2)  # the home lot is south of the road: door to the north
			var width: int = grid[0].length() if not grid.is_empty() else 0
			var origin := world.lot.position + Vector2i((world.lot.size.x - width) / 2, 1)
			TownGenerator.stamp(world, template, grid, origin, world.lot, 2)
	var household := HouseholdGenerator.create(world)
	household.coins = int(def.get("coins", Economy.start_coins()))
	var skill_rng := RandomNumberGenerator.new()
	skill_rng.seed = world.world_seed * 31 + 5
	for pawn in household.pawns:
		pawn.class_id = str(def.get("class", "peasant"))
		Skills.seed_pawn(pawn, skill_rng)
	for tool_id in def.get("tools", []):
		household.add_stock(str(tool_id), 1)
	var kept: Dictionary = def.get("stock", {})
	for item_id in kept:
		household.add_stock(str(item_id), int(kept[item_id]))
	var pet_rng := RandomNumberGenerator.new()
	pet_rng.seed = world.world_seed * 17 + 3
	for kind in def.get("pets", []):
		var spot := _pet_spot(world, household)
		if spot != Vector2i(-1, -1):
			Fauna.spawn(world, str(kind), spot, pet_rng, "household", WorldState.HOME_LOT)
	var camp: Variant = def.get("camp")
	CampGenerator.place(world, household, camp if camp is Array else null, house_id == "")
	world.titles[WorldState.HOME_LOT] = str(def.get("title", "freehold"))
	var realm := Realm.new()
	realm.start_id = start_id
	realm.choose_head(household)
	return { "household": household, "realm": realm }


## A free tile beside the household, for a pet to begin on.
static func _pet_spot(world: WorldState, household: Household) -> Vector2i:
	var around := household.pawns[0].tile if not household.pawns.is_empty() else world.lot.get_center()
	for radius in range(1, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := around + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and world.is_walkable(tile.x, tile.y) and world.object_at(tile) == null and world.animals_at(tile).is_empty():
					return tile
	return Vector2i(-1, -1)


static func _template(id: String) -> Dictionary:
	for def in DataRegistry.get_list("buildings"):
		if str(def["id"]) == id:
			return def
	return {}
