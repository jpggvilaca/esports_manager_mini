# scenes/Main.gd
# Management screen. Wires UI to GameManager. No game logic.
extends Control

signal return_to_world(week: int, season: int)

const PLAYER_PANEL_SCENE    := preload("res://ui/components/PlayerPanel.tscn")
const RESULT_ROW_SCENE      := preload("res://ui/components/ResultRow.tscn")
const LEVEL_UP_BANNER_SCENE := preload("res://ui/components/LevelUpBanner.tscn")

const PORTRAITS: Array = [
	preload("res://assets/portraits/portrait1.png"),
	preload("res://assets/portraits/portrait2.png"),
	preload("res://assets/portraits/portrait3.png"),
]

const COLOR_VICTORY   := Color(0.20, 0.85, 0.40, 1.0)
const COLOR_DEFEAT    := Color(0.90, 0.25, 0.25, 1.0)
const COLOR_IMPORTANT := Color(1.0,  0.65, 0.15, 1.0)
const COLOR_SOLO      := Color(0.55, 0.80, 1.0,  1.0)
const COLOR_TOURNAMENT := Color(1.0, 0.85, 0.20, 1.0)
const COLOR_REST      := Color(0.60, 0.60, 0.80, 1.0)
const COLOR_SELECTED_SOLO := Color(0.20, 0.60, 0.90, 1.0)
const COLOR_IDLE_SOLO     := Color(0.22, 0.22, 0.25, 1.0)

var _game: GameManager = null
var _actions_chosen: int = 0

@onready var _back_btn:          Button        = $MarginContainer/VBox/TeamRoomBtn
@onready var _prep_week_lbl:     Label         = $MarginContainer/VBox/PrepWeekLabel
@onready var _prep_context_lbl:  Label         = $MarginContainer/VBox/PrepContextLabel
@onready var _player_list:       VBoxContainer = $MarginContainer/VBox/PlayerList
@onready var _conditions_lbl:    Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/ConditionsLabel
@onready var _warning_lbl:       Label         = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/WarningLabel
@onready var _solo_picker:       VBoxContainer = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/SoloPicker
@onready var _solo_btn_row:      HBoxContainer = $MarginContainer/VBox/PreMatchPanel/PreMatchMargin/PreMatchVBox/SoloPicker/SoloButtonRow
@onready var _advance_btn:       Button        = $MarginContainer/VBox/AdvanceBtn
@onready var _result_overlay:    Control       = $ResultOverlay
@onready var _outcome_label:     Label         = $ResultOverlay/ResultMargin/OuterVBox/OutcomeLabel
@onready var _score_label:       Label         = $ResultOverlay/ResultMargin/OuterVBox/ScoreLabel
@onready var _summary_label:     Label         = $ResultOverlay/ResultMargin/OuterVBox/SummaryLabel
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
	var ctx: Dictionary  = _game.get_prematch_context()
	var is_solo: bool    = ctx["is_solo"]

	if _game_is_over():
		_advance_btn.disabled = true
		return

	if is_solo:
		# Solo weeks only require a solo player selection — not action buttons.
		_advance_btn.disabled = _game.selected_solo_player == ""
		if _game.selected_solo_player == "":
			_advance_btn.text = GameText.SOLO_PICK_PROMPT
		else:
			_advance_btn.text = GameText.ADVANCE_BTN_SOLO
		return

	# Normal / important / tournament: require all action buttons chosen.
	var chosen: int = 0
	for p: Player in _game.players:
		if p.planned_action != "":
			chosen += 1
	var all_chosen: bool = chosen == _game.players.size()
	_advance_btn.disabled = not all_chosen

	if not all_chosen:
		_advance_btn.text = "Choose actions (%d left)" % (_game.players.size() - chosen)
	else:
		_refresh_advance_btn_text()


func _refresh_advance_btn_text() -> void:
	var ctx: Dictionary = _game.get_prematch_context()
	match ctx["match_type"]:
		"important":  _advance_btn.text = GameText.ADVANCE_BTN_IMPORTANT
		"tournament": _advance_btn.text = GameText.ADVANCE_BTN_TOURNAMENT
		"solo":       _advance_btn.text = GameText.ADVANCE_BTN_SOLO
		_:            _advance_btn.text = GameText.ADVANCE_BTN_NORMAL


