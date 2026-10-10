class_name PawnPortrait
extends Control
## A small picture of a person for the household bar, drawn with the same code as the
## pawn in the world.

var look: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_set_transform(Vector2(22, 22), 0.0, Vector2.ONE)
	PawnArt.draw(self, look, Vector2i(0, 1), 1.15, 0.0)
