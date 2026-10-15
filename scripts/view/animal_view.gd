class_name AnimalView
extends Node2D
## Draws one animal and glides it between its tiles, like PawnView does for a person. A ridden animal
## takes the place of its rider's picture so the two move as one.

const FOLLOW_RATE := 18.0
const STRIDE := 0.16

var animal: Animal
## Where to be instead of the animal's own tile (the rider's picture), or null.
var follow: Node2D = null
var show_name := false:
	set(value):
		if value != show_name:
			show_name = value
			queue_redraw()
var label_scale := 1.0
var _phase := 0.0
var _last_facing := Vector2i(1, 0)


func setup(new_animal: Animal) -> void:
	animal = new_animal
	position = _target()
	z_index = 0
	queue_redraw()


func _target() -> Vector2:
	var here := Vector2(animal.tile) + Vector2(0.5, 0.5)
	if animal.is_moving():
		here = here.lerp(Vector2(animal.step_to) + Vector2(0.5, 0.5), animal.step_progress())
	return here * MapView.TILE_SIZE


func _process(delta: float) -> void:
	if animal == null:
		return
	var target := follow.position if follow != null else _target()
	var before := position
	if position.distance_to(target) > MapView.TILE_SIZE * 3.0 or follow != null:
		position = target  # a ridden animal does not trail its rider
	else:
		position = position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	var moved := position.distance_to(before)
	z_index = -1 if follow != null else 0  # the rider sits above the animal
	if moved > 0.02:
		_phase += moved * STRIDE * 48.0 / MapView.TILE_SIZE
		queue_redraw()
	elif _phase != 0.0:
		_phase = 0.0
		queue_redraw()
	if animal.facing != _last_facing:
		_last_facing = animal.facing
		queue_redraw()


func _draw() -> void:
	if animal == null:
		return
	var u := MapView.TILE_SIZE / 48.0
	AnimalArt.draw(self, animal.kind, animal.coat, animal.facing, u, _phase, Time.get_ticks_msec() / 1000.0)
	if show_name and animal.name != "" and animal.owner == "household":
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, 22.0 * u), 0.0, Vector2(label_scale, label_scale))
		draw_string_outline(font, Vector2(-60.0, 0.0), animal.name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-60.0, 0.0), animal.name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color(0.92, 0.88, 0.74))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
