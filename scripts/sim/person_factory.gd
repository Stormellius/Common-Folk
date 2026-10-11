class_name PersonFactory
extends RefCounted
## Makes one random person: name, looks, traits and starting needs, all from the data files
## (names.json, appearance.json, traits.json) and a random number generator, so the same seed
## always gives the same people. Used for the player's household and for the town.

const RANDOM_TRAITS := 2  # besides the orientation

# Hair styles in PawnArt: 0 short, 1 long, 2 shaved, 3 bun. Listing a style twice makes it likelier.
const HAIR_BY_GENDER := {
	"female": [1, 3, 1, 0],
	"male": [0, 2, 0, 3],
}


## A new person of the given family. `age` under 18 makes a child: no orientation trait yet,
## and only the random ones. `used_names` is the family's given names so far (kept different).
static func make(rng: RandomNumberGenerator, family: String, used_names: Array[String], age: int = 25) -> Pawn:
	var pawn := Pawn.new()
	pawn.age = age
	pawn.adult = age >= 18
	pawn.gender = "female" if rng.randi() % 2 == 0 else "male"
	var given := ""
	for attempt in 10:
		given = pick_text(rng, "names", "given_" + pawn.gender, "list", ["Alex"])
		if given not in used_names:
			break
	used_names.append(given)
	pawn.display_name = "%s %s" % [given, family]
	var hair_styles: Array = HAIR_BY_GENDER[pawn.gender]
	pawn.look = {
		"skin": pick_text(rng, "appearance", "skin", "colors", ["#e0ac80"]),
		"hair": pick_text(rng, "appearance", "hair", "colors", ["#4a3220"]),
		"top": pick_text(rng, "appearance", "top", "colors", ["#6a7a4a"]),
		"bottom": pick_text(rng, "appearance", "bottom", "colors", ["#4a3d32"]),
		"hair_style": hair_styles[rng.randi() % hair_styles.size()],
	}
	# Adults get an orientation (a trait in the "orientation" group) and RANDOM_TRAITS others, all different.
	var orientations: Array[String] = []
	var others: Array[String] = []
	for trait_def in DataRegistry.get_list("traits"):
		(orientations if str(trait_def.get("group", "")) == "orientation" else others).append(str(trait_def["id"]))
	if pawn.adult and not orientations.is_empty():
		pawn.traits.append(orientations[rng.randi() % orientations.size()])
	for i in mini(RANDOM_TRAITS, others.size()):
		var pick := others[rng.randi() % others.size()]
		others.erase(pick)
		pawn.traits.append(pick)
	for need_id in Needs.active_ids():
		pawn.needs[need_id] = snappedf(rng.randf_range(55.0, 95.0), 0.01)  # not everyone hungry at once
	return pawn


## A child who turns 18 gets an orientation, like every adult starts with.
static func give_orientation(pawn: Pawn, rng: RandomNumberGenerator) -> void:
	for trait_id in pawn.traits:
		if str(DataRegistry.get_def("traits", trait_id).get("group", "")) == "orientation":
			return
	var orientations: Array[String] = []
	for trait_def in DataRegistry.get_list("traits"):
		if str(trait_def.get("group", "")) == "orientation":
			orientations.append(str(trait_def["id"]))
	if not orientations.is_empty():
		pawn.traits.append(orientations[rng.randi() % orientations.size()])


static func pick_text(rng: RandomNumberGenerator, kind: String, id: String, key: String, fallback: Array) -> String:
	var options: Array = DataRegistry.get_def(kind, id).get(key, [])
	if options.is_empty():
		options = fallback
	return str(options[rng.randi() % options.size()])
