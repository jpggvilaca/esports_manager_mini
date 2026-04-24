# scenes/Main.gd
# Management screen. Wires UI to GameManager. No game logic.
extends Control

signal return_to_world(week: int, season: int)
# Fix 4: emit goal data directly so GameWorld never reaches into _game.
signal season_goal_updated(goal_display: Dictionary)

const PLAYER_PANEL_SCENE    := preload("res://ui/components/PlayerPanel.tscn")
const RESULT_ROW_SCENE      := preload("res://ui/components/ResultRow.tscn")
const LEVEL_UP_BANNER_SCENE := preload("res://ui/components/LevelUpBanner.tscn")

const PORTRAITS: Array = [
	preload("res://assets/portraits/portrait1.png"),
	preload("res://assets/portraits/portrait2.png"),
	preload("res://assets/portraits/portrait3.png"),
]

const COLOR_VICTORY       := Color(0.20, 0.85, 0.40, 1.0)
const COLOR_DEFEAT        := Color(0.90, 0.25, 0.25, 1.0)
const COLOR_IMPORTANT     := Color(1.0,  0.65, 0.15, 1.0)
const COLOR_SOLO          := Color(0.55, 0.80, 1.0,  1.0)
const COLOR_TOURNAMENT    := Color(1.0,  0.85, 0.20, 1.0)
const COLOR_REST          := Color(0.60, 0.60, 0.80, 1.0)
const COLOR_SELECTED_SOLO := Color(0.20, 0.60, 0.90, 1.0)
const COLOR_IDLE_SOLO     := Color(0.22, 0.22, 0.25, 1.0)

var _game: GameManager = null
var _actions_chosen: int = 0

@onready var _back_btn:         Button        = $MarginContainer/VBox/TeamRoomBtn
@onready var _prep_week_lbl:    Label         = $MarginContainer/VBox/PrepWeekLabel
@onready var _prep_context_lbl: Label         = $MarginContainer/VBox/PrepContextLabel
@onready var _player_list:      VBoxContainer = $MarginContainer/VBox/PlayerList
@onready var _conditions_lbl:   Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/ConditionsLabel
@onready var _warning_lbl:      Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/WarningLabel
@onready var _solo_picker:      VBoxContainer = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/SoloPicker
@onready var _solo_btn_row:     HBoxContainer = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/SoloPicker/SoloButtonRow
@onready var _advance_btn:      Button        = $MarginContainer/VBox/AdvanceBtn
@onready var _result_overlay:   Control       = $ResultOverlay
@onready var _outcome_label:    Label         = $ResultOverlay/ResultMargin/OuterVBox/OutcomeLabel
@onready var _score_label:      Label         = $ResultOverlay/ResultMargin/OuterVBox/ScoreLabel
@onready var _summary_label:    Label         = $ResultOverlay/ResultMargin/OuterVBox/SummaryLabel
@onready var _player_results:   VBoxContainer = $ResultOverlay/ResultMargin/OuterVBox/ScrollContainer/PlayerResultsList
@onready var _dismiss_btn:      Button        = $ResultOverlay/ResultMargin/OuterVBox/DismissBtn


func _ready() -> void:
	_game = GameManager.new()
	_result_overlay.hide()
	_advance_btn.pressed.connect(_on_advance_pressed)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_back_btn.pressed.connect(func(): return_to_world.emit(_game.week_in_season, _game.season))
	_build_player_panels()
	_refresh_prematch()
	_update_advance_lock()


func _build_player_panels() -> void:
	for i: int in _game.players.size():
		var player: Player      = _game.players[i]
		var portrait: Texture2D = PORTRAITS[i] if i < PORTRAITS.size() else null
		var panel: PlayerPanel  = PLAYER_PANEL_SCENE.instantiate()
		_player_list.add_child(panel)
		panel.setup(player, portrait)
		panel.action_changed.connect(_on_action_changed)


func _on_action_changed(_player_name: String, _action: String) -> void:
	_update_advance_lock()


func _update_advance_lock() -> void:
	var ctx: Dictionary = _game.get_prematch_context()
	var is_solo: bool   = ctx["is_solo"]

	if _game_is_over():
		_advance_btn.disabled = true
		return

	if is_solo:
		_advance_btn.disabled = _game.selected_solo_player == ""
		_advance_btn.text     = GameText.SOLO_PICK_PROMPT if _game.selected_solo_player == "" else GameText.ADVANCE_BTN_SOLO
		return

	var chosen: int = 0
	for p: Player in _game.players:
		if p.planned_action != "":
			chosen += 1
	var all_chosen: bool = chosen == _game.players.size()
	_advance_btn.disabled = not all_chosen
	_advance_btn.text = "Choose actions (%d left)" % (_game.players.size() - chosen) if not all_chosen else _advance_btn_text_for(ctx["match_type"])


