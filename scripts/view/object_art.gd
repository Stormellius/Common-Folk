class_name ObjectArt
extends RefCounted
## Draws the things people use (bed, pot, hearth...) with code, in the same hand-inked
## style as the people. Like PawnArt this is a placeholder: swap draw() for sprites later.
## An object whose id has no drawing here (for example one added by a mod) shows up as a crate.
##
## Drawing is centered on the tile; one tile is 48 units wide and `u` scales units to pixels.
## `t` is the time in seconds, for flames and steam; `occupied` is true while someone sleeps in it.

const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const ANIMATED := ["hearth", "cooking_pot"]


static func is_animated(def_id: String) -> bool:
	return def_id in ANIMATED


static func draw(ci: CanvasItem, def_id: String, u: float, t: float, occupied: bool = false) -> void:
	match def_id:
		"bed":
			_bed(ci, u, occupied)
		"cooking_pot":
			_cooking_pot(ci, u, t)
		"hearth":
			_hearth(ci, u, t)
		"wash_basin":
			_wash_basin(ci, u)
		"chamber_pot":
			_chamber_pot(ci, u)
		"lute":
			_lute(ci, u)
		_:
			_crate(ci, u)


static func _bed(ci: CanvasItem, u: float, occupied: bool) -> void:
	_rect(ci, u, -18, -22, 36, 44, Color(0.40, 0.29, 0.18), 1.2)
	_rect(ci, u, -14, -18, 28, 36, Color(0.81, 0.71, 0.49), 0.0)
	for stroke in [[-9, -6, -3, -4], [4, -1, 9, 1], [-8, 4, -2, 6], [3, -11, 8, -9], [-3, 10, 4, 9]]:
		ci.draw_line(Vector2(stroke[0], stroke[1]) * u, Vector2(stroke[2], stroke[3]) * u, Color(0.70, 0.60, 0.38), maxf(1.0, u))
	_rect(ci, u, -9, -16, 18, 9, Color(0.92, 0.90, 0.83), 1.0)
	if not occupied:  # a folded blanket at the foot
		_rect(ci, u, -13, 8, 26, 9, Color(0.49, 0.31, 0.31), 1.0)
		ci.draw_line(Vector2(-12, 11) * u, Vector2(12, 11) * u, Color(0.62, 0.42, 0.42), maxf(1.0, u))


static func _cooking_pot(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 18.0)
	for i in range(8):  # ring of stones
		var a := TAU * i / 8.0 + 0.2
		_ellipse(ci, u, Vector2(cos(a), sin(a)) * 17.0, Vector2(5.0, 4.2), Color(0.55, 0.55, 0.53), 1.0)
	ci.draw_circle(Vector2.ZERO, 14.0 * u, Color(0.16, 0.14, 0.13))
	for flame in range(3):  # small fire licking up around the pot
		var phase := t * 7.0 + flame * 2.1
		var a := TAU * flame / 3.0 + 0.5
		var base := Vector2(cos(a), sin(a)) * 11.0
		_flame(ci, u, base, 7.0 + 2.5 * sin(phase), 3.0)
	ci.draw_circle(Vector2(0, -1) * u, 13.5 * u, OUTLINE)
	ci.draw_circle(Vector2(0, -1) * u, 12.0 * u, Color(0.20, 0.19, 0.18))
	ci.draw_circle(Vector2(0, -1) * u, 10.0 * u, Color(0.35, 0.33, 0.31))
	ci.draw_circle(Vector2(0, -1) * u, 8.0 * u, Color(0.48, 0.32, 0.18))
	ci.draw_circle(Vector2(-2.5, -3.5) * u, 3.0 * u, Color(0.60, 0.43, 0.25, 0.8))
	for puff in range(2):  # steam
		var rise := fmod(t * 0.6 + puff * 0.5, 1.0)
		ci.draw_circle(Vector2(sin(t + puff) * 3.0, -8.0 - rise * 14.0) * u, (3.0 + rise * 3.0) * u, Color(1, 1, 1, 0.22 * (1.0 - rise)))


static func _hearth(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 21.0)
	ci.draw_circle(Vector2.ZERO, 28.0 * u, Color(1.0, 0.55, 0.15, 0.10))
	for i in range(10):
		var a := TAU * i / 10.0
		_ellipse(ci, u, Vector2(cos(a), sin(a)) * 18.0, Vector2(6.0, 5.0), Color(0.55, 0.55, 0.52), 1.1)
	ci.draw_circle(Vector2.ZERO, 14.0 * u, Color(0.17, 0.15, 0.14))
	ci.draw_line(Vector2(-10, 6) * u, Vector2(9, -5) * u, Color(0.33, 0.22, 0.13), 5.0 * u)
	ci.draw_line(Vector2(-9, -6) * u, Vector2(10, 5) * u, Color(0.28, 0.19, 0.11), 5.0 * u)
	_flame(ci, u, Vector2(-5, 2), 15.0 + 4.0 * sin(t * 9.0), 7.0)
	_flame(ci, u, Vector2(5, 3), 13.0 + 4.0 * sin(t * 8.0 + 1.7), 6.5)
	_flame(ci, u, Vector2(0, 0), 20.0 + 5.0 * sin(t * 10.0 + 0.6), 8.5)


