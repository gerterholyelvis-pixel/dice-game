extends Node3D
## The table: throw real dice, freeze the keepers, press on or bank. Rules live in RunState;
## physics decides the faces; this script sequences it and drives the HUD.

enum Phase { READY, ROLLING, DECIDING, RESOLVING, OVERLAY }

const MENU_SCENE_PATH := "res://scenes/start_screen.tscn"
const GOLD := Color(1.0, 0.82, 0.4)
const BURN_RED := Color(1.0, 0.3, 0.2)
const KEEP_GOLD := Color(1.0, 0.85, 0.35)

var state: RunState
var phase: Phase = Phase.READY
var dice: Array[Die3D] = []

var _pending: int = 0
var _shown_pot: int = -1

signal _throw_finished

@onready var arena: Arena = %Arena
@onready var dice_root: Node3D = %Dice
@onready var fade: ColorRect = %Fade
@onready var hoard_bar: ProgressBar = %HoardBar
@onready var hoard_value: Label = %HoardValue
@onready var round_label: Label = %RoundLabel
@onready var turns_label: Label = %TurnsLabel
@onready var heat_meter: HeatMeter = %HeatMeter
@onready var pot_label: Label = %PotLabel
@onready var hint_label: Label = %HintLabel
@onready var throw_button: Button = %ThrowButton
@onready var press_button: Button = %PressButton
@onready var bank_button: Button = %BankButton
@onready var menu_button: Button = %MenuButton
@onready var popup_layer: Control = %PopupLayer
@onready var reward_overlay: Control = %RewardOverlay
@onready var reward_title: Label = %RewardTitle
@onready var reward_sub: Label = %RewardSub
@onready var offer_row: HBoxContainer = %OfferRow
@onready var end_overlay: Control = %EndOverlay
@onready var end_title: Label = %EndTitle
@onready var end_sub: Label = %EndSub
@onready var retry_button: Button = %RetryButton
@onready var end_menu_button: Button = %EndMenuButton


func _ready() -> void:
	throw_button.pressed.connect(_on_throw_pressed)
	press_button.pressed.connect(_on_press_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	menu_button.pressed.connect(_go_to_menu)
	end_menu_button.pressed.connect(_go_to_menu)
	retry_button.pressed.connect(_new_run)

	create_tween().tween_property(fade, "color:a", 0.0, 0.9)
	state = RunState.new()
	_begin_round()


# --- Flow ---------------------------------------------------------------------------------

func _begin_round() -> void:
	state.start_round()
	arena.set_hoard_fill(0.0)
	_sync_dice()
	_park_all()
	phase = Phase.READY
	_update_hud()


func _begin_turn() -> void:
	state.start_turn()
	_park_all()
	phase = Phase.READY
	_update_hud()


func _on_throw_pressed() -> void:
	if phase == Phase.READY:
		_throw(state.throwable_indices())


func _on_press_pressed() -> void:
	if phase == Phase.DECIDING and state.can_press_on():
		_throw(state.throwable_indices())


func _on_bank_pressed() -> void:
	if phase != Phase.DECIDING or not state.can_bank():
		return
	phase = Phase.RESOLVING
	_update_hud()
	var banked: int = state.bank()
	arena.flash_bank()
	arena.set_hoard_fill(float(state.gold) / float(state.target()))
	for die in dice:
		die.flash(GOLD, 0.6)
	_popup("+%d gold" % banked, _dice_center(), GOLD, 84)
	await get_tree().create_timer(1.1).timeout
	await _after_turn()


func _throw(indices: Array[int]) -> void:
	phase = Phase.ROLLING
	_update_hud()
	# Keepers hold still while the others fly.
	for i in dice.size():
		if not indices.has(i):
			dice[i].freeze = true
	_pending = indices.size()
	for n in indices.size():
		var die: Die3D = dice[indices[n]]
		die.settled.connect(_on_die_settled, CONNECT_ONE_SHOT)
		die.throw_from(arena.throw_origin(n, indices.size()), arena.throw_target(), randf_range(0.85, 1.15))
	await _throw_finished
	await _resolve_throw(indices)


func _on_die_settled(_die: Die3D) -> void:
	_pending -= 1
	if _pending <= 0:
		_throw_finished.emit()


func _resolve_throw(indices: Array[int]) -> void:
	var results: Array[int] = []
	for i in indices:
		results.append(dice[i].top_value())
	var outcome: Dictionary = state.register_throw(indices, results)

	for n in indices.size():
		var die: Die3D = dice[indices[n]]
		if results[n] == RunState.BURN_FACE:
			die.flash(BURN_RED, 0.8)
			_popup("BURN", die.global_position + Vector3.UP * 1.1, BURN_RED, 52)
	_update_hud()

	if outcome["scorched"]:
		phase = Phase.RESOLVING
		arena.flash_scorch()
		_popup("SCORCHED!", _dice_center() + Vector3.UP * 0.8, BURN_RED, 110)
		for die in dice:
			die.flash(BURN_RED, 1.0)
		await get_tree().create_timer(1.6).timeout
		state.end_scorched_turn()
		await _after_turn()
	else:
		phase = Phase.DECIDING
		_update_hud()


func _after_turn() -> void:
	if state.is_run_won():
		_show_end(true)
	elif state.is_round_won():
		_show_rewards()
	elif state.is_round_lost():
		_show_end(false)
	else:
		_begin_turn()


# --- Freezing dice ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.DECIDING:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var i: int = _die_at(click.position)
			if i >= 0:
				toggle_freeze(i)


func toggle_freeze(i: int) -> void:
	if state.toggle_freeze(i):
		dice[i].frozen = state.frozen[i]
		dice[i].set_frozen_visual(state.frozen[i])
		_update_hud()


func _die_at(screen_pos: Vector2) -> int:
	var cam: Camera3D = arena.camera
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return dice.find(hit["collider"])


# --- Dice nodes ---------------------------------------------------------------------------

func _sync_dice() -> void:
	while dice.size() > state.dice_count():
		dice.pop_back().queue_free()
	while dice.size() < state.dice_count():
		var die := Die3D.new()
		dice_root.add_child(die)
		dice.append(die)
	for i in dice.size():
		dice[i].setup(state.dice_types[i])


func _park_all() -> void:
	for i in dice.size():
		dice[i].frozen = false
		dice[i].set_frozen_visual(false)
		dice[i].park_at(arena.park_position(i, dice.size()))


func _dice_center() -> Vector3:
	var sum := Vector3.ZERO
	for die in dice:
		sum += die.global_position
	return sum / maxf(dice.size(), 1)


# --- HUD ----------------------------------------------------------------------------------

func _update_hud() -> void:
	round_label.text = "ROUND %d / %d" % [state.round_number(), state.round_count()]
	turns_label.text = "Turns left: %d" % state.turns_left
	hoard_bar.max_value = state.target()
	create_tween().tween_property(hoard_bar, "value", float(state.gold), 0.4).set_trans(Tween.TRANS_CUBIC)
	hoard_value.text = "%d / %d" % [state.gold, state.target()]
	heat_meter.set_heat(state.burns, RunState.SCORCH_LIMIT)

	var pot: int = state.pot()
	pot_label.text = "SCORCHED" if state.scorched else "POT %d" % pot
	pot_label.add_theme_color_override("font_color", BURN_RED if state.scorched else GOLD)
	if pot != _shown_pot and state.throws > 0:
		_pop(pot_label)
	_shown_pot = pot

	var ready: bool = phase == Phase.READY
	var deciding: bool = phase == Phase.DECIDING
	throw_button.visible = ready
	press_button.visible = not ready
	bank_button.visible = not ready
	press_button.disabled = not (deciding and state.can_press_on())
	bank_button.disabled = not (deciding and state.can_bank())
	menu_button.disabled = phase == Phase.ROLLING or phase == Phase.RESOLVING

	var frozen_count: int = state.frozen.count(true)
	press_button.text = "Press On (%d)" % (state.dice_count() - frozen_count) if state.throws > 0 else "Press On"
	bank_button.text = "Bank %d" % pot if state.throws > 0 else "Bank"

	match phase:
		Phase.READY:
			hint_label.text = "Throw the bones."
		Phase.ROLLING:
			hint_label.text = ""
		Phase.DECIDING:
			hint_label.text = "Click dice to keep them. Press on to re-throw the rest, or bank the pot."
		_:
			hint_label.text = ""


func _pop(control: Control) -> void:
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2.ONE * 1.2, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _popup(text: String, world_pos: Vector3, color: Color, font_size: int = 60) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.02))
	label.add_theme_constant_override("outline_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(label)
	label.reset_size()
	var screen: Vector2 = arena.camera.unproject_position(world_pos)
	label.position = screen - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 0.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - 110.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.9)
	tw.chain().tween_callback(label.queue_free)


