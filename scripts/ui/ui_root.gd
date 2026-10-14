class_name UiRoot
extends Control
## The root of a screen of interface (the HUD, the menus): it covers the window, carries the theme
## and scales everything inside by the interface size setting. Anchors inside still work, because
## this node is made smaller by the same amount it is scaled up.


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
	var factor := clampf(Settings.ui_scale, 0.5, 3.0)
	scale = Vector2(factor, factor)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size / factor
