class_name PawnPortrait
extends Control
## A small picture of a person for the household bar, drawn with the same code as the
## pawn in the world.

var look: Dictionary = {}
var outfit: Dictionary = {}
var scale_factor := 1.0  # babies are drawn smaller
## Drawn as tall as they really are next to a grown-up (the creator, so that a child and a youth differ), not
## lifted a little so that the small chips in the bars stay readable.
var true_height := false


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var grown := PawnArt.stage_scale(str(outfit.get("stage", "adult")))
	var fit := grown if true_height else pow(grown, 0.6)  # the young are smaller here too, but not by as much as in the world
	draw_set_transform(Vector2(22, 22 + (1.0 - fit) * 9.0), 0.0, Vector2.ONE)
	PawnArt.draw(self, look, Vector2i(0, 1), 1.15 * scale_factor * fit, 0.0, false, outfit)
