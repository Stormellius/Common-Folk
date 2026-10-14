class_name ObjectArt
extends RefCounted
## Draws the things people use (bed, pot, hearth...) with code, in the same hand-inked
## style as the people. Like PawnArt this is a placeholder: swap draw() for sprites later.
## An object whose id has no drawing here (for example one added by a mod) shows up as a crate.
##
## Drawing is centered on the tile; one tile is 48 units wide and `u` scales units to pixels.
## `t` is the time in seconds, for flames and steam; `occupied` is true while someone sleeps in it.

const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const ANIMATED := ["hearth", "cooking_pot", "watch_post", "altar", "forge"]
## How tall the south face of a wall looks, in units. Light comes from the top-left, as in the
## terrain shader, so a wall shows a lit top and a shaded face to the south.
const WALL_FACE := 12.0
const TIMBER := Color(0.50, 0.36, 0.23)
const STONE := Color(0.57, 0.57, 0.56)


static func is_animated(def_id: String) -> bool:
	return def_id in ANIMATED


## How far the crops have got: 0 bare earth, 1 seedlings, 2 growing, 3 ripe, 4 stubble. They are
## sown in spring, ripen through summer and autumn, and the land lies bare in winter.
static func crop_stage() -> int:
	var seasons: Array = DataRegistry.get_list("seasons")
	if seasons.is_empty():
		return 3
	var position := GameClock.get_season_position()
	var progress := float(position["progress"])
	match str(seasons[position["index"]].get("id", "")):
		"spring":
			return 0 if progress < 0.25 else 1
		"summer":
			return 2 if progress < 0.6 else 3
		"autumn":
			return 3 if progress < 0.55 else 4
	return 0


## `connections` is a bitmask of neighbors that a wall or door should join up with
## (1 north, 2 east, 4 south, 8 west; see WorldState.connection_mask). `cell` is the tile it
## stands on; it only varies the stonework and planks so neighbors do not look stamped.
static func draw(ci: CanvasItem, def_id: String, u: float, t: float, occupied: bool = false, connections: int = 0, cell: Vector2i = Vector2i.ZERO) -> void:
	match def_id:
		"wall":
			_wall(ci, u, connections, cell, false)
		"stone_wall":
			_wall(ci, u, connections, cell, true)
		"door":
			_door(ci, u, connections, cell)
		"grave":
			_grave(ci, u)
		"bed":
			_bed(ci, u, occupied)
		"cradle":
			_cradle(ci, u)
		"chopping_block":
			_chopping_block(ci, u, cell)
		"quarry_face":
			_quarry_face(ci, u, cell)
		"field_plot":
			_field_plot(ci, u, cell)
		"herb_bed":
			_herb_bed(ci, u, cell)
		"fishing_spot":
			_fishing_spot(ci, u)
		"lantern_post":
			_lantern_post(ci, u, t)
		"flower_bed":
			_flower_bed(ci, u, cell)
		"bush":
			_bush(ci, u, cell)
		"haystack":
			_haystack(ci, u, cell)
		"woodpile":
			_woodpile(ci, u, cell)
		"cart":
			_cart(ci, u, cell)
		"market_stall":
			_market_stall(ci, u, cell)
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
			_watch_post(ci, u, t)
		"altar":
			_altar(ci, u, t)
		"sickbed":
			_sickbed(ci, u, occupied)
		"forge":
			_forge(ci, u, t)
		"workbench":
			_workbench(ci, u)
		"tool_rack":
			_tool_rack(ci, u)
		_:
			_crate(ci, u)


static func _bed(ci: CanvasItem, u: float, occupied: bool) -> void:
	_shadow(ci, u, 20.0)
	_rect(ci, u, -18, -22, 36, 44, Color(0.40, 0.29, 0.18), 1.2)
	_rect(ci, u, -14, -18, 28, 36, Color(0.81, 0.71, 0.49), 0.0)
	for stroke in [[-9, -6, -3, -4], [4, -1, 9, 1], [-8, 4, -2, 6], [3, -11, 8, -9], [-3, 10, 4, 9]]:
		ci.draw_line(Vector2(stroke[0], stroke[1]) * u, Vector2(stroke[2], stroke[3]) * u, Color(0.70, 0.60, 0.38), maxf(1.0, u))
	_rect(ci, u, -9, -16, 18, 9, Color(0.92, 0.90, 0.83), 1.0)
	if not occupied:  # a folded blanket at the foot
		_rect(ci, u, -13, 8, 26, 9, Color(0.49, 0.31, 0.31), 1.0)
		ci.draw_line(Vector2(-12, 11) * u, Vector2(12, 11) * u, Color(0.62, 0.42, 0.42), maxf(1.0, u))


## An iron post with a glass lantern on top, seen from above: its base, and the warm glow.
static func _lantern_post(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 9.0)
	ci.draw_circle(Vector2.ZERO, 8.0 * u, OUTLINE)
	ci.draw_circle(Vector2.ZERO, 6.6 * u, Color(0.34, 0.34, 0.36))
	ci.draw_circle(Vector2(-1.2, -1.2) * u, 3.2 * u, Color(0.50, 0.50, 0.52))
	_rect(ci, u, -4.5, -4.5, 9, 9, Color(0.18, 0.17, 0.18), 1.0)  # the lantern's cage
	var flicker := 0.92 + 0.08 * sin(t * 6.0)
	ci.draw_circle(Vector2.ZERO, 3.8 * u, Color(1.0, 0.82, 0.40, 0.95 * flicker))
	ci.draw_circle(Vector2.ZERO, 1.8 * u, Color(1.0, 0.97, 0.80))
	ci.draw_line(Vector2(-4.5, 0) * u, Vector2(4.5, 0) * u, Color(0.18, 0.17, 0.18), maxf(1.0, 0.8 * u))
	ci.draw_line(Vector2(0, -4.5) * u, Vector2(0, 4.5) * u, Color(0.18, 0.17, 0.18), maxf(1.0, 0.8 * u))


