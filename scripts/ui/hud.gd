class_name Hud
extends CanvasLayer
## The on-screen interface: date and time, speed buttons, tile info, help text and
## short messages. It is built in code so the project stays easy to read and diff;
## move it into scene nodes whenever you want to style it in the editor.
##
## The HUD only shows state and calls GameClock.set_speed(). Keyboard shortcuts
## live in main.gd.

const SPEED_LABELS: Array[String] = ["II", "1x", "2x", "3x"]
const HELP_TEXT := "WASD move   Wheel zoom   Space pause   1-3 speed   G grid   F5 save   F9 load   N new"

# Flat dark panels with thin light borders, in the spirit of RimWorld's interface.
const PANEL_COLOR := Color(0.11, 0.11, 0.12, 0.92)
const PANEL_BORDER := Color(0.36, 0.35, 0.33, 1.0)
const BUTTON_COLOR := Color(0.16, 0.16, 0.17, 1.0)
const BUTTON_HOVER := Color(0.23, 0.23, 0.24, 1.0)
const BUTTON_ACTIVE := Color(0.42, 0.40, 0.33, 1.0)
const TEXT_COLOR := Color(0.88, 0.87, 0.83, 1.0)
const TEXT_DIM := Color(0.62, 0.61, 0.58, 1.0)

var _date_label: Label
var _time_label: Label
var _info_label: Label
var _toast_label: Label
var _speed_buttons: Array[Button] = []
var _toast_serial := 0


func _ready() -> void:
	layer = 10
	_build_clock_panel()
	_build_corner_labels()
	GameClock.ticked.connect(func(_tick: int) -> void: refresh_clock())
	GameClock.time_set.connect(refresh_clock)
	GameClock.speed_changed.connect(_on_speed_changed)
	refresh_clock()
	_on_speed_changed(GameClock.speed_level)


func refresh_clock() -> void:
	var date := GameClock.get_date()
	_date_label.text = "%s %d, Y%d" % [date["season_name"], date["day"], date["year"]]
	_time_label.text = GameClock.get_time_text()


func set_info(text: String) -> void:
	_info_label.text = text


## Shows a short message at the bottom of the screen for a couple of seconds.
func show_message(text: String, seconds: float = 2.5) -> void:
	_toast_label.text = text
	_toast_serial += 1
	var serial := _toast_serial
	await get_tree().create_timer(seconds).timeout
	if serial == _toast_serial:  # a newer message replaces this one
		_toast_label.text = ""


# --- building the UI -----------------------------------------------------------

func _build_clock_panel() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.add_theme_stylebox_override("panel", _flat_box(PANEL_COLOR, PANEL_BORDER, 1, 0))
	panel.custom_minimum_size = Vector2(210, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 24)
	_time_label.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(_time_label)
	_date_label = Label.new()
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date_label.add_theme_font_size_override("font_size", 14)
	_date_label.add_theme_color_override("font_color", TEXT_DIM)
	top.add_child(_date_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	var group := ButtonGroup.new()
	for level in SPEED_LABELS.size():
		var button := Button.new()
		button.text = SPEED_LABELS[level]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE  # so Space is never swallowed by a focused button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button)
		button.pressed.connect(_on_speed_button_pressed.bind(level))
		row.add_child(button)
		_speed_buttons.append(button)


func _build_corner_labels() -> void:
	var help_panel := _make_panel_label(HELP_TEXT, TEXT_DIM, 13)
	add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)

	var info_panel := _make_panel_label("", TEXT_COLOR, 14)
	_info_label = info_panel.get_child(0).get_child(0) as Label
	add_child(info_panel)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_toast_label = _make_label("")
	add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 48)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _flat_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _flat_box(BUTTON_COLOR, PANEL_BORDER, 1, 0))
	button.add_theme_stylebox_override("hover", _flat_box(BUTTON_HOVER, PANEL_BORDER, 1, 0))
	button.add_theme_stylebox_override("pressed", _flat_box(BUTTON_ACTIVE, TEXT_COLOR, 1, 0))
	button.add_theme_stylebox_override("hover_pressed", _flat_box(BUTTON_ACTIVE, TEXT_COLOR, 1, 0))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 14)


## A small flat panel around one label; the label is panel.get_child(0).get_child(0).
func _make_panel_label(text: String, color: Color, size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat_box(PANEL_COLOR, PANEL_BORDER, 1, 0))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 8)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 4)
	panel.add_child(margin)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	margin.add_child(label)
	return panel


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


# --- signals -------------------------------------------------------------------

func _on_speed_button_pressed(level: int) -> void:
	GameClock.set_speed(level)


func _on_speed_changed(level: int) -> void:
	if level >= 0 and level < _speed_buttons.size():
		_speed_buttons[level].set_pressed_no_signal(true)
