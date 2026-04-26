# scripts/player/Player.gd
# Data-only class. No logic, no UI references.
class_name Player
extends RefCounted

# Traits: clutch | choker | grinder | lazy | consistent | volatile | none
# Minor:  resilient | fragile | none

var player_name:   String
var skill:         int
var focus:         int
var stamina:       int
var morale:        int
var primary_trait: String
var minor_trait:   String
var minor_trait_2: String = "none"
var bio:           String = ""

# --- State ---
var is_active: bool = false   # true = in the squad this week (one of the 3)
var is_benched: bool:         # computed from is_active
	get: return not is_active

# bench_action: what this player does while benched.
# "rest"  = recover stamina + morale (default for most)
# "train" = gain XP at cost of stamina (grinders default, but any player can choose)
var bench_action: String = "rest"

# --- Progression ---
var xp:        int  = 0
var level:     int  = 1
var xp_delta:  int  = 0

# --- Match history ---
var last_score:   int  = 0
var win_streak:   int  = 0
var debut_match:  bool = true

var form_history: Array = []
var form_label: String:
	get:
		if form_history.size() < 2: return ""
		var carried:   int = form_history.filter(func(l): return "Carried"   in l).size()
		var struggled: int = form_history.filter(func(l): return "Struggled" in l).size()
		if carried   >= 2: return "🔥 In Form"
		if struggled >= 2: return "📉 Struggling"
		return ""

# --- Hidden counters ---
var burnout:           int = 0
var hunger:            int = 3
var consecutive_rests: int = 0

# --- Delta tracking (for resolution screen) ---
var morale_delta:  int = 0
var stamina_delta: int = 0
var skill_delta:   int = 0


func _init(
	p_name:    String,
	p_skill:   int,
	p_focus:   int,
	p_stamina: int,
	p_morale:  int,
	p_primary: String = "none",
	p_minor:   String = "none"
) -> void:
	player_name   = p_name
	skill         = p_skill
	focus         = p_focus
	stamina       = p_stamina
	morale        = p_morale
	primary_trait = p_primary
	minor_trait   = p_minor


func get_minor_traits() -> Array[String]:
	var result: Array[String] = []
	if minor_trait   != "none" and minor_trait   != "": result.append(minor_trait)
	if minor_trait_2 != "none" and minor_trait_2 != "": result.append(minor_trait_2)
	return result


# Stamina condition bucket — used by UI and coaching voice.
func stamina_key() -> String:
	if stamina >= 70:   return "fresh"
	if stamina >= 45:   return "ok"
	if stamina >= 25:   return "tired"
	return "exhausted"


# One-line coaching sentence about this player's current state.
func voice(match_type: String) -> String:
	return GameText.player_voice(self, stamina_key(), morale_key(), match_type)


# Morale condition bucket.
func morale_key() -> String:
	if morale >= 80:  return "confident"
	if morale < 40:   return "shaky"
	return "neutral"
