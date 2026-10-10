class_name Hud
extends CanvasLayer
## The on-screen interface: date and time, speed buttons, tile info, help text and
## short messages. It is built in code so the project stays easy to read and diff;
## move it into scene nodes whenever you want to style it in the editor.
##
## The HUD only shows state and calls GameClock.set_speed(). Keyboard shortcuts
## live in main.gd.

const SPEED_LABELS: Array[String] = ["Pause", "1x", "2x", "3x"]
const HELP_TEXT := """WASD / arrows: move camera (Shift = faster)
Mouse wheel: zoom    Middle mouse drag: pan
Space: pause    1 / 2 / 3: speed
G: grid    Home: recenter
F5: save    F9: load    N: new world"""

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
	_date_label.text = "%s %d, Year %d" % [date["season_name"], date["day"], date["year"]]
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
	panel.custom_minimum_size = Vector2(230, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_date_label = Label.new()
	box.add_child(_date_label)

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 28)
	box.add_child(_time_label)

	var row := HBoxContainer.new()
	box.add_child(row)
	var group := ButtonGroup.new()
	for level in SPEED_LABELS.size():
		var button := Button.new()
		button.text = SPEED_LABELS[level]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE  # so Space is never swallowed by a focused button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_speed_button_pressed.bind(level))
		row.add_child(button)
		_speed_buttons.append(button)


func _build_corner_labels() -> void:
	var help := _make_label(HELP_TEXT)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)

	_info_label = _make_label("")
	add_child(_info_label)
	_info_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_info_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_toast_label = _make_label("")
	add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 48)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


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
