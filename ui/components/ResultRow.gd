# ui/components/ResultRow.gd
# Displays one player's post-match result: name, level, performance, flavor, XP bar.
# Populated via setup() after instantiation. No game logic.
class_name ResultRow
extends PanelContainer

const COLOR_MVP := Color(1.0, 0.85, 0.20, 1.0)

@onready var _name_lbl:   Label       = $Margin/VBox/Header/NameLabel
@onready var _level_lbl:  Label       = $Margin/VBox/Header/LevelLabel
@onready var _mvp_lbl:    Label       = $Margin/VBox/Header/MvpLabel
@onready var _perf_lbl:   Label       = $Margin/VBox/Header/PerfLabel
@onready var _flavor_lbl: Label       = $Margin/VBox/FlavorLabel
@onready var _xp_lbl:     Label       = $Margin/VBox/XpRow/XpLabel
@onready var _xp_bar:     ProgressBar = $Margin/VBox/XpRow/XpBar
@onready var _footer_lbl: Label       = $Margin/VBox/FooterLabel


func setup(p: Player, entry: Dictionary, is_mvp: bool) -> void:
	_name_lbl.text  = p.player_name
	_level_lbl.text = GameText.LEVEL_BADGE % entry.get("level", p.level)
	_perf_lbl.text  = entry["label"]
	_flavor_lbl.text = entry["flavor"]
	_xp_lbl.text    = GameText.XP_GAINED % entry.get("xp_gained", 0)
	_xp_bar.value   = entry.get("xp_progress", LevelSystem.level_progress(p))

	var streak_hint: String = ""
	if p.win_streak >= 3:    streak_hint = "  · " + GameText.STREAK_ON_ROLL
	elif p.win_streak <= -3: streak_hint = "  · " + GameText.STREAK_COLD
	_footer_lbl.text = "%d pts  ·  [%s]%s" % [entry["score"], p.primary_trait, streak_hint]

	if is_mvp:
		_name_lbl.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_lbl.text = GameText.MVP_BADGE
		_mvp_lbl.add_theme_color_override("font_color", COLOR_MVP)
		_mvp_lbl.show()
