# systems/balance.gd
# ============================================================
# BALANCE — global access to the three split balance resources.
#
# Registered as autoload `Balance` (see project.godot).
#
# DESIGN PHILOSOPHY:
#   Replaces scripts/data/Tuning.gd. Where Tuning held all gameplay-balance
#   numbers as `const` fields on a single static class, Balance loads three
#   typed `.tres` resources and exposes them as `match`, `progression`, and
#   `league`. Same one-stop-shop feel; inspector-editable; hot-reloadable
#   when the .tres files are edited.
#
# CALL SITE MIGRATION:
#   Old: Tuning.STAMINA_COST_NORMAL
#   New: Balance.match_balance.stamina_cost_normal
#
# DOMAIN SPLIT:
#   `match_balance`       — MatchBalance:       stamina, morale, bench, counter,
#                                                coverage, patch, synergy, burnout
#   `progression_balance` — ProgressionBalance: XP, level thresholds, quarter bonus
#                                                (XP/level fields unused until a
#                                                future phase migrates LevelSystem)
#   `league_balance`      — LeagueBalance:      NPC strength, end-of-season rewards
#
# NAMING NOTE:
#   Properties carry the `_balance` suffix because `match` is a reserved
#   keyword in GDScript (the `match` statement). The plan canonicalises
#   the suffixed form: `Balance.match_balance.x`.
#
# SCOPE NOTE:
#   Phase B5 wired this in. The progression resource has fields declared
#   for the eventual LevelSystem migration; today only quarter_bonus_*
#   are read at runtime.
# ============================================================
extends Node

var match_balance:       MatchBalance       = preload("res://resources/balance/match_balance.tres")
var progression_balance: ProgressionBalance = preload("res://resources/balance/progression_balance.tres")
var league_balance:      LeagueBalance      = preload("res://resources/balance/league_balance.tres")


func _ready() -> void:
	assert(match_balance       != null, "Balance: failed to load match_balance.tres")
	assert(progression_balance != null, "Balance: failed to load progression_balance.tres")
	assert(league_balance      != null, "Balance: failed to load league_balance.tres")
