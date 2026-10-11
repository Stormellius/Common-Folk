class_name Hud
extends CanvasLayer
## The on-screen interface: date and time, speed buttons, tile info, help text and
## short messages. It is built in code so the project stays easy to read and diff;
## move it into scene nodes whenever you want to style it in the editor.
##
## The HUD only shows state and calls GameClock.set_speed(). Keyboard shortcuts
## live in main.gd.

const SPEED_LABELS: Array[String] = ["II", "1x", "2x", "3x"]
const HELP_TEXT := "Click: pick person   Right-click: actions   B: build   Tab: next person   C: center   WASD: camera   Wheel: zoom   Space: pause   1-3: speed   G: grid   F5/F9: save/load   N: new world"
const BUILD_HELP := "Left-click: build (drag for walls and floors)   Right-click or Esc: put the tool away   Esc again or B: leave build mode"

## The player picked a household member in the bar at the bottom.
signal pawn_chosen(id: int)
## An entry of the right-click menu was picked (its id comes from PawnActions).
signal action_chosen(id: String)
## The Build button was pressed (or toggled from the keyboard via set_build_mode).
signal build_toggled(on: bool)
## A palette entry was picked: kind is "place", "floor", "move" or "remove", or "none" when it was put away.
signal build_tool_chosen(kind: String, id: String)
## A way of beginning was picked on the start screen (an id from data/starts.json).
signal start_chosen(id: String)

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
const BAND_COLORS := {
	"good": Color(0.48, 0.60, 0.32),
	"low": Color(0.80, 0.64, 0.25),
	"critical": Color(0.71, 0.28, 0.23),
}

var _needs_panel: PanelContainer
var _needs_name: Label
var _needs_traits: Label
var _needs_activity: Label
var _needs_job: Label
var _purse_label: Label
var _realm_label: Label
var _start_panel: PanelContainer
var _start_buttons: Dictionary = {}  # start id -> Button
var _mood_bar: ProgressBar
var _mood_fill: StyleBoxFlat
var _mood_label: Label
var _thoughts_text: RichTextLabel
var _relations_text: RichTextLabel
var _events_label: Label
var _need_rows: Dictionary = {}  # need id -> { "bar": ProgressBar, "fill": StyleBoxFlat }
var _household_row: HBoxContainer
var _action_menu := ActionMenu.new()
var _chips: Dictionary = {}  # pawn id -> Button
var _chip_marks: Dictionary = {}  # pawn id -> ColorRect, the strip showing how they are doing
var _game_over_panel: PanelContainer
var _game_over_label: Label
var _toast_serial := 0
var _build_button: Button
var _build_panel: PanelContainer
var _build_tabs: Dictionary = {}    # tab name -> HBoxContainer of item buttons
var _build_tab_buttons: Dictionary = {}  # tab name -> Button
var _build_items: Array[Button] = []
var _help_label: Label


func _ready() -> void:
	layer = 10
	_build_clock_panel()
	_build_corner_labels()
	_build_household_bar()
	_build_needs_panel()
	_build_build_ui()
	_build_game_over_panel()
	_build_start_panel()
	add_child(_action_menu)  # last, so it sits above the other panels
	_action_menu.action_chosen.connect(func(id: String) -> void: action_chosen.emit(id))
	GameClock.ticked.connect(func(_tick: int) -> void: refresh_clock())
	GameClock.time_set.connect(refresh_clock)
	GameClock.speed_changed.connect(_on_speed_changed)
	refresh_clock()
	_on_speed_changed(GameClock.speed_level)


## The household's purse, shown under the clock.
func set_purse(coins: int) -> void:
	_purse_label.text = "Purse: %s" % Economy.format(coins)


## Names of the town events going on, shown under the clock.
## Class, land title, next tax day, guild: the lines under the purse.
func set_realm(text: String) -> void:
	_realm_label.text = text
	_realm_label.visible = text != ""


