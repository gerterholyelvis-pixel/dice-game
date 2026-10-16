extends Control
## Title screen with Start and Settings. Emits `start_requested` when the player presses Start.

signal start_requested

## Scene loaded by Start once the dice game exists.
const GAME_SCENE_PATH := "res://scenes/game.tscn"
const PARALLAX_BACKGROUND := 14.0
const PARALLAX_DRAGON := 28.0

@onready var background: TextureRect = %Background
@onready var dragon: TextureRect = %Dragon
@onready var fire_glow: TextureRect = %FireGlow
@onready var fade: ColorRect = %Fade
@onready var flash: ColorRect = %Flash
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton

var _background_home: Vector2
var _dragon_home: Vector2


func _ready() -> void:
	_background_home = background.position
	_dragon_home = dragon.position

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(open_settings)
	back_button.pressed.connect(close_settings)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	for button: Button in [start_button, settings_button, back_button]:
		button.resized.connect(func() -> void: button.pivot_offset = Vector2(0.0, button.size.y * 0.5))
		button.mouse_entered.connect(_set_button_hover.bind(button, true))
		button.mouse_exited.connect(_set_button_hover.bind(button, false))
		button.focus_entered.connect(_set_button_hover.bind(button, true))
		button.focus_exited.connect(_set_button_hover.bind(button, false))

	_play_intro()
	_schedule_flash()
	start_button.grab_focus()


## Distant storm flicker: two quick pulses, then waits a random while.
func trigger_flash() -> void:
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.32, 0.05)
	tween.tween_property(flash, "color:a", 0.05, 0.08)
	tween.tween_property(flash, "color:a", 0.22, 0.04)
	tween.tween_property(flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func _schedule_flash() -> void:
	get_tree().create_timer(randf_range(6.0, 13.0)).timeout.connect(_on_flash_timer)


func _on_flash_timer() -> void:
	trigger_flash()
	_schedule_flash()


func _set_button_hover(button: Button, hovered: bool) -> void:
	var target := Vector2.ONE * (1.045 if hovered else 1.0)
	create_tween().tween_property(button, "scale", target, 0.12).set_trans(Tween.TRANS_QUAD)


func open_settings() -> void:
	volume_slider.set_value_no_signal(GameSettings.master_volume)
	fullscreen_check.set_pressed_no_signal(GameSettings.fullscreen)
	settings_panel.modulate.a = 0.0
	settings_panel.show()
	create_tween().tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	$Menu.hide()
	back_button.grab_focus()


func close_settings() -> void:
	GameSettings.save_settings()
	settings_panel.hide()
	$Menu.show()
	settings_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		close_settings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_apply_parallax((event as InputEventMouseMotion).position)


func _apply_parallax(mouse_pos: Vector2) -> void:
	var size_v: Vector2 = get_viewport_rect().size
	var offset: Vector2 = (mouse_pos / size_v - Vector2(0.5, 0.5)) * 2.0
	background.position = _background_home - offset * PARALLAX_BACKGROUND
	dragon.position = _dragon_home - offset * PARALLAX_DRAGON


func _play_intro() -> void:
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)

	# Slow breathing of the dragon.
	var breathe := create_tween().set_loops()
	breathe.tween_property(dragon, "scale", Vector2(1.006, 1.012), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(dragon, "scale", Vector2.ONE, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dragon.pivot_offset = dragon.size * Vector2(0.65, 1.0)

	# Fire glow pulse.
	var pulse := create_tween().set_loops()
	pulse.tween_property(fire_glow, "modulate:a", 0.55, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(fire_glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(fire_glow, "modulate:a", 0.75, 0.3).set_trans(Tween.TRANS_SINE)


func _on_start_pressed() -> void:
	start_requested.emit()
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		push_warning("Start pressed, but %s does not exist yet." % GAME_SCENE_PATH)


func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
