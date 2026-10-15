class_name SiteLayer
extends Node2D
## Shows what has been planned and not yet built: a see-through picture of the thing, a dashed blue
## outline, how much of its materials have arrived and how far the work has got.

const BLUEPRINT := Color(0.45, 0.70, 0.95)

var sim: Simulation
var _ghosts := SiteGhosts.new()
var _signature := -1
var _seen_view := -1


func _ready() -> void:
	y_sort_enabled = false
	_ghosts.modulate = Color(1, 1, 1, 0.55)
	add_child(_ghosts)


func bind(new_sim: Simulation) -> void:
	sim = new_sim
	_ghosts.sim = sim
	_signature = -1
	_ghosts.queue_redraw()
	queue_redraw()


func _process(_delta: float) -> void:
	if sim == null:
		return
	if _seen_view != Levels.serial:
		_seen_view = Levels.serial
		_signature = -1
	var sig := sim.world.sites.size() * 1000003
	for site in sim.world.sites:
		sig += site.id * 31 + roundi(site.progress * 40.0) * 7 + int(site.delivered.size()) * 13 + sim.world.reserved.size()
		for resource_id in site.delivered:
			sig += int(site.delivered[resource_id]) * 101
	if sig != _signature:
		_signature = sig
		_ghosts.queue_redraw()
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var size := float(MapView.TILE_SIZE)
	for site in sim.world.sites:
		if not Levels.shown(site.tile):
			continue
		var rect := Rect2(Vector2(Levels.ground(site.tile)) * size, Vector2(size, size)).grow(-3.0)
		_dashed(rect)
		var bar := Rect2(rect.position + Vector2(0, rect.size.y + 1.0), Vector2(rect.size.x, 4.0))
		draw_rect(bar, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(site.progress, 0.0, 1.0), bar.size.y)), Color(0.55, 0.85, 0.45))
		var slot := 0
		for resource_id in site.needs:  # a square for each unit of material: filled once it has arrived
			var color := Color(str(DataRegistry.get_def("resources", str(resource_id)).get("color", "#cccccc")))
			for unit in int(site.needs[resource_id]):
				var spot := rect.position + Vector2(3.0 + slot * 8.0, 3.0)
				draw_rect(Rect2(spot, Vector2(6, 6)), Color(0, 0, 0, 0.6))
				if unit < int(site.delivered.get(resource_id, 0)):
					draw_rect(Rect2(spot + Vector2(1, 1), Vector2(4, 4)), color)
				slot += 1


func _dashed(rect: Rect2) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var length := from.distance_to(to)
		var steps := int(length / 8.0)
		for step in range(0, steps, 2):
			draw_line(from.lerp(to, float(step) / steps), from.lerp(to, float(step + 1) / steps), BLUEPRINT, 2.0)


## The see-through pictures of the planned things.
class SiteGhosts extends Node2D:
	var sim: Simulation

	func _draw() -> void:
		if sim == null:
			return
		var size := float(MapView.TILE_SIZE)
		for site in sim.world.sites:
			if not Levels.shown(site.tile):
				continue
			var rect := Rect2(Vector2(Levels.ground(site.tile)) * size, Vector2(size, size))
			match site.kind:
				"floor":
					FloorArt.draw(self, site.def_id, rect, site.tile)
				"roof":
					RoofArt.draw(self, site.def_id, rect, site.tile, 0)
				_:
					draw_set_transform(rect.get_center(), 0.0, Vector2.ONE)
					var group := str(DataRegistry.get_def("objects", site.def_id).get("connects", ""))
					ObjectArt.draw(self, site.def_id, size / 48.0, 0.0, false, sim.world.connection_mask(site.tile, group) if group != "" else 0, site.tile)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
