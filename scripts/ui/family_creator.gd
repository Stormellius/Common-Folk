class_name FamilyCreator
extends VBoxContainer
## The step after choosing how to begin: draw up the family. Pick a person along the top, then change their
## name, gender, age, skin, hair and traits, with a picture that follows; add or remove people (up to five)
## or roll them all again. The result is a FamilyDesign dictionary (`design`), read when the game begins.

signal changed

const SKIN_COLORS: Array[String] = ["#f4d1bb", "#f1bd98", "#e0ac80", "#c68e63", "#9a6a46", "#6e4630", "#4b3028"]
const HAIR_COLORS: Array[String] = ["#2b2118", "#4a3220", "#7a5230", "#b8893f", "#e5bc6c", "#c9c2b4", "#8a3a22", "#b94629"]
const HAIR_STYLE_NAMES: Array[String] = ["Short", "Long", "Shaved", "Bun"]

var design: Dictionary = {}
var _selected := 0
var _rng := RandomNumberGenerator.new()
var _family_field: LineEdit
var _tabs: HBoxContainer
var _add_button: Button
var _remove_button: Button
var _portrait: PawnPortrait
var _given_field: LineEdit
var _gender_buttons: Dictionary = {}
var _age_option: OptionButton
var _skin_row: HBoxContainer
var _hair_row: HBoxContainer
var _style_row: HBoxContainer
var _orientation_option: OptionButton
var _orientation_note: Label
var _trait_row: HFlowContainer
var _note: Label
var _building := false


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_rng.randomize()
	_build()


## Starts again with a fresh, random family of three.
func reset() -> void:
	design = FamilyDesign.random_family(_rng)
	_selected = 0
	_refresh()


func problem() -> String:
	return FamilyDesign.problem(design)


