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
# { player, score, raw_score, label, flavor, xp_gained, level, xp_progress,
#   study_consumed, patch_mult, synergy_bonus, breakdown }
var player_results: Array = []

# Array of bench outcome dicts:
# { player, action, stamina_gain, xp_gained, study_charges, charge_gain, narrative }
var bench_results: Array = []

# Level-up events fired this week.
var level_ups: Array = []

# Quarter bonus description if triggered.
var quarter_bonus: String = ""

# --- Trait Matchup data (for ResolutionScreen display) ---
var opponent_traits:      Array[String] = []   # 3 opponent trait slots
var situations:           Array[String] = []   # 2–3 match situations
var player_match_traits:  Array[String] = []   # each active player's match trait
var matchup_modifier:     float         = 0.0  # legacy preview number (-15..+15)

# --- New (multiplicative) match math signals from Simulation ---
var counter_ratio:        float = 0.0   # -1..+1 — fully countered → fully countering
var counter_mult:         float = 1.0   # team-score multiplier from counter pressure
var coverage_hits:        int   = 0     # phases covered by squad
var coverage_mult:        float = 1.0   # multiplier from situation coverage
var synergy_bonus_total:  int   = 0     # sum of synergy bonuses applied this match
var synergy_per_player:   Dictionary = {}   # name → bonus
var synergized_pairs:     Array         = []   # [[name_a, name_b], …] active pairs at synergy

# --- Patch + Study ---
var patch_buffed:         String = ""
var patch_nerfed:         String = ""
var study_used_by_player: Dictionary = {}   # name → charges consumed this match

# --- League data (for ResolutionScreen + hub display) ---
var league_rank:          int    = 0    # player rank after this week's results
