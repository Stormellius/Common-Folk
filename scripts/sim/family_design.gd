class_name FamilyDesign
extends RefCounted
## The family a player draws up on the new-game screen before the world is made: a family name and up to five
## people, each with a name, gender, age, looks and traits. A design is a plain dictionary
## { "family": String, "members": [ { given, gender, age, skin, hair, hair_style, hairdo, traits } ] } so the menu can
## edit it freely; HouseholdGenerator turns it into the household (its random needs and the rest are still rolled).

const MAX_MEMBERS := 5
const MIN_AGE := 5     # the youngest and the oldest a person can be made
const MAX_AGE := 78
## Ages a person can be made at, with what they are called in the editor.
const AGES: Array = [["Child", 8], ["Youth", 15], ["Adult", 25], ["Middle-aged", 42], ["Elder", 64]]
## Where each of the stages in AGES begins.
const AGE_STARTS: Array = [5, 13, 18, 40, 60]
const TRAIT_PICKS := 3   # besides the orientation
const MIN_PARENT_GAP := 16  # years a parent is older than their child
const PARTNER_AGE := 18     # the age from which two people can be together
const PARTNER_OPINION := 60.0
const KIN_OPINION := 50.0


## The place in AGES of the stage an age belongs to.
static func age_index(age: int) -> int:
	var found := 0
	for index in AGE_STARTS.size():
		if age >= int(AGE_STARTS[index]):
			found = index
	return found


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
		"outfit": pawn.outfit_choice,
		"garments": pawn.garments.duplicate(),
		"traits": traits,
		"parents": [],
		"partner": -1,
		"married": false,
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
	return tree_problem(design)


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
	_dress(pawn, member)


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


## What they wear: the outfit they keep to (or none) and the garments they chose, as far as their pictures have them.
static func _dress(pawn: Pawn, member: Dictionary) -> void:
	var outfit := str(member.get("outfit", ""))
	pawn.outfit_choice = outfit if outfit in Clothing.choices() else ""
	pawn.garments = {}
	var chosen: Variant = member.get("garments", {})
	if not (chosen is Dictionary):
		return
	for slot in Clothing.SLOTS:
		var wanted := str(chosen.get(slot, ""))
		if wanted == "":
			continue
		for def in Clothing.available(pawn, slot):
			if str(def["id"]) == wanted:
				pawn.garments[slot] = wanted


# --- the family tree -------------------------------------------------------------------------------------

static func _members(design: Dictionary) -> Array:
	return design.get("members", [])


static func _age(design: Dictionary, index: int) -> int:
	return int(_members(design)[index].get("age", 25))


static func _given(design: Dictionary, index: int) -> String:
	return str(_members(design)[index].get("given", "")).strip_edges()


static func _female(design: Dictionary, index: int) -> bool:
	return str(_members(design)[index].get("gender", "female")) != "male"


## Who the person's parents are, as indices into the members (up to two; anyone out of range or themselves is left out).
static func parents_of(design: Dictionary, index: int) -> Array[int]:
	var found: Array[int] = []
	var members := _members(design)
	if index < 0 or index >= members.size():
		return found
	for value in members[index].get("parents", []):
		var parent := int(value)
		if parent >= 0 and parent < members.size() and parent != index and parent not in found and found.size() < 2:
			found.append(parent)
	return found


## Who they are together with, or -1.
static func partner_of(design: Dictionary, index: int) -> int:
	var members := _members(design)
	if index < 0 or index >= members.size():
		return -1
	var partner := int(members[index].get("partner", -1))
	return partner if partner >= 0 and partner < members.size() and partner != index else -1


static func is_married(design: Dictionary, index: int) -> bool:
	return partner_of(design, index) >= 0 and bool(_members(design)[index].get("married", false))


static func children_of(design: Dictionary, index: int) -> Array[int]:
	var found: Array[int] = []
	for other in _members(design).size():
		if index in parents_of(design, other):
			found.append(other)
	return found


## Whether they have a parent in common.
static func siblings(design: Dictionary, a: int, b: int) -> bool:
	if a == b:
		return false
	var theirs := parents_of(design, b)
	for parent in parents_of(design, a):
		if parent in theirs:
			return true
	return false


## Family by blood, as in Relations.are_kin: parent and child, or brother and sister.
static func kin(design: Dictionary, a: int, b: int) -> bool:
	return a in parents_of(design, b) or b in parents_of(design, a) or siblings(design, a, b)


