# systems/game_director.gd
# ============================================================
# GAME DIRECTOR — long-lived state ownership and turn orchestration.
#
# Registered as autoload `GameDirector` (see project.godot).
# Replaces the legacy `GameManager` RefCounted class — same responsibilities,
# but accessible as a global singleton instead of a per-screen instance.
#
# LOOP:
#   1. Player sees opponent traits + match situations + active patch on hub
#   2. Player picks 1–3 active players from the roster (set is_active)
#   3. Player decides what each benched player does: rest / train / study
#   4. Player presses "End Week"
#   5. advance_week() runs the WeekResolver pipeline and returns a WeekResult
#   6. UI plays the resolution sequence
#
# ACCESS PATTERN:
#   UI scripts read from `GameDirector` directly:
#     var ctx: Dictionary = GameDirector.get_week_context()
#     GameDirector.toggle_bench_action(player_name)
#   No instance variable, no .new() — it's the singleton.
#
# REFACTOR NOTE (Phase B2):
#   advance_week() is now a thin orchestrator that calls seven
#   WeekResolver static phases and emits one SignalHub signal per
#   phase. The 120-line god-method is gone; phase logic lives in
#   `scripts/systems/WeekResolver.gd`.
#
#   pending_banner was removed in B3. Banner events now fire as
#   SignalHub signals (goal_achieved, quarter_bonus_triggered,
#   patch_rotated, season_ended) — GameWorld listens in _ready().
# ============================================================
extends Node

const TraitMatchup  := preload("res://scripts/systems/TraitMatchup.gd")
const MetaPatch     := preload("res://scripts/systems/MetaPatch.gd")
const SynergyClass  := preload("res://scripts/systems/Synergy.gd")
const WeekResolverC := preload("res://scripts/systems/WeekResolver.gd")

const SQUAD_SIZE: int = 3   # max active players per week

# Cycle order for bench-action toggle: rest → train → study → rest …
const BENCH_ACTION_CYCLE: Array[String] = ["rest", "train", "study"]

var players: Array[Player]  = []
var week:    int             = 1

var goal_manager: SeasonGoalManager = null
var market:       PlayerMarket      = null
var league:       LeagueManager     = null
var synergy:      Synergy           = null

# B3: pending_banner removed. Banner events are now emitted as
# SignalHub signals (goal_achieved, quarter_bonus_triggered,
# patch_rotated, season_ended). GameWorld listens in _ready().

var season: int:
	get: return Calendar.get_season(week)
var week_in_season: int:
	get: return Calendar.get_week_in_season(week)


# ---------------------------------------------------------------------------
# AUTOLOAD LIFECYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	start_new_game()


# Resets all state to a fresh game. Called from _ready, and re-callable
# (the smoke test uses this to run multiple seasons from a clean slate).
func start_new_game() -> void:
	var apex  := Player.new("Apex",  50, 50, 65, 55, "clutch",    "resilient")
	var byte_ := Player.new("Byte",  43, 38, 60, 50, "resilient", "none")
	var ghost := Player.new("Ghost", 38, 45, 62, 45, "volatile",  "fragile")
	var kira  := Player.new("Kira",  40, 52, 70, 60, "focused",   "none")
	var rex   := Player.new("Rex",   35, 40, 75, 48, "aggressive","none")
	apex.bio  = "Mechanical prodigy who thrives under pressure — drifts in routine weeks."
	byte_.bio = "Endurance is everything. Holds form long after others fade."
	ghost.bio = "Unpredictable and fragile. On a good day, unplayable. On a bad one, invisible."
	kira.bio  = "Steady and precise. Bonus in big matches. Tight variance, no drama."
	rex.bio   = "Explosive when fresh. Fades fast if you overplay him."
	players   = [apex, byte_, ghost, kira, rex]
	# Default squad: first 3 active; resilient defaults to train on bench
	for i in players.size():
		players[i].is_active = i < SQUAD_SIZE
	byte_.bench_action = "train"  # Endurance player default

	week = 1

	goal_manager = SeasonGoalManager.new()
	market       = PlayerMarket.new()
	league       = LeagueManager.new(1, "Your Team")
	synergy      = SynergyClass.new()


