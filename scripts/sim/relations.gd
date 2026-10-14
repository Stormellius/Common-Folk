class_name Relations
extends RefCounted
## What people think of each other. Every person keeps an opinion of everyone they have met, from
## -100 to +100 (Pawn.relations, by the other person's id), changed by what they do together
## (data/interactions.json: "opinion"). Family starts out fond, and opinions drift back toward
## that starting point, or toward zero for strangers, a little every day.

const FAMILY_START := 40.0   # members of one household or family like each other
const FAMILY_FLOOR := 30.0   # and never drift below this
const DRIFT_PER_DAY := 0.5
const MIN := -100.0
const MAX := 100.0


## "Close friend", "Friend", "Friendly", "Acquaintance", "Unfriendly" or "Rival".
static func label(opinion: float) -> String:
	if opinion >= 60.0:
		return "Close friend"
	if opinion >= 30.0:
		return "Friend"
	if opinion >= 10.0:
		return "Friendly"
	if opinion > -10.0:
		return "Acquaintance"
	if opinion > -30.0:
		return "Unfriendly"
	return "Rival"


## Whether two people are family by blood: parent and child, or sisters and brothers. (Those who
## merely share a house, or were never given parents, are not.)
static func are_kin(a: Pawn, b: Pawn) -> bool:
	if a.id in b.parents or b.id in a.parents:
		return true
	for parent_id in a.parents:
		if parent_id != 0 and parent_id in b.parents:
			return true
	return false


## Makes everyone in the list fond of everyone else in it (a family).
static func make_family(members: Array[Pawn]) -> void:
	for a in members:
		for b in members:
			if a.id != b.id:
				a.set_opinion(b.id, FAMILY_START)


## One day passes: every opinion moves a little toward where it rests (family fondness for
## people who live together, zero for everyone else).
static func drift(everyone: Array[Pawn]) -> void:
	var by_id := {}
	for pawn in everyone:
		by_id[pawn.id] = pawn
	for pawn in everyone:
		for other_id in pawn.relations.keys():
			var other: Pawn = by_id.get(other_id)
			var rest := FAMILY_FLOOR if other != null and other.home_lot == pawn.home_lot else 0.0
			pawn.relations[other_id] = move_toward(float(pawn.relations[other_id]), rest, DRIFT_PER_DAY)
