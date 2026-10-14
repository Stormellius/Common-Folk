class_name FloorArt
extends RefCounted
## Draws one floor tile (planks, flagstone, straw) with code, like the other art. Used by the
## floor layer, the build palette and the placement preview. `cell` is the tile's place on the
## map: boards run on from tile to tile and every board and stone takes its own shade from it,
## so a floor reads as one surface rather than a grid of squares.
##
## Like the objects, a tile is measured in units 48 wide; `rect` scales them to pixels.

const PLANK_ROWS := 4


static func draw(ci: CanvasItem, floor_id: String, rect: Rect2, cell: Vector2i = Vector2i.ZERO) -> void:
	var def := DataRegistry.get_def("floors", floor_id)
	var fill := Color(str(def.get("color", "#ff00ff")))
	var line := Color(str(def.get("line", "#000000")))
	match str(def.get("pattern", "")):
		"planks":
			_planks(ci, rect, cell, fill, line)
		"flags":
			_flags(ci, rect, cell, fill, line)
		"straw":
			_straw(ci, rect, cell, fill, line)
		_:
			ci.draw_rect(rect, fill)


## Boards laid east to west, a few tiles long each, with staggered ends, a little grain and a
## dark gap between rows.
static func _planks(ci: CanvasItem, rect: Rect2, cell: Vector2i, fill: Color, line: Color) -> void:
	var k := rect.size.x / 48.0
	var w := maxf(1.0, k)
	var row_height := 48.0 / PLANK_ROWS
	for row in PLANK_ROWS:
		var lane := cell.y * PLANK_ROWS + row
		var length := 70.0 + 70.0 * ObjectArt.hash01(lane, 0, 41)
		var shift := ObjectArt.hash01(lane, 1, 41) * length
		var start := cell.x * 48.0
		var y0 := row * row_height
		var plank := floori((start - shift) / length)
		while shift + plank * length < start + 48.0:
			var plank_start := shift + plank * length
			var a := maxf(start, plank_start) - start
			var b := minf(start + 48.0, plank_start + length) - start
			var shade := 0.90 + 0.20 * ObjectArt.hash01(lane, plank, 43)
			var color := Color(fill.r * shade, fill.g * shade, fill.b * shade)
			ci.draw_rect(_part(rect, a, y0, b - a, row_height), color)
			ci.draw_line(_point(rect, a, y0 + 1.6), _point(rect, b, y0 + 1.6), color.lightened(0.10), w)  # worn, lit edge
			var gy := y0 + 3.5 + 5.5 * ObjectArt.hash01(lane, plank, 47)  # a streak of grain
			var gx := a + (b - a) * 0.6 * ObjectArt.hash01(lane, plank * 5, 53)
			ci.draw_line(_point(rect, gx, gy), _point(rect, minf(b, gx + 10.0 + 14.0 * ObjectArt.hash01(plank, lane, 59)), gy), color.darkened(0.10), w)
			if plank_start > start:  # the end joint, with nail heads beside it
				ci.draw_line(_point(rect, a, y0), _point(rect, a, y0 + row_height), line, w)
				var nail := Color(0.20, 0.17, 0.13, 0.8)
				ci.draw_rect(_part(rect, a + 1.5, y0 + 3.0, 1.2 * w / k, 1.2 * w / k), nail)
				ci.draw_rect(_part(rect, a + 1.5, y0 + row_height - 4.0, 1.2 * w / k, 1.2 * w / k), nail)
			plank += 1
		ci.draw_line(_point(rect, 0, y0 + 0.5), _point(rect, 48, y0 + 0.5), line, w)  # the gap between rows