# ---------------------------------------------------------------------------
# SQUAD MANAGEMENT
# ---------------------------------------------------------------------------

func active_players() -> Array[Player]:
	var result: Array[Player] = []
	for p in players:
		if p.is_active:
			result.append(p)
	return result


func benched_players() -> Array[Player]:
	var result: Array[Player] = []
	for p in players:
		if p.is_benched:
			result.append(p)
	return result


# Set a player active. If squad is already full, deactivates the last active player.
# NOTE: does NOT emit squad_changed — call sites that want the signal use toggle_active.
# RosterScreen._on_card_clicked calls set_active directly and emits after.
func set_active(player_name: String) -> void:
	var target: Player = _find_player(player_name)
	if target == null or target.is_active:
		return
	var active: Array[Player] = active_players()
	if active.size() >= SQUAD_SIZE:
		active[active.size() - 1].is_active = false
	target.is_active = true


# Toggle a player in/out of the squad.
func toggle_active(player_name: String) -> void:
	var target: Player = _find_player(player_name)
	if target == null:
		return
	if target.is_active:
		target.is_active = false
	else:
		set_active(player_name)
	SignalHub.squad_changed.emit(active_players(), benched_players())


func squad_is_valid() -> bool:
	return active_players().size() >= 1  # at least 1 player needed


# Cycle a benched player's action: rest → train → study → rest …
# B4: emits SignalHub.bench_action_changed after mutating.
func toggle_bench_action(player_name: String) -> void:
	var p: Player = _find_player(player_name)
	if p == null or p.is_active:
		return
	var idx: int = BENCH_ACTION_CYCLE.find(p.bench_action)
	if idx == -1:
		idx = 0
	var next_idx: int = (idx + 1) % BENCH_ACTION_CYCLE.size()
	p.bench_action = BENCH_ACTION_CYCLE[next_idx]
	SignalHub.bench_action_changed.emit(p, p.bench_action)


# ---------------------------------------------------------------------------
# LEAGUE BRIDGE METHODS
# Thin wrappers so UI only talks to GameDirector, never LeagueManager directly.
# ---------------------------------------------------------------------------

# Returns sorted standings for the hub panel.
# Each entry: { name, points, wins, losses, is_player, rank, tier }
func get_standings() -> Array[Dictionary]:
	return league.get_standings() if league != null else []

# Returns the player's current rank (1-indexed).
func league_rank() -> int:
	return league.player_rank() if league != null else 0

# Returns W–L string like "7–6".
func league_record() -> String:
	return league.player_record() if league != null else "0–0"


# ---------------------------------------------------------------------------
# MARKET BRIDGE METHODS
# Thin wrappers so UI only talks to GameDirector, never PlayerMarket directly.
# ---------------------------------------------------------------------------

# Open/refresh market — generates fresh candidates if none exist yet.
func open_market() -> void:
	if market == null:
		return
	market.generate_candidates(players)


# True if the player can still make a replacement this season.
func market_has_slots() -> bool:
	return market != null and market.has_slots()


# Slot display string like "●●○" for the market header.
func market_slots_display() -> String:
	return market.slots_display() if market != null else ""


# Attempt to hire a candidate into slot at index.
# Returns true on success, false if no slots remain or invalid index.
func hire_candidate(candidate: Player, replace_index: int) -> bool:
	if market == null:
		return false
	var ok: bool = market.replace_player(players, candidate, replace_index)
	if ok and synergy != null:
		# Drop synergy entries for the player who was replaced.
		synergy.clean_for_roster(players)
	return ok


