class_name Ambitions
extends RefCounted
## Ambitions and wishes, in the manner of the Sims' aspirations.
##
## Every young person and grown-up has an AMBITION, a goal for a whole life (data/ambitions.json): to
## be a master of a craft, to be loved by the town, to marry and raise a family, to grow rich. It
## comes in steps, each a measurable goal ("reach Journeyman at a skill", "make five friends"), and
## each step reached lifts their mood; seeing the last one through fulfils the ambition, which lifts
## it for good, and some days later they dream of something new. Which ambition someone takes up leans
## on who they are: their traits, talents and family trade (the "weights" of each ambition).
##
## A person also has a couple of small WISHES at a time (data/wishes.json): play the lute, have a
## chat, say a prayer. They come and go, lapse after a day or two, and are granted by simply doing the
## thing, whether the player sent them to or they went on their own, which they do now and then
## when idle (see Simulation._pursue_wish). A wish granted is a small lift to mood.
##
## Both are measured from DEEDS: counters of what a person has done in their life, kept by event
## key ("used:lute", "hunted", "interaction:chat", "child"). Every event that gives a thought
## (Mood.add_event) counts as a deed, so a new kind of event is a new thing to want without
## new code. The rules (how many wishes, how often, how long to wait for a new dream) are
## in data/dreams.json.


static func rules() -> Dictionary:
	return DataRegistry.get_def("dreams", "dreams")


static func _number(key: String, fallback: float) -> float:
	return float(rules().get(key, fallback))


# --- deeds ------------------------------------------------------------------------------------

## Something happened to `pawn` (an event key: see Mood.add_event, plus a few of our own). Counts it,
## grants a wish that asks for it and moves the ambition on if that was the missing piece.
static func note(pawn: Pawn, key: String) -> void:
	pawn.deeds[key] = int(pawn.deeds.get(key, 0)) + 1
	if not pawn.wishes.is_empty():
		_grant(pawn, key)
	if pawn.ambition != "":
		advance(pawn)


## How many times a person has done any of `keys` (a key, or a list of them).
static func count(pawn: Pawn, keys: Variant) -> int:
	if keys is Array:
		var total := 0
		for key in keys:
			total += int(pawn.deeds.get(str(key), 0))
		return total
	return int(pawn.deeds.get(str(keys), 0))


# --- ambitions --------------------------------------------------------------------------------

## Whether someone is old enough to have an ambition.
static func may_dream(pawn: Pawn) -> bool:
	return not pawn.is_infant() and not pawn.is_dying() and Life.stage_id(pawn) in rules().get("ambition_stages", [])


static func ambition_def(pawn: Pawn) -> Dictionary:
	return DataRegistry.get_def("ambitions", pawn.ambition) if pawn.ambition != "" else {}


static func ambition_name(pawn: Pawn) -> String:
	return str(ambition_def(pawn).get("name", ""))


## How far one goal has got: x is what they have, y is what it takes. `sim` is only needed for
## goals that look at the world (coin).
static func measure(pawn: Pawn, goal: Dictionary, sim: Simulation = null) -> Vector2:
	if goal.has("deed"):
		return Vector2(count(pawn, goal["deed"]), float(goal.get("count", 1)))
	if goal.has("skill"):
		var level_wanted := float(goal.get("level", 1))
		var skill_id := str(goal["skill"])
		return Vector2(float(best_level(pawn) if skill_id == "any" else Skills.level(pawn, skill_id)), level_wanted)
	if goal.has("skills_known"):
		var known := 0
		for skill_id in pawn.skills:
			if Skills.level(pawn, str(skill_id)) >= int(goal.get("level", 1)):
				known += 1
		return Vector2(known, float(goal["skills_known"]))
	if goal.has("friends"):
		return Vector2(friends(pawn, float(rules().get("friend_opinion", 30.0))), float(goal["friends"]))
	if goal.has("close_friends"):
		return Vector2(friends(pawn, float(rules().get("close_friend_opinion", 60.0))), float(goal["close_friends"]))
	if goal.has("coins"):
		return Vector2(float(sim.coins_of(pawn)) if sim != null else 0.0, float(goal["coins"]))
	if goal.has("towns"):
		return Vector2(pawn.visited.size(), float(goal["towns"]))
	if goal.has("partner"):
		return Vector2(1.0 if pawn.partner_id != 0 else 0.0, 1.0)
	if goal.has("engaged"):
		return Vector2(1.0 if pawn.bond != "" else 0.0, 1.0)
	if goal.has("married"):
		return Vector2(1.0 if pawn.bond == "married" else 0.0, 1.0)
	return Vector2(0.0, 1.0)


