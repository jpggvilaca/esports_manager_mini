# scripts/systems/LevelSystem.gd
# XP accumulation and level-up stat growth.
# Matches → main XP source. Train bench action → slow trickle.
#
# TO TWEAK XP balance           → edit the XP_ constants below.
# TO TWEAK level-up speed       → edit LEVEL_THRESHOLDS.
# TO TWEAK stat growth per level → edit TRAIT_GROWTH.
# TO TWEAK trait milestone unlocks → edit TRAIT_UNLOCKS.
class_name LevelSystem
extends RefCounted


# ---------------------------------------------------------------------------
# XP VALUES
# Tuned from simulation data: original values caused near-zero progression
# at 19% win rate because losses gave only 7–17 XP per match.
# ---------------------------------------------------------------------------

const XP_CARRIED:   int = 100  # Outstanding performance
const XP_SOLID:     int = 60   # Solid performance (was 50)
const XP_STRUGGLED: int = 30   # Poor performance (was 20) — losing shouldn't stall growth

const XP_TRAIN:   int = 5

const XP_MULT: Dictionary = {
	"normal":     1.0,
	"important":  1.5,
	"tournament": 3.0,
	"solo":       1.5,
}

# Loss multiplier raised from 0.35 to 0.55.
# At 0.35 with an 80% loss rate, players earned ~12 XP/match — effectively frozen.
const XP_LOSS_MULT: float = 0.55


# ---------------------------------------------------------------------------
# LEVEL THRESHOLDS — reduced ~25% from original values.
# Original pacing gave ~2 level-ups per 20 weeks. Target is 4–6.
# ---------------------------------------------------------------------------
const LEVEL_THRESHOLDS: Array[int] = [
	0,    # placeholder — level 0 does not exist
	90,   # Level 1 → 2  (was 120)
	160,  # Level 2 → 3  (was 200)
	240,  # Level 3 → 4  (was 300)
	340,  # Level 4 → 5  (was 420)
	460,  # Level 5 → 6  (was 560)
	600,  # Level 6 → 7  (was 720)
	760,  # Level 7 → 8  (was 900)
	940,  # Level 8 → 9  (was 1100)
	1140, # Level 9 → 10 (was 1320)
]

const MAX_LEVEL: int = 10


# ---------------------------------------------------------------------------
# STAT GROWTH — Pokémon-style variance on level-up.
# base + randi_range(0, trait_bonus) per stat per level-up.
# ---------------------------------------------------------------------------
const LEVEL_UP_SKILL_BASE:   int = 1
const LEVEL_UP_STAMINA_BASE: int = 0
const LEVEL_UP_FOCUS_BASE:   int = 0
const LEVEL_UP_MORALE_BASE:  int = 0

const TRAIT_GROWTH: Dictionary = {
	"clutch":    { "skill": 3, "stamina": 1, "focus": 1, "morale": 2 },
	"choker":    { "skill": 3, "stamina": 2, "focus": 0, "morale": 0 },
	"grinder":   { "skill": 2, "stamina": 3, "focus": 1, "morale": 1 },
	"lazy":      { "skill": 1, "stamina": 2, "focus": 0, "morale": 3 },
	"consistent":{ "skill": 2, "stamina": 1, "focus": 3, "morale": 1 },
	"volatile":  { "skill": 3, "stamina": 1, "focus": 3, "morale": 0 },
	"none":      { "skill": 2, "stamina": 2, "focus": 2, "morale": 1 },
}


# ---------------------------------------------------------------------------
# TRAIT UNLOCKS — minor traits granted at milestone levels.
# ---------------------------------------------------------------------------
const TRAIT_UNLOCKS: Dictionary = {
	3: {
		"clutch":    "resilient",
		"choker":    "fragile",
		"grinder":   "resilient",
		"lazy":      "fragile",
		"consistent":"resilient",
		"volatile":  "fragile",
		"none":      "resilient",
	},
	5: {
		"clutch":    "none",
		"choker":    "none",
		"grinder":   "none",
		"lazy":      "none",
		"consistent":"none",
		"volatile":  "none",
		"none":      "none",
	},
	10: {
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

static func award_match_xp_with_result(player: Player, perf_label: String, match_type: String, won: bool) -> Array:
	var base_xp: int      = _xp_for_label(perf_label)
	var multiplier: float = XP_MULT.get(match_type, 1.0)
	if not won:
		multiplier *= XP_LOSS_MULT
	return _apply_xp(player, roundi(base_xp * multiplier))


static func award_action_xp(player: Player, action: String) -> Array:
	var gained: int = 0
	match action:
		"train":   gained = XP_TRAIN
	if gained == 0:
		return []
	return _apply_xp(player, gained)


static func xp_to_next_level(player: Player) -> int:
	if player.level >= MAX_LEVEL:
		return -1
	return LEVEL_THRESHOLDS[player.level] - player.xp


static func level_progress(player: Player) -> float:
	if player.level >= MAX_LEVEL:
		return 1.0
	return clampf(float(player.xp) / float(LEVEL_THRESHOLDS[player.level]), 0.0, 1.0)


# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

static func _xp_for_label(label: String) -> int:
	if "Carried"   in label: return XP_CARRIED
	if "Solid"     in label: return XP_SOLID
	return XP_STRUGGLED


static func _apply_xp(player: Player, amount: int) -> Array:
	player.xp       += amount
	player.xp_delta += amount
	var level_ups: Array = []

	while player.level < MAX_LEVEL:
		var threshold: int = LEVEL_THRESHOLDS[player.level]
		if player.xp < threshold:
			break

		player.xp    -= threshold
		player.level += 1

		var growth: Dictionary = TRAIT_GROWTH.get(player.primary_trait, TRAIT_GROWTH["none"])
		var skill_gain:   int = LEVEL_UP_SKILL_BASE   + randi_range(0, growth["skill"])
		var stamina_gain: int = LEVEL_UP_STAMINA_BASE + randi_range(0, growth["stamina"])
		var focus_gain:   int = LEVEL_UP_FOCUS_BASE   + randi_range(0, growth["focus"])
		var morale_gain:  int = LEVEL_UP_MORALE_BASE  + randi_range(0, growth["morale"])
		player.skill   = min(player.skill   + skill_gain,   100)
		player.stamina = min(player.stamina + stamina_gain, 100)
		player.focus   = min(player.focus   + focus_gain,   100)
		player.morale  = min(player.morale  + morale_gain,  100)

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
