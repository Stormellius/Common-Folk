class_name Weather
extends CanvasLayer
## The sky over the town. A seeded roll each day (the same seed always has the same weather)
## picks clear, cloudy or wet: rain, or snow in a season with "snow" of 0.5 or more. This layer
## draws the falling rain or snow over the screen, and fireflies on summer nights. It is only
## a look: needs and work do not notice the weather.
##
## The chances come from data/seasons.json: "rain_chance" and "cloud_chance" per day, and
## "fireflies": true for a season with fireflies. Other views read the statics below: DayNight
## dims the day by `gloom`, smoke and cloud shadows drift with `wind`, and the cloud shadows
## thicken with `cover`.

static var cover := 0.25              # how much of the sky is cloud, 0 to 1
static var gloom := 0.0               # how much heavy cloud dims the day, 0 to 1
static var wind := Vector2(0.8, 0.1)  # direction and strength (about 0.4 to 1.1)
static var wet := 0.0                 # rain or snow falling now, 0 to 1
static var snowing := false

const DROPS := 420
const FLAKES := 320
const SPLASHES := 60
const FIREFLY_CELL := 2     # one firefly at most in each square of this many tiles
const FIREFLY_COLOR := Color(0.78, 1.0, 0.38)
const RAMP_MINUTES := 60.0  # rain and snow build up and die away over this long

var world_seed := 0

var _world: WorldState
var _forced := ""
var _days := {}             # day number -> its weather, worked out once
var _clock := 0.0           # seconds of unpaused play, for the animation
var _fireflies := 0.0       # 0 to 1, how many are out
var _fall := Node2D.new()   # rain and snow
var _glow := Node2D.new()   # fireflies, drawn as added light


func _ready() -> void:
	layer = 5  # over the map, under the HUD
	add_child(_fall)
	add_child(_glow)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_fall.draw.connect(_draw_fall)
	_glow.draw.connect(_draw_fireflies)
	GameClock.ticked.connect(func(_tick: int) -> void: _update())
	GameClock.time_set.connect(_update)


func bind(world: WorldState) -> void:
	_world = world
	world_seed = world.world_seed
	_days.clear()
	_update()


## For screenshots and testing: "clear", "cloudy", "rain" or "snow" from now on, or "" to go
## back to the seeded weather.
func force(kind: String) -> void:
	_forced = kind
	_days.clear()
	_update()


func _process(delta: float) -> void:
	if GameClock.speed_level > 0:
		_clock += delta
	_fall.queue_redraw()
	_glow.queue_redraw()


func _update() -> void:
	var day := GameClock.get_day_number()
	var minute := GameClock.get_minute_of_day()
	var now := day * GameClock.MINUTES_PER_DAY + minute
	var today := _day_weather(day)
	var tomorrow := _day_weather(day + 1)
	var blend := smoothstep(21.0 * 60.0, 24.0 * 60.0, float(minute))  # tomorrow's sky moves in before midnight
	wet = maxf(_spell(_day_weather(day - 1), now), _spell(today, now))
	snowing = bool(today["snow"])
	cover = maxf(lerpf(today["cover"], tomorrow["cover"], blend), 0.9 * wet)
	gloom = clampf((cover - 0.45) / 0.55, 0.0, 1.0)
	wind = (today["wind"] as Vector2).lerp(tomorrow["wind"], blend)
	var fireflies := bool(_season(day).get("fireflies", false))
	_fireflies = (1.0 - wet) * smoothstep(0.5, 0.9, DayNight.darkness) if fireflies else 0.0


## One day's sky: its cloud cover, its wind and, on a wet day, when the rain or snow falls
## (in minutes from the start of the game; it may run on past midnight).
func _day_weather(day: int) -> Dictionary:
	if not _days.has(day):
		if _days.size() > 8:
			_days.clear()
		_days[day] = _roll_day(day)
	return _days[day]


func _roll_day(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day, "weather"])
	var season := _season(day)
	var roll := rng.randf()
	var rain := float(season.get("rain_chance", 0.0))
	var kind := "wet" if roll < rain else ("cloudy" if roll < rain + float(season.get("cloud_chance", 0.0)) else "clear")
	var angle := rng.randf_range(-0.7, 0.7) + (PI if rng.randf() < 0.25 else 0.0)
	var weather := {
		"cover": rng.randf_range(0.20, 0.35),
		"wind": Vector2(cos(angle), sin(angle)) * rng.randf_range(0.4, 1.1),
		"start": 0, "end": 0,
		"snow": float(season.get("snow", 0.0)) >= 0.5,
	}
	var start := day * GameClock.MINUTES_PER_DAY + rng.randi_range(0, 20) * 60
	var hours := rng.randi_range(3, 10)
	if _forced != "":
		kind = "wet" if _forced in ["rain", "snow"] else _forced
		weather["snow"] = _forced == "snow"
		start = (day - 1) * GameClock.MINUTES_PER_DAY
		hours = 48
	if kind == "cloudy":
		weather["cover"] = rng.randf_range(0.55, 0.70)
	elif kind == "wet":
		weather["cover"] = 0.7
		weather["start"] = start
		weather["end"] = start + hours * 60
	return weather


## How hard a wet spell is falling at minute `now`: 0 outside it, easing in and out at the ends.
func _spell(weather: Dictionary, now: int) -> float:
	var start := float(weather["start"])
	var end := float(weather["end"])
	if end <= start:
		return 0.0
	return smoothstep(start, start + RAMP_MINUTES, now) * (1.0 - smoothstep(end - RAMP_MINUTES, end, now))