## Shows the start screen: one button per way of beginning. `starts` is the list from data/starts.json.
func show_start_choice(starts: Array) -> void:
	for id in _start_buttons:
		_start_buttons[id].queue_free()
	_start_buttons.clear()
	var box := _start_panel.get_meta("box") as VBoxContainer
	for def in starts:
		var button := Button.new()
		button.text = "%s\n%s" % [str(def.get("name", def["id"])), str(def.get("text", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(520, 70)
		button.focus_mode = Control.FOCUS_NONE
		_style_button(button)
		button.pressed.connect(func() -> void: start_chosen.emit(str(def["id"])))
		box.add_child(button)
		_start_buttons[str(def["id"])] = button
	_start_panel.visible = true


func hide_start_choice() -> void:
	_start_panel.visible = false


func is_start_choice_open() -> bool:
	return _start_panel.visible


func set_events(names: Array[String]) -> void:
	_events_label.text = ", ".join(names)
	_events_label.visible = not names.is_empty()


func refresh_clock() -> void:
	var date := GameClock.get_date()
	_date_label.text = "%s %d, Y%d" % [date["season_name"], date["day"], date["year"]]
	_time_label.text = GameClock.get_time_text()


## Rebuilds the row of household portraits at the bottom of the screen.
func set_household(household: Household) -> void:
	for chip in _household_row.get_children():
		chip.queue_free()
	_chips.clear()
	_chip_marks.clear()
	var group := ButtonGroup.new()
	for pawn in household.playable():
		var chip := Button.new()
		chip.toggle_mode = true
		chip.button_group = group
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(88, 68)
		chip.tooltip_text = pawn.display_name
		_style_button(chip)
		var portrait := PawnPortrait.new()
		portrait.look = pawn.look
		portrait.position = Vector2(22, 2)
		chip.add_child(portrait)
		var label := Label.new()
		label.text = pawn.display_name.get_slice(" ", 0)
		label.position = Vector2(0, 48)
		label.size = Vector2(88, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		chip.add_child(label)
		var mark := ColorRect.new()  # green, amber or red: the worst of their needs
		mark.position = Vector2(4, 64)
		mark.size = Vector2(80, 3)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(mark)
		_chip_marks[pawn.id] = mark
		var id := pawn.id
		chip.pressed.connect(func() -> void: pawn_chosen.emit(id))
		_household_row.add_child(chip)
		_chips[pawn.id] = chip
	set_selected(household.selected_id)


## Colors each household chip by the worst need of that person, so you can see who is in
## trouble while you control someone else. Cheap enough to call every frame.
func update_household_status(household: Household) -> void:
	for pawn in household.pawns:
		if not _chip_marks.has(pawn.id):
			continue
		var worst_value := Needs.FULL
		var worst_need := ""
		for need_id in pawn.needs:
			if float(pawn.needs[need_id]) < worst_value and need_id in Needs.active_ids():
				worst_value = float(pawn.needs[need_id])
				worst_need = str(need_id)
		var band := Needs.band(worst_value)
		_chip_marks[pawn.id].color = BAND_COLORS[band]
		var tip := pawn.display_name
		if band != "good":
			tip += "  -  %s %s" % [str(DataRegistry.get_def("needs", worst_need).get("name", worst_need)), "is critical" if band == "critical" else "is low"]
		_chips[pawn.id].tooltip_text = tip


## Covers the screen with the end-of-playthrough message, or hides it (empty text).
func show_game_over(text: String) -> void:
	_game_over_panel.visible = text != ""
	_game_over_label.text = text


## Shows the selected person's name, what they are doing and their need bars (hidden if null).
func show_pawn(pawn: Pawn, activity: String, job: String = "", relations: Array[Dictionary] = []) -> void:
	_needs_panel.visible = pawn != null
	if pawn == null:
		return
	_needs_name.text = pawn.display_name
	var trait_names: Array[String] = []
	for trait_id in pawn.traits:
		trait_names.append(str(DataRegistry.get_def("traits", trait_id).get("name", trait_id)))
	_needs_traits.text = ", ".join(trait_names) if not trait_names.is_empty() else " "
	_needs_activity.text = activity
	_needs_job.text = job if job != "" else "Out of work"
	_mood_bar.value = pawn.mood
	_mood_fill.bg_color = BAND_COLORS[Needs.band(pawn.mood)]
	_mood_label.text = Mood.band_name(pawn.mood).capitalize()
	var lines: Array[String] = []
	for part in pawn.mood_parts.slice(0, 8):
		var value := float(part["mood"])
		var color := "#9cc27a" if value > 0.0 else "#d97a6c"
		lines.append("[color=%s]%s%d[/color]  %s" % [color, "+" if value > 0.0 else "-", roundi(absf(value)), str(part["text"])])
	_thoughts_text.text = "\n".join(lines) if not lines.is_empty() else "[color=#9e9c94]Nothing on their mind[/color]"
	var known: Array[String] = []
	for line in relations:
		var opinion := float(line["opinion"])
		known.append("[color=%s]%s[/color]  %s" % ["#9cc27a" if opinion > 0.0 else "#d97a6c", str(line["label"]), str(line["name"])])
	_relations_text.text = "\n".join(known) if not known.is_empty() else "[color=#9e9c94]Knows nobody well yet[/color]"
	for need_id in _need_rows:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		var row: Dictionary = _need_rows[need_id]
		row["bar"].value = value
		row["fill"].bg_color = BAND_COLORS[Needs.band(value)]


## Pops up the right-click menu at a screen position.
func open_action_menu(screen_position: Vector2, title: String, actions: Array[Dictionary]) -> void:
	_action_menu.open(screen_position, title, actions)


func close_action_menu() -> void:
	_action_menu.close()


## Highlights one household member without sending a signal.
func set_selected(id: int) -> void:
	# set_pressed_no_signal does not release the others in a ButtonGroup, so set every one.
	for chip_id in _chips:
		_chips[chip_id].set_pressed_no_signal(chip_id == id)


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

	_events_label = Label.new()
	_events_label.add_theme_font_size_override("font_size", 13)
	_events_label.add_theme_color_override("font_color", Color(0.62, 0.80, 0.55))
	_events_label.visible = false
	box.add_child(_events_label)
	_purse_label = Label.new()
	_purse_label.add_theme_font_size_override("font_size", 14)
	_purse_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.45))
	box.add_child(_purse_label)
	_realm_label = Label.new()
	_realm_label.add_theme_font_size_override("font_size", 12)
	_realm_label.add_theme_color_override("font_color", TEXT_DIM)
	_realm_label.visible = false
	_realm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_realm_label.custom_minimum_size = Vector2(198, 0)
	box.add_child(_realm_label)

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
	_help_label = help_panel.get_child(0).get_child(0) as Label
	add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)

	var info_panel := _make_panel_label("", TEXT_COLOR, 14)
	_info_label = info_panel.get_child(0).get_child(0) as Label
	add_child(info_panel)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_toast_label = _make_label("")
	add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 100)
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