static func best_level(pawn: Pawn) -> int:
	var top := 0
	for skill_id in pawn.skills:
		top = maxi(top, Skills.level(pawn, str(skill_id)))
	return top


## How many people think this much of `pawn` (their opinion of them at least `opinion`).
static func friends(pawn: Pawn, opinion: float) -> int:
	var found := 0
	for other_id in pawn.relations:
		if float(pawn.relations[other_id]) >= opinion:
			found += 1
	return found


static func goal_done(pawn: Pawn, goal: Dictionary, sim: Simulation = null) -> bool:
	var progress := measure(pawn, goal, sim)
	return progress.x >= progress.y


## The step they are on: { "text", "goal" }, or empty without an ambition.
static func current_step(pawn: Pawn) -> Dictionary:
	var steps: Array = ambition_def(pawn).get("steps", [])
	return steps[pawn.ambition_step] if pawn.ambition_step < steps.size() else {}


## Takes up the ambition that suits `pawn` (see pick). `announce` tells the player's household.
static func assign(sim: Simulation, pawn: Pawn, announce: bool = false) -> void:
	var id := pick(pawn, sim.world.world_seed * 31 + pawn.id * 977 + GameClock.tick / GameClock.MINUTES_PER_DAY)
	if id == "":
		return
	pawn.ambition = id
	pawn.ambition_step = 0
	if announce:
		_tell(pawn, "%s has a new ambition: %s. %s" % [pawn.given_name(), ambition_name(pawn), str(ambition_def(pawn).get("text", ""))])
	advance(pawn, sim)


