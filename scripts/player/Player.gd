# scripts/player/Player.gd
# Data-only class. No logic, no UI references.
class_name Player
extends RefCounted

# Primary traits: clutch | choker | grinder | lazy | consistent | volatile | none
# Minor traits:  resilient | fragile | none

var player_name: String
var skill: int
var focus: int
var stamina: int
var morale: int
var primary_trait: String
var minor_trait: String
var planned_action: String

# --- Progression tracking (read by UI and FlavorGenerator, written by GameManager) ---
var last_score: int      = 0
var win_streak: int      = 0
var skill_delta: int     = 0
var stamina_delta: int   = 0
var morale_delta: int    = 0   # morale change this week (for UI feedback loop)

# --- Form tracking: last 3 match performance labels ("Carried", "Solid", "Struggled") ---
var form_history: Array  = []  # max 3 entries, most recent last

# Derived form label — read by UI, computed from form_history.
var form_label: String:
	get:
		if form_history.size() < 2:
			return ""  # not enough history yet
		var carried:   int = form_history.filter(func(l): return "Carried"   in l).size()
		var struggled: int = form_history.filter(func(l): return "Struggled" in l).size()
		if carried >= 2:   return "🔥 In Form"
		if struggled >= 2: return "📉 Struggling"
		return ""  # mixed — no label

# --- XP & Levelling (written by LevelSystem, read by UI) ---
var xp: int              = 0   # current XP within this level
var level: int           = 1   # current level (starts at 1)
var xp_delta: int        = 0   # XP gained this week (reset each week)


func _init(
	p_name: String,
	p_skill: int,
	p_focus: int,
	p_stamina: int,
	p_morale: int,
	p_primary: String = "none",
	p_minor: String   = "none"
) -> void:
	player_name    = p_name
	skill          = p_skill
	focus          = p_focus
	stamina        = p_stamina
	morale         = p_morale
	primary_trait  = p_primary
	minor_trait    = p_minor
	planned_action = ""  # no action selected — must be chosen before advancing
