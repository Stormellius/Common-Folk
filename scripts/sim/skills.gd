class_name Skills
extends RefCounted
## Skills that grow with practice, and the tools work needs.
##
## A skill (data/skills.json) is practised a little each minute its work goes on, and its xp turns
## into a level from 0 to 10 (data/learning.json). A person learns faster in youth, slower in old
## age, faster still at what they have a talent for, and twice as fast beside a master. Talents and
## a family trade pass from parent to child; a master can also give a lesson to anyone who knows
## less. What a level does is data: each skill lists its "effects" per level (more yield, fewer
## accidents, faster crafting, a better price...).
##
## Some work needs a tool in hand (an axe to chop, a sickle to reap; "tool" in data/objects.json,
## data/tools.json). The household's tools are kept in its stock like any other good. Whoever sets
## to work takes one from the stock, uses it (it wears) and puts it back when they stop. Anyone
## working a wage job at a business uses the employer's tool.


static func rules() -> Dictionary:
	return DataRegistry.get_def("learning", "learning")


static func skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in DataRegistry.get_list("skills"):
		ids.append(str(def["id"]))
	return ids


static func name_of(skill_id: String) -> String:
	return str(DataRegistry.get_def("skills", skill_id).get("name", skill_id))


static func max_level() -> int:
	return (rules().get("xp_to_level", [0]) as Array).size() - 1


# --- levels ---------------------------------------------------------------------------

static func xp(pawn: Pawn, skill_id: String) -> float:
	return float(pawn.skills.get(skill_id, 0.0))


static func level_of_xp(points: float) -> int:
	var table: Array = rules().get("xp_to_level", [0])
	var found := 0
	for index in table.size():
		if points >= float(table[index]):
			found = index
	return found


static func level(pawn: Pawn, skill_id: String) -> int:
	return level_of_xp(xp(pawn, skill_id))


## The xp that is the start of `level_number`.
static func xp_for_level(level_number: int) -> float:
	var table: Array = rules().get("xp_to_level", [0])
	return float(table[clampi(level_number, 0, table.size() - 1)])


## How far through the current level a skill is, 0 to 1 (1 at the top).
static func progress(pawn: Pawn, skill_id: String) -> float:
	var current := level(pawn, skill_id)
	if current >= max_level():
		return 1.0
	var from := xp_for_level(current)
	var to := xp_for_level(current + 1)
	return clampf((xp(pawn, skill_id) - from) / maxf(1.0, to - from), 0.0, 1.0)


## "Novice", "Journeyman", "Master"... for a level.
static func rank_name(level_number: int) -> String:
	var found := ""
	for rank in rules().get("ranks", []):
		if level_number >= int(rank.get("from", 0)):
			found = str(rank.get("name", ""))
	return found


## What a skill does at the person's level for one kind of effect (0 when it has none): the
## skill's per-level number times their level.
static func effect(pawn: Pawn, skill_id: String, key: String) -> float:
	var per_level := float(DataRegistry.get_def("skills", skill_id).get("effects", {}).get(key, 0.0))
	return per_level * float(level(pawn, skill_id))


## The skills a person has begun, best first: [{ "id", "level", "xp" }].
static func known(pawn: Pawn) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for skill_id in pawn.skills:
		if xp(pawn, str(skill_id)) > 0.0 and not DataRegistry.get_def("skills", str(skill_id)).is_empty():
			found.append({ "id": str(skill_id), "level": level(pawn, str(skill_id)), "xp": xp(pawn, str(skill_id)) })
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["xp"]) > float(b["xp"]))
	return found


## The skill a person is best at ("" if none).
static func best(pawn: Pawn) -> String:
	var all := known(pawn)
	return str(all[0]["id"]) if not all.is_empty() else ""


# --- practice ---------------------------------------------------------------------------

## A person at work for `minutes` practises `skill_id`: xp at the skill's rate, scaled by their
## stage of life, a talent for it and a master close by. A level gained is reported.
static func practice(sim: Simulation, pawn: Pawn, skill_id: String, minutes: float = 1.0) -> void:
	var def := DataRegistry.get_def("skills", skill_id)
	if def.is_empty():
		return
	var rate := float(def.get("gain", 0.1)) * Life.learn_rate(pawn)
	if rate <= 0.0:
		return
	if skill_id in pawn.talents:
		rate *= 1.0 + float(rules().get("talent_bonus", 0.5))
	rate *= _mentoring(sim, pawn, skill_id)
	_add_xp(sim, pawn, skill_id, rate * minutes)


