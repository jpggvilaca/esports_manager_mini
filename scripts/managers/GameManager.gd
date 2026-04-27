# scripts/managers/GameManager.gd
# ============================================================
# ORCHESTRATOR — owns the roster, week counter, and turn resolution.
#
# LOOP:
#   1. Player sees opponent traits + match situations on hub
#   2. Player picks 1–3 active players from the roster (set is_active)
#   3. Player presses "End Week"
#   4. advance_week() resolves: TraitMatchup modifier → Simulation → WeekResult
#   5. UI plays the resolution sequence
# ============================================================
class_name GameManager
extends RefCounted

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")

const SQUAD_SIZE: int = 3   # max active players per week

var players: Array[Player]  = []
var week:    int             = 1

var goal_manager: SeasonGoalManager = null
var market:       PlayerMarket      = null
var league:       LeagueManager     = null

# Banner shown on hub after the resolution screen closes.
# Set by advance_week() when a goal is achieved. Cleared when read by UI.
var pending_banner: String = ""

var season: int:
	get: return Calendar.get_season(week)
var week_in_season: int:
	get: return Calendar.get_week_in_season(week)


func _init() -> void:
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
	goal_manager = SeasonGoalManager.new()
	market       = PlayerMarket.new()
	league       = LeagueManager.new(1, "Your Team")


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


func squad_is_valid() -> bool:
	return active_players().size() >= 1  # at least 1 player needed


# Toggle a benched player's action between rest and train.
func toggle_bench_action(player_name: String) -> void:
	var p: Player = _find_player(player_name)
	if p == null or p.is_active:
		return
	p.bench_action = "train" if p.bench_action == "rest" else "rest"


# ---------------------------------------------------------------------------
# LEAGUE BRIDGE METHODS
# Thin wrappers so UI only talks to GameManager, never LeagueManager directly.
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
# Thin wrappers so UI only talks to GameManager, never PlayerMarket directly.
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
	return market.replace_player(players, candidate, replace_index)


# ---------------------------------------------------------------------------
# ADVANCE WEEK — resolves everything, returns a WeekResult.
# ---------------------------------------------------------------------------
func advance_week() -> WeekResult:
	var cal_entry:  Dictionary = Calendar.get_week(week)
	var match_type: String     = cal_entry["type"]
	var week_result := WeekResult.new()
	week_result.week       = week_in_season
	week_result.season     = season
	week_result.match_type = match_type

	var active:  Array[Player] = active_players()
	var benched: Array[Player] = benched_players()

	# --- League: simulate NPCs before player match ---
	league.simulate_npc_week(week_in_season)

	# --- Apply bench outcomes (passive rest/train) ---
	for p in benched:
		var bench_outcome: Dictionary = _resolve_bench(p)
		week_result.bench_results.append(bench_outcome)

	# --- Trait Matchup modifier ---
	# Generate opponent traits + situations here (not in Calendar, to avoid dependency issues).
	var opponent_traits:  Array[String] = TraitMatchup.generate_opponent_traits(
		season, week_in_season, cal_entry["label"]
	)
	var situations:       Array[String] = TraitMatchup.generate_situations(
		season, week_in_season, match_type
	)
	var player_mt:        Array[String] = TraitMatchup.get_team_traits(active)
	var matchup_modifier: int           = TraitMatchup.calculate_matchup_modifier(
		player_mt, opponent_traits, situations
	)

	# Store matchup breakdown in week_result for ResolutionScreen
	week_result.opponent_traits     = opponent_traits
	week_result.situations          = situations
	week_result.player_match_traits = player_mt
	week_result.matchup_modifier    = float(matchup_modifier)

	# --- Run match ---
	# Modifier adjusts the opponent score: positive modifier = player advantage
	var is_important: bool = match_type in [
		Calendar.TYPE_IMPORTANT, Calendar.TYPE_TOURNAMENT
	]
	var base_opp_score: int = cal_entry["opponent"] + randi_range(-10, 10)
	# Apply modifier: subtract from threshold (positive mod helps player)
	var effective_opp_score: int = int(base_opp_score - matchup_modifier)
	var match_sim: Dictionary = Simulation.simulate_team(active, is_important, effective_opp_score)

	week_result.won            = match_sim["won"]
	week_result.team_score     = match_sim["team_score"]
	week_result.opponent_score = effective_opp_score  # show effective (what was actually beaten)
	week_result.player_results = match_sim["players"]

	# --- League: record player result ---
	league.record_result(week_result.won)
	week_result.league_rank = league.player_rank()
	if week_in_season == Calendar.WEEKS_PER_SEASON:
		league.apply_season_result(players)

	# --- Post-match stat updates ---
	_update_streaks(week_result.won)
	_apply_match_stamina_cost(active, is_important)
	_apply_morale(active, week_result.won, match_type)

	# --- XP ---
	var level_ups: Array = []
	for entry in week_result.player_results:
		var p: Player = entry["player"]
		p.last_score  = entry["score"]
		var lu: Array = LevelSystem.award_match_xp_with_result(
			p, entry["label"], match_type, week_result.won
		)
		level_ups.append_array(lu)
		entry["xp_gained"]   = p.xp_delta
		entry["level"]       = p.level
		entry["xp_progress"] = LevelSystem.level_progress(p)
	week_result.level_ups = level_ups

	# --- Goals ---
	var wis: int = week_in_season
	goal_manager.on_match_result(week_result.won, match_type == Calendar.TYPE_TOURNAMENT, active, wis)
	goal_manager.check_quarter_boundary(wis)
	if goal_manager.quarter_bonus_pending:
		week_result.quarter_bonus = goal_manager.quarter_bonus_description
		goal_manager.consume_quarter_bonus(active)

	# --- New season reset — must run BEFORE week += 1, while week_in_season still equals WEEKS_PER_SEASON ---
	if week_in_season == Calendar.WEEKS_PER_SEASON:
		goal_manager = SeasonGoalManager.new()
		market.reset_for_new_season()
		league.reset_for_season(season + 1, "Your Team")

	week += 1
	goal_manager.start_new_quarter(week_in_season)

	# --- Set pending banner if a goal just completed ---
	pending_banner = ""
	var sg: Dictionary = goal_manager.get_display()
	var qg: Dictionary = goal_manager.get_quarter_display()
	if week_result.quarter_bonus != "":
		pending_banner = "🌟 " + week_result.quarter_bonus
	elif sg.get("achieved", false):
		pending_banner = "🏆 Season goal complete! " + sg.get("description", "")

	return week_result


