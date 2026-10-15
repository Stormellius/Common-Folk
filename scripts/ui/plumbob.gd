class_name Plumbob
extends Control
## The little diamond over the selected person's picture, green when they are content and shading
## to red as their mood sinks.

var color := Color(0.52, 0.8, 0.34)


func _init() -> void:
	custom_minimum_size = Vector2(22, 34)
	size = Vector2(22, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var top := Vector2(11, 1)
	var mid_left := Vector2(1, 17)
	var mid_right := Vector2(21, 17)
	var bottom := Vector2(11, 33)
	draw_colored_polygon(PackedVector2Array([top, mid_right, bottom, mid_left]), color)
	draw_colored_polygon(PackedVector2Array([top, mid_right, Vector2(11, 17)]), color.lightened(0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(11, 17), mid_right, bottom]), color.darkened(0.18))
	draw_colored_polygon(PackedVector2Array([top, Vector2(11, 17), mid_left]), color.lightened(0.12))
	draw_polyline(PackedVector2Array([top, mid_right, bottom, mid_left, top]), color.darkened(0.55), 1.5, true)
