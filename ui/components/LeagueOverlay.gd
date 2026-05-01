# ui/components/LeagueOverlay.gd
# Full-screen overlay showing league standings.
# Opened by GameWorld via _on_league_btn_pressed().
# Self-contained: reads from the GameDirector autoload, builds rows, closes on button.
#
# B1 NOTE: No longer takes a GameManager argument.
extends Control

signal closed

@onready var _season_label:    Label         = $OuterMargin/VBox/TitleRow/SeasonLabel
@onready var _standings_list:  VBoxContainer = $OuterMargin/VBox/StandingsList
@onready var _close_btn:       Button        = $OuterMargin/VBox/CloseBtn

# Tier accent colors
const COLOR_TOP_ACCENT:  Color = Color(0.28, 0.85, 0.45, 1.0)   # green — top 3
const COLOR_BOT_ACCENT:  Color = Color(0.90, 0.32, 0.32, 1.0)   # red   — bottom 2
const COLOR_MID:         Color = Color(0.75, 0.75, 0.82, 1.0)   # normal
const COLOR_PLAYER_NAME: Color = Color(0.55, 0.82, 1.00, 1.0)   # blue highlight
const COLOR_DIM:         Color = Color(0.45, 0.47, 0.55, 1.0)   # dimmed record
const COLOR_PTS:         Color = Color(0.95, 0.90, 0.70, 1.0)   # warm pts

const BG_PLAYER: Color  = Color(0.12, 0.18, 0.28, 1.0)          # subtle blue bg for player row
const BG_TOP:    Color  = Color(0.08, 0.18, 0.10, 0.60)         # subtle green bg for top 3
const BG_BOT:    Color  = Color(0.22, 0.08, 0.08, 0.60)         # subtle red bg for bottom 2


func _ready() -> void:
	_close_btn.pressed.connect(_on_close)


func open() -> void:
	_season_label.text = "Season %d  ·  Week %d" % [GameDirector.season, GameDirector.week_in_season]
	_build_standings()
	visible = true


func _build_standings() -> void:
	for child in _standings_list.get_children():
		child.queue_free()

	var standings: Array[Dictionary] = GameDirector.get_standings()
	var rank_int:  int               = GameDirector.league_rank()

	for entry in standings:
		var row: PanelContainer = _make_row(entry, rank_int)
		_standings_list.add_child(row)


func _make_row(entry: Dictionary, player_rank: int) -> PanelContainer:
	var rank:      int    = entry.get("rank", 0)
	var name_:     String = entry.get("name", "Unknown")
	var wins:      int    = entry.get("wins", 0)
	var losses:    int    = entry.get("losses", 0)
	var points:    int    = entry.get("points", 0)
	var is_player: bool   = entry.get("is_player", false)
	var tier:      String = entry.get("tier", "mid")

	# Outer panel for background color
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 3

	if is_player:
		style.bg_color           = BG_PLAYER
		style.border_color       = COLOR_PLAYER_NAME
	elif tier == "top":
		style.bg_color           = BG_TOP
		style.border_color       = COLOR_TOP_ACCENT
	elif tier == "bot":
		style.bg_color           = BG_BOT
		style.border_color       = COLOR_BOT_ACCENT
	else:
		style.bg_color     = Color(0.10, 0.11, 0.15, 0.40)
		style.border_color = Color(0.20, 0.22, 0.28, 0.0)

	panel.add_theme_stylebox_override("panel", style)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   12)
	inner.add_theme_constant_override("margin_top",    10)
	inner.add_theme_constant_override("margin_right",  12)
	inner.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(inner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	inner.add_child(hbox)

	# Rank number
	var rank_lbl := Label.new()
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	rank_lbl.text = str(rank)
	rank_lbl.add_theme_font_size_override("font_size", 15)
	var rank_col: Color = COLOR_TOP_ACCENT if tier == "top" \
		else COLOR_BOT_ACCENT if tier == "bot" \
		else COLOR_DIM
	rank_lbl.add_theme_color_override("font_color", rank_col)
	hbox.add_child(rank_lbl)

	# Team name
	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text = name_
	name_lbl.add_theme_font_size_override("font_size", 15)
	var name_col: Color = COLOR_PLAYER_NAME if is_player \
		else COLOR_TOP_ACCENT if tier == "top" \
		else COLOR_BOT_ACCENT if tier == "bot" \
		else COLOR_MID
	name_lbl.add_theme_color_override("font_color", name_col)
	if is_player:
		name_lbl.text += "  ◀"
	hbox.add_child(name_lbl)

	# W-L record
	var rec_lbl := Label.new()
	rec_lbl.custom_minimum_size = Vector2(60, 0)
	rec_lbl.text = "%d–%d" % [wins, losses]
	rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec_lbl.add_theme_font_size_override("font_size", 13)
	rec_lbl.add_theme_color_override("font_color", COLOR_DIM)
	hbox.add_child(rec_lbl)

	# Points
	var pts_lbl := Label.new()
	pts_lbl.custom_minimum_size = Vector2(50, 0)
	pts_lbl.text = str(points)
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.add_theme_font_size_override("font_size", 15)
	pts_lbl.add_theme_color_override("font_color",
		COLOR_PLAYER_NAME if is_player else COLOR_PTS)
	hbox.add_child(pts_lbl)

	return panel


func _on_close() -> void:
	visible = false
	closed.emit()
