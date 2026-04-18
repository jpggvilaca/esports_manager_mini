# ui/components/PlayerPanel.gd
# UI only: displays one player + lets user pick their action.
# Emits a signal upward — never touches GameManager directly.
class_name PlayerPanel
extends PanelContainer

signal action_changed(player_name: String, action: String)

var _player: Player = null

@onready var _name_label:     Label          = $VBox/NameLabel
@onready var _stats_label:    Label          = $VBox/StatsLabel
@onready var _action_buttons: HBoxContainer  = $VBox/ActionButtons


func setup(player: Player) -> void:
	_player = player
	# Build buttons here so _player is guaranteed set before any press.
	for action: String in ["train", "rest", "scrim"]:
		var btn := Button.new()
		btn.text = action.capitalize()
		var captured := action
		btn.pressed.connect(func(): _on_action_pressed(captured))
		_action_buttons.add_child(btn)
	_refresh_display()


func refresh() -> void:
	_refresh_display()


func _refresh_display() -> void:
	_name_label.text  = "%s  [%s]  → %s" % [_player.player_name, _player.special, _player.planned_action]
	_stats_label.text = "Skill:%d  Focus:%d  Stamina:%d  Morale:%d" % [
		_player.skill, _player.focus, _player.stamina, _player.morale
	]


func _on_action_pressed(action: String) -> void:
	_player.planned_action = action
	emit_signal("action_changed", _player.player_name, action)
	_refresh_display() # update the name label to show queued action immediately

	# Reset all highlights, then mark the selected button yellow.
	for btn: Button in _action_buttons.get_children():
		btn.modulate = Color.WHITE
	for btn: Button in _action_buttons.get_children():
		if btn.text.to_lower() == action:
			btn.modulate = Color.YELLOW
