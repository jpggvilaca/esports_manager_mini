# scripts/managers/GameManager.gd
# Owns game state and flow. Calls Simulation. No UI references.
class_name GameManager
extends RefCounted

var players: Array[Player]       = []
var week: int                    = 1
var team_win_streak: int         = 0
var selected_solo_player: String = ""

var season: int:         get = _get_season
var week_in_season: int: get = _get_week_in_season

func _get_season() -> int:         return Calendar.get_season(week)
func _get_week_in_season() -> int: return Calendar.get_week_in_season(week)


func _init() -> void:
	players = [
		Player.new("Apex",  70, 80, 90, 75, "clutch",   "resilient"),
		Player.new("Byte",  60, 60, 80, 70, "grinder",  "none"),
		Player.new("Ghost", 55, 75, 85, 65, "volatile", "fragile"),
	]


func advance_week() -> Dictionary:
	var cal_entry: Dictionary = Calendar.get_week(week)
	var match_type: String    = cal_entry["type"]

	var resting_players: Array[String] = []
	for player: Player in players:
		if player.planned_action == "rest" or player.planned_action == "":
			resting_players.append(player.player_name)

	var has_active: bool = _team_has_active_action()
	apply_actions()

	var result: Dictionary = {}
	match match_type:
		Calendar.TYPE_SOLO:
			result = run_solo_match()
			_update_streaks(result["won"])
		Calendar.TYPE_TOURNAMENT:
			result = run_tournament_match(resting_players)
			_update_streaks(result["won"])
		_:
			if has_active:
				result = run_match(resting_players)
				_update_streaks(result["won"])
			else:
				result = { "has_match": false }

	week += 1
	return result


func get_prematch_context() -> Dictionary:
	var entry: Dictionary  = Calendar.get_week(week)
	var match_type: String = entry["type"]
	var cal_label: String  = entry["label"]

	var conditions: Array = []
	var has_tired:  bool  = false
	for player: Player in players:
		var stamina_key: String
		if player.stamina >= 70:   stamina_key = "fresh"
		elif player.stamina >= 45: stamina_key = "ok"
		elif player.stamina >= 25: stamina_key = "tired"
		else:                      stamina_key = "exhausted"

		if stamina_key == "tired" or stamina_key == "exhausted":
			has_tired = true

		var morale_key: String
		if player.morale >= 80:   morale_key = "confident"
		elif player.morale < 40:  morale_key = "shaky"
		else:                     morale_key = "neutral"

		conditions.append({
			"name":         player.player_name,
			"stamina_key":  stamina_key,
			"stamina_lbl":  GameText.STAMINA_CONDITION[stamina_key],
			"morale_key":   morale_key,
			"morale_lbl":   GameText.MORALE_CONDITION[morale_key],
			"morale_delta": player.morale_delta,
			"condition":    GameText.CONDITIONS.get(stamina_key, GameText.CONDITIONS["ready"]),
		})

	# Win estimate: fuzzy comparison of total team skill vs base opponent score.
	var team_skill: int = 0
	for p: Player in players:
		team_skill += p.skill
	var estimate: String = _win_estimate(team_skill, entry["opponent"])

	return {
		"week":          week_in_season,
		"season":        season,
		"match_type":    match_type,
		"type_label":    GameText.MATCH_TYPE[match_type],
		"is_important":  match_type == Calendar.TYPE_IMPORTANT or match_type == Calendar.TYPE_TOURNAMENT,
		"is_tournament": match_type == Calendar.TYPE_TOURNAMENT,
		"is_solo":       match_type == Calendar.TYPE_SOLO,
		"opp_strength":  GameText.OPPONENT_STRENGTH.get(cal_label, cal_label),
		"difficulty":    GameText.DIFFICULTY.get(cal_label, cal_label),
		"win_estimate":  estimate,
		"conditions":    conditions,
		"has_tired":     has_tired,
		"streak":        team_win_streak,
		"game_over":     Calendar.is_game_over(week),
		"player_names":  players.map(func(p): return p.player_name),
	}


func apply_actions() -> void:
	for player: Player in players:
		var prev_skill:   int = player.skill
		var prev_stamina: int = player.stamina
		var prev_morale:  int = player.morale
		player.xp_delta = 0

		match player.planned_action:
			"train":
				var skill_gain: int   = 3
				var stamina_cost: int = 10
				if player.primary_trait == "grinder":
					skill_gain   += 1
					stamina_cost += 3
				elif player.primary_trait == "lazy":
					skill_gain = max(skill_gain - 1, 1)
				player.skill   = min(player.skill + skill_gain, 100)
				player.stamina = max(player.stamina - stamina_cost, 0)
			"rest":
				var stamina_gain: int = 15
				if player.primary_trait == "lazy":
					stamina_gain += 8
				player.stamina = min(player.stamina + stamina_gain, 100)
				player.morale  = min(player.morale + 5, 100)
			"scrim":
				player.focus = min(player.focus + 4, 100)

		LevelSystem.award_action_xp(player, player.planned_action)
		player.skill_delta    = player.skill   - prev_skill
		player.stamina_delta  = player.stamina - prev_stamina
		player.morale_delta   = player.morale  - prev_morale
		player.planned_action = "rest"


