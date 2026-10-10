class_name CameraController
extends Camera2D
## Pans and zooms the map. It runs on real time, so it keeps working while the game is paused.
##
## WASD or arrow keys pan (hold Shift to go faster), the mouse wheel zooms toward the
## cursor, and dragging with the middle mouse button pans.

const PAN_SPEED := 900.0  # screen pixels per second
const FAST_MULTIPLIER := 2.5
const ZOOM_STEP := 1.15
const ZOOM_MIN := 0.25
const ZOOM_MAX := 4.0

var _world_size := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	zoom = Vector2.ONE
	position_smoothing_enabled = false


## Tells the camera how big the world is, in pixels, so it cannot wander off the map.
func set_world_size(size: Vector2) -> void:
	_world_size = size
	limit_left = 0
	limit_top = 0
	limit_right = int(size.x)
	limit_bottom = int(size.y)


## Moves the camera to a point in the world (in pixels).
func focus_on(world_point: Vector2) -> void:
	position = world_point
	_keep_on_map()


func center_on_world() -> void:
	position = _world_size / 2.0


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction != Vector2.ZERO:
		var speed := PAN_SPEED * (FAST_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		position += direction.normalized() * speed * delta / zoom.x
		_keep_on_map()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_toward_mouse(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_toward_mouse(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		_keep_on_map()


## Zooms in or out while keeping the world point under the mouse in the same place.
func _zoom_toward_mouse(factor: float) -> void:
	var viewport := get_viewport()
	var offset_from_center := viewport.get_mouse_position() - viewport.get_visible_rect().size / 2.0
	var world_point := position + offset_from_center / zoom.x
	var new_zoom := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom, new_zoom)
	position = world_point - offset_from_center / new_zoom
	_keep_on_map()


func _keep_on_map() -> void:
	if _world_size != Vector2.ZERO:
		position = position.clamp(Vector2.ZERO, _world_size)