## Gives xp directly (a lesson, an inherited trade).
static func grant(sim: Simulation, pawn: Pawn, skill_id: String, points: float) -> void:
	if DataRegistry.get_def("skills", skill_id).is_empty() or points <= 0.0:
		return
	_add_xp(sim, pawn, skill_id, points)


static func _add_xp(sim: Simulation, pawn: Pawn, skill_id: String, points: float) -> void:
	var before := level(pawn, skill_id)
	var ceiling := xp_for_level(max_level())
	pawn.skills[skill_id] = minf(ceiling, xp(pawn, skill_id) + points)
	var after := level(pawn, skill_id)
	if after > before and sim != null:
		Mood.add_event(pawn, "skill_up", GameClock.tick)
		if sim.household.get_pawn(pawn.id) != null:
			sim.health_notice.emit("%s's %s is now %d (%s)." % [pawn.display_name.get_slice(" ", 0), name_of(skill_id).to_lower(), after, rank_name(after).to_lower()])


## 1 normally; more when a master of this skill is working close by. Looked up every ten minutes
## and remembered in between.
static func _mentoring(sim: Simulation, pawn: Pawn, skill_id: String) -> float:
	if sim == null:
		return 1.0
	if (GameClock.tick + pawn.id) % 10 != 0:
		return pawn.mentor_gain
	pawn.mentor_gain = 1.0
	var rule := rules()
	var gap := int(rule.get("master_gap", 3))
	var radius := int(rule.get("master_radius", 7))
	var mine := level(pawn, skill_id)
	if mine >= max_level() - 1:
		return 1.0
	for other in sim.people():
		if other.id == pawn.id or other.age < 16 or other.job_kind not in ["work", "use"] or other.job_stage != "using":
			continue
		if absi(other.tile.x - pawn.tile.x) > radius or absi(other.tile.y - pawn.tile.y) > radius:
			continue
		if level(other, skill_id) >= mine + gap:
			pawn.mentor_gain = 1.0 + float(rule.get("master_bonus", 1.0))
			break
	return pawn.mentor_gain


# --- who is good at what ---------------------------------------------------------------

## The skill a job trains: its own "skill", else its station's.
static func job_skill(job: Dictionary) -> String:
	if job.has("skill"):
		return str(job["skill"])
	return str(DataRegistry.get_def("objects", str(job.get("station", ""))).get("skill", ""))


## Starting skills for someone made at the start of a game: a little of what their class does,
## plus (for a grown person with a job) the job's skill, deeper the older they are. Children know
## nothing yet, though they may have a talent.
static func seed_pawn(pawn: Pawn, rng: RandomNumberGenerator) -> void:
	var class_skills: Array = DataRegistry.get_def("classes", pawn.class_id).get("skills", [])
	if pawn.talents.is_empty() and not class_skills.is_empty() and rng.randf() < float(rules().get("talent_at_random", 0.3)):
		pawn.talents.append(str(class_skills[rng.randi() % class_skills.size()]))
	if pawn.age < 14 or class_skills.is_empty():
		return
	var years := float(pawn.age - 14)
	var picks := 1 + rng.randi() % 2
	for i in picks:
		var skill_id := str(class_skills[rng.randi() % class_skills.size()])
		var reach := mini(max_level() - 3, 1 + roundi(years / 9.0)) + (1 if skill_id in pawn.talents else 0)
		pawn.skills[skill_id] = maxf(xp(pawn, skill_id), xp_for_level(clampi(rng.randi_range(1, maxi(1, reach)), 0, max_level())))


## A grown person's job trains its skill to a level that fits their years at it.
static func seed_for_job(pawn: Pawn, job: Dictionary, rng: RandomNumberGenerator) -> void:
	var skill_id := job_skill(job)
	if skill_id == "":
		return
	var reach := mini(max_level() - 2, 1 + roundi(float(pawn.age - 16) / 6.0)) + (1 if skill_id in pawn.talents else 0)
	var wanted := xp_for_level(clampi(rng.randi_range(maxi(1, reach - 2), maxi(1, reach)), 0, max_level()))
	pawn.skills[skill_id] = maxf(xp(pawn, skill_id), wanted + rng.randf() * 10.0)


