# scenes/Main.gd
# Wires UI events to GameManager. Displays results. No game logic here.
extends Control

const PLAYER_PANEL_SCENE := preload("res://ui/components/PlayerPanel.tscn")

const COLOR_VICTORY := Color(0.20, 0.85, 0.40, 1.0)
const COLOR_DEFEAT  := Color(0.90, 0.25, 0.25, 1.0)
const COLOR_MVP     := Color(1.0,  0.85, 0.20, 1.0)  # gold highlight for top scorer

var _game: GameManager = null

@onready var _week_label:        Label          = $MarginContainer/VBox/WeekLabel
@onready var _player_list:       VBoxContainer  = $MarginContainer/VBox/PlayerList
@onready var _advance_btn:       Button         = $MarginContainer/VBox/AdvanceBtn
@onready var _result_panel:      PanelContainer = $MarginContainer/VBox/ResultPanel
@onready var _outcome_label:     Label          = $MarginContainer/VBox/ResultPanel/ResultMargin/ResultVBox/OutcomeLabel
@onready var _score_label:       Label          = $MarginContainer/VBox/ResultPanel/ResultMargin/ResultVBox/ScoreLabel
@onready var _player_results:    VBoxContainer  = $MarginContainer/VBox/ResultPanel/ResultMargin/ResultVBox/PlayerResultsList
@onready var _dismiss_btn:       Button         = $MarginContainer/VBox/ResultPanel/ResultMargin/ResultVBox/DismissBtn


func _ready() -> void:
	_game = GameManager.new()
	_result_panel.hide()
	_advance_btn.pressed.connect(_on_advance_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_build_player_panels()
	_refresh_week_label()


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
	_advance_btn.disabled = true

	for panel in _player_list.get_children():
		panel.refresh()


func _on_dismiss_pressed() -> void:
	_result_panel.hide()
	_advance_btn.disabled = false


func _show_result(result: Dictionary) -> void:
	# --- Outcome header ---
	if result["won"]:
		_outcome_label.text              = "✅  VICTORY"
		_outcome_label.add_theme_color_override("font_color", COLOR_VICTORY)
	else:
		_outcome_label.text              = "❌  DEFEAT"
		_outcome_label.add_theme_color_override("font_color", COLOR_DEFEAT)

	_score_label.text = "Your team  %d pts   vs   Enemy  %d pts" % [
		result["team_score"], result["opponent_score"]
	]

	# --- Per-player entries ---
	# Clear previous results
	for child in _player_results.get_children():
		child.queue_free()

	# Find MVP (highest score) for gold highlight
	var mvp_score: int = 0
	for entry in result["players"]:
		if entry["score"] > mvp_score:
			mvp_score = entry["score"]

	for entry in result["players"]:
		var p: Player   = entry["player"]
		var is_mvp: bool = entry["score"] == mvp_score

		var row := _make_result_row(p, entry, is_mvp)
		_player_results.add_child(row)

	_result_panel.show()


# Build one result row per player — Label only, no extra scenes needed.
func _make_result_row(p: Player, entry: Dictionary, is_mvp: bool) -> PanelContainer:
	var card := PanelContainer.new()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Row 1: Name + label
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = p.player_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_mvp:
		name_lbl.add_theme_color_override("font_color", COLOR_MVP)
	header.add_child(name_lbl)

	if is_mvp:
		var mvp_badge := Label.new()
		mvp_badge.text = "⭐ MVP"
		mvp_badge.add_theme_font_size_override("font_size", 12)
		mvp_badge.add_theme_color_override("font_color", COLOR_MVP)
		header.add_child(mvp_badge)

	var perf_lbl := Label.new()
	perf_lbl.text = entry["label"]
	perf_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(perf_lbl)

	# Row 2: Flavor text
	var flavor_lbl := Label.new()
	flavor_lbl.text                     = entry["flavor"]
	flavor_lbl.add_theme_font_size_override("font_size", 12)
	flavor_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	flavor_lbl.autowrap_mode            = TextServer.AUTOWRAP_WORD
	vbox.add_child(flavor_lbl)

	# Row 3: Score + trait
	var footer := Label.new()
	footer.text = "%d pts  ·  [%s]" % [entry["score"], p.primary_trait]
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(footer)

	return card
