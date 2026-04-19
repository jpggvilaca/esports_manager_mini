# scripts/managers/GameManager.gd
# Owns game state and flow. Calls Simulation. No UI references.
class_name GameManager
extends RefCounted

const OPPONENT_BASE_SCORE: int = 160  # lower base — near-misses more common early

var players: Array     = []
var week: int          = 1
var is_important: bool = false
var team_win_streak: int = 0  # positive = wins, negative = losses


func _init() -> void:
	players = [
		Player.new("Apex",  70, 80, 90, 75, "clutch",   "resilient"),
		Player.new("Byte",  60, 60, 80, 70, "grinder",  "none"),
		Player.new("Ghost", 55, 75, 85, 65, "volatile", "fragile"),
	]


func advance_week() -> Dictionary:
	# Capture whether a match should happen BEFORE apply_actions resets planned_action.
	var has_match: bool = _team_has_active_action()
	apply_actions()
	var result: Dictionary = {}
	if has_match:
		result = run_match()
		_update_streaks(result["won"])
	else:
		result = { "has_match": false }
	week += 1
	return result


# Returns true if at least one player trained or scrimed this week.
# Pure rest weeks (everyone on "rest") skip match simulation.
func _team_has_active_action() -> bool:
	for player: Player in players:
		if player.planned_action == "train" or player.planned_action == "scrim":
			return true
	return false


# Returns pre-match context for UI to show BEFORE the player clicks Advance.
func get_prematch_context() -> Dictionary:
	# Important every 4th week
	is_important = (week % 4 == 0)

	# Opponent strength label based on scaled score
	var opp: int     = _opponent_score_this_week()
	var strength: String
	if opp < 170:   strength = GameText.OPPONENT_STRENGTH["weak"]
	elif opp < 190: strength = GameText.OPPONENT_STRENGTH["average"]
	elif opp < 210: strength = GameText.OPPONENT_STRENGTH["strong"]
	else:           strength = GameText.OPPONENT_STRENGTH["dominant"]

	# Player condition labels
	var conditions: Array = []
	for player: Player in players:
		var cond: String
		if player.stamina < 30:   cond = GameText.CONDITIONS["exhausted"]
		elif player.stamina < 50: cond = GameText.CONDITIONS["tired"]
		elif player.morale > 80:  cond = GameText.CONDITIONS["confident"]
		else:                     cond = GameText.CONDITIONS["ready"]
		conditions.append({ "name": player.player_name, "condition": cond })

	return {
		"week":        week,
		"is_important": is_important,
		"opp_strength": strength,
		"conditions":  conditions,
		"streak":      team_win_streak,
	}


func apply_actions() -> void:
	for player: Player in players:
		var prev_skill:   int = player.skill
		var prev_stamina: int = player.stamina

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
				# Scrim = practice matches. Builds game sense (focus), not raw mechanics (skill).
				# No stamina cost — it's controlled practice, not grind.
				player.focus = min(player.focus + 4, 100)

		# Track deltas for micro-reward display
		player.skill_delta   = player.skill   - prev_skill
		player.stamina_delta = player.stamina - prev_stamina
		player.planned_action = "rest"


func run_match() -> Dictionary:
	var opponent_score: int = _opponent_score_this_week()
	var result: Dictionary  = Simulation.simulate_team(players, is_important, opponent_score)

	# Write last_score back into each player for streak/identity tracking
	for entry in result["players"]:
		var p: Player    = entry["player"]
		p.last_score     = entry["score"]

	result["is_important"]  = is_important
	result["week"]          = week
	result["opp_strength"]  = _opponent_label(opponent_score)
	result["streak"]        = team_win_streak
	return result


# Opponent scales with weeks — creates genuine difficulty ramp.
# Near-miss tuning: variance is tight (±12) so results cluster near the threshold.
func _opponent_score_this_week() -> int:
	var ramp: int     = week * 3               # grows 3pts per week
	var variance: int = randi_range(-12, 12)   # tight band → near misses
	return OPPONENT_BASE_SCORE + ramp + variance


func _opponent_label(score: int) -> String:
	if score < 170:   return GameText.OPPONENT_STRENGTH["weak"]
	elif score < 190: return GameText.OPPONENT_STRENGTH["average"]
	elif score < 210: return GameText.OPPONENT_STRENGTH["strong"]
	else:             return GameText.OPPONENT_STRENGTH["dominant"]


func _update_streaks(won: bool) -> void:
	if won:
		team_win_streak = max(team_win_streak + 1, 1)
		for player: Player in players:
			player.win_streak = max(player.win_streak + 1, 1)
	else:
		team_win_streak = min(team_win_streak - 1, -1)
		for player: Player in players:
			player.win_streak = min(player.win_streak - 1, -1)
