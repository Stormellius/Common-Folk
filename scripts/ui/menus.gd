class_name Menus
extends CanvasLayer
## The game's menus: the title screen, starting a new game, loading and saving, settings, the
## pause menu and the end of a playthrough. Built in code like the HUD and styled by UiTheme.
## The menus only ask: main.gd listens to the signals and does the work.
##
## One screen shows at a time. Load, Save, Settings and New Game go back to wherever they were
## opened from (the title screen or the pause menu); Esc goes back too, or closes the pause menu.

signal new_game_requested(world_seed: int, start_id: String, lifespan: String)
signal load_requested(path: String)
signal save_requested(slot_name: String)
## Leave the game for the title screen.
signal title_requested
signal quit_requested
## Save Game was picked in the pause menu: main fills in a name and calls open_save.
signal save_screen_requested
## Every menu was closed: the game can carry on.
signal closed
## A newborn of your household was given a name.
signal baby_named(baby_id: int, given: String)
## The families screen was asked for (from the pause menu, or the end of a line): the game fills it in.
signal families_requested
## Take up the family on this lot, or move the household into the empty house on it.
signal play_family_requested(lot_id: String)
signal move_house_requested(lot_id: String)

const CREDIT := "Type: IM Fell English by Igino Marini and Alegreya by Huerta Tipográfica, under the SIL Open Font License"

var _root: UiRoot
var _shade: ColorRect
var _screens: Dictionary = {}  # screen name -> Control
var _current := ""
var _back_to := "title"
var _confirm_back := ""
var _confirm_action := Callable()
var _confirm_text: Label
var _confirm_yes: Button
var _continue_button: Button
var _continue_note: Label
## One button per way of beginning, by start id; kept so tests can reach them.
var _start_buttons: Dictionary = {}
var _start_picked := ""
## The family drawn up on the create screen, read by main.gd when the game begins.
var family_design: Dictionary = {}
var _creator: FamilyCreator
var _create_begin: Button
var _begin_button: Button
var _seed_field: LineEdit
var _lifespan_option: OptionButton
var _lifespan_note: Label
var _load_list: VBoxContainer
var _load_error: Label
var _save_list: VBoxContainer
var _save_error: Label
var _save_field: LineEdit
var _save_button: Button
var _save_overwrite := false
var _game_over_text: Label
var _pause_note: Label
var _display_option: OptionButton
var _size_option: OptionButton
var _scale_option: OptionButton
var _volume_sliders: Dictionary = {}  # setting name -> HSlider
var _art_box: CheckBox
var _people_box: CheckBox
var _vsync_box: CheckBox
var _autosave_box: CheckBox
var _name_intro: Label
var _name_field: LineEdit
var _name_button: Button
var _name_portrait: PawnPortrait
var _name_baby := 0
var _name_gender := ""
var _name_used: Array[String] = []
var _family_list: VBoxContainer
var _family_note: Label


func _ready() -> void:
	layer = 20  # over the HUD
	_root = UiRoot.new()
	add_child(_root)
	_shade = ColorRect.new()
	_shade.color = Color(0.03, 0.02, 0.015, 0.6)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP  # the game behind a dialog cannot be clicked
	_root.add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screens["title"] = _build_title()
	_screens["pause"] = _build_pause()
	_screens["new"] = _build_new_game()
	_screens["create"] = _build_create()
	_screens["load"] = _build_load()
	_screens["save"] = _build_save()
	_screens["settings"] = _build_settings()
	_screens["confirm"] = _build_confirm()
	_screens["game_over"] = _build_game_over()
	_screens["name"] = _build_naming()
	_screens["families"] = _build_families()
	_show("")


func is_open() -> bool:
	return _current != ""


## Which screen is showing ("" for none).
func current() -> String:
	return _current


## The title screen. `continue_text` describes the newest save ("" if there is none).
func show_title(continue_text: String) -> void:
	_back_to = "title"
	_continue_button.disabled = continue_text == ""
	_continue_note.text = continue_text
	_continue_note.visible = continue_text != ""
	_show("title")


## The pause menu, with a line about where the game stands.
func show_pause(note: String) -> void:
	_back_to = "pause"
	_pause_note.text = note
	_show("pause")


