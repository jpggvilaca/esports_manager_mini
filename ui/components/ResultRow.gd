# ui/components/ResultRow.gd
# Post-match row for one player: name, level, performance sentence, XP bar.
# Causal chain removed — coaching voice in the pre-match screen is the one place
# for that information. Here we just show what happened and how much XP they earned.
class_name ResultRow
extends PanelContainer

const COLOR_MVP         := Color(1.0,  0.85, 0.20, 1.0)
const COLOR_BEST_EFFORT := Color(0.65, 0.75, 1.0,  1.0)
const COLOR_WORST       := Color(0.85, 0.35, 0.35, 1.0)
const XP_TWEEN_DURATION: float = 1.2

var _xp_bar_target: float = 0.0

@onready var _name_label:        Label       = $Margin/VBox/Header/NameLabel
@onready var _level_label:       Label       = $Margin/VBox/Header/LevelLabel
@onready var _mvp_label:         Label       = $Margin/VBox/Header/MvpLabel
@onready var _performance_label: Label       = $Margin/VBox/Header/PerfLabel
@onready var _flavor_label:      Label       = $Margin/VBox/FlavorLabel
@onready var _xp_amount_label:   Label       = $Margin/VBox/XpRow/XpLabel
@onready var _xp_bar:            ProgressBar = $Margin/VBox/XpRow/XpBar
@onready var _footer_label:      Label       = $Margin/VBox/FooterLabel


func setup(player: Player, entry: Dictionary, is_mvp: bool, is_worst: bool = false, is_best_effort: bool = false) -> void:
	_name_label.text      = player.player_name
	_level_label.text     = GameText.LEVEL_BADGE % entry.get("level", player.level)
	_xp_amount_label.text = GameText.XP_GAINED % entry.get("xp_gained", 0)
	_xp_bar_target        = entry.get("xp_progress", LevelSystem.level_progress(player))
	_xp_bar.value         = 0.0

	if entry.get("rested", false):
		_performance_label.text = "💤 Rested"
		_performance_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 1.0))
		_flavor_label.text = "Sat this one out."
	else:
		_performance_label.text = entry["label"]
		_performance_label.remove_theme_color_override("font_color")
		_flavor_label.text = entry["flavor"]

	# Footer: score + trait plain-English description + streak hint.
	var trait_desc: String  = GameText.TRAIT_DESCRIPTIONS.get(player.primary_trait, player.primary_trait)
	var streak_hint: String = ""
	if player.win_streak >= 3:    streak_hint = "  · " + GameText.STREAK_ON_ROLL
	elif player.win_streak <= -3: streak_hint = "  · " + GameText.STREAK_COLD
	_footer_label.text = "%d pts  ·  %s%s" % [entry["score"], trait_desc, streak_hint]

	# Badge — exactly one per row: MVP > Best Effort > Struggled. Never overlap.
	if is_mvp and not entry.get("rested", false):
		_name_label.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_label.text = GameText.MVP_BADGE
		_mvp_label.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_label.show()
	elif is_best_effort and not entry.get("rested", false):
		_name_label.add_theme_color_override("font_color", COLOR_BEST_EFFORT)
		_mvp_label.text = "💪 Best effort"
		_mvp_label.add_theme_color_override("font_color", COLOR_BEST_EFFORT)
		_mvp_label.show()
	elif is_worst and not entry.get("rested", false):
		_name_label.add_theme_color_override("font_color", COLOR_WORST)
		_mvp_label.text = GameText.WORST_BADGE
		_mvp_label.add_theme_color_override("font_color", COLOR_WORST)
		_mvp_label.show()


func animate_xp(delay: float = 0.0) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(_xp_bar, "value", _xp_bar_target, XP_TWEEN_DURATION)
