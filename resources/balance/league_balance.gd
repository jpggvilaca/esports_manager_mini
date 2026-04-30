# resources/balance/league_balance.gd
# ============================================================
# LEAGUE BALANCE — NPC strength and end-of-season tier rewards.
#
# This is one of three split balance resources replacing Tuning.gd.
#
# DOMAIN: Season meta-progression. The numbers a designer essentially
# writes once and rarely revisits — how strong NPC teams are, how the
# difficulty ramps each season, what tier rewards you earn at the end.
#
# WHAT GOES ELSEWHERE:
#   - Match-feel numbers (stamina, morale, counters) → MatchBalance
#   - XP curves and quarter rewards                  → ProgressionBalance
#
# SCOPE: Phase A skeleton. Properties declared, NO VALUES YET. Migration
# happens in B5; Tuning.gd remains authoritative until then.
#
# AUTHORING TARGET:
#   res://resources/balance/league_balance.tres (created during B5).
# ============================================================
@tool
class_name LeagueBalance
extends Resource


# ---------------------------------------------------------------------------
# NPC STRENGTH — weekly win-probability range for the 7 NPC teams.
# Migrating from: Tuning.NPC_STRENGTH_MIN / NPC_STRENGTH_MAX /
#                 NPC_SEASON_RAMP / NPC_SEASON_RAMP_CAP / NPC_STRENGTH_HARD_CAP
# ---------------------------------------------------------------------------

@export var npc_strength_min:        int = 0
@export var npc_strength_max:        int = 0
@export var npc_season_ramp:         int = 0    # +strength per season
@export var npc_season_ramp_cap:     int = 0    # max accumulated ramp
@export var npc_strength_hard_cap:   int = 0    # absolute ceiling


# ---------------------------------------------------------------------------
# END-OF-SEASON TIER REWARDS — applied to all players based on final rank.
# Migrating from: Tuning.LEAGUE_TOP_MORALE_BONUS / LEAGUE_TOP_XP_BONUS /
#                 LEAGUE_BOT_MORALE_PENALTY
# ---------------------------------------------------------------------------

@export var league_top_morale_bonus:    int = 0    # +morale for rank 1–3
@export var league_top_xp_bonus:        int = 0    # +XP for rank 1–3
@export var league_bot_morale_penalty:  int = 0    # subtracted from rank 7–8
