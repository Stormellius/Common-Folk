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

## How far the name is pushed down so it does not cover a neighbor's (set by the layer), in
## screen pixels.
var label_drop := 0.0:
	set(value):
		if absf(value - label_drop) > 0.5:
			label_drop = value
			queue_redraw()

var _phase := 0.0
## Townspeople's names are drawn a little dimmer than your household's.
var townsfolk := false


func setup(new_pawn: Pawn) -> void:
	pawn = new_pawn
	position = _target()
	queue_redraw()


func _target() -> Vector2:
	var here := Vector2(pawn.tile) + Vector2(0.5, 0.5)
	if pawn.is_moving():
		here = here.lerp(Vector2(pawn.step_to) + Vector2(0.5, 0.5), pawn.step_progress())
	if pawn.is_infant() and pawn.pose != "lie":
		here += Vector2(0.2, -0.12)  # on the carer's arm
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
	# Always redraw: people breathe while they stand, and the Zzz, hearts and speech bubbles move.
	queue_redraw()


func _draw() -> void:
	if pawn == null:
		return
	var u := unit()
	if selected:
		var ring := PackedVector2Array()
		for i in range(25):
			var a := TAU * i / 24.0
			ring.append(Vector2(cos(a) * 17.0, 7.0 + sin(a) * 10.0) * u)
		draw_polyline(ring, Color(1.0, 0.95, 0.6, 0.95), 2.0)
	var asleep := pawn.pose == "lie"
	var fallen := pawn.pose == "fallen"
	var breath := Time.get_ticks_msec() / 1000.0 * 1.6 + pawn.id * 2.3
	self_modulate = Color(0.72, 0.72, 0.78) if fallen else Color.WHITE  # the dying grow grey
	if fallen:  # lying on the ground where they fell, a little askew
		draw_set_transform(Vector2(0.0, 4.0) * u, -0.35 if pawn.id % 2 == 0 else 0.35, Vector2.ONE)
	if pawn.mount != 0:  # sitting in the saddle, a little above the ground
		draw_set_transform(Vector2(0.0, -7.0) * u, 0.0, Vector2.ONE)
	PawnArt.draw(self, pawn.look, pawn.facing, u, _phase * 0.5 if pawn.mount != 0 else _phase, asleep or fallen, PawnArt.outfit_for(pawn), breath)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not pawn.carrying.is_empty() and not fallen and not asleep:
		PawnArt.draw_carry(self, pawn.carrying, pawn.facing, u)
	if pawn.tool != "" and not fallen and not asleep:
		PawnArt.draw_tool(self, pawn.tool, pawn.facing, u, Time.get_ticks_msec() / 1000.0 + pawn.id, pawn.job_stage == "using")
	if asleep:
		_draw_blanket_and_zzz(u)
	elif Babies.is_crying(pawn):
		_draw_crying(u)
	elif pawn.pose == "close":
		_draw_hearts(u)
	elif pawn.pose == "talk":
		_draw_speech(u)
	if show_name and not pawn.is_infant():
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, 27.0 * u + label_drop * label_scale), 0.0, Vector2(label_scale, label_scale))
		var label := pawn.display_name + (" (dying)" if fallen else "")
		draw_string_outline(font, Vector2(-90.0, 0.0), label, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 13, 4, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(-90.0, 0.0), label, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 13, Color(0.78, 0.77, 0.72) if townsfolk else Color(0.97, 0.96, 0.92))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Units to pixels for this person: the young are drawn smaller (see PawnArt.BUILDS).
func unit() -> float:
	return MapView.TILE_SIZE / 48.0 * PawnArt.stage_scale(Life.stage_id(pawn) if Life.stage_id(pawn) != "" else ("adult" if pawn.adult else "child"))


## Where the name sits, in world pixels, before any push down.
func label_anchor() -> Vector2:
	return position + Vector2(0.0, 27.0 * unit())


