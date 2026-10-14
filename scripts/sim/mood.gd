class_name Mood
extends RefCounted
## Thoughts and mood. A thought is a line with a mood value, like "Hungry -6" or "Slept in a
## bed +5". Mood is 50 plus every thought that applies right now, kept between 0 and 100.
##
## data/thoughts.json holds two kinds:
##   state thoughts ("when": ...)  hold while something is true, like being hungry. Those that
##       share a "group" (starving, hungry, well fed) do not stack: the strongest one counts.
##   event thoughts ("on": ..., "hours": ...)  are given when something happens ("used:bed",
##       "interaction:intimacy", "death") and fade after their hours.
## Either kind can be limited with "only_for" / "never_for" (lists of trait ids), and traits
## scale a thought with "thought_multipliers" in data/traits.json. An event thought can be about
## someone ("Mourning {name}"): the name is kept with it, and the same thought about two people
## counts twice.

const BASE := 50.0
const LOW_BELOW := 20.0    # miserable: the person drags their feet
const UNHAPPY_BELOW := 40.0
const HAPPY_FROM := 70.0
const ALONE_DISTANCE := 6  # tiles; nobody else this close counts as alone


## { "value": float, "parts": Array of { "id", "text", "mood" } strongest first }.
## `others` is everyone who might be near (an Array of Pawn, or a Household).
static func evaluate(pawn: Pawn, others: Variant, now: int) -> Dictionary:
	var people: Array = others.pawns if others is Household else others
	var strongest := {}  # group -> part
	for def in DataRegistry.get_list("thoughts"):
		if not def.has("when") or not _applies(def, pawn):
			continue
		if _holds(def["when"], pawn, people):
			var part := _part(def, pawn)
			var group := str(def.get("group", def["id"]))
			if not strongest.has(group) or absf(part["mood"]) > absf(strongest[group]["mood"]):
				strongest[group] = part
	var parts: Array[Dictionary] = []
	for part in strongest.values():
		parts.append(part)
	for thought in pawn.thoughts:
		if int(thought["until"]) > now:
			var def := DataRegistry.get_def("thoughts", str(thought["id"]))
			if not def.is_empty():
				parts.append(_part(def, pawn, str(thought.get("about", ""))))
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a["mood"]) > absf(b["mood"]))
	var total := BASE
	for part in parts:
		total += float(part["mood"])
	return { "value": clampf(total, 0.0, 100.0), "parts": parts }


## Gives `pawn` every event thought that goes with `key` ("used:bed", "mourning"...), about
## `about` if it names someone. A thought they already have (about the same person) just has its
## time renewed.
static func add_event(pawn: Pawn, key: String, now: int, about: String = "") -> void:
	for def in DataRegistry.get_list("thoughts"):
		if str(def.get("on", "")) != key or not _applies(def, pawn):
			continue
		var until := now + int(float(def.get("hours", 1.0)) * 60.0)
		var found := false
		for thought in pawn.thoughts:
			if thought["id"] == def["id"] and str(thought.get("about", "")) == about:
				thought["until"] = until
				found = true
		if not found:
			var thought := { "id": str(def["id"]), "until": until }
			if about != "":
				thought["about"] = about
			pawn.thoughts.append(thought)


## Throws away thoughts that have faded.
static func prune(pawn: Pawn, now: int) -> void:
	for i in range(pawn.thoughts.size() - 1, -1, -1):
		if int(pawn.thoughts[i]["until"]) <= now:
			pawn.thoughts.remove_at(i)


## "miserable", "unhappy", "content" or "happy".
static func band_name(value: float) -> String:
	if value < LOW_BELOW:
		return "miserable"
	if value < UNHAPPY_BELOW:
		return "unhappy"
	if value >= HAPPY_FROM:
		return "happy"
	return "content"


static func _part(def: Dictionary, pawn: Pawn, about: String = "") -> Dictionary:
	var factor := 1.0
	for trait_id in pawn.traits:
		var multipliers: Dictionary = DataRegistry.get_def("traits", trait_id).get("thought_multipliers", {})
		factor *= float(multipliers.get(str(def["id"]), 1.0))
	var text := str(def.get("text", def["id"])).replace("{name}", about if about != "" else "someone")
	return { "id": str(def["id"]), "text": text, "mood": float(def.get("mood", 0.0)) * factor }


static func _applies(def: Dictionary, pawn: Pawn) -> bool:
	var only: Array = def.get("only_for", [])
	if not only.is_empty():
		var has_one := false
		for trait_id in only:
			has_one = has_one or str(trait_id) in pawn.traits
		if not has_one:
			return false
	for trait_id in def.get("never_for", []):
		if str(trait_id) in pawn.traits:
			return false
	return true


static func _holds(condition: Dictionary, pawn: Pawn, people: Array) -> bool:
	if condition.has("need"):
		var need_id := str(condition["need"])
		if not pawn.needs.has(need_id):
			return false  # that need is not in play
		var value := float(pawn.needs[need_id])
		if condition.has("below") and not value < float(condition["below"]):
			return false
		if condition.has("above") and not value > float(condition["above"]):
			return false
	if condition.has("pregnant") and bool(condition["pregnant"]) != Pregnancy.is_known(pawn):
		return false
	if condition.has("heavy") and bool(condition["heavy"]) != Pregnancy.is_heavy(pawn):
		return false
	if condition.has("in_labour") and bool(condition["in_labour"]) != Pregnancy.in_labour(pawn):
		return false
	if condition.has("ill") and bool(condition["ill"]) != (pawn.illness != ""):
		return false
	if condition.has("idle") and bool(condition["idle"]) != not pawn.is_busy():
		return false
	if condition.has("alone"):
		var alone := true
		for other in people:
			if other.id != pawn.id and absi(other.tile.x - pawn.tile.x) + absi(other.tile.y - pawn.tile.y) <= ALONE_DISTANCE:
				alone = false
		if alone != bool(condition["alone"]):
			return false
	return true
