class_name Traits
extends RefCounted
## What a person's traits do beyond their need drains and thoughts (data/traits.json). A trait may carry
## "effects": { key: number }, which the systems ask for by key: Traits.mult for those that scale something
## (1.0 when no trait says anything), Traits.add for those that shift it (0.0 by default). Others the code asks for
## by name with Traits.has (polyamorous, jealous, shy, coward...). The keys in use:
##   rest_gain         how much more rest sleep gives (a heavy sleeper)
##   night_rest_seek   added to the rest level below which they go to bed at night (a night owl stays up later)
##   conception        how much likelier or unlikelier a pregnancy is when they are one of the pair
##   crop_yield        what they bring in from a field or herb bed
##   accident          how much likelier they are to be hurt at dangerous work
##   fire_fight_bonus  how big a fire they will take on
##   flee_radius_shift how much nearer (or further) a fire may be before they run from it
##   defense           how much they count toward the town's readiness against raids


static func has(pawn: Pawn, trait_id: String) -> bool:
	return pawn != null and trait_id in pawn.traits


static func mult(pawn: Pawn, key: String) -> float:
	var factor := 1.0
	if pawn == null:
		return factor
	for trait_id in pawn.traits:
		factor *= float(DataRegistry.get_def("traits", trait_id).get("effects", {}).get(key, 1.0))
	return factor


static func add(pawn: Pawn, key: String) -> float:
	var total := 0.0
	if pawn == null:
		return total
	for trait_id in pawn.traits:
		total += float(DataRegistry.get_def("traits", trait_id).get("effects", {}).get(key, 0.0))
	return total
