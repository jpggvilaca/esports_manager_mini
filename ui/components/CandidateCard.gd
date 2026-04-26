# ui/components/CandidateCard.gd
# Market "Available" column card. Data binding only — structure in CandidateCard.tscn.
class_name CandidateCard
extends PanelContainer

@onready var _name_lbl:  Label = $Margin/VBox/Header/NameLabel
@onready var _trait_lbl: Label = $Margin/VBox/Header/TraitBadge
@onready var _stats_lbl: Label = $Margin/VBox/StatsLabel
@onready var _minor_lbl: Label = $Margin/VBox/MinorLabel
@onready var _bio_lbl:   Label = $Margin/VBox/BioLabel


func setup(candidate: Player) -> void:
	_name_lbl.text  = "%s  Lv.%d" % [candidate.player_name, candidate.level]
	_trait_lbl.text = "[%s]" % candidate.primary_trait
	_stats_lbl.text = "Skill %d  ·  Focus %d  ·  Stamina %d  ·  Morale %d" % [
		candidate.skill, candidate.focus, candidate.stamina, candidate.morale
	]
	if candidate.minor_trait != "none" and candidate.minor_trait != "":
		_minor_lbl.text    = "Minor: %s" % candidate.minor_trait
		_minor_lbl.visible = true
	_bio_lbl.text = candidate.bio
