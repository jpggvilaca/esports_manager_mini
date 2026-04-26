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
var team_win_streak: int     = 0

var goal_manager: SeasonGoalManager = null
var market:       PlayerMarket      = null

var season: int:
	get: return Calendar.get_season(week)
var week_in_season: int:
	get: return Calendar.get_week_in_season(week)


func _init() -> void:
	var apex  := Player.new("Apex",  50, 50, 65, 55, "clutch",    "resilient")
	var byte_ := Player.new("Byte",  43, 38, 60, 50, "grinder",   "none")
	var ghost := Player.new("Ghost", 38, 45, 62, 45, "volatile",  "fragile")
	var kira  := Player.new("Kira",  40, 52, 70, 60, "consistent","none")
	var rex   := Player.new("Rex",   35, 40, 75, 48, "lazy",      "none")
	apex.bio  = "Mechanical prodigy who thrives under pressure — drifts in routine weeks."
	byte_.bio = "Grinds harder than anyone. Slow to start, relentless by mid-season."
	ghost.bio = "Unpredictable and fragile. On a good day, unplayable. On a bad one, invisible."
	kira.bio  = "Steady and focused. Never the hero, never the disaster."
	rex.bio   = "Explosive when fresh. Fades fast if you overplay him."
	players   = [apex, byte_, ghost, kira, rex]
	# Default squad: first 3 active; grinder defaults to train on bench
	for i in players.size():
		players[i].is_active = i < SQUAD_SIZE
	byte_.bench_action = "train"  # Grinder default
	goal_manager = SeasonGoalManager.new()
	market       = PlayerMarket.new()


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
	var player_mt:        Array[String] = TraitMatchup.get_player_match_traits(active)
	var sm_score:         float         = TraitMatchup.calc_stamina_morale_score(active)
	var matchup_modifier: float         = TraitMatchup.calc_modifier(
		player_mt, opponent_traits, situations, sm_score
	)

	# Store matchup breakdown in week_result for ResolutionScreen
	week_result.opponent_traits  = opponent_traits
	week_result.situations       = situations
	week_result.player_match_traits = player_mt
	week_result.matchup_modifier = matchup_modifier

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
	week_result.opponent_score = base_opp_score  # show raw to player (not effective)
	week_result.player_results = match_sim["players"]

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
	goal_manager.on_match_result(week_result.to_match_result(), active, wis)
	goal_manager.check_quarter_boundary(wis)
	if goal_manager.quarter_bonus_pending:
		week_result.quarter_bonus = goal_manager.quarter_bonus_description
		goal_manager.consume_quarter_bonus(active)

	week += 1
	goal_manager.start_new_quarter(week_in_season)

	return week_result


# ---------------------------------------------------------------------------
# BENCH RESOLUTION
# ---------------------------------------------------------------------------
func _resolve_bench(player: Player) -> Dictionary:
	var prev_stamina: int = player.stamina

	if player.bench_action == "train":
		player.stamina = max(player.stamina - 5, 0)
		player.burnout = min(player.burnout + 1, 5)
		player.hunger  = min(player.hunger + 1, 5)
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
		var gain: int = 23 if player.primary_trait == "lazy" else 15
		player.stamina           = _apply_with_dr(player.stamina, gain, 80, 0.5)
		player.morale            = _apply_with_dr(player.morale,  5,   80, 0.5)
		player.burnout           = max(player.burnout - 2, 0)
		player.consecutive_rests += 1
		if player.consecutive_rests >= 3:
			player.hunger = max(player.hunger - 1, 0)
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
	var player_mt:        Array[String] = TraitMatchup.get_player_match_traits(active)
	var sm_score:         float         = TraitMatchup.calc_stamina_morale_score(active)
	var matchup_modifier: float         = TraitMatchup.calc_modifier(
		player_mt, opponent_traits, situations, sm_score
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
		"matchup_modifier":    matchup_modifier,
		"next_event":          next,
		"squad_valid":         squad_is_valid(),
		"game_over":           Calendar.is_game_over(week),
		"win_estimate":        _win_estimate(active, opp_score_raw, matchup_modifier),
	}


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

func _win_estimate(active: Array[Player], opp_score: int, matchup_modifier: float) -> String:
	var team_skill: int = 0
	for p in active:
		team_skill += p.skill
	var adjusted_opp: float = float(opp_score) - matchup_modifier
	var ratio: float = float(team_skill * 3) / adjusted_opp  # ×3 since 3 players
	if ratio >= 1.05:
		return GameText.ESTIMATE_FAVORED
	elif ratio >= 0.92:
		return GameText.ESTIMATE_EVEN
	else:
		return GameText.ESTIMATE_UNDERDOG


func _update_streaks(won: bool) -> void:
	if won:
		team_win_streak += 1
	else:
		team_win_streak = 0
	for p in active_players():
		if won:
			p.win_streak += 1
		else:
			p.win_streak = 0


func _apply_match_stamina_cost(active: Array[Player], is_important: bool) -> void:
	var cost: int = 18 if is_important else 13
	for p in active:
		p.stamina          = max(p.stamina - cost, 0)
		p.burnout          = min(p.burnout + 1, 5)
		p.consecutive_rests = 0
		p.debut_match      = false
		if p.primary_trait == "grinder":
			p.hunger = min(p.hunger + 1, 5)


func _apply_morale(active: Array[Player], won: bool, match_type: String) -> void:
	var is_important: bool = match_type in [
		Calendar.TYPE_IMPORTANT, Calendar.TYPE_TOURNAMENT
	]
	for p in active:
		var delta: int = 0
		if won:
			delta = 8 if is_important else 5
			if p.primary_trait == "clutch" and is_important:
				delta += 3
		else:
			delta = -8 if is_important else -5
			if p.primary_trait == "choker" and is_important:
				delta -= 4
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
