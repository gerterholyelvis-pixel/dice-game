extends Node
## Persistent player settings (volume, fullscreen). Autoloaded as `GameSettings`.

signal changed

const DEFAULT_SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

var save_path: String = DEFAULT_SAVE_PATH

## Linear volume 0.0 .. 1.0 applied to the Master bus.
var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()
		changed.emit()

var fullscreen: bool = false:
	set(value):
		fullscreen = value
		_apply_fullscreen()
		changed.emit()


func _ready() -> void:
	load_settings()


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	return cfg.save(save_path)


func load_settings() -> Error:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(save_path)
	if err != OK:
		_apply_volume()
		return err
	master_volume = float(cfg.get_value(SECTION, "master_volume", master_volume))
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))
	return OK


func _apply_volume() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
