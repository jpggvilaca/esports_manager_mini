# ui/components/PlayerPanel.gd
# Management screen player card.
# Displays name, trait, portrait, stat bars, and action buttons.
class_name PlayerPanel
extends PanelContainer

signal action_changed(player_name: String, action: String)

const COLOR_SELECTED  := Color(0.20, 0.70, 0.35, 1.0)
const COLOR_IDLE      := Color(0.22, 0.22, 0.25, 1.0)
const COLOR_TEXT_ON   := Color(1.0,  1.0,  1.0,  1.0)
const COLOR_TEXT_OFF  := Color(0.65, 0.65, 0.65, 1.0)
const COLOR_INTENSE   := Color(0.85, 0.30, 0.15, 1.0)  # red-orange — danger signal

var _player: Player = null

@onready var _name_label:     Label          = $Margin/VBox/HeaderRow/NameLabel
@onready var _trait_badge:    Label          = $Margin/VBox/HeaderRow/TraitBadge
@onready var _form_label:     Label          = $Margin/VBox/HeaderRow/FormLabel
@onready var _bio_label:      Label          = $Margin/VBox/BioLabel
@onready var _portrait:       TextureRect    = $Margin/VBox/ContentRow/PortraitColumn/Portrait
@onready var _level_label:    Label          = $Margin/VBox/ContentRow/PortraitColumn/LevelLabel
@onready var _stat_bars:      PlayerStatBars = $Margin/VBox/ContentRow/StatBars
@onready var _action_label:   Label          = $Margin/VBox/ActionRow/ActionLabel
@onready var _action_buttons: HBoxContainer  = $Margin/VBox/ActionRow/ActionButtons


func setup(player: Player, portrait_texture: Texture2D = null) -> void:
	_player = player
	if portrait_texture != null:
		_portrait.texture = portrait_texture
	_action_label.hide()  # label is redundant — the buttons speak for themselves
	_build_action_buttons()
	_refresh_display()


func refresh() -> void:
	_refresh_display()


# Called by Main after advancing a week to clear the selection for next week.
func reset_action() -> void:
	_player.planned_action = ""
	_highlight_action("")
	emit_signal("action_changed", _player.player_name, "")


# Show or hide action buttons. Called by Main during solo weeks.
func set_actions_enabled(enabled: bool) -> void:
	_action_buttons.visible = enabled
	_action_label.visible   = enabled


func _build_action_buttons() -> void:
	for action_id: String in ["train", "rest", "scrim", "intense"]:
		var btn := Button.new()
		btn.text                = GameText.ACTIONS[action_id]["label"]
		btn.tooltip_text        = GameText.ACTIONS[action_id]["description"]
		btn.custom_minimum_size = Vector2(76, 30)
		btn.focus_mode          = Control.FOCUS_NONE
		var captured := action_id
		btn.pressed.connect(func(): _on_action_pressed(captured))
		_action_buttons.add_child(btn)
	_highlight_action(_player.planned_action)


func _refresh_display() -> void:
	_name_label.text  = _player.player_name
	_trait_badge.text = "[%s]" % _player.primary_trait
	_level_label.text = GameText.LEVEL_BADGE % _player.level
	_form_label.text  = _player.form_label
	_bio_label.text   = _player.bio
	_stat_bars.refresh(_player)
	_highlight_action(_player.planned_action)


func _on_action_pressed(action: String) -> void:
	_player.planned_action = action
	emit_signal("action_changed", _player.player_name, action)
	_highlight_action(action)


func _highlight_action(action: String) -> void:
	var action_ids := ["train", "rest", "scrim", "intense"]
	var buttons    := _action_buttons.get_children()
	for i in buttons.size():
		var btn: Button = buttons[i]
		var is_selected: bool = action_ids[i] == action
		if is_selected and action == "intense":
			btn.modulate = COLOR_INTENSE
		else:
			btn.modulate = COLOR_SELECTED if is_selected else COLOR_IDLE
		btn.add_theme_color_override("font_color",
			COLOR_TEXT_ON if is_selected else COLOR_TEXT_OFF)
