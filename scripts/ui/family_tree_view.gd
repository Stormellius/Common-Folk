class_name FamilyTreeView
extends Control
## The family tree of the design on the creator screen: a card for each person (their picture and their name) in a
## row for their generation, a double line between a couple and lines down from the parents to their children.
## The card of the person being edited is ringed; the others say what they are to them ("Mother", "Brother", ...).
## Clicking a card picks that person. The layout is worked out from the design alone (see `layout`), so it can be tested.

signal picked(index: int)

const CARD := Vector2(92, 108)
const GAP := Vector2(14, 28)
const PADDING := Vector2(8, 8)
const MIN_SCALE := 0.7  # a row too wide for the room shrinks its cards, down to this

var _design: Dictionary = {}
var _selected := 0
var _looks: Array[Dictionary] = []
var _outfits: Array[Dictionary] = []
var _spots: Array[Vector2] = []
var _generations: Array[int] = []
var _scale := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, CARD.y + PADDING.y * 2.0)


## Shows `design`, with the member at `selected` picked out.
func show_design(design: Dictionary, selected: int) -> void:
	_design = design
	_selected = selected
	_looks.clear()
	_outfits.clear()
	var family := str(design.get("family", ""))
	for member: Dictionary in design.get("members", []):
		var pawn := Pawn.new()
		FamilyDesign.apply(pawn, member, family)
		_looks.append(pawn.look)
		var outfit_id := pawn.outfit_choice if pawn.outfit_choice != "" else "casual"
		_outfits.append(PawnArt.outfit_for(pawn, outfit_id, Clothing.pieces_with(outfit_id, pawn.garments)))
	layout()
	queue_redraw()


## The row of each person (0 for the eldest generation, one more for their children) and where each card goes, from the
## top left of the tree. Partners stand side by side, in the row of whichever is further down the tree, and children are
## ordered under their parents.
func layout() -> void:
	var members: Array = _design.get("members", [])
	var count := members.size()
	_generations = []
	_generations.resize(count)
	_generations.fill(0)
	for _pass in count + 2:
		var changed := false
		for index in count:
			var row := _generations[index]
			for parent in FamilyDesign.parents_of(_design, index):
				row = maxi(row, _generations[parent] + 1)
			var partner := FamilyDesign.partner_of(_design, index)
			if partner >= 0:
				row = maxi(row, _generations[partner])
			if row != _generations[index]:
				_generations[index] = mini(row, count)
				changed = true
		if not changed:
			break
	var rows := 0
	for row in _generations:
		rows = maxi(rows, row + 1)
	var slots: Array[float] = []  # the place across the row of each person, in cards
	slots.resize(count)
	slots.fill(-1.0)
	var widest := 0.0
	for row in rows:
		var in_row: Array[int] = []
		for index in count:
			if _generations[index] == row:
				in_row.append(index)
		var wanted := {}  # where their parents stand: the further left they are, the further left they go
		for index in in_row:
			var mean := 0.0
			var known := 0
			for parent in FamilyDesign.parents_of(_design, index):
				if slots[parent] >= 0.0:
					mean += slots[parent]
					known += 1
			wanted[index] = mean / known if known > 0 else 999.0 + index
		in_row.sort_custom(func(a: int, b: int) -> bool: return wanted[a] < wanted[b] or (wanted[a] == wanted[b] and a < b))
		var ordered: Array[int] = []  # a couple stays together, the second after the first
		for index in in_row:
			if index in ordered:
				continue
			ordered.append(index)
			var partner := FamilyDesign.partner_of(_design, index)
			if partner >= 0 and partner in in_row and partner not in ordered:
				ordered.append(partner)
		for place in ordered.size():
			slots[ordered[place]] = float(place)
		widest = maxf(widest, float(ordered.size()))
	var room := size.x - PADDING.x * 2.0
	_scale = 1.0 if room <= 1.0 or widest <= 0.0 else clampf((room + GAP.x) / (widest * (CARD.x + GAP.x)), MIN_SCALE, 1.0)
	var card := CARD * _scale
	var gap := GAP * _scale
	_spots = []
	_spots.resize(count)
	for index in count:
		var in_row_count := 0
		for other in count:
			if _generations[other] == _generations[index]:
				in_row_count += 1
		var row_width := in_row_count * (card.x + gap.x) - gap.x
		var left := PADDING.x + maxf(0.0, (room - row_width) * 0.5)
		_spots[index] = Vector2(left + slots[index] * (card.x + gap.x), PADDING.y + _generations[index] * (card.y + gap.y))
	custom_minimum_size = Vector2(0.0, PADDING.y * 2.0 + rows * card.y + maxi(rows - 1, 0) * gap.y)