## A newborn's talents and family trade, from the parents.
static func inherit(child: Pawn, parents: Array[Pawn], rng: RandomNumberGenerator) -> void:
	var chance := float(rules().get("talent_from_parent", 0.4))
	for parent in parents:
		for talent in parent.talents:
			if talent not in child.talents and child.talents.size() < 2 and rng.randf() < chance:
				child.talents.append(talent)
	var trade := ""
	var best_xp := 0.0
	for parent in parents:
		var their_best := best(parent)
		if their_best != "" and xp(parent, their_best) > best_xp:
			trade = their_best
			best_xp = xp(parent, their_best)
	child.family_trade = trade


## A child old enough to be taken on at the family's trade (the youth stage begins) learns the
## basics of it: a share of what their best parent knows, or a start if the parents are gone.
static func take_up_trade(sim: Simulation, pawn: Pawn) -> void:
	var trade := pawn.family_trade
	if trade == "":
		return
	var points := float(rules().get("family_default_xp", 70))
	var parent_xp := 0.0
	for parent_id in pawn.parents:
		var parent := sim.person(parent_id)
		if parent != null:
			parent_xp = maxf(parent_xp, xp(parent, trade))
	if parent_xp > 0.0:
		points = parent_xp * float(rules().get("family_share", 0.3))
	if points > xp(pawn, trade):
		pawn.skills[trade] = points
		if sim.household.get_pawn(pawn.id) != null:
			sim.health_notice.emit("%s has been learning the family trade: %s." % [pawn.display_name.get_slice(" ", 0), name_of(trade).to_lower()])


## Midnight: grown townsfolk with no work take a vacancy in their own town, a few a night. The
## children of a trade tend to follow it, and each business keeps its last place open for
## whoever comes asking.
static func find_work(sim: Simulation, rng: RandomNumberGenerator, limit: int = 3) -> void:
	var staffed := {}
	for pawn in sim.people():
		if pawn.work_job != "":
			var key := "%s|%s" % [pawn.work_lot, pawn.work_job]
			staffed[key] = int(staffed.get(key, 0)) + 1
	var hired := 0
	var seekers: Array[Pawn] = sim.town.pawns.duplicate()
	for index in range(seekers.size() - 1, 0, -1):  # in a different order each night
		var swap := rng.randi() % (index + 1)
		var held := seekers[index]
		seekers[index] = seekers[swap]
		seekers[swap] = held
	for pawn in seekers:
		if hired >= limit:
			return
		if pawn.work_job != "" or pawn.age < 16 or pawn.age > 55 or pawn.is_dying() or pawn.is_infant() or pawn.carried_by != 0 or pawn.is_pregnant():
			continue
		var town_id := str(sim.world.get_lot(pawn.home_lot).get("town", ""))
		var chosen := {}
		var chosen_score := -1.0
		for lot in sim.world.lots:
			if str(lot.get("town", "")) != town_id:
				continue
			for job in DataRegistry.get_list("jobs"):
				if str(job.get("workplace", "")) != str(lot["kind"]):
					continue
				if int(job.get("positions", 1)) - int(staffed.get("%s|%s" % [lot["id"], job["id"]], 0)) < 2:
					continue  # keep the last place open
				if sim.hire_blocker(pawn, str(lot["id"]), str(job["id"])) != "":
					continue
				var skill_id := job_skill(job)
				var score := rng.randf() + float(level(pawn, skill_id)) + (3.0 if skill_id != "" and skill_id == pawn.family_trade else 0.0) + (2.0 if skill_id in pawn.talents else 0.0)
				if score > chosen_score:
					chosen_score = score
					chosen = { "lot": str(lot["id"]), "job": str(job["id"]) }
		if not chosen.is_empty():
			sim.hire(pawn, chosen["lot"], chosen["job"])
			staffed["%s|%s" % [chosen["lot"], chosen["job"]]] = int(staffed.get("%s|%s" % [chosen["lot"], chosen["job"]], 0)) + 1
			hired += 1


# --- lessons ----------------------------------------------------------------------------

