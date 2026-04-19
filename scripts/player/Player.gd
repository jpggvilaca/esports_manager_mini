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
var last_score: int      = 0   # score from previous match
var win_streak: int      = 0   # consecutive wins (+) or losses (-)
var skill_delta: int     = 0   # skill change this week (for micro-reward display)
var stamina_delta: int   = 0   # stamina change this week


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
	planned_action = "rest"