## The id of an ambition for this person, or "". It leans on their traits, talents and trade (each
## ambition's "weights"), skips what they have fulfilled or already achieved, and is settled by `seed_value`
## alone, so the same person on the same day always picks the same.
static func pick(pawn: Pawn, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array[String] = []
	var weights: Array[float] = []
	var stage := Life.stage_id(pawn)
	for def in DataRegistry.get_list("ambitions"):
		var id := str(def["id"])
		var steps: Array = def.get("steps", [])
		if id in pawn.ambitions_done or steps.is_empty():
			continue
		var stages: Array = def.get("stages", [])
		if not stages.is_empty() and stage not in stages:
			continue
		if _has_any(pawn.traits, def.get("never_for", [])):
			continue
		if goal_done(pawn, (steps[-1] as Dictionary)["goal"]):
			continue  # nothing left to reach
		var weight := weight_for(pawn, def.get("weights", {}))
		if goal_done(pawn, (steps[0] as Dictionary)["goal"]):
			weight *= 0.3  # a head start is less of a dream
		if weight > 0.0:
			ids.append(id)
			weights.append(weight)
	return _weighted(rng, ids, weights)


## Moves the ambition along every step that is already reached; fulfils it after the last.
## `sim` lets goals about coin count; without it they wait for the next hour.
static func advance(pawn: Pawn, sim: Simulation = null) -> void:
	for guard in 8:
		if pawn.ambition == "":
			return
		var def := ambition_def(pawn)
		var steps: Array = def.get("steps", [])
		if def.is_empty() or pawn.ambition_step >= steps.size():
			_fulfil(pawn)
			return
		var step: Dictionary = steps[pawn.ambition_step]
		if not goal_done(pawn, step["goal"], sim):
			return
		pawn.ambition_step += 1
		if pawn.ambition_step >= steps.size():
			_fulfil(pawn)
			return
		_tell(pawn, "%s is closer to a dream (%s): %s." % [pawn.given_name(), ambition_name(pawn), str(step["text"]).to_lower()])
		Mood.add_event(pawn, "ambition_step", GameClock.tick, str(step["text"]).to_lower())


static func _fulfil(pawn: Pawn) -> void:
	var id := pawn.ambition
	var title := ambition_name(pawn)
	pawn.ambition = ""
	pawn.ambition_step = 0
	pawn.ambition_next = GameClock.tick + roundi(_number("pick_wait_days", 3.0) * GameClock.MINUTES_PER_DAY)
	if id != "" and id not in pawn.ambitions_done:
		pawn.ambitions_done.append(id)
	if title != "":
		_tell(pawn, "%s's ambition is fulfilled: %s!" % [pawn.given_name(), title])
		Mood.add_event(pawn, "ambition_fulfilled", GameClock.tick, title)


## A summary for the panel: the ambition and its step, and the wishes with the hours left.
static func summary(sim: Simulation, pawn: Pawn) -> Dictionary:
	var result := { "ambition": "", "text": "", "step": 0, "steps": 0, "step_text": "", "have": 0.0, "need": 1.0, "done": [], "wishes": [] }
	var def := ambition_def(pawn)
	if not def.is_empty():
		var steps: Array = def.get("steps", [])
		result["ambition"] = str(def["name"])
		result["text"] = str(def.get("text", ""))
		result["step"] = pawn.ambition_step + 1
		result["steps"] = steps.size()
		var step := current_step(pawn)
		if not step.is_empty():
			result["step_text"] = str(step["text"])
			var progress := measure(pawn, step["goal"], sim)
			result["have"] = minf(progress.x, progress.y)
			result["need"] = progress.y
	var done: Array[String] = []
	for id in pawn.ambitions_done:
		done.append(str(DataRegistry.get_def("ambitions", id).get("name", id)))
	result["done"] = done
	var wishes: Array[Dictionary] = []
	for wish in pawn.wishes:
		var wish_def := DataRegistry.get_def("wishes", str(wish["id"]))
		if not wish_def.is_empty():
			wishes.append({ "text": str(wish_def["text"]), "hours": maxi(1, ceili((int(wish["until"]) - GameClock.tick) / 60.0)), "big": bool(wish_def.get("big", false)) })
	result["wishes"] = wishes
	return result


# --- wishes -----------------------------------------------------------------------------------

## Called every minute for everyone: now and then notes where they are, and once an hour looks
## to their wishes and ambition. Spread out so that not everyone is looked at at once.
static func step(sim: Simulation, pawn: Pawn) -> void:
	var phase := (GameClock.tick + pawn.id) % 60
	if phase % 10 != 0:
		return
	_track_visits(sim, pawn)
	if phase != 0:
		return
	if not pawn.news.is_empty() and sim.household.get_pawn(pawn.id) == null:
		pawn.news.clear()  # only the player's folk are told
	if not pawn.wishes.is_empty():
		_expire(pawn)
	if pawn.ambition != "":
		advance(pawn, sim)
	_roll_wishes(sim, pawn)


## The towns a person has been to. The first place they are seen is home; after that each new one is a visit.
static func _track_visits(sim: Simulation, pawn: Pawn) -> void:
	var town := sim.world.town_at(pawn.tile, 2)
	if town.is_empty():
		return
	var town_id := str(town["id"])
	if town_id in pawn.visited:
		return
	var first := pawn.visited.is_empty()
	pawn.visited.append(town_id)
	if not first:
		note(pawn, "visit")


static func _expire(pawn: Pawn) -> void:
	for index in range(pawn.wishes.size() - 1, -1, -1):
		if int(pawn.wishes[index]["until"]) <= GameClock.tick:
			pawn.wishes.remove_at(index)


static func _roll_wishes(sim: Simulation, pawn: Pawn) -> void:
	var stage := Life.stage_id(pawn)
	if pawn.is_infant() or pawn.is_dying() or stage not in rules().get("wish_stages", []):
		return
	var limit := int(_number("max_wishes_child", 1.0)) if stage == "child" else int(_number("max_wishes", 2.0))
	if pawn.wishes.size() >= limit:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.world.world_seed * 131 + pawn.id * 7907 + GameClock.tick
	if rng.randf() > _number("wish_chance", 0.5):
		return
	var active: Array[String] = []
	for wish in pawn.wishes:
		active.append(str(wish["id"]))
	var cooldown := roundi(_number("wish_cooldown_hours", 20.0) * 60.0)
	var ids: Array[String] = []
	var weights: Array[float] = []
	for def in DataRegistry.get_list("wishes"):
		var id := str(def["id"])
		if id in active or GameClock.tick - int(pawn.wish_done.get(id, -cooldown)) < cooldown:
			continue
		if not wish_allowed(sim, pawn, def, stage):
			continue
		var weight := weight_for(pawn, def.get("weights", {}))
		if weight > 0.0:
			ids.append(id)
			weights.append(weight)
	var chosen := _weighted(rng, ids, weights)
	if chosen != "":
		var def := DataRegistry.get_def("wishes", chosen)
		pawn.wishes.append({ "id": chosen, "until": GameClock.tick + roundi(float(def.get("hours", 24.0)) * 60.0) })


## Whether `pawn` could want this wish now: old enough, the right sort of person, and the
## thing wished for is there to be had.
static func wish_allowed(sim: Simulation, pawn: Pawn, def: Dictionary, stage: String) -> bool:
	if stage not in def.get("stages", ["youth", "adult", "elder"]):
		return false
	if _has_any(pawn.traits, def.get("never_traits", [])):
		return false
	if def.has("partner") and bool(def["partner"]) != (pawn.partner_id != 0):
		return false
	if def.has("employed") and bool(def["employed"]) != (pawn.work_job != ""):
		return false
	if def.has("household") and bool(def["household"]) != (sim.household.get_pawn(pawn.id) != null):
		return false
	if def.has("object") and not sim.has_object_kind(str(def["object"])):
		return false
	if bool(def.get("animals", false)) and sim.world.animals.is_empty():
		return false
	if def.has("towns") and sim.world.towns.size() < int(def["towns"]):
		return false
	if def.has("skill_level"):
		var wanted := int(def["skill_level"])
		var skill_id := str(def.get("skill", "any"))
		if (best_level(pawn) if skill_id == "any" else Skills.level(pawn, skill_id)) < wanted:
			return false
	return true


## A wish that asks for this deed has been done.
static func _grant(pawn: Pawn, key: String) -> void:
	for index in range(pawn.wishes.size() - 1, -1, -1):
		var id := str(pawn.wishes[index]["id"])
		var def := DataRegistry.get_def("wishes", id)
		if def.is_empty():
			pawn.wishes.remove_at(index)
			continue
		var deeds: Variant = def.get("deed", "")
		if key != str(deeds) and not (deeds is Array and key in deeds):
			continue
		pawn.wishes.remove_at(index)
		pawn.wish_done[id] = GameClock.tick
		var wish_text := str(def["text"]).to_lower()
		_tell(pawn, "%s's wish came true: %s." % [pawn.given_name(), wish_text])
		Mood.add_event(pawn, "wish_granted_big" if bool(def.get("big", false)) else "wish_granted", GameClock.tick, wish_text)


# --- the day ----------------------------------------------------------------------------------

## At midnight: a happy day is noted, and whoever has no ambition and is ready for one takes one up.
static func new_day(sim: Simulation) -> void:
	var happy := _number("happy_mood", 70.0)
	for pawn in sim.people():
		if pawn.is_infant() or pawn.is_dying():
			continue
		if pawn.mood >= happy:
			note(pawn, "happy_day")
		if pawn.ambition == "" and may_dream(pawn) and GameClock.tick >= pawn.ambition_next:
			assign(sim, pawn, sim.household.get_pawn(pawn.id) != null)


## Gives everyone ready for one an ambition, quietly (a new game, or a save from before there were any).
static func start(sim: Simulation) -> void:
	for pawn in sim.people():
		if pawn.ambition == "" and pawn.ambitions_done.is_empty() and may_dream(pawn):
			assign(sim, pawn)


# --- helpers ----------------------------------------------------------------------------------

## How much a person's make-up changes the weight of something: each entry of `weights` that fits
## them multiplies it. Keys: "trait:pious", "talent:music" ("talent:any"), "skill:music" (level
## 2 or better), "trade:smithing" ("trade:any"), "stage:elder", "partner", "single".
static func weight_for(pawn: Pawn, weights: Dictionary) -> float:
	var factor := 1.0
	for key in weights:
		if _fits(pawn, str(key)):
			factor *= float(weights[key])
	return factor


static func _fits(pawn: Pawn, key: String) -> bool:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	match kind:
		"trait":
			return arg in pawn.traits
		"talent":
			return not pawn.talents.is_empty() if arg == "any" else arg in pawn.talents
		"skill":
			return Skills.level(pawn, arg) >= 2
		"trade":
			return pawn.family_trade != "" if arg == "any" else pawn.family_trade == arg
		"stage":
			return Life.stage_id(pawn) == arg
		"partner":
			return pawn.partner_id != 0
		"single":
			return pawn.partner_id == 0
	return false


static func _has_any(have: Array, wanted: Array) -> bool:
	for item in wanted:
		if str(item) in have:
			return true
	return false


static func _weighted(rng: RandomNumberGenerator, ids: Array[String], weights: Array[float]) -> String:
	var total := 0.0
	for weight in weights:
		total += weight
	if ids.is_empty() or total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for index in ids.size():
		roll -= weights[index]
		if roll <= 0.0:
			return ids[index]
	return ids[-1]


## Something for the player to be told about (kept on the person until the simulation passes it on).
static func _tell(pawn: Pawn, text: String) -> void:
	if pawn.news.size() < int(_number("news_limit", 6.0)):
		pawn.news.append(text)
