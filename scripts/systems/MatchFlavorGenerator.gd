# scripts/systems/MatchFlavorGenerator.gd
# Pure logic. Takes a player + score + context, returns label + flavor text.
# No UI references. No state.
class_name MatchFlavorGenerator
extends RefCounted

# Thresholds — tweak here to rebalance labels without touching logic
const HIGH_SCORE: int = 75
const LOW_SCORE:  int = 50


# Returns { "label": String, "flavor": String }
static func generate(player: Player, score: int, is_important: bool) -> Dictionary:
	var label:  String = _get_label(score)
	var flavor: String = _get_flavor(player, score, is_important)
	return { "label": label, "flavor": flavor }


static func _get_label(score: int) -> String:
	if score >= HIGH_SCORE:   return "🔥 Carried"
	elif score >= LOW_SCORE:  return "✅ Solid"
	else:                     return "😬 Struggled"


static func _get_flavor(player: Player, score: int, is_important: bool) -> String:
	var is_high: bool = score >= HIGH_SCORE
	var is_low:  bool = score < LOW_SCORE

	match player.primary_trait:

		"clutch":
			if is_important and is_high:  return "Delivered under pressure."
			if is_important and is_low:   return "Couldn't step up when it mattered."
			if is_high:                   return "Carried key moments."
			if is_low:                    return "Had a rough match."
			return "Played a steady game."

		"choker":
			if is_important and is_low:   return "Collapsed under pressure."
			if is_important and is_high:  return "Managed to hold it together."
			if not is_important and is_high: return "Looked more comfortable than usual."
			if is_low:                    return "Struggled to keep up."
			return "Contributed consistently."

		"grinder":
			if is_high:   return "Hard work paid off."
			if not is_low: return "Reliable as always."
			return "Even grinding couldn't save today."

		"lazy":
			if is_low:    return "Looked unprepared."
			if is_high:   return "Seemed refreshed — and it showed."
			return "Did just enough to get by."

		"consistent":
			if is_high:   return "Dominated the match."
			if is_low:    return "Even consistency has its limits."
			return "Steady and dependable as expected."

		"volatile":
			if is_high:   return "Unpredictable — but brilliant today."
			if is_low:    return "Unpredictable — and it backfired."
			return "Unpredictable performance today."

	# Fallback for "none" or unknown traits
	if is_high:   return "Dominated the match."
	if is_low:    return "Had a rough match."
	return "Played a steady game."
