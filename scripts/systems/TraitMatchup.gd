# scripts/systems/TraitMatchup.gd
# ============================================================
# TRAIT MATCHUP SYSTEM — the core strategic layer.
#
# DESIGN (Pokémon-type model):
#   Each player has 1 match trait (the 5 match traits below).
#   Each opponent has 3 trait slots (randomly drawn per season).
#   Each match has 2–3 situations.
#
# SCORING (applied as modifier to opponent_score threshold):
#   Opponent matchup → 60%  (primary — counter their traits)
#   Situation coverage → 30% (secondary — align with match events)
#   Stamina/morale → 10%    (existing Simulation.gd modifier)
#
# MATCH TRAITS (distinct from performance traits in Simulation.gd):
#   aggressive  → beats focused,   loses to tactical
#   tactical    → beats aggressive, loses to focused
#   focused     → beats tactical,  loses to aggressive, beats clutch
#   clutch      → beats resilient, loses to focused
#   resilient   → beats clutch,    loses to aggressive
#
# SITUATIONS (each favors one match trait):
#   early_pressure  → aggressive
#   control_phase   → tactical
#   precision_phase → focused
#   clutch_moment   → clutch
#   endurance_phase → resilient
#
# OPPONENT GENERATION:
#   Opponents have 3 trait slots drawn from the 5 match traits.
#   The pool is seeded per season so traits shift each season
#   but stay fixed within a season (consistent opponent identity).
#   Harder opponents are weighted toward counter-heavy combos.
# ============================================================
class_name TraitMatchup
extends RefCounted


# ---------------------------------------------------------------------------
# MATCH TRAITS — the 5 strategic traits used only for matchup calculation.
# These are separate from primary_trait in Player.gd (clutch/grinder/etc.)
# Players map to a match trait via their primary_trait (see TRAIT_TO_MATCH below).
# ---------------------------------------------------------------------------
const MATCH_TRAITS: Array[String] = [
	"aggressive",
	"tactical",
	"focused",
	"clutch",
	"resilient",
]

# Maps a player's primary_trait → their match trait for matchup purposes.
# Clutch and resilient map directly. Performance traits map thematically.
const TRAIT_TO_MATCH: Dictionary = {
	"clutch":      "clutch",
	"choker":      "clutch",      # high-pressure archetype, same slot
	"grinder":     "resilient",   # endurance / consistency archetype
	"lazy":        "aggressive",  # explosive, all-in when fresh
	"consistent":  "focused",     # steady, precision archetype
	"volatile":    "aggressive",  # chaotic burst, pressure-forward
	"none":        "tactical",    # neutral → structured play
}

# ---------------------------------------------------------------------------
# MATCHUP TABLE — who beats whom.
# wins_against[trait] = Array of traits it beats
# loses_against[trait] = Array of traits it loses to
# Everything not listed = neutral (0 modifier)
# ---------------------------------------------------------------------------
const WINS_AGAINST: Dictionary = {
	"aggressive":  ["focused"],
	"tactical":    ["aggressive"],
	"focused":     ["tactical", "clutch"],
	"clutch":      ["resilient"],
	"resilient":   ["clutch"],
}

const LOSES_AGAINST: Dictionary = {
	"aggressive":  ["tactical", "resilient"],
	"tactical":    ["focused"],
	"focused":     ["aggressive"],
	"clutch":      ["focused"],
	"resilient":   ["aggressive", "clutch"],
}

# ---------------------------------------------------------------------------
# SITUATIONS — 5 types, each favors one match trait.
# ---------------------------------------------------------------------------
const ALL_SITUATIONS: Array[String] = [
	"early_pressure",
	"control_phase",
	"precision_phase",
	"clutch_moment",
	"endurance_phase",
]

const SITUATION_FAVORS: Dictionary = {
	"early_pressure":  "aggressive",
	"control_phase":   "tactical",
	"precision_phase": "focused",
	"clutch_moment":   "clutch",
	"endurance_phase": "resilient",
}

