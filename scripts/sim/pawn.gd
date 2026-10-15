class_name Pawn
extends RefCounted
## One person in the world, as plain data. It knows where it stands and where it is
## walking, but never draws anything: PawnView reads these fields and does the drawing.
##
## A walk is a list of tiles (`path`). One step at a time the pawn commits to the next
## tile, spends a few game ticks crossing it (more in forest, more on diagonals), and
## arrives. Because it only advances on clock ticks, pausing and speed changes just work.

## Game minutes to cross one open tile in a straight line.
const BASE_MOVE_TICKS := 3.0

var id := 0
var display_name := ""
var gender := "female"
## Interactions marked "adults_only" in data/interactions.json need every person to be one.
var adult := true
## Years old. Under 18 is a child (`adult` false); children are drawn smaller.
var age := 25
## The lot this person lives on (WorldState lot id). Only they may use what stands on a private lot.
var home_lot := WorldState.HOME_LOT
## Social standing, an id from data/classes.json.
var class_id := "peasant"
## What this person is ill with, an id from data/illness.json ("" when well), and since which tick.
var illness := ""
var ill_since := 0
## A pregnancy (see Pregnancy): the tick she conceived (-1 when not expecting), how many minutes it
## will last, by whom, how many babies are coming, whether the household has been told, and labour
## (the tick it began, -1 before, and how long it will take).
var pregnant_since := -1
var pregnancy_minutes := 0
var pregnancy_father := 0
var babies_due := 1
var pregnancy_announced := false
var labour_since := -1
var labour_minutes := 0
## A mother cannot conceive again before this tick (she is recovering from the birth).
var recovered_at := 0
## A baby's needs (see Babies), by id from "baby_care" in data/pregnancy.json, and since when one of
## them has been empty (-1 while it is cared for).
var care: Dictionary = {}
var neglected_since := -1
## Day of the year (0 to 59) the person has their birthday, or -1 for "work it out from the id".
var birthday := -1
## An infant is carried by someone from the household and cannot be controlled (see Pregnancy).
var carried_by := 0
## Someone whose time has come lies dying until Death takes them (see Mortality): what is killing
## them ("" while alive and well), the tick they fell, where Death comes from, and whether anyone
## has pleaded for them yet.
var dying_cause := ""
var dying_since := 0
var death_from := Vector2i.ZERO
var pleaded := false
## Colors as hex strings plus a hair style number; see PawnArt.
var look: Dictionary = {}

## The tile the pawn stands on (or is leaving, while a step is in progress).
var tile := Vector2i.ZERO
## Direction of the last step. (0, 1) is facing south, toward the camera.
var facing := Vector2i(0, 1)
## Tiles still to walk, not including the step in progress.
var path: Array[Vector2i] = []

## How full each need is, 0 to 100, by need id (only the needs in play; see Needs).
var needs: Dictionary = {}
## Thoughts that have not faded yet: { "id", "until" } (until is a GameClock tick). Mood is
## worked out from these and from how the person is doing right now; see Mood.
var thoughts: Array[Dictionary] = []
## Worked out every tick (not saved): 0 to 100, and the thoughts behind it, strongest first.
var mood := Mood.BASE
var mood_parts: Array[Dictionary] = []
## Trait ids from data/traits.json; they change how fast needs drain.
var traits: Array[String] = []
## True while any need is empty: the person drags their feet.
var slowed := false
## How many game minutes each deadly need (hunger, warmth) has been empty; see Simulation.
var deprivation: Dictionary = {}

