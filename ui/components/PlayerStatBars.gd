# ui/components/PlayerStatBars.gd
# Self-contained stat bar display — skill, stamina, focus.
# Usable anywhere: PlayerPanel (management) or GameWorld (over player asset).
# Call refresh(player) whenever stats change.
class_name PlayerStatBars
extends VBoxContainer

const STAMINA_WARN      := 40
const COLOR_STAMINA_OK  := Color(0.25, 0.75, 0.40, 1.0)
const COLOR_STAMINA_WARN := Color(0.85, 0.45, 0.10, 1.0)

@onready var _skill_bar:   ProgressBar = $SkillRow/SkillBar
@onready var _skill_val:   Label       = $SkillRow/SkillVal
@onready var _stamina_bar: ProgressBar = $StaminaRow/StaminaBar
@onready var _stamina_val: Label       = $StaminaRow/StaminaVal
@onready var _focus_bar:   ProgressBar = $FocusRow/FocusBar
@onready var _focus_val:   Label       = $FocusRow/FocusVal


func refresh(player: Player) -> void:
	_skill_bar.value  = player.skill
	_skill_val.text   = str(player.skill)

	_stamina_bar.value   = player.stamina
	_stamina_val.text    = str(player.stamina)
	_stamina_bar.modulate = COLOR_STAMINA_WARN if player.stamina < STAMINA_WARN else COLOR_STAMINA_OK

	_focus_bar.value  = player.focus
	_focus_val.text   = str(player.focus)