## Whether what one is drawn to takes in the other (the orientation traits; somebody with none is taken to be open).
static func attracted(design: Dictionary, a: int, b: int) -> bool:
	var members := _members(design)
	for trait_id in members[a].get("traits", []):
		match str(DataRegistry.get_def("traits", str(trait_id)).get("attracted_to", "")):
			"both":
				return true
			"none":
				return false
			"same":
				return str(members[a].get("gender", "")) == str(members[b].get("gender", ""))
			"opposite":
				return str(members[a].get("gender", "")) != str(members[b].get("gender", ""))
	return true


## What `of` is to `to` in the tree: "Mother", "Son", "Husband", "Partner", "Aunt", "Grandfather" and so on, or "".
static func relation(design: Dictionary, of: int, to: int) -> String:
	var members := _members(design)
	if of == to or of < 0 or to < 0 or of >= members.size() or to >= members.size():
		return ""
	var woman := _female(design, of)
	if partner_of(design, of) == to:
		return ("Wife" if woman else "Husband") if is_married(design, of) else "Partner"
	var their_parents := parents_of(design, to)
	if of in their_parents:
		return "Mother" if woman else "Father"
	if to in parents_of(design, of):
		return "Daughter" if woman else "Son"
	if siblings(design, of, to):
		return "Sister" if woman else "Brother"
	for parent in their_parents:
		if of in parents_of(design, parent):
			return "Grandmother" if woman else "Grandfather"
		if siblings(design, of, parent):
			return "Aunt" if woman else "Uncle"
	for parent in parents_of(design, of):
		if parent in their_parents:
			continue
		if to in parents_of(design, parent):
			return "Granddaughter" if woman else "Grandson"
		if siblings(design, parent, to):
			return "Niece" if woman else "Nephew"
	return ""


## Why `parent` cannot be `child`'s parent, or "".
static func parent_blocker(design: Dictionary, parent: int, child: int) -> String:
	var members := _members(design)
	if parent == child or parent < 0 or child < 0 or parent >= members.size() or child >= members.size():
		return "that is nobody"
	if _age(design, parent) - _age(design, child) < MIN_PARENT_GAP:
		return "%s is not %d years older than %s" % [_given(design, parent), MIN_PARENT_GAP, _given(design, child)]
	if partner_of(design, child) == parent or (kin(design, child, parent) and parent not in parents_of(design, child)):
		return "%s and %s are already family or together" % [_given(design, parent), _given(design, child)]
	var partner := partner_of(design, child)
	if partner >= 0 and parent in parents_of(design, partner):
		return "%s and %s would be brother and sister" % [_given(design, child), _given(design, partner)]
	return ""


## Why `a` and `b` cannot be together, or "".
static func partner_blocker(design: Dictionary, a: int, b: int) -> String:
	var members := _members(design)
	if a == b or a < 0 or b < 0 or a >= members.size() or b >= members.size():
		return "that is nobody"
	if _age(design, a) < PARTNER_AGE or _age(design, b) < PARTNER_AGE:
		return "only grown-ups can be together"
	if kin(design, a, b):
		return "they are family"
	if not attracted(design, a, b) or not attracted(design, b, a):
		return "they are not attracted to each other"
	return ""


## Puts `parent` in the person's first or second place for a parent (-1 for nobody). Returns false if it cannot be.
static func set_parent(design: Dictionary, child: int, slot: int, parent: int) -> bool:
	if parent >= 0 and parent_blocker(design, parent, child) != "" and parent not in parents_of(design, child):
		return false
	var kept := parents_of(design, child)
	while kept.size() <= slot:
		kept.append(-1)
	kept[slot] = parent
	var cleaned: Array = []
	for value in kept:
		if int(value) >= 0 and int(value) not in cleaned:
			cleaned.append(int(value))
	_members(design)[child]["parents"] = cleaned
	return true


## Makes `a` and `b` a couple (and nobody else's), wed or not. `b` of -1 leaves `a` alone. Returns false if they cannot be.
static func set_partner(design: Dictionary, a: int, b: int, married: bool = true) -> bool:
	if b >= 0 and partner_blocker(design, a, b) != "":
		return false
	for person in [a, b]:
		if person >= 0:
			var old := partner_of(design, person)
			if old >= 0:
				_members(design)[old]["partner"] = -1
				_members(design)[old]["married"] = false
			_members(design)[person]["partner"] = -1
			_members(design)[person]["married"] = false
	if b >= 0:
		_members(design)[a]["partner"] = b
		_members(design)[b]["partner"] = a
		_members(design)[a]["married"] = married
		_members(design)[b]["married"] = married
	return true


