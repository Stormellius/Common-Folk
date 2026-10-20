class_name FamilyCreator
extends VBoxContainer
## The step after choosing how to begin: draw up the family. Pick a person along the top, then change their
## name, gender and age, and (in the sections below) their looks (skin, hair), clothes, traits and place in the family
## tree, with a picture that follows; add or remove people (up to five) or roll them all again. The result is a
## FamilyDesign dictionary (`design`), read when the game begins.

signal changed

const SKIN_COLORS: Array[String] = ["#f8dcc6", "#f4d1bb", "#f1bd98", "#e8b48a", "#e0ac80", "#d09a6c", "#c68e63", "#b07a50", "#9a6a46", "#7e5538", "#6e4630", "#4b3028"]
const HAIR_COLORS: Array[String] = ["#1a1512", "#2b2118", "#4a3220", "#6b4226", "#8a3a22", "#b94629", "#b8893f", "#d9b061", "#ecd08a", "#c9c2b4", "#ece8e0"]
const HAIR_STYLE_NAMES: Array[String] = ["Short", "Long", "Shaved", "Bun"]
const SECTIONS: Array = [["looks", "Looks"], ["clothes", "Clothes"], ["traits", "Traits"], ["family", "Family tree"]]
const SLOT_NAMES := { "top": "Top", "bottom": "Bottoms", "feet": "Shoes" }
const NEAR_SWATCH := 0.09  # how close a colour has to be to a swatch for the swatch to be ringed

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
var _age_spin: SpinBox
var _skin_row: HFlowContainer
var _hair_row: HFlowContainer
var _skin_picker: ColorPickerButton
var _hair_picker: ColorPickerButton
var _hair_line: Control
var _style_row: HBoxContainer
var _look_row: HBoxContainer
var _orientation_option: OptionButton
var _orientation_note: Label
var _trait_row: HFlowContainer
var _section := "looks"
var _editor: HBoxContainer
var _section_buttons: Dictionary = {}
var _sections: Dictionary = {}
var _outfit_option: OptionButton
var _slot_options: Dictionary = {}
var _clothes_note: Label
var _tree: FamilyTreeView
var _partner_option: OptionButton
var _married_check: CheckBox
var _parent_options: Array[OptionButton] = []
var _kin_label: Label
var _suggest_button: Button
var _clear_button: Button
var _tree_note: Label
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
	_show_section("looks")
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

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	var section_group := ButtonGroup.new()
	for entry in SECTIONS:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.button_group = section_group
		button.custom_minimum_size = Vector2(120, 32)
		var id: String = entry[0]
		button.pressed.connect(func() -> void: _show_section(id))
		bar.add_child(button)
		_section_buttons[id] = button

	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 18)
	add_child(editor)
	_editor = editor
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
	_portrait.true_height = true
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
	var age_row := HBoxContainer.new()
	age_row.add_theme_constant_override("separation", 8)
	fields.add_child(age_row)
	age_row.add_child(_label("Age", "InkLabel", 80))
	_age_option = OptionButton.new()
	for entry in FamilyDesign.AGES:
		_age_option.add_item("%s (%d)" % [entry[0], entry[1]])
	_age_option.item_selected.connect(func(index: int) -> void:
		_member()["age"] = int(FamilyDesign.AGES[index][1])
		_age_spin.set_value_no_signal(float(_member()["age"]))
		_touched())
	age_row.add_child(_age_option)
	_age_spin = SpinBox.new()
	_age_spin.min_value = FamilyDesign.MIN_AGE
	_age_spin.max_value = FamilyDesign.MAX_AGE
	_age_spin.suffix = "years"
	_age_spin.tooltip_text = "Their exact age"
	_age_spin.value_changed.connect(func(value: float) -> void:
		if _building:
			return
		_member()["age"] = int(value)
		_age_option.select(FamilyDesign.age_index(int(value)))
		_touched())
	age_row.add_child(_age_spin)

	for entry in SECTIONS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		add_child(box)
		_sections[entry[0]] = box
	_build_looks(_sections["looks"])
	_build_clothes(_sections["clothes"])
	_build_traits(_sections["traits"])
	_build_family(_sections["family"])

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
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", UiTheme.BAD)
	foot.add_child(_note)
	_show_section(_section)