## The end of a playthrough: what happened, and where to go from here.
func show_game_over(text: String) -> void:
	_back_to = "game_over"
	_game_over_text.text = text
	_show("game_over")


## Straight to the new game screen (N in the game, or New Game on the title screen).
func open_new_game() -> void:
	if _current == "":
		_back_to = "pause"
	_start_picked = ""
	for id in _start_buttons:
		_start_buttons[id].set_pressed_no_signal(false)
	var starts: Array = DataRegistry.get_list("starts")
	if not starts.is_empty():
		_pick_start(str(starts[0]["id"]))
	_seed_field.text = ""
	_pick_lifespan("normal")
	_show("new")


## The family screen, straight from the new game screen (for a screenshot or test).
func open_create() -> void:
	_begin_button.pressed.emit()


## The save screen; `default_name` fills the name field.
func open_save(default_name: String) -> void:
	if _current == "":
		_back_to = "pause"
	_save_field.text = default_name
	_save_error.visible = false
	_save_overwrite = false
	_save_button.text = "Save"
	_refresh_save_list()
	_show("save")


func open_load() -> void:
	if _current == "":
		_back_to = "pause"
	_refresh_load_list()
	_show("load")


## A save could not be loaded: say why on the load screen.
func show_load_error(text: String) -> void:
	_refresh_load_list()
	_load_error.text = "Could not load that save: %s." % text
	_load_error.visible = true
	_show("load")


## The game could not be saved: say why on the save screen.
func show_save_error(text: String) -> void:
	_save_error.text = text
	_save_error.visible = true


## Asks what to call a newborn: `intro` says who it is, `suggestion` fills the box, and Another
## picks a different name for a `gender` baby that nobody in `used` already has.
func open_naming(baby: Pawn, intro: String, suggestion: String, used: Array[String]) -> void:
	_name_baby = baby.id
	_name_gender = baby.gender
	_name_used = used
	_name_intro.text = intro
	_name_field.text = suggestion
	_name_button.text = "Name Her" if baby.gender == "female" else "Name Him"
	_name_portrait.look = baby.look
	_name_portrait.outfit = PawnArt.outfit_for(baby)
	_name_portrait.queue_redraw()
	_show("name")
	_name_field.grab_focus()
	_name_field.select_all()


## Another name for the baby being named: one from the names list that nobody in the family has
## and that is not the one in the box now.
func _another_name() -> void:
	var names: Array = DataRegistry.get_def("names", "given_%s" % _name_gender).get("list", [])
	var choices: Array[String] = []
	for given in names:
		if not str(given) in _name_used and str(given) != _name_field.text.strip_edges():
			choices.append(str(given))
	if not choices.is_empty():
		_name_field.text = choices[randi() % choices.size()]


func _on_name_chosen() -> void:
	var given := _name_field.text.strip_edges()
	if given == "":
		_another_name()
		given = _name_field.text.strip_edges()
	close()
	baby_named.emit(_name_baby, given)


func open_settings() -> void:
	if _current == "":
		_back_to = "pause"
	_refresh_settings()
	_show("settings")


func close() -> void:
	_show("")
	closed.emit()


func _show(screen: String) -> void:
	for name in _screens:
		_screens[name].visible = name == screen
	_shade.visible = screen != "" and screen != "title"
	_current = screen
	if screen == "" and get_viewport() != null:
		get_viewport().gui_release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _current == "" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()  # nothing reaches the game while a menu is open
	if event.keycode != KEY_ESCAPE:
		return
	match _current:
		"pause":
			close()
		"name":
			_on_name_chosen()  # Esc keeps the name in the box
		"create":
			_show("new")
		"confirm":
			_show(_confirm_back)
		"title", "game_over":
			pass
		_:
			_show(_back_to)


# --- screens ---------------------------------------------------------------------