# --- Standard match (normal / important) ---
func run_match(resting_players: Array[String]) -> Dictionary:
	var cal_entry: Dictionary = Calendar.get_week(week)
	var match_type: String    = cal_entry["type"]
	var is_important: bool    = match_type != Calendar.TYPE_NORMAL
	var opponent_score: int   = cal_entry["opponent"] + randi_range(-10, 10)
	var result: Dictionary    = Simulation.simulate_team(players, is_important, opponent_score)
	var won: bool             = result["won"]

	var level_ups: Array = []
	for player_entry: Dictionary in result["players"]:
		var p: Player = player_entry["player"]
		p.last_score  = player_entry["score"]
		player_entry["rested"] = p.player_name in resting_players
		var new_levels: Array = LevelSystem.award_match_xp_with_result(p, player_entry["label"], match_type, won)
		level_ups.append_array(new_levels)
		player_entry["xp_gained"]   = p.xp_delta
		player_entry["level"]       = p.level
		player_entry["xp_progress"] = LevelSystem.level_progress(p)

	_apply_match_morale(won, Calendar.TYPE_NORMAL)
	return _finalise_result(result, match_type, cal_entry["label"], level_ups)


# --- Solo match ---
func run_solo_match() -> Dictionary:
	var cal_entry: Dictionary = Calendar.get_week(week)
	var base_opp: int         = int(cal_entry["opponent"] * 0.65)
	var opponent_score: int   = base_opp + randi_range(-8, 8)

	var solo: Player = _find_player(selected_solo_player)
	if solo == null:
		solo = players[0]

	var solo_score: int = Simulation.simulate_player(solo, true)
	var flavor_data     = MatchFlavorGenerator.generate(solo, solo_score, true)
	var won: bool       = solo_score >= opponent_score

	var solo_flavor: String = GameText.pick(GameText.SOLO_WIN_FLAVOR if won else GameText.SOLO_LOSS_FLAVOR)

	var player_entry: Dictionary = {
		"player":  solo,
		"score":   solo_score,
		"label":   flavor_data["label"],
		"flavor":  solo_flavor,
		"rested":  false,
	}

	var all_entries: Array = []
	for p: Player in players:
		if p == solo:
			all_entries.append(player_entry)
		else:
			all_entries.append({ "player": p, "score": 0, "label": "", "flavor": "", "rested": true })

	var level_ups: Array = LevelSystem.award_match_xp_with_result(solo, flavor_data["label"], "important", won)
	player_entry["xp_gained"]   = solo.xp_delta
	player_entry["level"]       = solo.level
	player_entry["xp_progress"] = LevelSystem.level_progress(solo)

	# Only the solo player gets morale consequence.
	var morale_change: int = 5 if won else -10
	solo.morale       = clamp(solo.morale + morale_change, 0, 100)
	solo.morale_delta = morale_change

	var result: Dictionary = {
		"won":            won,
		"team_score":     solo_score,
		"opponent_score": opponent_score,
		"players":        all_entries,
	}
	result = _finalise_result(result, Calendar.TYPE_SOLO, cal_entry["label"], level_ups)
	result["is_solo"]    = true
	result["mvp_name"]   = solo.player_name
	result["worst_name"] = ""
	return result