## What the person is doing on their own account, apart from walking orders:
## "" (nothing), "use" (going to, or busy with, an object), "interact" (with `job_partner`) or
## "work" (on the way to their post, or at it, for the shift).
## In an interaction the one who asked has job_stage "walking" then "using"; the other
## person waits, with job_stage "partner", and stays put until it is over.
var job_kind := ""
var job_partner := 0         # id of the other person in an interaction
var job_interaction := ""    # id from data/interactions.json
var job_object := 0          # id of the PlacedObject being used
var job_stage := ""          # "walking" on the way there, "using" once started
var job_tile := Vector2i.ZERO  # where the person stands while using it
var job_target := Vector2i.ZERO  # what they are working on, when it is a tile (a fire to put out)
var job_animal := 0          # id of the animal they are hunting, petting or going to ride
var job_site := 0            # id of the BuildSite they are working on
var job_minutes := 0         # how long the use has gone on
## "" standing, or "lie" while sleeping. Set by the simulation, read by the view.
var pose := ""
## Coin in this person's own pocket. Only the town's people use it; the player's household
## shares one purse (Household.coins).
var coins := 0
## Wages earned but not yet a whole coin.
var pay_carry := 0.0
## The job: a lot id from WorldState.lots and a job id from data/jobs.json ("" when out of work).
var work_lot := ""
var work_job := ""
## The day number on which the player took this person off their shift (see Simulation).
var skip_work_day := -1
## What this person thinks of each other person they have met, -100 to 100, by that person's id
## (see Relations). Missing means a stranger: 0.
var relations: Dictionary = {}
## Romance (see Romance): how taken this person is with each other person, 0 to 100, by id; who they
## are seeing (0 for nobody) and how far it has got ("dating", or "partners" once they live
## together) and since which tick; where they lived before moving in with someone; and their parents,
## so that family stay apart.
var romance: Dictionary = {}
var partner_id := 0
var partner_status := ""
var partner_since := 0
var origin_lot := ""
var parents: Array[int] = []
## Marriage (see Romance): "" or "engaged" or "married" to `partner_id`, since which tick; the name they
## were born with, kept once a wedding changes it; and the tick until which they are in wedding clothes.
var bond := ""
var bond_since := 0
var maiden_name := ""
var wed_until := 0
## Illness (see Illness): the tick until which someone is immune to each illness they have had
## (by illness id), the tick until which herbs are helping them recover, and how many minutes in a
## row they have stood in fire (see Fire).
var immune: Dictionary = {}
var treated_until := 0
var fire_minutes := 0
## Skills (see Skills): xp by skill id; the skills they take to naturally; the skill their parents
## were best at, which they learn the basics of when they grow up; the tool in their hand (and whether
## the employer lent it); the recipe they are making at a forge or bench; and, not saved, how much
## faster a master nearby has them learning.
var skills: Dictionary = {}
var talents: Array[String] = []
var family_trade := ""
var tool := ""
var tool_lent := false
var job_recipe := ""
## What the player has told this person to wear (an outfit id, or "" for whatever suits), and, while they are at a
## wardrobe, what they are changing into.
var outfit_choice := ""
var job_outfit := ""
var mentor_gain := 1.0
## The animal they ride (0 for none), and how much each step costs: 1 on foot, less on a horse, more
## when stalking game (worked out again from those two, so not saved).
var mount := 0
var pace := 1.0
## What a builder is carrying to a site, by resource id; and the tick until which a townsperson is
## hired to build on the player's land (0 when not).
var carrying: Dictionary = {}
var contract_until := 0
## The caravan a person is riding with (0 for none): see Caravans.
var caravan := 0
## Ambitions and wishes (see Ambitions): what they have done in their life, counted by event key; the
## ambition they are after, which step they are on, the tick from which they may take up a new one, and
## the ambitions they have fulfilled; the small wishes they have now ({ "id", "until", maybe "retry" }), when each was
## last granted, the towns they have been to, and, not saved, news for the player.
var deeds: Dictionary = {}
var ambition := ""
var ambition_step := 0
var ambition_next := 0
var ambitions_done: Array[String] = []
var wishes: Array[Dictionary] = []
var wish_done: Dictionary = {}
var visited: Array[String] = []
var news: Array[String] = []
## Ticks to wait before looking for something to do about a need again.
var think_cooldown := 0

