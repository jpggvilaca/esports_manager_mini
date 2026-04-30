# systems/signal_hub.gd
# ============================================================
# SIGNAL HUB — global signal vocabulary for the project.
#
# Registered as autoload `SignalHub` (see project.godot).
#
# DESIGN PHILOSOPHY:
#   This file declares the SIGNALS THE PROJECT CARES ABOUT — the events
#   that multiple unrelated systems may want to react to. It contains NO
#   logic, NO state, NO emitters. Emitters call `SignalHub.<signal>.emit(...)`
#   from wherever the state change actually happens; listeners connect in
#   their own `_ready()`.
#
# WHEN TO ADD A SIGNAL HERE:
#   - More than one unrelated system needs to react to the same event.
#   - The producer doesn't (and shouldn't) know who the consumers are.
#
# WHEN NOT TO ADD A SIGNAL HERE:
#   - Direct method calls work fine for pure queries (e.g. `league.player_rank()`).
#   - Internal coupling within one feature should use that feature's own
#     signals or methods, not the global hub.
#
# SCOPE NOTE:
#   This file is part of Phase A of the refactor (see REFACTOR_PLAN.md).
#   No code emits or listens to these signals YET — that wiring lands in
#   Phase B. The signals are declared first so the rest of the refactor
#   has a stable target vocabulary.
# ============================================================
extends Node


# ---------------------------------------------------------------------------
# WEEK / TURN LIFECYCLE
# ---------------------------------------------------------------------------

# Emitted after a full week has been resolved and the WeekResult is ready
# for consumption by the resolution screen, league overlay, etc.
# Payload: WeekResult
signal week_advanced(week_result)

# Emitted at the very end of the resolution pipeline, after side effects
# (XP, morale, league record) have been applied. UI should refresh state-
# dependent panels on this signal.
# Payload: WeekResult
signal match_resolved(week_result)


# ---------------------------------------------------------------------------
# ROSTER / SQUAD CHANGES
# ---------------------------------------------------------------------------

# The full roster array changed (player hired, fired, swapped via market).
# Payload: Array[Player]
signal roster_changed(players)

# The active/benched split changed without the roster itself changing
# (player toggled in/out of the squad).
# Payload: active: Array[Player], benched: Array[Player]
signal squad_changed(active, benched)

# A specific benched player switched bench action (rest/train/study).
# Payload: player: Player, action: String  (action will become BenchAction enum in C1)
signal bench_action_changed(player, action)


# ---------------------------------------------------------------------------
# STUDY CHARGES (knowledge-buff feature)
# ---------------------------------------------------------------------------

# A player just gained one or more study charges from a "study" bench action.
# Payload: player: Player, charges: int (current total after gain)
signal study_charge_gained(player, charges)

# A player just spent their study charges entering a match.
# Payload: player: Player, charges: int (count consumed this match)
signal study_charge_consumed(player, charges)


# ---------------------------------------------------------------------------
# PROGRESSION
# ---------------------------------------------------------------------------

# A player crossed a level threshold during XP application.
# Payload: player: Player, new_level: int
signal level_up(player, new_level)


# ---------------------------------------------------------------------------
# GOALS
# ---------------------------------------------------------------------------

# Season goal achieved this week. Banner-worthy.
# Payload: description: String
signal goal_achieved(description)

# Quarter-boundary bonus triggered. Distinct from goal_achieved because
# quarter bonuses are recurring and apply effects to active players.
# Payload: description: String
signal quarter_bonus_triggered(description)


# ---------------------------------------------------------------------------
# META PATCH ROTATION
# ---------------------------------------------------------------------------

# The active patch flipped to a new buffed/nerfed pair.
# Emitted at the start of a patch cycle (every PATCH_CYCLE_WEEKS weeks).
# Payload: buffed_archetype: String, nerfed_archetype: String
#          (will be ArchetypeDefinition refs once C3 lands)
signal patch_rotated(buffed_archetype, nerfed_archetype)


# ---------------------------------------------------------------------------
# SYNERGY
# ---------------------------------------------------------------------------

# A pair of players just crossed the synergy threshold.
# Fires once per pair, the moment they become synergized.
# Payload: name_a: String, name_b: String
signal synergy_formed(name_a, name_b)


# ---------------------------------------------------------------------------
# MARKET
# ---------------------------------------------------------------------------

# Market overlay was opened (candidates have been generated).
signal market_opened()

# A hire was confirmed: replaced_player swapped out, hired_player swapped in.
# Payload: replaced_player: Player, hired_player: Player
signal market_hire(replaced_player, hired_player)


# ---------------------------------------------------------------------------
# SEASON LIFECYCLE
# ---------------------------------------------------------------------------

# End-of-season tier rewards have been applied.
# Payload: rank: int, description: String
signal season_ended(rank, description)
