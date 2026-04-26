# ui/components/RosterCard.gd
# Market "Your Team" column card. Data binding only — structure in RosterCard.tscn.
class_name RosterCard
extends PanelContainer

@onready var _name_lbl:  Label = $Margin/VBox/Header/NameLabel
@onready var _trait_lbl: Label = $Margin/VBox/Header/TraitBadge
@onready var _stats_lbl: Label = $Margin/VBox/StatsLabel
@onready var _form_lbl:  Label = $Margin/VBox/FormLabel


func setup(player: Player) -> void:
	_name_lbl.text  = "%s  Lv.%d" % [player.player_name, player.level]
	_trait_lbl.text = "[%s]" % player.primary_trait
	_stats_lbl.text = "Skill %d  ·  Focus %d  ·  Stamina %d" % [
		player.skill, player.focus, player.stamina
	]
	if player.form_label != "":
		_form_lbl.text    = player.form_label
		_form_lbl.visible = true
