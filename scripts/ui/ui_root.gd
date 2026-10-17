class_name UiRoot
extends Control
## The root of a screen of interface (the HUD, the menus): it covers the window, carries the theme
## and scales everything inside by the interface size setting. Anchors inside still work, because
## this node is made smaller by the same amount it is scaled up.
##
## The window itself is stretched (project.godot: canvas_items, expand), so the screen is always at
## least 1280 by 720 of these units whatever its shape; a wider or taller screen just has more room.

## The least room the screen inside needs: a bigger interface size is held back to what still fits.
var min_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # the drawn frames stay smooth when scaled
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(func(key: String) -> void:
		if key == "ui_scale":
			_fit())
	_fit()


## Turns a point on the screen (as input events give it) into this node's own coordinates.
func from_screen(screen_point: Vector2) -> Vector2:
	return screen_point / scale.x


func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var factor := clampf(Settings.ui_scale, 0.5, 3.0)
	if min_size.x > 0.0 and min_size.y > 0.0:
		factor = minf(factor, maxf(1.0, minf(screen.x / min_size.x, screen.y / min_size.y)))
	scale = Vector2(factor, factor)
	position = Vector2.ZERO
	size = screen / factor
