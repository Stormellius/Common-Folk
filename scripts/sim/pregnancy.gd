class_name Pregnancy
extends RefCounted
## Pregnancy and birth (data/pregnancy.json), on the game's lifespan clock: a pregnancy lasts three
## quarters of a year of life (three days on Normal; see Life).
##
## Intimacy between a woman and a man may start one ("conception_chance" on the interaction), and
## couples of the town who live together have children of their own now and then. It stays a
## private matter for the first trimester (though mornings can be queasy), then she is known to be
## expecting: she eats and tires more, may crave something sweet, and her belly shows. Heavy in the
## last weeks, she stays off work. Then labour begins: she makes for the clinic's sickbed if she
## can afford it, or her own bed, and anyone who stays with her (or the clinic's staff on duty)
## acts as midwife. A birth can be hard, leaving her weak or, rarely, costing her life; the baby
## always lives, and now and then there are two or three. Babies are carried, or sleep in a cradle,
## until they are toddlers; Babies looks after what they need.

const HOUR := 60


static func config() -> Dictionary:
	return DataRegistry.get_def("pregnancy", "pregnancy")


static func _number(key: String, fallback: float) -> float:
	return float(config().get(key, fallback))


## Babies are carried until they are toddlers (data/life_stages.json).
static func infant_age() -> int:
	return Life.stage_start("toddler", int(config().get("infant_until_age", 2)))


## How long a pregnancy lasts in this game, in minutes.
static func length_minutes(world: WorldState) -> int:
	return maxi(HOUR, roundi(_number("duration_years", 0.75) * Life.days_per_year(world) * GameClock.MINUTES_PER_DAY))


## 0 when she conceived, 1 when the baby is due (more if labour has begun).
static func progress(pawn: Pawn) -> float:
	if not pawn.is_pregnant() or pawn.pregnancy_minutes <= 0:
		return 0.0
	return float(GameClock.tick - pawn.pregnant_since) / float(pawn.pregnancy_minutes)


## 1, 2 or 3, or 0 when not expecting.
static func trimester(pawn: Pawn) -> int:
	if not pawn.is_pregnant():
		return 0
	var done := progress(pawn)
	if done >= _number("third_trimester_at", 0.67):
		return 3
	return 2 if done >= _number("second_trimester_at", 0.34) else 1


## Pregnant and far enough along for everyone to know.
static func is_known(pawn: Pawn) -> bool:
	return pawn.is_pregnant() and progress(pawn) >= _number("announce_at", 0.27)


static func is_heavy(pawn: Pawn) -> bool:
	return pawn.is_pregnant() and progress(pawn) >= _number("heavy_at", 0.75)


static func in_labour(pawn: Pawn) -> bool:
	return pawn.is_pregnant() and pawn.labour_since >= 0


## How big the belly is, 0 (not showing) to 1 (due), for the view: it shows from the second trimester.
static func bump(pawn: Pawn) -> float:
	return bump_at(progress(pawn)) if pawn.is_pregnant() else 0.0


## The belly at `done` of the way through (0 to 1).
static func bump_at(done: float) -> float:
	var from := _number("second_trimester_at", 0.34)
	return clampf((done - from) / (1.0 - from), 0.0, 1.0)


## Whether `mother` could conceive right now.
static func can_conceive(mother: Pawn) -> bool:
	return mother.gender == "female" and mother.adult and not mother.is_pregnant() and not mother.is_dying() \
		and GameClock.tick >= mother.recovered_at and mother.age <= int(config().get("max_mother_age", 45))


## Called when an intimate interaction ends. Returns true if a pregnancy began.
static func try_conceive(sim: Simulation, a: Pawn, b: Pawn, chance: float, rng: RandomNumberGenerator) -> bool:
	if a.gender == b.gender or not (a.adult and b.adult):
		return false
	var mother := a if a.gender == "female" else b
	var father := b if mother == a else a
	if sim.person(mother.id) == null or not can_conceive(mother):
		return false
	if rng.randf() >= chance:
		return false
	begin(sim, mother, father, rng)
	return true


## She is with child: how long it will take is fixed now, and so is whether it is twins.
static func begin(sim: Simulation, mother: Pawn, father: Pawn, rng: RandomNumberGenerator) -> void:
	mother.pregnant_since = GameClock.tick
	mother.pregnancy_minutes = length_minutes(sim.world)
	mother.pregnancy_father = father.id if father != null else 0
	mother.pregnancy_announced = false
	mother.labour_since = -1
	var roll := rng.randf()
	mother.babies_due = 3 if roll < _number("triplets_chance", 0.004) else (2 if roll < _number("twins_chance", 0.04) else 1)


## `multipliers` with an expecting mother's extra hunger and tiredness multiplied in.
static func drain_multipliers(pawn: Pawn, multipliers: Dictionary) -> Dictionary:
	if not is_known(pawn):
		return multipliers
	var merged := multipliers.duplicate()
	var extra: Dictionary = config().get("need_drain_multipliers", {})
	for need_id in extra:
		merged[need_id] = float(merged.get(need_id, 1.0)) * float(extra[need_id])
	return merged


