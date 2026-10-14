class_name DeathLayer
extends Node2D
## Death and the dead on the map, drawn over the people: Death walking up to those who are dying
## and waiting beside them, the soul he leads away, and the ghosts of the restless dead on the
## nights they walk. It only reads the simulation (see Mortality).

const FOLLOW_RATE := 6.0  # how quickly a figure glides to where the simulation says it is
const DEATH_SCALE := 1.3  # Death stands a head taller than the living
const ROBE := Color(0.07, 0.06, 0.08)
const ROBE_FOLD := Color(0.13, 0.12, 0.15)
const BONE := Color(0.86, 0.84, 0.78)
const EYES := Color(0.70, 0.88, 1.0)
const BLADE := Color(0.74, 0.76, 0.80)
const HAFT := Color(0.26, 0.18, 0.11)

var sim: Simulation

var _shown: Dictionary = {}   # dying person's id -> where their Death is drawn (pixels)
var _ghosts: Dictionary = {}  # spirit name -> GhostView


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	_shown.clear()
	for ghost in _ghosts.values():
		ghost.queue_free()
	_ghosts.clear()


func _process(delta: float) -> void:
	if sim == null:
		return
	var follow := 1.0 - exp(-FOLLOW_RATE * delta)
	var wanted := {}
	for pawn in sim.people():
		var figure := Mortality.death_figure(pawn)
		if not figure["visible"]:
			continue
		var target: Vector2 = Vector2(figure["from"]).lerp(figure["to"], figure["progress"]) * MapView.TILE_SIZE
		wanted[pawn.id] = true
		_shown[pawn.id] = _shown[pawn.id].lerp(target, follow) if _shown.has(pawn.id) else target
	for id in _shown.keys():
		if not wanted.has(id):
			_shown.erase(id)
	_update_ghosts(follow)
	queue_redraw()


func _update_ghosts(follow: float) -> void:
	var walking := {}
	var now := float(GameClock.tick)
	for spirit in Mortality.haunting(sim.world, GameClock.tick):
		var key := str(spirit["name"])
		walking[key] = true
		var target := Mortality.ghost_position(spirit, now) * MapView.TILE_SIZE
		if not _ghosts.has(key):
			var ghost := GhostView.new()
			ghost.look = spirit["look"]
			ghost.position = target
			add_child(ghost)
			_ghosts[key] = ghost
		var view: GhostView = _ghosts[key]
		view.facing = Vector2i(signi(roundi(target.x - view.position.x)), 1)
		view.position = view.position.lerp(target, follow)
	for key in _ghosts.keys():
		if not walking.has(key):
			_ghosts[key].queue_free()
			_ghosts.erase(key)


