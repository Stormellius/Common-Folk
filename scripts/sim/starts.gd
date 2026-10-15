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


## The plots a new player can settle on: the usual one beside the square and every empty lot of the region's towns.
## Each: { "id", "name", "town", "rect", "note" }.
static func land_options(world: WorldState) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if world.lot.size != Vector2i.ZERO:
		var home := world.home_town()
		found.append({ "id": WorldState.HOME_LOT, "name": "Beside the square", "town": str(home.get("name", "")), "rect": world.lot, "note": "The plot kept for newcomers, a step from the market." })
	for entry in world.lots:
		if str(entry.get("kind", "")) == "vacant":
			var town := world.get_town(str(entry.get("town", "")))
			var offset := Vector2(entry["rect"].get_center() - Vector2i(town.get("center", entry["rect"].get_center())))
			var side := ("north" if offset.y < -4.0 else ("south" if offset.y > 4.0 else "")) + ("east" if offset.x > 4.0 else ("west" if offset.x < -4.0 else ""))
			var near := "%s of the square" % side if side != "" else "by the square"
			found.append({ "id": str(entry["id"]), "name": "Empty lot, %s" % near, "town": str(town.get("name", "")), "rect": entry["rect"], "note": "%d by %d tiles, %s in %s." % [entry["rect"].size.x, entry["rect"].size.y, near, str(town.get("name", "the town"))] })
	return found


## Makes `lot_id` (one of land_options) the player's lot: it and the usual plot trade places.
static func choose_lot(world: WorldState, lot_id: String) -> void:
	if lot_id == WorldState.HOME_LOT or lot_id == "":
		return
	var entry := world.get_lot(lot_id)
	if entry.is_empty() or str(entry.get("kind", "")) != "vacant":
		return
	var old_rect := world.lot
	var old_town := world.home_town()
	var new_town := world.get_town(str(entry.get("town", "")))
	world.lot = _grown(world, entry["rect"], str(entry.get("facing", "north")), str(entry["id"]))
	world.lot_rot = maxi(0, TownGenerator.FACING_NAMES.find(str(entry.get("facing", "north"))))
	entry["rect"] = old_rect
	entry["town"] = str(old_town.get("id", ""))
	entry["facing"] = TownGenerator.FACING_NAMES[2]
	if not new_town.is_empty():
		for town in world.towns:
			town["home"] = str(town["id"]) == str(new_town["id"])


## An empty lot is a little smaller than the plot kept for newcomers, so it takes in free grass beside and behind it,
## up to that size, never across the street or into another lot.
static func _grown(world: WorldState, rect: Rect2i, facing: String, own_id: String) -> Rect2i:
	var home_size := Vector2i(16, 13)
	var grown := rect
	var street := {"south": Vector2i(0, 1), "north": Vector2i(0, -1), "east": Vector2i(1, 0), "west": Vector2i(-1, 0)}.get(facing, Vector2i.ZERO) as Vector2i
	for step in 6:
		for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if direction == street or (grown.size.x >= home_size.x and direction.x != 0) or (grown.size.y >= home_size.y and direction.y != 0):
				continue
			var strip := Rect2i()
			if direction.x != 0:
				strip = Rect2i(grown.end.x if direction.x > 0 else grown.position.x - 1, grown.position.y, 1, grown.size.y)
			else:
				strip = Rect2i(grown.position.x, grown.end.y if direction.y > 0 else grown.position.y - 1, grown.size.x, 1)
			if _strip_free(world, strip, own_id):
				grown = grown.merge(strip)
	return grown


static func _strip_free(world: WorldState, strip: Rect2i, own_id: String) -> bool:
	for y in range(strip.position.y, strip.end.y):
		for x in range(strip.position.x, strip.end.x):
			if not world.in_bounds(x, y) or world.get_tile_id(x, y) not in ["grass", "dirt"] or world.object_at(Vector2i(x, y)) != null:
				return false
			for other in world.lots:
				if str(other["id"]) != own_id and (other["rect"] as Rect2i).grow(1).has_point(Vector2i(x, y)):
					return false
			if world.lot.has_point(Vector2i(x, y)):
				return false
	return true


## Sets up the household on the home lot as `start_id` says. Returns { "household", "realm" }.
static func begin(world: WorldState, start_id: String, design: Dictionary = {}) -> Dictionary:
	var def := DataRegistry.get_def("starts", start_id)
	if def.is_empty():
		def = DataRegistry.get_def("starts", DEFAULT)
		start_id = DEFAULT
	var house_id := str(def.get("house", ""))
	if house_id != "" and world.lot.size != Vector2i.ZERO:
		var template := _template(house_id)
		if not template.is_empty():
			var rot := world.lot_rot
			var grid := TownGenerator.oriented(template, false, rot)  # the door faces the street
			var width: int = grid[0].length() if not grid.is_empty() else 0
			var depth := grid.size()
			var at := Vector2i((world.lot.size.x - width) / 2, (world.lot.size.y - depth) / 2)
			match rot:
				2: at.y = 1
				0: at.y = world.lot.size.y - depth - 1
				1: at.x = 1
				3: at.x = world.lot.size.x - width - 1
			TownGenerator.stamp(world, template, grid, world.lot.position + at, world.lot, rot)
	var household := HouseholdGenerator.create(world, HouseholdGenerator.SIZE, design)
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