## A bed of earth with flowers, a different mix on every tile.
static func _flower_bed(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_rect(ci, u, -16, -13, 32, 26, Color(0.33, 0.23, 0.15), 1.2)
	_rect(ci, u, -14, -11, 28, 22, Color(0.26, 0.18, 0.12), 0.0)
	var colors := [Color(0.92, 0.35, 0.40), Color(0.97, 0.85, 0.30), Color(0.93, 0.93, 0.95), Color(0.66, 0.48, 0.86), Color(0.98, 0.60, 0.25)]
	var main_color: Color = colors[int(hash01(cell.x, cell.y, 31) * colors.size()) % colors.size()]
	var other_color: Color = colors[int(hash01(cell.x, cell.y, 32) * colors.size()) % colors.size()]
	for i in 11:
		var at := Vector2(lerpf(-11.0, 11.0, hash01(cell.x, cell.y, 40 + i)), lerpf(-8.0, 8.0, hash01(cell.x, cell.y, 60 + i)))
		_ellipse(ci, u, at + Vector2(0.0, 1.0), Vector2(3.4, 2.2), Color(0.28, 0.48, 0.24), 0.0)
		ci.draw_circle((at + Vector2(0.0, -1.5)) * u, 2.5 * u, main_color if i % 3 != 0 else other_color)
		ci.draw_circle((at + Vector2(0.0, -1.5)) * u, 0.9 * u, Color(0.98, 0.88, 0.40))


## A round shrub of dark leaves, with highlights and a few berries.
static func _bush(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 17.0)
	var tone := 0.9 + 0.2 * hash01(cell.x, cell.y, 5)
	for blob in [[Vector2(-7, 3), 10.0], [Vector2(7, 3), 10.0], [Vector2(0, -5), 11.0], [Vector2(0, 5), 10.0]]:
		ci.draw_circle(blob[0] * u, (blob[1] + 1.2) * u, OUTLINE)
	for blob in [[Vector2(-7, 3), 10.0], [Vector2(7, 3), 10.0], [Vector2(0, -5), 11.0], [Vector2(0, 5), 10.0]]:
		ci.draw_circle(blob[0] * u, blob[1] * u, Color(0.22, 0.38, 0.20) * tone)
	for blob in [[Vector2(-8, 1), 4.5], [Vector2(5, -6), 4.5], [Vector2(1, 3), 3.8]]:
		ci.draw_circle(blob[0] * u, blob[1] * u, Color(0.34, 0.54, 0.28) * tone)
	if hash01(cell.x, cell.y, 6) < 0.5:
		for i in 5:
			var at := Vector2(lerpf(-10.0, 10.0, hash01(cell.x, cell.y, 70 + i)), lerpf(-9.0, 9.0, hash01(cell.x, cell.y, 80 + i)))
			ci.draw_circle(at * u, 1.5 * u, Color(0.80, 0.18, 0.22))


## A golden mound of hay.
static func _haystack(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 20.0)
	_ellipse(ci, u, Vector2.ZERO, Vector2(19, 17), Color(0.78, 0.62, 0.26), 1.3)
	_ellipse(ci, u, Vector2(-2, -2), Vector2(13, 11), Color(0.88, 0.73, 0.36), 0.0)
	for i in 14:
		var a := TAU * i / 14.0 + hash01(cell.x, cell.y, 9) * 0.5
		ci.draw_line(Vector2(cos(a), sin(a)) * 3.0 * u, Vector2(cos(a), sin(a)) * (13.0 + 3.0 * hash01(cell.x, cell.y, 90 + i)) * u, Color(0.70, 0.54, 0.22), maxf(1.0, 0.9 * u))
	_ellipse(ci, u, Vector2(-4, -5), Vector2(6, 3.5), Color(1, 1, 1, 0.16), 0.0)


## Split logs stacked in a pile, their ends showing.
static func _woodpile(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 19.0)
	_rect(ci, u, -19, -15, 38, 30, Color(0.30, 0.20, 0.12), 1.2)
	for row in 4:
		var y := -11.0 + row * 7.2
		for col in 5:
			var x := -14.5 + col * 7.2 + (3.6 if row % 2 == 1 else 0.0)
			if x > 15.0:
				continue
			var shade := 0.85 + 0.3 * hash01(cell.x + col, cell.y + row, 12)
			ci.draw_circle(Vector2(x, y) * u, 3.9 * u, OUTLINE)
			ci.draw_circle(Vector2(x, y) * u, 3.3 * u, Color(0.70, 0.52, 0.30) * shade)
			ci.draw_arc(Vector2(x, y) * u, 1.8 * u, 0.0, TAU, 10, Color(0.50, 0.34, 0.18), maxf(1.0, 0.7 * u))
			ci.draw_circle(Vector2(x, y) * u, 0.7 * u, Color(0.42, 0.28, 0.14))


## A two-wheeled handcart with sacks in the bed.
static func _cart(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 21.0)
	_rect(ci, u, -9, 14, 18, 7, Color(0.36, 0.25, 0.15), 1.0)  # the shafts
	for side in [-1.0, 1.0]:
		_rect(ci, u, side * 19.0 - 2.5, -11, 5, 22, Color(0.24, 0.16, 0.10), 1.0)  # wheels, edge on
		ci.draw_line(Vector2(side * 19.0, -9) * u, Vector2(side * 19.0, 9) * u, Color(0.45, 0.33, 0.20), maxf(1.0, 1.2 * u))
	_rect(ci, u, -16, -15, 32, 30, Color(0.43, 0.30, 0.18), 1.3)
	_rect(ci, u, -13, -12, 26, 24, Color(0.58, 0.42, 0.25), 0.0)
	for i in 4:
		ci.draw_line(Vector2(-13, -6 + i * 6) * u, Vector2(13, -6 + i * 6) * u, Color(0.40, 0.28, 0.16), maxf(1.0, 0.8 * u))
	var sack := Color(0.80, 0.72, 0.52) if hash01(cell.x, cell.y, 3) < 0.5 else Color(0.62, 0.50, 0.34)
	_ellipse(ci, u, Vector2(-5, -3), Vector2(7, 6), sack, 1.0)
	_ellipse(ci, u, Vector2(6, 4), Vector2(6, 5), sack.darkened(0.08), 1.0)
	ci.draw_circle(Vector2(-5, -8) * u, 1.6 * u, sack.darkened(0.3))


## A trader's stall: a table under a striped awning, goods along the front.
static func _market_stall(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 22.0)
	_rect(ci, u, -22, -18, 44, 36, Color(0.36, 0.25, 0.15), 1.4)
	_rect(ci, u, -20, 4, 40, 12, Color(0.58, 0.42, 0.25), 0.0)  # the table showing under the awning
	var palette := [[Color(0.74, 0.20, 0.18), Color(0.93, 0.89, 0.78)], [Color(0.22, 0.40, 0.62), Color(0.93, 0.89, 0.78)], [Color(0.28, 0.50, 0.28), Color(0.93, 0.89, 0.78)]]
	var stripes: Array = palette[int(hash01(cell.x, cell.y, 14) * palette.size()) % palette.size()]
	for i in 8:
		_rect(ci, u, -20 + i * 5.0, -16, 5, 22, stripes[i % 2], 0.0)
	ci.draw_line(Vector2(-20, 6) * u, Vector2(20, 6) * u, Color(0.0, 0.0, 0.0, 0.25), maxf(1.0, 1.4 * u))
	for i in 6:  # goods on the table
		var at := Vector2(-16.0 + i * 6.4, 11.0)
		var goods := [Color(0.84, 0.30, 0.22), Color(0.95, 0.78, 0.30), Color(0.50, 0.68, 0.30), Color(0.80, 0.62, 0.40)]
		ci.draw_circle(at * u, 2.8 * u, OUTLINE)
		ci.draw_circle(at * u, 2.2 * u, goods[int(hash01(cell.x + i, cell.y, 16) * goods.size()) % goods.size()])


## A stump with an axe stuck in it and chips of wood about.
static func _chopping_block(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 18.0)
	for i in 6:  # chips
		var at := Vector2(lerpf(-20.0, 20.0, hash01(cell.x, cell.y, 20 + i)), lerpf(-15.0, 17.0, hash01(cell.x, cell.y, 30 + i)))
		_ellipse(ci, u, at, Vector2(3.0, 1.6), Color(0.76, 0.58, 0.34), 0.0)
	_ellipse(ci, u, Vector2.ZERO, Vector2(15, 13), Color(0.33, 0.22, 0.13), 1.3)
	_ellipse(ci, u, Vector2(0, -1), Vector2(12.5, 10.5), Color(0.72, 0.54, 0.33), 0.0)
	for ring in [8.5, 5.0, 2.0]:
		ci.draw_arc(Vector2(0, -1) * u, ring * u, 0.0, TAU, 14, Color(0.55, 0.38, 0.21), maxf(1.0, 0.8 * u))
	ci.draw_line(Vector2(5, -3) * u, Vector2(13, -13) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 3.0 * u))  # the axe's haft
	var blade := PackedVector2Array([Vector2(1, -2), Vector2(7, -1), Vector2(9, -7), Vector2(3, -8)])
	ci.draw_colored_polygon(_scaled(blade, u), Color(0.62, 0.64, 0.68))
	ci.draw_polyline(_scaled(PackedVector2Array([Vector2(1, -2), Vector2(7, -1), Vector2(9, -7), Vector2(3, -8), Vector2(1, -2)]), u), OUTLINE, maxf(1.0, u))


