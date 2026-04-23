# scripts/systems/LevelSystem.gd
# ============================================================
# LEVEL SYSTEM — XP accumulation and level-up stat growth.
#
# DESIGN INTENT (hybrid model):
#   Matches → HIGH XP  (main source — playing and performing matters most)
#   Scrims  → MEDIUM XP (balanced prep)
#   Train   → LOW XP   (long-term investment with stamina cost)
#   Intense → LOW-MED XP (high risk, moderate reward)
#   Rest    → ZERO XP  (purely recovery)
#
# If action XP is too high relative to match XP:
#   → players grind to max level without matches → boring
#
# LEVEL-UP STAT GROWTH:
#   Growth is trait-based with randomness (Pokémon-style).
#   Each trait has a growth profile — same trait, slightly different stats each run.
#   Skill always grows (minimum 1), other stats roll from trait's profile.
#
# TO TWEAK XP balance           → edit the XP_ constants below.
# TO TWEAK level-up speed       → edit LEVEL_THRESHOLDS.
# TO TWEAK stat growth per level → edit TRAIT_GROWTH.
# TO TWEAK trait milestone unlocks → edit TRAIT_UNLOCKS.
# ============================================================
class_name LevelSystem
extends RefCounted


# ---------------------------------------------------------------------------
# XP VALUES — calibrated so matches dominate over actions.
# Rule of thumb: total action XP per week should never exceed one "Struggled" match XP.
# ---------------------------------------------------------------------------

# Match performance XP — the main source of progression.
# TO TWEAK: adjust these to change how fast players grow from match results.
const XP_CARRIED:   int = 100   # Outstanding performance
const XP_SOLID:     int = 50    # Average performance
const XP_STRUGGLED: int = 20    # Poor performance

# Action XP — small bonuses to make preparation feel rewarding, not dominant.
# Train = lowest (skill investment has no other immediate reward)
# Scrim = medium (also costs stamina, so compensates slightly)
# Intense = moderate (high stamina cost justifies slightly more XP than train)
# Rest = zero (purely recovery, no progression reward)
# TO TWEAK: raise/lower these relative to match XP to change the action/match ratio.
const XP_TRAIN:   int = 5
const XP_SCRIM:   int = 15
const XP_REST:    int = 0
const XP_INTENSE: int = 20

# Match type multipliers — higher stakes = more XP.
# TO TWEAK: change these to reward risky match types more/less.
const XP_MULT: Dictionary = {
	"normal":     1.0,
	"important":  1.5,   # notable match — 50% bonus
	"tournament": 3.0,   # climax event — 3× base
	"solo":       1.5,   # same stakes as important
}

# Loss XP penalty — players still learn from losing, but far less.
# TO TWEAK: set closer to 1.0 to reduce punishment, closer to 0.0 to make losses devastating.
const XP_LOSS_MULT: float = 0.35


# ---------------------------------------------------------------------------
# LEVEL THRESHOLDS — XP required to reach each level.
# Deliberately slow — levelling should feel earned, not automatic.
# Index 0 is unused (no "level 0"). Index N = cost to go from level N to N+1.
# TO ADD MORE LEVELS → append more values and increase MAX_LEVEL.
# ---------------------------------------------------------------------------
const LEVEL_THRESHOLDS: Array[int] = [
	0,     # placeholder — level 0 does not exist
	120,   # Level 1 → 2
	200,   # Level 2 → 3
	300,   # Level 3 → 4
	420,   # Level 4 → 5
	560,   # Level 5 → 6
	720,   # Level 6 → 7
	900,   # Level 7 → 8
	1100,  # Level 8 → 9
	1320,  # Level 9 → 10
]

# Must equal LEVEL_THRESHOLDS.size() - 1 to avoid out-of-bounds reads.
const MAX_LEVEL: int = 10


