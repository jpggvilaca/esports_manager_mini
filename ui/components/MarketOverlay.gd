# ui/components/MarketOverlay.gd
# ============================================================
# MARKET OVERLAY — displays the player market and handles hire flow.
#
# Flow:
#   1. GameWorld calls open(game) → overlay generates candidates and shows.
#   2. Player clicks a candidate card → ConfirmPanel appears with "Replace who?" buttons.
#   3. Player chooses a roster slot → hire_candidate() is called → cards refresh.
#   4. Player clicks Close → market_closed signal fires → GameWorld hides overlay.
#
# TO TWEAK card appearance → _build_player_card() / _build_candidate_card()
# TO TWEAK hire confirmation text → ConfirmLabel in the scene
# ============================================================
class_name MarketOverlay
extends Control

signal market_closed   # fired when the player closes the overlay

# Colors
const COLOR_CANDIDATE_IDLE    := Color(0.14, 0.18, 0.24, 1.0)
const COLOR_CANDIDATE_HOVER   := Color(0.20, 0.28, 0.40, 1.0)
const COLOR_CANDIDATE_SELECTED := Color(0.15, 0.35, 0.55, 1.0)
const COLOR_ROSTER_REPLACE    := Color(0.70, 0.25, 0.25, 1.0)
const COLOR_ROSTER_IDLE       := Color(0.18, 0.18, 0.22, 1.0)
const COLOR_NO_SLOTS          := Color(0.40, 0.40, 0.40, 1.0)

# Node references
@onready var _slots_lbl:       Label         = $OuterMargin/VBox/TitleRow/SlotsLabel
@onready var _roster_list:     VBoxContainer = $OuterMargin/VBox/ContentRow/RosterColumn/RosterList
@onready var _candidates_list: VBoxContainer = $OuterMargin/VBox/ContentRow/CandidatesColumn/CandidatesList
@onready var _confirm_panel:   PanelContainer = $OuterMargin/VBox/ConfirmPanel
@onready var _confirm_lbl:     Label          = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmLabel
@onready var _confirm_btn_row: HBoxContainer  = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonRow
@onready var _cancel_btn:      Button         = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/CancelConfirmBtn
@onready var _close_btn:       Button         = $OuterMargin/VBox/CloseBtn

# Runtime state
var _game: GameManager = null
var _selected_candidate: Player = null   # candidate waiting for a replace-target click


# ---------------------------------------------------------------------------
# SETUP — called by GameWorld when opening the market.
# game: the shared GameManager instance
# ---------------------------------------------------------------------------
func open(game: GameManager) -> void:
	_game = game
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_close_btn.pressed.connect(_on_close_pressed)

	# Generate fresh candidates via GameManager.
	_game.open_market()

	_refresh()
	show()


# ---------------------------------------------------------------------------
# REFRESH — rebuilds both columns from current game state.
# Call this after every hire to keep cards in sync.
# ---------------------------------------------------------------------------
func _refresh() -> void:
	_selected_candidate = null
	_confirm_panel.hide()

	# Update slot counter display.
	_slots_lbl.text = "Slots: %s" % _game.market_slots_display()

	# Rebuild roster cards.
	for child in _roster_list.get_children():
		child.queue_free()
	for i in _game.players.size():
		_roster_list.add_child(_build_roster_card(_game.players[i], i))

	# Rebuild candidate cards.
	for child in _candidates_list.get_children():
		child.queue_free()
	for candidate in _game.market.current_candidates:
		_candidates_list.add_child(_build_candidate_card(candidate))


