# scenes/Main.gd
# Wires UI events to GameManager. Displays results. No game logic here.
extends Control

const PLAYER_PANEL_SCENE := preload("res://ui/components/PlayerPanel.tscn")

# GameManager created in _ready so timing is always clean.
var _game: GameManager = null

@onready var _week_label:   Label          = $MarginContainer/VBox/WeekLabel
@onready var _player_list:  VBoxContainer  = $MarginContainer/VBox/PlayerList
@onready var _advance_btn:  Button         = $MarginContainer/VBox/AdvanceBtn
@onready var _result_panel: PanelContainer = $MarginContainer/VBox/ResultPanel
@onready var _result_label: Label          = $MarginContainer/VBox/ResultPanel/ResultVBox/ResultLabel
@onready var _dismiss_btn:  Button         = $MarginContainer/VBox/ResultPanel/ResultVBox/DismissBtn


func _ready() -> void:
	_game = GameManager.new()

	_result_panel.hide()
	_advance_btn.pressed.connect(_on_advance_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)

	_build_player_panels()
	_refresh_week_label()


# Instance one PlayerPanel per player from the .tscn — paths are stable.
func _build_player_panels() -> void:
	for player: Player in _game.players:
		var panel := PLAYER_PANEL_SCENE.instantiate()
		_player_list.add_child(panel)
		panel.setup(player)


func _refresh_week_label() -> void:
	_week_label.text = "— Week %d —" % _game.week


func _on_advance_pressed() -> void:
	var result: Dictionary = _game.advance_week()
	_show_result(result)
	_refresh_week_label()
	_advance_btn.disabled = true  # lock until player dismisses result

	for panel in _player_list.get_children():
		panel.refresh()


func _on_dismiss_pressed() -> void:
	_result_panel.hide()
	_advance_btn.disabled = false  # re-enable for next week


func _show_result(result: Dictionary) -> void:
	var lines: PackedStringArray = []

	if result["won"]:
		lines.append("✅  VICTORY!   (%d vs %d)" % [result["team_score"], result["opponent_score"]])
	else:
		lines.append("❌  DEFEAT      (%d vs %d)" % [result["team_score"], result["opponent_score"]])

	lines.append("")
	lines.append("Player Performances (Week %d):" % result["week"])

	var scores: Array = result["per_player"]
	for i: int in _game.players.size():
		var p: Player  = _game.players[i]
		var score: int = scores[i]
		lines.append("  %s  →  %s  (%d pts)" % [p.player_name, _rate_player(score), score])

	_result_label.text = "\n".join(lines)
	_result_panel.show()


# Classify a player's score into a readable label.
func _rate_player(score: int) -> String:
	if score >= 75:   return "🔥 Carried"
	elif score >= 55: return "✅ Solid"
	else:             return "😬 Struggled"
