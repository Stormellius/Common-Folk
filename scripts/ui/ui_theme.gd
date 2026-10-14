class_name UiTheme
extends RefCounted
## The look of every menu and panel. In-game panels are dark carved wood with a gilt line, dialogs
## are parchment, buttons are beveled wood that warms to gold under the mouse and turns oxblood
## when chosen. Headings are set in IM Fell English and text in Alegreya (both under the SIL Open
## Font License; see fonts/). The textures are drawn by code here, like the rest of the art, so a
## color change below changes every menu.
##
## Type variations for labels: HeaderLabel (a gold heading), TitleLabel (the title screen),
## CapsLabel (small capitals for section names), DimLabel (quieter text), and for text on
## parchment InkLabel, InkHeader and InkDim. Panels: ParchmentPanel. Buttons: MenuItemButton (the
## flat entries of the right-click menu).

const INK := Color(0.93, 0.88, 0.77)         # light text on wood
const INK_DIM := Color(0.67, 0.61, 0.51)
const GOLD := Color(0.90, 0.73, 0.40)
const GOLD_DIM := Color(0.58, 0.45, 0.24)
const DARK_INK := Color(0.21, 0.13, 0.07)    # text on parchment
const DARK_INK_DIM := Color(0.43, 0.33, 0.22)
const WOOD := Color(0.155, 0.112, 0.078)
const GOOD := Color(0.52, 0.66, 0.34)
const LOW := Color(0.86, 0.66, 0.26)
const BAD := Color(0.76, 0.29, 0.22)

const HEADING_FONT := preload("res://fonts/IMFellEnglish-Regular.ttf")
const CAPS_FONT := preload("res://fonts/IMFellEnglishSC-Regular.ttf")
const TEXT_FONT := preload("res://fonts/Alegreya-Variable.ttf")

