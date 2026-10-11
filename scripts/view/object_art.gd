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


## `connections` is a bitmask of neighbors that a wall or door should join up with
## (1 north, 2 east, 4 south, 8 west; see WorldState.connection_mask).
static func draw(ci: CanvasItem, def_id: String, u: float, t: float, occupied: bool = false, connections: int = 0) -> void:
	match def_id:
		"wall":
			_wall(ci, u, connections, Color(0.47, 0.34, 0.22), Color(0.33, 0.23, 0.14))
		"stone_wall":
			_wall(ci, u, connections, Color(0.56, 0.57, 0.58), Color(0.39, 0.40, 0.41))
		"door":
			_door(ci, u, connections)
		"grave":
			_grave(ci, u)
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
		"table", "meal_table":
			_table(ci, u)
		"notice_board":
			_notice_board(ci, u)
		"counter":
			_counter(ci, u)
		"shelf", "food_shelf":
			_shelf(ci, u)
		"barrel", "ale_barrel":
			_barrel(ci, u)
		"bench":
			_bench(ci, u)
		"well":
			_well(ci, u)
		"pew":
			_pew(ci, u)
		"watch_post":
			_watch_post(ci, u)
		"altar":
			_altar(ci, u)
		"sickbed":
			_sickbed(ci, u, occupied)
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


## A wall seen from above: a post with a beam running to each connected neighbor, so a row of
## them reads as one wall and corners and crossings join up.
static func _wall_pieces(connections: int) -> Array[Rect2]:
	var half := 16.0
	var pieces: Array[Rect2] = [Rect2(-half, -half, half * 2.0, half * 2.0)]
	if connections & 1:
		pieces.append(Rect2(-half, -24.0, half * 2.0, 24.0 - half))
	if connections & 2:
		pieces.append(Rect2(half, -half, 24.0 - half, half * 2.0))
	if connections & 4:
		pieces.append(Rect2(-half, half, half * 2.0, 24.0 - half))
	if connections & 8:
		pieces.append(Rect2(-24.0, -half, 24.0 - half, half * 2.0))
	return pieces


## Outlines first, grown only sideways at the ends that meet a neighbor, so there is no seam.
static func _wall_outline(ci: CanvasItem, u: float, pieces: Array[Rect2], connections: int) -> void:
	for piece in pieces:
		var grown := piece.grow(1.5)
		if connections & 1 and piece.position.y <= -24.0:
			grown = Rect2(grown.position.x, -24.0, grown.size.x, grown.end.y + 24.0)
		if connections & 2 and piece.end.x >= 24.0:
			grown = Rect2(grown.position.x, grown.position.y, 24.0 - grown.position.x, grown.size.y)
		if connections & 4 and piece.end.y >= 24.0:
			grown = Rect2(grown.position.x, grown.position.y, grown.size.x, 24.0 - grown.position.y)
		if connections & 8 and piece.position.x <= -24.0:
			grown = Rect2(-24.0, grown.position.y, grown.end.x + 24.0, grown.size.y)
		ci.draw_rect(Rect2(grown.position * u, grown.size * u), OUTLINE)


static func _wall(ci: CanvasItem, u: float, connections: int, fill: Color, line: Color) -> void:
	var pieces := _wall_pieces(connections)
	_wall_outline(ci, u, pieces, connections)
	for piece in pieces:
		ci.draw_rect(Rect2(piece.position * u, piece.size * u), fill)
	# a lighter cap on the post and a dark line along each beam
	ci.draw_rect(Rect2(Vector2(-10, -10) * u, Vector2(20, 20) * u), fill.lightened(0.14))
	ci.draw_rect(Rect2(Vector2(-10, -10) * u, Vector2(20, 20) * u), line, false, maxf(1.0, u))
	for piece in pieces.slice(1):
		var middle: Vector2 = piece.get_center()
		if piece.size.x > piece.size.y:
			ci.draw_line(Vector2(piece.position.x, middle.y) * u, Vector2(piece.end.x, middle.y) * u, line, maxf(1.0, u))
		else:
			ci.draw_line(Vector2(middle.x, piece.position.y) * u, Vector2(middle.x, piece.end.y) * u, line, maxf(1.0, u))


## A door is a gap in the wall with a plank slab; people walk straight through it.
static func _door(ci: CanvasItem, u: float, connections: int) -> void:
	var timber := Color(0.47, 0.34, 0.22)
	var line := Color(0.33, 0.23, 0.14)
	var vertical := (connections & 5) != 0 and (connections & 10) == 0
	var along_wall := connections & ~(5 if not vertical else 10)
	var pieces := _wall_pieces(along_wall)
	_wall_outline(ci, u, pieces, along_wall)
	for piece in pieces:
		ci.draw_rect(Rect2(piece.position * u, piece.size * u), timber)
	var slab := Rect2(-6, -19, 12, 38) if vertical else Rect2(-19, -6, 38, 12)
	ci.draw_rect(Rect2(slab.grow(1.5).position * u, slab.grow(1.5).size * u), OUTLINE)
	ci.draw_rect(Rect2(slab.position * u, slab.size * u), Color(0.64, 0.47, 0.29))
	if vertical:
		ci.draw_line(Vector2(0, -19) * u, Vector2(0, 19) * u, line, maxf(1.0, u))
		ci.draw_circle(Vector2(2.5, 11) * u, 1.6 * u, Color(0.16, 0.12, 0.08))
	else:
		ci.draw_line(Vector2(-19, 0) * u, Vector2(19, 0) * u, line, maxf(1.0, u))
		ci.draw_circle(Vector2(11, 2.5) * u, 1.6 * u, Color(0.16, 0.12, 0.08))


