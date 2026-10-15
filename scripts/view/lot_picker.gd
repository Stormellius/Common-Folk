class_name LotPicker
extends Node2D
## Over the map while the player chooses where to settle: each plot on offer is outlined and named, the chosen
## one glows. Clicking a plot chooses it.

signal picked(lot_id: String)

var options: Array[Dictionary] = []
var chosen := ""
var camera: Camera2D


func show_options(new_options: Array[Dictionary], first: String) -> void:
	options = new_options
	chosen = first
	visible = true
	z_index = 50
	queue_redraw()


func hide_picker() -> void:
	visible = false
	options = []


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var spot := get_global_mouse_position() / float(MapView.TILE_SIZE)
	for option in options:
		if (option["rect"] as Rect2i).grow(1).has_point(Vector2i(floori(spot.x), floori(spot.y))):
			chosen = str(option["id"])
			picked.emit(chosen)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var tile := float(MapView.TILE_SIZE)
	var zoom := camera.zoom.x if camera != null else 1.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	for option in options:
		var rect: Rect2i = option["rect"]
		var area := Rect2(Vector2(rect.position) * tile, Vector2(rect.size) * tile)
		var on := str(option["id"]) == chosen
		var color := Color(0.98, 0.82, 0.38) if on else Color(0.82, 0.92, 0.98)
		draw_rect(area, Color(color, 0.22 + (0.16 * pulse if on else 0.0)))
		draw_rect(area, Color(color, 0.95 if on else 0.7), false, (4.0 if on else 2.0) / zoom)
		var font := ThemeDB.fallback_font
		var size := int(clampf(22.0 / zoom, 18.0, 64.0))
		var label := str(option.get("name", ""))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, area.get_center() + Vector2(-width * 0.5, size * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(font, area.get_center() + Vector2(-width * 0.5, size * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.96, 0.84))
