# ui/components/LevelUpBanner.gd
# Shown in results when a player levels up. Populated via setup(). No game logic.
class_name LevelUpBanner
extends PanelContainer

@onready var _title_lbl: Label = $Margin/VBox/TitleLabel
@onready var _stats_lbl: Label = $Margin/VBox/StatsLabel


func setup(lu: Dictionary) -> void:
	_title_lbl.text = "%s  %s" % [lu["player_name"], GameText.LEVEL_UP % lu["new_level"]]

	# Build the stat-gains line — only mention stats that actually grew.
	var parts: PackedStringArray = []
	if lu.get("skill_gain",   0) > 0: parts.append("Skill +%d"   % lu["skill_gain"])
	if lu.get("stamina_gain", 0) > 0: parts.append("Stamina +%d" % lu["stamina_gain"])
	if lu.get("focus_gain",   0) > 0: parts.append("Focus +%d"   % lu["focus_gain"])
	if lu.get("morale_gain",  0) > 0: parts.append("Morale +%d"  % lu["morale_gain"])
	_stats_lbl.text = "  ·  ".join(parts) if parts.size() > 0 else "Base stats improved."

	var unlocked: String = lu.get("trait_unlocked", "none")
	if unlocked != "none" and unlocked != "":
		_stats_lbl.text += "  ·  🔓 Trait unlocked: %s" % unlocked


# Called after the node is added to the tree so the tween has a valid parent.
func _ready() -> void:
	_pop_in()


func _pop_in() -> void:
	scale = Vector2(0.75, 0.75)
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35)
