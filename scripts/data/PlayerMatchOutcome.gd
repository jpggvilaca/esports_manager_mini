# scripts/data/PlayerMatchOutcome.gd
# ============================================================
# PLAYER MATCH OUTCOME — typed replacement for one entry in the
# `players` array returned by Simulation.simulate_team().
#
# CURRENT DICT SHAPE (from Simulation.simulate_team's player_results loop):
#   {
#     "player":        Player,
#     "score":         int,        # final per-player score (post counter+coverage+synergy)
#     "raw_score":     int,        # score BEFORE team-level multipliers
#     "label":         String,     # "🔥 Carried" | "✅ Solid" | "😬 Struggled"
#     "flavor":        String,     # picked from GameText.FLAVOR
#     "trait_trigger": String,     # e.g. "⚡ Clutch moment"
#     "breakdown":     Array,      # [{ reason, delta }, ...]
#     "study_consumed":int,        # charges spent on this match
#     "patch_mult":    float,      # buff/nerf applied this match
#     "synergy_bonus": int,        # flat bonus from synergized pairs
#     "xp_gained":     int,        # populated by GameManager AFTER simulate
#     "level":         int,        # populated by GameManager AFTER simulate
#     "xp_progress":   float,      # populated by GameManager AFTER simulate
#   }
#
# Note that the last three fields (xp_gained, level, xp_progress) are
# CURRENTLY mutated into the dict by GameManager.advance_week() AFTER
# Simulation returns. The typed container preserves that pattern but
# makes it explicit which fields are simulation-time vs post-match.
#
# SCOPE: Phase A skeleton. Nothing reads from this yet.
# ============================================================
class_name PlayerMatchOutcome
extends RefCounted


# ---------------------------------------------------------------------------
# SIMULATION-TIME FIELDS (populated by Simulation)
# ---------------------------------------------------------------------------

var player: Player = null

# Final per-player score after team-level counter, coverage, synergy effects.
var score: int = 0

# Per-player score BEFORE team-level multipliers — kept for debug + UI breakdowns.
var raw_score: int = 0

# Performance label and narrative flavor chosen by MatchFlavorGenerator.
var label:         String = ""
var flavor:        String = ""
var trait_trigger: String = ""

# Score delta breakdown — each entry: { "reason": String, "delta": int }
var breakdown: Array = []

# Study charges this player burned for this match (0 if they didn't have any).
var study_consumed: int = 0

# Multiplicative buff/nerf applied this match per the active patch.
var patch_mult: float = 1.0

# Flat synergy bonus from this player's synergized pair contributions.
var synergy_bonus: int = 0


# ---------------------------------------------------------------------------
# POST-MATCH FIELDS (populated by GameManager.advance_week's XP loop)
# These are filled in AFTER Simulation returns.
# ---------------------------------------------------------------------------

var xp_gained:   int   = 0
var level:       int   = 0
var xp_progress: float = 0.0