func _advance_btn_text_for(match_type: String) -> String:
	match match_type:
		"important":  return GameText.ADVANCE_BTN_IMPORTANT
		"tournament": return GameText.ADVANCE_BTN_TOURNAMENT
		"solo":       return GameText.ADVANCE_BTN_SOLO
		_:            return GameText.ADVANCE_BTN_NORMAL


func _refresh_prematch() -> void:
	var ctx: Dictionary     = _game.get_prematch_context()
	var is_solo: bool       = ctx["is_solo"]
	var is_tournament: bool = ctx["is_tournament"]
	var match_type: String  = ctx["match_type"]

	# Week header
	_prep_week_lbl.text    = GameText.WEEK_HEADER % [ctx["week"], GameText.MATCH_TYPE_UPPER.get(match_type, match_type.to_upper())]
	_prep_context_lbl.text = GameText.WEEK_CONTEXT.get(match_type, "")

	# Color the week label by match type
	if is_tournament:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_TOURNAMENT)
	elif is_solo:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_SOLO)
	elif ctx["is_important"]:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_IMPORTANT)
	else:
		_prep_week_lbl.remove_theme_color_override("font_color")

	# Conditions
	var cond_parts: PackedStringArray = []
	for entry: Dictionary in ctx["conditions"]:
		var line: String = entry["name"] + ": " + entry["stamina_lbl"]
		if entry["morale_lbl"] != "":
			line += " / " + entry["morale_lbl"]
		var delta: int = entry.get("morale_delta", 0)
		if delta > 0:
			line += " " + GameText.MORALE_GAIN % delta
		elif delta < 0:
			line += " " + GameText.MORALE_LOSS % delta
		cond_parts.append(line)
	_conditions_lbl.text = "  |  ".join(cond_parts)

	# Warnings — only show rest-count warning when all actions are chosen
	# (before that, unselected actions look like resting, which is misleading).
	var all_chosen: bool = true
	for p: Player in _game.players:
		if p.planned_action == "":
			all_chosen = false
			break

	var warnings: PackedStringArray = []
	if ctx["has_tired"]:
		warnings.append(GameText.WARN_TIRED_PLAYER)
	if ctx["is_important"] and not is_solo:
		warnings.append(GameText.WARN_IMPORTANT)
	if is_solo:
		warnings.append(GameText.WARN_SOLO)
	if all_chosen and ctx.get("rest_count", 0) >= 2 and not is_solo:
		warnings.append("⚠️ %d resting — team loses focus" % ctx["rest_count"])
	_warning_lbl.text = "  ·  ".join(warnings)

	# Solo picker
	if is_solo:
		_build_solo_picker(ctx["player_names"])
		_solo_picker.show()
	else:
		_solo_picker.hide()
		_game.selected_solo_player = ""

	# Disable action buttons on solo weeks
	for panel in _player_list.get_children():
		panel.set_actions_enabled(not is_solo)


func _build_solo_picker(names: Array) -> void:
	for child in _solo_btn_row.get_children():
		child.queue_free()
	for pname: String in names:
		var btn := Button.new()
		btn.text                = pname
		btn.custom_minimum_size = Vector2(90, 32)
		btn.focus_mode          = Control.FOCUS_NONE
		var captured := pname
		btn.pressed.connect(func(): _on_solo_player_selected(captured))
		_solo_btn_row.add_child(btn)
	_highlight_solo_picker(_game.selected_solo_player)


func _on_solo_player_selected(name: String) -> void:
	_game.selected_solo_player = name
	_highlight_solo_picker(name)
	_update_advance_lock()


func _highlight_solo_picker(selected_name: String) -> void:
	for btn: Button in _solo_btn_row.get_children():
		btn.modulate = COLOR_SELECTED_SOLO if btn.text == selected_name else COLOR_IDLE_SOLO


