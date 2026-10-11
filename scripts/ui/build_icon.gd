class_name BuildIcon
extends Control
## The little picture on a build palette button: the object or floor itself, drawn by the same
## code as in the world, or a symbol for the Move and Remove tools.

var kind := ""   # "place", "floor", "move" or "remove"
var id := ""


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match kind:
		"place":
			draw_set_transform(Vector2(22, 22), 0.0, Vector2.ONE)
			ObjectArt.draw(self, id, 0.8, 0.0)
		"floor":
			FloorArt.draw(self, id, Rect2(Vector2(6, 6), Vector2(32, 32)), Vector2i(1, 1))
		"remove":
			var red := Color(0.86, 0.33, 0.28)
			draw_line(Vector2(10, 10), Vector2(34, 34), red, 4.0)
			draw_line(Vector2(34, 10), Vector2(10, 34), red, 4.0)
		"move":
			var tan := Color(0.92, 0.84, 0.50)
			draw_line(Vector2(22, 8), Vector2(22, 36), tan, 3.0)
			draw_line(Vector2(8, 22), Vector2(36, 22), tan, 3.0)
			for tip in [[Vector2(22, 6), Vector2(17, 13), Vector2(27, 13)], [Vector2(22, 38), Vector2(17, 31), Vector2(27, 31)],
					[Vector2(6, 22), Vector2(13, 17), Vector2(13, 27)], [Vector2(38, 22), Vector2(31, 17), Vector2(31, 27)]]:
				draw_colored_polygon(PackedVector2Array(tip), tan)
