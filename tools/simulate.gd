extends SceneTree
## Monte Carlo balance simulator. Uses only RunState's public API.
## Run: godot --headless --path . -s tools/simulate.gd -- runs=3000 [targets=40,70,...] [turns=4] [scorch=3]
##      [grid_runs=300] [seed=1] [policy=freeze_min,bank_threshold,max_burns,stop(0/1)]  (policy skips the grid)
## Overrides: targets/turns/scorch replace RunState's consts; the sim does the win/loss/scorch checks itself.

var targets: Array[int] = []
var turns_per_round: int = RunState.TURNS_PER_ROUND
var scorch_limit: int = RunState.SCORCH_LIMIT
var runs: int = 3000
var grid_runs: int = 300
var base_seed: int = 1


class Policy:
	var freeze_min: int = 7       # freeze non-burned dice showing >= this (7 = never)
	var bank_threshold: int = 0   # bank once pot >= this
	var max_burns: int = 0        # press on only while burns <= this
	var stop_at_target: bool = true  # bank as soon as gold + pot reaches the round target

	func _init(f: int = 7, b: int = 0, m: int = 0, s: bool = true) -> void:
		freeze_min = f
		bank_threshold = b
		max_burns = m
		stop_at_target = s

	func label() -> String:
		return "freeze>=%d bank>=%d press_if_burns<=%d stop_at_target=%s" % [freeze_min, bank_threshold, max_burns, stop_at_target]


func _init() -> void:
	targets = RunState.TARGETS.duplicate()
	var fixed: Policy = null
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"runs": runs = int(kv[1])
			"grid_runs": grid_runs = int(kv[1])
			"seed": base_seed = int(kv[1])
			"turns": turns_per_round = int(kv[1])
			"scorch": scorch_limit = int(kv[1])
			"targets":
				targets.clear()
				for t: String in kv[1].split(",", false):
					targets.append(int(t))
			"policy":
				var p: PackedStringArray = kv[1].split(",", false)
				fixed = Policy.new(int(p[0]), int(p[1]), int(p[2]), int(p[3]) != 0)
	print("targets=%s turns=%d scorch=%d runs=%d" % [str(targets), turns_per_round, scorch_limit, runs])

	var best: Policy = fixed
	if best == null:
		best = _search_grid()
	var naive := Policy.new(7, 0, 0, false)
	_report("BEST   " + best.label(), _simulate(best, runs, base_seed + 777))
	_report("NAIVE  " + naive.label(), _simulate(naive, runs, base_seed + 777))
	quit()


func _search_grid() -> Policy:
	var best: Policy = null
	var best_score: float = -1.0
	var results: Array = []
	for f: int in [3, 4, 5, 6, 7]:
		for b: int in [10, 14, 18, 22, 28, 36, 1000]:
			for m: int in [0, 1, 2]:
				for s: bool in [true, false]:
					var p := Policy.new(f, b, m, s)
					var st: Dictionary = _simulate(p, grid_runs, base_seed)
					var score: float = st["win_rate"] + 0.001 * st["avg_rounds_cleared"]
					results.append([score, p, st])
					if score > best_score:
						best_score = score
						best = p
	results.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("-- top 5 policies (grid_runs=%d) --" % grid_runs)
	for i in mini(5, results.size()):
		var r: Array = results[i]
		print("  win=%.1f%%  %s" % [r[2]["win_rate"] * 100.0, (r[1] as Policy).label()])
	return best


## Expected value of a die per throw, with a mild penalty for burning.
func _die_score(type_id: String) -> float:
	var faces: Array[int] = DiceTypes.faces_of(type_id)
	var total: float = 0.0
	var burn_count: int = 0
	for f in faces:
		if f == RunState.BURN_FACE:
			burn_count += 1
		else:
			total += f
	return total / 6.0 - 2.0 * float(burn_count) / 6.0


func _pick_reward(rs: RunState) -> void:
	var offers: Array[String] = rs.offer_dice()
	var best_id: String = ""
	var best_val: float = -INF
	for id in offers:
		var v: float = _die_score(id)
		if v > best_val:
			best_val = v
			best_id = id
	rs.add_die(best_id)  # silently refused at MAX_DICE


