# scenes/GameWorld.gd
# Hub screen — week context, squad cards, Next Week button.
# Shows pre-match intel: opponent name, traits (with icons), situations, matchup verdict.
extends Node2D

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")

const ROSTER_SCENE     := preload("res://scenes/RosterScreen.tscn")
const RESOLUTION_SCENE := preload("res://scenes/ResolutionScreen.tscn")

const PORTRAIT_PATHS: Array[String] = [
	"res://assets/portraits/portrait1.png",
	"res://assets/portraits/portrait2.png",
	"res://assets/portraits/portrait3.png",
	"res://assets/portraits/portrait4.png",
	"res://assets/portraits/portrait5.png",
]

@onready var _week_label:    Label         = $UI/Root/Margin/VBox/Header/WeekLabel
@onready var _event_lbl:     Label         = $UI/Root/Margin/VBox/Header/EventLabel
@onready var _goal_lbl:      Label         = $UI/Root/Margin/VBox/Header/GoalLabel
@onready var _opponent_lbl:  Label         = $UI/Root/Margin/VBox/MatchInfo/OpponentLabel
@onready var _estimate_lbl:  Label         = $UI/Root/Margin/VBox/MatchInfo/EstimateLabel
@onready var _intel_box:     VBoxContainer = $UI/Root/Margin/VBox/IntelBox
@onready var _squad_row:     HBoxContainer = $UI/Root/Margin/VBox/SquadRow
@onready var _bench_row:     HBoxContainer = $UI/Root/Margin/VBox/BenchRow
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

	_week_label.text  = "Season %d  ·  Week %d" % [ctx["season"], ctx["week"]]
	_event_lbl.text   = _build_event_label(ctx)
	_goal_lbl.text    = _build_goal_label()

	# Opponent header — name + difficulty
	_opponent_lbl.text = "%s  ·  %s" % [ctx["opponent_name"], ctx["difficulty"]]
	_estimate_lbl.text = ctx["win_estimate"]

	# Pre-match intel block
	_build_match_intel(ctx)

	_refresh_squad_display(ctx["match_type"])

	_end_week_btn.disabled = not ctx["squad_valid"] or ctx["game_over"]
	_end_week_btn.text = "⚡  Next Week" if ctx["squad_valid"] \
		else "Pick %d players first" % GameManager.SQUAD_SIZE

	_market_btn.visible = _game.market != null and _game.market.is_available(ctx["week"], ctx.get("next_event", {}))


# ---------------------------------------------------------------------------
# MATCH INTEL — pre-match panel: opponent traits + situations + verdict
# Builds into _intel_box (VBoxContainer in the scene).
# Falls back gracefully if _intel_box is null (scene not updated yet).
# ---------------------------------------------------------------------------

func _build_match_intel(ctx: Dictionary) -> void:
	if _intel_box == null:
		return
	for child in _intel_box.get_children():
		child.queue_free()

	var opponent_traits:  Array = ctx.get("opponent_traits", [])
	var situations:       Array = ctx.get("situations", [])
	var modifier:         float = ctx.get("matchup_modifier", 0.0)

	# --- Section: Opponent traits ---
	_add_intel_section_header(_intel_box, "Opponent style")
	var traits_row := HBoxContainer.new()
	traits_row.add_theme_constant_override("separation", 8)
	for t in opponent_traits:
		var badge := _make_trait_badge(t, false)
		traits_row.add_child(badge)
	_intel_box.add_child(traits_row)

	# --- Section: Match situations ---
	_add_intel_section_header(_intel_box, "Today's match")
	for sit in situations:
		var sit_lbl := Label.new()
		var favored_trait: String = GameText.SITUATION_FAVORS.get(sit, "")
		var favored_label: String = GameText.trait_label(favored_trait)
		sit_lbl.text = GameText.situation_label(sit) + "  →  " + favored_label
		sit_lbl.add_theme_font_size_override("font_size", 11)
		sit_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.85))
		_intel_box.add_child(sit_lbl)

	# --- Section: Matchup verdict ---
	var verdict_lbl := Label.new()
	verdict_lbl.text = GameText.matchup_verdict(modifier)
	var verdict_color: Color
	if modifier >= 8.0:
		verdict_color = Color(0.30, 0.85, 0.45)
	elif modifier <= -8.0:
		verdict_color = Color(0.90, 0.35, 0.35)
	else:
		verdict_color = Color(0.90, 0.80, 0.30)
	verdict_lbl.add_theme_font_size_override("font_size", 11)
	verdict_lbl.add_theme_color_override("font_color", verdict_color)
	_intel_box.add_child(verdict_lbl)

	# --- Balance Fix 3: Your squad's counter hint ---
	# Show what each active player's match trait beats and loses to,
	# right on the pre-match panel so the player learns the matrix.
	var active: Array[Player] = _game.active_players()
	if active.size() > 0:
		_add_intel_section_header(_intel_box, "Your squad counters")
		for p in active:
			var mt: String = TraitMatchup.TRAIT_TO_MATCH.get(p.primary_trait, "tactical")
			var beats_arr: Array = TraitMatchup.WINS_AGAINST.get(mt, [])
			var weak_arr:  Array = TraitMatchup.LOSES_AGAINST.get(mt, [])
			var beats_labels: Array = beats_arr.map(func(t): return GameText.TRAIT_NAMES.get(t, t))
			var weak_labels:  Array = weak_arr.map(func(t):  return GameText.TRAIT_NAMES.get(t, t))
			var hint_lbl := Label.new()
			var b_str: String = " ↑ " + ", ".join(beats_labels) if beats_labels.size() > 0 else ""
			var w_str: String = " ↓ " + ", ".join(weak_labels)  if weak_labels.size()  > 0 else ""
			hint_lbl.text = GameText.trait_label(p.primary_trait) + b_str + w_str
			hint_lbl.add_theme_font_size_override("font_size", 10)
			hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
			_intel_box.add_child(hint_lbl)


func _add_intel_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.48))
	parent.add_child(lbl)


# Makes a compact trait badge label for the intel panel.
# is_player = true → blue tint (your trait); false → amber tint (opponent trait).
func _make_trait_badge(trait_key: String, is_player: bool) -> Label:
	var lbl := Label.new()
	lbl.text = GameText.trait_label(trait_key)
	lbl.add_theme_font_size_override("font_size", 11)
	var col: Color = Color(0.50, 0.75, 1.0) if is_player else Color(0.95, 0.72, 0.35)
	lbl.add_theme_color_override("font_color", col)
	return lbl


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

	# Trait — icon + name (performance trait) + match trait hint
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

	# Coaching voice for active players
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

	# Bench status label
	if not is_active:
		var bench_lbl := Label.new()
		bench_lbl.text = "📚 Training" if player.primary_trait == "grinder" else "💤 Resting"
		bench_lbl.add_theme_font_size_override("font_size", 10)
		bench_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52))
		vbox.add_child(bench_lbl)

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
	pass  # Market overlay — wired in a future pass


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
