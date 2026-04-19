# ui/components/LevelUpBanner.gd
# Shown in results when a player levels up. Populated via setup(). No game logic.
class_name LevelUpBanner
extends PanelContainer

@onready var _title_lbl: Label = $Margin/VBox/TitleLabel
@onready var _stats_lbl: Label = $Margin/VBox/StatsLabel


func setup(lu: Dictionary) -> void:
	_title_lbl.text = "%s  %s" % [lu["player_name"], GameText.LEVEL_UP % lu["new_level"]]
	var focus_part: String = "  Focus +%d" % lu["focus_gain"] if lu["focus_gain"] > 0 else ""
	_stats_lbl.text = GameText.LEVEL_UP_STATS % [lu["skill_gain"], focus_part]
