# ui/components/PlayerStatBars.gd
# Self-contained stat bar display — skill, stamina, focus.
# Usable anywhere: PlayerPanel (management) or GameWorld (over player asset).
# Call refresh(player) whenever stats change.
class_name PlayerStatBars
extends VBoxContainer

# Color thresholds apply to all three bars equally.
const THRESHOLD_GREEN:  int = 75
const THRESHOLD_ORANGE: int = 55
const THRESHOLD_YELLOW: int = 35

const COLOR_GREEN:  Color = Color(0.20, 0.78, 0.35, 1.0)
const COLOR_ORANGE: Color = Color(0.90, 0.50, 0.10, 1.0)
const COLOR_YELLOW: Color = Color(0.90, 0.80, 0.10, 1.0)
const COLOR_RED:    Color = Color(0.85, 0.18, 0.18, 1.0)

@onready var _skill_bar:   ProgressBar = $SkillRow/SkillBar
@onready var _skill_val:   Label       = $SkillRow/SkillVal
@onready var _stamina_bar: ProgressBar = $StaminaRow/StaminaBar
@onready var _stamina_val: Label       = $StaminaRow/StaminaVal
@onready var _focus_bar:   ProgressBar = $FocusRow/FocusBar
@onready var _focus_val:   Label       = $FocusRow/FocusVal


func refresh(player: Player) -> void:
	_set_bar(_skill_bar,   _skill_val,   player.skill)
	_set_bar(_stamina_bar, _stamina_val, player.stamina)
	_set_bar(_focus_bar,   _focus_val,   player.focus)


func _set_bar(bar: ProgressBar, val_label: Label, value: int) -> void:
	bar.value       = value
	val_label.text  = "%d/100" % value
	bar.modulate    = _color_for(value)


static func _color_for(value: int) -> Color:
	if value >= THRESHOLD_GREEN:  return COLOR_GREEN
	if value >= THRESHOLD_ORANGE: return COLOR_ORANGE
	if value >= THRESHOLD_YELLOW: return COLOR_YELLOW
	return COLOR_RED
