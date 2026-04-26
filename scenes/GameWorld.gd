# scenes/GameWorld.gd
# Hub screen. Two-panel top layout:
#   LEFT  — match intel (next match opponent, situations, prognosis, estimate)
#   RIGHT — season/quarter goals + week/event
extends Node2D

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")

const ROSTER_SCENE     := preload("res://scenes/RosterScreen.tscn")
const RESOLUTION_SCENE := preload("res://scenes/ResolutionScreen.tscn")
const MARKET_SCENE     := preload("res://ui/components/MarketOverlay.tscn")

const PORTRAIT_PATHS: Array[String] = [
	"res://assets/portraits/portrait1.png",
	"res://assets/portraits/portrait2.png",
	"res://assets/portraits/portrait3.png",
	"res://assets/portraits/portrait4.png",
	"res://assets/portraits/portrait5.png",
]

# Left panel nodes
@onready var _week_label:    Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/WeekLabel
@onready var _opponent_lbl:  Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/OpponentLabel
@onready var _intel_box:     VBoxContainer = $UI/Root/Margin/VBox/TopRow/LeftPanel/IntelBox
@onready var _estimate_lbl:  Label         = $UI/Root/Margin/VBox/TopRow/LeftPanel/EstimateLabel

# Right panel nodes
@onready var _week_mini_lbl: Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/WeekMiniLabel
@onready var _event_lbl:     Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/EventLabel
@onready var _goal_lbl:      Label         = $UI/Root/Margin/VBox/TopRow/RightPanel/GoalLabel

# Squad rows
@onready var _squad_row:     HBoxContainer = $UI/Root/Margin/VBox/SquadRow
@onready var _bench_row:     HBoxContainer = $UI/Root/Margin/VBox/BenchRow

# Buttons
@onready var _end_week_btn:  Button        = $UI/Root/Margin/VBox/ButtonRow/EndWeekBtn
@onready var _market_btn:    Button        = $UI/Root/Margin/VBox/ButtonRow/MarketBtn
@onready var _roster_btn:    Button        = $UI/Root/Margin/VBox/ButtonRow/RosterBtn

var _game: GameManager = null


func _ready() -> void:
	_game = GameManager.new()
	_roster_btn.pressed.connect(_on_roster_btn_pressed)
	_end_week_btn.pressed.connect(_on_end_week_pressed)
	_market_btn.pressed.connect(_on_market_btn_pressed)
	_refresh_ui()


# ---------------------------------------------------------------------------
# UI REFRESH
# ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	var ctx: Dictionary = _game.get_week_context()

	# Left panel — match intel
	_week_label.text   = "Season %d  ·  Week %d" % [ctx["season"], ctx["week"]]
	_opponent_lbl.text = "%s  ·  %s" % [ctx["opponent_name"], ctx["difficulty"]]
	_estimate_lbl.text = ctx["win_estimate"]
	_build_match_intel(ctx)

	# Right panel — goals
	_week_mini_lbl.text = "Season %d  ·  Week %d" % [ctx["season"], ctx["week"]]
	_event_lbl.text     = _build_event_label(ctx)
	_goal_lbl.text      = _build_goal_label()

	_refresh_squad_display(ctx["match_type"])

	_end_week_btn.disabled = not ctx["squad_valid"] or ctx["game_over"]
	_end_week_btn.text = "⚡  Next Week" if ctx["squad_valid"] \
		else "Pick %d players first" % GameManager.SQUAD_SIZE

	_market_btn.visible = _game.market != null and _game.market.is_available(ctx["week"], ctx.get("next_event", {}))
	# Show text so coach knows market is live this week
	_market_btn.text = "📊  Market"


# ---------------------------------------------------------------------------
# MATCH INTEL — left panel: situations + prognosis (Early/Mid/Late per trait)
# ---------------------------------------------------------------------------

