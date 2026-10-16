extends GutTest

const START_SCREEN := preload("res://scenes/start_screen.tscn")
const TEST_PATH := "user://test_start_screen.cfg"

var _screen: Control
var _original_path: String
var _original_volume: float


func before_each() -> void:
	_original_path = GameSettings.save_path
	_original_volume = GameSettings.master_volume
	GameSettings.save_path = TEST_PATH
	_screen = START_SCREEN.instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(2)


func after_each() -> void:
	GameSettings.save_path = _original_path
	GameSettings.master_volume = _original_volume
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_has_start_and_settings_buttons() -> void:
	assert_eq(_screen.start_button.text, "Start")
	assert_eq(_screen.settings_button.text, "Settings")


func test_settings_panel_hidden_initially() -> void:
	assert_false(_screen.settings_panel.visible)


func test_settings_button_opens_panel_and_hides_menu() -> void:
	_screen.settings_button.pressed.emit()
	assert_true(_screen.settings_panel.visible)
	assert_false(_screen.get_node("Menu").visible)


func test_back_button_closes_panel_and_restores_menu() -> void:
	_screen.open_settings()
	_screen.back_button.pressed.emit()
	assert_false(_screen.settings_panel.visible)
	assert_true(_screen.get_node("Menu").visible)


func test_back_saves_settings() -> void:
	_screen.open_settings()
	_screen.volume_slider.value = 0.42
	_screen.close_settings()
	assert_true(FileAccess.file_exists(TEST_PATH))


func test_slider_updates_master_volume() -> void:
	_screen.open_settings()
	_screen.volume_slider.value = 0.25
	assert_almost_eq(GameSettings.master_volume, 0.25, 0.001)


func test_open_settings_syncs_slider_to_current_volume() -> void:
	GameSettings.master_volume = 0.6
	_screen.open_settings()
	assert_almost_eq(_screen.volume_slider.value, 0.6, 0.001)


func test_start_emits_signal() -> void:
	_screen.change_scene_on_start = false
	watch_signals(_screen)
	_screen.start_button.pressed.emit()
	assert_signal_emitted(_screen, "start_requested")


func test_change_scene_on_start_defaults_to_true() -> void:
	assert_true(_screen.change_scene_on_start)


func test_trigger_flash_raises_flash_alpha() -> void:
	_screen.trigger_flash()
	await wait_seconds(0.08)
	assert_gt(_screen.flash.color.a, 0.0)


func test_graphics_nodes_present() -> void:
	for node_name in ["GodRays", "FogBack", "FogFront", "HeatHaze", "Sparks", "NostrilSmoke", "WorldEnvironment"]:
		assert_not_null(_screen.get_node_or_null(node_name), "%s missing" % node_name)
