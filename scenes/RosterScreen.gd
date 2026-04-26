# scenes/RosterScreen.gd
# Squad selection screen. Two columns: bench (left) ↔ active (right).
# Click any player card to move them to the other column.
# Active column = green border. Bench column = grey border.
class_name RosterScreen
extends Control

signal closed

const PORTRAITS: Array[String] = [
	"res://assets/portraits/portrait1.png",
	"res://assets/portraits/portrait2.png",
	"res://assets/portraits/portrait3.png",
	"res://assets/portraits/portrait4.png",
	"res://assets/portraits/portrait5.png",
]

const COLOR_ACTIVE_BORDER := Color(0.25, 0.80, 0.40, 1.0)
const COLOR_BENCH_BORDER  := Color(0.28, 0.28, 0.35, 1.0)
const COLOR_ACTIVE_BG     := Color(0.10, 0.18, 0.12, 1.0)
const COLOR_BENCH_BG      := Color(0.10, 0.10, 0.14, 1.0)

var _game: GameManager = null


func _ready() -> void:
	$Margin/VBox/HeaderRow/CloseBtn.pressed.connect(_on_close_btn_pressed)


func setup(game: GameManager) -> void:
	_game = game
	_build()


func _build() -> void:
	if _game == null:
		return

	var bench_list:  VBoxContainer = $Margin/VBox/Columns/BenchColumn/BenchList
	var active_list: VBoxContainer = $Margin/VBox/Columns/ActiveColumn/ActiveList

	for child in bench_list.get_children():
		child.queue_free()
	for child in active_list.get_children():
		child.queue_free()

	var active_count: int = _game.active_players().size()
	var bench_count:  int = _game.benched_players().size()

	$Margin/VBox/SubLabel.text = (
		"Click a player to move between bench and squad  ·  %d / %d active" % [
			active_count, GameManager.SQUAD_SIZE
		]
	)
	$Margin/VBox/Columns/ActiveColumn/ActiveHeader.text = (
		"ACTIVE SQUAD  ·  %d / %d" % [active_count, GameManager.SQUAD_SIZE]
	)

	for i in _game.players.size():
		var player: Player    = _game.players[i]
		var portrait: String  = PORTRAITS[i] if i < PORTRAITS.size() else PORTRAITS[0]
		var target_player: Player = null
		# When active column is full, clicking a bench player will swap with the
		# last active — find that player so we can show who gets bumped.
		if not player.is_active and active_count >= GameManager.SQUAD_SIZE:
			var active: Array[Player] = _game.active_players()
			target_player = active[active.size() - 1]
		var card: Control = _make_card(player, portrait, target_player)
		if player.is_active:
			active_list.add_child(card)
		else:
			bench_list.add_child(card)


func _make_card(player: Player, portrait_path: String, swap_target: Player) -> PanelContainer:
	var is_active: bool = player.is_active

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)

	# Coloured border via StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color           = COLOR_ACTIVE_BG if is_active else COLOR_BENCH_BG
	style.border_color       = COLOR_ACTIVE_BORDER if is_active else COLOR_BENCH_BORDER
	style.border_width_left  = 3
	style.border_width_right = 3
	style.border_width_top   = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Portrait
	var portrait_rect := TextureRect.new()
	var tex: Texture2D = load(portrait_path)
	if tex != null:
		portrait_rect.texture = tex
	portrait_rect.custom_minimum_size = Vector2(60, 60)
	portrait_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.modulate = Color(1, 1, 1, 1) if is_active else Color(0.65, 0.65, 0.70, 1)
	row.add_child(portrait_rect)

	# Content
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)

	# Name + badge row
	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = player.player_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.72, 0.72, 0.76, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var badge := Label.new()
	badge.text = "● ACTIVE" if is_active else "○  bench"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color",
		COLOR_ACTIVE_BORDER if is_active else COLOR_BENCH_BORDER)
	name_row.add_child(badge)
	vbox.add_child(name_row)

	# Trait
	var trait_lbl := Label.new()
	trait_lbl.text = GameText.TRAIT_DESCRIPTIONS.get(player.primary_trait, player.primary_trait)
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.add_theme_color_override("font_color", Color(0.50, 0.75, 1.0, 1.0))
	vbox.add_child(trait_lbl)

	# Bio
	var bio_lbl := Label.new()
	bio_lbl.text = player.bio
	bio_lbl.add_theme_font_size_override("font_size", 10)
	bio_lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.55, 1.0))
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(bio_lbl)

	# Stamina bar
	_add_bar(vbox, "Stamina", player.stamina, _stamina_bar_color(player.stamina_key()))
	# XP bar
	var xp_pct: float = LevelSystem.level_progress(player)
	var xp_to_next: int = LevelSystem.xp_to_next_level(player)
	var xp_label: String = "MAX" if xp_to_next == -1 else "%d/%d XP" % [player.xp, LevelSystem.LEVEL_THRESHOLDS[player.level]]
	_add_bar(vbox, "Lv.%d  %s" % [player.level, xp_label], int(xp_pct * 100), Color(0.40, 0.70, 1.0, 1.0))

	# Warnings
	if player.burnout >= 3:
		var warn := Label.new()
		warn.text = "🔥 Burnout — needs rest"
		warn.add_theme_font_size_override("font_size", 10)
		warn.add_theme_color_override("font_color", Color(1.0, 0.38, 0.18, 1.0))
		vbox.add_child(warn)

	if player.form_label != "":
		var form := Label.new()
		form.text = player.form_label
		form.add_theme_font_size_override("font_size", 11)
		vbox.add_child(form)

	# Action hint
	var hint_lbl := Label.new()
	if is_active:
		hint_lbl.text = "→ Click to bench"
		hint_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 1.0))
	elif swap_target != null:
		hint_lbl.text = "→ Click to swap with %s" % swap_target.player_name
		hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25, 1.0))
	else:
		hint_lbl.text = "→ Click to activate"
		hint_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45, 1.0))
	hint_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint_lbl)

	row.add_child(vbox)
	margin.add_child(row)
	panel.add_child(margin)

	# Full-card click button
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.add_theme_color_override("font_color",         Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color",   Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var captured_name: String = player.player_name
	btn.pressed.connect(func(): _on_card_clicked(captured_name))
	panel.add_child(btn)

	return panel


func _add_bar(parent: VBoxContainer, label: String, value: int, color: Color) -> void:
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65, 1.0))
	bar_row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value     = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size   = Vector2(0, 10)
	bar.modulate = color
	bar_row.add_child(bar)

	parent.add_child(bar_row)


func _stamina_bar_color(stamina_key: String) -> Color:
	match stamina_key:
		"exhausted": return Color(0.85, 0.22, 0.22, 1.0)
		"tired":     return Color(0.95, 0.55, 0.15, 1.0)
		_:           return Color(0.30, 0.80, 0.40, 1.0)


# ---------------------------------------------------------------------------
# INTERACTION — click to move between bench and active
# ---------------------------------------------------------------------------

func _on_card_clicked(player_name: String) -> void:
	var player: Player = _find_player(player_name)
	if player == null:
		return

	if player.is_active:
		# Move to bench
		player.is_active = false
	else:
		# Move to active — GameManager handles bumping if full
		_game.set_active(player_name)

	_build()


func _find_player(player_name: String) -> Player:
	for p in _game.players:
		if p.player_name == player_name:
			return p
	return null


func _on_close_btn_pressed() -> void:
	closed.emit()
	queue_free()
