class_name CloudShadows
extends Node2D
## Shadows of clouds drifting over the town on the wind: a few on a clear day, many under a
## cloudy sky, none at night. Drawn over everything on the ground and under the cursor. The
## clouds only move while the game runs.

const SHADER := preload("res://shaders/clouds.gdshader")
const DRIFT_RATE := 0.012  # how fast the wind carries them (cloud widths per second at full wind)
const STRENGTH := 0.30     # darkness of a shadow on a clear day

var _material := ShaderMaterial.new()
var _size := Vector2.ZERO
var _drift := Vector2.ZERO


func _ready() -> void:
	_material.shader = SHADER
	_material.set_shader_parameter("tile_px", float(MapView.TILE_SIZE))
	material = _material


func set_world(world: WorldState) -> void:
	_size = Vector2(world.width, world.height) * MapView.TILE_SIZE
	queue_redraw()


func _process(delta: float) -> void:
	if GameClock.speed_level > 0:
		_drift += Weather.wind * delta * DRIFT_RATE
	_material.set_shader_parameter("drift", _drift)
	_material.set_shader_parameter("coverage", Weather.cover)
	# Under a heavy sky the shadows run together into general gloom (DayNight handles that).
	var strength := STRENGTH * (1.0 - DayNight.darkness) * (1.0 - 0.6 * Weather.gloom)
	_material.set_shader_parameter("strength", strength)
	visible = strength > 0.005  # no work at night


func _draw() -> void:
	if _size != Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, _size), Color.WHITE)