# ---------------------------------------------------------------------------
# BENCH RESOLUTION
# ---------------------------------------------------------------------------
func _resolve_bench(player: Player) -> Dictionary:
	var prev_stamina: int = player.stamina

	if player.bench_action == "train":
		player.stamina = max(player.stamina - Tuning.BENCH_TRAIN_STAMINA_COST, 0)
		player.burnout = min(player.burnout + 1, 5)
		var lu: Array = LevelSystem.award_action_xp(player, "train")
		return {
			"player":       player,
			"action":       "train",
			"stamina_gain": player.stamina - prev_stamina,
			"xp_gained":    player.xp_delta,
			"level_ups":    lu,
			"narrative":    player.player_name + " trained on the bench. The grind never stops.",
		}
	else:
		var gain: int = Tuning.BENCH_REST_STAMINA_AGGRESSIVE if player.primary_trait == "aggressive" else Tuning.BENCH_REST_STAMINA
		player.stamina           = _apply_with_dr(player.stamina, gain, 80, 0.5)
		player.morale            = _apply_with_dr(player.morale,  Tuning.BENCH_REST_MORALE, 80, 0.5)
		player.burnout           = max(player.burnout - 2, 0)
		return {
			"player":       player,
			"action":       "rest",
			"stamina_gain": player.stamina - prev_stamina,
			"xp_gained":    0,
			"level_ups":    [],
			"narrative":    player.player_name + " rested this week. Stamina recovered.",
		}


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
		"win_estimate":        _win_estimate(active, opp_score_raw, matchup_modifier),
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

func _win_estimate(active: Array[Player], opp_score: int, matchup_modifier: int) -> String:
	var team_skill: int = 0
	for p in active:
		team_skill += p.skill
	var adjusted_opp: float = float(opp_score - matchup_modifier)
	var ratio: float = float(team_skill * 3) / adjusted_opp  # ×3 since 3 players
	if ratio >= 1.05:
		return GameText.ESTIMATE_FAVORED
	elif ratio >= 0.92:
		return GameText.ESTIMATE_EVEN
	else:
		return GameText.ESTIMATE_UNDERDOG


func _update_streaks(won: bool) -> void:
	for p in active_players():
		if won:
			p.win_streak += 1
		else:
			p.win_streak = 0


func _apply_match_stamina_cost(active: Array[Player], is_important: bool) -> void:
	var cost: int = Tuning.STAMINA_COST_IMPORTANT if is_important else Tuning.STAMINA_COST_NORMAL
	for p in active:
		p.stamina          = max(p.stamina - cost, 0)
		p.burnout          = min(p.burnout + 1, 5)


func _apply_morale(active: Array[Player], won: bool, match_type: String) -> void:
	var is_important: bool = match_type in [
		Calendar.TYPE_IMPORTANT, Calendar.TYPE_TOURNAMENT
	]
	for p in active:
		var delta: int = 0
		if won:
			delta = Tuning.MORALE_WIN_IMPORTANT if is_important else Tuning.MORALE_WIN_NORMAL
			if p.primary_trait == "clutch" and is_important:
				delta += Tuning.MORALE_CLUTCH_BONUS
		else:
			delta = Tuning.MORALE_LOSS_IMPORTANT if is_important else Tuning.MORALE_LOSS_NORMAL
			# volatile players have no extra morale penalty — unpredictability cuts both ways
		p.morale       = clamp(p.morale + delta, 0, 100)
		p.morale_delta = delta
		p.form_history.append(GameText.PERF_LABELS[1])  # updated properly in XP loop


func _apply_with_dr(current: int, gain: int, soft_cap: int, dr_factor: float) -> int:
	if current >= soft_cap:
		return int(current + gain * dr_factor)
	return min(current + gain, soft_cap)


func _find_player(player_name: String) -> Player:
	for p in players:
		if p.player_name == player_name:
			return p
	return null
