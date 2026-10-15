class_name SmokeLayer
extends Node2D
## Smoke rising from fires that have "smoke": true in objects.json (the hearth), drifting off
## on the wind and thinning out. Drawn over the people, so it rises above walls and heads, and
## lit by the firelight at night like everything else on the map.

const PUFFS := 9
const RISE := 62.0     # how high a puff climbs before it is gone, in units
const CARRY := 58.0    # how far a full wind carries it sideways, in units

var sim: Simulation

var _watched: WorldState
var _sources: Array[Vector2] = []
var _dirty := true
var _clock := 0.0


func bind(new_sim: Simulation) -> void:
	if _watched != null and _watched.tile_changed.is_connected(_on_tile_changed):
		_watched.tile_changed.disconnect(_on_tile_changed)
	sim = new_sim
	_watched = sim.world
	_watched.tile_changed.connect(_on_tile_changed)
	_dirty = true


func _on_tile_changed(_tile: Vector2i) -> void:
	_dirty = true


func _process(delta: float) -> void:
	if sim == null:
		return
	if _dirty:
		_dirty = false
		_sources.clear()
		for placed in sim.world.objects:
			if bool(placed.def().get("smoke", false)):
				_sources.append(Levels.pixel(placed.tile))
	if GameClock.speed_level > 0:
		_clock += delta
	if not _sources.is_empty():
		queue_redraw()


func _draw() -> void:
	var u := MapView.TILE_SIZE / 48.0
	var thin := 1.0 - 0.5 * Weather.wet  # rain beats the smoke down
	for n in _sources.size():
		var base: Vector2 = _sources[n] + Vector2(0.0, -6.0) * u
		for i in PUFFS:
			var age := fposmod(_clock * 0.17 + float(i) / PUFFS + n * 0.37, 1.0)
			var drift := Vector2(Weather.wind.x * CARRY * age + sin(age * 6.0 + i + n) * 4.0, -RISE * age + Weather.wind.y * 25.0 * age)
			var alpha := 0.45 * thin * smoothstep(0.0, 0.10, age) * (1.0 - age)
			draw_circle(base + drift * u, (5.0 + 15.0 * age) * u, Color(0.54, 0.52, 0.50, alpha))