## A blanket pulled up to the chest, and a little Zzz drifting up from the head.
func _draw_blanket_and_zzz(u: float) -> void:
	if not pawn.is_infant():  # (a baby in its cradle is already wrapped up)
		draw_rect(Rect2(Vector2(-15.0, -1.0) * u, Vector2(30.0, 17.0) * u), PawnArt.OUTLINE)
		draw_rect(Rect2(Vector2(-14.0, 0.0) * u, Vector2(28.0, 15.0) * u), Color(0.49, 0.31, 0.31))
		draw_line(Vector2(-14.0, 3.0) * u, Vector2(14.0, 3.0) * u, Color(0.64, 0.44, 0.44), maxf(1.0, 1.5 * u))
	var bump := Pregnancy.bump(pawn)
	if bump > 0.02:  # the belly rounds the blanket
		var mound := Vector2(0.0, 7.0) * u
		var radius := Vector2(5.0 + 3.5 * bump, 3.5 + 2.5 * bump) * u
		draw_colored_polygon(PawnArt._ellipse_points(mound, radius + Vector2(0.9, 0.9) * u), PawnArt.OUTLINE)
		draw_colored_polygon(PawnArt._ellipse_points(mound, radius), Color(0.55, 0.36, 0.36))
	var drift := sin(Time.get_ticks_msec() / 500.0) * 2.0
	var font := ThemeDB.fallback_font
	if Pregnancy.in_labour(pawn):  # no sleep for her: she strains and gasps
		var strain := absf(sin(Time.get_ticks_msec() / 350.0))
		for side in [-1.0, 1.0]:
			draw_line(Vector2(side * 10.0, -14.0) * u, Vector2(side * (13.0 + 2.0 * strain), -18.0 - strain) * u, Color(0.98, 0.95, 0.85, 0.9), maxf(1.0, 1.4 * u))
			draw_line(Vector2(side * 11.0, -9.0) * u, Vector2(side * (15.0 + 2.0 * strain), -10.0) * u, Color(0.98, 0.95, 0.85, 0.9), maxf(1.0, 1.4 * u))
		return
	draw_string_outline(font, Vector2(11.0, -17.0 + drift) * u, "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(11.0, -17.0 + drift) * u, "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 1.0))


## A crying baby: its face screwed up, tears flying and a little wail over its head.
func _draw_crying(u: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for side in [-1.0, 1.0]:
		var fly := fmod(t * 1.8 + (0.5 if side > 0.0 else 0.0), 1.0)
		var drop := Vector2(side * (6.0 + 7.0 * fly), -9.0 - 6.0 * sin(fly * PI)) * u
		draw_circle(drop, 1.7 * u * (1.0 - 0.4 * fly), Color(0.62, 0.80, 1.0, 1.0 - fly))
	var wail := Vector2(-11.0, -24.0 - absf(sin(t * 6.0)) * 2.0) * u
	var font := ThemeDB.fallback_font
	draw_string_outline(font, wail, "waah", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
	draw_string(font, wail, "waah", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.86, 0.80))


## A small speech bubble over the head with three dots that take turns lighting up.
func _draw_speech(u: float) -> void:
	var bubble := Rect2(Vector2(-11.0, -37.0) * u, Vector2(22.0, 13.0) * u)
	draw_rect(bubble.grow(1.2 * u), PawnArt.OUTLINE)
	draw_rect(bubble, Color(0.96, 0.95, 0.90))
	draw_colored_polygon(PackedVector2Array([Vector2(-3.0, -24.5) * u, Vector2(3.0, -24.5) * u, Vector2(-1.0, -20.5) * u]), Color(0.96, 0.95, 0.90))
	var lit := int(Time.get_ticks_msec() / 350.0) % 3
	for i in 3:
		draw_circle(Vector2(-6.0 + 6.0 * i, -30.5) * u, 1.6 * u, Color(0.20, 0.19, 0.17) if i == lit else Color(0.60, 0.58, 0.54))


## Two little hearts drifting up from a pair who are spending time together. Nothing more is shown.
func _draw_hearts(u: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 2:
		var rise := fposmod(t * 0.5 + i * 0.5, 1.0)
		var center := Vector2((6.0 if i == 0 else -6.0) + sin(t * 2.0 + i) * 2.0, -22.0 - rise * 12.0) * u
		var color := Color(0.93, 0.35, 0.45, 1.0 - rise * rise)
		var r := 3.2 * u
		draw_circle(center + Vector2(-r * 0.8, 0.0), r, color)
		draw_circle(center + Vector2(r * 0.8, 0.0), r, color)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-r * 1.75, r * 0.3), center + Vector2(r * 1.75, r * 0.3), center + Vector2(0.0, r * 2.6)]), color)
