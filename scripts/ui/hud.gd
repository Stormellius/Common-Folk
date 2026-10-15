class_name Hud
extends CanvasLayer
## The on-screen interface while playing: date and time, speed buttons, the purse, your folk at
## the bottom, the panel about the one you control, tile info, help and short messages. It is
## built in code so the project stays easy to read and diff; UiTheme gives it its look.
##
## The HUD only shows state and calls GameClock.set_speed(). Keyboard shortcuts live in main.gd;
## the title screen, saving, loading and settings are in Menus.

const SPEED_LABELS: Array[String] = ["II", "1x", "3x", "10x", "30x"]
const HINT_TEXT := "Right-click: actions   B: build   I: details   H: help   Esc: menu"
const BUILD_HELP := "Left-click: build (drag for walls and floors)    Right-click or Esc: put the tool away    Esc again or B: leave build mode"
## The help panel (H): [keys, what they do].
const HELP_LINES: Array = [
	["Left-click", "Pick one of your folk"],
	["Right-click", "What they can do there"],
	["Tab / Shift+Tab", "Next / previous of your folk"],
	["C", "Center on them"],
	["WASD, arrows", "Move the camera (Shift: faster)"],
	["Wheel, middle drag", "Zoom, pan"],
	["Space, 1 to 4", "Pause, speed"],
	["T, M, Home", "Next town, whole map, your home"],
	["B", "Build mode (plans, then someone builds)"],
	["R", "Roofs: by the zoom, shown, hidden"],
	["G", "Grid"],
	["F5 / F9", "Quick save / load the newest save"],
	["F11", "Full screen"],
	["F", "The town's families: play another, or move house"],
	["N", "A new game"],
	["Esc", "Menu"],
]

## The player picked one of their folk in the bar at the bottom.
signal pawn_chosen(id: int)
## An entry of the right-click menu was picked (its id comes from PawnActions).
signal action_chosen(id: String)
## The Build button was pressed (or toggled from the keyboard via set_build_mode).
signal build_toggled(on: bool)
## A palette entry was picked: kind is "place", "floor", "move" or "remove", or "none" when it was put away.
signal build_tool_chosen(kind: String, id: String)
## The Menu button was pressed.
signal level_requested(level: int)
signal menu_requested

const TEXT_COLOR := UiTheme.INK
const TEXT_DIM := UiTheme.INK_DIM
const BAND_COLORS := {
	"good": UiTheme.GOOD,
	"low": UiTheme.LOW,
	"critical": UiTheme.BAD,
}

var _root: UiRoot
var _date_label: Label
var _time_label: Label
var _season_glyph: SeasonGlyph
var _info_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _speed_buttons: Array[Button] = []
var _hint_label: Label
var _help_panel: PanelContainer

const SKILL_ROWS := 5
const PALETTE_WIDTH := 700.0   # the build palette wraps to rows this wide
const DETAILS_TOP := 100.0   # below the bar at the top
const BOTTOM_ROOM := 170.0   # what the panels along the bottom take

var _needs_panel: PanelContainer   # the details on the left: dreams, skills, thoughts, friends
var _control_panel: PanelContainer  # the bottom one: picture, name, mood, needs
var _bottom: HBoxContainer
var _bottom_right: VBoxContainer
var _details_button: Button
var _details_open := false
var _big_portrait: PawnPortrait
var _portrait_key := ""
var _needs_name: Label
var _needs_age: Label
var _needs_traits: Label
var _needs_activity: Label
var _needs_job: Label
var _purse_label: Label
var _realm_label: Label
var _place_label: Label
var _stock_label: Label
var _goods_row: HFlowContainer
var _goods_shown := {}
var _animals_label: Label
var _building_label: Label
var _mood_bar: ProgressBar
var _mood_fill: StyleBoxFlat
var _mood_label: Label
var _dream_title: Label
var _dream_step: Label
var _dream_bar: ProgressBar
var _wish_text: RichTextLabel
var _dream_done: Label
var _thoughts_text: RichTextLabel
var _relations_text: RichTextLabel
var _skill_rows: Array[Dictionary] = []  # { "row": HBoxContainer, "name": Label, "bar": ProgressBar }
var _skill_note: Label
var _events_label: Label
var _need_rows: Dictionary = {}  # need id -> { "bar": ProgressBar, "fill": StyleBoxFlat }
var _household_row: HBoxContainer
var _action_menu := ActionMenu.new()
var _chips: Dictionary = {}  # pawn id -> Button
var _chip_marks: Dictionary = {}  # pawn id -> ColorRect, the strip showing how they are doing
var _baby_chips: Dictionary = {}  # baby's id -> its chip (babies are shown, not chosen)
var _toast_serial := 0
var _build_button: Button
var _level_button: Button
var _build_panel: PanelContainer
var _build_tabs: Dictionary = {}    # tab name -> HBoxContainer of item buttons
var _build_tab_buttons: Dictionary = {}  # tab name -> Button
var _build_items: Array[Button] = []
var _palette_scroll: ScrollContainer


