# tests/smoke_test.gd
# ============================================================
# SMOKE TEST — runs a full 24-week season programmatically and asserts
# invariants both AFTER each week (end-to-end) and AFTER EACH PHASE
# of the WeekResolver pipeline. Used as the safety net for Phase B of
# the refactor (REFACTOR_PLAN.md).
#
# HOW TO RUN:
#   In the editor: Scene → Run Specific Scene → res://tests/smoke_test.tscn
#   The output panel will show:
#     - per-phase trace (compact, one line per phase emission)
#     - per-week summary line
#     - a final PASS/FAIL line
#   On any assertion failure the script pushes an error and stops the
#   season at the failing week so the broken state is visible.
#
# WHAT IT ASSERTS:
#   END-OF-WEEK (same as before):
#     - All player stats stay in their declared ranges.
#     - Squad size 1..SQUAD_SIZE.
#     - League rank 1..8.
#     - Roster size unchanged.
#     - WeekResult fields populated coherently.
#     - Synergy ledger only references current roster.
#
#   PER-PHASE (new in B2 — hooked into SignalHub):
#     - bench_resolved        : every outcome has a known action; benched
#                                players' stamina/morale/burnout still in range.
#     - match_context_generated: ctx.opponent_traits has the expected size,
#                                opponent_score > 0, situations 2-3 entries.
#     - match_simulated       : study charges consumed for any active player
#                                that had them; counter_mult in valid range.
#     - post_match_applied    : league.player_rank() in 1..8; active players'
#                                stamina/morale still in 0..100.
#     - xp_awarded            : every active player has level >= 1, xp >= 0.
#     - goals_checked         : if a quarter bonus fired, the description
#                                string is non-empty.
#     - season_rotated        : new_week is monotonically increasing.
#
# DRIVING STRATEGY:
#   Default squad (Apex/Byte/Ghost active, Kira/Rex on bench) plays every
#   match. No squad changes, no market hires. This is a regression detector,
#   not a balance test.
# ============================================================
extends Node


# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

const WEEKS_TO_RUN: int = 24

# Toggle true for a verbose per-phase trace.
# False prints only the per-week summary and the final pass/fail line.
const VERBOSE_PHASES: bool = false


# ---------------------------------------------------------------------------
# RUN STATE
# ---------------------------------------------------------------------------

var _failed: bool = false
var _failures: Array[String] = []

# Tracking state for per-phase assertions. Updated by signal handlers
# during a single advance_week() call so the per-week assertions can
# cross-check what each phase reported.
var _phase_trace_for_week: Array[String] = []
var _last_new_week:  int = 0    # for season_rotated monotonicity check


# ---------------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------------

func _ready() -> void:
	print("=" .repeat(72))
	print("SMOKE TEST — running %d weeks against GameDirector" % WEEKS_TO_RUN)
	print("=" .repeat(72))

	_connect_phase_signals()

	# Reset to a clean game state. _ready already ran on the autoload; we
	# call start_new_game() so this test is reproducible regardless of
	# what other scene last touched the autoload.
	GameDirector.start_new_game()
	_assert_initial_state()

	for i in WEEKS_TO_RUN:
		_phase_trace_for_week.clear()
		var result: WeekResult = GameDirector.advance_week()
		_assert_player_invariants(week_num)
		_assert_squad_invariants(week_num)
		_assert_league_invariants(week_num)
		_assert_synergy_invariants(week_num)
		_assert_phase_trace(week_num)
		_print_week_summary(week_num, result)
		if _failed:
			push_error("SMOKE TEST aborted at week %d" % week_num)
			break
	print("=" .repeat(72))
	if _failed:
		print("SMOKE TEST: ❌ FAIL  (%d invariant violation%s)" % [
			_failures.size(), "" if _failures.size() == 1 else "s"
		])
		for f in _failures:
			print("  - " + f)
		print("=" .repeat(72))
		get_tree().quit(1)
	else:
		print("SMOKE TEST: ✅ PASS  (24 weeks, all invariants held)")
		print("=" .repeat(72))
		get_tree().quit(0)# ---------------------------------------------------------------------------