func _build_title() -> Control:
	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_STOP  # the town behind is only to look at
	_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := TextureRect.new()  # darkens the left side so the words stand out
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.8])
	gradient.colors = PackedColorArray([Color(0.03, 0.02, 0.015, 0.9), Color(0.03, 0.02, 0.015, 0.65), Color(0.03, 0.02, 0.015, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 8
	fade.texture = texture
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	screen.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 90)
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.text = "Common Folk"
	column.add_child(title)
	var tagline := Label.new()
	tagline.theme_type_variation = "HeaderLabel"
	tagline.text = "A life among the folk of a medieval town"
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	column.add_child(gap)
	_continue_button = _title_button(column, "Continue", func() -> void: load_requested.emit(SaveSlots.newest()))
	_continue_note = Label.new()
	_continue_note.theme_type_variation = "DimLabel"
	column.add_child(_continue_note)
	_title_button(column, "New Game", open_new_game_from_title)
	_title_button(column, "Load Game", func() -> void:
		_refresh_load_list()
		_show("load"))
	_title_button(column, "Settings", func() -> void:
		_refresh_settings()
		_show("settings"))
	_title_button(column, "Quit", func() -> void: quit_requested.emit())

	var credit := Label.new()
	credit.theme_type_variation = "DimLabel"
	credit.add_theme_font_size_override("font_size", 11)
	credit.text = CREDIT
	screen.add_child(credit)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return screen


func open_new_game_from_title() -> void:
	_back_to = "title"
	open_new_game()


func _title_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 46)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _build_pause() -> Control:
	var parts := _card("Paused", 380.0)
	var box: VBoxContainer = parts[1]
	_pause_note = _ink_label("", "InkDim")
	_pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_pause_note)
	for entry in [
		["Resume", close],
		["Save Game", func() -> void: save_screen_requested.emit()],
		["Load Game", func() -> void:
			_refresh_load_list()
			_show("load")],
		["Town Families", func() -> void: families_requested.emit()],
		["Settings", func() -> void:
			_refresh_settings()
			_show("settings")],
		["Main Menu", func() -> void: _confirm("Leave this game for the title screen? Anything since your last save will be lost.", "Leave", func() -> void: title_requested.emit())],
		["Quit to Desktop", func() -> void: _confirm("Quit the game? Anything since your last save will be lost.", "Quit", func() -> void: quit_requested.emit())],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(entry[1])
		box.add_child(button)
	return parts[0]



func _build_new_game() -> Control:
	var parts := _card("A New Life", 600.0)
	var box: VBoxContainer = parts[1]
	box.add_child(_ink_label("How do you begin?", "InkLabel"))
	var group := ButtonGroup.new()
	for def in DataRegistry.get_list("starts"):
		var id := str(def["id"])
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(540, 90)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 14)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 7)
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_theme_constant_override("separation", 0)
		margin.add_child(lines)
		var name := Label.new()
		name.theme_type_variation = "HeaderLabel"
		name.text = str(def.get("name", id))
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(name)
		var text := Label.new()
		text.text = str(def.get("text", ""))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 14)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(text)
		button.pressed.connect(func() -> void: _pick_start(id))
		box.add_child(button)
		_start_buttons[id] = button
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	box.add_child(seed_row)
	var seed_label := _ink_label("World seed", "InkLabel")
	seed_label.custom_minimum_size = Vector2(110, 0)
	seed_row.add_child(seed_label)
	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "Leave empty for a new world"
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_field)
	var roll := Button.new()
	roll.text = "Roll"
	roll.pressed.connect(func() -> void: _seed_field.text = str(randi() % 1000000))
	seed_row.add_child(roll)
	var life_row := HBoxContainer.new()
	life_row.add_theme_constant_override("separation", 8)
	box.add_child(life_row)
	var life_label := _ink_label("Lifespan", "InkLabel")
	life_label.custom_minimum_size = Vector2(110, 0)
	life_row.add_child(life_label)
	_lifespan_option = OptionButton.new()
	_lifespan_option.custom_minimum_size = Vector2(200, 0)
	for def in DataRegistry.get_list("lifespans"):
		_lifespan_option.add_item(str(def.get("name", def["id"])))
		_lifespan_option.set_item_metadata(_lifespan_option.item_count - 1, str(def["id"]))
	_lifespan_option.item_selected.connect(func(index: int) -> void: _pick_lifespan(str(_lifespan_option.get_item_metadata(index))))
	life_row.add_child(_lifespan_option)
	_lifespan_note = _ink_label("", "InkDim")
	_lifespan_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lifespan_note.custom_minimum_size = Vector2(540, 0)
	box.add_child(_lifespan_note)
	_begin_button = Button.new()
	_begin_button.text = "Next: Your Family"
	_begin_button.custom_minimum_size = Vector2(190, 0)
	_begin_button.pressed.connect(func() -> void:
		if _start_picked != "":
			_creator.reset()
			_create_begin.disabled = _creator.problem() != ""
			_show("create"))
	box.add_child(_button_row([_back_button(), _begin_button]))
	return parts[0]