## A heap of cut and broken rock with a pick leaning on it.
static func _quarry_face(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	_shadow(ci, u, 20.0)
	for i in 9:
		var at := Vector2(lerpf(-14.0, 14.0, hash01(cell.x, cell.y, 50 + i)), lerpf(-12.0, 12.0, hash01(cell.x, cell.y, 60 + i)))
		var size := Vector2(lerpf(5.0, 9.5, hash01(cell.x, cell.y, 70 + i)), lerpf(4.0, 7.5, hash01(cell.x, cell.y, 80 + i)))
		var shade := 0.78 + 0.35 * hash01(cell.x, cell.y, 90 + i)
		_ellipse(ci, u, at, size, Color(0.62, 0.62, 0.60) * shade, 1.0)
		_ellipse(ci, u, at + Vector2(-1.2, -1.4), size * 0.5, Color(1, 1, 1, 0.12), 0.0)
	ci.draw_line(Vector2(-16, 14) * u, Vector2(6, -10) * u, OUTLINE, maxf(1.5, 3.8 * u))
	ci.draw_line(Vector2(-16, 14) * u, Vector2(6, -10) * u, Color(0.45, 0.31, 0.18), maxf(1.0, 2.4 * u))
	ci.draw_line(Vector2(0, -12) * u, Vector2(13, -6) * u, Color(0.55, 0.57, 0.60), maxf(1.5, 2.6 * u))  # the pick's head


## One plot of a field: tilled furrows, and whatever the season has done to them.
static func _field_plot(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	var stage := crop_stage()
	_rect(ci, u, -24, -24, 48, 48, Color(0.38, 0.27, 0.18), 0.0)
	for i in 6:
		var y := -19.0 + i * 7.6
		ci.draw_line(Vector2(-24, y) * u, Vector2(24, y) * u, Color(0.28, 0.19, 0.12), maxf(1.0, 2.2 * u))
		ci.draw_line(Vector2(-24, y + 2.6) * u, Vector2(24, y + 2.6) * u, Color(0.47, 0.34, 0.22), maxf(1.0, 1.2 * u))
	if stage == 0:
		return
	for row in 6:
		var y := -19.0 + row * 7.6
		for col in 8:
			var x := -21.0 + col * 6.0 + 1.5 * hash01(cell.x + col, cell.y + row, 3)
			match stage:
				1:
					ci.draw_line(Vector2(x, y + 2.0) * u, Vector2(x, y - 1.5) * u, Color(0.46, 0.68, 0.30), maxf(1.0, 1.4 * u))
				2:
					ci.draw_line(Vector2(x, y + 2.0) * u, Vector2(x + 0.5, y - 5.0) * u, Color(0.36, 0.60, 0.24), maxf(1.0, 1.8 * u))
					ci.draw_line(Vector2(x, y + 2.0) * u, Vector2(x - 1.8, y - 3.5) * u, Color(0.42, 0.65, 0.27), maxf(1.0, 1.4 * u))
				3:
					ci.draw_line(Vector2(x, y + 2.0) * u, Vector2(x, y - 6.0) * u, Color(0.80, 0.66, 0.28), maxf(1.0, 1.8 * u))
					ci.draw_line(Vector2(x, y - 6.0) * u, Vector2(x + 0.8, y - 9.5) * u, Color(0.93, 0.78, 0.32), maxf(1.0, 2.4 * u))
					ci.draw_line(Vector2(x + 2.0, y + 2.0) * u, Vector2(x + 1.6, y - 4.0) * u, Color(0.74, 0.60, 0.25), maxf(1.0, 1.4 * u))
				_:
					ci.draw_line(Vector2(x, y + 2.0) * u, Vector2(x, y - 1.0) * u, Color(0.70, 0.60, 0.36), maxf(1.0, 1.4 * u))


## A raised bed of herbs in a wooden frame.
static func _herb_bed(ci: CanvasItem, u: float, cell: Vector2i) -> void:
	var stage := crop_stage()
	_rect(ci, u, -20, -20, 40, 40, Color(0.40, 0.28, 0.17), 1.2)
	_rect(ci, u, -17, -17, 34, 34, Color(0.27, 0.19, 0.12), 0.0)
	if stage == 0:
		return
	var leaf := Color(0.40, 0.62, 0.30) if stage < 4 else Color(0.62, 0.58, 0.30)
	for i in 9:
		var at := Vector2(lerpf(-12.0, 12.0, hash01(cell.x, cell.y, 100 + i)), lerpf(-12.0, 12.0, hash01(cell.x, cell.y, 110 + i)))
		var grown := 3.0 if stage == 1 else 5.5
		_ellipse(ci, u, at, Vector2(grown, grown * 0.8), leaf * (0.85 + 0.3 * hash01(cell.x, cell.y, 120 + i)), 0.0)
		if stage in [2, 3] and i % 3 == 0:
			ci.draw_circle((at + Vector2(0, -1)) * u, 1.8 * u, Color(0.70, 0.52, 0.86) if stage == 3 else Color(0.90, 0.85, 0.50))


## The end of the jetty: a post with a coil of rope, a bucket of fish and a net.
static func _fishing_spot(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 14.0)
	ci.draw_circle(Vector2(-8, -6) * u, 6.5 * u, OUTLINE)
	ci.draw_circle(Vector2(-8, -6) * u, 5.2 * u, Color(0.34, 0.22, 0.13))
	ci.draw_circle(Vector2(-8, -6) * u, 3.2 * u, Color(0.55, 0.40, 0.24))
	ci.draw_arc(Vector2(10, 6) * u, 6.0 * u, 0.0, TAU, 12, Color(0.72, 0.62, 0.40), maxf(1.5, 2.2 * u))  # rope
	ci.draw_arc(Vector2(10, 6) * u, 3.4 * u, 0.0, TAU, 10, Color(0.62, 0.52, 0.32), maxf(1.0, 1.6 * u))
	_ellipse(ci, u, Vector2(8, -9), Vector2(8, 6), Color(0.40, 0.28, 0.17), 1.0)
	_ellipse(ci, u, Vector2(8, -10), Vector2(6, 4), Color(0.20, 0.34, 0.44), 0.0)
	for fish in [Vector2(6, -10), Vector2(10, -9)]:
		_ellipse(ci, u, fish, Vector2(3.2, 1.5), Color(0.70, 0.76, 0.82), 0.0)


## A little wooden cradle on two rockers, with a straw tick and a folded blanket.
static func _cradle(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 14.0)
	for side in [-1.0, 1.0]:  # the rockers stick out past the ends
		var runner := PackedVector2Array()
		for i in 9:
			var f := i / 8.0
			runner.append(Vector2(side * (11.0 + 2.5 * sin(f * PI)), lerpf(-19.0, 19.0, f)) * u)
		ci.draw_polyline(runner, OUTLINE, maxf(1.5, 3.4 * u))
		ci.draw_polyline(runner, Color(0.36, 0.24, 0.14), maxf(1.0, 2.2 * u))
	_rect(ci, u, -11, -15, 22, 30, Color(0.52, 0.36, 0.21), 1.2)
	_rect(ci, u, -8, -12, 16, 24, Color(0.80, 0.70, 0.48), 0.0)
	ci.draw_line(Vector2(-11, -15) * u, Vector2(11, -15) * u, Color(0.66, 0.48, 0.30), maxf(1.0, 1.5 * u))
	_rect(ci, u, -6, -11, 12, 6, Color(0.93, 0.91, 0.85), 0.8)  # the little pillow
	_rect(ci, u, -8, 3, 16, 9, Color(0.42, 0.50, 0.62), 0.8)
	ci.draw_line(Vector2(-7, 6) * u, Vector2(7, 6) * u, Color(0.55, 0.63, 0.74), maxf(1.0, u))


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


## A wall fills its whole tile, so a run of them reads as one solid wall and corners and
## crossings join up. Its top is laid in courses (planks or stone blocks) that carry on from
## tile to tile, and where no wall continues to the south it shows a shaded front face.
static func _wall(ci: CanvasItem, u: float, connections: int, cell: Vector2i, stone: bool) -> void:
	var base := STONE if stone else TIMBER
	var face_south := connections & 4 == 0
	var top := Rect2(-24, -24, 48, 48.0 - (WALL_FACE if face_south else 0.0))
	var along_x := (connections & 10) != 0
	var along_y := (connections & 5) != 0
	if along_x and along_y:  # a corner or crossing
		if stone:  # big quoin stones
			_courses(ci, u, top, true, 2, 24.0, base.lightened(0.05), cell, 0.18, 1.5, true, 11)
		else:  # a squared post where the timbers meet, bevelled, with a hint of end grain
			var post := top.grow(-4.0)
			ci.draw_rect(_scaled_rect(top, u), base.darkened(0.06))
			ci.draw_rect(_scaled_rect(post, u), base.darkened(0.14))
			ci.draw_line(post.position * u, Vector2(post.end.x, post.position.y) * u, base.lightened(0.12), maxf(1.0, u))
			ci.draw_line(post.position * u, Vector2(post.position.x, post.end.y) * u, base.lightened(0.08), maxf(1.0, u))
			ci.draw_line(Vector2(post.position.x, post.end.y) * u, post.end * u, base.darkened(0.34), maxf(1.0, u))
			ci.draw_line(Vector2(post.end.x, post.position.y) * u, post.end * u, base.darkened(0.30), maxf(1.0, u))
			ci.draw_arc(post.get_center() * u, 6.0 * u, 0.0, TAU, 16, base.darkened(0.22), maxf(1.0, 0.8 * u))
	elif stone:
		_courses(ci, u, top, along_x or not along_y, 3, 18.0, base, cell, 0.16, 1.5, true, 3)
	else:
		_courses(ci, u, top, along_x or not along_y, 3, 70.0, base, cell, 0.12, 1.0, false, 5)

	if face_south:
		var face := Rect2(-24, 24.0 - WALL_FACE, 48, WALL_FACE)
		var shaded := base.darkened(0.42)
		if stone:
			_courses(ci, u, face, true, 2, 15.0, shaded, cell, 0.20, 1.2, true, 9)
		else:  # upright boards
			ci.draw_rect(_scaled_rect(face, u), shaded)
			var start := -24.0 + 7.0 * hash01(cell.x, cell.y, 2)
			for i in 8:
				var x := start + i * 7.0
				if x > -24.0 and x < 24.0:
					ci.draw_line(Vector2(x, face.position.y) * u, Vector2(x, 24) * u, shaded.darkened(0.30), maxf(1.0, 0.8 * u))
		ci.draw_rect(Rect2(Vector2(-24, face.end.y - 2.5) * u, Vector2(48, 2.5) * u), Color(0, 0, 0, 0.25))  # dirt at the foot
		ci.draw_line(Vector2(-24, face.position.y) * u, Vector2(24, face.position.y) * u, base.lightened(0.28), maxf(1.0, 1.2 * u))  # the lit edge
		ci.draw_line(Vector2(-24, 24) * u, Vector2(24, 24) * u, OUTLINE, maxf(1.0, 1.5 * u))
	_wall_edges(ci, u, connections, base, top.end.y)


## Dark outlines along the sides that do not join another wall, with a lit rim on the sides
## that face the light (north and west) and a shaded one on the east.
static func _wall_edges(ci: CanvasItem, u: float, connections: int, base: Color, top_end: float) -> void:
	var outline := maxf(1.0, 1.5 * u)
	var rim := maxf(1.0, u)
	if connections & 1 == 0:
		ci.draw_line(Vector2(-24, -24) * u, Vector2(24, -24) * u, OUTLINE, outline)
		ci.draw_line(Vector2(-24, -22.5) * u, Vector2(24, -22.5) * u, base.lightened(0.25), rim)
	if connections & 8 == 0:
		ci.draw_line(Vector2(-22.5, -24) * u, Vector2(-22.5, top_end) * u, base.lightened(0.18), rim)
		ci.draw_line(Vector2(-24, -24) * u, Vector2(-24, 24) * u, OUTLINE, outline)
	if connections & 2 == 0:
		ci.draw_line(Vector2(22.5, -24) * u, Vector2(22.5, top_end) * u, base.darkened(0.25), rim)
		ci.draw_line(Vector2(24, -24) * u, Vector2(24, 24) * u, OUTLINE, outline)


## Fills `area` with rows of blocks or planks running along x (or along y), staggered, each a
## little lighter or darker than the next. Positions count from the map's corner, so a course
## carries on into the next tile of the same wall without a seam.
static func _courses(ci: CanvasItem, u: float, area: Rect2, along_x: bool, rows: int, length: float,
		base: Color, cell: Vector2i, variation: float, joint: float, stagger: bool, salt: int) -> void:
	var mortar := base.darkened(0.40)  # or the gaps between planks
	var width := maxf(1.0, joint * u)
	var origin := float(cell.x if along_x else cell.y) * 48.0
	var lane := cell.y if along_x else cell.x
	var start := origin + (area.position.x if along_x else area.position.y)
	var end := start + (area.size.x if along_x else area.size.y)
	var across_start := area.position.y if along_x else area.position.x
	var across := (area.size.y if along_x else area.size.x) / rows
	# Blocks edge to edge, then the joints drawn over them as lines (cheaper than mortar under all).
	for row in rows:
		var shift := hash01(lane, 0 if stagger else row, salt) * length
		if stagger and row % 2 == 1:
			shift += length * 0.5
		var c0 := across_start + row * across
		var c1 := c0 + across
		var k := floori((start - shift) / length)
		while shift + k * length < end:
			var block_start := shift + k * length
			var a := maxf(start, block_start) - origin
			var b := minf(end, block_start + length) - origin
			var shade := 1.0 + variation * (hash01(lane * 13 + row, k, salt) - 0.5)
			var color := Color(base.r * shade, base.g * shade, base.b * shade)
			var rect := Rect2(a, c0, b - a, c1 - c0) if along_x else Rect2(c0, a, c1 - c0, b - a)
			ci.draw_rect(_scaled_rect(rect, u), color)
			var lit_from := Vector2(a, c0 + joint) if along_x else Vector2(c0 + joint, a)
			var lit_to := Vector2(b, c0 + joint) if along_x else Vector2(c0 + joint, b)
			ci.draw_line(lit_from * u, lit_to * u, color.lightened(0.14), maxf(1.0, 0.8 * u))  # a lit edge
			if block_start > start:  # the joint where this block begins
				var j0 := Vector2(a, c0) if along_x else Vector2(c0, a)
				var j1 := Vector2(a, c1) if along_x else Vector2(c1, a)
				ci.draw_line(j0 * u, j1 * u, mortar, width)
			k += 1
		var edge0 := Vector2(start - origin, c0) if along_x else Vector2(c0, start - origin)
		var edge1 := Vector2(end - origin, c0) if along_x else Vector2(c0, end - origin)
		ci.draw_line(edge0 * u, edge1 * u, mortar, width)  # the bed joint above the row
	var last0 := Vector2(start - origin, across_start + rows * across) if along_x else Vector2(across_start + rows * across, start - origin)
	var last1 := Vector2(end - origin, across_start + rows * across) if along_x else Vector2(across_start + rows * across, end - origin)
	ci.draw_line(last0 * u, last1 * u, mortar, width)


## A door stands in a gap in the wall: timber jambs at either end, a plank leaf with iron
## straps between them and a worn threshold underneath. People walk straight through it.
static func _door(ci: CanvasItem, u: float, connections: int, cell: Vector2i) -> void:
	var vertical := (connections & 5) != 0 and (connections & 10) == 0
	var sill := Color(0.33, 0.25, 0.17)
	ci.draw_rect(Rect2(Vector2(-24, -24) * u, Vector2(48, 48) * u), sill)
	for i in range(1, 6):  # threshold boards, laid across the way through
		var p := -24.0 + i * 8.0
		var from := Vector2(-24, p) if vertical else Vector2(p, -24)
		var to := Vector2(24, p) if vertical else Vector2(p, 24)
		ci.draw_line(from * u, to * u, sill.darkened(0.30), maxf(1.0, 0.8 * u))
	var jamb := 7.0
	var timber := TIMBER
	var leaf := Color(0.63, 0.46, 0.29)
	if vertical:
		for y in [-24.0, 24.0 - jamb]:
			ci.draw_rect(Rect2(Vector2(-24, y) * u, Vector2(48, jamb) * u), timber)
		ci.draw_rect(Rect2(Vector2(-24, -24 + jamb - 3.0) * u, Vector2(48, 3.0) * u), timber.darkened(0.42))  # face of the top jamb
		var slab := Rect2(-6, -24 + jamb, 12, 48 - 2.0 * jamb)
		ci.draw_rect(_scaled_rect(slab.grow(1.2), u), OUTLINE)
		ci.draw_rect(_scaled_rect(slab, u), leaf)
		for i in range(1, 7):
			var y := slab.position.y + slab.size.y * i / 7.0
			ci.draw_line(Vector2(-6, y) * u, Vector2(6, y) * u, leaf.darkened(0.25), maxf(1.0, 0.8 * u))
		for x in [-3.0, 3.0]:  # iron straps
			ci.draw_line(Vector2(x, slab.position.y) * u, Vector2(x, slab.end.y) * u, Color(0.22, 0.21, 0.20), maxf(1.0, 1.3 * u))
		ci.draw_circle(Vector2(2.5, 9) * u, 1.8 * u, Color(0.16, 0.12, 0.08))
	else:
		for x in [-24.0, 24.0 - jamb]:
			ci.draw_rect(Rect2(Vector2(x, -24) * u, Vector2(jamb, 48) * u), timber)
			if connections & 4 == 0:
				ci.draw_rect(Rect2(Vector2(x, 24 - WALL_FACE) * u, Vector2(jamb, WALL_FACE) * u), timber.darkened(0.42))
		var slab := Rect2(-24 + jamb, -7, 48 - 2.0 * jamb, 12)
		ci.draw_rect(Rect2(Vector2(slab.position.x, slab.end.y) * u, Vector2(slab.size.x, 5) * u), Color(0, 0, 0, 0.30))  # its shadow
		ci.draw_rect(_scaled_rect(slab.grow(1.2), u), OUTLINE)
		ci.draw_rect(_scaled_rect(slab, u), leaf)
		ci.draw_rect(Rect2(Vector2(slab.position.x, slab.end.y - 3.5) * u, Vector2(slab.size.x, 3.5) * u), leaf.darkened(0.35))
		for i in range(1, 7):
			var x := slab.position.x + slab.size.x * i / 7.0
			ci.draw_line(Vector2(x, -7) * u, Vector2(x, 5 - 3.5) * u, leaf.darkened(0.25), maxf(1.0, 0.8 * u))
		for y in [-4.0, 0.5]:  # iron straps
			ci.draw_line(Vector2(slab.position.x, y) * u, Vector2(slab.end.x, y) * u, Color(0.22, 0.21, 0.20), maxf(1.0, 1.3 * u))
		ci.draw_circle(Vector2(9, -1.5) * u, 1.8 * u, Color(0.16, 0.12, 0.08))
	_wall_edges(ci, u, connections | (10 if vertical else 5), timber, 24.0)
	# outline the jambs where they meet the opening
	if vertical:
		ci.draw_line(Vector2(-24, -24 + jamb) * u, Vector2(24, -24 + jamb) * u, OUTLINE, maxf(1.0, 1.2 * u))
		ci.draw_line(Vector2(-24, 24 - jamb) * u, Vector2(24, 24 - jamb) * u, OUTLINE, maxf(1.0, 1.2 * u))
	else:
		ci.draw_line(Vector2(-24 + jamb, -24) * u, Vector2(-24 + jamb, 24) * u, OUTLINE, maxf(1.0, 1.2 * u))
		ci.draw_line(Vector2(24 - jamb, -24) * u, Vector2(24 - jamb, 24) * u, OUTLINE, maxf(1.0, 1.2 * u))
		ci.draw_line(Vector2(-24, -24) * u, Vector2(-24 + jamb, -24) * u, OUTLINE, maxf(1.0, 1.5 * u))
		ci.draw_line(Vector2(24 - jamb, -24) * u, Vector2(24, -24) * u, OUTLINE, maxf(1.0, 1.5 * u))
		if connections & 4 == 0:
			ci.draw_line(Vector2(-24, 24) * u, Vector2(-24 + jamb, 24) * u, OUTLINE, maxf(1.0, 1.5 * u))
			ci.draw_line(Vector2(24 - jamb, 24) * u, Vector2(24, 24) * u, OUTLINE, maxf(1.0, 1.5 * u))


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
	ci.draw_rect(Rect2(Vector2(-24, 13) * u, Vector2(48, 6) * u), Color(0, 0, 0, 0.18))
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
static func _watch_post(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 18.0)
	_rect(ci, u, -16, -16, 32, 32, Color(0.40, 0.29, 0.18), 1.4)          # the platform seen from above
	_rect(ci, u, -13, -13, 26, 26, Color(0.56, 0.42, 0.26), 0.0)
	for plank in [-4, 4]:
		ci.draw_line(Vector2(-13, plank) * u, Vector2(13, plank) * u, Color(0.42, 0.31, 0.19), maxf(1.0, u))
	_rect(ci, u, -4, -4, 8, 8, Color(0.30, 0.21, 0.13), 1.0)               # the post
	ci.draw_circle(Vector2.ZERO, (6.0 + 0.8 * sin(t * 6.0)) * u, Color(1.0, 0.75, 0.30, 0.25))  # the lantern
	ci.draw_circle(Vector2.ZERO, 3.0 * u, Color(1.0, 0.86, 0.45))
	for corner in [Vector2(-14, -14), Vector2(14, -14), Vector2(-14, 14), Vector2(14, 14)]:
		_rect(ci, u, corner.x - 2, corner.y - 2, 4, 4, Color(0.30, 0.21, 0.13), 0.8)


static func _pew(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 16.0)
	_rect(ci, u, -20, -9, 40, 18, Color(0.42, 0.28, 0.17), 1.2)
	_rect(ci, u, -18, -7, 36, 6, Color(0.55, 0.38, 0.23), 0.0)  # the back rail
	_rect(ci, u, -18, 0, 36, 7, Color(0.62, 0.45, 0.28), 0.0)   # the seat
	for x in [-17, 13]:
		_rect(ci, u, x, -9, 4, 18, Color(0.33, 0.22, 0.13), 0.8)


static func _altar(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 20.0)
	_rect(ci, u, -19, -14, 38, 28, Color(0.58, 0.58, 0.56), 1.4)
	_rect(ci, u, -19, -14, 38, 6, Color(0.92, 0.90, 0.84), 0.0)   # the cloth
	_rect(ci, u, -2, -22, 4, 18, Color(0.88, 0.76, 0.35), 1.0)    # a cross, upright
	_rect(ci, u, -7, -17, 14, 4, Color(0.88, 0.76, 0.35), 1.0)
	for x in [-14, 10]:
		_rect(ci, u, x, -8, 4, 8, Color(0.93, 0.89, 0.72), 0.8)  # candles
		_flame(ci, u, Vector2(x + 2, -8), 5.0 + 0.8 * sin(t * 9.0 + x), 2.6)


static func _sickbed(ci: CanvasItem, u: float, occupied: bool) -> void:
	_shadow(ci, u, 20.0)
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


## A stone forge with a glowing firebox and an anvil to its side.
static func _forge(ci: CanvasItem, u: float, t: float) -> void:
	_shadow(ci, u, 22.0)
	ci.draw_circle(Vector2(-2, -2) * u, 26.0 * u, Color(1.0, 0.5, 0.15, 0.10))
	_rect(ci, u, -22, -19, 31, 31, Color(0.46, 0.46, 0.48), 1.3)
	for row in 3:  # courses of stone
		var y := -13.0 + row * 9.0
		ci.draw_line(Vector2(-22, y) * u, Vector2(9, y) * u, Color(0.33, 0.33, 0.35), maxf(1.0, 0.9 * u))
		for col in 3:
			var x := -17.0 + col * 10.0 + (4.0 if row % 2 == 0 else 0.0)
			ci.draw_line(Vector2(x, y) * u, Vector2(x, y + 9.0) * u, Color(0.33, 0.33, 0.35), maxf(1.0, 0.9 * u))
	_rect(ci, u, -17, -9, 21, 15, Color(0.10, 0.07, 0.06), 1.0)  # the firebox
	var glow := 0.8 + 0.2 * sin(t * 6.0)
	_ellipse(ci, u, Vector2(-6.5, 0), Vector2(8.5, 4.5), Color(0.95, 0.38, 0.10) * glow, 0.0)
	_ellipse(ci, u, Vector2(-6.5, 0), Vector2(5.0, 2.5), Color(1.0, 0.78, 0.30) * glow, 0.0)
	_flame(ci, u, Vector2(-9, 1), 8.0 + 2.5 * sin(t * 9.0), 5.0)
	_flame(ci, u, Vector2(-3, 2), 7.0 + 2.5 * sin(t * 8.0 + 1.3), 4.5)
	# the anvil
	var anvil := PackedVector2Array([Vector2(12, -4), Vector2(23, -4), Vector2(25, -1), Vector2(21, 1), Vector2(21, 7), Vector2(24, 9), Vector2(11, 9), Vector2(14, 7), Vector2(14, 1), Vector2(12, 1)])
	ci.draw_colored_polygon(_scaled(anvil, u), Color(0.30, 0.31, 0.35))
	ci.draw_polyline(_scaled(anvil + PackedVector2Array([Vector2(12, -4)]), u), OUTLINE, maxf(1.0, u))
	ci.draw_line(Vector2(13, -3) * u, Vector2(23, -3) * u, Color(0.55, 0.57, 0.62), maxf(1.0, 1.2 * u))
	ci.draw_line(Vector2(5, 15) * u, Vector2(17, 11) * u, Color(0.32, 0.22, 0.13), maxf(1.5, 2.4 * u))  # tongs on the floor


## A carpenter's bench with a plank on it, a saw and a mallet.
static func _workbench(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 21.0)
	_rect(ci, u, -22, -13, 44, 26, Color(0.40, 0.28, 0.17), 1.3)
	_rect(ci, u, -22, -13, 44, 17, Color(0.64, 0.48, 0.30), 0.0)
	ci.draw_line(Vector2(-22, 4) * u, Vector2(22, 4) * u, Color(0.30, 0.20, 0.12), maxf(1.0, u))
	_rect(ci, u, -16, -9, 24, 6, Color(0.78, 0.64, 0.42), 0.9)  # a plank
	ci.draw_line(Vector2(-12, -6) * u, Vector2(2, -6) * u, Color(0.60, 0.46, 0.28), maxf(1.0, 0.8 * u))
	var saw := PackedVector2Array([Vector2(8, -2), Vector2(20, -6), Vector2(20, -1), Vector2(8, 2)])
	ci.draw_colored_polygon(_scaled(saw, u), Color(0.66, 0.68, 0.72))
	ci.draw_line(Vector2(8, 0) * u, Vector2(5, 3) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.6 * u))
	ci.draw_line(Vector2(-18, 8) * u, Vector2(-10, 8) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.4 * u))  # mallet
	_rect(ci, u, -11, 5, 6, 6, Color(0.48, 0.34, 0.20), 0.8)
	_rect(ci, u, 13, 7, 4, 3, Color(0.78, 0.64, 0.42), 0.0)  # shavings
	_rect(ci, u, 18, 9, 3, 2, Color(0.78, 0.64, 0.42), 0.0)