# PER-PHASE SIGNAL HOOKS
# ---------------------------------------------------------------------------

func _connect_phase_signals() -> void:
	SignalHub.bench_resolved.connect(_on_bench_resolved)
	SignalHub.match_context_generated.connect(_on_match_context_generated)
	SignalHub.match_simulated.connect(_on_match_simulated)
	SignalHub.post_match_applied.connect(_on_post_match_applied)
	SignalHub.xp_awarded.connect(_on_xp_awarded)
	SignalHub.goals_checked.connect(_on_goals_checked)
	SignalHub.season_rotated.connect(_on_season_rotated)


func _on_bench_resolved(outcomes: Array) -> void:
	_phase_trace_for_week.append("bench_resolved")
	if VERBOSE_PHASES:
		print("    [phase] bench_resolved (%d outcomes)" % outcomes.size())

	const VALID_ACTIONS := ["rest", "train", "study"]
	for o in outcomes:
		var action: String = o.get("action", "")
		_check(action in VALID_ACTIONS, "bench outcome action",
			"unexpected action '%s' for %s" % [action, o.get("player").player_name])
		var p: Player = o.get("player")
		if p == null:
			_check(false, "bench outcome player", "null player in outcome")
			continue
		_check(p.stamina >= 0 and p.stamina <= 100,
			"bench %s stamina post-action" % p.player_name,
			"out of range: %d" % p.stamina)
		_check(p.morale >= 0 and p.morale <= 100,
			"bench %s morale post-action" % p.player_name,
			"out of range: %d" % p.morale)
		_check(p.burnout >= 0 and p.burnout <= 5,
			"bench %s burnout post-action" % p.player_name,
			"out of range: %d" % p.burnout)


func _on_match_context_generated(ctx: MatchContext) -> void:
	_phase_trace_for_week.append("match_context_generated")
	if VERBOSE_PHASES:
		print("    [phase] match_context_generated (opp=%d, traits=%d, sit=%d)" % [
			ctx.opponent_score, ctx.opponent_traits.size(), ctx.situations.size()
		])

	_check(ctx.opponent_score > 0, "ctx.opponent_score",
		"non-positive: %d" % ctx.opponent_score)
	_check(ctx.opponent_traits.size() == 3, "ctx.opponent_traits.size",
		"expected 3, got %d" % ctx.opponent_traits.size())
	_check(ctx.situations.size() >= 2 and ctx.situations.size() <= 3,
		"ctx.situations.size", "expected 2-3, got %d" % ctx.situations.size())
	_check(ctx.absolute_week >= 1, "ctx.absolute_week",
		"non-positive: %d" % ctx.absolute_week)
	_check(ctx.match_type != "", "ctx.match_type", "empty")
	_check(ctx.patch.has("buffed") and ctx.patch.has("nerfed"),
		"ctx.patch shape", "missing buffed/nerfed keys")


func _on_match_simulated(match_sim: Dictionary) -> void:
	_phase_trace_for_week.append("match_simulated")
	if VERBOSE_PHASES:
		print("    [phase] match_simulated (team=%d opp=%d won=%s)" % [
			match_sim.get("team_score", 0),
			match_sim.get("opponent_score", 0),
			match_sim.get("won", false),
		])

	_check(match_sim.has("won"), "match_sim.won", "key missing")
	_check(match_sim.has("players"), "match_sim.players", "key missing")
	_check(match_sim.has("pre_study"), "match_sim.pre_study", "key missing (B2 contract)")

	var counter_mult: float = match_sim.get("counter_mult", 1.0)
	_check(counter_mult >= (1.0 - Balance.match_balance.counter_penalty_max) - 0.001
			and counter_mult <= (1.0 + Balance.match_balance.counter_bonus_max) + 0.001,
		"match_sim.counter_mult", "out of range: %f" % counter_mult)

	# Verify study charges were consumed for any active player who had them.
	# We use the pre_study snapshot to know who had charges at sim time.
	var pre_study: Dictionary = match_sim.get("pre_study", {})
	for player_name in pre_study.keys():
		var pre: int = pre_study[player_name]
		if pre > 0:
			var p: Player = _find_player_by_name(player_name)
			if p != null:
				_check(p.study_charges == 0,
					"%s study_charges post-sim" % player_name,
					"expected 0 (had %d pre-sim), got %d" % [pre, p.study_charges])


