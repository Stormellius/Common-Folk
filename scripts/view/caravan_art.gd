class_name CaravanArt
extends RefCounted
## Draws a trading caravan with code: an ox pulling a covered cart, a driver on each side of the ox,
## and any passengers sitting on top. Seen from above and turned to face the way it goes, like the
## animals. `u` scales units to pixels (48 to a tile).

const OUTLINE := Color(0.06, 0.05, 0.05, 0.85)
const CANVAS := Color(0.90, 0.86, 0.74)
const TIMBER := Color(0.42, 0.28, 0.16)


static func draw(ci: CanvasItem, facing: Vector2i, u: float, phase: float, clock: float, coat: int, driver_looks: Array, passenger_looks: Array) -> void:
	var angle := atan2(float(facing.y), float(facing.x))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_colored_polygon(PawnArt._ellipse_points(Vector2(4, 4) * u, Vector2(34, 17) * u), Color(0, 0, 0, 0.18))
	ci.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	# wheels first, the cart over them
	for x in [-18.0, -2.0]:
		for side in [-1.0, 1.0]:
			ci.draw_rect(Rect2(Vector2(x - 4.5, side * 11.0 - 1.8) * u, Vector2(9.0, 3.6) * u), OUTLINE)
			ci.draw_rect(Rect2(Vector2(x - 3.6, side * 11.0 - 1.1) * u, Vector2(7.2, 2.2) * u), Color(0.25, 0.17, 0.10))
	# the shaft to the ox
	ci.draw_line(Vector2(8, -4) * u, Vector2(24, -3) * u, TIMBER, maxf(1.5, 2.2 * u))
	ci.draw_line(Vector2(8, 4) * u, Vector2(24, 3) * u, TIMBER, maxf(1.5, 2.2 * u))
	# the cart bed and its canvas cover
	ci.draw_rect(Rect2(Vector2(-25, -11) * u, Vector2(34, 22) * u), OUTLINE)
	ci.draw_rect(Rect2(Vector2(-24, -10) * u, Vector2(32, 20) * u), TIMBER)
	PawnArt._ellipse_outlined(ci, Vector2(-9, 0) * u, Vector2(15, 9) * u, CANVAS, 1.0 * u)
	for rib in [-18.0, -12.0, -6.0, 0.0]:
		ci.draw_line(Vector2(rib, -8) * u, Vector2(rib, 8) * u, CANVAS.darkened(0.18), maxf(1.0, 0.9 * u))
	ci.draw_line(Vector2(-22, 0) * u, Vector2(3, 0) * u, CANVAS.lightened(0.2), maxf(1.0, 1.0 * u))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	AnimalArt.draw(ci, "ox", coat, facing, u * 0.95, phase, clock, Vector2(34, 0).rotated(angle) * u)
	# two drivers walk beside the ox
	for index in mini(driver_looks.size(), 2):
		var side := -1.0 if index == 0 else 1.0
		var spot := Vector2(24, side * 15.0).rotated(angle)
		_person(ci, driver_looks[index], facing, u * 0.9, phase + index * 0.6, spot * u, false)
	# passengers sit on the cover
	for index in passenger_looks.size():
		var seat := Vector2(-16.0 + index * 7.0, 0.0).rotated(angle)
		_person(ci, passenger_looks[index], facing, u * 0.7, 0.0, (seat + Vector2(0, -5)) * u, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _person(ci: CanvasItem, look: Dictionary, facing: Vector2i, u: float, phase: float, at: Vector2, sitting: bool) -> void:
	ci.draw_set_transform(at, 0.0, Vector2.ONE)
	var outfit := { "stage": "adult", "headwear": "" if sitting else "cap", "cap_color": Color("#7a4a3a"), "belt": true, "pouch": true, "beard": 0, "grey": 0.0, "apron": false, "trim": false, "bump": 0.0 }
	PawnArt.draw(ci, look, facing, u, phase if not sitting else 0.0, false, outfit, 0.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