# ---------------------------------------------------------------------------
# ADVANCE WEEK — thin orchestrator over the WeekResolver pipeline.
#
# Each phase is a single static call into WeekResolver, followed by a
# SignalHub emission so listeners (UI animations, audio cues, debug
# overlays, smoke-test invariant checks) can hook in without coupling to
# the resolver itself.
#
# Pipeline phases (see WeekResolver.gd for full design notes):
#   1. resolve_bench
#   2. generate_match_context
#   3. simulate_match
#   4. apply_post_match_effects
#   5. award_xp
#   6. check_goals
#   7. rotate_systems_if_season_end
#
# After phase 7 the orchestrator increments `week`, kicks the goal
# manager into the next quarter, and emits reactive banner signals. The
# week_advanced and match_resolved signals fire at the very end, after
# all phases have completed and state is stable.
# ---------------------------------------------------------------------------
func advance_week() -> WeekResult:
	var week_result := WeekResult.new()
	week_result.week       = week_in_season
	week_result.season     = season

	var active:  Array[Player] = active_players()
	var benched: Array[Player] = benched_players()

	# League NPCs simulate first — kept inline because it's a single one-line
	# call into LeagueManager, not a "phase" in its own right.
	league.simulate_npc_week(week_in_season)

	# --- Phase 1: bench resolution -----------------------------------------
	var bench_outcomes: Array = WeekResolverC.resolve_bench(benched)
	week_result.bench_results = bench_outcomes
	SignalHub.bench_resolved.emit(bench_outcomes)

	# --- Phase 2: match context generation ---------------------------------
	var ctx: MatchContext = WeekResolverC.generate_match_context(
		week, week_in_season, season, active
	)
	week_result.match_type           = ctx.match_type
	week_result.opponent_traits      = ctx.opponent_traits
	week_result.situations           = ctx.situations
	week_result.player_match_traits  = ctx.player_match_traits
	week_result.matchup_modifier     = float(ctx.matchup_modifier)
	week_result.patch_buffed         = ctx.patch.get("buffed", "")
	week_result.patch_nerfed         = ctx.patch.get("nerfed", "")
	SignalHub.match_context_generated.emit(ctx)

	# --- Phase 3: match simulation -----------------------------------------
	var match_sim: Dictionary = WeekResolverC.simulate_match(active, ctx, synergy)
	week_result.won                  = match_sim["won"]
	week_result.team_score           = match_sim["team_score"]
	week_result.opponent_score       = match_sim["opponent_score"]
	week_result.player_results       = match_sim["players"]
	week_result.counter_ratio        = match_sim["counter_ratio"]
	week_result.counter_mult         = match_sim["counter_mult"]
	week_result.coverage_hits        = match_sim["coverage_hits"]
	week_result.coverage_mult        = match_sim["coverage_mult"]
	week_result.synergy_bonus_total  = match_sim["synergy_bonus_total"]
	week_result.synergy_per_player   = match_sim["synergy_per_player"]
	week_result.synergized_pairs     = synergy.synergized_pairs_in(active) if synergy != null else []
	week_result.study_used_by_player = match_sim["pre_study"]
	SignalHub.match_simulated.emit(match_sim)

	# --- Phase 4: post-match effects ---------------------------------------
	WeekResolverC.apply_post_match_effects(
		active, players, week_result.won, ctx, league, synergy
	)
	week_result.league_rank = league.player_rank()
	SignalHub.post_match_applied.emit(week_result)

	# --- Phase 5: XP ------------------------------------------------------
	var level_ups: Array = WeekResolverC.award_xp(
		week_result.player_results, ctx.match_type, week_result.won
	)
	week_result.level_ups = level_ups
	SignalHub.xp_awarded.emit(level_ups)

	# --- Phase 6: goals ---------------------------------------------------
	var quarter_bonus: String = WeekResolverC.check_goals(
		goal_manager, active, week_in_season, week_result.won,
		ctx.match_type == Calendar.TYPE_TOURNAMENT
	)
	week_result.quarter_bonus = quarter_bonus
	SignalHub.goals_checked.emit(week_result)

	# --- Phase 7: season rotation -----------------------------------------
	# The resolver tells us IF a rotation should happen; the actual rebinding
	# of goal_manager / market / league lives here because they're owned by
	# this autoload. (Static methods can't rebind their callers' references.)
	var rotation: Dictionary = WeekResolverC.rotate_systems_if_season_end(
		week_in_season, season
	)
	if rotation["season_ended"]:
		# Capture rank before the reset so the season_ended signal has it.
		var final_rank: int = league.player_rank()
		goal_manager = SeasonGoalManager.new()
		market.reset_for_new_season()
		league.reset_for_season(rotation["next_season_index"], "Your Team")
		var rank_desc: String = "Rank %d / 8" % final_rank
		SignalHub.season_ended.emit(final_rank, rank_desc)

	week += 1
	goal_manager.start_new_quarter(week_in_season)
	SignalHub.season_rotated.emit(week)

	# --- B3: Reactive banner signals ---------------------------------------
	# Priority: quarter bonus > season goal > new patch > season end.
	# Each emits its own SignalHub signal; GameWorld connects in _ready().
	if quarter_bonus != "":
		SignalHub.quarter_bonus_triggered.emit(quarter_bonus)
	else:
		var sg: Dictionary = goal_manager.get_display()
		if sg.get("achieved", false):
			SignalHub.goal_achieved.emit(sg.get("description", ""))
	if MetaPatch.is_patch_week_one(week) and not Calendar.is_game_over(week):
		var np: Dictionary = MetaPatch.get_patch(week)
		SignalHub.patch_rotated.emit(np.get("buffed", ""), np.get("nerfed", ""))

	# --- Final lifecycle signals ------------------------------------------
	SignalHub.week_advanced.emit(week_result)
	SignalHub.match_resolved.emit(week_result)

	return week_result

