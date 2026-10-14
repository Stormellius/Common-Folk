class_name ObjectView
extends Node2D
## Draws one placed object. Only things that move (flames, steam) redraw every frame.
## An object with a "light" in objects.json ({ "color", "radius" in tiles, "energy" }) also
## casts a flickering glow on everything around it after dark.

const LIGHT_TEXTURE_SIZE := 256

static var _light_texture: GradientTexture2D

var placed: PlacedObject
var occupied := false:
	set(value):
		if value != occupied:
			occupied = value
			queue_redraw()


## Neighbors a wall or door joins up with; see WorldState.connection_mask.
var connections := -1:
	set(value):
		if value != connections:
			connections = value
			_update_occluders()
			queue_redraw()

var _light: PointLight2D
var _light_energy := 1.0
var _occluders: Array[LightOccluder2D] = []


func setup(new_placed: PlacedObject) -> void:
	placed = new_placed
	position = (Vector2(placed.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	_add_light()
	queue_redraw()


func _add_light() -> void:
	var spec: Variant = placed.def().get("light")
	if not spec is Dictionary:
		return
	_light = PointLight2D.new()
	_light.texture = glow_texture()
	_light.color = Color(str(spec.get("color", "#ffa24f")))
	_light.texture_scale = float(spec.get("radius", 4.0)) * MapView.TILE_SIZE / (LIGHT_TEXTURE_SIZE * 0.5)
	_light_energy = float(spec.get("energy", 1.0))
	_light.enabled = false
	_light.shadow_enabled = true  # walls stop the light, so a fire indoors does not light the street
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 1.5
	add_child(_light)


## A wall blocks light along its middle, joined to the walls next to it, so firelight lights
## the inner face of a wall and stops there. One people can walk through (a door) lets it out.
func _update_occluders() -> void:
	for occluder in _occluders:
		occluder.queue_free()
	_occluders.clear()
	if placed == null or not placed.blocks_walking() or str(placed.def().get("connects", "")) != "wall":
		return
	var half := MapView.TILE_SIZE * 0.5
	var core := MapView.TILE_SIZE * 0.08
	var bars: Array[Rect2] = []
	var mask := maxi(connections, 0)
	if mask & 10:
		bars.append(Rect2(Vector2(-half if mask & 8 else -core, -core), Vector2.ZERO).expand(Vector2(half if mask & 2 else core, core)))
	if mask & 5 or bars.is_empty():
		bars.append(Rect2(Vector2(-core, -half if mask & 1 else -core), Vector2.ZERO).expand(Vector2(core, half if mask & 4 else core)))
	for bar in bars:
		var shape := OccluderPolygon2D.new()
		shape.polygon = PackedVector2Array([bar.position, Vector2(bar.end.x, bar.position.y), bar.end, Vector2(bar.position.x, bar.end.y)])
		var occluder := LightOccluder2D.new()
		occluder.occluder = shape
		add_child(occluder)
		_occluders.append(occluder)


## A soft round falloff, shared by every light (and the ghosts' glow).
static func glow_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.85, 0.85, 0.85, 1), Color(0.3, 0.3, 0.3, 1), Color(0, 0, 0, 1)])
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(0.5, 0.0)
		_light_texture.width = LIGHT_TEXTURE_SIZE
		_light_texture.height = LIGHT_TEXTURE_SIZE
	return _light_texture


## Follows the object if it was moved.
func refresh() -> void:
	var wanted := (Vector2(placed.tile) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE
	if position != wanted:
		position = wanted


func _process(_delta: float) -> void:
	if placed == null:
		return
	if ObjectArt.is_animated(placed.def_id):
		queue_redraw()
	if _light != null:
		_light.enabled = DayNight.darkness > 0.01
		if _light.enabled:
			var t := Time.get_ticks_msec() / 1000.0 + placed.id * 1.7
			_light.energy = _light_energy * DayNight.darkness * (1.0 + 0.07 * sin(t * 7.3) + 0.05 * sin(t * 12.9))


func _draw() -> void:
	if placed != null:
		ObjectArt.draw(self, placed.def_id, MapView.TILE_SIZE / 48.0, Time.get_ticks_msec() / 1000.0, occupied, maxi(connections, 0), placed.tile)
