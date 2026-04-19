# scenes/Main.gd
# Management screen. Wires UI to GameManager. No game logic.
extends Control

signal return_to_world(week: int)

const PLAYER_PANEL_SCENE := preload("res://ui/components/PlayerPanel.tscn")

const COLOR_VICTORY   := Color(0.20, 0.85, 0.40, 1.0)
const COLOR_DEFEAT    := Color(0.90, 0.25, 0.25, 1.0)
const COLOR_MVP       := Color(1.0,  0.85, 0.20, 1.0)
const COLOR_IMPORTANT := Color(1.0,  0.65, 0.15, 1.0)
const COLOR_REST      := Color(0.60, 0.60, 0.80, 1.0)

var _game: GameManager = null

@onready var _back_btn:          Button        = $MarginContainer/VBox/TeamRoomBtn
@onready var _player_list:       VBoxContainer = $MarginContainer/VBox/PlayerList
@onready var _match_context_lbl: Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/MatchContextLabel
@onready var _conditions_lbl:    Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/ConditionsLabel
@onready var _advance_btn:       Button        = $MarginContainer/VBox/AdvanceBtn
@onready var _result_overlay:    Control       = $ResultOverlay
@onready var _outcome_label:     Label         = $ResultOverlay/ResultMargin/OuterVBox/OutcomeLabel
@onready var _score_label:       Label         = $ResultOverlay/ResultMargin/OuterVBox/ScoreLabel
@onready var _player_results:    VBoxContainer = $ResultOverlay/ResultMargin/OuterVBox/ScrollContainer/PlayerResultsList
@onready var _dismiss_btn:       Button        = $ResultOverlay/ResultMargin/OuterVBox/DismissBtn


func _ready() -> void:
	_game = GameManager.new()
	_result_overlay.hide()
	_advance_btn.pressed.connect(_on_advance_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_back_btn.pressed.connect(func(): emit_signal("return_to_world", _game.week))
	_build_player_panels()
	_refresh_prematch()


func _build_player_panels() -> void:
	for player: Player in _game.players:
		var panel := PLAYER_PANEL_SCENE.instantiate()
		_player_list.add_child(panel)
		panel.setup(player)


func _refresh_prematch() -> void:
	var ctx: Dictionary = _game.get_prematch_context()

	var context_parts: PackedStringArray = []
	if ctx["is_important"]:
		context_parts.append(GameText.MATCH_IMPORTANT)
		_match_context_lbl.add_theme_color_override("font_color", COLOR_IMPORTANT)
	else:
		_match_context_lbl.remove_theme_color_override("font_color")

	context_parts.append(GameText.MATCH_OPP_PREFIX % ctx["opp_strength"])

	if ctx["streak"] >= 2:
		context_parts.append(GameText.STREAK_WIN_PREFIX % ctx["streak"])
	elif ctx["streak"] <= -2:
		context_parts.append(GameText.STREAK_LOSS_PREFIX % absi(ctx["streak"]))

	_match_context_lbl.text = "  ·  ".join(context_parts)

	var cond_parts: PackedStringArray = []
	for entry in ctx["conditions"]:
		cond_parts.append("%s %s" % [entry["name"], entry["condition"]])
	_conditions_lbl.text = "  |  ".join(cond_parts)


func _on_advance_pressed() -> void:
	var result: Dictionary = _game.advance_week()
	_advance_btn.disabled = true
	for panel in _player_list.get_children():
		panel.refresh()
	if result.get("has_match", true):
		_show_result(result)
	else:
		_show_rest_summary()


func _on_dismiss_pressed() -> void:
	_result_overlay.hide()
	_advance_btn.disabled = false
	_refresh_prematch()


func _show_rest_summary() -> void:
	_outcome_label.text = GameText.OUTCOME_REST_WEEK
	_outcome_label.add_theme_color_override("font_color", COLOR_REST)
	_score_label.text   = GameText.OUTCOME_REST_DESC
	for child in _player_results.get_children():
		child.queue_free()
	_result_overlay.show()


func _show_result(result: Dictionary) -> void:
	var won:  bool = result["won"]
	var diff: int  = absi(result["team_score"] - result["opponent_score"])

	if won:
		_outcome_label.text = GameText.OUTCOME_VICTORY
		_outcome_label.add_theme_color_override("font_color", COLOR_VICTORY)
	else:
		var close: String   = GameText.OUTCOME_CLOSE if diff <= 15 else ""
		_outcome_label.text = GameText.OUTCOME_DEFEAT + close
		_outcome_label.add_theme_color_override("font_color", COLOR_DEFEAT)

	_score_label.text = GameText.MATCH_SCORE_LINE % [result["team_score"], result["opponent_score"]]

	for child in _player_results.get_children():
		child.queue_free()

	var mvp_score: int = 0
	for entry in result["players"]:
		if entry["score"] > mvp_score:
			mvp_score = entry["score"]

	for entry in result["players"]:
		_player_results.add_child(
			_make_result_row(entry["player"], entry, entry["score"] == mvp_score)
		)

	_result_overlay.show()


func _make_result_row(p: Player, entry: Dictionary, is_mvp: bool) -> PanelContainer:
	var card   := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Header row: name + MVP badge + performance label
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
		var badge := Label.new()
		badge.text = GameText.MVP_BADGE
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", COLOR_MVP)
		header.add_child(badge)

	var perf := Label.new()
	perf.text = entry["label"]
	perf.add_theme_font_size_override("font_size", 14)
	header.add_child(perf)

	# Flavor text
	var flavor := Label.new()
	flavor.text = entry["flavor"]
	flavor.add_theme_font_size_override("font_size", 12)
	flavor.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(flavor)

	# Footer: score + trait + streak
	var streak_hint: String = ""
	if p.win_streak >= 3:    streak_hint = "  · " + GameText.STREAK_ON_ROLL
	elif p.win_streak <= -3: streak_hint = "  · " + GameText.STREAK_COLD

	var footer := Label.new()
	footer.text = "%d pts  ·  [%s]%s" % [entry["score"], p.primary_trait, streak_hint]
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(footer)

	return card
