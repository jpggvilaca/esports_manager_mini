class_name Simulation
extends RefCounted


# Simulate a single player's match score, applying all trait effects.
static func simulate_player(player: Player, is_important: bool) -> int:
	var score: int = player.skill

	# --- Focus randomness ---
	# consistent: tighter spread / volatile: wider spread
	var focus_factor: float = player.focus / 100.0
	var rand_range_val: int = int(lerp(20.0, 5.0, focus_factor))
	
	if player.primary_trait == "consistent":
		rand_range_val = max(rand_range_val - 5, 2)
	elif player.primary_trait == "volatile":
		rand_range_val += 8
	score += randi_range(-rand_range_val, rand_range_val)

	# --- Stamina penalty ---
	# fragile (minor): penalty kicks in below 50 instead of 40
	# resilient (minor): halved penalty
	var stamina_threshold: int = 40
	
	if player.minor_trait == "fragile":
		stamina_threshold = 50
	if player.stamina < stamina_threshold:
		var penalty: int = int((stamina_threshold - player.stamina) * 0.5)
		
		if player.minor_trait == "resilient":
			penalty = penalty / 2
		score -= penalty

	# --- Primary trait match effects ---
	match player.primary_trait:
		"clutch":
			if is_important:
				score += 10
			else:
				# Slight inconsistency in normal matches
				score += randi_range(-3, 3)
		"choker":
			if is_important:
				score -= 8
			else:
				# Less nerves in normal matches = small boost
				score += 4
		"grinder", "lazy", "consistent", "volatile":
			pass # training traits handled in GameManager; volatile/consistent handled above
		"none":
			pass

	return max(score, 0)


# Returns the full structured result dict consumed by GameManager and displayed by Main.
# { "won": bool, "team_score": int, "opponent_score": int, "week": int (set by GM),
#   "players": [ { "player": Player, "score": int, "label": String, "flavor": String } ] }
static func simulate_team(players: Array, is_important: bool, opponent_score: int) -> Dictionary:
	var player_results: Array = []
	var team_score: int = 0

	for player: Player in players:
		var score: int      = simulate_player(player, is_important)
		var flavor_data     = MatchFlavorGenerator.generate(player, score, is_important)
		
		team_score         += score
		player_results.append({
			"player": player,
			"score":  score,
			"label":  flavor_data["label"],
			"flavor": flavor_data["flavor"],
		})

	return {
		"won":            team_score >= opponent_score,
		"team_score":     team_score,
		"opponent_score": opponent_score,
		"players":        player_results,
	}