## The step in progress: heading to `step_to`, `step_ticks_done` of `step_ticks_total` done.
var step_to := Vector2i.ZERO
var step_ticks_total := 0
var step_ticks_done := 0


func is_infant() -> bool:
	return age < Pregnancy.infant_age()


## The name that fixes who this person is born to be (their looks' details, the age they will die
## at): the one they were born with, so a wedding that changes their surname changes none of it.
func seed_name() -> String:
	return maiden_name if maiden_name != "" else display_name


func given_name() -> String:
	return display_name.get_slice(" ", 0)


func surname() -> String:
	return display_name.get_slice(" ", 1)


func romance_for(other_id: int) -> float:
	return float(romance.get(other_id, 0.0))


func add_romance(other_id: int, delta: float) -> void:
	var value := clampf(romance_for(other_id) + delta, 0.0, 100.0)
	if value <= 0.0:
		romance.erase(other_id)
	else:
		romance[other_id] = value


func is_pregnant() -> bool:
	return pregnant_since >= 0


func is_dying() -> bool:
	return dying_cause != ""


func opinion_of(other_id: int) -> float:
	return float(relations.get(other_id, 0.0))


func set_opinion(other_id: int, value: float) -> void:
	relations[other_id] = clampf(value, Relations.MIN, Relations.MAX)


func add_opinion(other_id: int, delta: float) -> void:
	set_opinion(other_id, opinion_of(other_id) + delta)


func is_moving() -> bool:
	return step_ticks_total > 0


func has_orders() -> bool:
	return is_moving() or not path.is_empty()


## True while walking somewhere, busy with an object, or lying dying.
func is_busy() -> bool:
	return has_orders() or job_kind != "" or is_dying()


## 0 to 1 progress through the step in progress.
func step_progress() -> float:
	if step_ticks_total <= 0:
		return 0.0
	return float(step_ticks_done) / float(step_ticks_total)


## The tile the pawn will be standing on once its current step is finished.
## New orders must start from here, or the pawn would turn around mid-step.
func committed_tile() -> Vector2i:
	return step_to if is_moving() else tile


func goal_tile() -> Vector2i:
	if not path.is_empty():
		return path[path.size() - 1]
	return committed_tile()


