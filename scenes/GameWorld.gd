# scenes/GameWorld.gd
# Hub screen: match intel (left) and season goals (right).
# Builds squad/bench rows using PlayerCard.tscn instances.
#
# B1 NOTE: This script no longer holds a `_game` reference. It reads
# from the `GameDirector` autoload directly. The legacy `GameManager`
# class is gone.
extends Node2D

const TraitMatchup     := preload("res://scripts/systems/TraitMatchup.gd")
const ROSTER_SCENE     := preload("res://scenes/RosterScreen.tscn")
const RESOLUTION_SCENE := preload("res://scenes/ResolutionScreen.tscn")
const MARKET_SCENE     := preload("res://ui/components/MarketOverlay.tscn")
const LEAGUE_SCENE     := preload("res://ui/components/LeagueOverlay.tscn")
const PLAYER_CARD      := preload("res://ui/components/PlayerCard.tscn")

const PORTRAIT_PATHS: Array[String] = [
	"res://assets/portraits/portrait1.png",
	"res://assets/portraits/portrait2.png",
	"res://assets/portraits/portrait3.png",
	"res://assets/portraits/portrait4.png",
	"res://assets/portraits/portrait5.png",
]

# Intel panel display constants — tweak here, not scattered in build functions
const FONT_OPP_TRAIT:  int   = 12
const FONT_PROGNOSIS:  int   = 9
const FONT_SIT_LINE:   int   = 11
const FONT_VERDICT:    int   = 11
const COLOR_OPP_TRAIT: Color = Color(0.95, 0.72, 0.35)
const COLOR_PROGNOSIS: Color = Color(0.40, 0.40, 0.50)
const COLOR_NO_EVENT:  Color = Color(0.40, 0.40, 0.50)
const COLOR_COVERED:   Color = Color(0.30, 0.85, 0.45)
const COLOR_MISSING:   Color = Color(0.85, 0.40, 0.40)
const COLOR_GOOD:      Color = Color(0.28, 0.85, 0.45)
const COLOR_BAD:       Color = Color(0.90, 0.32, 0.32)
const COLOR_NEUTRAL:   Color = Color(0.90, 0.78, 0.28)
const OPP_ROW_SEP:     int   = 10

@onready var _week_label:   Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/WeekLabel
@onready var _opponent_lbl: Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/OpponentLabel
@onready var _intel_box:    VBoxContainer = $UI/Root/Margin/VBox/TopRow/LeftPanel/IntelBox
@onready var _estimate_lbl: Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/EstimateLabel
@onready var _week_mini:    Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/WeekMiniLabel
@onready var _event_lbl:    Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/EventLabel
@onready var _goal_lbl:     Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/GoalLabel
@onready var _squad_row:    HBoxContainer = $UI/Root/Margin/VBox/SquadRow
@onready var _bench_row:    HBoxContainer = $UI/Root/Margin/VBox/BenchRow
@onready var _end_week_btn:    Button         = $UI/Root/Margin/VBox/ButtonRow/EndWeekBtn
@onready var _market_btn:      Button         = $UI/Root/Margin/VBox/ButtonRow/MarketBtn
@onready var _roster_btn:      Button         = $UI/Root/Margin/VBox/ButtonRow/RosterBtn
@onready var _league_btn:      Button         = $UI/Root/Margin/VBox/ButtonRow/LeagueBtn
@onready var _league_rank_lbl: Label          = $UI/Root/Margin/VBox/TopRow/RightPanel/LeagueRankLabel
@onready var _league_overlay:  Control        = $UI/Root/LeagueOverlay
@onready var _goal_banner:     PanelContainer = $UI/Root/GoalBanner
@onready var _banner_label: Label          = $UI/Root/GoalBanner/BannerMargin/BannerRow/BannerLabel
@onready var _banner_dismiss: Button       = $UI/Root/GoalBanner/BannerMargin/BannerRow/BannerDismiss


func _ready() -> void:
	_roster_btn.pressed.connect(_on_roster_btn_pressed)
	_end_week_btn.pressed.connect(_on_end_week_pressed)
	_market_btn.pressed.connect(_on_market_btn_pressed)
	_banner_dismiss.pressed.connect(_on_banner_dismissed)
	_league_btn.pressed.connect(_on_league_btn_pressed)
	_league_overlay.closed.connect(_on_league_closed)
	# B3: banner is now reactive — connect to SignalHub instead of polling pending_banner.
	SignalHub.goal_achieved.connect(_on_goal_achieved)
	SignalHub.quarter_bonus_triggered.connect(_on_quarter_bonus_triggered)
	SignalHub.patch_rotated.connect(_on_patch_rotated)
	SignalHub.season_ended.connect(_on_season_ended)
	# B4: squad/bench commands are now reactive.
	SignalHub.bench_action_changed.connect(_on_bench_action_changed)
	SignalHub.squad_changed.connect(_on_squad_changed)
	_refresh_ui()


