class_name LevelSystem
extends RefCounted


# --- XP awarded per performance tier after a match ---
const XP_CARRIED:   int = 100
const XP_SOLID:     int = 50
const XP_STRUGGLED: int = 20

# --- XP awarded per action taken (no match required) ---
const XP_TRAIN: int = 10
const XP_SCRIM: int = 20
const XP_REST:  int = 0   # rest gives nothing — intentional design

# --- Match type XP multipliers ---
const XP_MULT: Dictionary = {
	"normal":     1.0,
	"important":  1.5,
	"tournament": 3.0,   # raised from 2.0 — tournament is the climax
	"solo":       1.5,   # same stakes as important
}

# --- Loss XP penalty: multiply earned XP by this on a loss ---
# Player still gains something — losing teaches too — but far less.
const XP_LOSS_MULT: float = 0.35

# --- Level thresholds: XP needed to reach each level (index = target level) ---
# Index 0 unused. Level 1→2 costs 100, 2→3 costs 150, etc.
# Add more entries to extend the level cap.
const LEVEL_THRESHOLDS: Array[int] = [
	0,    # placeholder — no level 0
	100,  # Level 1 → 2
	150,  # Level 2 → 3
	200,  # Level 3 → 4
	260,  # Level 4 → 5
	330,  # Level 5 → 6
	410,  # Level 6 → 7
	500,  # Level 7 → 8
	600,  # Level 8 → 9
	710,  # Level 9 → 10
]

const MAX_LEVEL: int = 10  # level cap — must equal LEVEL_THRESHOLDS.size() - 1 to avoid OOB reads

# --- Stat bonuses granted on level up ---
const LEVEL_UP_SKILL_BONUS: int = 2   # always granted
const LEVEL_UP_FOCUS_BONUS: int = 1   # granted on even levels only (2, 4, 6...)


# Award match XP to a player based on their performance label and match type.
# Mutates player.xp and handles level-ups. Returns list of level-up dicts.
static func award_match_xp(player: Player, perf_label: String, match_type: String) -> Array:
	var base_xp: int = _xp_for_label(perf_label)
	var mult: float  = XP_MULT.get(match_type, 1.0)
	var gained: int  = int(base_xp * mult)
	return _apply_xp(player, gained)


# Like award_match_xp but applies loss penalty when the team lost.
# Use this in all match paths so loss consequences are consistent.
static func award_match_xp_with_result(player: Player, perf_label: String, match_type: String, won: bool) -> Array:
	var base_xp: int = _xp_for_label(perf_label)
	var mult: float  = XP_MULT.get(match_type, 1.0)
	if not won:
		mult *= XP_LOSS_MULT
	var gained: int  = int(base_xp * mult)
	return _apply_xp(player, gained)


# Award action XP (train/scrim). Returns list of level-up dicts (rare but possible).
static func award_action_xp(player: Player, action: String) -> Array:
	var gained: int = 0
	
	match action:
		"train": gained = XP_TRAIN
		"scrim": gained = XP_SCRIM
		
	if gained == 0:
		return []
		
	return _apply_xp(player, gained)


# Returns XP to next level, or -1 if at max level.
static func xp_to_next_level(player: Player) -> int:
	if player.level >= MAX_LEVEL:
		return -1
		
	return LEVEL_THRESHOLDS[player.level] - player.xp


# Returns progress fraction 0.0→1.0 toward next level.
static func level_progress(player: Player) -> float:
	if player.level >= MAX_LEVEL:
		return 1.0
		
	var threshold: int = LEVEL_THRESHOLDS[player.level]
	
	return clampf(float(player.xp) / float(threshold), 0.0, 1.0)


# --- Private helpers ---

static func _xp_for_label(label: String) -> int:
	if "Carried" in label:   return XP_CARRIED
	if "Solid"   in label:   return XP_SOLID
	
	return XP_STRUGGLED


static func _apply_xp(player: Player, amount: int) -> Array:
	player.xp      += amount
	player.xp_delta += amount  # accumulate — action XP may have already been set
	var level_ups: Array = []

	# Process level-ups one at a time (could gain multiple in one step theoretically)
	while player.level < MAX_LEVEL:
		var threshold: int = LEVEL_THRESHOLDS[player.level]
		
		if player.xp < threshold:
			break
			
		player.xp    -= threshold
		player.level += 1

		# Stat bonuses on level up
		var skill_gain: int = LEVEL_UP_SKILL_BONUS
		var focus_gain: int = LEVEL_UP_FOCUS_BONUS if (player.level % 2 == 0) else 0
		player.skill = min(player.skill + skill_gain, 100)
		player.focus = min(player.focus + focus_gain, 100)

		level_ups.append({
			"player_name": player.player_name,
			"new_level":   player.level,
			"skill_gain":  skill_gain,
			"focus_gain":  focus_gain,
		})

	return level_ups
