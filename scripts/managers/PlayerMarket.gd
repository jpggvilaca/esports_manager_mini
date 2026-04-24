# scripts/managers/PlayerMarket.gd
# ============================================================
# PLAYER MARKET — candidate generation and replacement logic.
# This is a tycoon system: the main decision is "keep my invested player
# vs take a stranger with better immediate stats".
#
# DESIGN INTENT:
#   - Market appears every MARKET_INTERVAL weeks, or before big events
#   - 2–3 candidates generated with deliberate trade-offs (never strictly better)
#   - 2 replacements per season (Option A — no currency)
#   - Replaced players are gone permanently; new players start at level 2
#
# TO TWEAK timing         → MARKET_INTERVAL constant
# TO TWEAK slot budget    → MAX_REPLACEMENTS_PER_SEASON
# TO TWEAK starting level → CANDIDATE_START_LEVEL
# TO TWEAK stat ranges    → ARCHETYPES array
# ============================================================
class_name PlayerMarket
extends RefCounted

# ---------------------------------------------------------------------------
# CONFIGURATION CONSTANTS
# TO TUNE: change these to adjust market pacing and acquisition limits.
# ---------------------------------------------------------------------------

# How often the market becomes available (in weeks within a season).
# Market also triggers 1 week before any important/tournament week.
const MARKET_INTERVAL: int = 4

# Maximum number of replacements allowed per season.
# When this hits 0, the market still opens but replacements are disabled.
const MAX_REPLACEMENTS_PER_SEASON: int = 2

# Level candidates start at. Give them some early progression already done.
# XP is set to midpoint of the level's threshold so they're partway through.
const CANDIDATE_START_LEVEL: int = 2

# ---------------------------------------------------------------------------
# CANDIDATE ARCHETYPES
# Each archetype defines a stat profile with deliberate trade-offs.
# Generated candidates are seeded from these and randomised slightly.
#
# Format: { name_pool, primary_trait, minor_trait, skill, focus, stamina, morale, bio }
# TO ADD A NEW ARCHETYPE → append a new dict to this array.
# ---------------------------------------------------------------------------
const ARCHETYPES: Array = [
	# The Specialist — high skill ceiling, but stamina-fragile
	{
		"names":        ["Kira", "Raze", "Echo", "Volt"],
		"primary":      "clutch",
		"minor":        "fragile",
		"skill":        [48, 58],
		"focus":        [35, 50],
		"stamina":      [30, 45],
		"morale":       [45, 65],
		"bio":          "Peaks in the big moments but burns out fast.",
	},
	# The Workhorse — great stamina, consistent output, lower ceiling
	{
		"names":        ["Dex", "Mako", "Fen", "Cruz"],
		"primary":      "grinder",
		"minor":        "resilient",
		"skill":        [32, 44],
		"focus":        [40, 55],
		"stamina":      [60, 75],
		"morale":       [50, 60],
		"bio":          "Won't dazzle you, but never lets you down.",
	},
	# The Wildcard — volatile with high focus, unpredictable results
	{
		"names":        ["Zyx", "Jinx", "Kael", "Nyx"],
		"primary":      "volatile",
		"minor":        "none",
		"skill":        [38, 55],
		"focus":        [55, 70],
		"stamina":      [40, 55],
		"morale":       [35, 55],
		"bio":          "You never know what you'll get. That's the point.",
	},
	# The Anchor — consistent, high focus, low drama, low ceiling
	{
		"names":        ["Sola", "Yuri", "Hemi", "Pell"],
		"primary":      "consistent",
		"minor":        "resilient",
		"skill":        [30, 42],
		"focus":        [60, 75],
		"stamina":      [50, 65],
		"morale":       [55, 70],
		"bio":          "Reads the game better than anyone. Won't carry, won't lose it either.",
	},
	# The Glass Cannon — very high skill, very low stamina
	{
		"names":        ["Vex", "Skar", "Lyra", "Thorn"],
		"primary":      "choker",
		"minor":        "fragile",
		"skill":        [52, 65],
		"focus":        [30, 48],
		"stamina":      [25, 40],
		"morale":       [40, 60],
		"bio":          "Incredible numbers when fresh. Collapses under pressure or fatigue.",
	},
]

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
var replacements_used: int   = 0    # reset each season by GameManager
var current_candidates: Array = []  # Array[Player] — generated fresh each market open


