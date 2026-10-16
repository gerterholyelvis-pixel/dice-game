extends GutTest

const SettingsScript := preload("res://scripts/autoload/game_settings.gd")
const TEST_PATH := "user://test_game_settings.cfg"

var _settings: Node


func before_each() -> void:
	_settings = SettingsScript.new()
	_settings.save_path = TEST_PATH
	add_child_autofree(_settings)


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_default_volume() -> void:
	assert_eq(_settings.master_volume, 0.8)


func test_volume_is_clamped() -> void:
	_settings.master_volume = 3.0
	assert_eq(_settings.master_volume, 1.0)
	_settings.master_volume = -1.0
	assert_eq(_settings.master_volume, 0.0)


func test_changed_signal_emitted_on_volume_change() -> void:
	watch_signals(_settings)
	_settings.master_volume = 0.5
	assert_signal_emitted(_settings, "changed")


func test_volume_applies_to_master_bus() -> void:
	_settings.master_volume = 0.5
	var bus: int = AudioServer.get_bus_index("Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5), 0.01)


func test_zero_volume_mutes_master_bus() -> void:
	_settings.master_volume = 0.0
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	_settings.master_volume = 0.5
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))


func test_save_and_load_round_trip() -> void:
	_settings.master_volume = 0.35
	assert_eq(_settings.save_settings(), OK)
	_settings.master_volume = 0.9
	assert_eq(_settings.load_settings(), OK)
	assert_almost_eq(_settings.master_volume, 0.35, 0.001)


func test_load_missing_file_keeps_defaults() -> void:
	var err: Error = _settings.load_settings()
	assert_ne(err, OK)
	assert_eq(_settings.master_volume, 0.8)
