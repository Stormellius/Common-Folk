class_name ActionMenu
extends Control
## The small pop-up list that appears where you right-click. Each entry is a flat button;
## entries that cannot be used are greyed out and say why. It closes when you pick
## something, click anywhere else, or press Escape. UiTheme gives it its look.
##
## An invisible full-screen layer sits behind the list to notice clicks outside it. That
## layer passes the click on after closing the menu, so a right-click elsewhere opens a
## new menu straight away.

signal action_chosen(id: String)

const MENU_WIDTH := 200.0

var _panel := PanelContainer.new()
var _box := VBoxContainer.new()
## One button per entry, in order; kept so tests (and later, keyboard use) can reach them.
var buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	_panel.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_box.add_theme_constant_override("separation", 1)
	_panel.add_child(_box)


## Shows the menu with its top-left corner at `at` (in the interface's own coordinates; moved if
## it would run off the screen).
func open(at: Vector2, title: String, actions: Array[Dictionary]) -> void:
	_clear()
	var heading := Label.new()
	heading.text = title
	heading.theme_type_variation = "CapsLabel"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(heading)
	_box.add_child(HSeparator.new())
	for action in actions:
		var button := _make_button(action)
		_box.add_child(button)
		buttons.append(button)
	visible = true
	_panel.reset_size()
	var area := size if size != Vector2.ZERO else get_viewport_rect().size
	var wanted := _panel.get_combined_minimum_size()
	_panel.position = Vector2(
		clampf(at.x, 4.0, maxf(4.0, area.x - wanted.x - 4.0)),
		clampf(at.y, 4.0, maxf(4.0, area.y - wanted.y - 4.0)))


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
	button.theme_type_variation = "MenuItemButton"
	var id := str(action.get("id", ""))
	button.pressed.connect(func() -> void:
		close()
		action_chosen.emit(id))
	return button


## Any click outside the list lands here: close, then let the click carry on to the map.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
