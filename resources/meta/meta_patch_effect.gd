# resources/meta/meta_patch_effect.gd
# ============================================================
# META PATCH EFFECT — typed authoring container for hand-crafted patches.
#
# CURRENT BEHAVIOUR (pre-refactor):
#   MetaPatch.get_patch() generates patches deterministically from the
#   absolute_week — it picks one buffed and one nerfed archetype by
#   shuffling a pool with a per-cycle seed. Patches are computed, never
#   authored.
#
# WHY THIS RESOURCE EXISTS:
#   Once we have authorable patches, the designer can override the seeded
#   roll for specific cycles ("Patch 3 always nerfs aggressive — story
#   beat") or extend patch effects beyond simple buff/nerf percentages
#   (e.g. "all clutch players gain +1 morale per match this patch").
#
# SCOPE: Phase A skeleton — fields are declared so the migration target
# exists, but no code reads from this yet. The seeded MetaPatch.get_patch()
# remains the source of truth until a future content phase chooses to
# author patches manually.
# ============================================================
@tool
class_name MetaPatchEffect
extends Resource


# Identifier shown to the player ("Patch 3.2", "Spring Patch", etc.).
@export var label: String = ""


# Which archetype keys this patch buffs / nerfs.
# Strings during Phase A; becomes Array[ArchetypeDefinition] in Phase C.
@export var buffed_keys: Array[String] = []
@export var nerfed_keys: Array[String] = []


# Multiplier applied to per-player score. Defaults match
# Tuning.PATCH_BUFF_PCT / PATCH_NERF_PCT.
@export_range(0.0, 1.0, 0.01) var buff_pct: float = 0.20
@export_range(0.0, 1.0, 0.01) var nerf_pct: float = 0.20


# Optional flavour text shown on the patch banner.
@export_multiline var notes: String = ""
