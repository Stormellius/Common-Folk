class_name SkillsBoard
extends PanelContainer
## The household's skills on one sheet (the K key): a row for every skill, where each of the
## household stands in it (level, rank and how far to the next), the perks it brings, and who in
## the home town could teach it. Filled from Skills.board each time it is opened.

const NAME_WIDTH := 110.0
const PERSON_WIDTH := 118.0

var _grid: GridContainer
var _note: Label
var _scroll: ScrollContainer
var _box: VBoxContainer


func _init() -> void:
	theme_type_variation = "ParchmentPanel"
	visible = false
	_scroll = ScrollContainer.new()
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_scroll.add_child(box)
	_box = box
	var title := Label.new()
	title.text = "The household's skills"
	title.theme_type_variation = "InkHeader"
	box.add_child(title)
	_note = Label.new()
	_note.theme_type_variation = "InkDim"
	_note.add_theme_font_size_override("font_size", 13)
	_note.text = "Hover a skill for its perks. K or Esc closes."
	box.add_child(_note)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)


## Opens it filled in for `sim`, or closes it if it is open.
func toggle(sim: Simulation) -> void:
	if visible or sim == null:
		visible = false
		return
	fill(sim)
	visible = true
	_place()


func fill(sim: Simulation) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var rows := Skills.board(sim)
	var folk: Array = rows[0]["people"] if not rows.is_empty() else []
	_grid.columns = 2 + folk.size()
	_grid.add_child(_cell("Skill", "InkHeader", NAME_WIDTH))
	for person in folk:
		_grid.add_child(_cell(str(person["name"]), "InkHeader", PERSON_WIDTH))
	_grid.add_child(_cell("Could teach it", "InkHeader", 0.0))
	for row in rows:
		var name := _cell(str(row["name"]), "InkLabel", NAME_WIDTH)
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		name.tooltip_text = "%s\n%s" % [str(DataRegistry.get_def("skills", str(row["id"])).get("text", "")), Skills.perks_text(null, str(row["id"]))]
		_grid.add_child(name)
		for person in row["people"]:
			_grid.add_child(_person_cell(person))
		var teacher: Dictionary = row["teacher"]
		_grid.add_child(_cell("%s (%d)" % [str(teacher["name"]), int(teacher["level"])] if not teacher.is_empty() else "", "InkDim", 0.0))


func _person_cell(person: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PERSON_WIDTH, 0)
	box.add_theme_constant_override("separation", 0)
	var lvl := int(person["level"])
	var text := "%d %s" % [lvl, str(person["rank"])] if lvl > 0 else "-"
	box.add_child(_cell(text + (" (talent)" if bool(person["talent"]) else ""), "InkLabel" if lvl > 0 else "InkDim", PERSON_WIDTH))
	if lvl > 0:
		var bar := ProgressBar.new()
		bar.theme = UiTheme.get_theme()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = float(person["progress"])
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(PERSON_WIDTH - 10.0, 6)
		box.add_child(bar)
	return box


func _cell(text: String, variation: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0)
		label.clip_text = true
	return label


## Centred, as big as the sheet but no bigger than the screen leaves room for (it scrolls then).
func _place() -> void:
	var screen := get_viewport_rect().size
	var wanted := _box.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(minf(wanted.x + 12.0, screen.x - 80.0), minf(wanted.y + 4.0, screen.y - 180.0))
	reset_size()
	position = (screen - get_combined_minimum_size()) * 0.5
