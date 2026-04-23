# scripts/managers/MatchDispatcher.gd
# Runs all match variants and returns a typed MatchResult.
# Extracted from GameManager — single responsibility: match execution.
# No UI references. No goal tracking. No streak management.
class_name MatchDispatcher
extends RefCounted


# Entry point. Called by GameManager.advance_week().
# Returns a fully populated MatchResult.
static func run(
	match_type: String,
	players: Array[Player],
	week: int,
	season: int,
	team_win_streak: int,
	selected_solo_player: String,
	resting_players: Array[String]
) -> MatchResult:
	var cal_entry: Dictionary = Calendar.get_week(week)

	match match_type:
		Calendar.TYPE_SOLO:
			return _run_solo(players, cal_entry, week, season, team_win_streak, selected_solo_player)
		Calendar.TYPE_TOURNAMENT:
			return _run_tournament(players, cal_entry, week, season, team_win_streak, resting_players)
		_:
			return _run_standard(players, cal_entry, match_type, week, season, team_win_streak, resting_players)


# --- Standard match (normal / important) ---
static func _run_standard(
	players: Array[Player],
	cal_entry: Dictionary,
	match_type: String,
	week: int,
	season: int,
	team_win_streak: int,
	resting_players: Array[String]
) -> MatchResult:
	var is_important: bool  = match_type != Calendar.TYPE_NORMAL
	var opp: int            = cal_entry["opponent"] + randi_range(-10, 10)
	var sim: Dictionary     = Simulation.simulate_team(players, is_important, opp)

	var result := MatchResult.new()
	result.won            = sim["won"]
	result.team_score     = sim["team_score"]
	result.opponent_score = opp

	var level_ups: Array = []
	for entry: Dictionary in sim["players"]:
		var p: Player = entry["player"]
		p.last_score  = entry["score"]
		entry["rested"] = p.player_name in resting_players
		var lu: Array = LevelSystem.award_match_xp_with_result(p, entry["label"], match_type, result.won)
		level_ups.append_array(lu)
		entry["xp_gained"]   = p.xp_delta
		entry["level"]       = p.level
		entry["xp_progress"] = LevelSystem.level_progress(p)
	result.players = sim["players"]

	_apply_morale(players, result.won, match_type)
	_update_form(result.players)
	return _finalise(result, match_type, cal_entry["label"], week, season, team_win_streak, level_ups)


# --- Solo match ---
static func _run_solo(
	players: Array[Player],
	cal_entry: Dictionary,
	week: int,
	season: int,
	team_win_streak: int,
	selected_solo_player: String
) -> MatchResult:
	var base_opp: int   = int(cal_entry["opponent"] * 0.65)
	var opp: int        = base_opp + randi_range(-8, 8)

	var solo: Player = _find_player(players, selected_solo_player)
	if solo == null:
		solo = players[0]

	var solo_sim: Dictionary = Simulation.simulate_player(solo, true)
	var solo_score: int      = solo_sim["score"]
	var flavor_data          = MatchFlavorGenerator.generate(solo, solo_score, true, solo_sim["trait_label"])
	var won: bool            = solo_score >= opp
	var solo_flavor: String  = GameText.pick(GameText.SOLO_WIN_FLAVOR if won else GameText.SOLO_LOSS_FLAVOR)

	var solo_entry: Dictionary = {
		"player":        solo,
		"score":         solo_score,
		"label":         flavor_data["label"],
		"flavor":        solo_flavor,
		"trait_trigger": flavor_data["trait_trigger"],
		"breakdown":     solo_sim["breakdown"],
		"rested":        false,
	}
	var lu: Array = LevelSystem.award_match_xp_with_result(solo, flavor_data["label"], "important", won)
	solo_entry["xp_gained"]   = solo.xp_delta
	solo_entry["level"]       = solo.level
	solo_entry["xp_progress"] = LevelSystem.level_progress(solo)

	# Morale only for the solo player.
	var morale_change: int = 5 if won else -10
	solo.morale       = clamp(solo.morale + morale_change, 0, 100)
	solo.morale_delta = morale_change

	var all_entries: Array = []
	for p: Player in players:
		if p == solo:
			all_entries.append(solo_entry)
			p.form_history.append(flavor_data["label"])
			if p.form_history.size() > 3:
				p.form_history.pop_front()
		else:
			all_entries.append({ "player": p, "score": 0, "label": "", "flavor": "", "rested": true })

	var result := MatchResult.new()
	result.won            = won
	result.team_score     = solo_score
	result.opponent_score = opp
	result.players        = all_entries
	result.is_solo        = true
	result.mvp_name       = solo.player_name
	result.worst_name     = ""

	return _finalise(result, Calendar.TYPE_SOLO, cal_entry["label"], week, season, team_win_streak, lu)


