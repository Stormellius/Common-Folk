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
	if pawn.pose == "lie":
		queue_redraw()  # the floating Zzz drifts
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
	var asleep := pawn.pose == "lie"
	PawnArt.draw(self, pawn.look, pawn.facing, u, _phase, asleep)
	if asleep:
		_draw_blanket_and_zzz(u)
	if show_name:
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, 27.0 * u), 0.0, Vector2(label_scale, label_scale))
		draw_string_outline(font, Vector2(-70.0, 0.0), pawn.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, 4, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(-70.0, 0.0), pawn.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, Color(0.95, 0.94, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A blanket pulled up to the chest, and a little Zzz drifting up from the head.
func _draw_blanket_and_zzz(u: float) -> void:
	draw_rect(Rect2(Vector2(-15.0, -1.0) * u, Vector2(30.0, 17.0) * u), PawnArt.OUTLINE)
	draw_rect(Rect2(Vector2(-14.0, 0.0) * u, Vector2(28.0, 15.0) * u), Color(0.49, 0.31, 0.31))
	draw_line(Vector2(-14.0, 3.0) * u, Vector2(14.0, 3.0) * u, Color(0.64, 0.44, 0.44), maxf(1.0, 1.5 * u))
	var drift := sin(Time.get_ticks_msec() / 500.0) * 2.0
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(11.0, -17.0 + drift) * u, "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(11.0, -17.0 + drift) * u, "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 1.0))