func _build_match_intel(ctx: Dictionary) -> void:
	for child in _intel_box.get_children():
		child.queue_free()

	var opponent_traits: Array = ctx.get("opponent_traits", [])
	var situations:      Array = ctx.get("situations", [])
	var modifier:        float = ctx.get("matchup_modifier", 0.0)

	# Opponent traits row
	if opponent_traits.size() > 0:
		var opp_row := HBoxContainer.new()
		opp_row.add_theme_constant_override("separation", 10)
		for t in opponent_traits:
			var lbl := Label.new()
			lbl.text = GameText.trait_label(t)
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
			opp_row.add_child(lbl)
		_intel_box.add_child(opp_row)

	# Match prognosis — always show Early / Mid / Late (pad if only 2 situations)
	if situations.size() > 0:
		var prog_lbl := Label.new()
		prog_lbl.text = "PROGNOSIS"
		prog_lbl.add_theme_font_size_override("font_size", 9)
		prog_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.50))
		_intel_box.add_child(prog_lbl)

		var phase_names: Array[String] = ["Early", "Mid", "Late"]
		var player_traits: Array[String] = ctx.get("player_match_traits", [])
		for i in 3:
			var phase: String = phase_names[i]
			var sit_lbl := Label.new()
			if i < situations.size():
				var sit: String = situations[i]
				var favored: String = GameText.SITUATION_FAVORS.get(sit, "")
				var covered: bool = favored != "" and favored in player_traits
				# Phase label neutral, situation text colored by coverage
				sit_lbl.text = "%s — %s  →  %s" % [
					phase,
					GameText.SITUATION_NAMES.get(sit, sit),
					GameText.trait_label(favored)
				]
				var sit_color: Color = Color(0.30, 0.85, 0.45) if covered else Color(0.85, 0.40, 0.40)
				sit_lbl.add_theme_color_override("font_color", sit_color)
			else:
				sit_lbl.text = "%s — No event" % phase
				sit_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.50))
			sit_lbl.add_theme_font_size_override("font_size", 11)
			sit_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			_intel_box.add_child(sit_lbl)

	# Matchup verdict
	var verdict_lbl := Label.new()
	verdict_lbl.text = GameText.matchup_verdict(modifier)
	var verdict_color: Color
	if modifier >= 8.0:
		verdict_color = Color(0.28, 0.85, 0.45)
	elif modifier <= -8.0:
		verdict_color = Color(0.90, 0.32, 0.32)
	else:
		verdict_color = Color(0.90, 0.78, 0.28)
	verdict_lbl.add_theme_font_size_override("font_size", 11)
	verdict_lbl.add_theme_color_override("font_color", verdict_color)
	_intel_box.add_child(verdict_lbl)


# ---------------------------------------------------------------------------
# SQUAD DISPLAY
# ---------------------------------------------------------------------------

func _refresh_squad_display(match_type: String) -> void:
	for child in _squad_row.get_children():
		child.queue_free()
	for child in _bench_row.get_children():
		child.queue_free()

	for i in _game.players.size():
		var player: Player        = _game.players[i]
		var portrait_path: String = PORTRAIT_PATHS[i] if i < PORTRAIT_PATHS.size() else PORTRAIT_PATHS[0]
		if player.is_active:
			_squad_row.add_child(_make_player_card(player, true,  match_type, portrait_path))
		else:
			_bench_row.add_child(_make_player_card(player, false, match_type, portrait_path))


func _make_player_card(player: Player, is_active: bool, match_type: String, portrait_path: String = "") -> PanelContainer:
	var panel     := PanelContainer.new()
	var margin    := MarginContainer.new()
	var outer_row := HBoxContainer.new()

	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	outer_row.add_theme_constant_override("separation", 10)

	# Portrait
	if portrait_path != "":
		var tex: Texture2D = load(portrait_path)
		if tex != null:
			var portrait := TextureRect.new()
			portrait.texture             = tex
			portrait.custom_minimum_size = Vector2(48, 48) if is_active else Vector2(36, 36)
			portrait.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.modulate            = Color(1, 1, 1, 1) if is_active else Color(0.65, 0.65, 0.70, 1)
			outer_row.add_child(portrait)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = player.player_name
	name_lbl.add_theme_font_size_override("font_size", 15 if is_active else 13)
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 1.0, 1.0) if is_active else Color(0.60, 0.60, 0.65))
	vbox.add_child(name_lbl)

	# Trait — performance icon+name · match trait icon+name
	var trait_lbl := Label.new()
	var perf_label: String = GameText.trait_label(player.primary_trait)
	var mt: String = TraitMatchup.TRAIT_TO_MATCH.get(player.primary_trait, "tactical")
	var mt_label: String = GameText.trait_label(mt)
	trait_lbl.text = perf_label + "  ·  " + mt_label
	trait_lbl.add_theme_font_size_override("font_size", 10)
	trait_lbl.add_theme_color_override("font_color", Color(0.50, 0.75, 1.0))
	vbox.add_child(trait_lbl)

	# Stamina bar
	_add_stat_bar(vbox, "Stamina", player.stamina, _stamina_color(player.stamina_key()))

	# XP bar
	var xp_progress: float  = LevelSystem.level_progress(player)
	var xp_to_next:  int    = LevelSystem.xp_to_next_level(player)
	var xp_suffix:   String = "MAX" if xp_to_next == -1 \
		else "%d / %d" % [player.xp, LevelSystem.LEVEL_THRESHOLDS[player.level]]
	_add_stat_bar(vbox, "Lv.%d  %s" % [player.level, xp_suffix],
		int(xp_progress * 100), Color(0.40, 0.70, 1.0))

	# Coaching voice
	if is_active:
		var voice_text: String = player.voice(match_type)
		if voice_text != "":
			var voice_lbl := Label.new()
			voice_lbl.text = voice_text
			voice_lbl.add_theme_font_size_override("font_size", 11)
			voice_lbl.add_theme_color_override("font_color", Color(0.68, 0.70, 0.80))
			voice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(voice_lbl)

	# Form
	if player.form_label != "":
		var form_lbl := Label.new()
		form_lbl.text = player.form_label
		form_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(form_lbl)

	# Burnout warning
	if player.burnout >= 3:
		var warn_lbl := Label.new()
		warn_lbl.text = "🔥 Burnout warning"
		warn_lbl.add_theme_font_size_override("font_size", 10)
		warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		vbox.add_child(warn_lbl)

	# Bench status + toggle button
	if not is_active:
		var bench_action_lbl: String = "📚 Training" if player.bench_action == "train" else "💤 Resting"
		var bench_lbl := Label.new()
		bench_lbl.text = bench_action_lbl
		bench_lbl.add_theme_font_size_override("font_size", 10)
		bench_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52))
		vbox.add_child(bench_lbl)

		# Toggle button — switches between train and rest
		var toggle_btn := Button.new()
		var other_action: String = "rest" if player.bench_action == "train" else "train"
		var other_label: String  = "Switch to 💤 Rest" if other_action == "rest" else "Switch to 📚 Train"
		toggle_btn.text = other_label
		toggle_btn.add_theme_font_size_override("font_size", 10)
		toggle_btn.custom_minimum_size = Vector2(0, 26)
		var captured_name: String = player.player_name
		toggle_btn.pressed.connect(func(): _on_bench_toggle(captured_name))
		vbox.add_child(toggle_btn)

	outer_row.add_child(vbox)
	margin.add_child(outer_row)
	panel.add_child(margin)
	panel.custom_minimum_size = Vector2(200 if is_active else 155, 0)
	return panel


