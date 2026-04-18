class_name GameManager
extends RefCounted

const OPPONENT_BASE_SCORE: int = 180

var players: Array = []
var week: int          = 1
var is_important: bool = false


func _init() -> void:
	players = [
		Player.new("Apex",  70, 80, 90, 75, "clutch",     "resilient"),
		Player.new("Byte",  60, 60, 80, 70, "grinder",    "none"),
		Player.new("Ghost", 55, 75, 85, 65, "volatile",   "fragile"),
	]


func advance_week() -> Dictionary:
	apply_actions()
	var result: Dictionary = run_match()
	week += 1
	return result


# Apply weekly action — training traits modify the stat deltas here.
func apply_actions() -> void:
	for player: Player in players:
		match player.planned_action:
			"train":
				# Grinder: +1 extra skill, -3 extra stamina
				# Lazy:    -1 skill gain, but we floor at +1 so it's not zero
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
				# Lazy: +8 extra stamina recovery
				var stamina_gain: int = 15
				
				if player.primary_trait == "lazy":
					stamina_gain += 8
				player.stamina = min(player.stamina + stamina_gain, 100)
				player.morale  = min(player.morale + 5, 100)

			"scrim":
				player.skill = min(player.skill + 1, 100)

		player.planned_action = "rest"


func run_match() -> Dictionary:
	var opponent_score: int = OPPONENT_BASE_SCORE + randi_range(-15, 15)
	var result: Dictionary  = Simulation.simulate_team(players, is_important, opponent_score)
	
	return result
