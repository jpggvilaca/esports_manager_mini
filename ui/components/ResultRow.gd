# ui/components/ResultRow.gd
# Displays one player's post-match result: name, level, performance, flavor,
# trait callout, causal chain, XP bar.
class_name ResultRow
extends PanelContainer

const COLOR_MVP         := Color(1.0,  0.85, 0.20, 1.0)
const COLOR_BEST_EFFORT := Color(0.65, 0.75, 1.0,  1.0)
const COLOR_WORST       := Color(0.85, 0.35, 0.35, 1.0)
const XP_TWEEN_DURATION: float = 1.2

var _xp_target: float = 0.0

@onready var _name_lbl:         Label       = $Margin/VBox/Header/NameLabel
@onready var _level_lbl:        Label       = $Margin/VBox/Header/LevelLabel
@onready var _mvp_lbl:          Label       = $Margin/VBox/Header/MvpLabel
@onready var _perf_lbl:         Label       = $Margin/VBox/Header/PerfLabel
@onready var _flavor_lbl:       Label       = $Margin/VBox/FlavorLabel
@onready var _trait_trigger_lbl: Label      = $Margin/VBox/TraitTriggerLabel
@onready var _causal_chain_lbl:  Label      = $Margin/VBox/CausalChainLabel
@onready var _xp_lbl:           Label       = $Margin/VBox/XpRow/XpLabel
@onready var _xp_bar:           ProgressBar = $Margin/VBox/XpRow/XpBar
@onready var _footer_lbl:       Label       = $Margin/VBox/FooterLabel


func setup(p: Player, entry: Dictionary, is_mvp: bool, is_worst: bool = false, is_best_effort: bool = false) -> void:
	_name_lbl.text  = p.player_name
	_level_lbl.text = GameText.LEVEL_BADGE % entry.get("level", p.level)
	_xp_lbl.text    = GameText.XP_GAINED % entry.get("xp_gained", 0)
	_xp_target      = entry.get("xp_progress", LevelSystem.level_progress(p))
	_xp_bar.value   = 0.0

	if entry.get("rested", false):
		_perf_lbl.text = "💤 Rested"
		_perf_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75, 1.0))
		_flavor_lbl.text = "Sat this one out."
		_trait_trigger_lbl.hide()
		_causal_chain_lbl.hide()
	else:
		_perf_lbl.text = entry["label"]
		_perf_lbl.remove_theme_color_override("font_color")
		_flavor_lbl.text = entry["flavor"]

		# --- Trait callout ---
		var trigger: String = entry.get("trait_trigger", "")
		if trigger != "":
			_trait_trigger_lbl.text = trigger
			_trait_trigger_lbl.show()
		else:
			_trait_trigger_lbl.hide()

		# --- Causal chain: compact breakdown of why the score is what it is ---
		var breakdown: Array = entry.get("breakdown", [])
		if breakdown.size() > 0:
			var parts: PackedStringArray = []
			for item: Dictionary in breakdown:
				var d: int = item["delta"]
				var sign: String = "+" if d >= 0 else ""
				parts.append("%s%d %s" % [sign, d, item["reason"]])
			_causal_chain_lbl.text = "  ·  ".join(parts)
			_causal_chain_lbl.show()
		else:
			_causal_chain_lbl.hide()

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


func animate_xp(delay: float = 0.0) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(_xp_bar, "value", _xp_target, XP_TWEEN_DURATION)
