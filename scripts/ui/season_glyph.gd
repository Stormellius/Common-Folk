class_name SeasonGlyph
extends Control
## A small picture of the season beside the date: a sprig for spring, the sun for summer, a leaf
## for autumn and a snowflake for winter. Drawn with code like the rest of the art.

var season_id := "":
	set(value):
		if value != season_id:
			season_id = value
			queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var outline := Color(0.05, 0.035, 0.02, 0.9)
	match season_id:
		"spring":
			draw_line(c + Vector2(0, 9), c + Vector2(0, -7), Color(0.42, 0.55, 0.25), 2.0)
			for side in [-1.0, 1.0]:
				var leaf := PackedVector2Array([c + Vector2(0, -1 + side), c + Vector2(side * 7, -6 + side * 2), c + Vector2(side * 3, 1)])
				draw_colored_polygon(leaf, Color(0.55, 0.72, 0.32))
			draw_circle(c + Vector2(0, -8), 2.5, Color(0.95, 0.88, 0.70))
		"summer":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 6.5, c + Vector2(cos(a), sin(a)) * 10.0, Color(0.95, 0.75, 0.30), 2.0)
			draw_circle(c, 6.0, outline)
			draw_circle(c, 5.0, Color(0.98, 0.82, 0.36))
		"autumn":
			var leaf := PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, -2), c + Vector2(4, 6), c + Vector2(0, 8), c + Vector2(-4, 6), c + Vector2(-7, -2)])
			draw_colored_polygon(leaf, Color(0.80, 0.42, 0.16))
			draw_polyline(leaf + PackedVector2Array([leaf[0]]), outline, 1.0)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 10), Color(0.45, 0.22, 0.08), 1.5)
		"winter":
			for i in 3:
				var a := PI * i / 3.0
				var arm := Vector2(cos(a), sin(a)) * 9.0
				draw_line(c - arm, c + arm, Color(0.85, 0.92, 1.0), 2.0)
				for end: Vector2 in [arm, -arm]:
					var tick := end * 0.55
					var across := Vector2(-end.y, end.x).normalized() * 2.5
					draw_line(c + tick, c + tick * 1.4 + across, Color(0.85, 0.92, 1.0), 1.2)
					draw_line(c + tick, c + tick * 1.4 - across, Color(0.85, 0.92, 1.0), 1.2)