# ---------------------------------------------------------------------------
# OPPONENT GENERATION
# Generates 3 trait slots for an opponent.
# Seeded by season + week so it's deterministic per playthrough
# but different every season.
#
# BALANCE FIX 1: Difficulty controls how "counter-proof" the opponent is:
#   weak/average  → random 3 from full pool (easy to counter)
#   strong        → one duplicate added (harder to get full counter)
#   dominant      → pool biased toward traits that hard-counter common picks
#                   (focused+resilient combo: punishes aggressive+clutch spam)
#
# BALANCE FIX 2: ~30% of normal-difficulty weeks are "situation-dominant":
#   Opponent gets 3 DIFFERENT traits (no repeats, no bias) so no single
#   counter dominates — the situations become the primary decision.
#   Seeded so specific weeks are always situation-dominant.
# ---------------------------------------------------------------------------
static func generate_opponent_traits(season: int, week_in_season: int, difficulty_label: String) -> Array[String]:
	var seed_val: int = season * 1000 + week_in_season * 37 + 7
	seed(seed_val)

	# BALANCE FIX 2: determine if this is a situation-dominant week.
	# Use a separate seed so it’s independent of the trait draw.
	var sit_seed: int = season * 777 + week_in_season * 13 + 99
	seed(sit_seed)
	var is_situation_week: bool = (difficulty_label == "weak" or difficulty_label == "average") \
		and (randi() % 10) < 3  # 30% chance on easy/average weeks

	# Reset main seed for trait draw
	seed(seed_val)

	if is_situation_week:
		# Draw 3 fully distinct traits — no counter advantage either way.
		# Player must read situations to win, not opponent counters.
		var pool: Array = MATCH_TRAITS.duplicate()
		pool.shuffle()
		var result: Array[String] = []
		for i in 3:
			result.append(pool[i])
		return result

	# Normal generation — difficulty controls pool bias
	var pool: Array[String] = MATCH_TRAITS.duplicate()

	# BALANCE FIX 1: Dominant opponents use a counter-heavy pool.
	# Rather than random duplicates, they skew toward focused+resilient
	# which punish the most tempting picks (aggressive/clutch spam).
	if difficulty_label == "dominant":
		# Weight pool toward traits that counter common player archetypes:
		# focused beats aggressive+clutch, resilient beats clutch+aggressive
		pool.append_array(["focused", "focused", "resilient", "tactical"])
	elif difficulty_label == "strong":
		# Add one extra copy of a random trait to make full-counter harder
		pool.append(pool[randi() % 5])  # original 5 traits only

	var result: Array[String] = []
	var pool_copy: Array = pool.duplicate()
	for i in 3:
		if pool_copy.is_empty():
			pool_copy = pool.duplicate()
		var idx: int = randi() % pool_copy.size()
		result.append(pool_copy[idx])
		pool_copy.remove_at(idx)

	return result


# ---------------------------------------------------------------------------
# SITUATION GENERATION
# Returns 2–3 situations for a match, seeded deterministically.
# Important/tournament matches tend to get 3 situations.
# ---------------------------------------------------------------------------
static func generate_situations(season: int, week_in_season: int, match_type: String) -> Array[String]:
	var seed_val: int = season * 999 + week_in_season * 53 + 13
	seed(seed_val)

	var count: int = 3 if match_type in ["important", "tournament"] else (2 + (randi() % 2))
	count = min(count, 3)

	var pool: Array = ALL_SITUATIONS.duplicate()
	var result: Array[String] = []
	for i in count:
		if pool.is_empty():
			break
		var idx: int = randi() % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)
	return result


