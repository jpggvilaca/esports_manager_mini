# scripts/systems/WeekResolver.gd
# ============================================================
# WEEK RESOLVER — pure phase functions for the weekly turn pipeline.
#
# DESIGN (Phase B2):
#   `advance_week()` used to be a 120-line method on GameManager that did
#   everything in one go. This file splits it into seven typed phases,
#   each a `static func` with explicit inputs and a typed return value.
#   GameDirector orchestrates them and emits SignalHub signals between
#   calls (see GameDirector.advance_week).
#
# PIPELINE ORDER (canonical, do not reorder without reading the side-effect notes):
#   1. resolve_bench               → applies rest/train/study to benched players
#   2. generate_match_context      → calendar, opponent, situations, patch lookup
#   3. simulate_match              → runs Simulation.simulate_team, consumes study charges
#   4. apply_post_match_effects    → streaks, stamina cost, morale, league record, synergy ledger
#   5. award_xp                    → XP loop, level-ups
#   6. check_goals                 → goal_manager updates, quarter bonuses
#   7. rotate_systems_if_season_end→ season-end signal (orchestrator handles the resets)
#
# STATELESS — every method is `static`. No instance fields, no `self`.
# Inputs come from arguments; outputs are returned. Mutations are explicit
# and applied to argument objects (not module-level state).
#
# DEPENDS ON:
#   - Calendar, TraitMatchup, Simulation, MetaPatch (pure / static)
#   - LevelSystem, GameText, Tuning (static lookups)
#   - Player, WeekResult, MatchContext (data containers)
#   - SeasonGoalManager, PlayerMarket, LeagueManager, Synergy (mutable
#     subsystems — passed in as arguments, mutated in place)
#
# DOES NOT DEPEND ON:
#   - GameDirector  (the autoload that orchestrates these phases)
#   - SignalHub     (signal emission lives at the orchestration layer)
#   - Any UI scenes
#
# DETERMINISM:
#   The single randi_range call is in `generate_match_context` (opponent
#   score wiggle). Moving it would change the seed sequence and break
#   smoke-test stability. Do not refactor RNG placement without checking.
# ============================================================
class_name WeekResolver
extends RefCounted

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")
const MetaPatch    := preload("res://scripts/systems/MetaPatch.gd")


# ---------------------------------------------------------------------------
# PHASE 1 — resolve_bench
#
# Applies the chosen bench action (rest / train / study) to each benched
# player. Mutates each player's stamina, morale, burnout, study_charges,
# xp (via LevelSystem.award_action_xp).
#
# Returns: Array of bench-outcome dicts (legacy shape, see BenchOutcome.gd
#   for the typed equivalent that will replace this in a later phase).
# ---------------------------------------------------------------------------
static func resolve_bench(benched: Array[Player]) -> Array:
	var outcomes: Array = []
	for p in benched:
		outcomes.append(_resolve_one_bench(p))
	return outcomes


static func _resolve_one_bench(player: Player) -> Dictionary:
	var prev_stamina: int = player.stamina

	match player.bench_action:
		"train":
			player.stamina = max(player.stamina - Balance.match_balance.bench_train_stamina_cost, 0)
			player.burnout = min(player.burnout + 1, 5)
			var lu: Array = LevelSystem.award_action_xp(player, "train")
			return {
				"player":        player,
				"action":        "train",
				"stamina_gain":  player.stamina - prev_stamina,
				"xp_gained":     player.xp_delta,
				"study_charges": player.study_charges,
				"level_ups":     lu,
				"narrative":     player.player_name + " trained on the bench. The grind never stops.",
			}

		"study":
			# Studying the meta — accrue a charge, no stamina change, small
			# morale bump (they feel prepared).
			var prev_charges: int = player.study_charges
			player.study_charges = min(
				player.study_charges + Balance.match_balance.bench_study_charge_gain,
				Balance.match_balance.bench_study_max_charges
			)
			var charge_gain: int = player.study_charges - prev_charges
			player.morale = clamp(player.morale + 2, 0, 100)
			return {
				"player":        player,
				"action":        "study",
				"stamina_gain":  0,
				"xp_gained":     0,
				"study_charges": player.study_charges,
				"charge_gain":   charge_gain,
				"level_ups":     [],
				"narrative":     "%s studied the meta (%d charge%s ready for next match)." % [
					player.player_name,
					player.study_charges,
					"" if player.study_charges == 1 else "s",
				],
			}

		_:  # "rest" and any unrecognized fallthrough
			var gain: int = Balance.match_balance.bench_rest_stamina_aggressive \
				if player.primary_trait == "aggressive" \
				else Balance.match_balance.bench_rest_stamina
			player.stamina = _apply_with_dr(player.stamina, gain, 80, 0.5)
			player.morale  = _apply_with_dr(player.morale,  Balance.match_balance.bench_rest_morale, 80, 0.5)
			player.burnout = max(player.burnout - 2, 0)
			return {
				"player":        player,
				"action":        "rest",
				"stamina_gain":  player.stamina - prev_stamina,
				"xp_gained":     0,
				"study_charges": player.study_charges,
				"level_ups":     [],
				"narrative":     player.player_name + " rested this week. Stamina recovered.",
			}