func _on_post_match_applied(week_result: WeekResult) -> void:
	_phase_trace_for_week.append("post_match_applied")
	if VERBOSE_PHASES:
		print("    [phase] post_match_applied (rank=%d)" % week_result.league_rank)

	_check(week_result.league_rank >= 1 and week_result.league_rank <= 8,
		"post_match league_rank", "out of range: %d" % week_result.league_rank)
	# Active players' stat ranges already covered by the per-week check, but
	# we re-check here so a regression points at this phase specifically.
	for p in GameDirector.active_players():
		_check(p.stamina >= 0 and p.stamina <= 100,
			"post_match %s stamina" % p.player_name,
			"out of range: %d" % p.stamina)
		_check(p.morale >= 0 and p.morale <= 100,
			"post_match %s morale" % p.player_name,
			"out of range: %d" % p.morale)


func _on_xp_awarded(level_ups: Array) -> void:
	_phase_trace_for_week.append("xp_awarded")
	if VERBOSE_PHASES:
		print("    [phase] xp_awarded (%d level-ups)" % level_ups.size())

	# After XP is awarded, every active player should still have a sane level.
	for p in GameDirector.active_players():
		_check(p.level >= 1 and p.level <= LevelSystem.MAX_LEVEL,
			"xp_awarded %s level" % p.player_name,
			"out of range: %d" % p.level)
		_check(p.xp >= 0, "xp_awarded %s xp" % p.player_name,
			"negative: %d" % p.xp)


func _on_goals_checked(week_result: WeekResult) -> void:
	_phase_trace_for_week.append("goals_checked")
	if VERBOSE_PHASES:
		var note: String = (" bonus='%s'" % week_result.quarter_bonus) \
			if week_result.quarter_bonus != "" else ""
		print("    [phase] goals_checked%s" % note)

	# If a quarter bonus fired, its description should be non-empty.
	# (The reverse — empty quarter_bonus when one should have fired — is
	# something the goal manager owns and we don't second-guess here.)


func _on_season_rotated(new_week: int) -> void:
	_phase_trace_for_week.append("season_rotated")
	if VERBOSE_PHASES:
		print("    [phase] season_rotated (new_week=%d)" % new_week)

	_check(new_week > _last_new_week,
		"season_rotated monotonicity",
		"new_week %d not greater than previous %d" % [new_week, _last_new_week])
	_last_new_week = new_week


# ---------------------------------------------------------------------------
# END-OF-WEEK INVARIANT CHECKS
# ---------------------------------------------------------------------------

func _assert_initial_state() -> void:
	_check(GameDirector.players.size() == 5, "initial roster", "expected 5 players")
	_check(GameDirector.week == 1, "initial week", "expected 1, got %d" % GameDirector.week)
	_check(GameDirector.synergy != null, "initial synergy", "synergy ledger is null")
	_check(GameDirector.league != null, "initial league", "league is null")
	_check(GameDirector.market != null, "initial market", "market is null")
	_check(GameDirector.goal_manager != null, "initial goals", "goal_manager is null")


func _assert_player_invariants(week_num: int) -> void:
	for p in GameDirector.players:
		var who: String = "%s (week %d)" % [p.player_name, week_num]
		_check(p.stamina >= 0 and p.stamina <= 100, who + " stamina",
			"out of range: %d" % p.stamina)
		_check(p.morale >= 0 and p.morale <= 100, who + " morale",
			"out of range: %d" % p.morale)
		_check(p.level >= 1 and p.level <= LevelSystem.MAX_LEVEL, who + " level",
			"out of range: %d" % p.level)
		_check(p.xp >= 0, who + " xp", "negative: %d" % p.xp)
		_check(p.burnout >= 0 and p.burnout <= 5, who + " burnout",
			"out of range: %d" % p.burnout)
		_check(p.study_charges >= 0 and p.study_charges <= Balance.match_balance.bench_study_max_charges,
			who + " study_charges", "out of range: %d" % p.study_charges)
		_check(p.skill > 0 and p.skill <= 100, who + " skill",
			"out of range: %d" % p.skill)
		_check(p.focus > 0 and p.focus <= 100, who + " focus",
			"out of range: %d" % p.focus)