## Flat stones of a few sizes with mortar between them, each with its own shade and a bevel:
## lit on the top and left edges, shaded on the bottom and right.
static func _flags(ci: CanvasItem, rect: Rect2, cell: Vector2i, fill: Color, line: Color) -> void:
	var k := rect.size.x / 48.0
	var w := maxf(1.0, k)
	var r0 := ObjectArt.hash01(cell.x, cell.y, 61)
	var r1 := 0.36 + 0.28 * ObjectArt.hash01(cell.x, cell.y, 67)
	var r2 := 0.36 + 0.28 * ObjectArt.hash01(cell.x, cell.y, 71)
	var stones: Array[Rect2] = []
	if r0 < 0.3:  # four, with the joints out of line
		stones = [Rect2(0, 0, 48 * r1, 24), Rect2(48 * r1, 0, 48 * (1 - r1), 24), Rect2(0, 24, 48 * r2, 24), Rect2(48 * r2, 24, 48 * (1 - r2), 24)]
	elif r0 < 0.55:  # a long stone over two
		stones = [Rect2(0, 0, 48, 48 * r1), Rect2(0, 48 * r1, 48 * r2, 48 * (1 - r1)), Rect2(48 * r2, 48 * r1, 48 * (1 - r2), 48 * (1 - r1))]
	elif r0 < 0.8:  # a tall stone beside two
		stones = [Rect2(0, 0, 48 * r1, 48), Rect2(48 * r1, 0, 48 * (1 - r1), 48 * r2), Rect2(48 * r1, 48 * r2, 48 * (1 - r1), 48 * (1 - r2))]
	else:  # one big slab
		stones = [Rect2(0, 0, 48, 48)]
	var warm := Color(0.62, 0.57, 0.50)
	for i in stones.size():
		var stone := stones[i].grow(-0.6)
		var shade := 0.86 + 0.24 * ObjectArt.hash01(cell.x * 7 + i, cell.y, 73)
		var color := Color(fill.r * shade, fill.g * shade, fill.b * shade).lerp(warm * shade, 0.3 * ObjectArt.hash01(cell.x, cell.y * 5 + i, 79))
		ci.draw_rect(_part(rect, stone.position.x, stone.position.y, stone.size.x, stone.size.y), color)
		var tl := stone.position
		var br := stone.end
		ci.draw_line(_point(rect, tl.x, tl.y + 0.6), _point(rect, br.x, tl.y + 0.6), color.lightened(0.14), w)
		ci.draw_line(_point(rect, tl.x + 0.6, tl.y), _point(rect, tl.x + 0.6, br.y), color.lightened(0.10), w)
		ci.draw_line(_point(rect, tl.x, br.y - 0.6), _point(rect, br.x, br.y - 0.6), color.darkened(0.16), w)
		ci.draw_line(_point(rect, br.x - 0.6, tl.y), _point(rect, br.x - 0.6, br.y), color.darkened(0.12), w)
		ci.draw_rect(_part(rect, stones[i].position.x, stones[i].position.y, stones[i].size.x, stones[i].size.y), line, false, maxf(1.0, 1.6 * k))  # mortar
		if ObjectArt.hash01(cell.x + i, cell.y, 83) < 0.06:  # an old crack
			var c := stone.get_center()
			ci.draw_polyline(PackedVector2Array([_point(rect, c.x - 5, c.y - 3), _point(rect, c.x - 1, c.y), _point(rect, c.x + 2, c.y - 1), _point(rect, c.x + 6, c.y + 3)]), color.darkened(0.15), w)


## Loose straw strewn over the floor: short strands in many directions, lighter and darker.
static func _straw(ci: CanvasItem, rect: Rect2, cell: Vector2i, fill: Color, line: Color) -> void:
	var k := rect.size.x / 48.0
	var w := maxf(1.0, k)
	var shade := 0.96 + 0.08 * ObjectArt.hash01(cell.x, cell.y, 89)
	ci.draw_rect(rect, Color(fill.r * shade, fill.g * shade, fill.b * shade))
	for i in 22:
		var x := 2.0 + 44.0 * ObjectArt.hash01(cell.x * 31 + i, cell.y, 97)
		var y := 2.0 + 44.0 * ObjectArt.hash01(cell.x, cell.y * 29 + i, 101)
		var angle := -0.5 + 1.6 * ObjectArt.hash01(i, cell.x + cell.y * 7, 103)
		var length := 5.0 + 5.0 * ObjectArt.hash01(i, cell.y, 107)
		var tip := Vector2(clampf(x + cos(angle) * length, 0.5, 47.5), clampf(y - sin(angle) * length, 0.5, 47.5))
		var color := fill.lightened(0.18) if i % 3 == 0 else (line if i % 3 == 1 else fill.darkened(0.08))
		ci.draw_line(_point(rect, x, y), _point(rect, tip.x, tip.y), color, w)


## A point given in tile units, inside `rect`.
static func _point(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + Vector2(x, y) * (rect.size.x / 48.0)


static func _part(rect: Rect2, x: float, y: float, width: float, height: float) -> Rect2:
	var k := rect.size.x / 48.0
	return Rect2(rect.position + Vector2(x, y) * k, Vector2(width, height) * k)