static func _grave(ci: CanvasItem, u: float) -> void:
	_ellipse(ci, u, Vector2(0, 5), Vector2(15.0, 10.0), Color(0.33, 0.25, 0.18), 1.2)  # a low mound
	_ellipse(ci, u, Vector2(0, 4), Vector2(11.0, 6.5), Color(0.41, 0.31, 0.22), 0.0)
	_rect(ci, u, -2, -15, 4, 18, Color(0.45, 0.33, 0.21), 1.0)  # a wooden cross
	_rect(ci, u, -7, -10, 14, 4, Color(0.45, 0.33, 0.21), 1.0)


static func _table(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 18.0)
	_rect(ci, u, -19, -16, 38, 32, Color(0.55, 0.40, 0.25), 1.3)
	_rect(ci, u, -16, -13, 32, 26, Color(0.66, 0.50, 0.32), 0.0)
	for y in [-4, 4]:
		ci.draw_line(Vector2(-16, y) * u, Vector2(16, y) * u, Color(0.52, 0.38, 0.23), maxf(1.0, u))
	ci.draw_circle(Vector2(-6, -3) * u, 3.4 * u, OUTLINE)  # a mug and a loaf
	ci.draw_circle(Vector2(-6, -3) * u, 2.6 * u, Color(0.70, 0.62, 0.50))
	_ellipse(ci, u, Vector2(7, 5), Vector2(5.5, 3.5), Color(0.74, 0.56, 0.30), 0.9)


## Runs the full width of the tile, so a row of counters reads as one long counter.
static func _counter(ci: CanvasItem, u: float) -> void:
	ci.draw_rect(Rect2(Vector2(-24, -15) * u, Vector2(48, 30) * u), OUTLINE)
	ci.draw_rect(Rect2(Vector2(-24, -13.5) * u, Vector2(48, 27) * u), Color(0.45, 0.31, 0.19))
	ci.draw_rect(Rect2(Vector2(-24, -13.5) * u, Vector2(48, 17) * u), Color(0.66, 0.50, 0.32))
	ci.draw_line(Vector2(-24, 4) * u, Vector2(24, 4) * u, Color(0.32, 0.22, 0.13), maxf(1.0, u))


static func _shelf(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 18.0)
	_rect(ci, u, -20, -14, 40, 28, Color(0.42, 0.30, 0.19), 1.3)
	_rect(ci, u, -17, -11, 34, 22, Color(0.30, 0.21, 0.13), 0.0)
	ci.draw_line(Vector2(-17, 0) * u, Vector2(17, 0) * u, Color(0.50, 0.37, 0.23), 2.0 * u)
	var colors := [Color(0.72, 0.30, 0.25), Color(0.80, 0.68, 0.35), Color(0.35, 0.50, 0.62), Color(0.55, 0.62, 0.35)]
	for i in 4:
		ci.draw_rect(Rect2(Vector2(-15 + i * 8.5, -9) * u, Vector2(6, 7) * u), colors[i])
		ci.draw_rect(Rect2(Vector2(-15 + (3 - i) * 8.5, 3) * u, Vector2(6, 6) * u), colors[(i + 1) % 4])


static func _barrel(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 15.0)
	ci.draw_circle(Vector2.ZERO, 16.0 * u, OUTLINE)
	ci.draw_circle(Vector2.ZERO, 14.5 * u, Color(0.50, 0.35, 0.20))
	ci.draw_arc(Vector2.ZERO, 11.0 * u, 0.0, TAU, 24, Color(0.30, 0.22, 0.14), 1.5 * u)
	ci.draw_circle(Vector2.ZERO, 9.5 * u, Color(0.60, 0.44, 0.26))
	ci.draw_line(Vector2(-9, -2) * u, Vector2(9, -2) * u, Color(0.46, 0.33, 0.19), maxf(1.0, u))
	ci.draw_line(Vector2(-9, 3) * u, Vector2(9, 3) * u, Color(0.46, 0.33, 0.19), maxf(1.0, u))


static func _bench(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 16.0)
	_rect(ci, u, -20, -8, 40, 16, Color(0.52, 0.38, 0.23), 1.2)
	_rect(ci, u, -18, -6, 36, 8, Color(0.68, 0.52, 0.33), 0.0)
	for x in [-14, 12]:
		_rect(ci, u, x, 4, 4, 5, Color(0.33, 0.23, 0.14), 0.8)


