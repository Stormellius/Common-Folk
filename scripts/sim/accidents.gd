class_name Accidents
extends RefCounted
## Work accidents (an object's "accident" in data/objects.json): a falling tree at the woodlot, a
## rockfall at the quarry, a fall from the jetty. While someone works at such a thing there is a
## small chance each minute that it goes wrong: they are hurt (an injury that heals in time, with
## rest) and, now and then, killed outright; a fall into the water is mostly fatal. Death is not
## always the end: someone who falls can still be pleaded for (see Mortality).


## Rolls the risk of one minute of work at something. Returns a notice for the player, or "".
static func roll(sim: Simulation, pawn: Pawn, object_def: Dictionary, rng: RandomNumberGenerator) -> String:
	var risk: Variant = object_def.get("accident")
	if not risk is Dictionary or pawn.is_dying():
		return ""
	var chance := float(risk.get("chance_per_hour", 0.0)) / 60.0
	var skill_id := str(object_def.get("skill", ""))
	if skill_id != "":
		chance *= Skills.safety_multiplier(pawn, skill_id)  # the practised are hurt less often
	if rng.randf() >= chance:
		return ""
	var mine := sim.household.get_pawn(pawn.id) != null
	var name := pawn.display_name.get_slice(" ", 0)
	if rng.randf() < float(risk.get("death_share", 0.0)):
		Mortality.fall(sim, pawn, str(risk.get("death_cause", "died in an accident")))
		return "%s %s." % [pawn.display_name, str(risk.get("text", "had an accident"))] if not mine else ""
	if pawn.illness == "":
		pawn.illness = "injury"
		pawn.ill_since = GameClock.tick
	sim.order_stop(pawn)
	Mood.add_event(pawn, "hurt_at_work", GameClock.tick)
	return "%s %s and is hurt." % [name, str(risk.get("text", "had an accident"))] if mine else ""