func _build_needs_panel() -> void:
	_needs_panel = PanelContainer.new()
	add_child(_needs_panel)
	_needs_panel.add_theme_stylebox_override("panel", _flat_box(PANEL_COLOR, PANEL_BORDER, 1, 0))
	_needs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needs_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	_needs_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_needs_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	_needs_name = _make_plain_label(16, TEXT_COLOR)
	box.add_child(_needs_name)
	_needs_traits = _make_plain_label(12, TEXT_DIM)
	box.add_child(_needs_traits)
	_needs_activity = _make_plain_label(13, Color(0.84, 0.78, 0.55))
	box.add_child(_needs_activity)
	_needs_job = _make_plain_label(12, TEXT_DIM)
	_needs_job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_needs_job.custom_minimum_size = Vector2(190, 0)
	box.add_child(_needs_job)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(separator)

	var mood_row := HBoxContainer.new()
	mood_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mood_row.add_theme_constant_override("separation", 6)
	box.add_child(mood_row)
	var mood_title := _make_plain_label(13, TEXT_COLOR)
	mood_title.text = "Mood"
	mood_title.custom_minimum_size = Vector2(62, 0)
	mood_row.add_child(mood_title)
	_mood_bar = ProgressBar.new()
	_mood_bar.min_value = 0.0
	_mood_bar.max_value = 100.0
	_mood_bar.show_percentage = false
	_mood_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_bar.custom_minimum_size = Vector2(110, 10)
	_mood_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mood_fill = _flat_box(BAND_COLORS["good"], Color(0, 0, 0, 0), 0, 0)
	_mood_bar.add_theme_stylebox_override("background", _flat_box(Color(0.05, 0.05, 0.06), PANEL_BORDER, 1, 0))
	_mood_bar.add_theme_stylebox_override("fill", _mood_fill)
	mood_row.add_child(_mood_bar)
	_mood_label = _make_plain_label(12, TEXT_DIM)
	box.add_child(_mood_label)
	var mood_separator := HSeparator.new()
	mood_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mood_separator)

	for need_id in Needs.active_ids():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var label := _make_plain_label(13, TEXT_COLOR)
		label.text = str(DataRegistry.get_def("needs", need_id).get("name", need_id))
		label.custom_minimum_size = Vector2(62, 0)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = Needs.FULL
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(110, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := _flat_box(BAND_COLORS["good"], Color(0, 0, 0, 0), 0, 0)
		bar.add_theme_stylebox_override("background", _flat_box(Color(0.05, 0.05, 0.06), PANEL_BORDER, 1, 0))
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		_need_rows[need_id] = { "bar": bar, "fill": fill }
	var thoughts_separator := HSeparator.new()
	thoughts_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(thoughts_separator)
	_thoughts_text = RichTextLabel.new()
	_thoughts_text.bbcode_enabled = true
	_thoughts_text.fit_content = true
	_thoughts_text.scroll_active = false
	_thoughts_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thoughts_text.custom_minimum_size = Vector2(190, 0)
	_thoughts_text.add_theme_font_size_override("normal_font_size", 12)
	_thoughts_text.add_theme_color_override("default_color", TEXT_COLOR)
	box.add_child(_thoughts_text)
	var relations_separator := HSeparator.new()
	relations_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(relations_separator)
	_relations_text = RichTextLabel.new()
	_relations_text.bbcode_enabled = true
	_relations_text.fit_content = true
	_relations_text.scroll_active = false
	_relations_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relations_text.custom_minimum_size = Vector2(190, 0)
	_relations_text.add_theme_font_size_override("normal_font_size", 12)
	_relations_text.add_theme_color_override("default_color", TEXT_COLOR)
	box.add_child(_relations_text)
	_needs_panel.visible = false


func _make_plain_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_household_bar() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.add_theme_stylebox_override("panel", _flat_box(PANEL_COLOR, PANEL_BORDER, 1, 0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 4)
	panel.add_child(margin)
	_household_row = HBoxContainer.new()
	_household_row.add_theme_constant_override("separation", 4)
	margin.add_child(_household_row)


func _build_game_over_panel() -> void:
	_game_over_panel = PanelContainer.new()
	add_child(_game_over_panel)
	_game_over_panel.add_theme_stylebox_override("panel", _flat_box(Color(0.05, 0.04, 0.04, 0.88), PANEL_BORDER, 1, 0))
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_game_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_game_over_panel.add_child(margin)
	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 20)
	_game_over_label.add_theme_color_override("font_color", TEXT_COLOR)
	margin.add_child(_game_over_label)
	_game_over_panel.visible = false


func _build_start_panel() -> void:
	_start_panel = PanelContainer.new()
	add_child(_start_panel)
	_start_panel.add_theme_stylebox_override("panel", _flat_box(Color(0.05, 0.04, 0.04, 0.94), PANEL_BORDER, 1, 0))
	_start_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_start_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_start_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_start_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "How do you begin?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(title)
	_start_panel.set_meta("box", box)
	_start_panel.visible = false


# --- build mode -------------------------------------------------------------------

## Shows or hides the build palette, and keeps the Build button in step (no signal).
func set_build_mode(on: bool) -> void:
	_build_button.set_pressed_no_signal(on)
	_build_panel.visible = on
	_help_label.text = BUILD_HELP if on else HELP_TEXT
	if not on:
		clear_build_selection()


## Un-presses every palette entry without sending a signal.
func clear_build_selection() -> void:
	for button in _build_items:
		button.set_pressed_no_signal(false)


func _build_build_ui() -> void:
	_build_button = Button.new()
	_build_button.text = "Build  (B)"
	_build_button.toggle_mode = true
	_build_button.focus_mode = Control.FOCUS_NONE
	_build_button.custom_minimum_size = Vector2(110, 32)
	_style_button(_build_button)
	add_child(_build_button)
	_build_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	_build_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_build_button.toggled.connect(func(on: bool) -> void: build_toggled.emit(on))

	_build_panel = PanelContainer.new()
	add_child(_build_panel)
	_build_panel.add_theme_stylebox_override("panel", _flat_box(PANEL_COLOR, PANEL_BORDER, 1, 0))
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_panel.offset_top -= 84.0   # sits above the household bar
	_build_panel.offset_bottom -= 84.0
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	_build_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 3)
	box.add_child(tab_row)
	var items_holder := VBoxContainer.new()
	box.add_child(items_holder)

	# One tab per object category (furniture, structure...), one for floors, one for tools.
	var tabs: Dictionary = {}  # tab name -> array of { kind, id, name }
	for object_def in DataRegistry.get_list("objects"):
		if not bool(object_def.get("buildable", true)):
			continue
		var category := str(object_def.get("category", "furniture")).capitalize()
		if not tabs.has(category):
			tabs[category] = []
		tabs[category].append({ "kind": "place", "id": str(object_def["id"]), "name": str(object_def.get("name", object_def["id"])), "cost": int(object_def.get("cost", 0)) })
	if DataRegistry.count("floors") > 0:
		tabs["Floors"] = []
		for floor_def in DataRegistry.get_list("floors"):
			tabs["Floors"].append({ "kind": "floor", "id": str(floor_def["id"]), "name": str(floor_def.get("name", floor_def["id"])), "cost": int(floor_def.get("cost", 0)) })
	tabs["Tools"] = [
		{ "kind": "move", "id": "", "name": "Move" },
		{ "kind": "remove", "id": "", "name": "Remove" },
	]
	var group := ButtonGroup.new()
	group.allow_unpress = true
	var tab_group := ButtonGroup.new()
	for tab_name in tabs:
		var tab_button := Button.new()
		tab_button.text = tab_name
		tab_button.toggle_mode = true
		tab_button.button_group = tab_group
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.custom_minimum_size = Vector2(84, 26)
		_style_button(tab_button)
		tab_row.add_child(tab_button)
		_build_tab_buttons[tab_name] = tab_button
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.visible = false
		items_holder.add_child(row)
		_build_tabs[tab_name] = row
		for entry in tabs[tab_name]:
			var item := Button.new()
			item.toggle_mode = true
			item.button_group = group
			item.focus_mode = Control.FOCUS_NONE
			item.custom_minimum_size = Vector2(88, 68)
			item.tooltip_text = str(entry["name"]) + ("  -  %s" % Economy.format(int(entry["cost"])) if int(entry.get("cost", 0)) > 0 else "")
			_style_button(item)
			var icon := BuildIcon.new()
			icon.kind = str(entry["kind"])
			icon.id = str(entry["id"])
			icon.position = Vector2(22, 2)
			item.add_child(icon)
			var label := Label.new()
			label.text = str(entry["name"]) + ("  %s" % Economy.format(int(entry["cost"])) if int(entry.get("cost", 0)) > 0 else "")
			label.position = Vector2(0, 48)
			label.size = Vector2(88, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", TEXT_COLOR)
			item.add_child(label)
			var kind := str(entry["kind"])
			var id := str(entry["id"])
			item.toggled.connect(func(on: bool) -> void: build_tool_chosen.emit(kind if on else "none", id if on else ""))
			row.add_child(item)
			_build_items.append(item)
		tab_button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_build_tab(tab_name))
	if not tabs.is_empty():
		_build_tab_buttons[tabs.keys()[0]].set_pressed_no_signal(true)
		_show_build_tab(tabs.keys()[0])
	_build_panel.visible = false


func _show_build_tab(tab_name: String) -> void:
	for name in _build_tabs:
		_build_tabs[name].visible = (name == tab_name)
	for name in _build_tab_buttons:
		_build_tab_buttons[name].set_pressed_no_signal(name == tab_name)


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
	# set_pressed_no_signal does not release the others in a ButtonGroup, so set every one.
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == level)
