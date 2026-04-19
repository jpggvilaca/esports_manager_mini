# ui/components/PlayerPanel.gd
# Management screen player card.
# Displays name, trait, stat bars (via PlayerStatBars), and action buttons.
class_name PlayerPanel
extends PanelContainer

signal action_changed(player_name: String, action: String)

const COLOR_SELECTED  := Color(0.20, 0.70, 0.35, 1.0)
const COLOR_IDLE      := Color(0.22, 0.22, 0.25, 1.0)
const COLOR_TEXT_ON   := Color(1.0,  1.0,  1.0,  1.0)
const COLOR_TEXT_OFF  := Color(0.65, 0.65, 0.65, 1.0)

var _player: Player = null

@onready var _name_label:     Label          = $Margin/VBox/HeaderRow/NameLabel
@onready var _trait_badge:    Label          = $Margin/VBox/HeaderRow/TraitBadge
@onready var _stat_bars:      PlayerStatBars = $Margin/VBox/StatBars
@onready var _action_buttons: HBoxContainer  = $Margin/VBox/ActionRow/ActionButtons


func setup(player: Player) -> void:
	_player = player
	_build_action_buttons()
	_refresh_display()


func refresh() -> void:
	_refresh_display()


func _build_action_buttons() -> void:
	for action_id: String in ["train", "rest", "scrim"]:
		var btn := Button.new()
		btn.text                = GameText.ACTIONS[action_id]["label"]
		btn.tooltip_text        = GameText.ACTIONS[action_id]["description"]
		btn.custom_minimum_size = Vector2(80, 30)
		btn.focus_mode          = Control.FOCUS_NONE
		var captured := action_id
		btn.pressed.connect(func(): _on_action_pressed(captured))
		_action_buttons.add_child(btn)
	_highlight_action(_player.planned_action)


func _refresh_display() -> void:
	_name_label.text  = _player.player_name
	_trait_badge.text = "[%s]" % _player.primary_trait
	_stat_bars.refresh(_player)
	_highlight_action(_player.planned_action)


func _on_action_pressed(action: String) -> void:
	_player.planned_action = action
	emit_signal("action_changed", _player.player_name, action)
	_highlight_action(action)


func _highlight_action(action: String) -> void:
	var action_ids := ["train", "rest", "scrim"]
	var buttons    := _action_buttons.get_children()
	for i in buttons.size():
		var btn: Button    = buttons[i]
		var is_selected    = action_ids[i] == action
		btn.modulate       = COLOR_SELECTED if is_selected else COLOR_IDLE
		btn.add_theme_color_override("font_color",
			COLOR_TEXT_ON if is_selected else COLOR_TEXT_OFF)
