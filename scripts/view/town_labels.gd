class_name TownLabels
extends Node2D
## The names of the towns, written large over the map when the camera is pulled back far enough
## that the streets are small, so you can find your way between them. It only reads the world.

const SHOW_BELOW := 0.55   # camera zoom
const FADE_FROM := 0.40    # fully shown at this zoom and below

var world: WorldState


func bind(new_world: WorldState) -> void:
	world = new_world
	queue_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	visible = world != null and camera != null and camera.zoom.x < SHOW_BELOW
	if visible:
		queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if world == null or camera == null:
		return
	var alpha := clampf((SHOW_BELOW - camera.zoom.x) / (SHOW_BELOW - FADE_FROM), 0.0, 1.0)
	var scale := 1.0 / camera.zoom.x
	var font := UiTheme.HEADING_FONT
	var small := UiTheme.CAPS_FONT
	for town in world.towns:
		var at := Vector2(town["center"]) * MapView.TILE_SIZE
		draw_set_transform(at, 0.0, Vector2(scale, scale))
		var name_text := str(town["name"])
		draw_string_outline(font, Vector2(-200.0, 0.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 30, 7, Color(0.05, 0.03, 0.02, 0.9 * alpha))
		draw_string(font, Vector2(-200.0, 0.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 30, Color(UiTheme.INK, alpha))
		var kind := str(town.get("kind", "town")).capitalize()
		if bool(town.get("home", false)):
			kind += "  -  your home"
		draw_string_outline(small, Vector2(-200.0, 22.0), kind, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 15, 5, Color(0.05, 0.03, 0.02, 0.85 * alpha))
		draw_string(small, Vector2(-200.0, 22.0), kind, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 15, Color(UiTheme.GOLD, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