# ---------------------------------------------------------------------------
# ROSTER CARD — displays a current team member.
# During the confirm phase, these become "replace this player" buttons.
# ---------------------------------------------------------------------------
func _build_roster_card(player: Player, slot_index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Header: name + trait badge
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = "%s  Lv.%d" % [player.player_name, player.level]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var trait_lbl := Label.new()
	trait_lbl.text = "[%s]" % player.primary_trait
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
	header.add_child(trait_lbl)

	# Stats line
	var stats_lbl := Label.new()
	stats_lbl.text = "Skill %d  ·  Focus %d  ·  Stamina %d" % [player.skill, player.focus, player.stamina]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.70, 1.0))
	vbox.add_child(stats_lbl)

	# Form label if available
	if player.form_label != "":
		var form_lbl := Label.new()
		form_lbl.text = player.form_label
		form_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(form_lbl)

	# Make it clickable during confirm phase.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _selected_candidate != null and _game.market_has_slots():
				_on_replace_confirmed(slot_index)
	)
	return card


# ---------------------------------------------------------------------------
# CANDIDATE CARD — displays a market candidate with full stats + bio.
# Clicking selects the candidate and shows the confirm panel.
# ---------------------------------------------------------------------------
func _build_candidate_card(candidate: Player) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header: name + level + trait
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = "%s  Lv.%d" % [candidate.player_name, candidate.level]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var trait_lbl := Label.new()
	trait_lbl.text = "[%s]" % candidate.primary_trait
	trait_lbl.add_theme_font_size_override("font_size", 12)
	trait_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1.0))
	header.add_child(trait_lbl)

	# Stats line
	var stats_lbl := Label.new()
	stats_lbl.text = "Skill %d  ·  Focus %d  ·  Stamina %d  ·  Morale %d" % [
		candidate.skill, candidate.focus, candidate.stamina, candidate.morale
	]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.70, 0.72, 0.80, 1.0))
	vbox.add_child(stats_lbl)

	# Minor trait if any
	if candidate.minor_trait != "none" and candidate.minor_trait != "":
		var minor_lbl := Label.new()
		minor_lbl.text = "Minor: %s" % candidate.minor_trait
		minor_lbl.add_theme_font_size_override("font_size", 11)
		minor_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45, 1.0))
		vbox.add_child(minor_lbl)

	# Bio
	var bio_lbl := Label.new()
	bio_lbl.text = candidate.bio
	bio_lbl.add_theme_font_size_override("font_size", 11)
	bio_lbl.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58, 1.0))
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(bio_lbl)

	# Dim card if no slots.
	if not _game.market_has_slots():
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
		return card

	# Click handler — select this candidate.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_candidate_selected(candidate)
	)
	return card


# ---------------------------------------------------------------------------
# EVENT HANDLERS
# ---------------------------------------------------------------------------

# Player clicked a candidate — enter confirm phase.
func _on_candidate_selected(candidate: Player) -> void:
	_selected_candidate = candidate
	_confirm_lbl.text = "Replace who with %s?" % candidate.player_name
	# Clear old confirm buttons.
	for child in _confirm_btn_row.get_children():
		child.queue_free()
	# Build one button per current player.
	for i in _game.players.size():
		var p: Player = _game.players[i]
		var btn := Button.new()
		btn.text = "%s (Lv.%d)" % [p.player_name, p.level]
		btn.custom_minimum_size = Vector2(120, 36)
		var captured_i := i
		btn.pressed.connect(func(): _on_replace_confirmed(captured_i))
		_confirm_btn_row.add_child(btn)
	_confirm_panel.show()


# Player confirmed — execute the hire, refresh UI.
func _on_replace_confirmed(slot_index: int) -> void:
	if _selected_candidate == null:
		return
	var success: bool = _game.hire_candidate(_selected_candidate, slot_index)
	if success:
		_refresh()
	else:
		# Out of slots — just hide confirm panel.
		_confirm_panel.hide()
		_selected_candidate = null


# Cancel confirm panel — return to browsing state.
func _on_cancel_pressed() -> void:
	_selected_candidate = null
	_confirm_panel.hide()


# Close the market entirely.
func _on_close_pressed() -> void:
	hide()
	market_closed.emit()