func _build_looks(box: VBoxContainer) -> void:
	var skin := _swatch_row(box, "Skin", "skin")
	_skin_row = skin[0]
	_skin_picker = skin[1]
	var hair := _swatch_row(box, "Hair", "hair")
	_hair_row = hair[0]
	_hair_picker = hair[1]
	_hair_line = _hair_row.get_parent()
	_look_row = HBoxContainer.new()
	_look_row.add_theme_constant_override("separation", 6)
	box.add_child(_look_row)
	_look_row.add_child(_label("Hair style", "InkLabel", 80))
	_style_row = HBoxContainer.new()
	_style_row.add_theme_constant_override("separation", 6)
	box.add_child(_style_row)
	_style_row.add_child(_label("Hair style", "InkLabel", 80))


func _build_clothes(box: VBoxContainer) -> void:
	box.add_child(_label("Their clothes. Left alone they dress for the weather and their work; here they can be given an outfit to keep to, or pieces of their own.", "InkDim", 0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	grid.add_child(_label("Outfit", "InkLabel", 80))
	_outfit_option = OptionButton.new()
	_outfit_option.custom_minimum_size = Vector2(300, 0)
	_outfit_option.item_selected.connect(func(index: int) -> void:
		_member()["outfit"] = str(_outfit_option.get_item_metadata(index))
		_refresh.call_deferred())
	grid.add_child(_outfit_option)
	for slot in Clothing.SLOTS:
		grid.add_child(_label(SLOT_NAMES.get(slot, slot), "InkLabel", 80))
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(300, 0)
		var which: String = slot
		option.item_selected.connect(func(index: int) -> void:
			var garments: Dictionary = _member().get("garments", {})
			var chosen := str(option.get_item_metadata(index))
			if chosen == "":
				garments.erase(which)
			else:
				garments[which] = chosen
			_member()["garments"] = garments
			_refresh.call_deferred())
		grid.add_child(option)
		_slot_options[slot] = option
	_clothes_note = _label("", "InkDim", 0)
	_clothes_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_clothes_note)


func _build_traits(box: VBoxContainer) -> void:
	var orient_row := HBoxContainer.new()
	orient_row.add_theme_constant_override("separation", 8)
	box.add_child(orient_row)
	orient_row.add_child(_label("Attracted to", "InkLabel", 100))
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
	box.add_child(_label("Traits (choose up to %d)" % FamilyDesign.TRAIT_PICKS, "InkLabel", 0))
	_trait_row = HFlowContainer.new()
	_trait_row.add_theme_constant_override("h_separation", 6)
	_trait_row.add_theme_constant_override("v_separation", 4)
	box.add_child(_trait_row)


func _build_family(box: VBoxContainer) -> void:
	box.add_child(_label("Who is whose. Click a card to pick someone, then say on the right who they are together with and who their parents are.", "InkDim", 0))
	var across := HBoxContainer.new()
	across.add_theme_constant_override("separation", 14)
	box.add_child(across)
	_tree = FamilyTreeView.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tree.picked.connect(func(index: int) -> void:
		_selected = index
		_refresh.call_deferred())
	across.add_child(_tree)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size = Vector2(250, 0)
	across.add_child(side)
	side.add_child(_label("Together with", "InkLabel", 0))
	_partner_option = OptionButton.new()
	_partner_option.item_selected.connect(func(index: int) -> void:
		var married := FamilyDesign.partner_of(design, _selected) < 0 or _married_check.button_pressed  # wed, unless they say otherwise
		FamilyDesign.set_partner(design, _selected, int(_partner_option.get_item_metadata(index)), married)
		_refresh.call_deferred())
	side.add_child(_partner_option)
	_married_check = CheckBox.new()
	_married_check.text = "Married"
	_married_check.toggled.connect(func(pressed: bool) -> void:
		if _building:
			return
		var partner := FamilyDesign.partner_of(design, _selected)
		if partner >= 0:
			design["members"][_selected]["married"] = pressed
			design["members"][partner]["married"] = pressed
		_touched())
	side.add_child(_married_check)
	for slot in 2:
		side.add_child(_label("Parent" if slot == 0 else "Other parent", "InkLabel", 0))
		var option := OptionButton.new()
		var which := slot
		option.item_selected.connect(func(index: int) -> void:
			FamilyDesign.set_parent(design, _selected, which, int(option.get_item_metadata(index)))
			_refresh.call_deferred())
		side.add_child(option)
		_parent_options.append(option)
	_kin_label = _label("", "InkDim", 0)
	_kin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_kin_label)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)
	var suggest := Button.new()
	_suggest_button = suggest
	suggest.text = "Suggest a tree"
	suggest.tooltip_text = "Fit a family tree to their ages: the couple nearest in age, and the children of whoever is old enough to be their parents"
	suggest.pressed.connect(func() -> void:
		FamilyDesign.suggest_tree(design)
		_refresh.call_deferred())
	tools.add_child(suggest)
	var clear := Button.new()
	_clear_button = clear
	clear.text = "Make them unrelated"
	clear.pressed.connect(func() -> void:
		for member: Dictionary in design["members"]:
			member["parents"] = []
			member["partner"] = -1
			member["married"] = false
		_refresh.call_deferred())
	tools.add_child(clear)
	_tree_note = _label("", "InkDim", 0)
	_tree_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tree_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(_tree_note)


