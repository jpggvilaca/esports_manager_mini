# scenes/Main.gd
# Management screen. Wires UI to GameManager. No game logic.
extends Control

signal return_to_world(week: int, season: int)

const PLAYER_PANEL_SCENE    := preload("res://ui/components/PlayerPanel.tscn")
const RESULT_ROW_SCENE      := preload("res://ui/components/ResultRow.tscn")
const LEVEL_UP_BANNER_SCENE := preload("res://ui/components/LevelUpBanner.tscn")

# Portrait textures indexed by player slot (0-based).
const PORTRAITS: Array = [
	preload("res://assets/portraits/portrait1.png"),
	preload("res://assets/portraits/portrait2.png"),
	preload("res://assets/portraits/portrait3.png"),
]

const COLOR_VICTORY   := Color(0.20, 0.85, 0.40, 1.0)
const COLOR_DEFEAT    := Color(0.90, 0.25, 0.25, 1.0)
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
	_back_btn.pressed.connect(func(): return_to_world.emit(_game.week_in_season, _game.season))
	_build_player_panels()
	_refresh_prematch()


func _build_player_panels() -> void:
	for i: int in _game.players.size():
		var player: Player = _game.players[i]
		var portrait: Texture2D = PORTRAITS[i] if i < PORTRAITS.size() else null
		var panel: PlayerPanel = PLAYER_PANEL_SCENE.instantiate()
		_player_list.add_child(panel)
		panel.setup(player, portrait)


func _refresh_prematch() -> void:
	var ctx: Dictionary = _game.get_prematch_context()
	var context_parts: PackedStringArray = []

	context_parts.append(ctx["type_label"])

	if ctx["is_important"]:
		_match_context_lbl.add_theme_color_override("font_color", COLOR_IMPORTANT)
	else:
		_match_context_lbl.remove_theme_color_override("font_color")

	context_parts.append(GameText.MATCH_OPP_PREFIX % ctx["opp_strength"])

	if ctx["streak"] >= 2:
		context_parts.append(GameText.STREAK_WIN_PREFIX % ctx["streak"])
	elif ctx["streak"] <= -2:
		context_parts.append(GameText.STREAK_LOSS_PREFIX % absi(ctx["streak"]))

	if ctx.get("game_over", false):
		context_parts.append(GameText.GAME_OVER_NOTICE)

	_match_context_lbl.text = "  ·  ".join(context_parts)

	var cond_parts: PackedStringArray = []
	for entry: Dictionary in ctx["conditions"]:
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

	if result.get("game_over", false):
		_advance_btn.text     = GameText.GAME_OVER_BTN
		# Leave disabled — dismiss will not re-enable it


func _on_dismiss_pressed() -> void:
	_result_overlay.hide()
	if not _game_is_over():
		_advance_btn.disabled = false
	_refresh_prematch()


func _game_is_over() -> bool:
	return Calendar.is_game_over(_game.week)


func _show_rest_summary() -> void:
	_outcome_label.text = GameText.OUTCOME_REST_WEEK
	_outcome_label.add_theme_color_override("font_color", COLOR_REST)
	_score_label.text   = GameText.OUTCOME_REST_DESC
	_clear_results()
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

	_score_label.text = result.get("type_label", "") + "\n" + \
		GameText.MATCH_SCORE_LINE % [result["team_score"], result["opponent_score"]]

	_clear_results()

	var mvp_score: int = 0
	for entry: Dictionary in result["players"]:
		if entry["score"] > mvp_score:
			mvp_score = entry["score"]

	for entry: Dictionary in result["players"]:
		var row: ResultRow = RESULT_ROW_SCENE.instantiate()
		_player_results.add_child(row)
		row.setup(entry["player"], entry, entry["score"] == mvp_score)

	for lu: Dictionary in result.get("level_ups", []):
		var banner: LevelUpBanner = LEVEL_UP_BANNER_SCENE.instantiate()
		_player_results.add_child(banner)
		banner.setup(lu)

	_result_overlay.show()


func _clear_results() -> void:
	for child in _player_results.get_children():
		child.queue_free()
