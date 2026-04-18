# scripts/player/Player.gd
# Data-only class. No logic, no UI references.
# Note: "name" and "trait" are reserved in GDScript — using player_name / special instead.
class_name Player
extends RefCounted

var player_name: String
var skill: int
var focus: int
var stamina: int
var morale: int
var special: String        # e.g. "clutch", "none"  ("trait" is a reserved keyword)
var planned_action: String # "train" | "rest" | "scrim"

func _init(
	p_name: String,
	p_skill: int,
	p_focus: int,
	p_stamina: int,
	p_morale: int,
	p_special: String = "none"
) -> void:
	player_name    = p_name
	skill          = p_skill
	focus          = p_focus
	stamina        = p_stamina
	morale         = p_morale
	special        = p_special
	planned_action = "rest" # default action
