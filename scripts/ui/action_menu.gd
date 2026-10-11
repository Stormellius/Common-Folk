class_name ActionMenu
extends Control
## The small pop-up list that appears where you right-click. Each entry is a flat button;
## entries that cannot be used are greyed out and say why. It closes when you pick
## something, click anywhere else, or press Escape.
##
## An invisible full-screen layer sits behind the list to notice clicks outside it. That
## layer passes the click on after closing the menu, so a right-click elsewhere opens a
## new menu straight away.

signal action_chosen(id: String)

const PANEL_COLOR := Color(0.11, 0.11, 0.12, 0.96)
const PANEL_BORDER := Color(0.42, 0.40, 0.36, 1.0)
const HOVER_COLOR := Color(0.30, 0.29, 0.25, 1.0)
const TEXT_COLOR := Color(0.92, 0.91, 0.87, 1.0)
const TEXT_DIM := Color(0.55, 0.54, 0.51, 1.0)
const MENU_WIDTH := 190.0

var _panel := PanelContainer.new()
var _box := VBoxContainer.new()
## One button per entry, in order; kept so tests (and later, keyboard use) can reach them.
var buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_box.add_theme_constant_override("separation", 1)
	_panel.add_child(_box)


## Shows the menu with its top-left corner at `screen_position` (moved if it would run off screen).
func open(screen_position: Vector2, title: String, actions: Array[Dictionary]) -> void:
	_clear()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", TEXT_DIM)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(heading)
	_box.add_child(HSeparator.new())
	for action in actions:
		var button := _make_button(action)
		_box.add_child(button)
		buttons.append(button)
	visible = true
	_panel.reset_size()
	var screen := get_viewport_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.position = Vector2(
		clampf(screen_position.x, 4.0, maxf(4.0, screen.x - size.x - 4.0)),
		clampf(screen_position.y, 4.0, maxf(4.0, screen.y - size.y - 4.0)))


func close() -> void:
	visible = false
	_clear()


func _clear() -> void:
	buttons.clear()
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()


func _make_button(action: Dictionary) -> Button:
	var button := Button.new()
	var enabled := bool(action.get("enabled", true))
	button.text = str(action.get("label", "?"))
	if not enabled:
		button.text += "  (%s)" % str(action.get("reason", "not possible"))
	button.disabled = not enabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _flat(HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _flat(HOVER_COLOR))
	button.add_theme_stylebox_override("disabled", _flat(Color(0, 0, 0, 0)))
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var id := str(action.get("id", ""))
	button.pressed.connect(func() -> void:
		close()
		action_chosen.emit(id))
	return button


func _flat(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(5)
	style.content_margin_left = 8
	return style


## Any click outside the list lands here: close, then let the click carry on to the map.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