func _ready() -> void:
	layer = 10
	_root = UiRoot.new()
	add_child(_root)
	_build_top_bar()
	_build_clock_panel()
	_build_bottom_bar()
	_build_needs_panel()
	_build_build_ui()
	_build_toast()
	_build_help_panel()
	_root.add_child(_action_menu)  # last, so it sits above the other panels
	_action_menu.action_chosen.connect(func(id: String) -> void: action_chosen.emit(id))
	GameClock.ticked.connect(func(_tick: int) -> void: refresh_clock())
	GameClock.time_set.connect(refresh_clock)
	GameClock.speed_changed.connect(_on_speed_changed)
	refresh_clock()
	_on_speed_changed(GameClock.speed_level)


## Where the person you control is: a town's name, or "Open country".
func set_place(text: String) -> void:
	_place_label.text = text


## The household's purse, shown under the clock, and what it has gathered.
func set_purse(coins: int, stock: Dictionary = {}) -> void:
	_purse_label.text = "Purse  %s" % Economy.format(coins)
	_show_goods(stock)


## The stockpile: a painted icon and a count for each good that has an icon, and words for the tools and the rest.
func _show_goods(stock: Dictionary) -> void:
	var painted := Settings.illustrated_art
	var key := {}
	for item_id in stock:
		key[item_id] = stock[item_id]
	key["_painted"] = painted
	if key == _goods_shown:
		return
	_goods_shown = key
	for child in _goods_row.get_children():
		child.queue_free()
	var words: Array[String] = []
	for item_id in Economy.resource_ids():
		var count := int(stock.get(item_id, 0))
		if count <= 0:
			continue
		var icon := SpriteBank.texture("goods/" + str(item_id)) if painted else null
		if icon == null:
			words.append("%d %s" % [count, Economy.resource_name(item_id).to_lower()])
			continue
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.tooltip_text = Economy.resource_name(item_id)
		var picture := TextureRect.new()
		picture.texture = icon
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.custom_minimum_size = Vector2(24, 24)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(picture)
		var number := _make_label(str(count), "")
		number.add_theme_font_size_override("font_size", 13)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(number)
		_goods_row.add_child(cell)
	for tool_id in Skills.tool_ids():
		if int(stock.get(tool_id, 0)) > 0:
			words.append("%d %s" % [int(stock[tool_id]), Skills.tool_name(tool_id).to_lower()])
	_stock_label.text = ", ".join(words) if not words.is_empty() else ("" if _goods_row.get_child_count() > 0 else "Nothing stockpiled")
	_stock_label.visible = _stock_label.text != ""


## The animals the household keeps, under the stockpile (nothing shown when there are none).
func set_animals(text: String) -> void:
	_animals_label.text = text
	_animals_label.visible = text != ""


## "Building: 5 planned, 1 at work" under the animals (nothing shown when nothing is planned).
func set_building(text: String) -> void:
	_building_label.text = text
	_building_label.visible = text != ""


## Class, land title, next tax day, guild: the lines under the purse.
func set_realm(text: String) -> void:
	_realm_label.text = text
	_realm_label.visible = text != ""


## Names of the town events going on, shown under the clock.
func set_events(names: Array[String]) -> void:
	_events_label.text = ", ".join(names)
	_events_label.visible = not names.is_empty()


func refresh_clock() -> void:
	var date := GameClock.get_date()
	_date_label.text = "%s %d, year %d" % [date["season_name"], date["day"], date["year"]]
	_time_label.text = GameClock.get_time_text()
	_season_glyph.season_id = str(date.get("season_id", ""))


## Rebuilds the row of your folk at the bottom of the screen.
func set_household(household: Household) -> void:
	for chip in _household_row.get_children():
		chip.queue_free()
	_chips.clear()
	_chip_marks.clear()
	_baby_chips.clear()
	var group := ButtonGroup.new()
	for pawn in household.playable():
		var chip := Button.new()
		chip.toggle_mode = true
		chip.button_group = group
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(80, 70)
		_sims_button(chip)
		chip.tooltip_text = pawn.display_name
		var portrait := PawnPortrait.new()
		portrait.look = pawn.look
		portrait.outfit = PawnArt.outfit_for(pawn)
		portrait.position = Vector2(18, 3)
		chip.add_child(portrait)
		var label := Label.new()
		label.text = pawn.display_name.get_slice(" ", 0)
		label.position = Vector2(0, 47)
		label.size = Vector2(80, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 13)
		chip.add_child(label)
		var mark := ColorRect.new()  # green, amber or red: the worst of their needs
		mark.position = Vector2(8, 64)
		mark.size = Vector2(64, 3)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(mark)
		_chip_marks[pawn.id] = mark
		var id := pawn.id
		chip.pressed.connect(func() -> void: pawn_chosen.emit(id))
		_household_row.add_child(chip)
		_chips[pawn.id] = chip
	for baby in household.pawns:
		if baby.is_infant():
			_household_row.add_child(_baby_chip(baby))
	set_selected(household.selected_id)


