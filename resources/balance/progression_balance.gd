# resources/balance/progression_balance.gd
# ============================================================
# PROGRESSION BALANCE — XP, level-up, and quarter-bonus tuning.
#
# This is one of three split balance resources replacing Tuning.gd.
#
# DOMAIN: Long-arc progression. The numbers a designer touches once per
# major content update — XP curves, how fast players level, how much each
# trait grows on level-up, quarter goal rewards.
#
# WHAT GOES ELSEWHERE:
#   - Match-feel numbers (stamina, morale, counters) → MatchBalance
#   - NPC strength and end-of-season rewards         → LeagueBalance
#
# SCOPE: Phase A skeleton. Properties declared, NO VALUES YET. Migration
# happens in B5; until then LevelSystem.gd's constants and Tuning.gd's
# QUARTER_BONUS_* remain authoritative.
#
# AUTHORING TARGET:
#   res://resources/balance/progression_balance.tres (created during B5).
# ============================================================
@tool
class_name ProgressionBalance
extends Resource


# ---------------------------------------------------------------------------
# XP REWARDS — per-match XP by performance label.
# Migrating from: LevelSystem.XP_CARRIED / XP_SOLID / XP_STRUGGLED / XP_TRAIN
#                 LevelSystem.XP_MULT  (per match-type)
#                 LevelSystem.XP_LOSS_MULT
# ---------------------------------------------------------------------------

@export var xp_carried:   int = 0    # Outstanding performance
@export var xp_solid:     int = 0
@export var xp_struggled: int = 0
@export var xp_train:     int = 0    # bench train action

# Match-type multipliers (normal=1.0, important=1.5, tournament=3.0, solo=1.5)
@export var xp_mult_normal:     float = 0.0
@export var xp_mult_important:  float = 0.0
@export var xp_mult_tournament: float = 0.0
@export var xp_mult_solo:       float = 0.0

@export_range(0.0, 1.0, 0.01) var xp_loss_mult: float = 0.0


# ---------------------------------------------------------------------------
# LEVEL THRESHOLDS — XP needed to advance to the next level.
# Migrating from: LevelSystem.LEVEL_THRESHOLDS
# Index 0 is unused (level 0 doesn't exist); index N is "XP to go from
# level N to level N+1".
# ---------------------------------------------------------------------------

@export var level_thresholds: Array[int] = []
@export var max_level: int = 10


# ---------------------------------------------------------------------------
# LEVEL-UP BASE GAINS — flat amount added to every level-up before the
# per-archetype `randi_range(0, growth_bonus)` rolls.
# Migrating from: LevelSystem.LEVEL_UP_*_BASE
# (Per-archetype random bonus comes from ArchetypeDefinition.growth.)
# ---------------------------------------------------------------------------

@export var level_up_skill_base:   int = 0
@export var level_up_stamina_base: int = 0
@export var level_up_focus_base:   int = 0
@export var level_up_morale_base:  int = 0


# ---------------------------------------------------------------------------
# QUARTER GOAL REWARDS — applied to active players when a quarter goal hits.
# Migrating from: Tuning.QUARTER_BONUS_MORALE / QUARTER_BONUS_XP
# ---------------------------------------------------------------------------

@export var quarter_bonus_morale: int = 0
@export var quarter_bonus_xp:     int = 0