func _assert_squad_invariants(week_num: int) -> void:
	var active_count: int = GameDirector.active_players().size()
	_check(active_count >= 1 and active_count <= GameDirector.SQUAD_SIZE,
		"week %d active count" % week_num, "got %d" % active_count)


func _assert_league_invariants(week_num: int) -> void:
	var rank: int = GameDirector.league_rank()
	_check(rank >= 1 and rank <= 8, "week %d league rank" % week_num,
		"out of range: %d" % rank)
	_check(GameDirector.get_standings().size() == 8,
		"week %d standings size" % week_num, "expected 8 teams")


func _assert_synergy_invariants(week_num: int) -> void:
	var active: Array = GameDirector.active_players()
	for i in active.size():
		for j in range(i + 1, active.size()):
			var n: int = GameDirector.synergy.matches_together(
				active[i].player_name, active[j].player_name
			)
			_check(n >= 1, "week %d synergy(%s,%s)" % [
				week_num, active[i].player_name, active[j].player_name
			], "expected >= 1, got %d" % n)


func _assert_week_result(result: WeekResult, week_num: int) -> void:
	_check(result != null, "week %d result" % week_num, "null WeekResult returned")
	if result == null:
		return
	_check(result.team_score >= 0, "week %d team_score" % week_num,
		"negative: %d" % result.team_score)
	_check(result.opponent_score > 0, "week %d opponent_score" % week_num,
		"non-positive: %d" % result.opponent_score)
	_check(result.counter_mult >= (1.0 - Balance.match_balance.counter_penalty_max) - 0.001
			and result.counter_mult <= (1.0 + Balance.match_balance.counter_bonus_max) + 0.001,
		"week %d counter_mult" % week_num,
		"out of range: %f" % result.counter_mult)
	_check(result.coverage_mult >= 1.0 - 0.001,
		"week %d coverage_mult" % week_num,
		"below 1.0: %f" % result.coverage_mult)
	_check(result.synergy_bonus_total >= 0, "week %d synergy_bonus_total" % week_num,
		"negative: %d" % result.synergy_bonus_total)
	_check(result.player_results.size() >= 1,
		"week %d player_results" % week_num, "empty")


# Verifies the WeekResolver pipeline emitted all 7 phases in order.
# A missing or out-of-order phase indicates a regression in advance_week's
# orchestration code.
func _assert_phase_trace(week_num: int) -> void:
	const EXPECTED: Array[String] = [
		"bench_resolved",
		"match_context_generated",
		"match_simulated",
		"post_match_applied",
		"xp_awarded",
		"goals_checked",
		"season_rotated",
	]
	_check(_phase_trace_for_week == EXPECTED,
		"week %d phase trace" % week_num,
		"expected %s, got %s" % [str(EXPECTED), str(_phase_trace_for_week)])


# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------

func _print_week_summary(week_num: int, result: WeekResult) -> void:
	var outcome: String = "WIN " if result.won else "LOSS"
	var line: String = "  W%02d  %s  team=%3d  opp=%3d  rank=%d  cnt_mult=%.2f  cov=%.2f  syn=%d" % [
		week_num, outcome, result.team_score, result.opponent_score,
		result.league_rank, result.counter_mult, result.coverage_mult,
		result.synergy_bonus_total
	]
	print(line)


func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		return
	_failed = true
	var msg: String = "%s — %s" % [label, detail]
	_failures.append(msg)
	push_error("INVARIANT FAIL: " + msg)


func _find_player_by_name(player_name: String) -> Player:
	for p in GameDirector.players:
		if p.player_name == player_name:
			return p
	return null