func _build_create() -> Control:
	var parts := _card("Your Family", 820.0)
	var box: VBoxContainer = parts[1]
	_creator = FamilyCreator.new()
	box.add_child(_creator)
	_create_begin = Button.new()
	_create_begin.text = "Begin"
	_creator.changed.connect(func() -> void: _create_begin.disabled = _creator.problem() != "")
	_create_begin.pressed.connect(func() -> void:
		if _start_picked != "" and _creator.problem() == "":
			family_design = _creator.design.duplicate(true)
			new_game_requested.emit(seed_from_text(_seed_field.text), _start_picked, chosen_lifespan()))
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: _show("new"))
	box.add_child(_button_row([back, _create_begin]))
	return parts[0]


## A seed typed by the player: a number is used as it is, any other text is turned into one (so
## "Thornbury" always makes the same town), and nothing at all rolls a new one.
static func seed_from_text(text: String) -> int:
	var clean := text.strip_edges()
	if clean == "":
		return randi()
	if clean.is_valid_int():
		return int(clean)
	return absi(hash(clean))


## The lifespan picked on the new game screen (an id from data/lifespans.json).
func chosen_lifespan() -> String:
	var index := _lifespan_option.selected
	return str(_lifespan_option.get_item_metadata(index)) if index >= 0 else "normal"


func _pick_lifespan(id: String) -> void:
	for i in _lifespan_option.item_count:
		if str(_lifespan_option.get_item_metadata(i)) == id:
			_lifespan_option.select(i)
	_lifespan_note.text = str(DataRegistry.get_def("lifespans", id).get("text", ""))


func _pick_start(id: String) -> void:
	_start_picked = id
	for start_id in _start_buttons:
		_start_buttons[start_id].set_pressed_no_signal(start_id == id)
	if _begin_button != null:
		_begin_button.disabled = false


func _build_load() -> Control:
	var parts := _card("Load a Game", 640.0)
	var box: VBoxContainer = parts[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_load_error = _ink_label("", "InkLabel")
	_load_error.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08))
	_load_error.visible = false
	box.add_child(_load_error)
	_load_list = VBoxContainer.new()
	_load_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_load_list)
	box.add_child(_button_row([_back_button()]))
	return parts[0]


func _refresh_load_list() -> void:
	_clear(_load_list)
	_load_error.visible = false
	var saves := SaveSlots.all()
	if saves.is_empty():
		_load_list.add_child(_ink_label("No saved games yet.", "InkDim"))
	for entry in saves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_load_list.add_child(row)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		var title := _ink_label(str(entry["title"]), "InkLabel")
		title.add_theme_font_override("font", UiTheme.bold_font())
		words.add_child(title)
		words.add_child(_ink_label(describe_save(entry), "InkDim"))
		var path := str(entry["path"])
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(func() -> void: load_requested.emit(path))
		row.add_child(load_button)
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(func() -> void:
			if delete_button.text != "Sure?":
				delete_button.text = "Sure?"
				return
			SaveSlots.remove(path)
			_refresh_load_list())
		row.add_child(delete_button)
		_load_list.add_child(_ink_rule())


## "The Brook family, 3 folk  ·  Spring 3, Y1, 12:00  ·  saved 14 Oct 2026, 05:43"
static func describe_save(entry: Dictionary) -> String:
	var meta: Dictionary = entry.get("meta", {})
	var parts: Array[String] = []
	if meta.has("family"):
		var folk := int(meta.get("folk", 0))
		parts.append("The %s family, %d folk" % [str(meta["family"]), folk] if folk > 0 else "The %s family" % str(meta["family"]))
	if meta.has("date"):
		parts.append("%s, %s" % [str(meta["date"]), str(meta.get("time", ""))])
	if parts.is_empty():
		parts.append("An older save")
	parts.append("saved %s" % _when(int(entry.get("modified", 0))))
	return "  ·  ".join(parts)


