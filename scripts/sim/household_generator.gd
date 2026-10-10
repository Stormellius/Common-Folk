class_name HouseholdGenerator
extends RefCounted
## Creates the starting household for a new world: a family of three standing near the
## crossroads. The same world seed always gives the same people. Names and colors come
## from data/names.json and data/appearance.json, so mods can change them.

const SIZE := 3
const SEARCH_RADIUS := 12

# Hair styles in PawnArt: 0 short, 1 long, 2 shaved, 3 bun. Listing a style twice makes it likelier.
const HAIR_BY_GENDER := {
	"female": [1, 3, 1, 0],
	"male": [0, 2, 0, 3],
}


static func create(world: WorldState, size: int = SIZE) -> Household:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.world_seed * 7919 + 17
	var household := Household.new()
	var family := _pick_text(rng, "names", "family", "list", ["Smith"])
	var used_names: Array[String] = []
	for spot in _spawn_tiles(world, size):
		var pawn := Pawn.new()
		pawn.gender = "female" if rng.randi() % 2 == 0 else "male"
		var given := ""
		for attempt in 10:
			given = _pick_text(rng, "names", "given_" + pawn.gender, "list", ["Alex"])
			if given not in used_names:
				break
		used_names.append(given)
		pawn.display_name = "%s %s" % [given, family]
		var hair_styles: Array = HAIR_BY_GENDER[pawn.gender]
		pawn.look = {
			"skin": _pick_text(rng, "appearance", "skin", "colors", ["#e0ac80"]),
			"hair": _pick_text(rng, "appearance", "hair", "colors", ["#4a3220"]),
			"top": _pick_text(rng, "appearance", "top", "colors", ["#6a7a4a"]),
			"bottom": _pick_text(rng, "appearance", "bottom", "colors", ["#4a3d32"]),
			"hair_style": hair_styles[rng.randi() % hair_styles.size()],
		}
		pawn.tile = spot
		pawn.step_to = spot
		household.add_pawn(pawn)
	return household


## Walkable tiles around the map center, nearest first, on a checkerboard so that the
## starting pawns do not stand shoulder to shoulder.
static func _spawn_tiles(world: WorldState, count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var center := Vector2i(world.width / 2, world.height / 2)
	for radius in SEARCH_RADIUS + 1:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := center + Vector2i(dx, dy)
				if (cell.x + cell.y) % 2 == 0 and world.is_walkable(cell.x, cell.y):
					found.append(cell)
					if found.size() >= count:
						return found
	return found


static func _pick_text(rng: RandomNumberGenerator, kind: String, id: String, key: String, fallback: Array) -> String:
	var options: Array = DataRegistry.get_def(kind, id).get(key, [])
	if options.is_empty():
		options = fallback
	return str(options[rng.randi() % options.size()])