func _show_section(id: String) -> void:
	_section = id
	_editor.visible = id != "family"  # the tree has its own room: the people on it are named on their cards
	for key in _sections:
		(_sections[key] as Control).visible = key == id
		(_section_buttons[key] as Button).set_pressed_no_signal(key == id)
	if id == "family" and _tree != null and not design.is_empty():
		_tree.show_design(design, _selected)


func _label(text: String, variation: String, width: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0)
	return label


## A line for choosing a colour: its name, a button for any other colour (returned second) and the swatches (a flow, returned first).
func _swatch_row(parent: Control, title: String, key: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(_label(title, "InkLabel", 80))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(52, 30)
	picker.edit_alpha = false
	picker.tooltip_text = "Any other colour"
	picker.color_changed.connect(func(color: Color) -> void:
		if _building:
			return
		_member()[key] = "#" + color.to_html(false)
		_refresh.call_deferred())
	row.add_child(picker)
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 6)
	swatches.add_theme_constant_override("v_separation", 4)
	swatches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(swatches)
	return [swatches, picker]


## Picks a person without a click (for the tests).
func _select_member_for_test(index: int) -> void:
	_selected = clampi(index, 0, (design["members"] as Array).size() - 1)


func _member() -> Dictionary:
	return design["members"][clampi(_selected, 0, (design["members"] as Array).size() - 1)]


func _touched() -> void:
	_refresh_portrait()
	_note.text = problem()
	if not _building:
		_fill_relations()
	if _tree != null and _sections.get("family") != null and (_sections["family"] as Control).visible:
		_tree.show_design(design, _selected)
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
	FamilyDesign.remove_member(design, _selected)
	_selected = clampi(_selected, 0, members.size() - 1)
	_refresh()


func _reroll_member() -> void:
	var used: Array[String] = []
	for index in (design["members"] as Array).size():
		if index != _selected:
			used.append(str(design["members"][index]["given"]))
	var old := _member()
	var fresh := FamilyDesign.random_member(_rng, str(design["family"]), used, int(old["age"]))
	for key in ["parents", "partner", "married"]:  # their place in the family stays, if it still fits
		fresh[key] = old.get(key, fresh[key])
	design["members"][_selected] = fresh
	FamilyDesign.mend(design)
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
			_refresh.call_deferred())
		_tabs.add_child(tab)
	_add_button.disabled = members.size() >= FamilyDesign.MAX_MEMBERS
	_remove_button.disabled = members.size() <= 1
	var member := _member()
	_given_field.text = str(member["given"])
	for gender in _gender_buttons:
		_gender_buttons[gender].set_pressed_no_signal(gender == str(member["gender"]))
	_age_option.select(FamilyDesign.age_index(int(member["age"])))
	_age_spin.set_value_no_signal(float(member["age"]))
	_fill_swatches(_skin_row, _skin_picker, SKIN_COLORS, "skin")
	_fill_swatches(_hair_row, _hair_picker, HAIR_COLORS, "hair")
	_fill_looks()
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
			_refresh.call_deferred())
		_style_row.add_child(button)
	_fill_clothes()
	_refresh_traits()
	_building = false
	_touched()