func _refresh_prematch() -> void:
	var ctx: Dictionary     = _game.get_prematch_context()
	var is_solo: bool       = ctx["is_solo"]
	var is_tournament: bool = ctx["is_tournament"]

	# --- Week header + context line ---
	var match_type: String     = ctx["match_type"]
	var type_upper: String     = GameText.MATCH_TYPE_UPPER.get(match_type, match_type.to_upper())
	_prep_week_lbl.text        = GameText.WEEK_HEADER % [ctx["week"], type_upper]
	_prep_context_lbl.text     = GameText.WEEK_CONTEXT.get(match_type, "")

	# --- Line 1: match type icon + label (drives prep area color) ---
	if is_tournament:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_TOURNAMENT)
	elif is_solo:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_SOLO)
	elif ctx["is_important"]:
		_prep_week_lbl.add_theme_color_override("font_color", COLOR_IMPORTANT)
	else:
		_prep_week_lbl.remove_theme_color_override("font_color")

	# --- Line 3: conditions with morale delta ---
	var cond_parts: PackedStringArray = []
	for entry: Dictionary in ctx["conditions"]:
		var line: String = entry["name"] + ": " + entry["stamina_lbl"]
		if entry["morale_lbl"] != "":
			line += " / " + entry["morale_lbl"]
		# Show morale delta if it changed this week (feedback loop)
		var delta: int = entry.get("morale_delta", 0)
		if delta > 0:
			line += " " + GameText.MORALE_GAIN % delta
		elif delta < 0:
			line += " " + GameText.MORALE_LOSS % delta
		cond_parts.append(line)
	_conditions_lbl.text = "  |  ".join(cond_parts)

	# --- Line 4: warnings ---
	var warnings: PackedStringArray = []
	if ctx["has_tired"]:
		warnings.append(GameText.WARN_TIRED_PLAYER)
	if ctx["is_important"] and not is_solo:
		warnings.append(GameText.WARN_IMPORTANT)
	if is_solo:
		warnings.append(GameText.WARN_SOLO)
	_warning_lbl.text = "  ·  ".join(warnings)

	# --- Solo picker ---
	if is_solo:
		_build_solo_picker(ctx["player_names"])
		_solo_picker.show()
	else:
		_solo_picker.hide()
		_game.selected_solo_player = ""

	# Disable action buttons on solo weeks — only the picker matters.
	for panel in _player_list.get_children():
		panel.set_actions_enabled(not is_solo)


func _build_solo_picker(names: Array) -> void:
	# Clear previous buttons first.
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

	# Restore highlight if already selected.
	_highlight_solo_picker(_game.selected_solo_player)


func _on_solo_player_selected(name: String) -> void:
	_game.selected_solo_player = name
	_highlight_solo_picker(name)
	_update_advance_lock()


func _highlight_solo_picker(selected_name: String) -> void:
	for btn: Button in _solo_btn_row.get_children():
		var is_sel: bool = btn.text == selected_name
		btn.modulate = COLOR_SELECTED_SOLO if is_sel else COLOR_IDLE_SOLO


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
		_advance_btn.text = GameText.GAME_OVER_BTN


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


func _show_result(result: Dictionary) -> void:
	var won:  bool = result["won"]
	var diff: int  = absi(result["team_score"] - result["opponent_score"])
	var is_tournament: bool = result.get("is_tournament", false)
	var is_solo: bool       = result.get("is_solo", false)

	# --- Outcome header ---
	if won:
		_outcome_label.text = GameText.OUTCOME_VICTORY
		_outcome_label.add_theme_color_override("font_color", COLOR_VICTORY)
	else:
		var close: String   = GameText.OUTCOME_CLOSE if diff <= 15 else ""
		_outcome_label.text = GameText.OUTCOME_DEFEAT + close
		_outcome_label.add_theme_color_override("font_color", COLOR_DEFEAT)

	# --- Score / context line ---
	var type_label: String = result.get("type_label", "")
	var score_line: String = GameText.MATCH_SCORE_LINE % [result["team_score"], result["opponent_score"]]
	if is_tournament:
		var rounds_summary: String = GameText.TOURNAMENT_ROUNDS_WON % [
			result.get("rounds_won", 0), result.get("rounds_total", 3)
		]
		_score_label.text = "%s\n%s  ·  %s" % [type_label, score_line, rounds_summary]
	else:
		_score_label.text = type_label + "\n" + score_line

	# --- Summary line (MVP / worst / round summary) ---
	var mvp:   String = result.get("mvp_name",  "") if won else ""
	var best_effort: String = result.get("mvp_name", "") if not won else ""
	var worst: String = result.get("worst_name", "")
	var summary_parts: PackedStringArray = []
	if mvp != "":          summary_parts.append("⭐ MVP: %s" % mvp)
	if best_effort != "": summary_parts.append("💪 Best effort: %s" % best_effort)
	if worst != "":        summary_parts.append("💔 Struggled: %s" % worst)
	if is_tournament:
		summary_parts.append(result.get("round_summary", ""))
	_summary_label.text = "  ·  ".join(summary_parts)

	_clear_results()

	var mvp_name:   String = result.get("mvp_name",  "")
	var worst_name: String = result.get("worst_name", "")

	var stagger: float = 0.0
	for entry: Dictionary in result["players"]:
		var p: Player      = entry["player"]
		if is_solo and entry.get("rested", false):
			continue
		# MVP badge only on wins. On defeat show "best effort" badge instead (handled in ResultRow).
		var is_mvp:        bool = won and p.player_name == mvp_name   and not entry.get("rested", false)
		var is_best_effort: bool = not won and p.player_name == mvp_name and not entry.get("rested", false)
		var is_worst:      bool = p.player_name == worst_name and not entry.get("rested", false)
		var row: ResultRow = RESULT_ROW_SCENE.instantiate()
		_player_results.add_child(row)
		row.setup(p, entry, is_mvp, is_worst, is_best_effort)
		row.animate_xp(stagger)
		stagger += 0.15

	for lu: Dictionary in result.get("level_ups", []):
		var banner: LevelUpBanner = LEVEL_UP_BANNER_SCENE.instantiate()
		_player_results.add_child(banner)
		banner.setup(lu)

	_result_overlay.show()


func _clear_results() -> void:
	for child in _player_results.get_children():
		child.queue_free()


func prepare_new_week() -> void:
	_advance_btn.disabled = false
	_advance_btn.text     = GameText.ADVANCE_BTN_NORMAL
	_actions_chosen       = 0
	_game.selected_solo_player = ""
	for panel in _player_list.get_children():
		panel.reset_action()
	_refresh_prematch()
	_update_advance_lock()
