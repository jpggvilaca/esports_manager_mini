# scripts/data/BenchOutcome.gd
# ============================================================
# BENCH OUTCOME — typed replacement for the dict returned by
# GameManager._resolve_bench().
#
# CURRENT DICT SHAPE (from GameManager._resolve_bench):
#   {
#     "player":        Player,
#     "action":        String,    # "rest" | "train" | "study"
#     "stamina_gain":  int,
#     "xp_gained":     int,
#     "study_charges": int,       # post-action total
#     "charge_gain":   int,       # only present on study branch (+0..+1)
#     "level_ups":     Array,
#     "narrative":     String,
#   }
#
# Field names below match the legacy dict keys exactly so Phase B can do
# a literal type substitution without reaching into UI code.
#
# SCOPE: Phase A skeleton. Nothing reads from this yet — the real wiring
# lands in step B2 when WeekResolver replaces the legacy `_resolve_bench()`.
# ============================================================
class_name BenchOutcome
extends RefCounted


# Reference to the player this outcome belongs to.
var player: Player = null

# Bench action that produced this outcome. Stays as String during Phase A
# so it stays compatible with the legacy field on Player; becomes a
# `BenchAction` enum once C1 lands.
var action: String = "rest"

# Stamina delta applied this week (positive on rest, ~0 on study, negative on train).
var stamina_gain: int = 0

# XP awarded this week. Only the train branch awards XP today.
var xp_gained: int = 0

# Player's total study charges AFTER this action resolved.
# Carried even on rest/train branches so callers don't have to re-read player.
var study_charges: int = 0

# Charges newly added this week. 0 except on the "study" branch.
var charge_gain: int = 0

# Level-up events triggered by xp_gained, in the same shape produced by
# LevelSystem._apply_xp() (Array of dicts). Phase A keeps this loose; a
# future phase may type the level-up events too.
var level_ups: Array = []

# One-line narrative shown on the resolution screen.
var narrative: String = ""