# --- Rewards and end ----------------------------------------------------------------------

func _show_rewards() -> void:
	phase = Phase.OVERLAY
	_update_hud()
	reward_title.text = "Hoard Raided!"
	reward_sub.text = "Round %d cleared with %d gold. Claim a die for your pouch." % [state.round_number(), state.gold]
	for child in offer_row.get_children():
		child.queue_free()
	for id in state.offer_dice():
		offer_row.add_child(_make_offer_button(id))
	_show_overlay(reward_overlay)


func _make_offer_button(type_id: String) -> Button:
	var data: Dictionary = DiceTypes.TYPES[type_id]
	var faces: Array[int] = DiceTypes.faces_of(type_id)
	var face_text: String = " ".join(faces.map(func(f: int) -> String: return str(f)))
	var button := Button.new()
	button.custom_minimum_size = Vector2(340, 300)
	button.add_theme_font_size_override("font_size", 30)
	button.text = "%s\n\n%s\navg %.1f\n\n%s" % [data["name"], face_text, DiceTypes.average(type_id), data["blurb"]]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_choose_die.bind(type_id))
	return button


func _choose_die(type_id: String) -> void:
	state.add_die(type_id)
	state.advance_round()
	reward_overlay.hide()
	_begin_round()


func _show_end(won: bool) -> void:
	phase = Phase.OVERLAY
	_update_hud()
	if won:
		end_title.text = "Hoard Plundered!"
		end_title.add_theme_color_override("font_color", GOLD)
		end_sub.text = "All %d rounds cleared. The dragon sleeps poorer." % state.round_count()
	else:
		end_title.text = "Devoured"
		end_title.add_theme_color_override("font_color", BURN_RED)
		end_sub.text = "Round %d: %d of %d gold stolen." % [state.round_number(), state.gold, state.target()]
	_show_overlay(end_overlay)


func _show_overlay(overlay: Control) -> void:
	overlay.modulate.a = 0.0
	overlay.show()
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.3)


func _new_run() -> void:
	end_overlay.hide()
	state = RunState.new()
	_begin_round()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
