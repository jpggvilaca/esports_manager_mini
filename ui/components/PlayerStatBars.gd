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
@onready var _xp_bar:      ProgressBar = $XPRow/XPBar
@onready var _xp_val:      Label       = $XPRow/XPVal


func refresh(player: Player) -> void:
	_set_bar(_skill_bar,   _skill_val,   player.skill)
	_set_bar(_stamina_bar, _stamina_val, player.stamina)
	_set_bar(_focus_bar,   _focus_val,   player.focus)
	_refresh_xp(player)


func _refresh_xp(player: Player) -> void:
	var progress: float = LevelSystem.level_progress(player) * 100.0
	var to_next:  int   = LevelSystem.xp_to_next_level(player)
	_xp_bar.value   = progress
	_xp_bar.modulate = Color(0.55, 0.80, 1.0, 1.0)  # always blue — not a health stat
	if to_next == -1:
		_xp_val.text = "MAX"
	else:
		_xp_val.text = "%d/%d" % [player.xp, LevelSystem.LEVEL_THRESHOLDS[player.level]]


func _set_bar(bar: ProgressBar, val_label: Label, value: int) -> void:
	bar.value       = value
	val_label.text  = "%d/100" % value
	bar.modulate    = _color_for(value)


static func _color_for(value: int) -> Color:
	if value >= THRESHOLD_GREEN:  return COLOR_GREEN
	if value >= THRESHOLD_ORANGE: return COLOR_ORANGE
	if value >= THRESHOLD_YELLOW: return COLOR_YELLOW
	return COLOR_RED
