# scripts/data/MatchOutcome.gd
# ============================================================
# MATCH OUTCOME — typed replacement for the dict returned by
# Simulation.simulate_team().
#
# CURRENT DICT SHAPE (from Simulation.simulate_team's return):
#   {
#     "won":                   bool,
#     "team_score":            int,
#     "raw_team_score":        int,
#     "opponent_score":        int,
#     "players":               Array,        # of player_result dicts
#     "counter_ratio":         float,
#     "counter_mult":          float,
#     "coverage_hits":         int,
#     "coverage_mult":         float,
#     "synergy_bonus_total":   int,
#     "synergy_per_player":    Dictionary,   # name → bonus
#     "study_consumed_total":  int,
#   }
#
# Field names match the dict keys exactly. The `players` array is typed
# as Array[PlayerMatchOutcome] (was Array of dicts).
#
# SCOPE: Phase A skeleton. Nothing reads from this yet.
# ============================================================
class_name MatchOutcome
extends RefCounted


# ---------------------------------------------------------------------------
# OUTCOME
# ---------------------------------------------------------------------------

var won: bool = false


# ---------------------------------------------------------------------------
# SCORES
# ---------------------------------------------------------------------------

# Final team score the opponent threshold was compared against.
var team_score: int = 0

# Sum of raw per-player scores BEFORE team-level multipliers — useful for
# debug and the resolution screen breakdown.
var raw_team_score: int = 0

# Opponent threshold used for this match (already includes pre-match RNG
# wiggle from GameManager.advance_week).
var opponent_score: int = 0


# ---------------------------------------------------------------------------
# PER-PLAYER RESULTS — typed container per active player.
# ---------------------------------------------------------------------------

var players: Array[PlayerMatchOutcome] = []


# ---------------------------------------------------------------------------
# COUNTER PRESSURE — multiplicative team-score modifier from counter math.
# Range: counter_ratio ∈ [-1, +1]; counter_mult derived from it via
# Tuning.COUNTER_PENALTY_MAX / COUNTER_BONUS_MAX (will move to MatchBalance).
# ---------------------------------------------------------------------------

var counter_ratio: float = 0.0
var counter_mult:  float = 1.0


# ---------------------------------------------------------------------------
# SITUATION COVERAGE — small multiplicative bonus per phase covered.
# ---------------------------------------------------------------------------

var coverage_hits: int   = 0
var coverage_mult: float = 1.0


# ---------------------------------------------------------------------------
# SYNERGY — flat per-player bonuses from synergized pairs.
# ---------------------------------------------------------------------------

var synergy_bonus_total: int        = 0
var synergy_per_player:  Dictionary = {}    # player_name (String) → bonus (int)


# ---------------------------------------------------------------------------
# STUDY — total charges consumed across the squad this match.
# ---------------------------------------------------------------------------

var study_consumed_total: int = 0
