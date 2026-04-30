# resources/market/player_archetype.gd
# ============================================================
# PLAYER ARCHETYPE — typed replacement for PlayerMarket.ARCHETYPES dicts.
#
# DO NOT CONFUSE WITH ArchetypeDefinition.
#   - ArchetypeDefinition  → "what an aggressive player IS" (gameplay identity)
#   - PlayerArchetype      → "a market candidate template"  (roster slot type)
#
# A PlayerArchetype combines:
#   - a name pool to draw a candidate name from
#   - a primary ArchetypeDefinition (the gameplay identity)
#   - a starter minor archetype string (resilient/fragile/none)
#   - stat ranges to roll within
#   - a bio shown in the market UI
#
# SCOPE: Phase A skeleton. Legacy ARCHETYPES const in PlayerMarket.gd remains
# authoritative until Phase B migration.
# ============================================================
@tool
class_name PlayerArchetype
extends Resource


# Pool of candidate names. The market avoids duplicates with the current
# roster; if all names in the pool are taken it appends a number suffix.
@export var names: Array[String] = []

# The gameplay identity this candidate carries. References an
# ArchetypeDefinition resource (see resources/archetype/).
@export var primary: ArchetypeDefinition = null

# Minor archetype string ("resilient", "fragile", "none"). Stays as a
# string for Phase A — becomes a typed reference / enum in Phase C.
@export_enum("none", "resilient", "fragile") var minor: String = "none"


# Stat ranges. Vector2i so .x = lo, .y = hi.
@export var skill_range:   Vector2i = Vector2i(35, 50)
@export var focus_range:   Vector2i = Vector2i(40, 55)
@export var stamina_range: Vector2i = Vector2i(40, 60)
@export var morale_range:  Vector2i = Vector2i(45, 60)


@export_multiline var bio: String = ""
