class_name FireLayer
extends Node2D
## Fire on the map: tongues of flame on every burning tile, a glow that lights up the night, and
## smoke drifting off downwind. It only reads the world's fires (see Fire).

const MAX_LIGHTS := 24
const FLAME_COLORS := [Color(0.85, 0.22, 0.08), Color(0.97, 0.52, 0.12), Color(1.0, 0.82, 0.30)]

var sim: Simulation

var _lights: Dictionary = {}  # tile -> PointLight2D


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	for light in _lights.values():
		light.queue_free()
	_lights.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if sim == null:
		return
	var fires := sim.world.fires
	for tile in _lights.keys():
		if not fires.has(tile):
			_lights[tile].queue_free()
			_lights.erase(tile)
	for tile in fires:
		if not _lights.has(tile) and _lights.size() < MAX_LIGHTS:
			var light := PointLight2D.new()
			light.texture = ObjectView.glow_texture()
			light.color = Color(1.0, 0.58, 0.22)
			light.texture_scale = 3.2 * MapView.TILE_SIZE / (ObjectView.LIGHT_TEXTURE_SIZE * 0.5)
			light.position = Levels.pixel(tile)
			add_child(light)
			_lights[tile] = light
	var t := Time.get_ticks_msec() / 1000.0
	for tile in _lights:
		_lights[tile].visible = Levels.shown(tile)
		_lights[tile].energy = 0.9 + 0.25 * sin(t * 9.0 + tile.x * 1.7 + tile.y * 2.3)
	if not fires.is_empty() or _was_burning:
		queue_redraw()
	_was_burning = not fires.is_empty()


var _was_burning := false


func _draw() -> void:
	if sim == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var u := MapView.TILE_SIZE / 48.0
	for tile in sim.world.fires:
		if not Levels.shown(tile):
			continue
		var burning: Dictionary = sim.world.fires[tile]
		var strength := clampf(float(burning["fuel"]) / 20.0, 0.35, 1.0)
		var centre := Levels.pixel(tile)
		draw_circle(centre, 30.0 * u * strength, Color(1.0, 0.45, 0.10, 0.14))
		for i in 5:  # flame tongues
			var phase := t * (6.0 + i * 1.3) + float(tile.x * 7 + tile.y * 3) + i * 2.1
			var base := centre + Vector2(cos(i * 1.26 + 0.4), sin(i * 1.26 + 0.4)) * 9.0 * u
			var height := maxf(6.0 * u, (20.0 + 11.0 * sin(phase)) * u * strength)
			var width := (8.0 + 1.5 * sin(phase * 0.7)) * u
			for layer in 3:
				var shrink := 1.0 - layer * 0.28
				var tongue := PackedVector2Array([base + Vector2(-width * 0.5 * shrink, 0.0), base + Vector2(sin(phase * 1.3) * 2.0 * u, -height * shrink), base + Vector2(width * 0.5 * shrink, 0.0)])
				draw_colored_polygon(tongue, FLAME_COLORS[layer])
		for i in 3:  # smoke
			var rise := fmod(t * 0.5 + i * 0.33 + float(tile.x) * 0.13, 1.0)
			var drift := Vector2(sin(t + i) * 6.0 + rise * 22.0 * Weather.wind.x, -rise * 46.0) * u
			draw_circle(centre + drift, (6.0 + rise * 10.0) * u, Color(0.16, 0.15, 0.15, 0.30 * (1.0 - rise) * strength))