## A smaller chip for a baby: it cannot be controlled, but its strip shows how it is cared for and
## its tooltip what it needs. Right-click the baby on the map to see to it.
func _baby_chip(baby: Pawn) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(58, 70)
	chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	chip.tooltip_text = baby.display_name
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(holder)
	var portrait := PawnPortrait.new()
	portrait.look = baby.look
	portrait.outfit = PawnArt.outfit_for(baby)
	portrait.scale_factor = 1.0
	portrait.position = Vector2(3, 8)
	holder.add_child(portrait)
	var label := Label.new()
	label.text = baby.display_name.get_slice(" ", 0)
	label.position = Vector2(-6, 42)
	label.size = Vector2(62, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	holder.add_child(label)
	var mark := ColorRect.new()
	mark.position = Vector2(2, 58)
	mark.size = Vector2(46, 3)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(mark)
	_chip_marks[baby.id] = mark
	_baby_chips[baby.id] = chip
	return chip


## Colors each chip by the worst need of that person, so you can see who is in trouble while you
## control someone else. Cheap enough to call every frame.
func update_household_status(household: Household) -> void:
	for pawn in household.pawns:
		if not _chip_marks.has(pawn.id):
			continue
		if _baby_chips.has(pawn.id):
			_update_baby_chip(pawn)
			continue
		var worst_value := Needs.FULL
		var worst_need := ""
		for need_id in pawn.needs:
			if float(pawn.needs[need_id]) < worst_value and need_id in Needs.active_ids():
				worst_value = float(pawn.needs[need_id])
				worst_need = str(need_id)
		var band := "critical" if pawn.is_dying() else Needs.band(worst_value)
		_chip_marks[pawn.id].color = BAND_COLORS[band]
		var tip := pawn.display_name
		if pawn.is_dying():
			tip += "  -  dying"
		elif band != "good":
			tip += "  -  %s %s" % [str(DataRegistry.get_def("needs", worst_need).get("name", worst_need)), "is critical" if band == "critical" else "is low"]
		_chips[pawn.id].tooltip_text = tip


func _update_baby_chip(baby: Pawn) -> void:
	var worst := Babies.worst_care(baby)
	_chip_marks[baby.id].color = BAND_COLORS["critical" if Babies.is_crying(baby) else Needs.band(worst)]
	var tip := "%s, a baby" % baby.display_name
	for def in Babies.care_defs():
		tip += "\n%s: %d%%" % [str(def.get("name", def["id"])), roundi(float(baby.care.get(str(def["id"]), Needs.FULL)) / Needs.FULL * 100.0)]
	if Babies.is_crying(baby):
		tip += "\nCrying! Right-click the baby to see to it."
	_baby_chips[baby.id].tooltip_text = tip


## Shows the selected person's name, what they are doing and their need bars (hidden if null).
func show_pawn(pawn: Pawn, activity: String, job: String = "", relations: Array[Dictionary] = [], dreams: Dictionary = {}, worn: String = "", pieces: Variant = null) -> void:
	_control_panel.visible = pawn != null
	_needs_panel.visible = pawn != null and _details_open
	if pawn == null:
		return
	var dressed := PawnArt.outfit_for(pawn, worn if worn != "" else "casual", pieces)
	var portrait_key := "%s%s" % [str(pawn.look), str(dressed)]
	if portrait_key != _portrait_key:
		_portrait_key = portrait_key
		_big_portrait.look = pawn.look
		_big_portrait.outfit = dressed
		_big_portrait.queue_redraw()

	_needs_name.text = pawn.display_name
	_needs_age.text = Life.describe_age(pawn) + (", née %s" % pawn.maiden_name.get_slice(" ", 1) if pawn.maiden_name != "" and pawn.maiden_name != pawn.display_name else "") + (", in %s" % Clothing.name_of(worn).to_lower() if worn != "" else "")
	var trait_names: Array[String] = []
	for trait_id in pawn.traits:
		trait_names.append(str(DataRegistry.get_def("traits", trait_id).get("name", trait_id)))
	_needs_traits.text = ", ".join(trait_names) if not trait_names.is_empty() else " "
	_needs_activity.text = activity
	_needs_job.text = job if job != "" else "Out of work"
	_mood_bar.value = pawn.mood
	_mood_fill.bg_color = BAND_COLORS[Needs.band(pawn.mood)]
	_mood_label.text = Mood.band_name(pawn.mood).capitalize()
	_show_dreams(dreams)
	var lines: Array[String] = []
	for part in pawn.mood_parts.slice(0, 6):
		var value := float(part["mood"])
		var color := "#a9c784" if value > 0.0 else "#e08a72"
		lines.append("[color=%s][b]%s%d[/b][/color]  %s" % [color, "+" if value > 0.0 else "-", roundi(absf(value)), str(part["text"])])
	_thoughts_text.text = "\n".join(lines) if not lines.is_empty() else "[color=#a89c86]Nothing on their mind[/color]"
	var known: Array[String] = []
	for line in relations:
		var opinion := float(line["opinion"])
		known.append("[color=%s]%s[/color]  %s" % ["#a9c784" if opinion > 0.0 else "#e08a72", str(line["label"]), str(line["name"])])
	_relations_text.text = "\n".join(known) if not known.is_empty() else "[color=#a89c86]Knows nobody well yet[/color]"
	var skills := Skills.known(pawn)
	for index in SKILL_ROWS:
		var shown: bool = index < skills.size()
		var entry: Dictionary = _skill_rows[index]
		entry["row"].visible = shown
		if shown:
			var skill_id := str(skills[index]["id"])
			var rank_level := Skills.level(pawn, skill_id)
			entry["name"].text = "%s %d" % [Skills.name_of(skill_id), rank_level]
			entry["name"].tooltip_text = "%s (%s). %s" % [Skills.name_of(skill_id), Skills.rank_name(rank_level), str(DataRegistry.get_def("skills", skill_id).get("text", ""))]
			entry["bar"].value = Skills.progress(pawn, skill_id)
	var notes: Array[String] = []
	if skills.is_empty():
		notes.append("No skills to speak of yet")
	if pawn.tool != "":
		notes.append("%s in hand" % Skills.tool_name(pawn.tool))
	if not pawn.talents.is_empty():
		var gifts: Array[String] = []
		for talent in pawn.talents:
			gifts.append(Skills.name_of(talent).to_lower())
		notes.append("Gifted at " + " and ".join(gifts))
	if pawn.family_trade != "":
		notes.append("Family trade: " + Skills.name_of(pawn.family_trade).to_lower())
	_skill_note.text = ". ".join(notes)
	for need_id in _need_rows:
		var value := float(pawn.needs.get(need_id, Needs.FULL))
		var row: Dictionary = _need_rows[need_id]
		row["bar"].value = value
		row["fill"].bg_color = BAND_COLORS[Needs.band(value)]
	_fit_needs_panel()


## The panel is made smaller if all it has to say does not fit on the screen.
func _fit_needs_panel() -> void:
	if not _needs_panel.visible:
		return
	var wanted := _needs_panel.get_combined_minimum_size().y
	var factor := clampf((_root.size.y - DETAILS_TOP - BOTTOM_ROOM) / maxf(wanted, 1.0), 0.5, 1.0)
	if absf(factor - _needs_panel.scale.x) > 0.005:
		_needs_panel.scale = Vector2(factor, factor)
	_needs_panel.pivot_offset = Vector2.ZERO


## Pops up the right-click menu at a screen position.
func open_action_menu(screen_position: Vector2, title: String, actions: Array[Dictionary]) -> void:
	_action_menu.open(_root.from_screen(screen_position), title, actions)


func close_action_menu() -> void:
	_action_menu.close()


## Highlights one of your folk without sending a signal.
func set_selected(id: int) -> void:
	# set_pressed_no_signal does not release the others in a ButtonGroup, so set every one.
	for chip_id in _chips:
		_chips[chip_id].set_pressed_no_signal(chip_id == id)


func set_info(text: String) -> void:
	_info_label.text = text


## H: shows or hides the list of keys.
func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible


## Shows a short message above your folk for a couple of seconds.
func show_message(text: String, seconds: float = 2.5) -> void:
	_toast_label.text = text
	_toast_panel.visible = text != ""
	_toast_panel.reset_size()
	_toast_serial += 1
	var serial := _toast_serial
	await get_tree().create_timer(seconds).timeout
	if serial == _toast_serial:  # a newer message replaces this one
		_toast_label.text = ""
		_toast_panel.visible = false


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	_sims_panel(panel, 0.88, 8)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var menu := Button.new()
	menu.text = "Menu"
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(70, 28)
	_sims_button(menu)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu)
	_details_button = Button.new()
	_details_button.text = "Details"
	_details_button.toggle_mode = true
	_details_button.focus_mode = Control.FOCUS_NONE
	_details_button.custom_minimum_size = Vector2(80, 28)
	_sims_button(_details_button)
	_details_button.toggled.connect(func(on: bool) -> void: set_details_open(on))
	row.add_child(_details_button)
	_hint_label = _make_label(HINT_TEXT, "DimLabel")
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(_hint_label)
	_info_label = _make_label("", "")
	_info_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_info_label)