# ---------------------------------------------------------------------------
# UI REFRESH
# ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	var ctx: Dictionary = GameDirector.get_week_context()

	_week_label.text   = "Season %d  ·  Week %d" % [ctx["season"], ctx["week"]]
	_opponent_lbl.text = "%s  ·  %s" % [ctx["opponent_name"], ctx["difficulty"]]
	_estimate_lbl.text = ctx["win_estimate"]
	_build_match_intel(ctx)

	_week_mini.text = "Season %d  ·  Week %d" % [ctx["season"], ctx["week"]]
	_event_lbl.text = _build_event_label(ctx)
	_goal_lbl.text  = _build_goal_label()

	_refresh_squad_display(ctx["match_type"])

	_end_week_btn.disabled = not ctx["squad_valid"] or ctx["game_over"]
	_end_week_btn.text = "⚡  Next Week" if ctx["squad_valid"] \
		else "Pick %d players first" % GameDirector.SQUAD_SIZE

	_market_btn.visible = GameDirector.market != null \
		and GameDirector.market.is_available(ctx["week"], ctx.get("next_event", {}))

	# League rank mini-label in right panel
	var rank: int    = GameDirector.league_rank()
	var rec:  String = GameDirector.league_record()
	_league_rank_lbl.text = "🏆  Rank %d / 8  ·  %s" % [rank, rec] if rank > 0 \
		else "🏆  Standings"


# ---------------------------------------------------------------------------
# MATCH INTEL — left panel: opponent traits + Early/Mid/Late prognosis
# ---------------------------------------------------------------------------

func _build_match_intel(ctx: Dictionary) -> void:
	for child in _intel_box.get_children():
		child.queue_free()

	var opponent_traits: Array = ctx.get("opponent_traits", [])
	var situations:      Array = ctx.get("situations", [])
	var modifier:        float = ctx.get("matchup_modifier", 0.0)
	var player_traits:   Array = ctx.get("player_match_traits", [])

	# Opponent trait icons
	if opponent_traits.size() > 0:
		var opp_row := HBoxContainer.new()
		opp_row.add_theme_constant_override("separation", OPP_ROW_SEP)
		for t in opponent_traits:
			var lbl := Label.new()
			lbl.text = GameText.trait_label(t)
			lbl.add_theme_font_size_override("font_size", FONT_OPP_TRAIT)
			lbl.add_theme_color_override("font_color", COLOR_OPP_TRAIT)
			opp_row.add_child(lbl)
		_intel_box.add_child(opp_row)

	# Prognosis: always show Early / Mid / Late (gray "No event" if only 2 situations)
	if situations.size() > 0:
		var prog_lbl := Label.new()
		prog_lbl.text = "PROGNOSIS"
		prog_lbl.add_theme_font_size_override("font_size", FONT_PROGNOSIS)
		prog_lbl.add_theme_color_override("font_color", COLOR_PROGNOSIS)
		_intel_box.add_child(prog_lbl)

		for i in 3:
			var sit_lbl := Label.new()
			sit_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sit_lbl.add_theme_font_size_override("font_size", FONT_SIT_LINE)
			if i < situations.size():
				var sit:     String = situations[i]
				var favored: String = TraitMatchup.SITUATION_FAVORS.get(sit, "")
				var covered: bool   = favored != "" and favored in player_traits
				sit_lbl.text = "%s — %s  →  %s" % [
					["Early", "Mid", "Late"][i],
					GameText.SITUATION_NAMES.get(sit, sit),
					GameText.trait_label(favored)
				]
				sit_lbl.add_theme_color_override("font_color",
					COLOR_COVERED if covered else COLOR_MISSING)
			else:
				sit_lbl.text = "%s — No event" % ["Early", "Mid", "Late"][i]
				sit_lbl.add_theme_color_override("font_color", COLOR_NO_EVENT)
			_intel_box.add_child(sit_lbl)

	# Matchup verdict
	var verdict_lbl := Label.new()
	verdict_lbl.text = GameText.matchup_verdict(modifier)
	verdict_lbl.add_theme_font_size_override("font_size", FONT_VERDICT)
	verdict_lbl.add_theme_color_override("font_color",
		COLOR_GOOD if modifier >= 8.0 else COLOR_BAD if modifier <= -8.0 else COLOR_NEUTRAL)
	_intel_box.add_child(verdict_lbl)


