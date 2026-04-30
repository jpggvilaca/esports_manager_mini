# resources/player/player_data.gd
# ============================================================
# PLAYER DATA — typed authoring container for starter players.
#
# RATIONALE:
#   Today the starting roster is hardcoded in `GameManager._init()`:
#     var apex := Player.new("Apex", 50, 50, 65, 55, "clutch", "resilient")
#     apex.bio = "Mechanical prodigy who thrives under pressure..."
#     ...
#   This resource lets the starting roster be authored as `.tres` files in
#   the editor, dragged into a `starting_roster: Array[PlayerData]` slot
#   on GameDirector.
#
# RUNTIME vs AUTHORING:
#   `Player.gd` (RefCounted) keeps RUNTIME state — stamina, morale,
#   xp, study_charges, win_streak, form_history, etc. — fields that
#   change every match.
#   `PlayerData` (Resource) holds AUTHORING data — the spawn-time values.
#   GameDirector.start_new_game() will read PlayerData and produce a Player.
#
# SCOPE: Phase A skeleton. Optional in the plan but cheap to define now;
# saves a step during the B1 GameDirector handoff.
# ============================================================
@tool
class_name PlayerData
extends Resource


# ---------------------------------------------------------------------------
# IDENTITY
# ---------------------------------------------------------------------------

@export var player_name: String = ""
@export_multiline var bio: String = ""


# ---------------------------------------------------------------------------
# STARTING STATS
# Match the constructor argument order on Player.new() for easy migration.
# ---------------------------------------------------------------------------

@export var skill:   int = 40
@export var focus:   int = 45
@export var stamina: int = 60
@export var morale:  int = 50


# ---------------------------------------------------------------------------
# ARCHETYPES
# Stays as String during Phase A so it can be loaded by current code if
# needed during migration. Will become `primary_archetype: ArchetypeDefinition`
# once Phase C lands.
# ---------------------------------------------------------------------------

@export_enum("aggressive", "tactical", "focused", "clutch", "resilient", "volatile") \
	var primary_archetype_key: String = "tactical"

@export_enum("none", "resilient", "fragile") var minor_archetype: String = "none"


# ---------------------------------------------------------------------------
# STARTING BENCH ACTION
# Most starter players default to "rest". The legacy code seeds Byte
# (resilient endurance player) with "train" — that override is still
# expressible per-PlayerData.
# ---------------------------------------------------------------------------

@export_enum("rest", "train", "study") var bench_action: String = "rest"