# ---------------------------------------------------------------------------
# PHASE 2 — generate_match_context
#
# Looks up the calendar entry, generates opponent traits + situations
# (both deterministic from season/week/label), computes legacy preview
# matchup modifier, picks the active patch, and rolls the opponent score
# (the only RNG inside this phase — the ±10 wiggle around the seeded
# threshold).
# ---------------------------------------------------------------------------
static func generate_match_context(
	absolute_week: int,
	week_in_season: int,
	season: int,
	active: Array[Player]
) -> MatchContext:
	var ctx := MatchContext.new()
	var cal_entry: Dictionary = Calendar.get_week(absolute_week)

	ctx.absolute_week    = absolute_week
	ctx.week_in_season   = week_in_season
	ctx.season           = season
	ctx.match_type       = cal_entry["type"]
	ctx.difficulty_label = cal_entry["label"]
	ctx.is_important     = ctx.match_type in [
		Calendar.TYPE_IMPORTANT, Calendar.TYPE_TOURNAMENT
	]

	# Opponent score — base threshold + RNG wiggle (preserves legacy seed seq).
	ctx.opponent_score = cal_entry["opponent"] + randi_range(-10, 10)

	# Trait/situation generation (deterministic from season/week/label).
	ctx.opponent_traits = TraitMatchup.generate_opponent_traits(
		season, week_in_season, cal_entry["label"]
	)
	ctx.situations = TraitMatchup.generate_situations(
		season, week_in_season, ctx.match_type
	)

	# Squad-side trait array + legacy preview number (UI-only, not in formula).
	ctx.player_match_traits = TraitMatchup.get_team_traits(active)
	ctx.matchup_modifier    = TraitMatchup.calculate_matchup_modifier(
		ctx.player_match_traits, ctx.opponent_traits, ctx.situations
	)

	ctx.patch = MetaPatch.get_patch(absolute_week)

	return ctx


# ---------------------------------------------------------------------------
# PHASE 3 — simulate_match
#
# Runs the actual match simulation. Snapshots study charges before
# simulating (so the resolution screen can show "Apex used 2 charges"),
# then consumes them after. Returns the raw simulation result dict
# (legacy shape — typed MatchOutcome lands in a follow-up sweep).
#
# MUTATES: active players' study_charges (set to 0 for any who had charges).
# ---------------------------------------------------------------------------
static func simulate_match(
	active: Array[Player],
	ctx: MatchContext,
	synergy: Synergy
) -> Dictionary:
	# Snapshot pre-match study charges by name (UI display).
	var pre_study: Dictionary = {}
	for p in active:
		pre_study[p.player_name] = p.study_charges

	var match_sim: Dictionary = Simulation.simulate_team(
		active,
		ctx.is_important,
		ctx.opponent_score,
		ctx.opponent_traits,
		ctx.situations,
		synergy,
		ctx.absolute_week
	)

	# Consume charges for any active player that had them.
	for p in active:
		if p.study_charges > 0:
			p.study_charges = 0

	match_sim["pre_study"] = pre_study
	return match_sim


# ---------------------------------------------------------------------------
# PHASE 4 — apply_post_match_effects
#
# Updates streaks, applies stamina cost, applies morale delta, records
# the player result in the league, applies end-of-season tier rewards if
# applicable, increments synergy ledger.
#
# `roster` is the FULL roster (active + benched) — needed because
# `league.apply_season_result` rewards every player, not just the active
# squad. Passing it in keeps the season-end concern inside the resolver
# rather than leaking into GameDirector.
#
# MUTATES:
#   - active players: win_streak, stamina, burnout, morale, morale_delta, form_history
#   - league: record_result, apply_season_result (on final week)
#   - synergy: record_match
# ---------------------------------------------------------------------------
static func apply_post_match_effects(
	active: Array[Player],
	roster: Array[Player],
	won: bool,
	ctx: MatchContext,
	league: LeagueManager,
	synergy: Synergy
) -> void:
	_update_streaks(active, won)
	_apply_match_stamina_cost(active, ctx.is_important)
	_apply_morale(active, won, ctx.match_type, ctx.is_important)

	league.record_result(won)
	if ctx.week_in_season == Calendar.WEEKS_PER_SEASON:
		league.apply_season_result(roster)

	if synergy != null:
		synergy.record_match(active)