# --- Tournament match ---
static func _run_tournament(
	players: Array[Player],
	cal_entry: Dictionary,
	week: int,
	season: int,
	team_win_streak: int,
	resting_players: Array[String]
) -> MatchResult:
	const ROUNDS:           int   = 3
	const STAMINA_RECOVERY: int   = 5
	const OPP_SCALE: Array        = [1.0, 1.10, 1.20]

	var base_opp: int        = cal_entry["opponent"]
	var all_level_ups: Array = []
	var rounds_won: int      = 0
	var round_results: Array = []
	var lost_in_round: int   = -1

	for round_idx in ROUNDS:
		var opp: int = int(base_opp * OPP_SCALE[round_idx]) + randi_range(-12, 12)
		var sim: Dictionary = Simulation.simulate_team(players, true, opp)
		var round_won: bool = sim["won"]
		round_results.append({
			"round": round_idx + 1, "won": round_won,
			"team_score": sim["team_score"], "opponent_score": opp,
			"players": sim["players"],
		})
		if round_won:
			rounds_won += 1
		else:
			lost_in_round = round_idx + 1
			break
		if round_idx < ROUNDS - 1:
			for p: Player in players:
				p.stamina = min(p.stamina + STAMINA_RECOVERY, 100)

	var overall_won: bool       = lost_in_round == -1
	var final_round: Dictionary = round_results[-1]

	var level_ups: Array = []
	for entry: Dictionary in final_round["players"]:
		var p: Player = entry["player"]
		p.last_score  = entry["score"]
		entry["rested"] = p.player_name in resting_players
		var lu: Array = LevelSystem.award_match_xp_with_result(p, entry["label"], Calendar.TYPE_TOURNAMENT, overall_won)
		level_ups.append_array(lu)
		all_level_ups.append_array(lu)
		entry["xp_gained"]   = p.xp_delta
		entry["level"]       = p.level
		entry["xp_progress"] = LevelSystem.level_progress(p)

	_apply_morale(players, overall_won, Calendar.TYPE_TOURNAMENT)
	_update_form(final_round["players"])

	var result := MatchResult.new()
	result.won             = overall_won
	result.team_score      = final_round["team_score"]
	result.opponent_score  = final_round["opponent_score"]
	result.players         = final_round["players"]
	result.is_tournament   = true
	result.rounds_won      = rounds_won
	result.rounds_total    = ROUNDS if overall_won else lost_in_round
	result.lost_in_round   = lost_in_round
	result.tournament_rounds = round_results
	result.round_summary   = _tournament_summary(overall_won, rounds_won, ROUNDS, lost_in_round)

	return _finalise(result, Calendar.TYPE_TOURNAMENT, cal_entry["label"], week, season, team_win_streak, all_level_ups)


# --- Shared finalisation ---
static func _finalise(
	result: MatchResult,
	match_type: String,
	opp_label: String,
	week: int,
	season: int,
	team_win_streak: int,
	level_ups: Array
) -> MatchResult:
	result.match_type   = match_type
	result.type_label   = GameText.MATCH_TYPE[match_type]
	result.is_important = match_type != Calendar.TYPE_NORMAL and match_type != Calendar.TYPE_SOLO
	result.week         = Calendar.get_week_in_season(week)
	result.season       = season
	result.opp_strength = opp_label
	result.streak       = team_win_streak
	result.game_over    = Calendar.is_game_over(week + 1)
	result.level_ups    = level_ups

	if not result.is_solo:
		var sorted: Array = result.players.duplicate()
		sorted.sort_custom(func(a, b): return a["score"] > b["score"])
		var active: Array = sorted.filter(func(e): return not e.get("rested", false))
		result.mvp_name   = active[0]["player"].player_name if active.size() > 0 else ""
		result.worst_name = active[-1]["player"].player_name if active.size() > 1 else ""

	# Build defeat hint from worst performer's breakdown.
	if not result.won and result.worst_name != "":
		var worst_entry: Dictionary = {}
		for e: Dictionary in result.players:
			if e["player"].player_name == result.worst_name:
				worst_entry = e
				break
		if not worst_entry.is_empty():
			var breakdown: Array = worst_entry.get("breakdown", [])
			var worst_reason: String = ""
			var worst_delta: int = 0
			for item: Dictionary in breakdown:
				if item["delta"] < worst_delta:
					worst_delta  = item["delta"]
					worst_reason = item["reason"]
			if worst_reason != "":
				var p_name: String = result.worst_name
				var action_hint: String = "Rest" if "Tired" in worst_reason else "Scrim"
				result.defeat_hint = "%s suffered %s (%d pts). Consider: %s them next week." % [p_name, worst_reason.to_lower(), worst_delta, action_hint]

	return result


# --- Morale application ---
static func _apply_morale(players: Array[Player], won: bool, match_type: String) -> void:
	var gain: int = 8  if match_type == Calendar.TYPE_TOURNAMENT else 5
	var loss: int = -15 if match_type == Calendar.TYPE_TOURNAMENT else -10
	var delta: int = gain if won else loss
	for p: Player in players:
		var prev: int  = p.morale
		p.morale       = clamp(p.morale + delta, 0, 100)
		p.morale_delta = p.morale - prev


# --- Form history update ---
static func _update_form(player_entries: Array) -> void:
	for entry: Dictionary in player_entries:
		if not entry.get("rested", false):
			var p: Player = entry["player"]
			p.form_history.append(entry["label"])
			if p.form_history.size() > 3:
				p.form_history.pop_front()


# --- Win estimate ---
static func win_estimate(team_skill: int, opponent_base: int) -> String:
	var ratio: float = float(team_skill) / float(opponent_base * 3)
	if ratio >= 1.10:   return GameText.ESTIMATE_FAVORED
	elif ratio >= 0.90: return GameText.ESTIMATE_EVEN
	else:               return GameText.ESTIMATE_UNDERDOG


# --- Tournament summary string ---
static func _tournament_summary(won: bool, rounds_won: int, total: int, lost_in_round: int) -> String:
	if won:
		return GameText.TOURNAMENT_WIN_ALL if rounds_won == total else GameText.TOURNAMENT_WIN_CLOSE
	return GameText.TOURNAMENT_LOSS_ROUND % lost_in_round


# --- Utility ---
static func _find_player(players: Array[Player], name: String) -> Player:
	for p: Player in players:
		if p.player_name == name:
			return p
	return null