func _build_help_panel() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.theme_type_variation = "ParchmentPanel"
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_help_panel)
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	_help_panel.offset_top += 84.0
	_help_panel.offset_bottom += 84.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(box)
	box.add_child(_make_label("Keys", "InkHeader"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for line in HELP_LINES:
		var key := _make_label(str(line[0]), "InkLabel")
		key.add_theme_font_override("font", UiTheme.bold_font())
		key.add_theme_font_size_override("font_size", 14)
		grid.add_child(key)
		var does := _make_label(str(line[1]), "InkLabel")
		does.add_theme_font_size_override("font_size", 14)
		grid.add_child(does)
	_help_panel.visible = false


func _build_clock_panel() -> void:
	var panel := PanelContainer.new()
	_root.add_child(panel)
	_sims_panel(panel)
	panel.custom_minimum_size = Vector2(240, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	_time_label = _make_label("", "HeaderLabel")
	_time_label.add_theme_font_size_override("font_size", 30)
	top.add_child(_time_label)
	var date_box := VBoxContainer.new()
	date_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(date_box)
	_date_label = _make_label("", "")
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_date_label.add_theme_font_size_override("font_size", 14)
	date_box.add_child(_date_label)
	_place_label = _make_label("", "DimLabel")
	_place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place_label.add_theme_font_size_override("font_size", 12)
	date_box.add_child(_place_label)
	_season_glyph = SeasonGlyph.new()
	_season_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_season_glyph)

	_events_label = _make_label("", "")
	_events_label.add_theme_font_size_override("font_size", 13)
	_events_label.add_theme_color_override("font_color", Color(0.66, 0.82, 0.55))
	_events_label.visible = false
	box.add_child(_events_label)
	_purse_label = _make_label("", "")
	_purse_label.add_theme_font_override("font", UiTheme.bold_font())
	_purse_label.add_theme_font_size_override("font_size", 15)
	_purse_label.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_purse_label)
	_stock_label = _make_label("", "DimLabel")
	_stock_label.add_theme_font_size_override("font_size", 12)
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_label.custom_minimum_size = Vector2(214, 0)
	_goods_row = HFlowContainer.new()
	_goods_row.add_theme_constant_override("h_separation", 8)
	_goods_row.add_theme_constant_override("v_separation", 2)
	_goods_row.custom_minimum_size = Vector2(214, 0)
	box.add_child(_goods_row)
	box.add_child(_stock_label)
	_animals_label = _make_label("", "DimLabel")
	_animals_label.add_theme_font_size_override("font_size", 12)
	_animals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animals_label.custom_minimum_size = Vector2(214, 0)
	box.add_child(_animals_label)
	_building_label = _make_label("", "DimLabel")
	_building_label.add_theme_font_size_override("font_size", 12)
	_building_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.95))
	box.add_child(_building_label)
	_realm_label = _make_label("", "DimLabel")
	_realm_label.add_theme_font_size_override("font_size", 12)
	_realm_label.visible = false
	_realm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_realm_label.custom_minimum_size = Vector2(214, 0)
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
		button.custom_minimum_size = Vector2(0, 30)
		_sims_button(button)
		button.pressed.connect(_on_speed_button_pressed.bind(level))
		row.add_child(button)
		_speed_buttons.append(button)


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.theme_type_variation = "ParchmentPanel"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_panel)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 160)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.add_theme_stylebox_override("panel", _toast_box())
	_toast_label = _make_label("", "InkLabel")
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false