func _season(day: int) -> Dictionary:
	var seasons: Array = DataRegistry.get_list("seasons")
	if seasons.is_empty():
		return {}
	var year := 0
	for season in seasons:
		year += int(season.get("days", 15))
	var left := posmod(day, maxi(year, 1))
	for season in seasons:
		left -= int(season.get("days", 15))
		if left < 0:
			return season
	return seasons[-1]


# --- drawing -----------------------------------------------------------------------

## Rain streaks slanting with the wind and small splashes, or snowflakes drifting down. Drawn
## on the screen, tinted by the time of day like the map beneath.
func _draw_fall() -> void:
	if wet < 0.01:
		return
	var size := get_viewport().get_visible_rect().size
	var tint := DayNight.tint
	if snowing:
		for i in int(FLAKES * wet):
			var speed := 35.0 + 45.0 * ObjectArt.hash01(i, 2, 307)
			var sway := sin(_clock * (0.7 + ObjectArt.hash01(i, 4, 307)) + i) * 14.0
			var y := fposmod(ObjectArt.hash01(i, 1, 307) * size.y + _clock * speed, size.y + 40.0) - 20.0
			var x := fposmod(ObjectArt.hash01(i, 3, 307) * size.x + _clock * wind.x * 30.0 + sway, size.x + 40.0) - 20.0
			var radius := 1.1 + 1.7 * ObjectArt.hash01(i, 5, 307)
			_fall.draw_circle(Vector2(x, y), radius + 0.8, Color(tint.r, tint.g, tint.b, 0.25))
			_fall.draw_circle(Vector2(x, y), radius, Color(0.96 * tint.r, 0.97 * tint.g, tint.b, 0.85))
		return
	var slant := Vector2(wind.x * 0.35, 1.0).normalized()
	var streak := Color(0.78 * tint.r, 0.84 * tint.g, 0.95 * tint.b, 0.38)
	for i in int(DROPS * wet):
		var speed := 900.0 + 500.0 * ObjectArt.hash01(i, 2, 311)
		var length := 14.0 + 12.0 * ObjectArt.hash01(i, 3, 311)
		var y := fposmod(ObjectArt.hash01(i, 1, 311) * (size.y + 100.0) + _clock * speed, size.y + 100.0) - 50.0
		var x := fposmod(ObjectArt.hash01(i, 4, 311) * (size.x + 200.0) + y * slant.x / slant.y, size.x + 200.0) - 100.0
		_fall.draw_line(Vector2(x, y), Vector2(x, y) - slant * length, streak, 1.2)
	var splash := Color(0.80 * tint.r, 0.86 * tint.g, 0.95 * tint.b, 1.0)
	for i in int(SPLASHES * wet):
		var cycle := _clock * 2.2 + ObjectArt.hash01(i, 6, 313)
		var age := fposmod(cycle, 1.0)
		var round_number := floori(cycle)
		var at := Vector2(ObjectArt.hash01(i, round_number, 317) * size.x, ObjectArt.hash01(round_number, i, 331) * size.y)
		splash.a = 0.35 * (1.0 - age)
		_fall.draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		_fall.draw_arc(Vector2.ZERO, 2.0 + age * 7.0, 0.0, TAU, 12, splash, 1.0)
	_fall.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Fireflies drifting over the grass and the woods on summer nights, blinking on and off. They
## belong to the ground (they stay put as the camera moves) but glow on top of the dark.
func _draw_fireflies() -> void:
	if _fireflies < 0.01 or _world == null:
		return
	var to_screen := get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	if zoom < 0.35:
		return  # too far out to see them
	var tile := float(MapView.TILE_SIZE)
	var view := Rect2(-to_screen.origin / zoom, get_viewport().get_visible_rect().size / zoom)
	var cell := tile * FIREFLY_CELL
	var radius := clampf(zoom, 0.6, 1.6)
	for cy in range(floori(view.position.y / cell) - 1, ceili(view.end.y / cell) + 1):
		for cx in range(floori(view.position.x / cell) - 1, ceili(view.end.x / cell) + 1):
			var h := ObjectArt.hash01(cx, cy, 401)
			if h > 0.75 * _fireflies:
				continue
			var spot := Vector2i(cx * FIREFLY_CELL + int(ObjectArt.hash01(cx, cy, 409) * FIREFLY_CELL), cy * FIREFLY_CELL + int(ObjectArt.hash01(cx, cy, 419) * FIREFLY_CELL))
			if not _world.in_bounds(spot.x, spot.y) or _world.object_at(spot) != null or not _world.get_tile_id(spot.x, spot.y) in ["grass", "forest"]:
				continue
			var blink := pow(maxf(0.0, sin(_clock * 1.1 + h * 300.0)), 3.0)
			if blink < 0.02:
				continue
			var wander := Vector2(sin(_clock * 0.6 + h * 40.0), cos(_clock * 0.45 + h * 70.0)) * 0.9 \
				+ Vector2(sin(_clock * 1.7 + h * 9.0), cos(_clock * 1.3 + h * 13.0)) * 0.15
			var at := to_screen * ((Vector2(spot) + Vector2(0.5, 0.5) + wander) * tile)
			_glow.draw_circle(at, 10.0 * radius, Color(FIREFLY_COLOR, 0.07 * blink))
			_glow.draw_circle(at, 4.0 * radius, Color(FIREFLY_COLOR, 0.30 * blink))
			_glow.draw_circle(at, 1.7 * radius, Color(1.0, 1.0, 0.8, 0.95 * blink))
