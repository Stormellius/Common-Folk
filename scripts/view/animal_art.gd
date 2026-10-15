class_name AnimalArt
extends RefCounted
## Draws the animals with code, seen from above like the people: a body, a head at the front, legs
## that swing as it walks, and whatever marks the kind (antlers, tusks, a mane, panniers). Which kind
## has what is data ("art" in data/animals.json). Like PawnArt this is a placeholder for sprites.
##
## Everything is drawn pointing along +x and the whole picture is turned to face the way the animal
## is going. `u` scales units to pixels (48 units to a tile).

const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const HOOF := Color(0.16, 0.13, 0.11)
const BASKET := Color(0.70, 0.55, 0.30)
const SADDLE := Color(0.42, 0.26, 0.16)


static func draw(ci: CanvasItem, kind: String, coat: int, facing: Vector2i, u: float, phase: float, clock: float = 0.0, origin: Vector2 = Vector2.ZERO) -> void:
	if SpriteBank.draw_animal(ci, kind, facing, u, phase, origin):
		return
	var art: Dictionary = DataRegistry.get_def("animals", kind).get("art", {})
	var body: Array = art.get("body", [20, 10])
	var length := float(body[0])
	var width := float(body[1])
	var colors: Array = art.get("colors", ["#8a6a4a"])
	var coat_color := Color(str(colors[coat % colors.size()]))
	var belly := Color(str(art.get("belly", "#e0d0b0")))
	if belly.a < 0.5:
		belly = coat_color.lightened(0.15)
	var head_radius := float(art.get("head", 5.0))
	var angle := atan2(float(facing.y), float(facing.x))
	var swing := sin(phase)

	# The shadow is the same whichever way it faces.
	ci.draw_set_transform(origin, 0.0, Vector2.ONE)
	ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(2.0, 3.0) * u, Vector2(length * 0.62, width * 0.62) * u), Color(0, 0, 0, 0.20))

	ci.draw_set_transform(origin, angle, Vector2.ONE)
	# Legs, front pair and hind pair, swinging in step.
	for i in 4:
		var forward := 1.0 if i < 2 else -1.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var swung := swing * (1.0 if (i == 0 or i == 3) else -1.0) * length * 0.13
		var spot := Vector2(forward * length * 0.30 + swung, side * width * 0.60)
		PawnArt._ellipse_outlined(ci, spot * u, Vector2(3.0, 2.3) * u, HOOF if bool(art.get("hooves", kind in ["deer", "horse", "donkey", "ox", "boar"])) else coat_color.darkened(0.25), 0.7 * u)

	_tail(ci, art, u, length, width, coat_color, clock)

	# The body, with a lighter underside and a darker saddle of colour along the back.
	PawnArt._ellipse_outlined(ci, Vector2.ZERO, Vector2(length * 0.5, width * 0.5) * u, coat_color, 1.1 * u)
	PawnArt._ellipse(ci, Vector2(0, width * 0.18) * u, Vector2(length * 0.40, width * 0.26) * u, belly.lerp(coat_color, 0.35))
	PawnArt._ellipse(ci, Vector2(-length * 0.04, -width * 0.12) * u, Vector2(length * 0.38, width * 0.26) * u, coat_color.darkened(0.12))
	PawnArt._ellipse(ci, Vector2(-length * 0.08, -width * 0.22) * u, Vector2(length * 0.28, width * 0.12) * u, Color(1, 1, 1, 0.10))

	if bool(art.get("saddle", false)):
		var seat := PackedVector2Array([Vector2(-5, -width * 0.42), Vector2(4, -width * 0.38), Vector2(4, width * 0.38), Vector2(-5, width * 0.42)])
		ci.draw_colored_polygon(_scaled(seat, u), SADDLE)
		ci.draw_polyline(_scaled(seat + PackedVector2Array([seat[0]]), u), OUTLINE, maxf(1.0, 0.8 * u))
	if bool(art.get("panniers", false)):
		for side in [-1.0, 1.0]:
			PawnArt._ellipse_outlined(ci, Vector2(-1.0, side * width * 0.60) * u, Vector2(6.0, 3.4) * u, BASKET, 0.9 * u)
			ci.draw_line(Vector2(-5, side * width * 0.60) * u, Vector2(3, side * width * 0.60) * u, BASKET.darkened(0.25), maxf(1.0, 0.8 * u))
	if bool(art.get("mane", false)):
		PawnArt._ellipse(ci, Vector2(length * 0.36, 0) * u, Vector2(6.0, width * 0.20) * u, coat_color.darkened(0.45))

	_head(ci, art, u, length, width, head_radius, coat_color, belly, kind)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _tail(ci: CanvasItem, art: Dictionary, u: float, length: float, width: float, coat_color: Color, clock: float) -> void:
	var base := Vector2(-length * 0.5, 0)
	match str(art.get("tail", "thin")):
		"tuft":
			ci.draw_circle((base + Vector2(-1.0, 0)) * u, 2.4 * u, Color(0.95, 0.94, 0.90))
		"white":
			PawnArt._ellipse_outlined(ci, (base + Vector2(-1.5, 0)) * u, Vector2(2.8, 2.0) * u, Color(0.96, 0.95, 0.92), 0.7 * u)
		"flow":
			PawnArt._ellipse_outlined(ci, (base + Vector2(-4.5, sin(clock * 3.0) * 1.2)) * u, Vector2(6.5, 3.0) * u, coat_color.darkened(0.45), 0.8 * u)
		"curl":
			ci.draw_arc((base + Vector2(-2.0, -2.0)) * u, 3.2 * u, 0.4, 4.6, 10, coat_color.darkened(0.2), maxf(1.5, 2.0 * u))
		"long":
			var wave := sin(clock * 2.5) * 2.0
			ci.draw_polyline(PackedVector2Array([base * u, (base + Vector2(-5, wave)) * u, (base + Vector2(-10, -wave * 0.6)) * u]), coat_color.darkened(0.25), maxf(1.5, 2.2 * u))
		"bushy":
			PawnArt._ellipse_outlined(ci, (base + Vector2(-5.0, 0)) * u, Vector2(6.5, 3.4) * u, coat_color.darkened(0.15), 0.8 * u)
		_:
			ci.draw_line(base * u, (base + Vector2(-5, 0)) * u, coat_color.darkened(0.3), maxf(1.5, 1.8 * u))


