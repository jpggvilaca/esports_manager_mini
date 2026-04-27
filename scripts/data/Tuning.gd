# scripts/data/Tuning.gd
# ============================================================
# CENTRAL TUNING TABLE
#
# All gameplay-balance numbers live here. To rebalance the game,
# edit this file and nothing else.
#
# WHAT BELONGS HERE:
#   Numbers that govern match-to-match feel: how much stamina a match costs,
#   how much morale a win gives, what bench rest restores, how rewarding
#   each league tier finish is.
#
# WHAT DOES NOT BELONG HERE:
#   - Structural constants (WEEKS_PER_SEASON, SQUAD_SIZE, MARKET_INTERVAL)
#     → those stay with their owning systems; changing them changes shape, not feel.
#   - Trait identity numbers (variance modifiers, stamina floors)
#     → those stay in Simulation.gd where each trait's full identity is in one place.
#   - XP curve values (LEVEL_THRESHOLDS, XP_CARRIED, etc.)
#     → those stay in LevelSystem.gd as the progression table.
# ============================================================
class_name Tuning
extends RefCounted


# ---------------------------------------------------------------------------
# MATCH STAMINA COST
# Subtracted from each active player's stamina after a match.
# ---------------------------------------------------------------------------
const STAMINA_COST_NORMAL:    int = 13
const STAMINA_COST_IMPORTANT: int = 18   # important + tournament


# ---------------------------------------------------------------------------
# MATCH MORALE DELTA
# Added/subtracted from each active player's morale after a match.
# Clutch players get an extra +MORALE_CLUTCH_BONUS on important wins.
# ---------------------------------------------------------------------------
const MORALE_WIN_NORMAL:     int = 5
const MORALE_WIN_IMPORTANT:  int = 8
const MORALE_LOSS_NORMAL:    int = -5
const MORALE_LOSS_IMPORTANT: int = -8
const MORALE_CLUTCH_BONUS:   int = 3   # added to clutch trait wins on important matches


# ---------------------------------------------------------------------------
# BENCH OUTCOMES
# Applied each week to benched players based on their bench_action.
# Aggressive trait gets a faster rest recovery (their burn-rate is the cost).
# ---------------------------------------------------------------------------
const BENCH_REST_STAMINA:            int = 15
const BENCH_REST_STAMINA_AGGRESSIVE: int = 23
const BENCH_REST_MORALE:             int = 5
const BENCH_TRAIN_STAMINA_COST:      int = 5


# ---------------------------------------------------------------------------
# BURNOUT
# Per-player counter that rises on match played + bench train, falls on rest.
# At BURNOUT_WARNING_THRESHOLD the UI shows a warning. No mechanical penalty yet.
# ---------------------------------------------------------------------------
const BURNOUT_WARNING_THRESHOLD: int = 3


# ---------------------------------------------------------------------------
# LEAGUE END-OF-SEASON REWARDS
# Applied to all players based on final rank.
# ---------------------------------------------------------------------------
const LEAGUE_TOP_MORALE_BONUS:    int = 15   # +morale for rank 1–3
const LEAGUE_TOP_XP_BONUS:        int = 100  # +XP for rank 1–3
const LEAGUE_BOT_MORALE_PENALTY: int  = 10   # −morale for rank 7–8 (subtracted)


# ---------------------------------------------------------------------------
# QUARTER GOAL BONUS
# Applied to all active players when a quarter goal is achieved.
# ---------------------------------------------------------------------------
const QUARTER_BONUS_MORALE: int = 10
const QUARTER_BONUS_XP:     int = 50


# ---------------------------------------------------------------------------
# NPC LEAGUE STRENGTH
# Each NPC team gets a strength score representing their weekly win probability.
# Per-season ramp grows the field over time.
# ---------------------------------------------------------------------------
const NPC_STRENGTH_MIN:        int = 30   # weakest NPC % win rate
const NPC_STRENGTH_MAX:        int = 80   # strongest NPC % win rate
const NPC_SEASON_RAMP:         int = 5    # +strength per season (rivals improve)
const NPC_SEASON_RAMP_CAP:     int = 30   # max accumulated ramp
const NPC_STRENGTH_HARD_CAP:   int = 88   # ceiling so any team is beatable
