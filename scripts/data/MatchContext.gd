# scripts/data/MatchContext.gd
# ============================================================
# MATCH CONTEXT — typed bundle of per-week match parameters.
#
# RATIONALE (Phase B2):
#   Created to give WeekResolver.simulate_match() a single typed argument
#   instead of 6 loose parameters. Holds everything that is "looked up"
#   for a week BEFORE the match runs: calendar entry, opponent traits,
#   situations, importance flag, opponent score (post-RNG), active patch.
#
# DIFFERENCES FROM HubContext:
#   HubContext is the UI-facing snapshot used by the hub screen for
#   pre-match display (includes win_estimate, next_event, synergized_pairs,
#   etc.). MatchContext is the resolver's internal handoff between the
#   `generate_match_context` and `simulate_match` phases.
#
# DIFFERENCES FROM WeekResult:
#   WeekResult is the OUTPUT of advance_week. MatchContext is an
#   INTERMEDIATE produced part-way through the pipeline.
#
# SCOPE: Created in B2 with the WeekResolver split. RefCounted (not
# Resource) — same reasoning as BenchOutcome / MatchOutcome: per-call
# throwaway, not authored as .tres.
# ============================================================
class_name MatchContext
extends RefCounted


# ---------------------------------------------------------------------------
# CALENDAR
# ---------------------------------------------------------------------------

# Absolute week number (1-based, never resets).
var absolute_week: int = 1

# Week within the current season (1..WEEKS_PER_SEASON).
var week_in_season: int = 1

# Current season number (1, 2, 3, ...).
var season: int = 1

# Match type: "normal" | "important" | "tournament" | "solo".
# Stays as String during Phase B; becomes MatchType enum in C3.
var match_type: String = "normal"

# Difficulty label from Calendar ("weak" | "average" | "strong" | "dominant").
# Used to bias opponent name and trait pool.
var difficulty_label: String = ""

# Whether this match counts as "important" for clutch / focused / morale logic.
# True for important + tournament match types.
var is_important: bool = false


# ---------------------------------------------------------------------------
# OPPONENT
# ---------------------------------------------------------------------------

# Final opponent threshold score, including the ±10 RNG wiggle applied
# at simulation time. This is the value the team score is compared against.
var opponent_score: int = 0

# 3 archetype keys representing the opponent's trait slots.
var opponent_traits: Array[String] = []


# ---------------------------------------------------------------------------
# SITUATIONS
# ---------------------------------------------------------------------------

# 2-3 situation keys ("early" | "mid" | "late") representing match phases.
var situations: Array[String] = []


# ---------------------------------------------------------------------------
# SQUAD
# ---------------------------------------------------------------------------

# Active squad's archetype keys, in active_players() order.
# Populated for matchup_modifier preview computation.
var player_match_traits: Array[String] = []

# Legacy preview number (-15..+15). NOT fed into the formula.
# Kept for backwards-compatible UI display only.
var matchup_modifier: int = 0


# ---------------------------------------------------------------------------
# META PATCH
# ---------------------------------------------------------------------------

# Current patch dict (from MetaPatch.get_patch). Stays Dictionary during
# Phase B; becomes MetaPatchEffect typed reference in a future content phase.
var patch: Dictionary = {}
