# scripts/systems/TraitMatchup.gd
# ============================================================
# UNIFIED TRAIT SYSTEM — single source of truth.
#
# DESIGN PHILOSOPHY:
#   One trait. Visible to the player. Affects BOTH simulation AND matchup.
#   No hidden mapping. No second trait system. "Simple to learn, hard to master."
#
# THE 6 TRAITS:
#   aggressive → high-variance burst; counters focused; weak to tactical & resilient
#   tactical   → structured play; counters aggressive; weak to focused
#   focused    → precision; counters tactical & clutch; weak to aggressive
#   clutch     → late-game spike; counters resilient; weak to focused & aggressive
#   resilient  → endurance; counters aggressive & clutch; weak to clutch (see note)
#   volatile   → chaos; wide variance; neutral counters (random matchup role)
#
# COUNTER RING (main loop):
#   tactical > aggressive > focused > tactical   (rock-paper-scissors core)
#   clutch > resilient > aggressive              (side chain for late-game)
#   focused > clutch                             (precision shuts down spike)
#   volatile = wild card — no reliable counter, no reliable weakness
#
# SITUATIONS:
#   Early  → aggressive  (set the pace, take space)
#   Mid    → tactical    (adapt, read, control)
#   Late   → clutch      (perform when it matters most)
#
# SIMULATION EFFECTS (see Simulation.gd for implementation):
#   aggressive → variance +8; stamina drains 10% faster
#   tactical   → variance -4; no stamina modifier
#   focused    → variance -6; small bonus on important matches
#   clutch     → +12 score on important/late; otherwise small variance
#   resilient  → stamina floor raised; no variance modifier
#   volatile   → variance +14; can spike or crash
#
# OPPONENT GENERATION:
#   Opponents have 3 trait slots drawn from the 6 traits.
#   Seeded per season+week for determinism. Difficulty biases the pool.
# ============================================================
class_name TraitMatchup
extends RefCounted


# ---------------------------------------------------------------------------
# THE 6 UNIFIED TRAITS
# ---------------------------------------------------------------------------
const ALL_TRAITS: Array[String] = [
	"aggressive",
	"tactical",
	"focused",
	"clutch",
	"resilient",
	"volatile",
]


# ---------------------------------------------------------------------------
# MATCHUP TABLE — who beats whom.
# Volatile is intentionally absent from both tables → always neutral.
# ---------------------------------------------------------------------------
const WINS_AGAINST: Dictionary = {
	"aggressive": ["focused"],
	"tactical":   ["aggressive"],
	"focused":    ["tactical", "clutch"],
	"clutch":     ["resilient"],
	"resilient":  ["aggressive", "clutch"],
}

const LOSES_AGAINST: Dictionary = {
	"aggressive": ["tactical", "resilient"],
	"tactical":   ["focused"],
	"focused":    ["aggressive"],
	"clutch":     ["focused", "aggressive"],
	"resilient":  ["clutch"],
}


# ---------------------------------------------------------------------------
# SITUATIONS — 3 phases, each favors one trait.
# Kept simple and intuitive: Early/Mid/Late.
# ---------------------------------------------------------------------------
const ALL_SITUATIONS: Array[String] = [
	"early",
	"mid",
	"late",
]

const SITUATION_FAVORS: Dictionary = {
	"early": "aggressive",   # who moves first sets the tone
	"mid":   "tactical",     # read, adapt, control the midgame
	"late":  "clutch",       # deliver when the stakes are highest
}


# ---------------------------------------------------------------------------
# OPPONENT GENERATION
# Generates 3 trait slots for an opponent.
# Seeded by season + week so it's deterministic per playthrough.
#
# Difficulty controls counter-proofing:
#   weak/average  → random 3 from full pool
#   strong        → pool adds extra copy of a trait (harder to full-counter)
#   dominant      → pool biased toward focused+resilient (punishes aggressive/clutch spam)
#
# ~30% of normal weeks are "situation-dominant":
#   3 distinct traits → no single counter dominates; phases become the key decision.
# ---------------------------------------------------------------------------
static func generate_opponent_traits(season: int, week_in_season: int, difficulty_label: String) -> Array[String]:
	var seed_val: int = season * 1000 + week_in_season * 37 + 7
	seed(seed_val)

	# Determine if this is a situation-dominant week (independent seed).
	var sit_seed: int = season * 777 + week_in_season * 13 + 99
	seed(sit_seed)
	var is_situation_week: bool = (difficulty_label == "weak" or difficulty_label == "average") \
		and (randi() % 10) < 3

	seed(seed_val)

	if is_situation_week:
		var pool: Array = ALL_TRAITS.duplicate()
		pool.shuffle()
		var result: Array[String] = []
		for i in 3:
			result.append(pool[i])
		return result

	var pool: Array[String] = ALL_TRAITS.duplicate()

	if difficulty_label == "dominant":
		# Bias toward focused+resilient — punishes aggressive/clutch spam.
		pool.append_array(["focused", "focused", "resilient", "tactical"])
	elif difficulty_label == "strong":
		pool.append(pool[randi() % ALL_TRAITS.size()])

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
# Returns 3 situations for a match: early, mid, late (always all three).
# Important/tournament matches keep all 3. Normal matches may drop to 2.
# ---------------------------------------------------------------------------
static func generate_situations(season: int, week_in_season: int, match_type: String) -> Array[String]:
	var seed_val: int = season * 999 + week_in_season * 53 + 13
	seed(seed_val)

	if match_type in ["important", "tournament"]:
		return ["early", "mid", "late"]

	# Normal matches: 2 or 3 situations
	var count: int = 2 + (randi() % 2)
	var pool: Array = ALL_SITUATIONS.duplicate()
	pool.shuffle()
	var result: Array[String] = []
	for i in count:
		result.append(pool[i])
	return result


# ---------------------------------------------------------------------------
# MATCHUP SCORE
# Returns an int modifier representing how well the player team
# counters the opponent traits given the match situations.
#
# Weights:
#   Opponent matchup  → 60%  (counter their traits)
#   Situation coverage → 30% (align with match phases)
#   Always integer-based.
#
# Output range roughly -15 to +15.
# Positive = player team has advantage.
# ---------------------------------------------------------------------------
static func calculate_matchup_modifier(
	player_traits: Array[String],
	opponent_traits: Array[String],
	situations: Array[String]
) -> int:
	var modifier: int = 0

	# --- Opponent matchup (60% weight) ---
	for p_trait in player_traits:
		for o_trait in opponent_traits:
			if WINS_AGAINST.has(p_trait) and o_trait in WINS_AGAINST[p_trait]:
				modifier += 3   # player counters opponent trait
			elif LOSES_AGAINST.has(p_trait) and o_trait in LOSES_AGAINST[p_trait]:
				modifier -= 2   # opponent counters player trait
			# volatile vs anything = 0 (intentional)

	# --- Situation coverage (30% weight) ---
	for situation in situations:
		var favored: String = SITUATION_FAVORS.get(situation, "")
		if favored == "":
			continue
		if favored in player_traits:
			modifier += 2   # player aligned with this phase
		if favored in opponent_traits:
			modifier -= 1   # opponent also aligned (partial offset)

	return modifier


# ---------------------------------------------------------------------------
# TEAM TRAIT ARRAY
# Extracts the trait from each active player. Trait IS the unified trait.
# No mapping needed — primary_trait is already one of the 6.
# ---------------------------------------------------------------------------
static func get_team_traits(players: Array) -> Array[String]:
	var result: Array[String] = []
	for p in players:
		result.append(p.primary_trait)
	return result
