# scripts/data/Calendar.gd
# Season calendar — pure data + lookup logic. No UI, no game state.
#
# Structure:
#   - One season = WEEKS_PER_SEASON weeks, repeating the same template.
#   - Difficulty scales each season via a per-season multiplier.
#   - MAX_SEASONS caps how long the game runs (set to -1 for infinite).
#
# To tune: change WEEKS_PER_SEASON, MAX_SEASONS, or the WEEK_TEMPLATE entries.
# To add a new week pattern: add an entry to WEEK_TEMPLATE.
class_name Calendar
extends RefCounted

# --- Configuration (edit these freely) ---
const WEEKS_PER_SEASON: int = 24   # weeks in one full season
const MAX_SEASONS:      int = 10   # -1 = infinite
# How much harder each season gets (multiplied onto opponent base score).
# Season 1 = ×1.0, Season 2 = ×1.08, Season 3 = ×1.16, etc.
const SEASON_DIFFICULTY_STEP: float = 0.08

# --- Match type constants ---
const TYPE_NORMAL:     String = "normal"
const TYPE_IMPORTANT:  String = "important"
const TYPE_TOURNAMENT: String = "tournament"

# --- Week template (repeats every season) ---
# opponent: base score at season-1 difficulty (scaled up in later seasons)
# type:     normal | important | tournament
# label:    difficulty label key into GameText.OPPONENT_STRENGTH
#
# 24-week season structure:
#   Weeks  1–6:  Early grind (easy normals, first important)
#   Weeks  7–12: Mid-season (medium difficulty, second tournament)
#   Weeks 13–18: Late season (hard, third important)
#   Weeks 19–24: Season finale (very hard, two tournaments)
const WEEK_TEMPLATE: Array[Dictionary] = [
	# Block 1 — Early grind
	{ "type": TYPE_NORMAL,     "opponent": 145, "label": "weak"     },  #  1
	{ "type": TYPE_NORMAL,     "opponent": 150, "label": "weak"     },  #  2
	{ "type": TYPE_NORMAL,     "opponent": 158, "label": "weak"     },  #  3
	{ "type": TYPE_IMPORTANT,  "opponent": 168, "label": "average"  },  #  4 ★
	{ "type": TYPE_NORMAL,     "opponent": 160, "label": "average"  },  #  5
	{ "type": TYPE_NORMAL,     "opponent": 165, "label": "average"  },  #  6

	# Block 2 — Mid-season
	{ "type": TYPE_NORMAL,     "opponent": 170, "label": "average"  },  #  7
	{ "type": TYPE_NORMAL,     "opponent": 175, "label": "average"  },  #  8
	{ "type": TYPE_IMPORTANT,  "opponent": 185, "label": "strong"   },  #  9 ★
	{ "type": TYPE_NORMAL,     "opponent": 178, "label": "strong"   },  # 10
	{ "type": TYPE_NORMAL,     "opponent": 183, "label": "strong"   },  # 11
	{ "type": TYPE_TOURNAMENT, "opponent": 205, "label": "dominant" },  # 12 🏆

	# Block 3 — Late season
	{ "type": TYPE_NORMAL,     "opponent": 185, "label": "strong"   },  # 13
	{ "type": TYPE_NORMAL,     "opponent": 190, "label": "strong"   },  # 14
	{ "type": TYPE_IMPORTANT,  "opponent": 200, "label": "dominant" },  # 15 ★
	{ "type": TYPE_NORMAL,     "opponent": 192, "label": "strong"   },  # 16
	{ "type": TYPE_NORMAL,     "opponent": 198, "label": "dominant" },  # 17
	{ "type": TYPE_IMPORTANT,  "opponent": 208, "label": "dominant" },  # 18 ★

	# Block 4 — Season finale
	{ "type": TYPE_NORMAL,     "opponent": 200, "label": "dominant" },  # 19
	{ "type": TYPE_NORMAL,     "opponent": 205, "label": "dominant" },  # 20
	{ "type": TYPE_IMPORTANT,  "opponent": 215, "label": "dominant" },  # 21 ★
	{ "type": TYPE_NORMAL,     "opponent": 208, "label": "dominant" },  # 22
	{ "type": TYPE_TOURNAMENT, "opponent": 225, "label": "dominant" },  # 23 🏆
	{ "type": TYPE_TOURNAMENT, "opponent": 235, "label": "dominant" },  # 24 🏆🏆
]


# Returns the calendar entry for a given absolute week number (1-based).
# Scales opponent score based on current season number.
static func get_week(absolute_week: int) -> Dictionary:
	var season:       int = get_season(absolute_week)
	var week_in_season: int = get_week_in_season(absolute_week)
	var template_idx: int = clamp(week_in_season - 1, 0, WEEK_TEMPLATE.size() - 1)
	var template:     Dictionary = WEEK_TEMPLATE[template_idx].duplicate()

	# Scale opponent score: each season multiplies by (1 + step * (season - 1))
	var scale: float = 1.0 + SEASON_DIFFICULTY_STEP * (season - 1)
	template["opponent"] = int(template["opponent"] * scale)
	template["season"]   = season
	template["week_in_season"] = week_in_season

	return template


# Current season number (1-based) given absolute week.
static func get_season(absolute_week: int) -> int:
	return int((absolute_week - 1) / WEEKS_PER_SEASON) + 1


# Week number within the current season (1-based).
static func get_week_in_season(absolute_week: int) -> int:
	return ((absolute_week - 1) % WEEKS_PER_SEASON) + 1


# True when the game has run past the configured season limit.
static func is_game_over(absolute_week: int) -> bool:
	if MAX_SEASONS == -1:
		return false
	return get_season(absolute_week) > MAX_SEASONS