## The parchment, with less room around the words than a dialog.
func _toast_box() -> StyleBox:
	var box := UiTheme.get_theme().get_stylebox("panel", "ParchmentPanel").duplicate() as StyleBoxTexture
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != "":
		label.theme_type_variation = variation
	return label


func _section(box: VBoxContainer, title: String) -> void:
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	box.add_child(_make_label(title, "CapsLabel"))


## The ambition and its step, and the small wishes (from Ambitions.summary).
func _show_dreams(dreams: Dictionary) -> void:
	var ambition := str(dreams.get("ambition", ""))
	var wishes: Array = dreams.get("wishes", [])
	var done: Array = dreams.get("done", [])
	_dream_title.visible = ambition != "" or not done.is_empty()
	_dream_done.visible = ambition != "" and not done.is_empty()
	if _dream_done.visible:
		_dream_done.text = "Fulfilled: " + ", ".join(done)
	_dream_step.visible = ambition != ""
	_dream_bar.visible = ambition != ""
	if ambition != "":
		_dream_title.text = "%s  (%d/%d)" % [ambition, int(dreams["step"]), int(dreams["steps"])]
		_dream_title.tooltip_text = str(dreams.get("text", ""))
		var have := float(dreams["have"])
		var need := float(dreams["need"])
		_dream_step.text = "%s (%s/%s)" % [str(dreams["step_text"]), str(roundi(have)), str(roundi(need))]
		_dream_bar.max_value = maxf(1.0, need)
		_dream_bar.value = have
	elif _dream_title.visible:
		_dream_title.text = "Fulfilled: " + ", ".join(done)
		_dream_title.tooltip_text = ""
	var lines: Array[String] = []
	for wish in wishes:
		lines.append("[color=%s]%s[/color]  [color=#a89c86]%dh[/color]" % ["#e7c46a" if bool(wish["big"]) else "#d8cdb4", str(wish["text"]), int(wish["hours"])])
	_wish_text.text = "\n".join(lines) if not lines.is_empty() else "[color=#a89c86]Nothing in particular[/color]"