func _build() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	top.add_child(_label("Family name", "InkLabel", 110))
	_family_field = LineEdit.new()
	_family_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_field.max_length = 20
	_family_field.text_changed.connect(func(text: String) -> void:
		if not _building:
			design["family"] = text
			_touched())
	top.add_child(_family_field)
	var roll := Button.new()
	roll.text = "Roll everyone"
	roll.tooltip_text = "Make a new random family"
	roll.pressed.connect(reset)
	top.add_child(roll)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	add_child(_tabs)

	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 18)
	add_child(editor)
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(150, 190)
	editor.add_child(picture)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0.47, 0.56, 0.36, 0.6)
	frame_box.border_color = Color(UiTheme.DARK_INK_DIM, 0.8)
	frame_box.set_border_width_all(2)
	frame_box.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", frame_box)
	picture.add_child(frame)
	_portrait = PawnPortrait.new()
	_portrait.scale = Vector2(3.0, 3.0)
	_portrait.position = Vector2(9, 52)
	picture.add_child(_portrait)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 6)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(fields)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	fields.add_child(name_row)
	name_row.add_child(_label("Name", "InkLabel", 80))
	_given_field = LineEdit.new()
	_given_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_given_field.max_length = 16
	_given_field.text_changed.connect(func(text: String) -> void:
		if not _building:
			_member()["given"] = text
			_touched())
	name_row.add_child(_given_field)
	var reroll := Button.new()
	reroll.text = "Surprise me"
	reroll.tooltip_text = "Roll this person's name, looks and traits again"
	reroll.pressed.connect(_reroll_member)
	name_row.add_child(reroll)

	var set_row := HBoxContainer.new()
	set_row.add_theme_constant_override("separation", 8)
	fields.add_child(set_row)
	set_row.add_child(_label("Gender", "InkLabel", 80))
	var gender_group := ButtonGroup.new()
	for entry in [["female", "Woman"], ["male", "Man"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.button_group = gender_group
		button.custom_minimum_size = Vector2(90, 0)
		var gender: String = entry[0]
		button.pressed.connect(func() -> void:
			_member()["gender"] = gender
			_touched())
		set_row.add_child(button)
		_gender_buttons[gender] = button
	set_row.add_child(_label("   Age", "InkLabel", 0))
	_age_option = OptionButton.new()
	for entry in FamilyDesign.AGES:
		_age_option.add_item("%s (%d)" % [entry[0], entry[1]])
	_age_option.item_selected.connect(func(index: int) -> void:
		_member()["age"] = int(FamilyDesign.AGES[index][1])
		_touched())
	set_row.add_child(_age_option)

	_skin_row = _swatch_row(fields, "Skin")
	_hair_row = _swatch_row(fields, "Hair")
	var style_line := HBoxContainer.new()
	style_line.add_theme_constant_override("separation", 6)
	fields.add_child(style_line)
	style_line.add_child(_label("Hair style", "InkLabel", 80))
	_style_row = style_line

	var orient_row := HBoxContainer.new()
	orient_row.add_theme_constant_override("separation", 8)
	fields.add_child(orient_row)
	orient_row.add_child(_label("Attracted to", "InkLabel", 80))
	_orientation_option = OptionButton.new()
	for def in FamilyDesign.orientations():
		_orientation_option.add_item(str(def.get("name", def["id"])))
		_orientation_option.set_item_metadata(_orientation_option.item_count - 1, str(def["id"]))
	_orientation_option.item_selected.connect(func(index: int) -> void:
		_set_orientation(str(_orientation_option.get_item_metadata(index)))
		_touched())
	orient_row.add_child(_orientation_option)
	_orientation_note = _label("", "InkDim", 0)
	orient_row.add_child(_orientation_note)

	fields.add_child(_label("Traits (choose up to %d)" % FamilyDesign.TRAIT_PICKS, "InkLabel", 0))
	_trait_row = HFlowContainer.new()
	_trait_row.add_theme_constant_override("h_separation", 6)
	_trait_row.add_theme_constant_override("v_separation", 4)
	fields.add_child(_trait_row)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	add_child(foot)
	_add_button = Button.new()
	_add_button.text = "Add a person"
	_add_button.pressed.connect(_add_member)
	foot.add_child(_add_button)
	_remove_button = Button.new()
	_remove_button.text = "Remove this person"
	_remove_button.pressed.connect(_remove_member)
	foot.add_child(_remove_button)
	_note = _label("", "InkDim", 0)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.add_theme_color_override("font_color", UiTheme.BAD)
	foot.add_child(_note)


func _label(text: String, variation: String, width: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0)
	return label


func _swatch_row(parent: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(_label(title, "InkLabel", 80))
	return row


func _member() -> Dictionary:
	return design["members"][clampi(_selected, 0, (design["members"] as Array).size() - 1)]


func _touched() -> void:
	_refresh_portrait()
	_note.text = problem()
	changed.emit()


func _add_member() -> void:
	var members: Array = design["members"]
	if members.size() >= FamilyDesign.MAX_MEMBERS:
		return
	var used: Array[String] = []
	for member: Dictionary in members:
		used.append(str(member["given"]))
	members.append(FamilyDesign.random_member(_rng, str(design["family"]), used))
	_selected = members.size() - 1
	_refresh()


func _remove_member() -> void:
	var members: Array = design["members"]
	if members.size() <= 1:
		return
	members.remove_at(_selected)
	_selected = clampi(_selected, 0, members.size() - 1)
	_refresh()


func _reroll_member() -> void:
	var used: Array[String] = []
	for index in (design["members"] as Array).size():
		if index != _selected:
			used.append(str(design["members"][index]["given"]))
	var fresh := FamilyDesign.random_member(_rng, str(design["family"]), used, int(_member()["age"]))
	design["members"][_selected] = fresh
	_refresh()


func _set_orientation(trait_id: String) -> void:
	var traits: Array = _member()["traits"]
	for def in FamilyDesign.orientations():
		traits.erase(str(def["id"]))
	traits.append(trait_id)


func _toggle_trait(trait_id: String, on: bool) -> void:
	var traits: Array = _member()["traits"]
	traits.erase(trait_id)
	if on:
		traits.append(trait_id)
	_refresh_traits()
	_touched()


func _refresh() -> void:
	_building = true
	_family_field.text = str(design["family"])
	for tab in _tabs.get_children():
		tab.queue_free()
	var group := ButtonGroup.new()
	var members: Array = design["members"]
	for index in members.size():
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.text = str(members[index]["given"]) if str(members[index]["given"]).strip_edges() != "" else "(unnamed)"
		tab.custom_minimum_size = Vector2(104, 34)
		tab.button_pressed = index == _selected
		var chosen := index
		tab.pressed.connect(func() -> void:
			_selected = chosen
			_refresh())
		_tabs.add_child(tab)
	_add_button.disabled = members.size() >= FamilyDesign.MAX_MEMBERS
	_remove_button.disabled = members.size() <= 1
	var member := _member()
	_given_field.text = str(member["given"])
	for gender in _gender_buttons:
		_gender_buttons[gender].set_pressed_no_signal(gender == str(member["gender"]))
	var age_index := 0
	for index in FamilyDesign.AGES.size():
		if int(member["age"]) >= int(FamilyDesign.AGES[index][1]):
			age_index = index
	_age_option.select(age_index)
	_fill_swatches(_skin_row, SKIN_COLORS, "skin")
	_fill_swatches(_hair_row, HAIR_COLORS, "hair")
	for child in _style_row.get_children().slice(1):
		child.queue_free()
	for index in HAIR_STYLE_NAMES.size():
		var button := Button.new()
		button.text = HAIR_STYLE_NAMES[index]
		button.toggle_mode = true
		button.set_pressed_no_signal(int(member["hair_style"]) == index)
		var style := index
		button.pressed.connect(func() -> void:
			_member()["hair_style"] = style
			_refresh())
		_style_row.add_child(button)
	_refresh_traits()
	_building = false
	_touched()


## Colour swatches for `key` of the person (their skin or hair); the nearest one to what they have is ringed.
func _fill_swatches(row: HBoxContainer, colors: Array[String], key: String) -> void:
	for child in row.get_children().slice(1):
		child.queue_free()
	var current := Color(str(_member()[key]))
	var nearest := 0
	var gap := INF
	for index in colors.size():
		var other := Color(colors[index])
		var distance := Vector3(current.r - other.r, current.g - other.g, current.b - other.b).length()
		if distance < gap:
			gap = distance
			nearest = index
	for index in colors.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(32, 32)
		swatch.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(colors[index])
			box.set_corner_radius_all(16)
			box.set_border_width_all(4 if index == nearest else 2)
			box.border_color = Color(1, 1, 1) if index == nearest else Color(0, 0, 0, 0.45)
			if state == "hover":
				box.border_color = Color(1, 0.95, 0.7)
			swatch.add_theme_stylebox_override(state, box)
		var color := colors[index]
		swatch.pressed.connect(func() -> void:
			_member()[key] = color
			_refresh())
		row.add_child(swatch)


func _refresh_traits() -> void:
	var member := _member()
	var traits: Array = member["traits"]
	var grown := int(member["age"]) >= 18
	_orientation_option.get_parent().visible = grown
	if grown:
		var current := ""
		for def in FamilyDesign.orientations():
			if str(def["id"]) in traits:
				current = str(def["id"])
		for index in _orientation_option.item_count:
			if str(_orientation_option.get_item_metadata(index)) == current:
				_orientation_option.select(index)
		if current == "":
			_orientation_option.select(0)
			_set_orientation(str(_orientation_option.get_item_metadata(0)))
		_orientation_note.text = str(DataRegistry.get_def("traits", current if current != "" else str(_orientation_option.get_item_metadata(0))).get("description", ""))
	for child in _trait_row.get_children():
		child.queue_free()
	var taken := 0
	for def in FamilyDesign.free_traits():
		if str(def["id"]) in traits:
			taken += 1
	for def in FamilyDesign.free_traits():
		var id := str(def["id"])
		var on := id in traits
		var button := Button.new()
		button.text = str(def.get("name", id))
		button.toggle_mode = true
		button.tooltip_text = str(def.get("description", ""))
		button.set_pressed_no_signal(on)
		button.disabled = not on and (taken >= FamilyDesign.TRAIT_PICKS or FamilyDesign.clashes(id, traits))
		if button.disabled and not on and taken < FamilyDesign.TRAIT_PICKS:
			button.tooltip_text += "\n(Does not go with the traits already chosen.)"
		button.custom_minimum_size = Vector2(96, 30)
		button.toggled.connect(func(pressed: bool) -> void: _toggle_trait(id, pressed))
		_trait_row.add_child(button)


func _refresh_portrait() -> void:
	var pawn := Pawn.new()
	FamilyDesign.apply(pawn, _member(), str(design["family"]))
	_portrait.look = pawn.look
	_portrait.outfit = PawnArt.outfit_for(pawn)
	_portrait.queue_redraw()
