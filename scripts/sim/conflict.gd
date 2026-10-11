class_name Conflict
extends RefCounted
## Raids and war (data/conflicts.json). You never fight: word arrives a few days ahead of a threat
## with its strength, and when the day comes the outcome is worked out off-screen from the town's
## defenses against that strength. What you can do is prepare:
##   supplies    food in the town (anything that fills hunger), up to a cap
##   readiness   able-bodied adults in the town
##   fund        coin given to the defense fund (half of it is used up each time)
##   standing    your reputation with the Crown and the town
##   watch posts built (objects with a "defense" value)
## A little luck (+- realm.json defense.luck) decides the close ones. Winning raises standing and
## lifts the town's mood; losing means plunder (a share of the purse), dead townspeople, perhaps a
## member of your household, and a darker mood. The state (the threat and the fund) lives in Realm.


static func defense_config() -> Dictionary:
	return Realm.config().get("defense", {})


## The town's defense now: { "total": float, "parts": { name: points } }.
static func defense(sim: Simulation) -> Dictionary:
	var config := defense_config()
	var food := 0
	var posts := 0.0
	for placed in sim.world.objects:
		var def := placed.def()
		if def.get("satisfies", {}).has("hunger"):
			food += 1
		posts += float(def.get("defense", 0.0))
	var able := 0
	for pawn in sim.town.pawns:
		if pawn.adult and pawn.illness == "":
			able += 1
	var parts := {
		"supplies": minf(float(food) * float(config.get("supplies_weight", 0.0)), float(config.get("supplies_cap", 99))),
		"readiness": float(able) * float(config.get("readiness_weight", 0.0)),
		"fund": float(sim.realm.fund) * float(config.get("fund_weight", 0.0)),
		"standing": sim.realm.reputation * float(config.get("reputation_weight", 0.0)),
		"watch": posts,
	}
	var total := 0.0
	for part in parts.values():
		total += float(part)
	return { "total": total, "parts": parts }


## Midnight: possibly news of a threat, or the threat arriving. Returns messages.
static func new_day(sim: Simulation, day: int) -> Array[String]:
	var realm := sim.realm
	var messages: Array[String] = []
	if not realm.threat.is_empty():
		if day >= int(realm.threat["due_day"]):
			messages.append_array(_resolve(sim, day))
		return messages
	if day < int(Realm.config().get("conflict_from_day", 10)):
		return messages
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.world.world_seed, day, 99])
	for def in DataRegistry.get_list("conflicts"):
		var roll := rng.randf()  # always drawn, so the day's outcome never depends on what came before
		if roll >= float(def.get("chance_per_day", 0.0)) or day - int(realm.last_conflict_days.get(str(def["id"]), -1000)) < int(def.get("cooldown_days", 0)):
			continue
		var range_: Array = def.get("strength", [10, 10])
		var strength := rng.randi_range(int(range_[0]), int(range_[1]))
		realm.threat = { "id": str(def["id"]), "due_day": day + int(def.get("warning_days", 2)), "strength": strength }
		messages.append(str(def.get("announce", "Trouble is coming.")).replace("{days}", str(int(def.get("warning_days", 2)))).replace("{strength}", str(strength)).replace("{defense}", str(roundi(float(defense(sim)["total"])))))
		break
	return messages


static func _resolve(sim: Simulation, day: int) -> Array[String]:
	var realm := sim.realm
	var def := DataRegistry.get_def("conflicts", str(realm.threat["id"]))
	var strength := int(realm.threat["strength"])
	realm.threat = {}
	realm.last_conflict_days[str(def.get("id", ""))] = day
	var messages: Array[String] = []
	if def.is_empty():
		return messages
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.world.world_seed, day, 101])
	var score := float(defense(sim)["total"]) + rng.randf_range(-1.0, 1.0) * float(defense_config().get("luck", 3))
	var kept := float(defense_config().get("fund_kept_percent", 50)) / 100.0
	realm.fund = int(realm.fund * kept)
	var rep_min := float(Realm.config().get("reputation_min", -100))
	var rep_max := float(Realm.config().get("reputation_max", 100))
	if score >= strength:
		realm.reputation = clampf(realm.reputation + float(def.get("reputation_win", 0)), rep_min, rep_max)
		for pawn in sim.people():
			Mood.add_event(pawn, "conflict:won", GameClock.tick)
		messages.append(str(def.get("victory", "The threat has passed.")))
		return messages
	realm.reputation = clampf(realm.reputation + float(def.get("reputation_loss", 0)), rep_min, rep_max)
	var lost := sim.household.coins * int(def.get("plunder_percent", 0)) / 100
	sim.household.coins -= lost
	var text := str(def.get("defeat", "The town was raided."))
	if lost > 0:
		text += " You lost %s." % Economy.format(lost)
	messages.append(text)
	var casualties_range: Array = def.get("casualties", [0, 0])
	var casualties := rng.randi_range(int(casualties_range[0]), int(casualties_range[1]))
	for i in casualties:
		if sim.town.pawns.is_empty():
			break
		var victim: Pawn = sim.town.pawns[rng.randi() % sim.town.pawns.size()]
		sim.die(victim, "was killed by raiders")
	for pawn in sim.household.pawns.duplicate():
		if rng.randf() < float(def.get("household_death_chance", 0.0)):
			sim.die(pawn, "was killed by raiders")
	for pawn in sim.people():
		Mood.add_event(pawn, "conflict:lost", GameClock.tick)
	return messages