## The card of each person, as rectangles in the control (for the tests as much as for the clicks).
func card_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for spot in _spots:
		found.append(Rect2(spot, CARD * _scale))
	return found


func generation_of(index: int) -> int:
	return _generations[index] if index >= 0 and index < _generations.size() else 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _design.is_empty():
		layout()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rects := card_rects()
		for index in rects.size():
			if rects[index].has_point(event.position):
				picked.emit(index)
				accept_event()
				return


func _draw() -> void:
	var members: Array = _design.get("members", [])
	if members.is_empty() or _spots.size() != members.size():
		return
	var line := Color(UiTheme.DARK_INK_DIM, 0.9)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.47, 0.56, 0.36, 0.18)
	backing.set_corner_radius_all(10)
	draw_style_box(backing, Rect2(Vector2.ZERO, size))
	var rects := card_rects()
	# the lines first, under the cards
	var drawn_couples := {}
	for index in members.size():
		var partner := FamilyDesign.partner_of(_design, index)
		if partner > index and FamilyDesign.partner_of(_design, partner) == index and _generations[partner] == _generations[index]:
			var left := rects[index] if rects[index].position.x < rects[partner].position.x else rects[partner]
			var right := rects[partner] if left == rects[index] else rects[index]
			var y := left.position.y + 38.0 * _scale
			draw_line(Vector2(left.end.x, y - 2.0), Vector2(right.position.x, y - 2.0), line, 2.0)
			draw_line(Vector2(left.end.x, y + 2.0), Vector2(right.position.x, y + 2.0), line, 2.0)
			drawn_couples[index] = Vector2((left.end.x + right.position.x) * 0.5, y)
			drawn_couples[partner] = drawn_couples[index]
	for index in members.size():
		var parents := FamilyDesign.parents_of(_design, index)
		if parents.is_empty():
			continue
		var to := Vector2(rects[index].get_center().x, rects[index].position.y)
		var bottom := 0.0
		for parent in parents:
			bottom = maxf(bottom, rects[parent].end.y)
		var from := Vector2.ZERO
		if parents.size() == 2 and drawn_couples.has(parents[0]) and drawn_couples.get(parents[0]) == drawn_couples.get(parents[1]):
			from = drawn_couples[parents[0]]  # from the middle of the couple's line
		else:
			for parent in parents:
				from += Vector2(rects[parent].get_center().x, bottom)
			from /= parents.size()
		var bus := minf(bottom + GAP.y * _scale * 0.5, to.y - 6.0)
		draw_line(from, Vector2(from.x, bus), line, 2.0)
		draw_line(Vector2(from.x, bus), Vector2(to.x, bus), line, 2.0)
		draw_line(Vector2(to.x, bus), to, line, 2.0)
	var font := get_theme_default_font()
	for index in members.size():
		var card := rects[index]
		var on := index == _selected
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.47, 0.56, 0.36, 0.55) if not on else Color(0.62, 0.70, 0.42, 0.75)
		box.border_color = Color(1.0, 0.95, 0.7) if on else Color(UiTheme.DARK_INK_DIM, 0.8)
		box.set_border_width_all(3 if on else 2)
		box.set_corner_radius_all(10)
		draw_style_box(box, card)
		var stage := str(_outfits[index].get("stage", "adult"))
		var fit := PawnArt.stage_scale(stage)
		draw_set_transform(card.position + Vector2(card.size.x * 0.5, (52.0 + (1.0 - fit) * 12.0) * _scale), 0.0, Vector2.ONE)
		PawnArt.draw(self, _looks[index], Vector2i(0, 1), 1.55 * fit * _scale, 0.0, false, _outfits[index])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var name := str(members[index].get("given", "")).strip_edges()
		var text_size := int(15.0 * maxf(_scale, 0.85))
		draw_string(font, card.position + Vector2(0.0, 85.0 * _scale), name if name != "" else "(unnamed)", HORIZONTAL_ALIGNMENT_CENTER, card.size.x, text_size, UiTheme.DARK_INK)
		var caption := "" if on else FamilyDesign.relation(_design, index, _selected)
		draw_string(font, card.position + Vector2(0.0, 102.0 * _scale), caption if caption != "" else ("age %d" % int(members[index].get("age", 25))), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, text_size - 2, UiTheme.DARK_INK_DIM)
