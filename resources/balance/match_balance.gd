# resources/balance/match_balance.gd
# ============================================================
# MATCH BALANCE — match-feel tuning numbers (highest edit cadence).
#
# This is one of three split balance resources replacing Tuning.gd.
# Together they cover everything currently in scripts/data/Tuning.gd.
#
# DOMAIN: Match-to-match feel. The numbers a designer touches every
# balance pass: how much stamina a match costs, how much morale a win
# gives, how brutal the counter penalty is, how strong a synergy bonus
# is. These are the "tuning knobs" of moment-to-moment play.
#
# WHAT GOES ELSEWHERE:
#   - XP curves and level-up stat gains  → ProgressionBalance
#   - NPC strength and end-of-season tier rewards → LeagueBalance
#
# SCOPE: Phase A skeleton. Properties declared, NO VALUES YET. Tuning.gd
# remains the source of truth for runtime code until step B5 ports the
# values across and deletes Tuning.gd.
#
# AUTHORING TARGET:
#   The intended `.tres` instance is res://resources/balance/match_balance.tres
#   (created during B5).
# ============================================================
@tool
class_name MatchBalance
extends Resource


# ---------------------------------------------------------------------------
# STAMINA COSTS — applied to active players after a match.
# Migrating from: Tuning.STAMINA_COST_NORMAL / STAMINA_COST_IMPORTANT
# ---------------------------------------------------------------------------

@export var stamina_cost_normal:    int = 0
@export var stamina_cost_important: int = 0


# ---------------------------------------------------------------------------
# MORALE DELTAS — match win/loss morale changes.
# Migrating from: Tuning.MORALE_WIN_NORMAL / WIN_IMPORTANT / LOSS_NORMAL /
#                  LOSS_IMPORTANT / MORALE_CLUTCH_BONUS
# ---------------------------------------------------------------------------

@export var morale_win_normal:     int = 0
@export var morale_win_important:  int = 0
@export var morale_loss_normal:    int = 0
@export var morale_loss_important: int = 0
@export var morale_clutch_bonus:   int = 0


# ---------------------------------------------------------------------------
# BENCH OUTCOMES — applied to benched players based on their bench_action.
# Migrating from: Tuning.BENCH_REST_STAMINA / *_AGGRESSIVE / BENCH_REST_MORALE
#                  BENCH_TRAIN_STAMINA_COST
#                  BENCH_STUDY_CHARGE_GAIN / BENCH_STUDY_MAX_CHARGES
#                  STUDY_COUNTER_BONUS_PER_CHARGE / STUDY_FLAT_SKILL_BONUS
# ---------------------------------------------------------------------------

@export var bench_rest_stamina:            int = 0
@export var bench_rest_stamina_aggressive: int = 0
@export var bench_rest_morale:             int = 0

@export var bench_train_stamina_cost:      int = 0

@export var bench_study_charge_gain: int = 0
@export var bench_study_max_charges: int = 0
@export var study_counter_bonus_per_charge: float = 0.0
@export var study_flat_skill_bonus: int = 0


# ---------------------------------------------------------------------------
# BURNOUT — UI-warning threshold (no mechanical penalty yet).
# Migrating from: Tuning.BURNOUT_WARNING_THRESHOLD
# ---------------------------------------------------------------------------

@export var burnout_warning_threshold: int = 0


# ---------------------------------------------------------------------------
# COUNTER PRESSURE — multiplicative team-score modifier from counter math.
# Migrating from: Tuning.COUNTER_PENALTY_MAX / COUNTER_BONUS_MAX
#                  SITUATION_COVERAGE_BONUS_PER_HIT
# ---------------------------------------------------------------------------

@export_range(0.0, 1.0, 0.01) var counter_penalty_max: float = 0.0
@export_range(0.0, 1.0, 0.01) var counter_bonus_max:   float = 0.0
@export_range(0.0, 0.5, 0.01) var situation_coverage_bonus_per_hit: float = 0.0


# ---------------------------------------------------------------------------
# META PATCH — buff/nerf percentages and cycle length.
# Migrating from: Tuning.PATCH_CYCLE_WEEKS / PATCH_BUFF_PCT / PATCH_NERF_PCT
# ---------------------------------------------------------------------------

@export var patch_cycle_weeks: int   = 0
@export_range(0.0, 1.0, 0.01) var patch_buff_pct: float = 0.0
@export_range(0.0, 1.0, 0.01) var patch_nerf_pct: float = 0.0


# ---------------------------------------------------------------------------
# SYNERGY — co-play bonus mechanics.
# Migrating from: Tuning.SYNERGY_THRESHOLD / SYNERGY_BONUS_PER_PAIR /
#                  SYNERGY_STACK_DIMINISH
# ---------------------------------------------------------------------------

@export var synergy_threshold:      int   = 0
@export var synergy_bonus_per_pair: int   = 0
@export_range(0.0, 1.0, 0.01) var synergy_stack_diminish: float = 0.0
