# resources/archetype/archetype_definition.gd
# ============================================================
# ARCHETYPE DEFINITION — the typed home of "what an archetype IS".
#
# Replaces the scattered string-keyed tables currently spread across:
#   - TraitMatchup.WINS_AGAINST / LOSES_AGAINST       (counter ring)
#   - TraitMatchup.SITUATION_FAVORS                   (phase mapping)
#   - GameText.TRAIT_ICONS / TRAIT_NAMES /
#     TRAIT_TOOLTIPS / TRAIT_COUNTERS                  (display strings)
#   - LevelSystem.TRAIT_GROWTH                        (level-up bonuses)
#   - Simulation match block                          (variance, stamina floor)
#
# In the legacy code this concept was called "trait", but `trait` is
# reserved in GDScript 4.x — hence "archetype" throughout the refactor.
# Display copy ("Aggressive trait", "trait counters", etc.) stays in
# `GameText.gd` unchanged; only identifiers move.
#
# SCOPE: Phase A skeleton. Properties are declared so editor authoring
# can begin; no runtime code reads from these resources yet. The wiring
# lands in Phase B once GameDirector and WeekResolver exist to consume
# them.
#
# AUTHORING NOTES:
#   - `key` is the canonical identifier, matching the legacy strings:
#       aggressive | tactical | focused | clutch | resilient | volatile
#     This is what the migration step (B-something) will look up by.
#   - `counters` and `weak_to` are arrays of OTHER ArchetypeDefinition
#     resources. Volatile is intentionally absent from both — neutral
#     counter relationship.
#   - `phase` is the Early/Mid/Late slot this archetype is favored in,
#     or "" for none (focused, resilient, volatile have no phase).
# ============================================================
@tool
class_name ArchetypeDefinition
extends Resource


# ---------------------------------------------------------------------------
# IDENTITY
# ---------------------------------------------------------------------------

@export var key:          StringName = &""
@export var display_name: String     = ""
@export var icon:         String     = ""    # emoji + spacing, matches GameText.TRAIT_ICONS
@export_multiline var tooltip: String = ""


# ---------------------------------------------------------------------------
# COUNTER RELATIONSHIPS
# Volatile leaves both arrays empty (intentional — no reliable counter).
# ---------------------------------------------------------------------------

@export var counters: Array[ArchetypeDefinition] = []
@export var weak_to:  Array[ArchetypeDefinition] = []


# ---------------------------------------------------------------------------
# SITUATION / PHASE
# Empty string = no phase association (focused, resilient, volatile).
# ---------------------------------------------------------------------------

@export_enum("none", "early", "mid", "late") var phase: String = "none"


# ---------------------------------------------------------------------------
# SIMULATION IDENTITY
# These move out of Simulation.gd's match block during Phase B migration.
# Defaults match the "tactical" baseline (no modifier).
# ---------------------------------------------------------------------------

# Added to focus-roll variance range. Negative = tighter, positive = wider.
# Reference values from current Simulation:
#   focused -6, tactical -4, aggressive +8, volatile +14, clutch/resilient 0
@export var variance_modifier: int = 0

# Stamina drag floor at zero stamina. 0.70 baseline, 0.65 aggressive,
# 0.80 resilient.
@export_range(0.5, 1.0, 0.01) var stamina_floor: float = 0.70


# ---------------------------------------------------------------------------
# PROGRESSION
# Sub-resource. Authored per archetype.
# ---------------------------------------------------------------------------

@export var growth: ArchetypeGrowth = null
