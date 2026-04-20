# scripts/managers/GameManager.gd
# Owns game state and flow. Calls Simulation. No UI references.
class_name GameManager
extends RefCounted

var players: Array[Player]       = []
var week: int            = 1  # absolute week number across all seasons
var team_win_streak: int = 0  # positive = wins, negative = losses

# Derived from week — never set directly.
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
	# Capture planned actions BEFORE apply_actions resets them to "rest".
	var has_match: bool = _team_has_active_action()
	# Also record which players are resting so results can mark them.
	var resting_players: Array[String] = []
	for player: Player in players:
		if player.planned_action == "rest":
			resting_players.append(player.player_name)
	apply_actions()

	var result: Dictionary = {}
	if has_match:
		result = run_match(resting_players)
		_update_streaks(result["won"])
	else:
		result = { "has_match": false }

	week += 1
	return result


func get_prematch_context() -> Dictionary:
	var entry: Dictionary  = Calendar.get_week(week)
	var match_type: String = entry["type"]

	var conditions: Array = []
	for player: Player in players:
		var cond: String
		
		if player.stamina < 30:   cond = GameText.CONDITIONS["exhausted"]
		elif player.stamina < 50: cond = GameText.CONDITIONS["tired"]
		elif player.morale > 80:  cond = GameText.CONDITIONS["confident"]
		else:                     cond = GameText.CONDITIONS["ready"]
		conditions.append({ "name": player.player_name, "condition": cond })

	return {
		"week":         week_in_season,
		"season":       season,
		"match_type":   match_type,
		"type_label":   GameText.MATCH_TYPE[match_type],
		"is_important": match_type != Calendar.TYPE_NORMAL,
		"opp_strength": GameText.OPPONENT_STRENGTH.get(entry["label"], entry["label"]),
		"conditions":   conditions,
		"streak":       team_win_streak,
		"game_over":    Calendar.is_game_over(week),
	}


func apply_actions() -> void:
	for player: Player in players:
		var prev_skill:   int = player.skill
		var prev_stamina: int = player.stamina
		player.xp_delta = 0  # reset accumulator before this week's XP

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

		# award_action_xp must run before planned_action is reset below.
		LevelSystem.award_action_xp(player, player.planned_action)

		player.skill_delta    = player.skill   - prev_skill
		player.stamina_delta  = player.stamina - prev_stamina
		player.planned_action = "rest"


func run_match(resting_players: Array[String]) -> Dictionary:
	var cal_entry: Dictionary = Calendar.get_week(week)
	var match_type: String    = cal_entry["type"]
	var is_important: bool    = match_type != Calendar.TYPE_NORMAL

	var variance: int = randi_range(-18, 18) if match_type == Calendar.TYPE_TOURNAMENT \
		else randi_range(-10, 10)

	var opponent_score: int = cal_entry["opponent"] + variance
	var result: Dictionary  = Simulation.simulate_team(players, is_important, opponent_score)

	# Award match XP and collect level-up events for the UI.
	var level_ups: Array = []
	for player_entry: Dictionary in result["players"]:
		var p: Player = player_entry["player"]
		p.last_score  = player_entry["score"]
		# Mark resting players — they played but had a passive week.
		player_entry["rested"] = p.player_name in resting_players

		var new_levels: Array = LevelSystem.award_match_xp(p, player_entry["label"], match_type)
		level_ups.append_array(new_levels)

		# Attach per-player XP data so the result row can display it.
		player_entry["xp_gained"]   = p.xp_delta
		player_entry["level"]       = p.level
		player_entry["xp_progress"] = LevelSystem.level_progress(p)

	result["is_important"] = is_important
	result["match_type"]   = match_type
	result["type_label"]   = GameText.MATCH_TYPE[match_type]
	result["week"]         = week_in_season
	result["season"]       = season
	result["opp_strength"] = cal_entry["label"]
	result["streak"]       = team_win_streak
	result["game_over"]    = Calendar.is_game_over(week + 1)
	result["level_ups"]    = level_ups
	return result


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