# ---------------------------------------------------------------------------
# PHASE 5 — award_xp
#
# XP loop. For each entry in the player_results array (from simulate_match),
# award match XP and collect any level-ups. Mutates each entry in-place to
# add xp_gained / level / xp_progress fields (preserves legacy dict shape
# for ResolutionScreen).
#
# MUTATES:
#   - active players' xp, level (via LevelSystem)
#   - player_results entries (added xp_gained / level / xp_progress fields)
#
# Returns: Array of level-up event dicts (concatenated across all players).
# ---------------------------------------------------------------------------
static func award_xp(
	player_results: Array,
	match_type: String,
	won: bool
) -> Array:
	var level_ups: Array = []
	for entry in player_results:
		var p: Player = entry["player"]
		p.last_score  = entry["score"]
		var lu: Array = LevelSystem.award_match_xp_with_result(
			p, entry["label"], match_type, won
		)
		level_ups.append_array(lu)
		entry["xp_gained"]   = p.xp_delta
		entry["level"]       = p.level
		entry["xp_progress"] = LevelSystem.level_progress(p)
	return level_ups


# ---------------------------------------------------------------------------
# PHASE 6 — check_goals
#
# Updates the season goal manager (which tracks wins/losses/tournaments
# against the current season's goal) and checks whether a quarter
# boundary has been crossed (which may trigger a quarter bonus that
# applies to active players).
#
# MUTATES:
#   - goal_manager (on_match_result, check_quarter_boundary, consume_quarter_bonus)
#   - active players' morale + xp if a quarter bonus was triggered
#
# Returns: quarter_bonus description string ("" if no bonus this week).
# ---------------------------------------------------------------------------
static func check_goals(
	goal_manager: SeasonGoalManager,
	active: Array[Player],
	week_in_season: int,
	won: bool,
	is_tournament: bool
) -> String:
	goal_manager.on_match_result(won, is_tournament, active, week_in_season)
	goal_manager.check_quarter_boundary(week_in_season)
	if goal_manager.quarter_bonus_pending:
		var desc: String = goal_manager.quarter_bonus_description
		goal_manager.consume_quarter_bonus(active)
		return desc
	return ""


# ---------------------------------------------------------------------------
# PHASE 7 — rotate_systems_if_season_end
#
# Detects whether this was the final week of a season. The actual reset
# work — instantiating new SeasonGoalManager / resetting market / resetting
# league — is done by GameDirector, because it owns those references and
# rebinding them from a static method requires a complicated passthrough.
#
# This phase exists so the orchestrator has a single named pure function
# to ask "did a season just end?" rather than inlining the comparison.
#
# Returns: Dictionary {
#   "season_ended":      bool — true if this week was WEEKS_PER_SEASON
#   "next_season_index": int  — value to pass to league.reset_for_season
# }
# ---------------------------------------------------------------------------
static func rotate_systems_if_season_end(
	week_in_season: int,
	current_season: int
) -> Dictionary:
	if week_in_season == Calendar.WEEKS_PER_SEASON:
		return {
			"season_ended":      true,
			"next_season_index": current_season + 1,
		}
	return {
		"season_ended":      false,
		"next_season_index": current_season,
	}




# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# (lifted verbatim from the legacy GameManager — same logic, same constants)
# ---------------------------------------------------------------------------

static func _update_streaks(active: Array[Player], won: bool) -> void:
	for p in active:
		if won:
			p.win_streak += 1
		else:
			p.win_streak = 0


static func _apply_match_stamina_cost(active: Array[Player], is_important: bool) -> void:
	var cost: int = Balance.match_balance.stamina_cost_important if is_important else Balance.match_balance.stamina_cost_normal
	for p in active:
		p.stamina = max(p.stamina - cost, 0)
		p.burnout = min(p.burnout + 1, 5)


static func _apply_morale(
	active: Array[Player],
	won: bool,
	match_type: String,
	is_important: bool
) -> void:
	for p in active:
		var delta: int = 0
		if won:
			delta = Balance.match_balance.morale_win_important if is_important else Balance.match_balance.morale_win_normal
			if p.primary_trait == "clutch" and is_important:
				delta += Balance.match_balance.morale_clutch_bonus
		else:
			delta = Balance.match_balance.morale_loss_important if is_important else Balance.match_balance.morale_loss_normal
		p.morale       = clamp(p.morale + delta, 0, 100)
		p.morale_delta = delta
		p.form_history.append(GameText.PERF_LABELS[1])  # updated properly in XP loop


static func _apply_with_dr(current: int, gain: int, soft_cap: int, dr_factor: float) -> int:
	# Hard ceiling at 100 — stamina and morale are both 0..100 ranges.
	# Below soft_cap (default 80): full gain, capped at soft_cap.
	# At/above soft_cap: diminishing returns, but never exceed 100.
	if current >= soft_cap:
		return min(int(current + gain * dr_factor), 100)
	return min(current + gain, soft_cap)
