# scripts/managers/GameManager.gd
# Owns game state and flow. Calls Simulation. No UI references.
class_name GameManager
extends RefCounted

const OPPONENT_BASE_SCORE: int = 180 # fixed difficulty bar

var players: Array = []
var week: int      = 1
var is_important: bool = false # could vary by week later


func _init() -> void:
	# Hardcoded roster — extend here when you want more players
	players = [
		Player.new("Apex",  70, 80, 90, 75, "clutch"),
		Player.new("Byte",  60, 60, 80, 70, "none"),
		Player.new("Ghost", 55, 75, 85, 65, "none"),
	]


# Call once per week after players pick their actions.
# Returns the match result dict.
func advance_week() -> Dictionary:
	apply_actions()
	var result: Dictionary = run_match()
	week += 1
	return result


# Apply each player's planned_action to their stats.
func apply_actions() -> void:
	for player: Player in players:
		match player.planned_action:
			"train":
				player.skill   = min(player.skill + 3, 100)
				player.stamina = max(player.stamina - 10, 0)
			"rest":
				player.stamina = min(player.stamina + 15, 100)
				player.morale  = min(player.morale + 5, 100)
			"scrim":
				player.skill   = min(player.skill + 1, 100)
		# Reset to default each week
		player.planned_action = "rest"


# Simulate match and return structured result dict.
func run_match() -> Dictionary:
	var sim_result: Dictionary = Simulation.simulate_team(players, is_important)
	var team_score: int        = sim_result["total"]
	var opponent_score: int    = OPPONENT_BASE_SCORE + randi_range(-15, 15)
	var won: bool              = team_score >= opponent_score

	return {
		"won":            won,
		"team_score":     team_score,
		"opponent_score": opponent_score,
		"per_player":     sim_result["per_player"], # Array, same order as players
		"week":           week,
	}