# ---------------------------------------------------------------------------
# CONTEXT — everything the hub screen needs.
# Generates opponent name/traits/situations via TraitMatchup + Calendar.
# ---------------------------------------------------------------------------
func get_week_context() -> Dictionary:
	var entry:  Dictionary = Calendar.get_week(week)
	var mtype:  String     = entry["type"]
	var next:   Dictionary = Calendar.get_next_event(week)

	# Generate opponent name, traits, situations
	var opp_name:        String        = Calendar.get_opponent_name(season, week_in_season, entry["label"])
	var opponent_traits: Array[String] = TraitMatchup.generate_opponent_traits(season, week_in_season, entry["label"])
	var situations:      Array[String] = TraitMatchup.generate_situations(season, week_in_season, mtype)

	# Matchup hint — preview how current squad counters the opponent
	var active:           Array[Player] = active_players()
	var player_mt:        Array[String] = TraitMatchup.get_team_traits(active)
	var matchup_modifier: int           = TraitMatchup.calculate_matchup_modifier(
		player_mt, opponent_traits, situations
	)

	var opp_score_raw: int = entry["opponent"]

	return {
		"week":                week_in_season,
		"season":              season,
		"absolute_week":       week,
		"match_type":          mtype,
		"difficulty":          GameText.DIFFICULTY.get(entry["label"], entry["label"]),
		"opponent_name":       opp_name,
		"opponent_traits":     opponent_traits,
		"situations":          situations,
		"player_match_traits": player_mt,
		"matchup_modifier":    float(matchup_modifier),
		"next_event":          next,
		"squad_valid":         squad_is_valid(),
		"game_over":           Calendar.is_game_over(week),
		"win_estimate":        _win_estimate(active, opp_score_raw, opponent_traits, situations),
		"patch":               MetaPatch.get_patch(week),
		"next_patch":          MetaPatch.next_patch(week),
		"synergized_pairs":    synergy.synergized_pairs_in(active) if synergy != null else [],
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

# Win estimate now reflects the multiplicative counter pressure model.
# We compute the team's expected score under the counter ratio + patch +
# synergy effects and compare to the raw opponent threshold.
#
# NOTE: stays here (not in WeekResolver) because this is a PRE-match
# preview — the user reads it on the hub before deciding to advance the
# week. WeekResolver only knows about resolution-time logic.
func _win_estimate(
	active: Array[Player],
	opp_score: int,
	opponent_traits: Array,
	situations: Array
) -> String:
	if active.is_empty():
		return GameText.ESTIMATE_UNDERDOG

	# Raw expected team score (skill × patch × stamina-ish discount).
	var raw_expected: float = 0.0
	for p in active:
		var stamina_factor: float = clampf(float(p.stamina) / 100.0, 0.6, 1.0)
		var patch_mult: float = MetaPatch.multiplier_for(p.primary_trait, week)
		raw_expected += float(p.skill) * stamina_factor * patch_mult

	# Counter pressure multiplier.
	var per_player_study: Dictionary = {}
	for p in active:
		per_player_study[p.player_name] = p.study_charges
	var counter_data: Dictionary = _preview_counter_ratio(active, opponent_traits, per_player_study)
	var counter_mult: float = 1.0
	var ratio: float = counter_data["ratio"]
	if ratio >= 0.0:
		counter_mult = 1.0 + Balance.match_balance.counter_bonus_max * ratio
	else:
		counter_mult = 1.0 + Balance.match_balance.counter_penalty_max * ratio

	# Coverage bonus.
	var team_traits: Dictionary = {}
	for p in active: team_traits[p.primary_trait] = true
	var coverage_hits: int = 0
	for sit in situations:
		var fav: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
		if fav != "" and team_traits.has(fav):
			coverage_hits += 1
	var coverage_mult: float = 1.0 + Balance.match_balance.situation_coverage_bonus_per_hit * float(coverage_hits)

	# Synergy estimate.
	var synergy_bonus: int = 0
	if synergy != null:
		var per_player: Dictionary = synergy.score_bonus_per_player(active)
		for n in per_player.keys():
			synergy_bonus += per_player[n]

	var expected_score: float = raw_expected * counter_mult * coverage_mult + float(synergy_bonus)
	var ratio_vs_opp: float = expected_score / float(max(opp_score, 1))

	if ratio_vs_opp >= 1.05:
		return GameText.ESTIMATE_FAVORED
	elif ratio_vs_opp >= 0.92:
		return GameText.ESTIMATE_EVEN
	else:
		return GameText.ESTIMATE_UNDERDOG


# Preview-only — mirrors Simulation._calc_counter_ratio for win-estimate use.
# Kept here (not on Simulation) to avoid invoking randi() during preview.
func _preview_counter_ratio(
	active: Array,
	opponent_traits: Array,
	per_player_study: Dictionary
) -> Dictionary:
	if opponent_traits.is_empty() or active.is_empty():
		return { "ratio": 0.0 }
	var weighted_sum: float = 0.0
	var total_weight: float = 0.0
	for p in active:
		var pt: String = p.primary_trait
		var contribution: int = 0
		for ot in opponent_traits:
			if TraitMatchup.WINS_AGAINST.has(pt) and ot in TraitMatchup.WINS_AGAINST[pt]:
				contribution += 1
			elif TraitMatchup.LOSES_AGAINST.has(pt) and ot in TraitMatchup.LOSES_AGAINST[pt]:
				contribution -= 1
		var per_player_ratio: float = clampf(
			float(contribution) / float(opponent_traits.size()), -1.0, 1.0
		)
		var study: int = per_player_study.get(p.player_name, 0)
		var weight: float = 1.0 + Balance.match_balance.study_counter_bonus_per_charge * float(study)
		weighted_sum += per_player_ratio * weight
		total_weight += weight
	if total_weight <= 0.0:
		return { "ratio": 0.0 }
	return { "ratio": clampf(weighted_sum / total_weight, -1.0, 1.0) }


func _find_player(player_name: String) -> Player:
	for p in players:
		if p.player_name == player_name:
			return p
	return null