## A tall timber post with a lantern on a little platform.
static func _watch_post(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 18.0)
	_rect(ci, u, -16, -16, 32, 32, Color(0.40, 0.29, 0.18), 1.4)          # the platform seen from above
	_rect(ci, u, -13, -13, 26, 26, Color(0.56, 0.42, 0.26), 0.0)
	for plank in [-4, 4]:
		ci.draw_line(Vector2(-13, plank) * u, Vector2(13, plank) * u, Color(0.42, 0.31, 0.19), maxf(1.0, u))
	_rect(ci, u, -4, -4, 8, 8, Color(0.30, 0.21, 0.13), 1.0)               # the post
	ci.draw_circle(Vector2(0, 0), 3.0 * u, Color(1.0, 0.82, 0.35))         # the lantern
	for corner in [Vector2(-14, -14), Vector2(14, -14), Vector2(-14, 14), Vector2(14, 14)]:
		_rect(ci, u, corner.x - 2, corner.y - 2, 4, 4, Color(0.30, 0.21, 0.13), 0.8)


static func _pew(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 16.0)
	_rect(ci, u, -20, -9, 40, 18, Color(0.42, 0.28, 0.17), 1.2)
	_rect(ci, u, -18, -7, 36, 6, Color(0.55, 0.38, 0.23), 0.0)  # the back rail
	_rect(ci, u, -18, 0, 36, 7, Color(0.62, 0.45, 0.28), 0.0)   # the seat
	for x in [-17, 13]:
		_rect(ci, u, x, -9, 4, 18, Color(0.33, 0.22, 0.13), 0.8)


static func _altar(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 20.0)
	_rect(ci, u, -19, -14, 38, 28, Color(0.58, 0.58, 0.56), 1.4)
	_rect(ci, u, -19, -14, 38, 6, Color(0.92, 0.90, 0.84), 0.0)   # the cloth
	_rect(ci, u, -2, -22, 4, 18, Color(0.88, 0.76, 0.35), 1.0)    # a cross, upright
	_rect(ci, u, -7, -17, 14, 4, Color(0.88, 0.76, 0.35), 1.0)
	for x in [-14, 10]:
		_rect(ci, u, x, -8, 4, 8, Color(0.93, 0.89, 0.72), 0.8)  # candles


static func _sickbed(ci: CanvasItem, u: float, occupied: bool) -> void:
	_rect(ci, u, -18, -22, 36, 44, Color(0.45, 0.45, 0.47), 1.2)
	_rect(ci, u, -14, -18, 28, 36, Color(0.88, 0.89, 0.86), 0.0)
	_rect(ci, u, -9, -16, 18, 9, Color(0.97, 0.97, 0.95), 1.0)
	if not occupied:
		_rect(ci, u, -13, 6, 26, 11, Color(0.42, 0.55, 0.62), 1.0)
	ci.draw_line(Vector2(-4, 12) * u, Vector2(4, 12) * u, Color(0.80, 0.30, 0.28), maxf(2.0, 2.0 * u))
	ci.draw_line(Vector2(0, 8) * u, Vector2(0, 16) * u, Color(0.80, 0.30, 0.28), maxf(2.0, 2.0 * u))


static func _well(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 22.0)
	ci.draw_circle(Vector2.ZERO, 22.0 * u, OUTLINE)
	for i in 12:
		var a := TAU * i / 12.0
		_ellipse(ci, u, Vector2(cos(a), sin(a)) * 16.0, Vector2(6.5, 5.5), Color(0.58, 0.58, 0.56) if i % 2 == 0 else Color(0.50, 0.50, 0.49), 1.0)
	ci.draw_circle(Vector2.ZERO, 11.0 * u, Color(0.10, 0.12, 0.14))
	ci.draw_circle(Vector2.ZERO, 9.0 * u, Color(0.22, 0.38, 0.52))
	ci.draw_arc(Vector2(-1, -1) * u, 5.0 * u, 3.4, 5.6, 10, Color(0.55, 0.72, 0.84), maxf(1.0, u))


## A board on two posts with pinned notes.
static func _notice_board(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 18.0)
	_rect(ci, u, -19, -10, 38, 20, Color(0.38, 0.27, 0.17), 1.3)
	_rect(ci, u, -16, -7, 32, 14, Color(0.62, 0.48, 0.30), 0.0)
	for note in [[-13, -5, 8, 6, Color(0.92, 0.89, 0.78)], [-2, -6, 7, 7, Color(0.88, 0.84, 0.70)], [8, -4, 6, 5, Color(0.94, 0.91, 0.82)]]:
		_rect(ci, u, note[0], note[1], note[2], note[3], note[4], 0.7)
	for post in [-16, 12]:
		_rect(ci, u, post, 10, 4, 6, Color(0.30, 0.21, 0.13), 0.8)


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