static func _when(unix_time: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(unix_time + bias)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [date["day"], months[clampi(int(date["month"]) - 1, 0, 11)], date["year"], date["hour"], date["minute"]]


func _build_save() -> Control:
	var parts := _card("Save the Game", 600.0)
	var box: VBoxContainer = parts[1]
	box.add_child(_ink_label("Name this save", "InkLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_save_field = LineEdit.new()
	_save_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_field.max_length = 60
	_save_field.text_changed.connect(func(_text: String) -> void:
		_save_overwrite = false
		_save_button.text = "Save")
	_save_field.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	row.add_child(_save_field)
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(140, 0)
	_save_button.pressed.connect(_on_save_pressed)
	row.add_child(_save_button)
	_save_error = _ink_label("", "InkLabel")
	_save_error.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08))
	_save_error.visible = false
	box.add_child(_save_error)
	box.add_child(_ink_label("Or pick one of your saves to write over it:", "InkDim"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_save_list = VBoxContainer.new()
	_save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_save_list)
	box.add_child(_button_row([_back_button()]))
	return parts[0]


func _on_save_pressed() -> void:
	var slot_name := _save_field.text.strip_edges()
	if slot_name == "":
		return
	if FileAccess.file_exists(SaveSlots.slot_path(slot_name)) and not _save_overwrite:
		_save_overwrite = true
		_save_button.text = "Write over it?"
		return
	save_requested.emit(slot_name)


func _refresh_save_list() -> void:
	_clear(_save_list)
	var any := false
	for entry in SaveSlots.all():
		if entry["kind"] != "slot":
			continue
		any = true
		var button := Button.new()
		button.text = "%s   —   %s" % [str(entry["title"]), describe_save(entry)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = "MenuItemButton"
		button.add_theme_color_override("font_color", UiTheme.DARK_INK)
		button.add_theme_color_override("font_hover_color", UiTheme.DARK_INK)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var title := str(entry["title"])
		button.pressed.connect(func() -> void:
			_save_field.text = title
			_save_overwrite = false
			_on_save_pressed())
		_save_list.add_child(button)
	if not any:
		_save_list.add_child(_ink_label("None yet.", "InkDim"))


func _build_settings() -> Control:
	var parts := _card("Settings", 560.0)
	var box: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	_display_option = OptionButton.new()
	for key in Settings.DISPLAY_MODES:
		_display_option.add_item(Settings.DISPLAY_MODES[key])
		_display_option.set_item_metadata(_display_option.item_count - 1, key)
	_display_option.item_selected.connect(func(index: int) -> void:
		Settings.set_value("display_mode", str(_display_option.get_item_metadata(index)))
		_refresh_settings())
	_setting_row(grid, "Display", _display_option)

	_size_option = OptionButton.new()
	for window_size in Settings.WINDOW_SIZES:
		_size_option.add_item("%d × %d" % [window_size.x, window_size.y])
	_size_option.item_selected.connect(func(index: int) -> void: Settings.set_value("window_size", Settings.WINDOW_SIZES[index]))
	_setting_row(grid, "Window size", _size_option)

	_scale_option = OptionButton.new()
	for factor in Settings.UI_SCALES:
		_scale_option.add_item("%d%%" % roundi(factor * 100.0))
	_scale_option.item_selected.connect(func(index: int) -> void: Settings.set_value("ui_scale", Settings.UI_SCALES[index]))
	_setting_row(grid, "Interface size", _scale_option)

	for entry in [["master_volume", "Volume"], ["music_volume", "Music"], ["ambience_volume", "Wind, rain and town"], ["effects_volume", "Work and effects"]]:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = entry[0]
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
		_volume_sliders[key] = slider
		_setting_row(grid, entry[1], slider)

	_art_box = CheckBox.new()
	_art_box.toggled.connect(func(on: bool) -> void: Settings.set_value("illustrated_art", on))
	_setting_row(grid, "Painted art", _art_box)

	_people_box = CheckBox.new()
	_people_box.toggled.connect(func(on: bool) -> void: Settings.set_value("painted_characters", on))
	_setting_row(grid, "Painted people", _people_box)

	_vsync_box = CheckBox.new()
	_vsync_box.toggled.connect(func(on: bool) -> void: Settings.set_value("vsync", on))
	_setting_row(grid, "Vertical sync", _vsync_box)

	_autosave_box = CheckBox.new()
	_autosave_box.toggled.connect(func(on: bool) -> void: Settings.set_value("autosave", on))
	_setting_row(grid, "Autosave every morning", _autosave_box)

	box.add_child(_ink_label("F11 switches between the window and a borderless full screen.", "InkDim"))
	box.add_child(_button_row([_back_button("Done")]))
	return parts[0]


func _setting_row(grid: GridContainer, text: String, control: Control) -> void:
	var label := _ink_label(text, "InkLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	control.custom_minimum_size = Vector2(220, 0)
	grid.add_child(control)


func _refresh_settings() -> void:
	for i in _display_option.item_count:
		if str(_display_option.get_item_metadata(i)) == Settings.display_mode:
			_display_option.select(i)
	_size_option.select(maxi(0, Settings.WINDOW_SIZES.find(Settings.window_size)))
	_size_option.disabled = Settings.display_mode != "windowed"
	var nearest := 0
	for i in Settings.UI_SCALES.size():
		if absf(Settings.UI_SCALES[i] - Settings.ui_scale) < absf(Settings.UI_SCALES[nearest] - Settings.ui_scale):
			nearest = i
	_scale_option.select(nearest)
	for key in _volume_sliders:
		(_volume_sliders[key] as HSlider).set_value_no_signal(float(Settings.get(key)))
	_art_box.set_pressed_no_signal(Settings.illustrated_art)
	_people_box.set_pressed_no_signal(Settings.painted_characters)
	_vsync_box.set_pressed_no_signal(Settings.vsync)
	_autosave_box.set_pressed_no_signal(Settings.autosave)


func _build_confirm() -> Control:
	var parts := _card("Are You Sure?", 460.0)
	var box: VBoxContainer = parts[1]
	_confirm_text = _ink_label("", "InkLabel")
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(400, 0)
	box.add_child(_confirm_text)
	var stay := Button.new()
	stay.text = "Stay"
	stay.pressed.connect(func() -> void: _show(_confirm_back))
	_confirm_yes = Button.new()
	_confirm_yes.pressed.connect(func() -> void: _confirm_action.call())
	box.add_child(_button_row([stay, _confirm_yes]))
	return parts[0]


func _confirm(text: String, yes: String, action: Callable) -> void:
	_confirm_back = _current
	_confirm_text.text = text
	_confirm_yes.text = yes
	_confirm_action = action
	_show("confirm")


func _build_naming() -> Control:
	var parts := _card("A New Baby", 480.0)
	var box: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(56, 56)
	row.add_child(frame)
	_name_portrait = PawnPortrait.new()
	_name_portrait.scale_factor = 1.6
	_name_portrait.position = Vector2(6, 4)
	frame.add_child(_name_portrait)
	_name_intro = _ink_label("", "InkLabel")
	_name_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_intro.custom_minimum_size = Vector2(360, 0)
	_name_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_intro)
	box.add_child(_ink_label("What will you call the child?", "InkDim"))
	_name_field = LineEdit.new()
	_name_field.max_length = 20
	_name_field.text_submitted.connect(func(_text: String) -> void: _on_name_chosen())
	box.add_child(_name_field)
	var another := Button.new()
	another.text = "Another Name"
	another.pressed.connect(_another_name)
	_name_button = Button.new()
	_name_button.text = "Name Them"
	_name_button.pressed.connect(_on_name_chosen)
	box.add_child(_button_row([another, _name_button]))
	return parts[0]


func _build_game_over() -> Control:
	var parts := _card("The Line Has Ended", 520.0)
	var box: VBoxContainer = parts[1]
	_game_over_text = _ink_label("", "InkLabel")
	_game_over_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_text.custom_minimum_size = Vector2(460, 0)
	box.add_child(_game_over_text)
	var load_button := Button.new()
	load_button.text = "Load a Save"
	load_button.pressed.connect(func() -> void:
		_refresh_load_list()
		_show("load"))
	var new_button := Button.new()
	new_button.text = "New Game"
	new_button.pressed.connect(open_new_game)
	var title_button := Button.new()
	title_button.text = "Main Menu"
	title_button.pressed.connect(func() -> void: title_requested.emit())
	var family_button := Button.new()
	family_button.text = "Another Family"
	family_button.pressed.connect(func() -> void: families_requested.emit())
	box.add_child(_button_row([family_button, load_button, new_button, title_button]))
	return parts[0]


# --- the town's families -----------------------------------------------------------

func _build_families() -> Control:
	var parts := _card("The Town's Families", 760.0)
	var box: VBoxContainer = parts[1]
	_family_note = _ink_label("", "InkDim")
	_family_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_family_note.custom_minimum_size = Vector2(720, 0)
	box.add_child(_family_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_family_list = VBoxContainer.new()
	_family_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_family_list)
	box.add_child(_button_row([_back_button()]))
	return parts[0]


## The families screen. `families` and `empty` are the rows from Families.rows and Families.empty_rows,
## `chronicle` the lines of what has happened, and `note` says who you are now.
func open_families(families: Array[Dictionary], empty: Array[Dictionary], chronicle: Array[String], note: String) -> void:
	if _current == "":
		_back_to = "pause"
	_family_note.text = note
	_clear(_family_list)
	_family_list.add_child(_ink_label("Families of the town", "InkHeader"))
	var last_town := "~"
	for row in families:
		if str(row["town"]) != last_town:
			last_town = str(row["town"])
			var heading := _ink_label(last_town, "InkLabel")
			heading.add_theme_font_override("font", UiTheme.bold_font())
			_family_list.add_child(heading)
		_family_list.add_child(_family_row("%s  ·  %s" % [row["title"], row["class"]], str(row["who"]), "Play", str(row["blocker"]), str(row["lot"]), play_family_requested))
	if families.is_empty():
		_family_list.add_child(_ink_label("Nobody else lives in the town.", "InkDim"))
	_family_list.add_child(_ink_rule())
	_family_list.add_child(_ink_label("Empty houses", "InkHeader"))
	for row in empty:
		_family_list.add_child(_family_row("%s  ·  %s" % [row["title"], row["town"]], "%d beds" % int(row["beds"]), "Move in", str(row["blocker"]), str(row["lot"]), move_house_requested))
	if empty.is_empty():
		_family_list.add_child(_ink_label("Every house is lived in.", "InkDim"))
	_family_list.add_child(_ink_rule())
	_family_list.add_child(_ink_label("What has happened", "InkHeader"))
	for line in chronicle.slice(0, 14):
		var entry := _ink_label(line, "InkDim")
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.custom_minimum_size = Vector2(680, 0)
		_family_list.add_child(entry)
	if chronicle.is_empty():
		_family_list.add_child(_ink_label("Nothing yet.", "InkDim"))
	_show("families")


## Words on the families screen (why something could not be done).
func show_families_note(text: String) -> void:
	_family_note.text = text


func _family_row(title: String, detail: String, button_text: String, blocker: String, lot_id: String, request: Signal) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading := _ink_label(title, "InkLabel")
	heading.add_theme_font_override("font", UiTheme.bold_font())
	words.add_child(heading)
	var who := _ink_label(detail, "InkDim")
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.custom_minimum_size = Vector2(540, 0)
	words.add_child(who)
	var button := Button.new()
	button.text = button_text
	button.disabled = blocker != ""
	button.tooltip_text = blocker
	button.custom_minimum_size = Vector2(90, 0)
	button.pressed.connect(func() -> void: request.emit(lot_id))
	row.add_child(button)
	return row


# --- small parts -------------------------------------------------------------------

## A parchment dialog in the middle of the screen with a heading: [panel, the box to fill].
func _card(title: String, width: float) -> Array:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ParchmentPanel"
	panel.custom_minimum_size = Vector2(width, 0)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := _ink_label(title, "InkHeader")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	box.add_child(_ink_rule())
	return [panel, box]


func _ink_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	return label


func _ink_rule() -> HSeparator:
	var rule := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(UiTheme.DARK_INK_DIM, 0.55)
	line.thickness = 1
	rule.add_theme_stylebox_override("separator", line)
	return rule


func _back_button(text: String = "Back") -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void: _show(_back_to))
	return button


## Buttons side by side at the foot of a dialog, the last one on the right.
func _button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	for button in buttons:
		button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 130), 38)
		row.add_child(button)
	return row


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