func _on_advance_pressed() -> void:
	# advance_week now returns typed MatchResult, not a Dictionary.
	var result: MatchResult = _game.advance_week()
	_advance_btn.disabled = true

	for panel in _player_list.get_children():
		panel.refresh()

	if result.has_match:
		_show_result(result)
	else:
		_show_rest_summary()

	if result.game_over:
		_advance_btn.text = GameText.GAME_OVER_BTN

	# Emit goal state so GameWorld doesn't need to reach in.
	season_goal_updated.emit({
		"season":  _game.get_season_goal_display(),
		"quarter": _game.get_quarter_goal_display(),
	})


func _on_dismiss_pressed() -> void:
	_clear_results()
	_result_overlay.hide()
	return_to_world.emit(_game.week_in_season, _game.season)


func _game_is_over() -> bool:
	return Calendar.is_game_over(_game.week)


func _show_rest_summary() -> void:
	_outcome_label.text = GameText.OUTCOME_REST_WEEK
	_outcome_label.add_theme_color_override("font_color", COLOR_REST)
	_score_label.text   = GameText.OUTCOME_REST_DESC
	_summary_label.text = ""
	_clear_results()
	_result_overlay.show()


func _show_result(result: MatchResult) -> void:
	# All access via typed properties — no .get("key", default).
	var won:  bool = result.won
	var diff: int  = absi(result.team_score - result.opponent_score)

	if won:
		_outcome_label.text = GameText.OUTCOME_VICTORY
		_outcome_label.add_theme_color_override("font_color", COLOR_VICTORY)
	else:
		_outcome_label.text = GameText.OUTCOME_DEFEAT + (GameText.OUTCOME_CLOSE if diff <= 15 else "")
		_outcome_label.add_theme_color_override("font_color", COLOR_DEFEAT)

	var score_line: String = GameText.MATCH_SCORE_LINE % [result.team_score, result.opponent_score]
	if result.is_tournament:
		_score_label.text = "%s\n%s  ·  %s" % [
			result.type_label, score_line,
			GameText.TOURNAMENT_ROUNDS_WON % [result.rounds_won, result.rounds_total]
		]
	else:
		_score_label.text = result.type_label + "\n" + score_line

	var summary_parts: PackedStringArray = []
	var mvp_name:   String = result.mvp_name   if won else ""
	var best_effort: String = result.mvp_name  if not won else ""
	var worst_name: String = result.worst_name
	if mvp_name != "":    summary_parts.append("⭐ MVP: %s" % mvp_name)
	if best_effort != "": summary_parts.append("💪 Best effort: %s" % best_effort)
	if worst_name != "":  summary_parts.append("💔 Struggled: %s" % worst_name)
	if result.is_tournament:
		summary_parts.append(result.round_summary)
	if not won and result.defeat_hint != "":
		summary_parts.append(result.defeat_hint)
	if result.quarter_bonus_description != "":
		summary_parts.append("🌟 " + result.quarter_bonus_description)
	_summary_label.text = "  ·  ".join(summary_parts)

	_clear_results()

	# Level-up banners first — they are the headline moment, not the footer.
	for lu: Dictionary in result.level_ups:
		var banner: LevelUpBanner = LEVEL_UP_BANNER_SCENE.instantiate()
		_player_results.add_child(banner)
		banner.setup(lu)

	var stagger: float = 0.0
	for entry: Dictionary in result.players:
		var p: Player = entry["player"]
		if result.is_solo and entry.get("rested", false):
			continue
		var is_mvp:         bool = won and p.player_name == result.mvp_name   and not entry.get("rested", false)
		var is_best_effort: bool = not won and p.player_name == result.mvp_name and not entry.get("rested", false)
		var is_worst:       bool = p.player_name == result.worst_name and not entry.get("rested", false)
		var row: ResultRow = RESULT_ROW_SCENE.instantiate()
		_player_results.add_child(row)
		row.setup(p, entry, is_mvp, is_worst, is_best_effort)
		row.animate_xp(stagger)
		stagger += 0.15

	_result_overlay.show()


func _clear_results() -> void:
	for child in _player_results.get_children():
		child.queue_free()


func prepare_new_week() -> void:
	_advance_btn.disabled = false
	_advance_btn.text     = GameText.ADVANCE_BTN_NORMAL
	_actions_chosen       = 0
	_game.selected_solo_player = ""
	_rebuild_player_panels()
	_refresh_prematch()
	_update_advance_lock()
	# Broadcast goal state immediately on re-entry so header is current.
	season_goal_updated.emit({
		"season":  _game.get_season_goal_display(),
		"quarter": _game.get_quarter_goal_display(),
	})


func _rebuild_player_panels() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_build_player_panels()