static var _theme: Theme
static var _bold: FontVariation


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Called once at startup: text drawn outside the menus (names over people's heads) uses the
## book face too.
static func install() -> void:
	ThemeDB.fallback_font = TEXT_FONT


## Alegreya at a heavier weight, for names and numbers that should stand out.
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = TEXT_FONT
		_bold.variation_opentype = { "wght": 700 }
	return _bold


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = TEXT_FONT
	theme.default_font_size = 15

	var wood := _texture_box(_wood_panel_image(), 9, 11, true)
	theme.set_stylebox("panel", "PanelContainer", wood)
	theme.set_stylebox("panel", "Panel", wood)
	theme.set_type_variation("ParchmentPanel", "PanelContainer")
	theme.set_stylebox("panel", "ParchmentPanel", _texture_box(_parchment_image(), 14, 26, true))

	# Buttons: beveled wood; gold under the mouse; oxblood and gold when chosen.
	var normal := _texture_box(_button_image(Color(0.25, 0.18, 0.12), Color(0.17, 0.12, 0.08), Color(0.50, 0.38, 0.21)), 5, 0, false)
	var hover := _texture_box(_button_image(Color(0.33, 0.24, 0.15), Color(0.22, 0.16, 0.10), GOLD), 5, 0, false)
	var pressed := _texture_box(_button_image(Color(0.46, 0.16, 0.12), Color(0.32, 0.10, 0.08), GOLD), 5, 0, false)
	var disabled := _texture_box(_button_image(Color(0.18, 0.16, 0.14), Color(0.13, 0.12, 0.11), Color(0.33, 0.30, 0.26)), 5, 0, false)
	for box in [normal, hover, pressed, disabled]:
		_margins(box, 12, 5)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_font("font", "Button", HEADING_FONT)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.93, 0.74))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.92, 0.70))
	theme.set_color("font_hover_pressed_color", "Button", Color(1.0, 0.95, 0.80))
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(0.48, 0.44, 0.38))

	# The flat entries of the right-click menu.
	theme.set_type_variation("MenuItemButton", "Button")
	var item := _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3)
	var item_hover := _flat(Color(0.42, 0.30, 0.15, 0.55), GOLD_DIM, 1, 3)
	for box in [item, item_hover]:
		_margins(box, 10, 4)
	theme.set_stylebox("normal", "MenuItemButton", item)
	theme.set_stylebox("hover", "MenuItemButton", item_hover)
	theme.set_stylebox("pressed", "MenuItemButton", item_hover)
	theme.set_stylebox("disabled", "MenuItemButton", item)
	theme.set_font("font", "MenuItemButton", TEXT_FONT)
	theme.set_font_size("font_size", "MenuItemButton", 15)
	theme.set_color("font_disabled_color", "MenuItemButton", INK_DIM.darkened(0.15))

	# Labels.
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	_label_variation(theme, "HeaderLabel", HEADING_FONT, 20, GOLD)
	_label_variation(theme, "TitleLabel", HEADING_FONT, 84, Color(0.96, 0.89, 0.72))
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.75))
	theme.set_constant("shadow_offset_x", "TitleLabel", 3)
	theme.set_constant("shadow_offset_y", "TitleLabel", 4)
	theme.set_constant("shadow_outline_size", "TitleLabel", 6)
	_label_variation(theme, "CapsLabel", CAPS_FONT, 14, GOLD_DIM.lightened(0.2))
	_label_variation(theme, "DimLabel", TEXT_FONT, 13, INK_DIM)
	_label_variation(theme, "InkLabel", TEXT_FONT, 16, DARK_INK)
	_label_variation(theme, "InkHeader", HEADING_FONT, 30, DARK_INK)
	_label_variation(theme, "InkDim", TEXT_FONT, 14, DARK_INK_DIM)

	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_font("normal_font", "RichTextLabel", TEXT_FONT)
	theme.set_font("bold_font", "RichTextLabel", bold_font())
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)
	theme.set_font_size("bold_font_size", "RichTextLabel", 13)

	# Text fields.
	var field := _flat(Color(0.09, 0.065, 0.045, 0.95), GOLD_DIM, 1, 3)
	_margins(field, 8, 5)
	var field_focus := _flat(Color(0.11, 0.08, 0.055, 0.95), GOLD, 1, 3)
	_margins(field_focus, 8, 5)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_DIM.darkened(0.2))
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	theme.set_font_size("font_size", "LineEdit", 16)

	# Drop-down lists and their pop-ups.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "OptionButton", theme.get_stylebox(state, "Button"))
	theme.set_font("font", "OptionButton", TEXT_FONT)
	theme.set_font_size("font_size", "OptionButton", 15)
	theme.set_color("font_color", "OptionButton", INK)
	theme.set_color("font_hover_color", "OptionButton", Color(1.0, 0.93, 0.74))
	theme.set_color("font_disabled_color", "OptionButton", Color(0.48, 0.44, 0.38))
	theme.set_stylebox("panel", "PopupMenu", wood)
	theme.set_stylebox("hover", "PopupMenu", item_hover)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.93, 0.74))
	theme.set_font("font", "PopupMenu", TEXT_FONT)
	theme.set_font_size("font_size", "PopupMenu", 15)

	# Check boxes: a dark box with a gold tick.
	theme.set_icon("unchecked", "CheckBox", ImageTexture.create_from_image(_check_image(false)))
	theme.set_icon("checked", "CheckBox", ImageTexture.create_from_image(_check_image(true)))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckBox", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("focus", "CheckBox", _focus_box())
	theme.set_color("font_color", "CheckBox", INK)

	# Bars, lines, tooltips and scroll bars.
	var trough := _flat(Color(0.06, 0.045, 0.035, 1.0), Color(0.34, 0.26, 0.15), 1, 3)
	theme.set_stylebox("background", "ProgressBar", trough)
	theme.set_stylebox("fill", "ProgressBar", _flat(GOOD, Color(0, 0, 0, 0), 0, 3))
	var line := StyleBoxLine.new()
	line.color = Color(GOLD_DIM, 0.75)
	line.thickness = 1
	line.grow_begin = -2.0
	line.grow_end = -2.0
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 9)
	theme.set_stylebox("panel", "TooltipPanel", _texture_box(_parchment_image(), 14, 8, true))
	theme.set_color("font_color", "TooltipLabel", DARK_INK)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	theme.set_stylebox("scroll", "VScrollBar", _flat(Color(0.05, 0.04, 0.03, 0.35), Color(0, 0, 0, 0), 0, 4))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(state, "VScrollBar", _flat(GOLD_DIM if state == "grabber" else GOLD, Color(0, 0, 0, 0), 0, 4))
	return theme


static func _label_variation(theme: Theme, variation: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)


