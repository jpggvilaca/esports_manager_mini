class_name MatchFlavorGenerator
extends RefCounted

const HIGH_SCORE: int = 75
const LOW_SCORE:  int = 50


# Returns { "label": String, "flavor": String }
static func generate(player: Player, score: int, is_important: bool) -> Dictionary:
	return {
		"label":  _get_label(score),
		"flavor": _get_flavor(player, score, is_important),
	}


static func _get_label(score: int) -> String:
	if score >= HIGH_SCORE:  return GameText.PERF_LABELS[2]
	elif score >= LOW_SCORE: return GameText.PERF_LABELS[1]
	else:                    return GameText.PERF_LABELS[0]


static func _get_flavor(player: Player, score: int, is_important: bool) -> String:
	var is_high:        bool = score >= HIGH_SCORE
	var is_low:         bool = score < LOW_SCORE
	var win_streak:     bool = player.win_streak >= 2
	var loss_streak:    bool = player.win_streak <= -2
	var t:              String = player.primary_trait

	# Resolve situation key — most specific first
	if is_important:
		if is_high: return GameText.flavor(t, "important_high_streak" if win_streak  else "important_high")
		if is_low:  return GameText.flavor(t, "important_low_streak"  if loss_streak else "important_low")
	else:
		if is_high and t == "choker": return GameText.flavor(t, "normal_high")

	if is_high: return GameText.flavor(t, "high_streak" if win_streak else "high")
	if is_low:  return GameText.flavor(t, "low_streak"  if loss_streak else "low")
	
	return GameText.flavor(t, "mid")