# --- Tournament match: 3 rounds with escalating opponent ---
func run_tournament_match(resting_players: Array[String]) -> Dictionary:
	const ROUNDS:           int   = 3
	const STAMINA_RECOVERY: int   = 5
	const OPP_SCALE: Array        = [1.0, 1.10, 1.20]

	var cal_entry: Dictionary = Calendar.get_week(week)
	var base_opp: int         = cal_entry["opponent"]

	var all_level_ups: Array = []
	var rounds_won: int      = 0
	var round_results: Array = []
	var lost_in_round: int   = -1

	for round_idx in ROUNDS:
		var opp: int = int(base_opp * OPP_SCALE[round_idx]) + randi_range(-12, 12)
		var round_sim: Dictionary = Simulation.simulate_team(players, true, opp)
		var round_won: bool = round_sim["won"]
		round_results.append({
			"round": round_idx + 1,
			"won":   round_won,
			"team_score":     round_sim["team_score"],
			"opponent_score": opp,
			"players":        round_sim["players"],
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
	var result: Dictionary = {
		"won":            overall_won,
		"team_score":     final_round["team_score"],
		"opponent_score": final_round["opponent_score"],
		"players":        final_round["players"],
	}

	for player_entry: Dictionary in result["players"]:
		var p: Player = player_entry["player"]
		p.last_score  = player_entry["score"]
		player_entry["rested"] = p.player_name in resting_players
		var new_levels: Array = LevelSystem.award_match_xp_with_result(p, player_entry["label"], Calendar.TYPE_TOURNAMENT, overall_won)
		all_level_ups.append_array(new_levels)
		player_entry["xp_gained"]   = p.xp_delta
		player_entry["level"]       = p.level
		player_entry["xp_progress"] = LevelSystem.level_progress(p)

	# Tournament morale swings harder.
	_apply_match_morale(overall_won, Calendar.TYPE_TOURNAMENT)
	result = _finalise_result(result, Calendar.TYPE_TOURNAMENT, cal_entry["label"], all_level_ups)
	result["is_tournament"]     = true
	result["rounds_won"]        = rounds_won
	result["rounds_total"]      = ROUNDS if overall_won else lost_in_round
	result["lost_in_round"]     = lost_in_round
	result["tournament_rounds"] = round_results
	result["round_summary"]     = _tournament_summary(overall_won, rounds_won, ROUNDS, lost_in_round)
	return result


# --- Helpers ---

func _apply_match_morale(won: bool, match_type: String) -> void:
	# Morale change per player. Tournament loss hurts more — there was more at stake.
	var gain: int
	var loss: int
	if match_type == Calendar.TYPE_TOURNAMENT:
		gain = 8
		loss = -15
	else:
		gain = 5
		loss = -10

	var delta: int = gain if won else loss
	for p: Player in players:
		var prev: int   = p.morale
		p.morale        = clamp(p.morale + delta, 0, 100)
		p.morale_delta  = p.morale - prev  # track for UI feedback


func _win_estimate(team_skill: int, opponent_base: int) -> String:
	# team_skill is the sum of all player skills (~165–210 range for 3 players at avg 55–70).
	# opponent_base is already per-player-equivalent (the score one team achieves).
	# We compare team_skill (3 players combined) to opponent_base * 3 to keep scale consistent.
	var ratio: float = float(team_skill) / float(opponent_base * 3)
	if ratio >= 1.10:   return GameText.ESTIMATE_FAVORED
	elif ratio >= 0.90: return GameText.ESTIMATE_EVEN
	else:               return GameText.ESTIMATE_UNDERDOG


func _tournament_summary(won: bool, rounds_won: int, total: int, lost_in_round: int) -> String:
	if won:
		return GameText.TOURNAMENT_WIN_ALL if rounds_won == total else GameText.TOURNAMENT_WIN_CLOSE
	return GameText.TOURNAMENT_LOSS_ROUND % lost_in_round


func _finalise_result(result: Dictionary, match_type: String, opp_label: String, level_ups: Array) -> Dictionary:
	result["is_important"] = match_type != Calendar.TYPE_NORMAL
	result["match_type"]   = match_type
	result["type_label"]   = GameText.MATCH_TYPE[match_type]
	result["week"]         = week_in_season
	result["season"]       = season
	result["opp_strength"] = opp_label
	result["streak"]       = team_win_streak
	result["game_over"]    = Calendar.is_game_over(week + 1)
	result["level_ups"]    = level_ups

	var sorted: Array = result["players"].duplicate()
	sorted.sort_custom(func(a, b): return a["score"] > b["score"])
	var active: Array = sorted.filter(func(e): return not e.get("rested", false))
	result["mvp_name"]   = active[0]["player"].player_name if active.size() > 0 else ""
	result["worst_name"] = active[-1]["player"].player_name if active.size() > 1 else ""
	return result


func _find_player(name: String) -> Player:
	for p: Player in players:
		if p.player_name == name:
			return p
	return null


func _team_has_active_action() -> bool:
	for player: Player in players:
		if player.planned_action == "train" or player.planned_action == "scrim":
			return true
	return false


func _update_streaks(won: bool) -> void:
	if won:
		team_win_streak = max(team_win_streak + 1, 1)
		for player: Player in players:
			player.win_streak = max(player.win_streak + 1, 1)
	else:
		team_win_streak = min(team_win_streak - 1, -1)
		for player: Player in players:
			player.win_streak = min(player.win_streak - 1, -1)