# ---------------------------------------------------------------------------
# STAT GROWTH — Pokémon-style variance on level-up.
# Base values are the guaranteed minimum per level-up.
# Trait-specific rolls are added on top of the base (0 to max_bonus).
# Total gain per stat per level = base + randi_range(0, trait_bonus).
# TO TWEAK: raise base for guaranteed progression, raise bonus for more variance.
# ---------------------------------------------------------------------------
const LEVEL_UP_SKILL_BASE:   int = 1   # always gain at least 1 skill
const LEVEL_UP_STAMINA_BASE: int = 0
const LEVEL_UP_FOCUS_BASE:   int = 0
const LEVEL_UP_MORALE_BASE:  int = 0

# Per-trait growth profiles. Each value is the MAX random bonus added to the base.
# TO TWEAK individual trait ceilings → change values in this dict.
const TRAIT_GROWTH: Dictionary = {
	# clutch: strong skill ceiling, decent morale upside
	"clutch":    { "skill": 3, "stamina": 1, "focus": 1, "morale": 2 },
	# choker: strong mechanics but morale never improves from levelling
	"choker":    { "skill": 3, "stamina": 2, "focus": 0, "morale": 0 },
	# grinder: best stamina growth, solid skill
	"grinder":   { "skill": 2, "stamina": 3, "focus": 1, "morale": 1 },
	# lazy: best morale growth (feels great when fresh), low skill ceiling
	"lazy":      { "skill": 1, "stamina": 2, "focus": 0, "morale": 3 },
	# consistent: strongest focus growth — reduces match variance at high level
	"consistent":{ "skill": 2, "stamina": 1, "focus": 3, "morale": 1 },
	# volatile: chaotic — high rolls in both skill and focus, but unreliable
	"volatile":  { "skill": 3, "stamina": 1, "focus": 3, "morale": 0 },
	# none: balanced across everything
	"none":      { "skill": 2, "stamina": 2, "focus": 2, "morale": 1 },
}


# ---------------------------------------------------------------------------
# TRAIT UNLOCKS — minor traits granted at milestone levels.
# These change Simulation.gd's stamina multiplier floor.
# TO ADD MILESTONES → add new keys (level numbers) to this dict.
# ---------------------------------------------------------------------------
const TRAIT_UNLOCKS: Dictionary = {
	3:  {
		# First milestone: traits begin to crystallise.
		"clutch":    "resilient",   # clutch players build mental armour
		"choker":    "fragile",     # pressure takes its structural toll
		"grinder":   "resilient",   # grinding builds physical toughness
		"lazy":      "fragile",     # laziness becomes a physical weakness
		"consistent":"resilient",   # consistency breeds durability
		"volatile":  "fragile",     # volatility is hard on the body
		"none":      "resilient",
	},
	5: {
		# Second milestone — currently no new unlocks (all return "none").
		# TO ADD unlocks at level 5 → replace "none" values here.
		"clutch":    "none",
		"choker":    "none",
		"grinder":   "none",
		"lazy":      "none",
		"consistent":"none",
		"volatile":  "none",
		"none":      "none",
	},
	10: {
		# Max-level milestone: resilience for everyone who doesn't have it.
		"clutch":    "resilient",
		"choker":    "resilient",
		"grinder":   "resilient",
		"lazy":      "resilient",
		"consistent":"resilient",
		"volatile":  "resilient",
		"none":      "resilient",
	},
}


# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

# Award match XP based on performance label and match type, without loss penalty.
# (Used for edge cases — prefer award_match_xp_with_result for normal match paths.)
static func award_match_xp(player: Player, perf_label: String, match_type: String) -> Array:
	var base_xp: int = _xp_for_label(perf_label)
	var mult: float  = XP_MULT.get(match_type, 1.0)
	return _apply_xp(player, int(base_xp * mult))


# Award match XP with win/loss result. Loss multiplies XP by XP_LOSS_MULT.
# USE THIS in all standard match paths (MatchDispatcher).
static func award_match_xp_with_result(player: Player, perf_label: String, match_type: String, won: bool) -> Array:
	var base_xp: int = _xp_for_label(perf_label)
	var mult: float  = XP_MULT.get(match_type, 1.0)
	if not won:
		mult *= XP_LOSS_MULT
	return _apply_xp(player, int(base_xp * mult))


