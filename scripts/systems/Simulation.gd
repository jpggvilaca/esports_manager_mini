# scripts/systems/Simulation.gd
# ============================================================
# MATCH SIMULATION — pure functions, no side effects.
# Takes a Player's current stats and returns a match score + breakdown.
#
# PERFORMANCE FORMULA (order of application):
#   1. Skill         → base score
#   2. Stamina drag  → continuous multiplier (always active)
#   3. Focus         → controls score variance (higher focus = smaller random swings)
#   4. Trait effects → situational bonuses/penalties
#
# HIGH SKILL ALONE DOES NOT GUARANTEE VICTORY.
# A 90-skill player at 10 stamina will underperform a 60-skill fresh player.
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
#   This flag amplifies clutch/choker trait effects.
# modifiers: optional dict of { score_bonus, morale_gain, morale_loss } from incidents.
# ---------------------------------------------------------------------------
static func simulate_player(player: Player, is_important: bool) -> Dictionary:
	var breakdown: Array = []

	# --- STEP 1: Skill base ---
	# Skill is the raw mechanical ceiling. All other factors modify it.
	var score: float = player.skill

	# --- STEP 2: Stamina drag (continuous, always active) ---
	# Unlike a cliff-penalty, this is a smooth multiplier.
	# A fully rested player performs at 100% of their skill.
	# An exhausted player performs at ~70% regardless of other stats.
	# fragile minor trait makes the drag kick in harder (lower floor).
	# resilient minor trait resists the drag (higher floor).
	var minor_traits: Array = player.get_minor_traits()
	var stamina_mult: float = _stamina_multiplier(player.stamina, minor_traits)
	var drag_delta: int     = int(player.skill * stamina_mult) - player.skill
	# drag_delta is zero or negative — only record it if it's actually hurting.
	if drag_delta < 0:
		score += drag_delta
		breakdown.append({ "reason": "Tired legs", "delta": drag_delta })

	# --- STEP 3: Focus variance ---
	# High focus → tight performance (small random swing).
	# Low focus  → wide variance (could go well or badly).
	# consistent trait tightens variance further; volatile widens it.
	var focus_factor: float = player.focus / 100.0
	var rand_range_val: int = int(lerp(22.0, 4.0, focus_factor))
	if player.primary_trait == "consistent":
		rand_range_val = max(rand_range_val - 5, 2)
	elif player.primary_trait == "volatile":
		rand_range_val += 8
	var focus_roll: int = randi_range(-rand_range_val, rand_range_val)
	score += focus_roll
	if focus_roll > 0:
		breakdown.append({ "reason": "Good read", "delta": focus_roll })
	elif focus_roll < 0:
		breakdown.append({ "reason": "Off read", "delta": focus_roll })

	# --- STEP 4: Primary trait effects ---
	# Traits are situational — they fire based on match context.
	# TO ADD A NEW TRAIT → add a new branch here and in GameText.FLAVOR.
	var trait_delta: int    = 0
	var trait_label: String = ""
	match player.primary_trait:
		"clutch":
			# Clutch players spike on important matches. In normal games, small variance.
			if is_important:
				trait_delta = 10
				trait_label = "⚡ Clutch moment"
			else:
				trait_delta = randi_range(-3, 3)
				trait_label = "" if trait_delta == 0 else "⚡ Clutch"
		"choker":
			# Chokers crumble on important matches but thrive with no pressure.
			if is_important:
				trait_delta = -8
				trait_label = "😰 Choked"
			else:
				trait_delta = 4
				trait_label = "😌 No pressure"
		# grinder, lazy, consistent, volatile: their effects are in training/stamina,
		# not direct score bonuses. See GameManager.apply_actions() and _stamina_multiplier().
		"grinder", "lazy", "consistent", "volatile", "none":
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
# SIMULATE TEAM — runs simulate_player for all players, sums scores, compares to opponent.
#
# players: the roster (Array[Player])
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
#   ~0.7 at zero stamina → 30% reduction
#
# The curve is linear between FLOOR and 1.0.
# TO TWEAK: raise floor to make stamina less punishing, lower it for harsher penalty.
# fragile trait lowers the floor (more drag), resilient raises it (less drag).
# ---------------------------------------------------------------------------
static func _stamina_multiplier(stamina: int, minor_traits: Array) -> float:
	# Base performance floor at zero stamina.
	# TO TWEAK: change BASE_FLOOR to make exhaustion more or less punishing.
	const BASE_FLOOR: float    = 0.70
	const FRAGILE_FLOOR: float = 0.60  # fragile players fall apart when tired
	const RESILIENT_FLOOR: float = 0.80  # resilient players hold together better

	var floor_val: float = BASE_FLOOR
	if "fragile"   in minor_traits: floor_val = FRAGILE_FLOOR
	if "resilient" in minor_traits: floor_val = RESILIENT_FLOOR

	# Linear interpolation: stamina 0 → floor_val, stamina 100 → 1.0
	return lerp(floor_val, 1.0, clampf(stamina / 100.0, 0.0, 1.0))
