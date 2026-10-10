class_name PawnArt
extends RefCounted
## Draws a person with code, in the top-down RimWorld manner: a round head over wide
## shoulders, dark outlines, a soft shadow. It is a placeholder that needs no art files.
## To use real sprites later, replace PawnArt.draw() and leave everything else alone.
##
## Everything is measured in "units" where one tile is 48 units wide; `u` scales it to
## the real tile size. Drawing is centered on the pawn's middle, y pointing down.

const HAIR_STYLES := 4  # 0 short, 1 long, 2 shaved, 3 bun
const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const EYE := Color(0.10, 0.08, 0.07)

const SOUTH := 0
const EAST := 1
const NORTH := 2
const WEST := 3


## Which of the four views to draw for a walking direction.
static func facing_kind(facing: Vector2i) -> int:
	if facing.x != 0 and absi(facing.x) >= absi(facing.y):
		return EAST if facing.x > 0 else WEST
	return NORTH if facing.y < 0 else SOUTH


## Draws one pawn on a CanvasItem (call this from its _draw). `phase` is the walk cycle:
## feet and hands swing with sin(phase); pass 0 to stand still.
static func draw(ci: CanvasItem, look: Dictionary, facing: Vector2i, u: float, phase: float) -> void:
	var skin := Color(str(look.get("skin", "#e0ac80")))
	var hair := Color(str(look.get("hair", "#4a3220")))
	var top := Color(str(look.get("top", "#6a7a4a")))
	var bottom := Color(str(look.get("bottom", "#4a3d32")))
	var style := int(look.get("hair_style", 0)) % HAIR_STYLES
	var kind := facing_kind(facing)
	var side := kind == EAST or kind == WEST
	var sx := 1.0 if kind == EAST else (-1.0 if kind == WEST else 0.0)
	var swing := sin(phase)
	var bob := -absf(swing) * 1.3

	_ellipse(ci, Vector2(3.0, 7.0) * u, Vector2(12.0, 6.5) * u, Color(0, 0, 0, 0.22))

	# Feet swing back and forth while walking.
	for s in [-1.0, 1.0]:
		var foot := Vector2(swing * s * 4.5, 11.0) if side else Vector2(s * 4.5, 10.5 + swing * s * 3.0)
		_ellipse_outlined(ci, foot * u, Vector2(3.2, 2.8) * u, bottom.darkened(0.15), u)

	# Shoulders.
	var torso_center := Vector2(0.0, 3.0)
	var torso_radius := Vector2(7.6, 7.2) if side else Vector2(11.0, 7.4)
	_ellipse_outlined(ci, torso_center * u, torso_radius * u, top, 1.1 * u)
	_ellipse(ci, (torso_center + Vector2(-1.5, -1.8)) * u, torso_radius * 0.55 * u, Color(1, 1, 1, 0.12))

	# Hands.
	for s in [-1.0, 1.0]:
		var hand := Vector2(swing * s * 4.5, 4.5) if side else Vector2(s * 11.5, 4.0 + swing * s * 2.0)
		_ellipse_outlined(ci, hand * u, Vector2(2.6, 2.6) * u, skin, 0.9 * u)

	var head := Vector2(sx * 1.8, -5.5 + bob)
	var head_radius := 8.6
	var hair_radius := head_radius + 0.9

	# Long hair hangs behind the head, over the shoulders.
	if style == 1 and kind == NORTH:
		_ellipse_outlined(ci, (head + Vector2(0, 5.0)) * u, Vector2(hair_radius, 10.5) * u, hair, 0.9 * u)
	elif style == 1 and side:
		_ellipse_outlined(ci, (head + Vector2(-sx * 3.5, 4.5)) * u, Vector2(5.0, 8.5) * u, hair, 0.9 * u)

	_ellipse_outlined(ci, head * u, Vector2(head_radius, head_radius) * u, skin, 1.1 * u)

	var hair_color := hair
	if style == 2:  # shaved: just a shadow of stubble
		hair_color = skin.darkened(0.12).lerp(hair, 0.35)
		hair_radius = head_radius + 0.2
	_hair_cap(ci, hair_color, kind, sx, head, hair_radius, u)

	if style == 1 and kind == SOUTH:  # side locks falling in front of the shoulders
		for s in [-1.0, 1.0]:
			_ellipse_outlined(ci, (head + Vector2(s * (hair_radius - 1.4), 4.5)) * u, Vector2(2.8, 7.0) * u, hair, 0.8 * u)
	if style == 3:  # bun
		var bun := head + Vector2(0, -hair_radius + 0.5)
		if side:
			bun = head + Vector2(-sx * (hair_radius - 0.5), -3.0)
		_ellipse_outlined(ci, bun * u, Vector2(3.4, 3.4) * u, hair, 0.8 * u)

	# Eyes: two from the front, one in profile, none from behind.
	if kind == SOUTH:
		for s in [-1.0, 1.0]:
			_ellipse(ci, (head + Vector2(s * 3.3, 1.0)) * u, Vector2(1.3, 1.5) * u, EYE)
	elif side:
		_ellipse(ci, (head + Vector2(sx * 4.6, 0.8)) * u, Vector2(1.3, 1.5) * u, EYE)


## Hair covering the top of the head (and all of it from behind).
static func _hair_cap(ci: CanvasItem, color: Color, kind: int, sx: float, head: Vector2, radius: float, u: float) -> void:
	if kind == NORTH:
		_ellipse_outlined(ci, head * u, Vector2(radius, radius) * u, color, 0.9 * u)
		return
	var points := PackedVector2Array()
	if kind == SOUTH:
		for i in range(13):
			var a := lerpf(-PI * 0.93, -PI * 0.07, i / 12.0)
			points.append(head + Vector2(cos(a), sin(a)) * radius)
		points.append(head + Vector2(radius * 0.9, -radius * 0.18))
		points.append(head + Vector2(0.0, -radius * 0.52))
		points.append(head + Vector2(-radius * 0.9, -radius * 0.18))
	else:
		for i in range(15):
			var a := lerpf(-PI * 0.30, -PI * 1.20, i / 14.0)
			points.append(head + Vector2(cos(a) * sx, sin(a)) * radius)
		points.append(head + Vector2(sx * radius * 0.15, radius * 0.15))
	_polygon_outlined(ci, points, color, u)


static func _ellipse_points(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


static func _ellipse(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	ci.draw_colored_polygon(_ellipse_points(center, radius), color)


static func _ellipse_outlined(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, outline_width: float) -> void:
	ci.draw_colored_polygon(_ellipse_points(center, radius + Vector2(outline_width, outline_width)), OUTLINE)
	ci.draw_colored_polygon(_ellipse_points(center, radius), color)


static func _polygon_outlined(ci: CanvasItem, points: PackedVector2Array, color: Color, u: float) -> void:
	ci.draw_colored_polygon(_scaled(points, u), color)
	var closed := _scaled(points, u)
	closed.append(closed[0])
	ci.draw_polyline(closed, OUTLINE, maxf(1.0, 1.0 * u))


static func _scaled(points: PackedVector2Array, u: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * u)
	return result