## Heavily pregnant women (and those in labour) stay home from work.
static func needs_rest_from_work(pawn: Pawn) -> bool:
	return in_labour(pawn) or (bool(config().get("heavy_work_break", true)) and is_heavy(pawn))


## The person's birthday, by the calendar (see Life.birthday_of for the game's own lifespan).
static func birthday_of(pawn: Pawn) -> int:
	return Life.birthday_of(pawn, null)


## She has eaten: a craving is satisfied.
static func after_eating(pawn: Pawn) -> void:
	for i in range(pawn.thoughts.size() - 1, -1, -1):
		if pawn.thoughts[i]["id"] == "craving":
			pawn.thoughts.remove_at(i)
			Mood.add_event(pawn, "craving_met", GameClock.tick)


# --- carrying -----------------------------------------------------------------------------

## Keeps every baby with its family: on the arms of someone of its home, moving with them, or
## asleep in a cradle there at night (see Babies).
static func carry_infants(sim: Simulation) -> void:
	for baby in sim.people():
		if not baby.is_infant():
			continue
		var cradle := Babies.cradle_for(sim, baby)
		if cradle != null:
			baby.tile = cradle.tile
			baby.step_to = cradle.tile
			baby.step_ticks_total = 0
			baby.step_ticks_done = 0
			baby.facing = Vector2i(0, 1)
			baby.path.clear()
			baby.pose = "lie"
			continue
		baby.pose = ""
		var carer := sim.person(baby.carried_by)
		if carer == null or carer.is_infant() or carer.is_dying() or carer.home_lot != baby.home_lot:
			carer = null
			for candidate in _family_of(sim, baby):
				if not candidate.is_infant() and not candidate.is_dying() and (carer == null or (candidate.adult and not carer.adult)):
					carer = candidate
			baby.carried_by = carer.id if carer != null else 0
		if carer == null:
			continue
		baby.tile = carer.tile
		baby.step_to = carer.step_to
		baby.step_ticks_total = carer.step_ticks_total
		baby.step_ticks_done = carer.step_ticks_done
		baby.facing = carer.facing
		baby.path.clear()


## Everyone in the baby's own household (yours, or its family in the town).
static func _family_of(sim: Simulation, pawn: Pawn) -> Array[Pawn]:
	if sim.household.get_pawn(pawn.id) != null:
		return sim.household.pawns
	var family: Array[Pawn] = []
	for other in sim.town.pawns:
		if other.home_lot == pawn.home_lot:
			family.append(other)
	return family


# --- the days of a pregnancy ------------------------------------------------------------