## A wall rack hung with tools for sale.
static func _tool_rack(ci: CanvasItem, u: float) -> void:
	_shadow(ci, u, 20.0)
	_rect(ci, u, -22, -13, 44, 26, Color(0.36, 0.26, 0.16), 1.3)
	_rect(ci, u, -20, -11, 40, 22, Color(0.52, 0.38, 0.24), 0.0)
	ci.draw_line(Vector2(-20, -1) * u, Vector2(20, -1) * u, Color(0.28, 0.19, 0.11), maxf(1.5, 2.0 * u))
	# an axe, a pick, a sickle and a hammer, hanging by their hafts
	ci.draw_line(Vector2(-14, -10) * u, Vector2(-14, 5) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.2 * u))
	ci.draw_colored_polygon(_scaled(PackedVector2Array([Vector2(-14, -9), Vector2(-8, -10), Vector2(-8, -3), Vector2(-14, -4)]), u), Color(0.64, 0.66, 0.70))
	ci.draw_line(Vector2(-4, -10) * u, Vector2(-4, 6) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.2 * u))
	ci.draw_line(Vector2(-10, -9) * u, Vector2(2, -9) * u, Color(0.58, 0.60, 0.64), maxf(1.5, 2.4 * u))
	ci.draw_arc(Vector2(7, -3) * u, 6.0 * u, PI * 0.9, PI * 2.1, 10, Color(0.68, 0.70, 0.74), maxf(1.5, 2.0 * u))
	ci.draw_line(Vector2(7, 3) * u, Vector2(7, 8) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.2 * u))
	ci.draw_line(Vector2(16, -9) * u, Vector2(16, 7) * u, Color(0.30, 0.20, 0.12), maxf(1.5, 2.2 * u))
	_rect(ci, u, 12, -10, 8, 5, Color(0.50, 0.52, 0.56), 0.8)
	_rect(ci, u, -22, 9, 44, 4, Color(0.28, 0.19, 0.11), 0.0)


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


static func _scaled_rect(rect: Rect2, u: float) -> Rect2:
	return Rect2(rect.position * u, rect.size * u)


## A repeatable random number from 0 to 1 for three whole numbers, so patterns stay the same
## from frame to frame and from one run to the next.
static func hash01(a: int, b: int, c: int) -> float:
	var h := a * 374761393 + b * 668265263 + c * 1274126177
	h = (h ^ (h >> 13)) * 1103515245
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