func _add_stat_bar(parent: VBoxContainer, label: String, value: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(88, 0)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.64))
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value             = 100
	bar.value                 = clamp(value, 0, 100)
	bar.show_percentage       = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size   = Vector2(0, 8)
	bar.modulate              = color
	row.add_child(bar)

	parent.add_child(row)


func _stamina_color(stamina_key: String) -> Color:
	match stamina_key:
		"exhausted": return Color(0.85, 0.22, 0.22)
		"tired":     return Color(0.95, 0.55, 0.15)
		_:           return Color(0.30, 0.80, 0.40)


# ---------------------------------------------------------------------------
# BUTTON HANDLERS
# ---------------------------------------------------------------------------

func _on_roster_btn_pressed() -> void:
	var roster: RosterScreen = ROSTER_SCENE.instantiate()
	roster.closed.connect(_on_roster_closed)
	$UI.add_child(roster)
	roster.setup(_game)


func _on_roster_closed() -> void:
	_refresh_ui()


func _on_end_week_pressed() -> void:
	_end_week_btn.disabled = true
	var result: WeekResult = _game.advance_week()
	var resolution: ResolutionScreen = RESOLUTION_SCENE.instantiate()
	resolution.finished.connect(_on_resolution_finished)
	$UI.add_child(resolution)
	resolution.setup(result, _game)


func _on_resolution_finished() -> void:
	_refresh_ui()


func _on_market_btn_pressed() -> void:
	var overlay: MarketOverlay = MARKET_SCENE.instantiate()
	overlay.market_closed.connect(_on_market_closed)
	$UI.add_child(overlay)
	overlay.open(_game)


func _on_market_closed() -> void:
	_refresh_ui()


func _on_bench_toggle(player_name: String) -> void:
	_game.toggle_bench_action(player_name)
	_refresh_ui()


# ---------------------------------------------------------------------------
# TEXT HELPERS
# ---------------------------------------------------------------------------

func _build_event_label(ctx: Dictionary) -> String:
	var next: Dictionary = ctx.get("next_event", {})
	if next.is_empty():
		return ""
	var type_display: String = GameText.MATCH_TYPE.get(next["type"], next["type"])
	return "Next: %s in %d week%s" % [type_display, next["weeks_away"],
		"s" if next["weeks_away"] != 1 else ""]


func _build_goal_label() -> String:
	if _game.goal_manager == null:
		return ""
	var lines: Array = []
	var sg: Dictionary = _game.goal_manager.get_display()
	if sg.get("description", "") != "":
		lines.append(sg["description"])
	var qg: Dictionary = _game.goal_manager.get_quarter_display()
	if qg.get("description", "") != "":
		lines.append(qg["description"])
	return "\n".join(lines)