# Award action XP (train/scrim/intense). Rest gives zero — intentional.
# Returns level-up dicts if levelling occurred during a training week (rare).
static func award_action_xp(player: Player, action: String) -> Array:
	var gained: int = 0
	match action:
		"train":   gained = XP_TRAIN
		"scrim":   gained = XP_SCRIM
		"intense": gained = XP_INTENSE
		# rest: 0 — no progression reward for resting
	if gained == 0:
		return []
	return _apply_xp(player, gained)


# Returns XP needed to reach the next level, or -1 if already at max.
static func xp_to_next_level(player: Player) -> int:
	if player.level >= MAX_LEVEL:
		return -1
	return LEVEL_THRESHOLDS[player.level] - player.xp


# Returns progress fraction 0.0 → 1.0 toward the next level (for XP bar UI).
static func level_progress(player: Player) -> float:
	if player.level >= MAX_LEVEL:
		return 1.0
	return clampf(float(player.xp) / float(LEVEL_THRESHOLDS[player.level]), 0.0, 1.0)


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

# Maps a performance label string to its base XP value.
# Labels come from GameText.PERF_LABELS via MatchFlavorGenerator.
static func _xp_for_label(label: String) -> int:
	if "Carried"   in label: return XP_CARRIED
	if "Solid"     in label: return XP_SOLID
	return XP_STRUGGLED


# Core XP application: adds XP, handles level-up loop, rolls stat gains, checks trait unlocks.
# Returns array of level-up event dicts for UI display (LevelUpBanner).
static func _apply_xp(player: Player, amount: int) -> Array:
	player.xp      += amount
	player.xp_delta += amount  # accumulates across actions + match in one week
	var level_ups: Array = []

	# Level-up loop — process one level at a time (multi-level in one week is rare but valid).
	while player.level < MAX_LEVEL:
		var threshold: int = LEVEL_THRESHOLDS[player.level]
		if player.xp < threshold:
			break

		player.xp    -= threshold
		player.level += 1

		# --- Trait-based stat growth (Pokémon-style variance) ---
		# Each level-up is slightly different, even for the same trait.
		# TO TWEAK overall growth speed → edit LEVEL_UP_*_BASE constants above.
		var growth: Dictionary = TRAIT_GROWTH.get(player.primary_trait, TRAIT_GROWTH["none"])
		var skill_gain:   int = LEVEL_UP_SKILL_BASE   + randi_range(0, growth["skill"])
		var stamina_gain: int = LEVEL_UP_STAMINA_BASE + randi_range(0, growth["stamina"])
		var focus_gain:   int = LEVEL_UP_FOCUS_BASE   + randi_range(0, growth["focus"])
		var morale_gain:  int = LEVEL_UP_MORALE_BASE  + randi_range(0, growth["morale"])
		player.skill   = min(player.skill   + skill_gain,   100)
		player.stamina = min(player.stamina + stamina_gain, 100)
		player.focus   = min(player.focus   + focus_gain,   100)
		player.morale  = min(player.morale  + morale_gain,  100)

		# --- Trait unlock at milestone levels ---
		# Fills minor_trait first, then minor_trait_2 if already occupied.
		var trait_unlocked: String = "none"
		if TRAIT_UNLOCKS.has(player.level):
			var candidate: String = TRAIT_UNLOCKS[player.level].get(player.primary_trait, "none")
			if candidate != "none":
				if player.minor_trait == "none" or player.minor_trait == "":
					player.minor_trait = candidate
					trait_unlocked     = candidate
				elif player.minor_trait_2 == "none" or player.minor_trait_2 == "":
					player.minor_trait_2 = candidate
					trait_unlocked       = candidate

		# Emit a level-up event dict for LevelUpBanner to display.
		level_ups.append({
			"player_name":    player.player_name,
			"new_level":      player.level,
			"skill_gain":     skill_gain,
			"stamina_gain":   stamina_gain,
			"focus_gain":     focus_gain,
			"morale_gain":    morale_gain,
			"trait_unlocked": trait_unlocked,
		})

	return level_ups
