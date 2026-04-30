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
#   each league tier finish is, counter penalty severity, patch swings,
#   synergy threshold and bonus.
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
#
# bench_action values:
#   "rest"  → recover stamina + morale, drop burnout
#   "train" → gain a trickle of XP, lose a bit of stamina
#   "study" → gain a "Studied the Meta" buff that boosts the next match
#             played (more counter-modifier weight + small flat bonus).
# ---------------------------------------------------------------------------
const BENCH_REST_STAMINA:            int = 15
const BENCH_REST_STAMINA_AGGRESSIVE: int = 23
const BENCH_REST_MORALE:             int = 5
const BENCH_TRAIN_STAMINA_COST:      int = 5

# Studying — costs no stamina, but the player isn't recovering either.
# Each week of study adds a charge (capped). Charges are consumed on
# the next match the player plays, applying a multiplicative bonus to
# their per-player counter & coverage contribution.
const BENCH_STUDY_CHARGE_GAIN:    int   = 1
const BENCH_STUDY_MAX_CHARGES:    int   = 3
# Per-charge multiplier on the counter math for that player's first match
# back. 1 charge = +35% counter weight, 2 = +70%, 3 = +100%. Capped.
const STUDY_COUNTER_BONUS_PER_CHARGE: float = 0.35
# Small flat skill bump on the match the buff is consumed (knowledge buff).
const STUDY_FLAT_SKILL_BONUS:    int   = 4


# ---------------------------------------------------------------------------
# BURNOUT
# Per-player counter that rises on match played + bench train, falls on rest.
# At BURNOUT_WARNING_THRESHOLD the UI shows a warning. No mechanical penalty yet.
# ---------------------------------------------------------------------------
const BURNOUT_WARNING_THRESHOLD: int = 3


# ---------------------------------------------------------------------------
# COUNTER PRESSURE — multiplicative penalty/bonus on team score.
#
# This is what makes "Strategy > Power". Counter advantage is no longer
# a +/-15 nudge on the threshold; it is a multiplier on the team's score.
#
# Math (in Simulation.simulate_team after raw scores are computed):
#   counter_ratio = (counter_wins - counter_losses) / max_possible
#                   range -1.0 (fully countered) to +1.0 (fully countering)
#   multiplier    = 1.0 + COUNTER_PENALTY_MAX * counter_ratio
#                   when ratio < 0  (penalty side, capped at 1 - PENALTY_MAX)
#   multiplier    = 1.0 + COUNTER_BONUS_MAX  * counter_ratio
#                   when ratio > 0  (bonus side, capped at 1 + BONUS_MAX)
#
# A fully-countered team (every player gets counter-punished, none of theirs
# lands) is reduced to (1 - COUNTER_PENALTY_MAX) of their score.
#
# DEFAULT 0.50 → "fully countered" team plays at 50% effectiveness. Brutal,
# but matches the design brief: "If a Counter applies a 50% penalty to base
# stats, it forces the player to value Strategy > Power."
# ---------------------------------------------------------------------------
const COUNTER_PENALTY_MAX: float = 0.50   # max % score lost when fully countered
const COUNTER_BONUS_MAX:   float = 0.30   # max % score gained when fully countering

# Situation coverage gets a smaller multiplicative effect — counters dominate.
const SITUATION_COVERAGE_BONUS_PER_HIT: float = 0.04  # +4% per phase covered


# ---------------------------------------------------------------------------
# META PATCH (Game Patch every PATCH_CYCLE_WEEKS weeks)
#
# Every PATCH_CYCLE_WEEKS, a deterministic patch picks one buffed trait and
# one nerfed trait. Players whose primary_trait matches the buffed trait
# multiply their player score by (1 + PATCH_BUFF_PCT). Nerfed trait players
# multiply by (1 - PATCH_NERF_PCT).
#
# Tuned so the patch is significant but not crushing — enough to make
# benching a nerfed star and starting a buffed bench player a real choice.
# ---------------------------------------------------------------------------
const PATCH_CYCLE_WEEKS: int   = 4    # patch flips every N absolute weeks
const PATCH_BUFF_PCT:    float = 0.20 # +20% on player score for buffed trait
const PATCH_NERF_PCT:    float = 0.20 # -20% on player score for nerfed trait


# ---------------------------------------------------------------------------
# SYNERGY
#
# Two players who play together build "synergy" over time. After
# SYNERGY_THRESHOLD shared matches, the unordered pair earns a flat per-player
# bonus added to each of their match scores whenever both are active.
#
# Stacking: in a 3-player squad, up to 3 unordered pairs can form. Each
# qualifying pair adds SYNERGY_BONUS_PER_PAIR per player, with diminishing
# returns past the first pair (multiplied by SYNERGY_STACK_DIMINISH^n).
#
# Practical effect: a fully synergized 3-player squad gives every player
# roughly +12 score. Decisive but not match-breaking on its own.
# ---------------------------------------------------------------------------
const SYNERGY_THRESHOLD:        int   = 5     # matches together to form synergy
const SYNERGY_BONUS_PER_PAIR:   int   = 5     # flat score bonus per active pair
const SYNERGY_STACK_DIMINISH:   float = 0.7   # second pair counts ×0.7, third ×0.49


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
