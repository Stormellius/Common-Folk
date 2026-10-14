extends Node
## Player settings, kept between runs in user://settings.cfg: how the window is shown, the size of
## the interface and a few game options. Changing one applies it at once and saves the file.
##
## When the game is started with the testing and screenshot options after "--" (see main.gd), or
## with no window at all (--headless), the window is left as the command line made it.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DISPLAY_MODES := { "windowed": "Windowed", "fullscreen": "Fullscreen", "borderless": "Borderless window" }
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const UI_SCALES: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5]

var display_mode := "windowed"
var window_size := Vector2i(1280, 720)
var vsync := true
var ui_scale := 1.0
## Save a copy every morning (see main.gd).
var autosave := true


func _ready() -> void:
	load_file()
	UiTheme.install()
	if may_touch_window():
		apply_display()


## Changes one setting (by its variable name), applies it and saves the file.
func set_value(key: String, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	if key in ["display_mode", "window_size", "vsync"] and may_touch_window():
		apply_display()
	save_file()
	changed.emit(key)


## F11: between the window and a borderless window over the whole screen.
func toggle_fullscreen() -> void:
	set_value("display_mode", "borderless" if display_mode == "windowed" else "windowed")


func apply_display() -> void:
	match display_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			# In Godot 4 plain "fullscreen" is a borderless window the size of the screen.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var wanted := Vector2i(mini(window_size.x, screen.size.x), mini(window_size.y, screen.size.y))
			DisplayServer.window_set_size(wanted)
			DisplayServer.window_set_position(screen.position + (screen.size - wanted) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func may_touch_window() -> bool:
	return DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().is_empty()


func load_file() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	var mode := str(config.get_value("display", "mode", display_mode))
	display_mode = mode if DISPLAY_MODES.has(mode) else "windowed"
	window_size = Vector2i(int(config.get_value("display", "width", window_size.x)), int(config.get_value("display", "height", window_size.y)))
	vsync = bool(config.get_value("display", "vsync", vsync))
	ui_scale = clampf(float(config.get_value("display", "ui_scale", ui_scale)), 0.5, 3.0)
	autosave = bool(config.get_value("game", "autosave", autosave))


func save_file() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "width", window_size.x)
	config.set_value("display", "height", window_size.y)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("game", "autosave", autosave)
	config.save(PATH)
