# scripts/data/WeekResult.gd
# Data container for a full week's resolution output.
# Passed from GameManager.advance_week() to the resolution screen.
class_name WeekResult
extends RefCounted

var week:           int    = 1
var season:         int    = 1
var match_type:     String = "normal"
var won:            bool   = false
var team_score:     int    = 0
var opponent_score: int    = 0

# Array of per-player match result dicts:
# { player, score, label, flavor, xp_gained, level, xp_progress }
var player_results: Array = []

# Array of bench outcome dicts:
# { player, action, stamina_gain, xp_gained, narrative }
var bench_results: Array = []

# Level-up events fired this week.
var level_ups: Array = []

# Quarter bonus description if triggered.
var quarter_bonus: String = ""

# --- Trait Matchup data (for ResolutionScreen display) ---
var opponent_traits:      Array[String] = []   # 3 opponent trait slots
var situations:           Array[String] = []   # 2–3 match situations
var player_match_traits:  Array[String] = []   # each active player's match trait
var matchup_modifier:     float         = 0.0  # positive = player advantage

# --- League data (for ResolutionScreen + hub display) ---
var league_rank:          int    = 0    # player rank after this week's results

