# scripts/systems/Simulation.gd
# Pure logic. No UI, no scene references. Stateless functions only.
class_name Simulation
extends RefCounted

# Returns a single player's performance score for one match.
static func simulate_player(player: Player, is_important: bool) -> int:
	var score: int = player.skill

	# Randomness scaled by focus (higher focus = tighter spread)
	var focus_factor: float = player.focus / 100.0
	var rand_range_val: int = int(lerp(20.0, 5.0, focus_factor))
	score += randi_range(-rand_range_val, rand_range_val)

	# Stamina penalty: below 40 stamina hurts performance
	if player.stamina < 40:
		var penalty: int = int((40 - player.stamina) * 0.5)
		score -= penalty

	# Special trait: "clutch" boosts score on important matches
	if player.special == "clutch" and is_important:
		score += 10

	return max(score, 0) # score can't go negative


# Returns { "total": int, "per_player": Array }
static func simulate_team(players: Array, is_important: bool) -> Dictionary:
	var per_player: Array = []
	var total: int = 0

	for player in players:
		var s: int = simulate_player(player, is_important)
		per_player.append(s)
		total += s

	return { "total": total, "per_player": per_player }
