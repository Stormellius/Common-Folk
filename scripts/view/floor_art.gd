class_name FloorArt
extends RefCounted
## Draws one floor tile (planks, flagstone, straw) with code, like the other art. Used by the
## floor layer, the build palette and the placement preview. `cell` only varies the pattern so
## neighboring tiles do not look stamped.

static func draw(ci: CanvasItem, floor_id: String, rect: Rect2, cell: Vector2i = Vector2i.ZERO) -> void:
	var def := DataRegistry.get_def("floors", floor_id)
	var fill := Color(str(def.get("color", "#ff00ff")))
	var line := Color(str(def.get("line", "#000000")))
	var w := maxf(1.0, rect.size.x / 48.0)
	ci.draw_rect(rect, fill)
	var k := rect.size.x / 48.0
	match str(def.get("pattern", "")):
		"planks":
			for i in range(1, 4):
				var y := rect.position.y + rect.size.y * i / 4.0
				ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line, w)
			for row in 4:  # staggered end joints
				var x := rect.position.x + rect.size.x * (0.25 + 0.5 * float((cell.x + cell.y + row * 2) % 3) / 2.0 + 0.1 * row)
				ci.draw_line(Vector2(x, rect.position.y + rect.size.y * row / 4.0), Vector2(x, rect.position.y + rect.size.y * (row + 1) / 4.0), line, w)
		"flags":
			var split := rect.size.x * (0.35 + 0.1 * float((cell.x * 3 + cell.y) % 3))
			ci.draw_line(rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), line, w)
			ci.draw_line(rect.position + Vector2(split, 0), rect.position + Vector2(split, rect.size.y * 0.5), line, w)
			ci.draw_line(rect.position + Vector2(rect.size.x - split, rect.size.y * 0.5), rect.position + Vector2(rect.size.x - split, rect.size.y), line, w)
		"straw":
			var spot := (cell.x * 31 + cell.y * 17) % 7
			for i in 9:
				var x := rect.position.x + rect.size.x * fposmod(0.11 + i * 0.37 + spot * 0.05, 1.0)
				var y := rect.position.y + rect.size.y * fposmod(0.07 + i * 0.23 + spot * 0.03, 1.0)
				ci.draw_line(Vector2(x, y), Vector2(x + 7.0 * k, y - 3.0 * k), line, w)
	ci.draw_rect(rect, line.darkened(0.2), false, w)