## Colour swatches for `key` of the person (their skin or hair); the nearest one to what they have is ringed, if one is
## near. `picker` shows the colour they have, and picks any other.
func _fill_swatches(row: HFlowContainer, picker: ColorPickerButton, colors: Array[String], key: String) -> void:
	for child in row.get_children():
		child.queue_free()
	var current := Color(str(_member()[key]))
	if not picker.color.is_equal_approx(current):  # not while it is being dragged: setting it again would lose the hue
		picker.color = current
	var nearest := 0
	var gap := INF
	for index in colors.size():
		var other := Color(colors[index])
		var distance := Vector3(current.r - other.r, current.g - other.g, current.b - other.b).length()
		if distance < gap:
			gap = distance
			nearest = index
	var ringed := nearest if gap < NEAR_SWATCH else -1
	for index in colors.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(colors[index])
			box.set_corner_radius_all(15)
			box.set_border_width_all(4 if index == ringed else 2)
			box.border_color = Color(1, 1, 1) if index == ringed else Color(0, 0, 0, 0.45)
			if state == "hover":
				box.border_color = Color(1, 0.95, 0.7)
			swatch.add_theme_stylebox_override(state, box)
		var color := colors[index]
		swatch.pressed.connect(func() -> void:
			_member()[key] = color
			_refresh.call_deferred())
		row.add_child(swatch)


## The painted people are layers: the body (its skin tinted to the colour chosen above), their hair (a style and a
## colour, each chosen on its own) and the clothes. So with them the person is given a choice of hair styles (and
## "Bald"); the hair colour swatches go with it. A set with no hair of its own (old men) has none of this, and the
## drawn people (and any painted ones without hair layers) keep the older short, long, shaved and bun styles.
func _fill_looks() -> void:
	for child in _look_row.get_children().slice(1):
		child.queue_free()
	var painted := SpriteBank.people_enabled()
	var temp := Pawn.new()
	FamilyDesign.apply(temp, _member(), str(design["family"]))
	var outfit := PawnArt.outfit_for(temp)
	var entry := SpriteBank.person_set(str(outfit.get("stage", "adult")), temp.gender) if painted else {}
	var styles: Array = SpriteBank.hair_styles(str(entry.get("id", ""))) if not entry.is_empty() else []
	var layered := not styles.is_empty()
	var drawn := not painted or entry.is_empty()  # drawn by code: hair colour and one of four styles
	_look_row.visible = layered
	_hair_line.visible = layered or drawn
	_style_row.visible = drawn
	if not layered:
		return
	var current := SpriteBank.hairdo_for(styles, temp.look, temp.gender, int(outfit.get("seed", 0)))
	var choices: Array = styles.duplicate()
	choices.append({ "id": "none", "name": "Bald" })
	for style: Dictionary in choices:
		var button := Button.new()
		button.text = str(style["name"])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(86, 30)
		button.set_pressed_no_signal(str(style["id"]) == current or (current == "" and str(style["id"]) == "none"))
		var chosen := str(style["id"])
		button.pressed.connect(func() -> void:
			_member()["hairdo"] = chosen
			_refresh.call_deferred())
		_look_row.add_child(button)