static func _flat(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = radius > 0
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := _flat(Color(0, 0, 0, 0), Color(GOLD, 0.8), 1, 3)
	box.draw_center = false
	box.set_expand_margin_all(2.0)
	return box


static func _margins(box: StyleBox, horizontal: float, vertical: float) -> void:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical


## A nine-patch box from a drawn image: `edge` pixels at each side are the frame, the middle is
## tiled (panels) or stretched (buttons).
static func _texture_box(image: Image, edge: int, content: int, tile: bool) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	box.texture_margin_left = edge
	box.texture_margin_right = edge
	box.texture_margin_top = edge
	box.texture_margin_bottom = edge
	if content > 0:
		box.set_content_margin_all(content)
	if tile:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box


# --- drawn textures ------------------------------------------------------------------

## Repeats every 32 pixels, so the tiled middle of a panel shows no seams.
static func _grain(x: int, y: int) -> float:
	var fx := float(posmod(x, 32))
	var fy := float(posmod(y, 32))
	var wave := sin(TAU * (fy * 3.0 / 32.0 + 0.6 * sin(TAU * fx / 32.0) / TAU))
	var fine := sin(TAU * (fy * 9.0 + fx * 1.0) / 32.0)
	var speck := ObjectArt.hash01(posmod(x, 32), posmod(y, 32), 7) - 0.5
	return 1.0 + 0.055 * wave + 0.025 * fine + 0.05 * speck


## Dark walnut with a black edge, a lit bevel, an engraved gilt line and a brass stud in each corner.
static func _wood_panel_image() -> Image:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var g := _grain(x, y)
			image.set_pixel(x, y, Color(WOOD.r * g, WOOD.g * g, WOOD.b * g, 0.95))
	for i in size:
		for edge in [[i, 0], [i, size - 1], [0, i], [size - 1, i]]:
			image.set_pixel(edge[0], edge[1], Color(0.04, 0.028, 0.02, 1.0))
		if i > 0 and i < size - 1:
			image.set_pixel(i, 1, Color(0.30, 0.22, 0.15, 1.0))       # the lit top bevel
			image.set_pixel(1, i, Color(0.26, 0.19, 0.13, 1.0))
			image.set_pixel(i, size - 2, Color(0.07, 0.05, 0.035, 1.0))
			image.set_pixel(size - 2, i, Color(0.07, 0.05, 0.035, 1.0))
		if i >= 4 and i <= size - 5:
			for edge in [[i, 4], [i, size - 5], [4, i], [size - 5, i]]:
				image.set_pixel(edge[0], edge[1], Color(0.62, 0.48, 0.25, 1.0))  # gilt line
			for edge in [[i, 5], [5, i]]:
				image.set_pixel(edge[0], edge[1], Color(0.08, 0.055, 0.035, 1.0))  # its engraved shadow
	for corner in [Vector2i(4, 4), Vector2i(size - 5, 4), Vector2i(4, size - 5), Vector2i(size - 5, size - 5)]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var d := Vector2(dx, dy).length()
				if d <= 2.2:
					var shade := 1.15 - 0.25 * (dx + dy + 4) / 8.0
					image.set_pixel(corner.x + dx, corner.y + dy, Color(0.80 * shade, 0.63 * shade, 0.32 * shade, 1.0))
	return image


## Old parchment: warm, blotched, darker toward a burnt edge, with a thin brown rule.
static func _parchment_image() -> Image:
	var size := 64
	var edge := 14
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base := Color(0.87, 0.80, 0.64)
	for y in size:
		for x in size:
			var fx := float(posmod(x - edge, 32))
			var fy := float(posmod(y - edge, 32))
			var blot := 0.016 * sin(TAU * (fx / 32.0 + 0.3 * sin(TAU * fy / 32.0))) + 0.012 * sin(TAU * (2.0 * fy / 32.0 + 0.2 * sin(TAU * 2.0 * fx / 32.0)))
			var speck := 0.035 * (ObjectArt.hash01(posmod(x - edge, 32), posmod(y - edge, 32), 11) - 0.5)
			var border := minf(minf(x, y), minf(size - 1 - x, size - 1 - y))
			var burn := clampf(1.0 - border / float(edge - 2), 0.0, 1.0)
			var c := base * (1.0 + blot + speck)
			c = c.lerp(Color(0.52, 0.38, 0.22), burn * burn * 0.8)
			c.a = 1.0 if border >= 1 else 0.0
			image.set_pixel(x, y, c)
	for i in range(5, size - 5):
		for e in [[i, 5], [i, size - 6], [5, i], [size - 6, i]]:
			image.set_pixel(e[0], e[1], Color(0.45, 0.31, 0.17, 1.0))
	return image


## A button: lighter at the top, darker at the bottom, with a dark edge and a colored rim.
static func _button_image(top: Color, bottom: Color, rim: Color) -> Image:
	var size := 24
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var c := top.lerp(bottom, y / float(size - 1))
		for x in size:
			image.set_pixel(x, y, c)
	for i in size:
		for e in [[i, 0], [i, size - 1], [0, i], [size - 1, i]]:
			image.set_pixel(e[0], e[1], Color(0.04, 0.03, 0.02, 1.0))
	for i in range(1, size - 1):
		for e in [[i, 1], [i, size - 2], [1, i], [size - 2, i]]:
			image.set_pixel(e[0], e[1], rim)
	for i in range(2, size - 2):
		image.set_pixel(i, 2, top.lightened(0.18))  # the lit edge of the bevel
	for corner in [Vector2i(0, 0), Vector2i(size - 1, 0), Vector2i(0, size - 1), Vector2i(size - 1, size - 1)]:
		image.set_pixel(corner.x, corner.y, Color(0, 0, 0, 0))  # rounded off
	return image


static func _check_image(checked: bool) -> Image:
	var size := 18
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var rim := x <= 1 or y <= 1 or x >= size - 2 or y >= size - 2
			image.set_pixel(x, y, GOLD_DIM if rim else Color(0.09, 0.065, 0.045, 1.0))
	if checked:
		var points := [Vector2(4, 9), Vector2(7, 12.5), Vector2(14, 4.5)]
		for t in 60:
			var f := t / 59.0
			var p: Vector2 = points[0].lerp(points[1], f * 2.0) if f < 0.5 else points[1].lerp(points[2], (f - 0.5) * 2.0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var px := Vector2i(roundi(p.x) + dx, roundi(p.y) + dy)
					if px.x > 1 and px.y > 1 and px.x < size - 2 and px.y < size - 2:
						image.set_pixelv(px, GOLD)
	return image
