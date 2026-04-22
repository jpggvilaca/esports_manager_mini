# ui/components/ResultRow.gd
# Displays one player's post-match result: name, level, performance, flavor, XP bar.
# Populated via setup() after instantiation. No game logic.
class_name ResultRow
extends PanelContainer

const COLOR_MVP        := Color(1.0,  0.85, 0.20, 1.0)
const COLOR_BEST_EFFORT := Color(0.65, 0.75, 1.0,  1.0)  # blue-grey — tried hard, still lost
const COLOR_WORST      := Color(0.85, 0.35, 0.35, 1.0)

# XP animation duration in seconds — tune here.
const XP_TWEEN_DURATION: float = 1.2

var _xp_target: float = 0.0

@onready var _name_lbl:   Label       = $Margin/VBox/Header/NameLabel
@onready var _level_lbl:  Label       = $Margin/VBox/Header/LevelLabel
@onready var _mvp_lbl:    Label       = $Margin/VBox/Header/MvpLabel
@onready var _perf_lbl:   Label       = $Margin/VBox/Header/PerfLabel
@onready var _flavor_lbl: Label       = $Margin/VBox/FlavorLabel
@onready var _xp_lbl:     Label       = $Margin/VBox/XpRow/XpLabel
@onready var _xp_bar:     ProgressBar = $Margin/VBox/XpRow/XpBar
@onready var _footer_lbl: Label       = $Margin/VBox/FooterLabel


func setup(p: Player, entry: Dictionary, is_mvp: bool, is_worst: bool = false, is_best_effort: bool = false) -> void:
	_name_lbl.text   = p.player_name
	_level_lbl.text  = GameText.LEVEL_BADGE % entry.get("level", p.level)
	_flavor_lbl.text = entry["flavor"]
	_xp_lbl.text     = GameText.XP_GAINED % entry.get("xp_gained", 0)

	# Bar starts at 0 — animate_xp() fills it after the node is in the tree.
	_xp_target    = entry.get("xp_progress", LevelSystem.level_progress(p))
	_xp_bar.value = 0.0

	if entry.get("rested", false):
		_perf_lbl.text = "💤 Rested"
		_perf_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 1.0))
		_flavor_lbl.text = "Sat this one out."
	else:
		_perf_lbl.text = entry["label"]
		_perf_lbl.remove_theme_color_override("font_color")

	var streak_hint: String = ""
	if p.win_streak >= 3:    streak_hint = "  · " + GameText.STREAK_ON_ROLL
	elif p.win_streak <= -3: streak_hint = "  · " + GameText.STREAK_COLD
	_footer_lbl.text = "%d pts  ·  [%s]%s" % [entry["score"], p.primary_trait, streak_hint]

	if is_mvp and not entry.get("rested", false):
		_name_lbl.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_lbl.text = GameText.MVP_BADGE
		_mvp_lbl.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_lbl.show()
	elif is_best_effort and not entry.get("rested", false):
		_name_lbl.add_theme_color_override("font_color", COLOR_BEST_EFFORT)
		_mvp_lbl.text = "💪 Best effort"
		_mvp_lbl.add_theme_color_override("font_color", COLOR_BEST_EFFORT)
		_mvp_lbl.show()
	elif is_worst and not entry.get("rested", false):
		_name_lbl.add_theme_color_override("font_color", COLOR_WORST)
		_mvp_lbl.text = GameText.WORST_BADGE
		_mvp_lbl.add_theme_color_override("font_color", COLOR_WORST)
		_mvp_lbl.show()


# Called by Main after the row is in the scene tree.
# Creates a Tween that fills the XP bar from 0 to _xp_target.
func animate_xp(delay: float = 0.0) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(_xp_bar, "value", _xp_target, XP_TWEEN_DURATION)
