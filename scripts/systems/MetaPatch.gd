# scripts/systems/MetaPatch.gd
# ============================================================
# META PATCH — rotating game-balance changes.
#
# DESIGN (from the brief):
#   "Every 4 weeks, the Game Patch changes. Suddenly, Aggressive traits
#    are nerfed, and Defensive traits are buffed. This forces the player
#    to pivot their roster, preventing them from using the same 3 players
#    forever."
#
# IMPLEMENTATION:
#   Pure functions, deterministic by absolute_week. The patch covers a
#   block of Tuning.PATCH_CYCLE_WEEKS contiguous weeks. During that block,
#   ONE trait gets buffed (+PATCH_BUFF_PCT on player score) and ONE
#   different trait gets nerfed (-PATCH_NERF_PCT).
#
#   "Volatile" is excluded from selection — it's already chaotic by nature
#   and patching it would be either a freebie or a deathblow.
#
# DETERMINISM:
#   Same absolute_week → same patch. Player can plan around the next patch
#   if they look ahead. Patch index is (absolute_week - 1) / PATCH_CYCLE_WEEKS,
#   so weeks 1..PATCH_CYCLE_WEEKS are patch 0, weeks 5..8 are patch 1, etc.
# ============================================================
class_name MetaPatch
extends RefCounted


# Traits eligible for buff/nerf. Volatile excluded by design.
const PATCHABLE_TRAITS: Array[String] = [
	"aggressive",
	"tactical",
	"focused",
	"clutch",
	"resilient",
]


# ---------------------------------------------------------------------------
# GET PATCH — returns the active patch for the given absolute week.
# Returns Dictionary:
#   {
#     "patch_index":  int    — monotonically increasing, week 1 = patch 0
#     "buffed":       String — primary_trait that gets +PATCH_BUFF_PCT
#     "nerfed":       String — primary_trait that gets -PATCH_NERF_PCT
#     "weeks_left":   int    — weeks remaining in this patch (incl. current)
#     "starts_week":  int    — absolute week this patch began on
#     "ends_week":    int    — absolute week this patch will end on
#   }
# ---------------------------------------------------------------------------
static func get_patch(absolute_week: int) -> Dictionary:
	var cycle: int = max(Tuning.PATCH_CYCLE_WEEKS, 1)
	var patch_index: int = (absolute_week - 1) / cycle
	var starts_week:  int = patch_index * cycle + 1
	var ends_week:    int = starts_week + cycle - 1
	var weeks_left:   int = ends_week - absolute_week + 1

	# Seed RNG on patch_index so the same patch period always shows the same
	# buff/nerf pair, regardless of when the player checks.
	seed(patch_index * 31337 + 11)

	var pool: Array[String] = PATCHABLE_TRAITS.duplicate()
	pool.shuffle()
	var buffed: String = pool[0]
	var nerfed: String = pool[1]

	return {
		"patch_index": patch_index,
		"buffed":      buffed,
		"nerfed":      nerfed,
		"weeks_left":  weeks_left,
		"starts_week": starts_week,
		"ends_week":   ends_week,
	}


# ---------------------------------------------------------------------------
# MULTIPLIER FOR TRAIT — returns the score multiplier applied to a player
# whose primary_trait is `trait_key` under the patch active for `absolute_week`.
#   buffed trait → 1 + PATCH_BUFF_PCT
#   nerfed trait → 1 - PATCH_NERF_PCT
#   anything else → 1.0
# ---------------------------------------------------------------------------
static func multiplier_for(trait_key: String, absolute_week: int) -> float:
	var patch: Dictionary = get_patch(absolute_week)
	if trait_key == patch["buffed"]:
		return 1.0 + Tuning.PATCH_BUFF_PCT
	if trait_key == patch["nerfed"]:
		return 1.0 - Tuning.PATCH_NERF_PCT
	return 1.0


# ---------------------------------------------------------------------------
# IS PATCH WEEK ONE — true if the given absolute_week is the FIRST week of
# a new patch cycle. Useful for showing a "Patch Notes" banner on the hub.
# ---------------------------------------------------------------------------
static func is_patch_week_one(absolute_week: int) -> bool:
	var cycle: int = max(Tuning.PATCH_CYCLE_WEEKS, 1)
	return (absolute_week - 1) % cycle == 0


# ---------------------------------------------------------------------------
# NEXT PATCH PREVIEW — what the patch will be next cycle. Useful for letting
# the player prepare a roster pivot in advance.
# ---------------------------------------------------------------------------
static func next_patch(absolute_week: int) -> Dictionary:
	var cycle: int = max(Tuning.PATCH_CYCLE_WEEKS, 1)
	var next_week: int = ((absolute_week - 1) / cycle + 1) * cycle + 1
	return get_patch(next_week)