## Throws and applies the overridable scorch limit (RunState's const may differ).
func _throw(rs: RunState) -> void:
	rs.simulate_throw(rs.throwable_indices())
	rs.scorched = rs.burns >= scorch_limit


## Plays one turn. Returns {banked, scorched}. Ends the turn through RunState.
func _play_turn(rs: RunState, p: Policy, target: int) -> Dictionary:
	rs.start_turn()
	_throw(rs)
	while true:
		if rs.scorched:
			rs.end_scorched_turn()
			return {"banked": 0, "scorched": true}
		var pot: int = rs.pot()
		var bank_now: bool = pot >= p.bank_threshold
		if p.stop_at_target and rs.gold + pot >= target:
			bank_now = true
		if not bank_now:
			if p.freeze_min <= 6:
				for i in rs.dice_types.size():
					if not rs.is_burned(i) and rs.values[i] >= p.freeze_min and not rs.frozen[i]:
						rs.toggle_freeze(i)
			if rs.burns > p.max_burns or not rs.can_press_on():
				bank_now = true
		if bank_now:
			return {"banked": rs.bank(), "scorched": false}
		_throw(rs)
	return {}


func _simulate(p: Policy, n_runs: int, seed0: int) -> Dictionary:
	var rounds: int = targets.size()
	var reached: Array[int] = []
	var lost: Array[int] = []
	var banked_sum: Array[int] = []
	var turns_n: Array[int] = []
	var scorch_n: Array[int] = []
	var dice_sum: Array[int] = []
	for _r in rounds:
		reached.append(0)
		lost.append(0)
		banked_sum.append(0)
		turns_n.append(0)
		scorch_n.append(0)
		dice_sum.append(0)
	var wins: int = 0
	var cleared_total: int = 0
	for n in n_runs:
		var rs := RunState.new(seed0 + n)
		var cleared: int = 0
		for r in rounds:
			rs.start_round()
			reached[r] += 1
			dice_sum[r] += rs.dice_count()
			var turns_left: int = turns_per_round
			while turns_left > 0 and rs.gold < targets[r]:
				var res: Dictionary = _play_turn(rs, p, targets[r])
				turns_left -= 1
				turns_n[r] += 1
				banked_sum[r] += res["banked"]
				if res["scorched"]:
					scorch_n[r] += 1
				if turns_left > 0 and rs.gold < targets[r]:
					rs.start_turn()
			if rs.gold < targets[r]:
				lost[r] += 1
				break
			cleared += 1
			if r == rounds - 1:
				wins += 1
			else:
				_pick_reward(rs)
				rs.advance_round()
		cleared_total += cleared
	return {
		"win_rate": float(wins) / n_runs,
		"avg_rounds_cleared": float(cleared_total) / n_runs,
		"reached": reached, "lost": lost, "banked": banked_sum,
		"turns": turns_n, "scorch": scorch_n, "dice": dice_sum, "n": n_runs,
	}


func _report(title: String, st: Dictionary) -> void:
	print("== %s" % title)
	print("  RUN WIN RATE: %.1f%%   avg rounds cleared: %.2f" % [st["win_rate"] * 100.0, st["avg_rounds_cleared"]])
	print("  round | target | reached | loss% (of reached) | gold/turn | scorch/turn | dice")
	for r in targets.size():
		var reached: int = st["reached"][r]
		if reached == 0:
			print("   %d    |  %3d   |    0" % [r + 1, targets[r]])
			continue
		var turns: int = maxi(1, st["turns"][r])
		print("   %d    |  %3d   | %6.1f%% |  %5.1f%%   |  %5.1f  |  %5.1f%%  |  %.2f" % [
			r + 1, targets[r], 100.0 * reached / st["n"], 100.0 * st["lost"][r] / reached,
			float(st["banked"][r]) / turns, 100.0 * st["scorch"][r] / turns, float(st["dice"][r]) / reached])