## The skill `teacher` could pass on to `student` (their best that the student is behind in by
## at least a level), or "".
static func lesson_skill(teacher: Pawn, student: Pawn) -> String:
	if teacher.age < 14 or student.age < 8:
		return ""
	var chosen := ""
	var widest := 0
	for entry in known(teacher):
		var skill_id := str(entry["id"])
		if int(entry["level"]) < int(rules().get("lesson_min_level", 2)):
			continue
		var gap := int(entry["level"]) - level(student, skill_id)
		if gap >= 1 and (gap > widest or (gap == widest and skill_id in student.talents)):
			chosen = skill_id
			widest = gap
	return chosen


## Why `a` and `b` cannot have a lesson now, or "".
static func lesson_blocker(a: Pawn, b: Pawn) -> String:
	if lesson_skill(a, b) == "" and lesson_skill(b, a) == "":
		return "neither has anything to teach the other"
	return ""


## `a` and `b` have a lesson: the better of them teaches the other. Returns a notice.
static func give_lesson(sim: Simulation, a: Pawn, b: Pawn) -> String:
	var teacher := a
	var student := b
	var skill_id := lesson_skill(a, b)
	var other_skill := lesson_skill(b, a)
	if skill_id == "" or (other_skill != "" and level(b, other_skill) - level(a, other_skill) > level(a, skill_id) - level(b, skill_id)):
		teacher = b
		student = a
		skill_id = other_skill
	if skill_id == "":
		return ""
	grant(sim, student, skill_id, float(rules().get("lesson_xp", 40)) * maxf(0.5, Life.learn_rate(student)))
	Mood.add_event(student, "learned", GameClock.tick)
	Mood.add_event(teacher, "taught", GameClock.tick)
	return "%s taught %s some %s." % [teacher.display_name.get_slice(" ", 0), student.display_name.get_slice(" ", 0), name_of(skill_id).to_lower()]


# --- what a skill does ----------------------------------------------------------------

## How many of a resource a gatherer brings in: the base amount, raised by their skill. The
## fraction is settled by chance.
static func yield_amount(pawn: Pawn, skill_id: String, base: int, rng: RandomNumberGenerator) -> int:
	var exact := float(base) * (1.0 + effect(pawn, skill_id, "yield"))
	var whole := floori(exact)
	return whole + (1 if rng.randf() < exact - float(whole) else 0)


## The chance of an accident, scaled down by skill (never below a third).
static func safety_multiplier(pawn: Pawn, skill_id: String) -> float:
	return maxf(0.33, 1.0 - effect(pawn, skill_id, "safety"))


## How much a skill adds to what an object gives when used (1 for none).
static func boost(pawn: Pawn, skill_id: String) -> float:
	return 1.0 + effect(pawn, skill_id, "boost")


## The panel line for one skill: "Woodcutting 3 Apprentice".
static func describe(pawn: Pawn, skill_id: String) -> String:
	var lvl := level(pawn, skill_id)
	return "%s %d, %s" % [name_of(skill_id), lvl, rank_name(lvl).to_lower()]


# --- tools ------------------------------------------------------------------------------

static func tool_name(tool_id: String) -> String:
	return str(DataRegistry.get_def("tools", tool_id).get("name", tool_id))


static func tool_price(tool_id: String) -> int:
	return roundi(float(DataRegistry.get_def("tools", tool_id).get("price", 10)) * float(rules().get("tool_buy_markup", 1.0)))


static func is_tool_id(item_id: String) -> bool:
	return not DataRegistry.get_def("tools", item_id).is_empty()


static func tool_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in DataRegistry.get_list("tools"):
		ids.append(str(def["id"]))
	return ids