static func _head(ci: CanvasItem, art: Dictionary, u: float, length: float, width: float, head_radius: float, coat_color: Color, belly: Color, kind: String) -> void:
	var neck_length := float(art.get("neck", 0.0))
	var neck := Vector2(length * 0.5 + head_radius * 0.15 + neck_length * 0.6, 0)
	if neck_length > 0.0:  # a long neck joins the head to the shoulders
		PawnArt._ellipse_outlined(ci, Vector2(length * 0.5 + neck_length * 0.2, 0) * u, Vector2(neck_length * 0.9 + 3.0, head_radius * 0.62) * u, coat_color, 0.9 * u)
	var head := neck + Vector2(head_radius * 0.55, 0)
	var ears := str(art.get("ears", "point"))
	# ears first, so the head covers their roots
	for side in [-1.0, 1.0]:
		match ears:
			"long":
				var ear := PackedVector2Array([neck + Vector2(0.5, side * head_radius * 0.5), neck + Vector2(-9.0, side * head_radius * 1.1), neck + Vector2(-8.0, side * head_radius * 0.4)])
				ci.draw_colored_polygon(_scaled(ear, u), coat_color.darkened(0.1))
				ci.draw_polyline(_scaled(ear + PackedVector2Array([ear[0]]), u), OUTLINE, maxf(1.0, 0.8 * u))
			"floppy":
				PawnArt._ellipse_outlined(ci, (neck + Vector2(-0.5, side * head_radius * 0.95)) * u, Vector2(3.4, 2.0) * u, coat_color.darkened(0.35), 0.7 * u)
			"point":
				var tip := PackedVector2Array([neck + Vector2(0.5, side * head_radius * 0.6), neck + Vector2(-2.0, side * head_radius * 1.35), neck + Vector2(-3.0, side * head_radius * 0.5)])
				ci.draw_colored_polygon(_scaled(tip, u), coat_color.darkened(0.08))
				ci.draw_polyline(_scaled(tip + PackedVector2Array([tip[0]]), u), OUTLINE, maxf(1.0, 0.8 * u))
	if bool(art.get("antlers", false)):
		for side in [-1.0, 1.0]:
			var antler := Color(0.80, 0.70, 0.52)
			var root := neck + Vector2(-1.0, side * head_radius * 0.5)
			ci.draw_polyline(_scaled(PackedVector2Array([root, root + Vector2(4, side * 5), root + Vector2(8, side * 6.5)]), u), antler, maxf(1.0, 1.4 * u))
			ci.draw_polyline(_scaled(PackedVector2Array([root + Vector2(4, side * 5), root + Vector2(6, side * 9)]), u), antler, maxf(1.0, 1.2 * u))
	if bool(art.get("horns", false)):
		for side in [-1.0, 1.0]:
			ci.draw_arc((neck + Vector2(1.5, side * head_radius * 0.95)) * u, 4.0 * u, -1.2 if side > 0.0 else 0.4, 1.0 if side < 0.0 else 2.8, 8, Color(0.92, 0.88, 0.76), maxf(1.0, 1.8 * u))
	# the head and muzzle
	PawnArt._ellipse_outlined(ci, head * u, Vector2(head_radius, head_radius * 0.86) * u, coat_color, 1.0 * u)
	var muzzle := head + Vector2(head_radius * 0.75, 0)
	PawnArt._ellipse_outlined(ci, muzzle * u, Vector2(head_radius * 0.55, head_radius * 0.5) * u, belly.lerp(coat_color, 0.3), 0.8 * u)
	ci.draw_circle((muzzle + Vector2(head_radius * 0.4, 0)) * u, maxf(1.0, 1.0 * u), Color(0.12, 0.09, 0.09))
	for side in [-1.0, 1.0]:
		ci.draw_circle((head + Vector2(head_radius * 0.25, side * head_radius * 0.42)) * u, maxf(1.0, 1.0 * u), Color(0.08, 0.06, 0.06))
	if bool(art.get("tusks", false)):
		for side in [-1.0, 1.0]:
			var tusk := PackedVector2Array([muzzle + Vector2(1.5, side * 1.6), muzzle + Vector2(4.5, side * 3.2), muzzle + Vector2(2.5, side * 1.0)])
			ci.draw_colored_polygon(_scaled(tusk, u), Color(0.96, 0.94, 0.86))


static func _scaled(points: PackedVector2Array, u: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * u)
	return result
