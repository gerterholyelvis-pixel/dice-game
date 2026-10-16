extends GutTest

var _s: RunState


func before_each() -> void:
	_s = RunState.new(99)
	_s.start_round()


func _throw_all(results: Array[int]) -> Dictionary:
	return _s.register_throw(_s.throwable_indices(), results)


func test_round_starts_fresh() -> void:
	assert_eq(_s.turns_left, RunState.TURNS_PER_ROUND)
	assert_eq(_s.gold, 0)
	assert_eq(_s.dice_count(), RunState.START_DICE.size())
	assert_eq(_s.throws, 0)
	assert_false(_s.turn_over)


func test_first_throw_moves_every_die() -> void:
	assert_eq(_s.throwable_indices().size(), _s.dice_count())


func test_pot_sums_landed_faces() -> void:
	_throw_all([2, 3, 4, 6] as Array[int])
	assert_eq(_s.pot(), 15)


func test_burns_are_worth_nothing_and_counted() -> void:
	var r: Dictionary = _throw_all([1, 3, 1, 6] as Array[int])
	assert_eq(r["burns_added"], 2)
	assert_eq(_s.burns, 2)
	assert_eq(_s.pot(), 9)
	assert_false(r["scorched"])


func test_three_burns_scorch_and_wipe_the_pot() -> void:
	var r: Dictionary = _throw_all([1, 1, 1, 6] as Array[int])
	assert_true(r["scorched"])
	assert_eq(_s.pot(), 0)
	assert_false(_s.can_bank())
	assert_false(_s.can_press_on())


func test_burns_accumulate_across_throws_in_a_turn() -> void:
	_throw_all([1, 1, 4, 5] as Array[int])
	assert_false(_s.scorched)
	_s.register_throw(_s.throwable_indices(), [1, 2, 3, 4] as Array[int])
	assert_eq(_s.burns, 3)
	assert_true(_s.scorched)


func test_press_on_rethrows_only_unfrozen_dice() -> void:
	_throw_all([6, 2, 5, 3] as Array[int])
	assert_true(_s.toggle_freeze(0))
	assert_true(_s.toggle_freeze(2))
	assert_eq(_s.throwable_indices(), [1, 3] as Array[int])


func test_cannot_freeze_before_throwing_or_a_burned_die() -> void:
	assert_false(_s.toggle_freeze(0))
	_throw_all([1, 2, 3, 4] as Array[int])
	assert_false(_s.toggle_freeze(0))
	assert_true(_s.toggle_freeze(1))


func test_toggle_freeze_twice_unfreezes() -> void:
	_throw_all([6, 2, 5, 3] as Array[int])
	_s.toggle_freeze(0)
	_s.toggle_freeze(0)
	assert_false(_s.frozen[0])


func test_cannot_press_on_with_everything_frozen() -> void:
	_throw_all([6, 2, 5, 3] as Array[int])
	for i in 4:
		_s.toggle_freeze(i)
	assert_false(_s.can_press_on())


func test_bank_adds_pot_and_ends_turn() -> void:
	_throw_all([6, 5, 4, 3] as Array[int])
	var banked: int = _s.bank()
	assert_eq(banked, 18)
	assert_eq(_s.gold, 18)
	assert_eq(_s.turns_left, RunState.TURNS_PER_ROUND - 1)
	assert_true(_s.turn_over)
	assert_eq(_s.bank(), 0)


func test_scorched_turn_costs_a_turn_and_no_gold() -> void:
	_throw_all([1, 1, 1, 5] as Array[int])
	_s.end_scorched_turn()
	assert_eq(_s.gold, 0)
	assert_eq(_s.turns_left, RunState.TURNS_PER_ROUND - 1)


func test_new_turn_clears_turn_state() -> void:
	_throw_all([1, 1, 4, 5] as Array[int])
	_s.bank()
	_s.start_turn()
	assert_eq(_s.burns, 0)
	assert_eq(_s.throws, 0)
	assert_false(_s.turn_over)
	assert_eq(_s.pot(), 0)


func test_round_won_and_lost() -> void:
	_s.gold = _s.target()
	assert_true(_s.is_round_won())
	assert_false(_s.is_round_lost())
	_s.gold = 0
	_s.turns_left = 0
	assert_true(_s.is_round_lost())


func test_winning_on_the_last_turn_is_not_a_loss() -> void:
	_s.turns_left = 0
	_s.gold = _s.target()
	assert_false(_s.is_round_lost())


func test_targets_increase_and_final_round_flags() -> void:
	for i in range(1, RunState.TARGETS.size()):
		assert_gt(RunState.TARGETS[i], RunState.TARGETS[i - 1])
	for _i in 20:
		_s.advance_round()
	assert_true(_s.is_final_round())
	assert_false(_s.is_run_won())
	_s.gold = _s.target()
	assert_true(_s.is_run_won())


func test_add_die_respects_cap_and_validity() -> void:
	assert_false(_s.add_die("nonsense"))
	assert_true(_s.add_die("obsidian"))
	assert_eq(_s.dice_count(), RunState.START_DICE.size() + 1)
	while _s.dice_count() < RunState.MAX_DICE:
		_s.add_die("bone")
	assert_false(_s.add_die("bone"))


func test_offers_are_distinct_valid_types() -> void:
	for _i in 20:
		var offers: Array[String] = _s.offer_dice()
		assert_eq(offers.size(), RunState.OFFER_COUNT)
		var seen := {}
		for id in offers:
			assert_true(DiceTypes.TYPES.has(id))
			assert_false(seen.has(id))
			seen[id] = true


func test_random_face_comes_from_the_dice_faces() -> void:
	_s.dice_types[0] = "obsidian"
	for _i in 100:
		assert_does_not_have([1], [_s.random_face(0)] as Array)
		assert_true(DiceTypes.faces_of("obsidian").has(_s.random_face(0)))


func test_obsidian_never_burns() -> void:
	for f in DiceTypes.faces_of("obsidian"):
		assert_ne(f, RunState.BURN_FACE)


func test_every_type_has_six_faces_within_pip_range() -> void:
	for id in DiceTypes.ORDER:
		var faces: Array[int] = DiceTypes.faces_of(id)
		assert_eq(faces.size(), 6, id)
		for f in faces:
			assert_between(f, 1, 6, id)


func test_same_seed_same_throws() -> void:
	var a := RunState.new(7)
	var b := RunState.new(7)
	a.start_round()
	b.start_round()
	a.simulate_throw(a.throwable_indices())
	b.simulate_throw(b.throwable_indices())
	assert_eq(a.values, b.values)
