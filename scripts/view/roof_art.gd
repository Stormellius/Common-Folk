class_name RoofArt
extends RefCounted
## Draws one roof tile from its painted texture (SpriteBank.draw_roof) or with code: thatch (reed
## bundles) or clay tiles (rows of scales); either way with a dark eave where the roof ends. Used by the roof layer and the build palette.


## `edges` says which sides of the tile have no roof beside them (1 north, 2 east, 4 south, 8 west).
static func draw(ci: CanvasItem, roof_id: String, rect: Rect2, cell: Vector2i = Vector2i.ZERO, edges: int = 0) -> void:
	var def := DataRegistry.get_def("roofs", roof_id)
	var base := Color(str(def.get("color", "#b8914c")))
	var edge := Color(str(def.get("edge", "#6f5630")))
	var k := rect.size.x / 48.0
	if SpriteBank.draw_roof(ci, roof_id, rect, cell):
		pass  # a painted roof; the eaves are still drawn below
	elif roof_id == "tile":
		_fill(ci, rect, cell, base)
		for row in 4:
			var y := rect.position.y + row * 12.0 * k
			ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), edge, maxf(1.0, 1.2 * k))
			var offset := 12.0 * k if (row + cell.y) % 2 == 0 else 0.0
			for col in 5:
				var x := rect.position.x + offset + col * 24.0 * k
				if x < rect.end.x:
					ci.draw_line(Vector2(x, y), Vector2(x, y + 12.0 * k), edge, maxf(1.0, 0.9 * k))
	else:
		_fill(ci, rect, cell, base)
		for strand in 7:
			var x := rect.position.x + (strand + 0.5 + 0.4 * ObjectArt.hash01(cell.x * 7 + strand, cell.y, 73)) * 48.0 * k / 7.0
			var top := rect.position.y + 48.0 * k * ObjectArt.hash01(cell.x, cell.y * 7 + strand, 75) * 0.5
			ci.draw_line(Vector2(x, top), Vector2(x + 3.0 * k, rect.end.y), edge.lerp(base, 0.55), maxf(1.0, 1.4 * k))
	var width := maxf(2.0, 3.0 * k)
	if edges & 1:
		ci.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), edge, width)
	if edges & 2:
		ci.draw_line(Vector2(rect.end.x, rect.position.y), rect.end, edge, width)
	if edges & 4:
		ci.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, edge, width)
		ci.draw_line(Vector2(rect.position.x, rect.end.y + width), Vector2(rect.end.x, rect.end.y + width), Color(0, 0, 0, 0.22), width)
	if edges & 8:
		ci.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), edge, width)


## The roof's own colour, a little lighter or darker on each tile.
static func _fill(ci: CanvasItem, rect: Rect2, cell: Vector2i, base: Color) -> void:
	var shade := 0.90 + 0.18 * ObjectArt.hash01(cell.x, cell.y, 71)
	ci.draw_rect(rect, Color(base.r * shade, base.g * shade, base.b * shade))