func _build_needs_panel() -> void:
	# The bottom panel: a picture with the plumbob, name and doings, the mood, and the needs in a grid.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_control_panel.add_child(row)
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(92, 104)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	_big_portrait = PawnPortrait.new()
	_big_portrait.scale = Vector2(2.0, 2.0)
	_big_portrait.position = Vector2(2, 20)
	picture.add_child(_big_portrait)

	var who := VBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_constant_override("separation", 1)
	who.custom_minimum_size = Vector2(230, 0)
	row.add_child(who)
	_needs_name = _make_label("", "HeaderLabel")
	_needs_name.add_theme_font_size_override("font_size", 22)
	who.add_child(_needs_name)
	_needs_age = _make_label("", "")
	_needs_age.add_theme_font_size_override("font_size", 14)
	who.add_child(_needs_age)
	_needs_traits = _make_label("", "DimLabel")
	_needs_traits.add_theme_font_size_override("font_size", 13)
	who.add_child(_needs_traits)
	_needs_activity = _make_label("", "")
	_needs_activity.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58))
	_needs_activity.add_theme_font_size_override("font_size", 14)
	_needs_activity.clip_text = true
	who.add_child(_needs_activity)
	_needs_job = _make_label("", "DimLabel")
	_needs_job.add_theme_font_size_override("font_size", 13)
	_needs_job.clip_text = true
	who.add_child(_needs_job)
	var mood_row := HBoxContainer.new()
	mood_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mood_row.add_theme_constant_override("separation", 8)
	who.add_child(mood_row)
	_mood_bar = _make_bar(100.0)
	_mood_fill = _mood_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_mood_bar.add_theme_stylebox_override("fill", _mood_fill)
	_mood_bar.custom_minimum_size = Vector2(110, 11)
	mood_row.add_child(_mood_bar)
	_mood_label = _make_label("", "DimLabel")
	mood_row.add_child(_mood_label)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	for need_id in Needs.active_ids():
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 1)
		grid.add_child(cell)
		var label := _make_label(str(DataRegistry.get_def("needs", need_id).get("name", need_id)), "")
		label.add_theme_font_size_override("font_size", 13)
		cell.add_child(label)
		var bar := _make_bar(Needs.FULL)
		var fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		bar.add_theme_stylebox_override("fill", fill)
		bar.custom_minimum_size = Vector2(72, 10)
		cell.add_child(bar)
		_need_rows[need_id] = { "bar": bar, "fill": fill }

	# The details on the left, opened with I or the Details button.
	_needs_panel = PanelContainer.new()
	_sims_panel(_needs_panel, 0.94, 12)
	_root.add_child(_needs_panel)
	_needs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needs_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	_needs_panel.offset_top = DETAILS_TOP
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_needs_panel.add_child(box)
	_section(box, "Dreams")
	_dream_title = _make_label("", "")
	_dream_title.add_theme_font_size_override("font_size", 15)
	_dream_title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58))
	_dream_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dream_title.custom_minimum_size = Vector2(214, 0)
	_dream_title.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_dream_title)
	_dream_step = _make_label("", "DimLabel")
	_dream_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dream_step.custom_minimum_size = Vector2(214, 0)
	box.add_child(_dream_step)
	_dream_bar = _make_bar(1.0)
	_dream_bar.custom_minimum_size = Vector2(214, 8)
	box.add_child(_dream_bar)
	_wish_text = _make_rich_text()
	box.add_child(_wish_text)
	_dream_done = _make_label("", "DimLabel")
	_dream_done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dream_done.custom_minimum_size = Vector2(214, 0)
	box.add_child(_dream_done)

	_section(box, "Skills")
	for i in SKILL_ROWS:
		var skill_row := HBoxContainer.new()
		skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_row.add_theme_constant_override("separation", 8)
		box.add_child(skill_row)
		var skill_name := _make_label("", "")
		skill_name.add_theme_font_size_override("font_size", 14)
		skill_name.custom_minimum_size = Vector2(118, 0)
		skill_row.add_child(skill_name)
		var skill_bar := _make_bar(1.0)
		skill_bar.custom_minimum_size = Vector2(70, 9)
		skill_row.add_child(skill_bar)
		_skill_rows.append({ "row": skill_row, "name": skill_name, "bar": skill_bar })
	_skill_note = _make_label("", "DimLabel")
	_skill_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_note.custom_minimum_size = Vector2(214, 0)
	box.add_child(_skill_note)

	_section(box, "Thoughts")
	_thoughts_text = _make_rich_text()
	box.add_child(_thoughts_text)
	_section(box, "Friends and foes")
	_relations_text = _make_rich_text()
	box.add_child(_relations_text)
	_needs_panel.visible = false