## Takes somebody out of the family, and out of everyone's parents and partners with them.
static func remove_member(design: Dictionary, index: int) -> void:
	var members := _members(design)
	if index < 0 or index >= members.size():
		return
	members.remove_at(index)
	for member: Dictionary in members:
		var moved: Array = []
		for value in member.get("parents", []):
			var parent := int(value)
			if parent != index:
				moved.append(parent - (1 if parent > index else 0))
		member["parents"] = moved
		var partner := int(member.get("partner", -1))
		if partner == index:
			member["partner"] = -1
			member["married"] = false
		elif partner > index:
			member["partner"] = partner - 1


## Drops whatever in the tree can no longer be (somebody grew younger, changed whom they like, and so on), keeping the rest.
static func mend(design: Dictionary) -> void:
	for index in _members(design).size():
		for parent in parents_of(design, index):
			if _age(design, parent) - _age(design, index) < MIN_PARENT_GAP:
				set_parent(design, index, parents_of(design, index).find(parent), -1)
		var partner := partner_of(design, index)
		if partner >= 0 and (partner_of(design, partner) != index or partner_blocker(design, index, partner) != ""):
			set_partner(design, index, -1)
	for index in _members(design).size():
		if partner_of(design, index) < 0:
			_members(design)[index]["married"] = false


## What is wrong with the tree, or "".
static func tree_problem(design: Dictionary) -> String:
	var members := _members(design)
	for index in members.size():
		var raw_parents: Array = members[index].get("parents", [])
		if raw_parents.size() > 2:
			return "%s has more than two parents." % _given(design, index)
		for parent in parents_of(design, index):
			var gap := _age(design, parent) - _age(design, index)
			if gap < MIN_PARENT_GAP:
				return "%s is too young to be %s's parent." % [_given(design, parent), _given(design, index)]
		var partner := partner_of(design, index)
		if partner >= 0:
			if partner_of(design, partner) != index:
				return "%s and %s do not agree they are together." % [_given(design, index), _given(design, partner)]
			var why := partner_blocker(design, index, partner)
			if why != "":
				return "%s and %s cannot be together: %s." % [_given(design, index), _given(design, partner), why]
	return ""


## Sets up a tree that fits the ages: the two grown-ups who suit each other and are nearest in age become a married couple, and everyone
## with someone old enough to be their parent becomes their child (of the youngest of those, and their partner).
static func suggest_tree(design: Dictionary) -> void:
	var members := _members(design)
	for member: Dictionary in members:
		member["parents"] = []
		member["partner"] = -1
		member["married"] = false
	var order: Array[int] = []
	for index in members.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return _age(design, a) > _age(design, b) or (_age(design, a) == _age(design, b) and a < b))
	var couple := Vector2i(-1, -1)  # the grown-ups who suit each other and are nearest in age
	var nearest := 99
	for first in order:
		for second in order:
			var gap := absi(_age(design, first) - _age(design, second))
			if first < second and gap <= 20 and gap < nearest and partner_blocker(design, first, second) == "":
				couple = Vector2i(first, second)
				nearest = gap
	if couple.x >= 0:
		set_partner(design, couple.x, couple.y, true)
	for position in order.size():
		var child: int = order[position]
		var best := -1
		for other in order.slice(0, position):  # the older ones; the last that is old enough is the youngest of them
			if parent_blocker(design, other, child) == "":
				best = other
		if best < 0:
			continue
		set_parent(design, child, 0, best)
		var partner := partner_of(design, best)
		if partner >= 0 and parent_blocker(design, partner, child) == "":
			set_parent(design, child, 1, partner)


## Gives the household's people the parents and partners the design says (`pawns` are in the order of the members).
static func link(pawns: Array[Pawn], design: Dictionary) -> void:
	for index in mini(pawns.size(), _members(design).size()):
		var pawn := pawns[index]
		for parent in parents_of(design, index):
			if parent < pawns.size():
				pawn.parents.append(pawns[parent].id)
				pawn.set_opinion(pawns[parent].id, KIN_OPINION)
				pawns[parent].set_opinion(pawn.id, KIN_OPINION)
		for other in siblings_among(design, index):
			if other < pawns.size():
				pawn.set_opinion(pawns[other].id, KIN_OPINION)
		var partner := partner_of(design, index)
		if partner >= 0 and partner < pawns.size() and partner_of(design, partner) == index:
			pawn.partner_id = pawns[partner].id
			pawn.partner_status = "partners"
			pawn.bond = "married" if is_married(design, index) else ""
			pawn.bond_since = GameClock.tick if pawn.bond != "" else 0
			pawn.partner_since = GameClock.tick
			pawn.romance[pawns[partner].id] = PARTNER_OPINION
			pawn.set_opinion(pawns[partner].id, PARTNER_OPINION)


static func siblings_among(design: Dictionary, index: int) -> Array[int]:
	var found: Array[int] = []
	for other in _members(design).size():
		if siblings(design, index, other):
			found.append(other)
	return found