# ---------------------------------------------------------------------------
# AVAILABILITY CHECK
# Returns true if the market should be available this week.
#
# week_in_season: current week within the season (1-based)
# next_event:     dict from Calendar.get_next_event() — { type, weeks_away } or {}
# ---------------------------------------------------------------------------
func is_available(week_in_season: int, _next_event: Dictionary) -> bool:
	# Market opens only at end-of-quarter boundaries (weeks 3, 6, 9, 12).
	# This gives exactly 4 windows per season — roughly "twice a year" per half-season.
	return week_in_season % MARKET_INTERVAL == 0


# ---------------------------------------------------------------------------
# CANDIDATE GENERATION
# Generates 2–3 fresh candidates with trade-off stats.
# Avoids duplicating names that are already on the roster.
#
# current_players: the team's current Array[Player]
# Returns the generated candidates and stores them in current_candidates.
# ---------------------------------------------------------------------------
func generate_candidates(current_players: Array) -> Array:
	# Pick how many candidates to show (2 or 3).
	var count: int = randi_range(2, 3)

	# Build the pool of used names to avoid duplicates.
	var used_names: Array = current_players.map(func(p): return p.player_name)

	# Shuffle archetypes so we don't always get the same order.
	var shuffled: Array = ARCHETYPES.duplicate()
	shuffled.shuffle()

	var candidates: Array = []
	for i in count:
		var arch: Dictionary = shuffled[i % shuffled.size()]
		var candidate: Player = _build_from_archetype(arch, used_names)
		used_names.append(candidate.player_name)
		candidates.append(candidate)

	current_candidates = candidates
	return candidates


# ---------------------------------------------------------------------------
# REPLACEMENT
# Replaces a player in the roster with a candidate.
# Returns true on success, false if no slots remain.
#
# players:         the mutable Array[Player] owned by GameManager
# candidate:       the chosen Player from current_candidates
# replace_index:   index in players array to replace (0, 1, or 2)
# ---------------------------------------------------------------------------
func replace_player(players: Array, candidate: Player, replace_index: int) -> bool:
	# Guard: no slots left this season.
	if replacements_used >= MAX_REPLACEMENTS_PER_SEASON:
		return false
	# Guard: invalid index.
	if replace_index < 0 or replace_index >= players.size():
		return false

	players[replace_index] = candidate
	replacements_used += 1
	# Remove the hired player from current_candidates so they can't be hired twice.
	current_candidates.erase(candidate)
	return true


# ---------------------------------------------------------------------------
# SEASON RESET
# Called by GameManager at the start of each new season.
# ---------------------------------------------------------------------------
func reset_for_new_season() -> void:
	replacements_used  = 0
	current_candidates = []


# ---------------------------------------------------------------------------
# DISPLAY HELPERS
# ---------------------------------------------------------------------------

# Returns remaining replacement slots as a string like "●●○" or "●○○".
func slots_display() -> String:
	var remaining: int = MAX_REPLACEMENTS_PER_SEASON - replacements_used
	var used: int      = replacements_used
	return "●".repeat(remaining) + "○".repeat(used)


# Returns true if at least one replacement slot is available.
func has_slots() -> bool:
	return replacements_used < MAX_REPLACEMENTS_PER_SEASON


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

# Builds a Player from an archetype dict with slight stat randomisation.
# Ensures the candidate name isn't already on the roster.
static func _build_from_archetype(arch: Dictionary, used_names: Array) -> Player:
	# Pick a name not already in use.
	var available_names: Array = arch["names"].filter(func(n): return n not in used_names)
	if available_names.is_empty():
		# Fallback: generate a unique name by appending a number.
		available_names = [arch["names"][0] + str(randi_range(2, 9))]
	var name: String = available_names[randi() % available_names.size()]

	# Roll stats within the archetype's range.
	var skill:   int = randi_range(arch["skill"][0],   arch["skill"][1])
	var focus:   int = randi_range(arch["focus"][0],   arch["focus"][1])
	var stamina: int = randi_range(arch["stamina"][0], arch["stamina"][1])
	var morale:  int = randi_range(arch["morale"][0],  arch["morale"][1])

	var candidate: Player = Player.new(
		name, skill, focus, stamina, morale,
		arch["primary"], arch["minor"]
	)
	candidate.bio = arch["bio"]

	# Set the candidate at a meaningful starting level (not blank, not overpowered).
	candidate.level = CANDIDATE_START_LEVEL
	# Seed XP partway through the level so they don't immediately level up.
	var threshold: int = LevelSystem.LEVEL_THRESHOLDS[CANDIDATE_START_LEVEL]
	candidate.xp = threshold / 2

	return candidate