## "an axe" / "a sickle" for a message.
static func tool_phrase(tool_id: String) -> String:
	var tool_label := tool_name(tool_id).to_lower()
	return ("an " if tool_label.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + tool_label


## The tool a thing needs ("" for none).
static func tool_needed(object_def: Dictionary) -> String:
	return str(object_def.get("tool", ""))


## Why `pawn` cannot work at something that wants a tool, or "". Only the player's household has
## to bring tools; the town's people have their own.
static func tool_blocker(sim: Simulation, pawn: Pawn, object_def: Dictionary) -> String:
	var tool_id := tool_needed(object_def)
	if tool_id == "" or sim.household.get_pawn(pawn.id) == null:
		return ""
	if pawn.tool == tool_id or sim.household.stock_of(tool_id) > 0:
		return ""
	if _someone_holds(sim, tool_id):
		return "every %s is in use" % tool_name(tool_id).to_lower()
	return "needs %s (a shop sells them, or make one)" % tool_phrase(tool_id)


static func _someone_holds(sim: Simulation, tool_id: String) -> bool:
	for pawn in sim.household.pawns:
		if pawn.tool == tool_id and not pawn.tool_lent:
			return true
	return false


## Takes the tool for the job in hand: from the household's stock, or lent by the employer for a
## wage job. False if there is none to take.
static func equip(sim: Simulation, pawn: Pawn, tool_id: String, lent: bool = false) -> bool:
	if tool_id == "":
		return true
	if pawn.tool == tool_id:
		return true
	unequip(sim, pawn)
	if lent or sim.household.get_pawn(pawn.id) == null:
		pawn.tool = tool_id
		pawn.tool_lent = true
		return true
	if sim.household.stock_of(tool_id) <= 0:
		return false
	sim.household.add_stock(tool_id, -1)
	pawn.tool = tool_id
	pawn.tool_lent = false
	return true


## Puts the tool in hand back (on the household's stock if it was theirs).
static func unequip(sim: Simulation, pawn: Pawn) -> void:
	if pawn.tool == "":
		return
	if not pawn.tool_lent and sim.household.get_pawn(pawn.id) != null:
		sim.household.add_stock(pawn.tool, 1)
	pawn.tool = ""
	pawn.tool_lent = false


## One minute of use wears the tool a little. Returns a notice when it breaks (the tool is gone).
static func wear(sim: Simulation, pawn: Pawn) -> String:
	if pawn.tool == "" or pawn.tool_lent:
		return ""
	var durability := float(DataRegistry.get_def("tools", pawn.tool).get("durability", 3000))
	var worn: float = float(sim.household.tool_wear.get(pawn.tool, 0.0)) + 1.0
	if worn < durability:
		sim.household.tool_wear[pawn.tool] = worn
		return ""
	sim.household.tool_wear[pawn.tool] = worn - durability
	var broken := pawn.tool
	pawn.tool = ""
	pawn.tool_lent = false
	return "%s's %s broke." % [pawn.display_name.get_slice(" ", 0), tool_name(broken).to_lower()]


# --- crafting -----------------------------------------------------------------------------

static func recipes_for(station_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for recipe in DataRegistry.get_list("recipes"):
		if str(recipe.get("station", "")) == station_id:
			found.append(recipe)
	return found


## What one making of a recipe takes `pawn`, in minutes: faster with the skill.
static func recipe_minutes(pawn: Pawn, recipe: Dictionary) -> int:
	var speed := 1.0 - effect(pawn, str(recipe.get("skill", "")), "speed")
	return maxi(10, roundi(float(recipe.get("minutes", 60)) * maxf(0.5, speed)))


## Why the household cannot make this now, or "" (lacking skill or materials).
static func recipe_blocker(sim: Simulation, pawn: Pawn, recipe: Dictionary) -> String:
	if level(pawn, str(recipe.get("skill", ""))) < int(recipe.get("min_level", 0)):
		return "needs %s level %d" % [name_of(str(recipe.get("skill", ""))).to_lower(), int(recipe.get("min_level", 0))]
	var lacking := {}
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		var short := int(inputs[item_id]) - sim.household.stock_of(str(item_id))
		if short > 0:
			lacking[str(item_id)] = short
	if not lacking.is_empty():
		return "you need %s more" % Economy.stock_text(lacking)
	return ""


## Takes the materials for a recipe from the stock, with the skill sometimes saving some.
static func consume_inputs(sim: Simulation, pawn: Pawn, recipe: Dictionary, rng: RandomNumberGenerator) -> void:
	var saving := effect(pawn, str(recipe.get("skill", "")), "save")
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		var amount := int(inputs[item_id])
		if amount > 1 and rng.randf() < saving:
			amount -= 1  # a careful worker wastes less
		sim.household.add_stock(str(item_id), -amount)


## "wood 1, stone 2" for a recipe's materials.
static func inputs_text(recipe: Dictionary) -> String:
	return Economy.stock_text(recipe.get("inputs", {}))
