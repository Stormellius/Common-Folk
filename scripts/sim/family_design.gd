class_name FamilyDesign
extends RefCounted
## The family a player draws up on the new-game screen before the world is made: a family name and up to five
## people, each with a name, gender, age, looks and traits. A design is a plain dictionary
## { "family": String, "members": [ { given, gender, age, skin, hair, hair_style, hairdo, traits } ] } so the menu can
## edit it freely; HouseholdGenerator turns it into the household (its random needs and the rest are still rolled).

const MAX_MEMBERS := 5
## Ages a person can be made at, with what they are called in the editor.
const AGES: Array = [["Child", 8], ["Youth", 15], ["Adult", 25], ["Middle-aged", 42], ["Elder", 64]]
const TRAIT_PICKS := 3   # besides the orientation


static func random_member(rng: RandomNumberGenerator, family: String, used: Array[String], age: int = 25) -> Dictionary:
	return from_pawn(PersonFactory.make(rng, family, used, age))


static func random_family(rng: RandomNumberGenerator, size: int = 3) -> Dictionary:
	var family := PersonFactory.pick_text(rng, "names", "family", "list", ["Smith"])
	var used: Array[String] = []
	var members: Array = []
	for i in size:
		members.append(random_member(rng, family, used))
	return { "family": family, "members": members }


static func from_pawn(pawn: Pawn) -> Dictionary:
	var traits: Array = []
	for trait_id in pawn.traits:
		traits.append(str(trait_id))
	return {
		"given": pawn.display_name.get_slice(" ", 0),
		"gender": pawn.gender,
		"age": pawn.age,
		"skin": str(pawn.look.get("skin", "#e0ac80")),
		"hair": str(pawn.look.get("hair", "#4a3220")),
		"hair_style": int(pawn.look.get("hair_style", 0)),
		"hairdo": str(pawn.look.get("hairdo", "")),
		"traits": traits,
	}


## What is wrong with a design (shown beside the Begin button), or "" when it will do.
static func problem(design: Dictionary) -> String:
	var members: Array = design.get("members", [])
	if members.is_empty():
		return "A family needs at least one person."
	if members.size() > MAX_MEMBERS:
		return "A family can have at most %d people." % MAX_MEMBERS
	if str(design.get("family", "")).strip_edges() == "":
		return "The family needs a name."
	var grown := false
	var seen := {}
	for member: Dictionary in members:
		var given := str(member.get("given", "")).strip_edges()
		if given == "":
			return "Everyone needs a name."
		if seen.has(given.to_lower()):
			return "Two people are both called %s." % given
		seen[given.to_lower()] = true
		grown = grown or int(member.get("age", 25)) >= 18
	if not grown:
		return "Somebody grown has to look after the children."
	return ""


## Writes a design's person onto a pawn (their needs and the rest are left as they are).
static func apply(pawn: Pawn, member: Dictionary, family: String) -> void:
	pawn.display_name = "%s %s" % [str(member.get("given", "Alex")).strip_edges(), family.strip_edges()]
	pawn.gender = "male" if str(member.get("gender", "female")) == "male" else "female"
	pawn.age = clampi(int(member.get("age", 25)), 1, 90)
	pawn.adult = pawn.age >= 18
	pawn.look = {
		"skin": str(member.get("skin", "#e0ac80")),
		"hair": str(member.get("hair", "#4a3220")),
		"top": str(pawn.look.get("top", "#6a7a4a")),
		"bottom": str(pawn.look.get("bottom", "#4a3d32")),
		"hair_style": int(member.get("hair_style", 0)),
		"hairdo": str(member.get("hairdo", "")),
	}
	var chosen: Array[String] = []
	for trait_id in member.get("traits", []):
		if DataRegistry.has_def("traits", str(trait_id)) and str(trait_id) not in chosen and not clashes(str(trait_id), chosen):
			var group := str(DataRegistry.get_def("traits", str(trait_id)).get("group", ""))
			if group == "orientation" and not pawn.adult:
				continue
			chosen.append(str(trait_id))
	pawn.traits = chosen
	if pawn.adult:
		PersonFactory.give_orientation(pawn, RandomNumberGenerator.new())


## Whether picking `trait_id` clashes with one already held (a trait lists what it "excludes").
static func clashes(trait_id: String, held: Array) -> bool:
	var excluded: Array = DataRegistry.get_def("traits", trait_id).get("excludes", [])
	for other in held:
		if str(other) in excluded or trait_id in DataRegistry.get_def("traits", str(other)).get("excludes", []):
			return true
	return false


## Traits that can be picked freely (everything but the orientation group).
static func free_traits() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for def in DataRegistry.get_list("traits"):
		if str(def.get("group", "")) != "orientation":
			found.append(def)
	return found


static func orientations() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for def in DataRegistry.get_list("traits"):
		if str(def.get("group", "")) == "orientation":
			found.append(def)
	return found
