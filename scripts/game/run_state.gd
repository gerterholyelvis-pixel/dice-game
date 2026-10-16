class_name RunState
extends RefCounted
## Rules of one run. Pure logic: physics decides what faces land, this class decides what it means.
##
## A round: steal `target()` gold from the dragon's hoard within TURNS_PER_ROUND turns.
## A turn: throw every die. Dice showing one pip are BURNS (worth nothing; three burns in a turn
## SCORCH you and the turn's pot is lost). After a throw you may freeze dice you like, then either
## BANK the pot or PRESS ON by re-throwing every unfrozen die.

const SCORCH_LIMIT := 3
const TURNS_PER_ROUND := 4
const MAX_DICE := 8
const OFFER_COUNT := 3
const BURN_FACE := 1
const TARGETS: Array[int] = [35, 55, 80, 105, 125, 145]
const START_DICE: Array[String] = ["bone", "bone", "bone", "bone"]

var rng := RandomNumberGenerator.new()
var round_index: int = 0
var turns_left: int = 0
var gold: int = 0
var dice_types: Array[String] = []
var values: Array[int] = []
var frozen: Array[bool] = []
var burns: int = 0
var throws: int = 0
var scorched: bool = false
var turn_over: bool = true


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	dice_types = START_DICE.duplicate()


func round_number() -> int:
	return round_index + 1


func round_count() -> int:
	return TARGETS.size()


func target() -> int:
	return TARGETS[round_index]


func dice_count() -> int:
	return dice_types.size()


func start_round() -> void:
	gold = 0
	turns_left = TURNS_PER_ROUND
	start_turn()


## Resets per-turn state. Every die is unthrown (value 0) and must be thrown.
func start_turn() -> void:
	values.clear()
	frozen.clear()
	for i in dice_types.size():
		values.append(0)
		frozen.append(false)
	burns = 0
	throws = 0
	scorched = false
	turn_over = false


## Dice that the next throw will move: all of them on the first throw, otherwise the unfrozen ones.
func throwable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in dice_types.size():
		if throws == 0 or not frozen[i]:
			out.append(i)
	return out


## Records the landed faces of a throw. `indices` and `results` are parallel arrays.
## Returns {burns_added: int, scorched: bool}.
func register_throw(indices: Array[int], results: Array[int]) -> Dictionary:
	var added: int = 0
	for n in indices.size():
		var i: int = indices[n]
		values[i] = results[n]
		if results[n] == BURN_FACE:
			added += 1
	throws += 1
	burns += added
	if burns >= SCORCH_LIMIT:
		scorched = true
	return {"burns_added": added, "scorched": scorched}


func is_burned(i: int) -> bool:
	return values[i] == BURN_FACE


## Gold at stake this turn: every landed die except burns.
func pot() -> int:
	if scorched:
		return 0
	var total: int = 0
	for v in values:
		if v != BURN_FACE:
			total += v
	return total


func can_freeze(i: int) -> bool:
	return throws > 0 and not scorched and not turn_over and i >= 0 and i < dice_types.size() and not is_burned(i)


## Toggles a die's frozen flag. Frozen dice are kept on the next press-on. Burned dice cannot freeze.
func toggle_freeze(i: int) -> bool:
	if not can_freeze(i):
		return false
	frozen[i] = not frozen[i]
	return true


func can_press_on() -> bool:
	if throws == 0 or scorched or turn_over:
		return false
	for i in dice_types.size():
		if not frozen[i]:
			return true
	return false


func can_bank() -> bool:
	return throws > 0 and not scorched and not turn_over


## Banks the pot into the hoard and ends the turn. Returns the gold banked.
func bank() -> int:
	if not can_bank():
		return 0
	var banked: int = pot()
	gold += banked
	_end_turn()
	return banked


## Ends a scorched turn (the pot is lost).
func end_scorched_turn() -> void:
	if scorched and not turn_over:
		_end_turn()


func _end_turn() -> void:
	turn_over = true
	turns_left -= 1


func is_round_won() -> bool:
	return gold >= target()


func is_round_lost() -> bool:
	return turns_left <= 0 and not is_round_won()


func is_final_round() -> bool:
	return round_index == TARGETS.size() - 1


func is_run_won() -> bool:
	return is_final_round() and is_round_won()


func advance_round() -> void:
	round_index = mini(round_index + 1, TARGETS.size() - 1)


func add_die(type_id: String) -> bool:
	if dice_types.size() >= MAX_DICE or not DiceTypes.TYPES.has(type_id):
		return false
	dice_types.append(type_id)
	return true


## Picks distinct die types to offer as a reward between rounds.
func offer_dice(count: int = OFFER_COUNT) -> Array[String]:
	var pool: Array[String] = DiceTypes.ORDER.duplicate()
	var offers: Array[String] = []
	while offers.size() < count and not pool.is_empty():
		var pick: int = rng.randi_range(0, pool.size() - 1)
		offers.append(pool[pick])
		pool.remove_at(pick)
	return offers


## Statistical roll of die `i` (used by tests and the balance simulator; the game uses physics).
func random_face(i: int) -> int:
	var faces: Array[int] = DiceTypes.faces_of(dice_types[i])
	return faces[rng.randi_range(0, faces.size() - 1)]


## Convenience for simulation/tests: throws `indices` using the RNG and registers the result.
func simulate_throw(indices: Array[int]) -> Dictionary:
	var results: Array[int] = []
	for i in indices:
		results.append(random_face(i))
	return register_throw(indices, results)