## The outfit and the pieces on offer, for this person's age and sex (the painted people have only some pieces).
func _fill_clothes() -> void:
	var member := _member()
	var temp := Pawn.new()
	FamilyDesign.apply(temp, member, str(design["family"]))
	_outfit_option.clear()
	_outfit_option.add_item("Whatever suits the weather and work")
	_outfit_option.set_item_metadata(0, "")
	var picked := 0
	for outfit_id in Clothing.choices():
		_outfit_option.add_item(Clothing.name_of(outfit_id))
		_outfit_option.set_item_metadata(_outfit_option.item_count - 1, outfit_id)
		if outfit_id == temp.outfit_choice:
			picked = _outfit_option.item_count - 1
	_outfit_option.select(picked)
	for slot in Clothing.SLOTS:
		var option: OptionButton = _slot_options[slot]
		option.clear()
		option.add_item("As the outfit has it")
		option.set_item_metadata(0, "")
		var chosen := 0
		for def in Clothing.available(temp, slot):
			option.add_item(str(def.get("name", def["id"])))
			option.set_item_metadata(option.item_count - 1, str(def["id"]))
			if str(def["id"]) == str(temp.garments.get(slot, "")):
				chosen = option.item_count - 1
		option.select(chosen)
	_clothes_note.text = "" if temp.outfit_choice == "" else "%s keeps to these clothes until somebody changes them at a wardrobe." % temp.given_name()


## The partner and parent choices for the person picked, the line about their children and brothers and sisters, and
## the problem with the tree, if any. A person who cannot be chosen is greyed out, with the reason beside their name.
func _fill_relations() -> void:
	var members: Array = design.get("members", [])
	if members.is_empty() or _partner_option == null:
		return
	var me := clampi(_selected, 0, members.size() - 1)
	var mine := FamilyDesign.parents_of(design, me)
	_fill_choice(_partner_option, me, FamilyDesign.partner_of(design, me), func(other: int) -> String: return FamilyDesign.partner_blocker(design, me, other))
	_married_check.set_pressed_no_signal(FamilyDesign.is_married(design, me))
	_married_check.disabled = FamilyDesign.partner_of(design, me) < 0
	for slot in _parent_options.size():
		var has: int = mine[slot] if slot < mine.size() else -1
		var other_slot: int = mine[1 - slot] if 1 - slot < mine.size() else -1
		_fill_choice(_parent_options[slot], me, has, func(other: int) -> String:
			if other == other_slot:
				return "already a parent"
			return FamilyDesign.parent_blocker(design, other, me))
	var lines: Array[String] = []
	var children := FamilyDesign.children_of(design, me)
	if not children.is_empty():
		lines.append("Children: " + ", ".join(children.map(func(i: int) -> String: return str(members[i]["given"]))))
	var siblings := FamilyDesign.siblings_among(design, me)
	if not siblings.is_empty():
		lines.append("Brothers and sisters: " + ", ".join(siblings.map(func(i: int) -> String: return str(members[i]["given"]))))
	_kin_label.text = ". ".join(lines)
	_tree_note.text = FamilyDesign.tree_problem(design)
	_tree_note.add_theme_color_override("font_color", UiTheme.BAD)


## Fills a drop-down with Nobody and then each other member (their index as its metadata), the one in `current` chosen
## and the ones `blocker` gives a reason against greyed out.
func _fill_choice(option: OptionButton, me: int, current: int, blocker: Callable) -> void:
	option.clear()
	option.add_item("Nobody")
	option.set_item_metadata(0, -1)
	var picked := 0
	for other in (design["members"] as Array).size():
		if other == me:
			continue
		var name := str(design["members"][other]["given"]).strip_edges()
		var why: String = "" if other == current else str(blocker.call(other))
		option.add_item(name if why == "" else "%s (%s)" % [name, why])
		var item := option.item_count - 1
		option.set_item_metadata(item, other)
		option.set_item_disabled(item, why != "")
		if other == current:
			picked = item
	option.select(picked)


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
	var outfit_id := pawn.outfit_choice if pawn.outfit_choice != "" else "casual"
	_portrait.look = pawn.look
	_portrait.outfit = PawnArt.outfit_for(pawn, outfit_id, Clothing.pieces_with(outfit_id, pawn.garments))
	_portrait.queue_redraw()
