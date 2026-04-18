# scripts/player/Player.gd
# Data-only class. No logic, no UI references.
class_name Player
extends RefCounted

# Primary traits (strong effect on simulation):
#   "clutch"     — bonus on important matches, slight variance in normal
#   "choker"     — penalty on important matches, slight boost on normal
#   "grinder"    — faster skill gain, more stamina cost on train
#   "lazy"       — slower skill gain, faster stamina recovery on rest
#   "consistent" — reduced randomness
#   "volatile"   — increased randomness
#   "none"       — no effect

# Minor traits (small modifiers, optional):
#   "resilient"  — halved stamina penalty in simulation
#   "fragile"    — stamina penalty kicks in earlier (below 50, not 40)
#   "none"

var player_name: String
var skill: int
var focus: int
var stamina: int
var morale: int
var primary_trait: String  # see above
var minor_trait: String    # see above
var planned_action: String # "train" | "rest" | "scrim"


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