static func _wash_basin(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 16.0)
	ci.draw_circle(Vector2.ZERO, 16.0 * u, OUTLINE)
	ci.draw_circle(Vector2.ZERO, 15.0 * u, Color(0.48, 0.35, 0.22))
	ci.draw_circle(Vector2.ZERO, 12.5 * u, Color(0.58, 0.44, 0.29))
	ci.draw_circle(Vector2.ZERO, 10.5 * u, Color(0.37, 0.56, 0.69))
	ci.draw_arc(Vector2(0, 1) * u, 6.0 * u, 0.3, 2.4, 12, Color(0.65, 0.80, 0.88), maxf(1.0, u))
	ci.draw_arc(Vector2(-1, -1) * u, 3.0 * u, 3.4, 5.4, 10, Color(0.65, 0.80, 0.88), maxf(1.0, u))
	_rect(ci, u, 12, 4, 8, 10, Color(0.90, 0.87, 0.79), 0.9)  # a towel on the rim


static func _chamber_pot(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 11.0)
	_ellipse(ci, u, Vector2(0, 1), Vector2(9.0, 8.0), Color(0.58, 0.34, 0.23), 1.2)
	_ellipse(ci, u, Vector2(0, -1), Vector2(9.0, 5.5), Color(0.45, 0.26, 0.17), 1.0)
	_ellipse(ci, u, Vector2(0, -1), Vector2(6.5, 3.5), Color(0.22, 0.13, 0.09), 0.0)
	ci.draw_arc(Vector2(10, 2) * u, 5.0 * u, -1.4, 1.4, 8, OUTLINE, 2.5 * u)
	ci.draw_arc(Vector2(10, 2) * u, 5.0 * u, -1.4, 1.4, 8, Color(0.58, 0.34, 0.23), 1.2 * u)


static func _lute(ci: CanvasItem, u: float) -> void:
	_rect(ci, u, -19, -13, 38, 26, Color(0.50, 0.26, 0.21), 1.2)  # a small rug
	_rect(ci, u, -16, -10, 32, 20, Color(0.62, 0.36, 0.27), 0.0)
	ci.draw_line(Vector2(-16, -6) * u, Vector2(16, -6) * u, Color(0.80, 0.66, 0.40), maxf(1.0, u))
	ci.draw_line(Vector2(-16, 6) * u, Vector2(16, 6) * u, Color(0.80, 0.66, 0.40), maxf(1.0, u))
	# the lute: a round body with a long neck pointing up and to the right
	var neck := PackedVector2Array([Vector2(1, -1), Vector2(13, -11), Vector2(15, -9), Vector2(3, 2)])
	var scaled := PackedVector2Array()
	for point in neck:
		scaled.append(point * u)
	ci.draw_colored_polygon(scaled, Color(0.38, 0.27, 0.16))
	_rect(ci, u, 13, -14, 5, 5, Color(0.28, 0.19, 0.11), 0.8)
	_ellipse(ci, u, Vector2(-4, 3), Vector2(9.0, 10.0), Color(0.72, 0.46, 0.25), 1.2)
	ci.draw_circle(Vector2(-3, 2) * u, 2.8 * u, Color(0.18, 0.11, 0.07))


static func _crate(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 14.0)
	_rect(ci, u, -13, -13, 26, 26, Color(0.54, 0.42, 0.25), 1.2)
	ci.draw_line(Vector2(-13, -13) * u, Vector2(13, 13) * u, Color(0.40, 0.30, 0.17), maxf(1.0, u))
	ci.draw_line(Vector2(13, -13) * u, Vector2(-13, 13) * u, Color(0.40, 0.30, 0.17), maxf(1.0, u))


# --- little shapes -----------------------------------------------------------------

static func _shadow(ci: CanvasItem, u: float, radius: float) -> void:
	_ellipse(ci, u, Vector2(3, 5), Vector2(radius, radius * 0.7), Color(0, 0, 0, 0.20), 0.0)


static func _flame(ci: CanvasItem, u: float, base: Vector2, height: float, width: float) -> void:
	var outer := PackedVector2Array([base + Vector2(-width * 0.5, 0), base + Vector2(0, -height), base + Vector2(width * 0.5, 0), base + Vector2(0, width * 0.3)])
	var inner := PackedVector2Array([base + Vector2(-width * 0.25, 0), base + Vector2(0, -height * 0.55), base + Vector2(width * 0.25, 0), base + Vector2(0, width * 0.15)])
	ci.draw_colored_polygon(_scaled(outer, u), Color(0.95, 0.45, 0.12, 0.95))
	ci.draw_colored_polygon(_scaled(inner, u), Color(1.0, 0.85, 0.35, 0.95))


static func _scaled(points: PackedVector2Array, u: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * u)
	return result


static func _rect(ci: CanvasItem, u: float, x: float, y: float, w: float, h: float, color: Color, outline_width: float) -> void:
	if outline_width > 0.0:
		ci.draw_rect(Rect2(Vector2(x - outline_width, y - outline_width) * u, Vector2(w + 2.0 * outline_width, h + 2.0 * outline_width) * u), OUTLINE)
	ci.draw_rect(Rect2(Vector2(x, y) * u, Vector2(w, h) * u), color)


static func _ellipse(ci: CanvasItem, u: float, center: Vector2, radius: Vector2, color: Color, outline_width: float) -> void:
	if outline_width > 0.0:
		ci.draw_colored_polygon(PawnArt._ellipse_points(center * u, (radius + Vector2(outline_width, outline_width)) * u), OUTLINE)
	ci.draw_colored_polygon(PawnArt._ellipse_points(center * u, radius * u), color)
