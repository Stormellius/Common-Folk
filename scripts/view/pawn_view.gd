class_name PawnView
extends Node2D
## Draws one pawn and glides it smoothly between its tiles. The simulation moves a pawn a
## whole tile at a time on clock ticks; this node only follows, so a paused game freezes
## it and 3x speed just makes it follow faster.

const FOLLOW_RATE := 18.0  # how quickly the picture catches up with the simulation
const STRIDE := 0.13       # walk-cycle phase per pixel moved (at 48 px tiles)

var pawn: Pawn
var selected := false:
	set(value):
		if value != selected:
			selected = value
			queue_redraw()
var show_name := true:
	set(value):
		if value != show_name:
			show_name = value
			queue_redraw()

## Names keep the same size on screen at any zoom: the layer sets this to 1 / camera zoom.
var label_scale := 1.0:
	set(value):
		if absf(value - label_scale) > 0.02:
			label_scale = value
			queue_redraw()

var _phase := 0.0
var _drawn_facing := Vector2i(-99, -99)


func setup(new_pawn: Pawn) -> void:
	pawn = new_pawn
	position = _target()
	queue_redraw()


func _target() -> Vector2:
	var here := Vector2(pawn.tile) + Vector2(0.5, 0.5)
	if pawn.is_moving():
		here = here.lerp(Vector2(pawn.step_to) + Vector2(0.5, 0.5), pawn.step_progress())
	return here * MapView.TILE_SIZE


func _process(delta: float) -> void:
	if pawn == null:
		return
	var target := _target()
	var before := position
	if position.distance_to(target) > MapView.TILE_SIZE * 3.0:
		position = target  # teleported (loaded a save): do not glide across the map
	else:
		position = position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	var moved := position.distance_to(before)
	if moved > 0.02:
		_phase += moved * STRIDE * 48.0 / MapView.TILE_SIZE
		queue_redraw()
	elif _phase != 0.0:
		_phase = 0.0
		queue_redraw()
	if pawn.facing != _drawn_facing:
		queue_redraw()


func _draw() -> void:
	if pawn == null:
		return
	_drawn_facing = pawn.facing
	var u := MapView.TILE_SIZE / 48.0
	if selected:
		var ring := PackedVector2Array()
		for i in range(25):
			var a := TAU * i / 24.0
			ring.append(Vector2(cos(a) * 17.0, 7.0 + sin(a) * 10.0) * u)
		draw_polyline(ring, Color(1.0, 0.95, 0.6, 0.95), 2.0)
	PawnArt.draw(self, pawn.look, pawn.facing, u, _phase)
	if show_name:
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, 27.0 * u), 0.0, Vector2(label_scale, label_scale))
		draw_string_outline(font, Vector2(-70.0, 0.0), pawn.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, 4, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(-70.0, 0.0), pawn.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, Color(0.95, 0.94, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
