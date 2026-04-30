# resources/archetype/archetype_growth.gd
# ============================================================
# ARCHETYPE GROWTH — sub-resource embedded in ArchetypeDefinition.
#
# Defines how much of each stat a player of this archetype can gain on
# level-up: `base + randi_range(0, bonus)`. Today these values live as
# dictionary entries in `LevelSystem.TRAIT_GROWTH`; this resource is the
# typed home they will move to in Phase B.
#
# SCOPE: Phase A skeleton. No code reads this yet — values still live in
# LevelSystem.gd until B5 wires balance resources up.
# ============================================================
@tool
class_name ArchetypeGrowth
extends Resource


@export var skill_bonus:   int = 1
@export var stamina_bonus: int = 1
@export var focus_bonus:   int = 1
@export var morale_bonus:  int = 1