func _draw() -> void:
	if sim == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var u := MapView.TILE_SIZE / 48.0 * DEATH_SCALE
	for pawn in sim.people():
		if not _shown.has(pawn.id):
			continue
		var figure := Mortality.death_figure(pawn)
		var body := (Vector2(pawn.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
		_draw_death(_shown[pawn.id], float(figure["fade"]), t + pawn.id, body.x > _shown[pawn.id].x, u)
	for departure in sim.departures:
		var minutes := float(GameClock.tick - int(departure["tick"]))
		var p := clampf(minutes / 40.0, 0.0, 1.0)
		var tile := Vector2(departure["tile"]) + Vector2(0.5, 0.5)
		var soul := (tile + Vector2(0.0, -1.6 * p)) * MapView.TILE_SIZE
		var glow := 1.0 - p
		if glow > 0.0:
			draw_circle(soul, 10.0 * u * (0.6 + 0.4 * p), Color(EYES, 0.18 * glow))
			draw_circle(soul, 4.5 * u, Color(0.92, 0.96, 1.0, 0.75 * glow))
		var at: Variant = departure.get("death_at")
		if at is Vector2 and p < 1.0:
			var spot: Vector2 = at * MapView.TILE_SIZE + Vector2(0.0, -12.0 * p * u)
			_draw_death(spot, 1.0 - p, t, tile.x * MapView.TILE_SIZE > spot.x, u)


## A tall hooded figure in a black robe, a scythe in his bony hand and two cold lights for eyes.
## `fade` is 0 (not there) to 1; `facing_right` turns him toward the one he has come for.
func _draw_death(at: Vector2, fade: float, t: float, facing_right: bool, u: float) -> void:
	if fade <= 0.01:
		return
	var bob := sin(t * 1.4) * 1.5
	var flip := 1.0 if facing_right else -1.0
	draw_set_transform(at + Vector2(0.0, bob) * u, 0.0, Vector2(-flip * u, u))  # the blade toward them
	var a := fade
	_ellipse(Vector2(3, 15), Vector2(15, 6), Color(0, 0, 0, 0.28 * a))
	for i in 6:  # dark mist curling round the hem
		var swirl := t * 0.8 + i * 1.05
		draw_circle(Vector2(cos(swirl) * 12.0, 14.0 + sin(swirl * 1.3) * 2.0), 5.0 + 1.5 * sin(swirl * 2.0), Color(0.05, 0.04, 0.07, 0.22 * a))
	var robe := PackedVector2Array([Vector2(-6, -27), Vector2(0, -32), Vector2(6, -27), Vector2(11, -16), Vector2(13, 0), Vector2(16, 15),
		Vector2(11, 12), Vector2(7, 17), Vector2(1, 13), Vector2(-5, 17), Vector2(-10, 12), Vector2(-16, 15), Vector2(-13, 0), Vector2(-11, -16)])
	var outline := robe.duplicate()
	outline.append(robe[0])
	draw_colored_polygon(robe, Color(ROBE, a))
	draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.8 * a), 1.2)
	for fold in [[Vector2(-4, -12), Vector2(-7, 13)], [Vector2(3, -10), Vector2(5, 14)], [Vector2(0, -6), Vector2(-1, 12)]]:
		draw_line(fold[0], fold[1], Color(ROBE_FOLD, a), 1.2)
	# The scythe: a long haft held at his side, its blade curving out over the one he has come for.
	draw_line(Vector2(-12, 18), Vector2(-17, -44), Color(0.0, 0.0, 0.0, 0.8 * a), 3.6)
	draw_line(Vector2(-12, 18), Vector2(-17, -44), Color(HAFT, a), 2.4)
	var blade := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		blade.append(Vector2(-17, -44) + Vector2(-26.0 * f, -6.0 * sin(f * PI) + 12.0 * f * f))
	for i in range(8, -1, -1):
		var f := i / 8.0
		blade.append(Vector2(-17, -44) + Vector2(-26.0 * f, -6.0 * sin(f * PI) + 12.0 * f * f + 4.5 * (1.0 - f)))
	draw_colored_polygon(blade, Color(BLADE, a))
	draw_polyline(blade, Color(0.20, 0.21, 0.25, 0.9 * a), 1.2)
	draw_line(Vector2(-16, -40), Vector2(-40, -33), Color(1, 1, 1, 0.35 * a), 1.0)  # the edge catches the light
	# The hood, empty but for the eyes.
	_ellipse(Vector2(0, -22), Vector2(9.5, 10.5), Color(0.10, 0.09, 0.11, a))
	_ellipse(Vector2(0.5, -20), Vector2(5.8, 6.8), Color(0.0, 0.0, 0.01, a))
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(0.5 + side * 2.2, -21), 2.4, Color(EYES, 0.25 * a))
		draw_circle(Vector2(0.5 + side * 2.2, -21), 1.0, Color(EYES, a))
	# Bony hands on the haft.
	for hand in [Vector2(-15, -10), Vector2(-13, 4)]:
		draw_circle(hand, 2.6, Color(0.0, 0.0, 0.0, 0.8 * a))
		draw_circle(hand, 2.0, Color(BONE, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_colored_polygon(PawnArt._ellipse_points(center, radius), color)


## One ghost: the person as they were, pale and see-through, drifting a little above the ground,
## with a faint cold light about them.
class GhostView extends Node2D:
	var look: Dictionary = {}
	var facing := Vector2i(0, 1)

	func _ready() -> void:
		# Drawn as added light, so a ghost glows pale blue against the night and has no dark outline.
		modulate = Color(0.50, 0.68, 0.95, 0.9)
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow
		var light := PointLight2D.new()
		light.texture = ObjectView.glow_texture()
		light.texture_scale = 2.4 * MapView.TILE_SIZE / (ObjectView.LIGHT_TEXTURE_SIZE * 0.5)
		light.color = Color(0.55, 0.75, 1.0)
		light.energy = 0.7
		add_child(light)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		draw_set_transform(Vector2(0.0, -6.0 + sin(t * 1.7) * 2.5), 0.0, Vector2.ONE)
		PawnArt.draw(self, look, Vector2i(facing.x, 1 if facing.x == 0 else 0), MapView.TILE_SIZE / 48.0, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
