class_name DayNight
extends CanvasModulate
## Tints the whole map by the time of day: blue nights, orange dawn and dusk, clear days.
## The HUD sits on its own canvas layer, so it is never tinted.

## [hour, color] pairs across one day. Colors are multiplied with the scene.
const KEYFRAMES: Array = [
	[0.0, Color("#566aa6")],
	[4.5, Color("#566aa6")],
	[6.0, Color("#f0c8b4")],
	[8.0, Color("#ffffff")],
	[17.0, Color("#ffffff")],
	[19.0, Color("#ffcca4")],
	[21.0, Color("#566aa6")],
	[24.0, Color("#566aa6")],
]

var _gradient := Gradient.new()


func _ready() -> void:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for key in KEYFRAMES:
		offsets.append(float(key[0]) / 24.0)
		colors.append(key[1])
	_gradient.offsets = offsets
	_gradient.colors = colors
	GameClock.ticked.connect(func(_tick: int) -> void: _update())
	GameClock.time_set.connect(_update)
	_update()


func _update() -> void:
	color = _gradient.sample(float(GameClock.get_minute_of_day()) / GameClock.MINUTES_PER_DAY)