# ---------------------------------------------------------------------------
# MATCHUP SCORE
# Returns a float 0.0–1.0 representing how well the player team
# counters the opponent traits.
#
# Algorithm:
#   For each player trait vs each opponent slot:
#     +2 if player beats opponent slot
#     -1 if player loses to opponent slot
#     0  if neutral
#   Max possible = 3 players × 2 points = 6
#   Min possible = 3 players × -3 (3 losses) = -9
#   Normalize to 0–1 range clamped.
# ---------------------------------------------------------------------------
static func calc_opponent_score(player_match_traits: Array[String], opponent_traits: Array[String]) -> float:
	var raw: float = 0.0
	for pt in player_match_traits:
		for ot in opponent_traits:
			if pt in WINS_AGAINST and ot in WINS_AGAINST[pt]:
				raw += 2.0
			elif pt in LOSES_AGAINST and ot in LOSES_AGAINST[pt]:
				raw -= 1.0
	# Normalize: max = 6, we clamp raw to [-9, 6] then map to [0, 1]
	return clampf((raw + 9.0) / 15.0, 0.0, 1.0)


# ---------------------------------------------------------------------------
# SITUATION SCORE
# Returns a float 0.0–1.0 representing how well the player team
# covers the match situations.
#
# Each situation that has a matching player trait = +1 point.
# Normalize by number of situations.
# ---------------------------------------------------------------------------
static func calc_situation_score(player_match_traits: Array[String], situations: Array[String]) -> float:
	if situations.is_empty():
		return 0.5
	var hits: float = 0.0
	for sit in situations:
		var favored: String = SITUATION_FAVORS.get(sit, "")
		if favored in player_match_traits:
			hits += 1.0
	return clampf(hits / float(situations.size()), 0.0, 1.0)


# ---------------------------------------------------------------------------
# COMBINED MATCHUP MODIFIER
# Returns a float adjustment to apply to the opponent score threshold.
# Positive = advantage for the player team (lower effective threshold).
# Negative = disadvantage.
#
# Weights: opponent 60%, situations 30%, stamina/morale 10% (handled externally).
# The modifier range maps to roughly ±15% of a typical opponent score
# so it can tip close matches but not dominate skill gaps.
# ---------------------------------------------------------------------------
static func calc_modifier(
	player_traits:    Array[String],
	opponent_traits:  Array[String],
	situations:       Array[String],
	stamina_morale_score: float      # 0.0–1.0, from Simulation
) -> float:
	var opp_score: float = calc_opponent_score(player_traits, opponent_traits)
	var sit_score: float = calc_situation_score(player_traits, situations)

	# Combined score 0.0–1.0 (0.5 = neutral, no advantage)
	var combined: float = (opp_score * 0.6) + (sit_score * 0.3) + (stamina_morale_score * 0.1)

	# Map 0.5 → 0 modifier, 1.0 → +MAX_BONUS, 0.0 → -MAX_BONUS
	# MAX_BONUS = 20 points (roughly 15-20% of a typical mid-season opponent score)
	const MAX_BONUS: float = 20.0
	return (combined - 0.5) * 2.0 * MAX_BONUS


# ---------------------------------------------------------------------------
# PLAYER MATCH TRAITS
# Extracts the match trait for each active player.
# ---------------------------------------------------------------------------
static func get_player_match_traits(players: Array[Player]) -> Array[String]:
	var result: Array[String] = []
	for p in players:
		var mt: String = TRAIT_TO_MATCH.get(p.primary_trait, "tactical")
		result.append(mt)
	return result


# ---------------------------------------------------------------------------
# STAMINA/MORALE SCORE — summarizes team condition as a 0–1 float.
# Used as the 10% modifier input.
# ---------------------------------------------------------------------------
static func calc_stamina_morale_score(players: Array[Player]) -> float:
	if players.is_empty():
		return 0.5
	var total: float = 0.0
	for p in players:
		var s: float = p.stamina / 100.0
		var m: float = p.morale  / 100.0
		total += (s * 0.6) + (m * 0.4)
	return clampf(total / float(players.size()), 0.0, 1.0)
