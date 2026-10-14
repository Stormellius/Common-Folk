class_name CaravanView
extends Node2D
## Draws one caravan and glides it along the road, like AnimalView does for an animal. Its name shows
## when it is camped and the camera is close.

const FOLLOW_RATE := 14.0
const STRIDE := 0.15

var caravan: Caravan
var sim: Simulation
var show_name := false:
	set(value):
		if value != show_name:
			show_name = value
			queue_redraw()
var label_scale := 1.0
var _phase := 0.0
var _last_riders := -1


func setup(new_caravan: Caravan, new_sim: Simulation) -> void:
	caravan = new_caravan
	sim = new_sim
	position = _target()
	queue_redraw()


func _target() -> Vector2:
	var here := Vector2(caravan.tile) + Vector2(0.5, 0.5)
	if caravan.is_moving():
		here = here.lerp(Vector2(caravan.step_to) + Vector2(0.5, 0.5), caravan.step_progress())
	return here * MapView.TILE_SIZE


func _process(delta: float) -> void:
	if caravan == null:
		return
	var target := _target()
	var before := position
	if position.distance_to(target) > MapView.TILE_SIZE * 3.0:
		position = target
	else:
		position = position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	var moved := position.distance_to(before)
	if moved > 0.02:
		_phase += moved * STRIDE * 48.0 / MapView.TILE_SIZE
		queue_redraw()
	elif _phase != 0.0:
		_phase = 0.0
		queue_redraw()
	if _last_riders != caravan.passengers.size():
		_last_riders = caravan.passengers.size()
		queue_redraw()


func _draw() -> void:
	if caravan == null:
		return
	var u := MapView.TILE_SIZE / 48.0
	var riders: Array = []
	for passenger_id in caravan.passengers:
		var rider := sim.person(passenger_id) if sim != null else null
		if rider != null:
			riders.append(rider.look)
	CaravanArt.draw(self, caravan.facing, u, _phase, Time.get_ticks_msec() / 1000.0, caravan.coat, caravan.looks, riders)
	if show_name and caravan.state == "camped":
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, 30.0 * u), 0.0, Vector2(label_scale, label_scale))
		draw_string_outline(font, Vector2(-100.0, 0.0), caravan.name, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 12, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(-100.0, 0.0), caravan.name, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 12, Color(0.94, 0.86, 0.60))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