# ---------------------------------------------------------------------------
# SQUAD DISPLAY — PlayerCard instances
# ---------------------------------------------------------------------------

func _refresh_squad_display(match_type: String) -> void:
	for child in _squad_row.get_children():
		child.queue_free()
	for child in _bench_row.get_children():
		child.queue_free()

	for i in GameDirector.players.size():
		var player: Player        = GameDirector.players[i]
		var portrait_path: String = PORTRAIT_PATHS[i] if i < PORTRAIT_PATHS.size() else PORTRAIT_PATHS[0]
		var tex: Texture2D        = load(portrait_path)
		var card: PlayerCard      = PLAYER_CARD.instantiate()
		if player.is_active:
			_squad_row.add_child(card)
		else:
			_bench_row.add_child(card)
		card.setup(player, player.is_active, match_type, tex)
		card.bench_toggle_pressed.connect(_on_bench_toggle)


# ---------------------------------------------------------------------------
# BUTTON HANDLERS
# ---------------------------------------------------------------------------

func _on_roster_btn_pressed() -> void:
	var roster: RosterScreen = ROSTER_SCENE.instantiate()
	roster.closed.connect(_on_roster_closed)
	$UI.add_child(roster)
	roster.setup()


func _on_roster_closed() -> void:
	_refresh_ui()


func _on_end_week_pressed() -> void:
	_end_week_btn.disabled = true
	var result: WeekResult = GameDirector.advance_week()
	var resolution: ResolutionScreen = RESOLUTION_SCENE.instantiate()
	resolution.finished.connect(_on_resolution_finished)
	$UI.add_child(resolution)
	resolution.setup(result)


func _on_resolution_finished() -> void:
	_refresh_ui()


# B3: Banner is shown reactively via SignalHub signal handlers below.
# The old _show_banner_if_pending() polling method has been removed.

func _show_banner(text: String) -> void:
	_banner_label.text = text
	_goal_banner.show()


func _on_goal_achieved(description: String) -> void:
	_show_banner("🏆 Season goal complete! " + description)


func _on_quarter_bonus_triggered(description: String) -> void:
	_show_banner("🌟 " + description)


func _on_patch_rotated(buffed_archetype: String, nerfed_archetype: String) -> void:
	_show_banner("📰 New patch: %s buffed · %s nerfed" % [
		GameText.trait_label(buffed_archetype).strip_edges(),
		GameText.trait_label(nerfed_archetype).strip_edges(),
	])


func _on_season_ended(rank: int, _description: String) -> void:
	_show_banner("🏁 Season over — Rank %d / 8" % rank)


# B4: Reactive handlers for squad/bench command signals.
func _on_bench_action_changed(_player: Player, _action: String) -> void:
	# A benched player's action changed — refresh the bench row display.
	var ctx: Dictionary = GameDirector.get_week_context()
	_refresh_squad_display(ctx["match_type"])


func _on_squad_changed(_active: Array, _benched: Array) -> void:
	# Active/bench split changed — full UI refresh (end-week validity may change).
	_refresh_ui()


func _on_banner_dismissed() -> void:
	_goal_banner.hide()


func _on_league_btn_pressed() -> void:
	_league_overlay.open()


func _on_league_closed() -> void:
	_refresh_ui()


func _on_market_btn_pressed() -> void:
	var overlay: MarketOverlay = MARKET_SCENE.instantiate()
	overlay.market_closed.connect(_on_market_closed)
	$UI.add_child(overlay)
	overlay.open()


func _on_market_closed() -> void:
	_refresh_ui()


func _on_bench_toggle(player_name: String) -> void:
	# B4: mutation + signal emission handled in GameDirector.toggle_bench_action.
	# bench_action_changed signal drives the refresh.
	GameDirector.toggle_bench_action(player_name)


# ---------------------------------------------------------------------------
# TEXT HELPERS
# ---------------------------------------------------------------------------

func _build_event_label(ctx: Dictionary) -> String:
	var next: Dictionary = ctx.get("next_event", {})
	if next.is_empty():
		return ""
	var type_display: String = GameText.MATCH_TYPE.get(next["type"], next["type"])
	return "Next: %s in %d week%s" % [
		type_display, next["weeks_away"],
		"s" if next["weeks_away"] != 1 else ""
	]


func _build_goal_label() -> String:
	if GameDirector.goal_manager == null:
		return ""
	var lines: Array = []
	var sg: Dictionary = GameDirector.goal_manager.get_display()
	if sg.get("description", "") != "":
		lines.append(sg["description"])
	var qg: Dictionary = GameDirector.goal_manager.get_quarter_display()
	if qg.get("description", "") != "":
		lines.append(qg["description"])
	return "\n".join(lines)