## Every minute: the news, sick mornings, cravings, labour and births. Returns messages about your
## own folk; a birth into your household is reported by `sim.household_changed` and
## `sim.babies_born` too.
static func step(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var messages: Array[String] = []
	var minute := GameClock.get_minute_of_day()
	for pawn in sim.people():
		if not pawn.is_pregnant() or pawn.is_dying():
			continue
		var yours := sim.household.get_pawn(pawn.id) != null
		if not pawn.pregnancy_announced and is_known(pawn):
			pawn.pregnancy_announced = true
			if yours:
				messages.append("%s is expecting a baby." % pawn.display_name)
		var stage := trimester(pawn)
		if minute == 7 * HOUR and stage == 1 and rng.randf() < _number("morning_sickness_chance", 0.5):
			Mood.add_event(pawn, "morning_sick", GameClock.tick)
		elif minute == 11 * HOUR and stage == 2 and rng.randf() < _number("craving_chance", 0.4):
			Mood.add_event(pawn, "craving", GameClock.tick)
		if pawn.labour_since < 0 and progress(pawn) >= 1.0:
			if not yours:
				_give_birth(sim, pawn, rng)  # the town's births happen at home, quietly
				continue
			pawn.labour_since = GameClock.tick
			var hours: Array = config().get("labour_hours", [3, 8])
			pawn.labour_minutes = rng.randi_range(int(hours[0]) * HOUR, int(hours[1]) * HOUR)
			sim.begin_labour(pawn)
			messages.append("%s's labour has begun! Someone should stay with her." % pawn.display_name)
		elif pawn.labour_since >= 0 and GameClock.tick - pawn.labour_since >= pawn.labour_minutes:
			messages.append(_give_birth(sim, pawn, rng))
		elif pawn.labour_since >= 0 and pawn.job_kind != "labour":
			sim.begin_labour(pawn)  # something got her up: back to bed
	return messages


## Midnight: couples of the town who live together may start a family.
static func new_day(sim: Simulation, rng: RandomNumberGenerator) -> Array[String]:
	var chance := _number("town_conception_chance", 0.02)
	var limit := int(config().get("town_home_limit", 6))
	var homes := {}
	for pawn in sim.town.pawns:
		homes[pawn.home_lot] = int(homes.get(pawn.home_lot, 0)) + 1
	for mother in sim.town.pawns:
		if not can_conceive(mother) or int(homes.get(mother.home_lot, 0)) >= limit:
			continue
		for father in sim.town.pawns:
			if father.home_lot == mother.home_lot and father.gender != mother.gender and father.adult and not father.is_dying() \
					and sim.attracted(mother, father) and sim.attracted(father, mother):
				if rng.randf() < chance:
					begin(sim, mother, father, rng)
				break
	return []


# --- birth ---------------------------------------------------------------------------------

## Whether someone is acting as midwife: staying with her, or (in a clinic's sickbed) the clinic's
## staff on duty.
static func midwife_present(sim: Simulation, mother: Pawn) -> bool:
	for other in sim.people():
		if other.job_kind == "attend" and other.job_partner == mother.id and other.job_stage == "using":
			return true
	var bed := birth_bed(sim, mother)
	if bed != null and bed.def_id == "sickbed":
		var lot := sim.world.lot_at(bed.tile)
		for other in sim.people():
			if other.job_kind == "work" and other.job_stage == "using" and other.work_lot == str(lot.get("id", "")):
				return true
	return false


## The bed she is lying in for the birth, or null.
static func birth_bed(sim: Simulation, mother: Pawn) -> PlacedObject:
	if mother.job_kind != "labour" or mother.job_stage != "using":
		return null
	return sim.world.get_object(mother.job_object)


## The chance this birth goes badly, from where she is and who is with her.
static func complication_chance(sim: Simulation, mother: Pawn) -> float:
	var chance := _number("complication_chance", 0.1)
	var bed := birth_bed(sim, mother)
	if bed != null:
		chance *= _number("complication_in_sickbed", 0.3) if bed.def_id == "sickbed" else _number("complication_in_bed", 0.6)
	if midwife_present(sim, mother):
		chance *= _number("complication_with_midwife", 0.4)
	return chance


static func _give_birth(sim: Simulation, mother: Pawn, rng: RandomNumberGenerator) -> String:
	var yours := sim.household.get_pawn(mother.id) != null
	var hard := rng.randf() < complication_chance(sim, mother)
	var fatal := hard and rng.randf() < _number("complication_fatal_share", 0.2)
	var babies: Array[Pawn] = []
	for i in maxi(1, mother.babies_due):
		babies.append(_make_baby(sim, mother, rng))
	sim.end_labour(mother)
	mother.pregnant_since = -1
	mother.labour_since = -1
	mother.babies_due = 1
	var recovery := roundi(_number("recovery_years", 0.25) * Life.days_per_year(sim.world) * GameClock.MINUTES_PER_DAY)
	mother.recovered_at = GameClock.tick + recovery * (2 if hard else 1)
	for relative in _family_of(sim, mother):
		Mood.add_event(relative, "birth", GameClock.tick)
	Mood.add_event(mother, "gave_birth", GameClock.tick)
	if hard:
		Mood.add_event(mother, "hard_birth", GameClock.tick)
		for need_id in ["rest", "hygiene"]:
			if mother.needs.has(need_id):
				mother.needs[need_id] = minf(float(mother.needs[need_id]), 8.0)
	if yours:
		sim.household_changed.emit()
		var ids: Array[int] = []
		for baby in babies:
			ids.append(baby.id)
		sim.babies_born.emit(ids)
	if fatal:
		Mortality.fall(sim, mother, "died in childbirth")
	var kinds: Array[String] = []
	for baby in babies:
		kinds.append("a girl" if baby.gender == "female" else "a boy")
	var what := "a baby %s" % kinds[0].trim_prefix("a ") if babies.size() == 1 else "%s: %s" % ["twins" if babies.size() == 2 else "triplets", ", ".join(kinds.slice(0, kinds.size() - 1)) + " and " + kinds[-1]]
	var text := "%s gave birth to %s." % [mother.display_name, what]
	if hard and not fatal:
		text += " It was a hard birth, and she is weak."
	elif fatal:
		text += " It was a hard birth."
	return text


static func _make_baby(sim: Simulation, mother: Pawn, rng: RandomNumberGenerator) -> Pawn:
	var used: Array[String] = []
	for relative in _family_of(sim, mother):
		used.append(relative.display_name.get_slice(" ", 0))
	var family := mother.display_name.get_slice(" ", 1)
	var baby := PersonFactory.make(rng, family if family != "" else "Smith", used, 0)
	var father := sim.person(mother.pregnancy_father)
	var parent_skins: Array[String] = [str(mother.look.get("skin", ""))]
	if father != null:
		parent_skins.append(str(father.look.get("skin", "")))
	var skin := parent_skins[rng.randi() % parent_skins.size()]
	if skin != "":
		baby.look["skin"] = skin
	baby.home_lot = mother.home_lot
	baby.class_id = mother.class_id
	baby.birthday = posmod(GameClock.get_day_number(), Life.days_per_year(sim.world))
	baby.carried_by = mother.id
	baby.tile = mother.committed_tile()
	baby.step_to = baby.tile
	Babies.reset_care(baby)
	var family_members: Array[Pawn] = _family_of(sim, mother).duplicate()
	if sim.household.get_pawn(mother.id) != null:
		sim.household.add_pawn(baby)
	else:
		sim.town.add_pawn(baby)
	family_members.append(baby)
	Relations.make_family(family_members)
	return baby