func _make_bar(maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme = UiTheme.get_theme()  # so its style can be copied before it is in the tree
	bar.min_value = 0.0
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(124, 11)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


func _make_rich_text() -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size = Vector2(200, 0)
	return text


func _build_bottom_bar() -> void:
	_bottom = HBoxContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override("separation", 12)
	_root.add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var panel := PanelContainer.new()
	_sims_panel(panel, 0.92, 8)
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_bottom.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var heading := _make_label("Your folk", "CapsLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_household_row = HBoxContainer.new()
	_household_row.add_theme_constant_override("separation", 4)
	box.add_child(_household_row)
	var left_gap := Control.new()
	left_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(left_gap)
	_control_panel = PanelContainer.new()
	_control_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sims_panel(_control_panel, 0.94, 12)
	_control_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_control_panel.visible = false
	_bottom.add_child(_control_panel)
	var right_gap := Control.new()
	right_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(right_gap)
	_bottom_right = VBoxContainer.new()
	_bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_right.size_flags_vertical = Control.SIZE_SHRINK_END
	_bottom.add_child(_bottom_right)


## The look of the game's panels in play: rounded, a cool dark blue with a pale edge, as in The Sims.
func _sims_panel(panel: Control, alpha: float = 0.95, margin: int = 12) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.15, 0.105, 0.07, alpha)
	box.border_color = Color(0.72, 0.55, 0.28)
	box.set_border_width_all(3)
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 7
	box.shadow_offset = Vector2(0, 2)
	box.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", box)


## Rounded blue buttons for the panels of the HUD; chosen ones light up.
func _sims_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(4)
		box.set_content_margin_all(4)
		box.set_border_width_all(2)
		match state:
			"normal", "focus":
				box.bg_color = Color(0.27, 0.19, 0.12)
				box.border_color = Color(0.46, 0.34, 0.19)
			"disabled":
				box.bg_color = Color(0.20, 0.15, 0.10)
				box.border_color = Color(0.33, 0.26, 0.16)
			"hover":
				box.bg_color = Color(0.37, 0.26, 0.15)
				box.border_color = Color(0.78, 0.60, 0.30)
			_:
				box.bg_color = Color(0.47, 0.15, 0.11)
				box.border_color = Color(0.86, 0.68, 0.36)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", UiTheme.INK)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.78))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.94, 0.78))
	button.add_theme_color_override("font_disabled_color", UiTheme.INK_DIM)


## Which floor is on screen, on the button that changes it.
func set_level(level: int) -> void:
	_level_button.text = "Upstairs" if level == 1 else "Ground floor"


## I: the dreams, skills, thoughts and friends of the person you are playing, down the left.
func toggle_details() -> void:
	_details_button.button_pressed = not _details_button.button_pressed


func set_details_open(on: bool) -> void:
	_details_open = on
	_details_button.set_pressed_no_signal(on)
	_needs_panel.visible = on and _control_panel.visible
	_fit_needs_panel()


## The wooden panel with less padding, for the bars that hold buttons.
func _compact_wood() -> StyleBox:
	var box := UiTheme.get_theme().get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxTexture
	box.set_content_margin_all(8)
	return box


# --- build mode -------------------------------------------------------------------

## Shows or hides the build palette, and keeps the Build button in step (no signal).
func set_build_mode(on: bool) -> void:
	_build_button.set_pressed_no_signal(on)
	_build_panel.visible = on
	_hint_label.text = BUILD_HELP if on else HINT_TEXT
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
	_build_button.custom_minimum_size = Vector2(120, 44)
	_sims_button(_build_button)
	_bottom_right.add_child(_build_button)
	_level_button = Button.new()
	_level_button.text = "Ground floor"
	_level_button.tooltip_text = "Go up or down a floor (PageUp, PageDown)"
	_level_button.focus_mode = Control.FOCUS_NONE
	_level_button.custom_minimum_size = Vector2(120, 34)
	_sims_button(_level_button)
	_level_button.pressed.connect(func() -> void: level_requested.emit(1 - Levels.view))
	_bottom_right.add_child(_level_button)
	_bottom_right.move_child(_level_button, 0)
	_bottom_right.add_theme_constant_override("separation", 6)
	_build_button.toggled.connect(func(on: bool) -> void: build_toggled.emit(on))

	_build_panel = PanelContainer.new()
	_root.add_child(_build_panel)
	_sims_panel(_build_panel, 0.96, 8)
	_build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_panel.offset_top -= 150.0   # sits above the bottom panels
	_build_panel.offset_bottom -= 150.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_build_panel.add_child(box)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 3)
	box.add_child(tab_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PALETTE_WIDTH + 12.0, 0.0)
	scroll.set("_palette_scroll", true)
	box.add_child(scroll)
	_palette_scroll = scroll
	var items_holder := VBoxContainer.new()
	scroll.add_child(items_holder)

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
	if DataRegistry.count("roofs") > 0:
		tabs["Roofs"] = []
		for roof_def in DataRegistry.get_list("roofs"):
			tabs["Roofs"].append({ "kind": "roof", "id": str(roof_def["id"]), "name": str(roof_def.get("name", roof_def["id"])), "cost": 0,
				"hint": "Click inside a closed room to roof it all: %s a tile" % Economy.stock_text(roof_def.get("materials", {})) })
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
		tab_button.custom_minimum_size = Vector2(96, 30)
		_sims_button(tab_button)
		tab_row.add_child(tab_button)
		_build_tab_buttons[tab_name] = tab_button
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
		row.visible = false
		row.custom_minimum_size = Vector2(PALETTE_WIDTH, 0)
		items_holder.add_child(row)
		_build_tabs[tab_name] = row
		for entry in tabs[tab_name]:
			var item := Button.new()
			item.toggle_mode = true
			item.button_group = group
			item.focus_mode = Control.FOCUS_NONE
			item.custom_minimum_size = Vector2(90, 84)
			_sims_button(item)
			item.clip_contents = true
			if entry.has("hint"):
				item.tooltip_text = "%s  -  %s" % [str(entry["name"]), str(entry["hint"])]
			else:
				item.tooltip_text = str(entry["name"]) + ("  -  %s" % (Economy.cost_text(str(entry["id"])) if str(entry["kind"]) == "place" else Economy.format(int(entry["cost"]))) if int(entry.get("cost", 0)) > 0 else "")
			var icon := BuildIcon.new()
			icon.kind = str(entry["kind"])
			icon.id = str(entry["id"])
			icon.position = Vector2(23, 3)
			item.add_child(icon)
			var label := Label.new()
			label.text = str(entry["name"]) + ("\n%s" % Economy.format(int(entry["cost"])) if int(entry.get("cost", 0)) > 0 else "")
			label.position = Vector2(0, 45)
			label.size = Vector2(90, 36)
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			label.add_theme_constant_override("line_spacing", -3)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.clip_text = true
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 12)
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
	# The palette is as tall as its tab needs, but never taller than a third of the screen.
	var rows := 1
	if _build_tabs.has(tab_name):
		rows = ceili(float((_build_tabs[tab_name] as Control).get_child_count()) / floorf(PALETTE_WIDTH / 94.0))
	_palette_scroll.custom_minimum_size.y = minf(float(rows) * 88.0, maxf(_root.size.y * 0.38, 170.0))
	for name in _build_tabs:
		_build_tabs[name].visible = (name == tab_name)
	for name in _build_tab_buttons:
		_build_tab_buttons[name].set_pressed_no_signal(name == tab_name)


# --- signals -------------------------------------------------------------------

func _on_speed_button_pressed(level: int) -> void:
	GameClock.set_speed(level)


func _on_speed_changed(level: int) -> void:
	# set_pressed_no_signal does not release the others in a ButtonGroup, so set every one.
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == level)