func tick(world: WorldState) -> void:
	if step_ticks_total == 0:
		if path.is_empty():
			return
		var next: Vector2i = path[0]
		if not world.is_walkable(next.x, next.y):
			path.clear()  # the world changed under us
			return
		path.remove_at(0)
		var diagonal := next.x != tile.x and next.y != tile.y
		var cost := BASE_MOVE_TICKS * maxf(world.get_move_cost(next.x, next.y), 1.0)
		if diagonal:
			cost *= 1.41421
		if slowed:
			cost *= 1.5
		cost *= Life.walk_multiplier(self)  # elders take their time
		cost *= pace  # a horse is quicker, stalking slower
		step_to = next
		step_ticks_total = maxi(1, roundi(cost))
		step_ticks_done = 0
		facing = next - tile
	step_ticks_done += 1
	if step_ticks_done >= step_ticks_total:
		tile = step_to
		step_ticks_total = 0
		step_ticks_done = 0


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_path: Array = []
	for cell in path:
		saved_path.append(_vec_to_array(cell))
	return {
		"id": id,
		"name": display_name,
		"gender": gender,
		"adult": adult,
		"age": age,
		"home_lot": home_lot,
		"class": class_id,
		"illness": illness,
		"ill_since": ill_since,
		"pregnant_tick": pregnant_since,
		"pregnancy_minutes": pregnancy_minutes,
		"pregnancy_father": pregnancy_father,
		"babies_due": babies_due,
		"pregnancy_announced": pregnancy_announced,
		"labour_since": labour_since,
		"labour_minutes": labour_minutes,
		"recovered_tick": recovered_at,
		"care": _rounded(care),
		"neglected_since": neglected_since,
		"birthday": birthday,
		"carried_by": carried_by,
		"dying_cause": dying_cause,
		"dying_since": dying_since,
		"death_from": _vec_to_array(death_from),
		"pleaded": pleaded,
		"coins": coins,
		"pay_carry": snappedf(pay_carry, 0.001),
		"work_lot": work_lot,
		"work_job": work_job,
		"skip_work_day": skip_work_day,
		"relations": _relations_for_save(),
		"romance": _romance_for_save(),
		"partner": partner_id,
		"partner_status": partner_status,
		"partner_since": partner_since,
		"origin_lot": origin_lot,
		"parents": Array(parents),
		"bond": bond,
		"bond_since": bond_since,
		"maiden_name": maiden_name,
		"wed_until": wed_until,
		"immune": immune.duplicate(),
		"treated_until": treated_until,
		"fire_minutes": fire_minutes,
		"skills": _rounded(skills),
		"talents": Array(talents),
		"family_trade": family_trade,
		"tool": tool,
		"tool_lent": tool_lent,
		"job_recipe": job_recipe,
		"outfit_choice": outfit_choice,
		"deeds": deeds.duplicate(),
		"ambition": ambition,
		"ambition_step": ambition_step,
		"ambition_next": ambition_next,
		"ambitions_done": Array(ambitions_done),
		"wishes": wishes.duplicate(true),
		"wish_done": wish_done.duplicate(),
		"visited": Array(visited),
		"look": look.duplicate(),
		"tile": _vec_to_array(tile),
		"facing": _vec_to_array(facing),
		"path": saved_path,
		"step_to": _vec_to_array(step_to),
		"step_total": step_ticks_total,
		"step_done": step_ticks_done,
		"needs": _rounded(needs),
		"traits": Array(traits),
		"slowed": slowed,
		"deprivation": deprivation.duplicate(),
		"thoughts": thoughts.duplicate(true),
		"job": job_kind,
		"job_partner": job_partner,
		"job_interaction": job_interaction,
		"job_object": job_object,
		"job_stage": job_stage,
		"job_tile": _vec_to_array(job_tile),
		"job_target": _vec_to_array(job_target),
		"job_animal": job_animal,
		"job_site": job_site,
		"carrying": carrying.duplicate(),
		"contract_until": contract_until,
		"caravan": caravan,
		"mount": mount,
		"job_minutes": job_minutes,
		"pose": pose,
		"think": think_cooldown,
	}


