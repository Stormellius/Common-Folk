extends Node
## Not a pass/fail test: plays 20 game days on a few seeds with nobody giving orders and prints
## how the people did (deaths, mood, the lowest each need got). Run it after changing needs,
## thoughts or the starting camp to see whether the balance still holds:
##   godot --headless --path . res://tests/balance_check.tscn

const SEEDS := [7, 42, 99]
const START_DAYS := [0, 45]  # the first day of spring, and the middle of winter
const DAYS := 20  # long enough to cross a quarter day
const STARTS := ["arrived", "inherited", "bought"]  # one per seed, in turn


func _ready() -> void:
	var only := OS.get_cmdline_user_args()  # "--seed=7 --day=45" plays just that one
	var one_seed := -1
	var one_day := -1
	for arg in only:
		if arg.begins_with("--seed="):
			one_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--day="):
			one_day = int(arg.trim_prefix("--day="))
	for start_day in START_DAYS:
		for world_seed in SEEDS:
			if (one_seed == -1 or one_seed == world_seed) and (one_day == -1 or one_day == start_day):
				_play(world_seed, start_day)
	get_tree().quit()


func _play(world_seed: int, start_day: int) -> void:
	var start_id: String = STARTS[SEEDS.find(world_seed)]
	for once in 1:
		GameClock.reset()
		GameClock.set_time(start_day, 6)
		var world := RegionGenerator.generate(world_seed)
		var begun := Starts.begin(world, start_id)
		var household: Household = begun["household"]
		var sim := Simulation.new(world, household, NpcGenerator.create(world), begun["realm"])
		var causes: Array[String] = []
		var deaths := [0]
		var town_deaths := [0]
		sim.pawn_died.connect(func(person: String, cause: String, _next: String) -> void:
			deaths[0] += 1
			causes.append("%s %s (day %d)" % [person, cause, GameClock.get_day_number()]))
		sim.town_death.connect(func(person: String, cause: String) -> void:
			town_deaths[0] += 1
			causes.append("%s of the town %s (day %d)" % [person, cause, GameClock.get_day_number()]))
		var coins_at_start := 0
		for villager in sim.town.pawns:
			coins_at_start += villager.coins
		var levels_at_start := {}
		for pawn in sim.people():
			levels_at_start[pawn.id] = _levels(pawn)
		var lowest := {}
		var total := 0.0
		var samples := 0
		var worst_mood := 100.0
		for minute in DAYS * GameClock.MINUTES_PER_DAY:
			GameClock.advance_one_tick()
			sim.step(GameClock.SUBSTEPS_PER_MINUTE)
			if minute % 60 == 0:
				for pawn in sim.people():
					total += pawn.mood
					samples += 1
					worst_mood = minf(worst_mood, pawn.mood)
					for need_id in pawn.needs:
						lowest[need_id] = minf(float(lowest.get(need_id, 100.0)), float(pawn.needs[need_id]))
		var rounded := {}
		for need_id in lowest:
			rounded[need_id] = snappedf(lowest[need_id], 0.1)
		var coins_at_end := 0
		var employed := 0
		for villager in sim.town.pawns:
			coins_at_end += villager.coins
			employed += 1 if villager.work_job != "" else 0
		var gained := {}  # skill: levels gained by everyone alive at both ends
		for pawn in sim.people():
			var before: Dictionary = levels_at_start.get(pawn.id, {})
			var after := _levels(pawn)
			for skill_id in after:
				var up := int(after[skill_id]) - int(before.get(skill_id, 0))
				if up > 0:
					gained[skill_id] = int(gained.get(skill_id, 0)) + up
		print("seed %d (%s start), day %d: %d deaths (%d in town), %d people, average mood %.1f, worst mood %.1f, lowest needs %s" % [world_seed, start_id, start_day, deaths[0], town_deaths[0], sim.people().size(), total / maxf(1.0, samples), worst_mood, rounded])
		print("    town: %d in work, pockets %d -> %d coin; household purse %d, standing %.0f, arrears %d%s" % [employed, coins_at_start, coins_at_end, household.coins, sim.realm.reputation, sim.realm.arrears, ("\n    " + "\n    ".join(causes)) if not causes.is_empty() else ""])
		print("    skills: levels gained %s; household best %s" % [gained, _household_best(household)])


## { skill: level } for every skill a person has begun.
func _levels(pawn: Pawn) -> Dictionary:
	var found := {}
	for entry in Skills.known(pawn):
		found[entry["id"]] = entry["level"]
	return found


## "Ada woodcutting 3, ..." for the player's people.
func _household_best(household: Household) -> String:
	var parts: Array[String] = []
	for pawn in household.pawns:
		var top := Skills.best(pawn)
		if top != "":
			parts.append("%s %s %d" % [pawn.display_name.get_slice(" ", 0), top, Skills.level(pawn, top)])
	return ", ".join(parts)
