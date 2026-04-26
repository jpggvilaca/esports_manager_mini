# scripts/systems/Simulation.gd
# ============================================================
# MATCH SIMULATION — pure functions, no side effects.
# Takes a Player's current stats and returns a match score + breakdown.
#
# UNIFIED TRAIT SYSTEM:
#   Every player has ONE primary_trait from the set:
#   aggressive | tactical | focused | clutch | resilient | volatile
#
#   Each trait affects BOTH simulation (here) AND matchup (TraitMatchup.gd).
#
# PERFORMANCE FORMULA (order of application):
#   1. Skill         → base score
#   2. Stamina drag  → continuous multiplier (always active)
#   3. Focus         → controls score variance (higher focus = smaller swing)
#   4. Trait effects → simulation bonuses / variance modifiers
#
# HIGH SKILL ALONE DOES NOT GUARANTEE VICTORY.
# A 90-skill player at 10 stamina will underperform a 60-skill fresh player.
#
# TRAIT SIMULATION EFFECTS:
#   aggressive → variance +8; stamina drains faster (lower floor)
#   tactical   → variance -4; no floor modifier
#   focused    → variance -6; +5 on important matches
#   clutch     → +12 on important; small variance in normal games
#   resilient  → stamina floor raised; no variance modifier
#   volatile   → variance +14; big swing either way
#
# TO TWEAK stamina drag    → edit _stamina_multiplier()
# TO TWEAK focus variance  → edit the rand_range_val section in simulate_player()
# TO TWEAK trait bonuses   → edit the match block in simulate_player()
# ============================================================
class_name Simulation
extends RefCounted


# ---------------------------------------------------------------------------
# SIMULATE PLAYER — computes one player's contribution score for a match.
#
# Returns { "score": int, "breakdown": Array, "trait_label": String }
# breakdown entries: { "reason": String, "delta": int }
#
# is_important: true for important matches, tournaments, and solos.
#   Amplifies clutch and focused trait effects.
# ---------------------------------------------------------------------------
static func simulate_player(player: Player, is_important: bool) -> Dictionary:
	var breakdown: Array = []

	# --- STEP 1: Skill base ---
	var score: float = player.skill

	# --- STEP 2: Stamina drag (continuous, always active) ---
	var minor_traits: Array = player.get_minor_traits()
	var primary_trait: String = player.primary_trait
	var stamina_mult: float = _stamina_multiplier(player.stamina, minor_traits, primary_trait)
	var drag_delta: int     = int(player.skill * stamina_mult) - player.skill
	if drag_delta < 0:
		score += drag_delta
		breakdown.append({ "reason": "Tired legs", "delta": drag_delta })

	# --- STEP 3: Focus variance ---
	# High focus → tight performance. Low focus → wide variance.
	# Trait modifies the variance range on top of focus.
	var focus_factor: float = player.focus / 100.0
	var rand_range_val: int = int(lerp(22.0, 4.0, focus_factor))

	match primary_trait:
		"focused":    rand_range_val = max(rand_range_val - 6, 2)   # precision: tightest variance
		"tactical":   rand_range_val = max(rand_range_val - 4, 2)   # structured: steady
		"aggressive": rand_range_val += 8                            # explosive: wide swings
		"volatile":   rand_range_val += 14                           # chaos: biggest swings
		# clutch, resilient: no variance modifier — their effect is situational/stamina

	var focus_roll: int = randi_range(-rand_range_val, rand_range_val)
	score += focus_roll
	if focus_roll > 0:
		breakdown.append({ "reason": "Good read", "delta": focus_roll })
	elif focus_roll < 0:
		breakdown.append({ "reason": "Off read", "delta": focus_roll })

	# --- STEP 4: Primary trait effects ---
	var trait_delta: int    = 0
	var trait_label: String = ""

	match primary_trait:
		"clutch":
			# Spikes on important matches. Small noise in normal games.
			if is_important:
				trait_delta = 12
				trait_label = "⚡ Clutch moment"
			else:
				trait_delta = randi_range(-3, 3)
				trait_label = "" if trait_delta == 0 else "⚡ Clutch"
		"focused":
			# Small but consistent bonus on important matches (precision under pressure).
			if is_important:
				trait_delta = 5
				trait_label = "🎯 Locked in"
		"volatile":
			# Extra spike chance — coin-flip direction, high magnitude.
			var spike: int = randi_range(0, 1)
			if spike == 1:
				trait_delta = randi_range(5, 12)
				trait_label = "🌀 Hot streak"
			else:
				trait_delta = randi_range(-12, -5)
				trait_label = "🌀 Off day"
		# aggressive, tactical, resilient: their effects are stamina/variance-based (Steps 2–3).
		"aggressive", "tactical", "resilient":
			pass

	if trait_delta != 0:
		score += trait_delta
		breakdown.append({ "reason": trait_label, "delta": trait_delta })

	return {
		"score":       max(int(score), 0),
		"breakdown":   breakdown,
		"trait_label": trait_label,
	}


# ---------------------------------------------------------------------------
# SIMULATE TEAM — runs simulate_player for all players, sums scores.
# ---------------------------------------------------------------------------
static func simulate_team(players: Array[Player], is_important: bool, opponent_score: int) -> Dictionary:
	var player_results: Array = []
	var team_score: int = 0

	for player: Player in players:
		var sim: Dictionary = simulate_player(player, is_important)
		var score: int      = sim["score"]
		var flavor_data: Dictionary = MatchFlavorGenerator.generate(player, score, is_important, sim["trait_label"])

		team_score += score
		player_results.append({
			"player":        player,
			"score":         score,
			"label":         flavor_data["label"],
			"flavor":        flavor_data["flavor"],
			"trait_trigger": flavor_data["trait_trigger"],
			"breakdown":     sim["breakdown"],
		})

	return {
		"won":            team_score >= opponent_score,
		"team_score":     team_score,
		"opponent_score": opponent_score,
		"players":        player_results,
	}


# ---------------------------------------------------------------------------
# STAMINA MULTIPLIER — continuous stamina drag on performance.
#
# Returns a multiplier applied to base skill:
#   1.0 at full stamina  → no drag
#   ~0.70 at zero stamina → 30% reduction (base)
#
# aggressive lowers the floor (burns harder, drains faster).
# resilient raises the floor (endurance — holds together under fatigue).
# fragile minor trait further lowers; resilient minor trait further raises.
# ---------------------------------------------------------------------------
static func _stamina_multiplier(stamina: int, minor_traits: Array, primary_trait: String) -> float:
	const BASE_FLOOR:      float = 0.70
	const FRAGILE_FLOOR:   float = 0.60
	const RESILIENT_FLOOR: float = 0.80

	var floor_val: float = BASE_FLOOR

	# Primary trait modifier
	if primary_trait == "aggressive":
		floor_val = 0.65   # burns hot, pays a stamina cost
	elif primary_trait == "resilient":
		floor_val = 0.80   # endurance: holds form under fatigue

	# Minor trait override (takes priority over primary)
	if "fragile"   in minor_traits: floor_val = FRAGILE_FLOOR
	if "resilient" in minor_traits: floor_val = RESILIENT_FLOOR

	return lerp(floor_val, 1.0, clampf(stamina / 100.0, 0.0, 1.0))
