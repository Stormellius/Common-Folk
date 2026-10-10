extends Node
## The game clock. It turns real time into fixed simulation ticks.
##
## One tick is one game minute. Everything in the simulation should advance on
## the "ticked" signal, never on frame time, so that pausing and speed changes
## affect the whole world the same way (and save games are reproducible).
##
## Speed levels: 0 = paused, 1 = 1x, 2 = 2x, 3 = 3x (see SPEED_MULTIPLIERS).

signal ticked(tick: int)
signal day_changed(day_number: int)
signal speed_changed(level: int)
## Emitted when the time is set from outside (new game, loaded save).
signal time_set

const TICK_SECONDS := 0.1            # real seconds per tick at 1x
const MINUTES_PER_DAY := 1440
const START_TICK := 6 * 60           # a new game starts at 06:00 on day 1
const SPEED_MULTIPLIERS: Array[float] = [0.0, 1.0, 2.0, 3.0]
const MAX_TICKS_PER_FRAME := 30      # protects against a spiral after a long frame

## Used only if no seasons.json is loaded.
const FALLBACK_SEASONS: Array = [{ "id": "season", "name": "Season", "days": 60 }]

var tick: int = START_TICK
var speed_level: int = 1

var _last_running_speed: int = 1
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if speed_level == 0:
		return
	_accumulator += delta * SPEED_MULTIPLIERS[speed_level]
	var steps := 0
	while _accumulator >= TICK_SECONDS and steps < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_SECONDS
		advance_one_tick()
		steps += 1
	if steps == MAX_TICKS_PER_FRAME:
		_accumulator = 0.0  # drop the backlog instead of running ever further behind


func advance_one_tick() -> void:
	var day_before := get_day_number()
	tick += 1
	ticked.emit(tick)
	var day_after := get_day_number()
	if day_after != day_before:
		day_changed.emit(day_after)


## Advances the clock without waiting for real time (used by tests and tools).
func advance_ticks(amount: int) -> void:
	for i in amount:
		advance_one_tick()


func set_speed(level: int) -> void:
	level = clampi(level, 0, SPEED_MULTIPLIERS.size() - 1)
	if level == speed_level:
		return
	speed_level = level
	if level > 0:
		_last_running_speed = level
	speed_changed.emit(speed_level)


func toggle_pause() -> void:
	if speed_level == 0:
		set_speed(_last_running_speed)
	else:
		set_speed(0)


## Back to the start of a new game.
func reset() -> void:
	tick = START_TICK
	_accumulator = 0.0
	time_set.emit()


# --- calendar ------------------------------------------------------------------

func get_day_number() -> int:
	return floori(float(tick) / MINUTES_PER_DAY)  # 0 on the first day


func get_minute_of_day() -> int:
	return tick % MINUTES_PER_DAY


func get_time_text() -> String:
	var minute := get_minute_of_day()
	return "%02d:%02d" % [floori(float(minute) / 60.0), minute % 60]


## Returns { "year", "season_id", "season_name", "day" } with year and day counted from 1.
## Season names and lengths come from data/seasons.json, so mods can change them.
func get_date() -> Dictionary:
	var seasons: Array = DataRegistry.get_list("seasons")
	if seasons.is_empty():
		seasons = FALLBACK_SEASONS
	var year_length := 0
	for season in seasons:
		year_length += maxi(1, int(season.get("days", 1)))
	var day := get_day_number()
	var year := floori(float(day) / year_length)
	var day_in_year := day % year_length
	for season in seasons:
		var days := maxi(1, int(season.get("days", 1)))
		if day_in_year < days:
			return {
				"year": year + 1,
				"season_id": str(season.get("id", "season")),
				"season_name": str(season.get("name", "Season")),
				"day": day_in_year + 1,
			}
		day_in_year -= days
	return { "year": year + 1, "season_id": "season", "season_name": "Season", "day": 1 }


# --- saving --------------------------------------------------------------------

func to_dict() -> Dictionary:
	return { "tick": tick, "speed": speed_level }


func from_dict(data: Dictionary) -> void:
	tick = int(data.get("tick", START_TICK))
	speed_level = clampi(int(data.get("speed", 1)), 0, SPEED_MULTIPLIERS.size() - 1)
	_last_running_speed = maxi(1, speed_level)
	_accumulator = 0.0
	time_set.emit()
	speed_changed.emit(speed_level)
