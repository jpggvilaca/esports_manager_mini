# scripts/managers/SeasonGoalManager.gd
# Owns the current season goal + quarterly sub-goals.
# Quarter goals reset at weeks 6, 12, 18 and give bonuses on completion.
class_name SeasonGoalManager
extends RefCounted

# Season goal (runs the full season)
var total_wins: int         = 0
var season_goal: Dictionary = {}

# Quarter goals (resets at each quarter boundary: weeks 6, 12, 18)
var quarter_goal: Dictionary       = {}
var quarter_bonus_pending: bool    = false
var quarter_bonus_description: String = ""

const QUARTER_WEEKS: Array[int] = [6, 12, 18]

func _init() -> void:
	season_goal  = _pick_season()
	quarter_goal = _pick_quarter()


# Called by GameManager after every match to advance week tracking.
func on_match_result(result: MatchResult, players: Array[Player], week_in_season: int) -> void:
	if result.won:
		total_wins += 1
	_check_season(result, players)
	_check_quarter(result, players, week_in_season)


# Called by GameManager to apply pending bonus to players.
# Returns true if a bonus was applied so caller can surface it.
func consume_quarter_bonus(players: Array[Player]) -> bool:
	if not quarter_bonus_pending:
		return false
	quarter_bonus_pending = false
	for p: Player in players:
		p.morale = min(p.morale + 10, 100)
		# Award a flat XP surge
		p.xp       += 50
		p.xp_delta += 50
	return true


func start_new_quarter(week_in_season: int) -> void:
	# Called at the start of each new quarter to refresh the quarter goal.
	if week_in_season in QUARTER_WEEKS:
		quarter_goal = _pick_quarter()


func get_display() -> Dictionary:
	var desc: String
	match season_goal["type"]:
		"wins":
			desc = "🎯 Season: Win %d matches" % season_goal["target"]
		"tournament_win":
			desc = "🎯 Season: Win a tournament"
		"top_form":
			desc = "🎯 Season: Get %d players on a hot streak" % season_goal["target"]
		_:
			desc = ""
	return {
		"description": desc,
		"current":     season_goal.get("current",  0),
		"target":      season_goal.get("target",   0),
		"achieved":    season_goal.get("achieved", false),
		"type":        season_goal.get("type",     ""),
	}


func get_quarter_display() -> Dictionary:
	var desc: String
	match quarter_goal["type"]:
		"quarter_wins":
			desc = "✨ This quarter: Win %d matches" % quarter_goal["target"]
		"quarter_no_loss":
			desc = "✨ This quarter: Go unbeaten"
		"quarter_form":
			desc = "✨ This quarter: Get a player on a hot streak"
		_:
			desc = ""
	return {
		"description": desc,
		"current":     quarter_goal.get("current",  0),
		"target":      quarter_goal.get("target",   0),
		"achieved":    quarter_goal.get("achieved", false),
		"type":        quarter_goal.get("type",     ""),
	}


func _pick_season() -> Dictionary:
	var goals: Array = [
		{ "type": "wins",           "target": 8,  "current": 0, "achieved": false },
		{ "type": "wins",           "target": 12, "current": 0, "achieved": false },
		{ "type": "tournament_win", "target": 1,  "current": 0, "achieved": false },
		{ "type": "top_form",       "target": 2,  "current": 0, "achieved": false },
	]
	return goals[randi() % goals.size()]


func _pick_quarter() -> Dictionary:
	var goals: Array = [
		{ "type": "quarter_wins",    "target": 3, "current": 0, "achieved": false, "wins_this_quarter": 0 },
		{ "type": "quarter_wins",    "target": 4, "current": 0, "achieved": false, "wins_this_quarter": 0 },
		{ "type": "quarter_no_loss", "target": 1, "current": 0, "achieved": false, "clean": true },
		{ "type": "quarter_form",    "target": 1, "current": 0, "achieved": false },
	]
	return goals[randi() % goals.size()]


func _check_season(result: MatchResult, players: Array[Player]) -> void:
	if season_goal.get("achieved", false):
		return
	match season_goal["type"]:
		"wins":
			season_goal["current"] = total_wins
			if total_wins >= season_goal["target"]:
				season_goal["achieved"] = true
		"tournament_win":
			if result.is_tournament and result.won:
				season_goal["current"]  = 1
				season_goal["achieved"] = true
		"top_form":
			var in_form: int = 0
			for p: Player in players:
				if p.form_label == "🔥 In Form":
					in_form += 1
			season_goal["current"] = in_form
			if in_form >= season_goal["target"]:
				season_goal["achieved"] = true


func _check_quarter(result: MatchResult, players: Array[Player], _week_in_season: int) -> void:
	if quarter_goal.get("achieved", false):
		return
	match quarter_goal["type"]:
		"quarter_wins":
			if result.won:
				quarter_goal["wins_this_quarter"] = quarter_goal.get("wins_this_quarter", 0) + 1
			quarter_goal["current"] = quarter_goal["wins_this_quarter"]
			if quarter_goal["wins_this_quarter"] >= quarter_goal["target"]:
				quarter_goal["achieved"] = true
				_trigger_quarter_bonus("Crushed the quarter — team morale +10, all players +50 XP")
		"quarter_no_loss":
			if not result.won:
				quarter_goal["clean"] = false
				quarter_goal["achieved"] = false
			# Quarter is only confirmed complete at the boundary — checked in start_new_quarter
		"quarter_form":
			for p: Player in players:
				if p.form_label == "🔥 In Form":
					quarter_goal["current"]  = 1
					quarter_goal["achieved"] = true
					_trigger_quarter_bonus("Player hit top form — team morale +10, all players +50 XP")
					break


# Called at quarter boundary to finalise no-loss quarter.
func check_quarter_boundary(week_in_season: int) -> void:
	if week_in_season not in QUARTER_WEEKS:
		return
	if quarter_goal.get("type") == "quarter_no_loss" and quarter_goal.get("clean", false):
		if not quarter_goal.get("achieved", false):
			quarter_goal["achieved"] = true
			_trigger_quarter_bonus("Flawless quarter — team morale +10, all players +50 XP")


func _trigger_quarter_bonus(description: String) -> void:
	quarter_bonus_pending     = true
	quarter_bonus_description = description
