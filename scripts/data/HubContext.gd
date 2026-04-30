# scripts/data/HubContext.gd
# ============================================================
# HUB CONTEXT — typed replacement for the dict returned by
# GameManager.get_week_context().
#
# CURRENT DICT SHAPE (18 keys, called every UI refresh):
#   {
#     "week":                int,
#     "season":              int,
#     "absolute_week":       int,
#     "match_type":          String,
#     "difficulty":          String,        # display name (Easy/Medium/Hard/Very Hard)
#     "opponent_name":       String,
#     "opponent_traits":     Array[String], # 3 archetype keys
#     "situations":          Array[String], # 2–3 situation keys (early/mid/late)
#     "player_match_traits": Array[String], # active squad's archetype keys
#     "matchup_modifier":    float,         # legacy preview number, NOT in formula
#     "next_event":          Dictionary,    # { type, weeks_away } or {}
#     "squad_valid":         bool,
#     "game_over":           bool,
#     "win_estimate":        String,        # GameText.ESTIMATE_* string
#     "patch":               Dictionary,    # MetaPatch.get_patch(week)
#     "next_patch":          Dictionary,    # MetaPatch.next_patch(week)
#     "synergized_pairs":    Array,         # [[name_a, name_b], …]
#   }
#
# Field names below match the dict keys exactly so Phase B can do a
# literal type substitution. Three of the fields (next_event, patch,
# next_patch) stay as Dictionary for now — they have their own typed
# resource targets in MetaPatchEffect / WeekTemplate but those swaps
# can land independently in Phase B without coupling to this container.
#
# SCOPE: Phase A skeleton. Nothing reads from this yet; GameManager
# still returns a Dictionary until Phase B's WeekResolver replaces it.
# ============================================================
class_name HubContext
extends RefCounted


# ---------------------------------------------------------------------------
# CALENDAR / WEEK
# ---------------------------------------------------------------------------

var week:           int    = 1     # 1..WEEKS_PER_SEASON
var season:         int    = 1
var absolute_week:  int    = 1     # never resets (used by MetaPatch math)


# ---------------------------------------------------------------------------
# MATCH IDENTITY
# ---------------------------------------------------------------------------

var match_type: String = "normal"   # becomes MatchType enum in C3
var difficulty: String = ""         # display name from GameText.DIFFICULTY


# ---------------------------------------------------------------------------
# OPPONENT
# ---------------------------------------------------------------------------

var opponent_name:    String        = ""
var opponent_traits:  Array[String] = []   # 3 archetype keys


# ---------------------------------------------------------------------------
# SITUATIONS / PHASES
# ---------------------------------------------------------------------------

var situations: Array[String] = []   # 2–3 of: "early" | "mid" | "late"


# ---------------------------------------------------------------------------
# SQUAD CONTEXT
# ---------------------------------------------------------------------------

# Archetype keys of the currently-active squad. Order matches active_players().
var player_match_traits: Array[String] = []

# Legacy preview number (-15..+15). NOT fed into the simulation formula
# anymore; kept for backwards-compatible UI display only.
var matchup_modifier: float = 0.0


# ---------------------------------------------------------------------------
# CALENDAR LOOKAHEAD
# ---------------------------------------------------------------------------

# { "type": String, "weeks_away": int } or {} when no upcoming event.
# Stays Dictionary for Phase A — see header note.
var next_event: Dictionary = {}


# ---------------------------------------------------------------------------
# UI GATES
# ---------------------------------------------------------------------------

var squad_valid:  bool = false
var game_over:    bool = false
var win_estimate: String = ""   # GameText.ESTIMATE_FAVORED / ESTIMATE_EVEN / ESTIMATE_UNDERDOG


# ---------------------------------------------------------------------------
# META PATCH
# ---------------------------------------------------------------------------

# Active patch and the next one — both as Dictionary during Phase A.
# A future migration may replace both with a typed PatchPreview/MetaPatchEffect.
var patch:      Dictionary = {}
var next_patch: Dictionary = {}


# ---------------------------------------------------------------------------
# SYNERGY
# ---------------------------------------------------------------------------

# List of synergized pairs currently active in the squad: [[name_a, name_b], …]
var synergized_pairs: Array = []