static func from_dict(data: Dictionary) -> Pawn:
	var pawn := Pawn.new()
	pawn.id = int(data.get("id", 0))
	pawn.display_name = str(data.get("name", ""))
	pawn.gender = str(data.get("gender", "female"))
	pawn.adult = bool(data.get("adult", true))
	pawn.age = int(data.get("age", 25 if pawn.adult else 10))
	pawn.home_lot = str(data.get("home_lot", WorldState.HOME_LOT))
	pawn.class_id = str(data.get("class", "peasant"))
	pawn.illness = str(data.get("illness", ""))
	pawn.ill_since = int(data.get("ill_since", 0))
	if data.has("pregnant_tick"):
		pawn.pregnant_since = int(data["pregnant_tick"])
		pawn.pregnancy_minutes = int(data.get("pregnancy_minutes", 0))
	elif int(data.get("pregnant_since", -1)) >= 0:  # an older save counted the days of a 45-day pregnancy
		pawn.pregnant_since = int(data["pregnant_since"]) * GameClock.MINUTES_PER_DAY
		pawn.pregnancy_minutes = 45 * GameClock.MINUTES_PER_DAY
	pawn.pregnancy_father = int(data.get("pregnancy_father", 0))
	pawn.babies_due = int(data.get("babies_due", 1))
	pawn.pregnancy_announced = bool(data.get("pregnancy_announced", true))
	pawn.labour_since = int(data.get("labour_since", -1))
	pawn.labour_minutes = int(data.get("labour_minutes", 0))
	pawn.recovered_at = int(data.get("recovered_tick", int(data.get("recovered_on", 0)) * GameClock.MINUTES_PER_DAY))
	var saved_care: Variant = data.get("care", {})
	if saved_care is Dictionary:
		for care_id in saved_care:
			pawn.care[str(care_id)] = float(saved_care[care_id])
	pawn.neglected_since = int(data.get("neglected_since", -1))
	pawn.birthday = int(data.get("birthday", -1))
	pawn.carried_by = int(data.get("carried_by", 0))
	pawn.dying_cause = str(data.get("dying_cause", ""))
	pawn.dying_since = int(data.get("dying_since", 0))
	pawn.death_from = _array_to_vec(data.get("death_from", [0, 0]))
	pawn.pleaded = bool(data.get("pleaded", false))
	pawn.coins = int(data.get("coins", 0))
	pawn.pay_carry = float(data.get("pay_carry", 0.0))
	pawn.work_lot = str(data.get("work_lot", ""))
	pawn.work_job = str(data.get("work_job", ""))
	pawn.skip_work_day = int(data.get("skip_work_day", -1))
	var saved_relations: Variant = data.get("relations", {})
	if saved_relations is Dictionary:
		for other_id in saved_relations:
			pawn.relations[int(other_id)] = float(saved_relations[other_id])  # JSON keys are text
	var saved_romance: Variant = data.get("romance", {})
	if saved_romance is Dictionary:
		for other_id in saved_romance:
			pawn.romance[int(other_id)] = float(saved_romance[other_id])
	pawn.partner_id = int(data.get("partner", 0))
	pawn.partner_status = str(data.get("partner_status", ""))
	pawn.partner_since = int(data.get("partner_since", 0))
	pawn.origin_lot = str(data.get("origin_lot", ""))
	for parent_id in data.get("parents", []):
		pawn.parents.append(int(parent_id))
	pawn.bond = str(data.get("bond", ""))
	pawn.bond_since = int(data.get("bond_since", 0))
	pawn.maiden_name = str(data.get("maiden_name", ""))
	pawn.wed_until = int(data.get("wed_until", 0))
	var saved_immune: Variant = data.get("immune", {})
	if saved_immune is Dictionary:
		for illness_id in saved_immune:
			pawn.immune[str(illness_id)] = int(saved_immune[illness_id])
	pawn.treated_until = int(data.get("treated_until", 0))
	pawn.fire_minutes = int(data.get("fire_minutes", 0))
	var saved_skills: Variant = data.get("skills", {})
	if saved_skills is Dictionary:
		for skill_id in saved_skills:
			pawn.skills[str(skill_id)] = float(saved_skills[skill_id])
	for talent in data.get("talents", []):
		pawn.talents.append(str(talent))
	pawn.family_trade = str(data.get("family_trade", ""))
	pawn.tool = str(data.get("tool", ""))
	pawn.tool_lent = bool(data.get("tool_lent", false))
	pawn.job_recipe = str(data.get("job_recipe", ""))
	pawn.outfit_choice = str(data.get("outfit_choice", ""))
	var saved_deeds: Variant = data.get("deeds", {})
	if saved_deeds is Dictionary:
		for key in saved_deeds:
			pawn.deeds[str(key)] = int(saved_deeds[key])
	pawn.ambition = str(data.get("ambition", ""))
	pawn.ambition_step = int(data.get("ambition_step", 0))
	pawn.ambition_next = int(data.get("ambition_next", 0))
	for done_id in data.get("ambitions_done", []):
		pawn.ambitions_done.append(str(done_id))
	for saved_wish in data.get("wishes", []):
		if saved_wish is Dictionary and saved_wish.has("id"):
			var wish := { "id": str(saved_wish["id"]), "until": int(saved_wish.get("until", 0)) }
			if saved_wish.has("retry"):
				wish["retry"] = int(saved_wish["retry"])
			pawn.wishes.append(wish)
	var saved_wish_done: Variant = data.get("wish_done", {})
	if saved_wish_done is Dictionary:
		for wish_id in saved_wish_done:
			pawn.wish_done[str(wish_id)] = int(saved_wish_done[wish_id])
	for town_id in data.get("visited", []):
		pawn.visited.append(str(town_id))
	var saved_look: Variant = data.get("look", {})
	pawn.look = saved_look.duplicate() if saved_look is Dictionary else {}
	if pawn.look.has("hair_style"):
		pawn.look["hair_style"] = int(pawn.look["hair_style"])  # JSON numbers load as floats
	pawn.tile = _array_to_vec(data.get("tile", [0, 0]))
	pawn.facing = _array_to_vec(data.get("facing", [0, 1]))
	for cell in data.get("path", []):
		pawn.path.append(_array_to_vec(cell))
	pawn.step_to = _array_to_vec(data.get("step_to", [0, 0]))
	pawn.step_ticks_total = int(data.get("step_total", 0))
	pawn.step_ticks_done = int(data.get("step_done", 0))
	var saved_needs: Variant = data.get("needs", {})
	if saved_needs is Dictionary:
		for need_id in saved_needs:
			pawn.needs[str(need_id)] = float(saved_needs[need_id])
	for trait_id in data.get("traits", []):
		pawn.traits.append(str(trait_id))
	pawn.slowed = bool(data.get("slowed", false))
	for saved_thought in data.get("thoughts", []):
		if saved_thought is Dictionary and saved_thought.has("id"):
			var thought := { "id": str(saved_thought["id"]), "until": int(saved_thought.get("until", 0)) }
			if saved_thought.has("about"):
				thought["about"] = str(saved_thought["about"])
			pawn.thoughts.append(thought)
	var saved_deprivation: Variant = data.get("deprivation", {})
	if saved_deprivation is Dictionary:
		for need_id in saved_deprivation:
			pawn.deprivation[str(need_id)] = int(saved_deprivation[need_id])
	pawn.job_kind = str(data.get("job", ""))
	pawn.job_partner = int(data.get("job_partner", 0))
	pawn.job_interaction = str(data.get("job_interaction", ""))
	pawn.job_object = int(data.get("job_object", 0))
	pawn.job_stage = str(data.get("job_stage", ""))
	pawn.job_tile = _array_to_vec(data.get("job_tile", [0, 0]))
	pawn.job_target = _array_to_vec(data.get("job_target", [0, 0]))
	pawn.job_animal = int(data.get("job_animal", 0))
	pawn.job_site = int(data.get("job_site", 0))
	pawn.contract_until = int(data.get("contract_until", 0))
	pawn.caravan = int(data.get("caravan", 0))
	var saved_carrying: Variant = data.get("carrying", {})
	if saved_carrying is Dictionary:
		for resource_id in saved_carrying:
			pawn.carrying[str(resource_id)] = int(saved_carrying[resource_id])
	pawn.mount = int(data.get("mount", 0))
	pawn.job_minutes = int(data.get("job_minutes", 0))
	pawn.pose = str(data.get("pose", ""))
	pawn.think_cooldown = int(data.get("think", 0))
	return pawn


func _romance_for_save() -> Dictionary:
	var saved := {}
	for other_id in romance:
		saved[str(other_id)] = snappedf(float(romance[other_id]), 0.1)
	return saved


func _relations_for_save() -> Dictionary:
	var saved := {}
	for other_id in relations:
		saved[str(other_id)] = snappedf(float(relations[other_id]), 0.1)
	return saved


## Need values rounded for the save file, so a save and a reload give identical numbers.
static func _rounded(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		result[key] = snappedf(float(values[key]), 0.01)
	return result


static func _vec_to_array(v: Vector2i) -> Array:
	return [v.x, v.y]


static func _array_to_vec(a: Variant) -> Vector2i:
	if a is Array and a.size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))  # JSON numbers load as floats
	return Vector2i.ZERO
