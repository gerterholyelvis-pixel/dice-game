extends GutTest

const GAME := preload("res://scenes/game.tscn")

var _game: Node3D


func before_each() -> void:
	Engine.time_scale = 3.0
	_game = GAME.instantiate()
	add_child_autofree(_game)
	await wait_process_frames(3)


func after_each() -> void:
	Engine.time_scale = 1.0


func _wait_for_phase(target: int, max_seconds: float = 15.0) -> bool:
	var waited := 0.0
	while _game.phase != target and waited < max_seconds:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	return _game.phase == target


func test_starts_ready_with_parked_dice() -> void:
	assert_eq(_game.phase, _game.Phase.READY)
	assert_eq(_game.dice.size(), RunState.START_DICE.size())
	assert_true(_game.throw_button.visible)
	assert_false(_game.press_button.visible)
	assert_false(_game.bank_button.visible)
	assert_eq(_game.round_label.text, "ROUND 1 / %d" % RunState.TARGETS.size())


func test_throw_lands_and_matches_rules_state() -> void:
	_game._on_throw_pressed()
	assert_eq(_game.phase, _game.Phase.ROLLING)
	var reached: bool = await _wait_for_phase(_game.Phase.DECIDING)
	if not reached:
		pass_test("Scorched on the first throw (turn already reset)")
		return
	assert_eq(_game.state.throws, 1)
	for i in _game.dice.size():
		assert_eq(_game.state.values[i], _game.dice[i].top_value())
	assert_true(_game.bank_button.visible)


func test_freeze_toggles_die_and_state() -> void:
	_game._on_throw_pressed()
	var reached: bool = await _wait_for_phase(_game.Phase.DECIDING)
	if not reached:
		pass_test("Scorched on the first throw; nothing to freeze")
		return
	var target := -1
	for i in _game.dice.size():
		if _game.state.can_freeze(i):
			target = i
			break
	if target < 0:
		pass_test("All burned; nothing to freeze")
		return
	_game.toggle_freeze(target)
	assert_true(_game.state.frozen[target])
	assert_true(_game.dice[target].frozen)
	_game.toggle_freeze(target)
	assert_false(_game.dice[target].frozen)


func test_bank_adds_pot_to_hoard_and_starts_next_turn() -> void:
	_game._on_throw_pressed()
	var reached: bool = await _wait_for_phase(_game.Phase.DECIDING)
	if not reached:
		pass_test("Scorched on the first throw")
		return
	var pot: int = _game.state.pot()
	var turns: int = _game.state.turns_left
	_game._on_bank_pressed()
	await _wait_for_phase(_game.Phase.READY, 10.0)
	assert_eq(_game.state.gold, pot)
	assert_eq(_game.state.turns_left, turns - 1)
	assert_eq(_game.state.throws, 0)


func test_winning_a_round_offers_dice() -> void:
	_game.state.gold = _game.state.target()
	_game.state.turns_left = 1
	_game.state.throws = 1
	_game.state.values = [3, 3, 3, 3] as Array[int]
	_game.phase = _game.Phase.DECIDING
	_game._on_bank_pressed()
	await wait_seconds(2.0)
	assert_true(_game.reward_overlay.visible)
	assert_eq(_game.offer_row.get_child_count(), RunState.OFFER_COUNT)
	_game._choose_die("obsidian")
	assert_eq(_game.state.round_number(), 2)
	assert_eq(_game.dice.size(), RunState.START_DICE.size() + 1)
	assert_false(_game.reward_overlay.visible)


func test_losing_last_turn_shows_end_screen() -> void:
	_game.state.turns_left = 1
	_game.state.throws = 1
	_game.state.values = [2, 2, 2, 2] as Array[int]
	_game.phase = _game.Phase.DECIDING
	_game._on_bank_pressed()
	await wait_seconds(2.0)
	assert_true(_game.end_overlay.visible)
	assert_eq(_game.end_title.text, "Devoured")
