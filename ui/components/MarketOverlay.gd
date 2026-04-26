# ui/components/MarketOverlay.gd
# Market overlay: browse candidates, confirm hire, replace a roster slot.
# Card structure lives in RosterCard.tscn / CandidateCard.tscn.
# This script is data-wiring and event-handling only.
class_name MarketOverlay
extends Control

signal market_closed

const ROSTER_CARD    := preload("res://ui/components/RosterCard.tscn")
const CANDIDATE_CARD := preload("res://ui/components/CandidateCard.tscn")

@onready var _slots_lbl:       Label         = $OuterMargin/VBox/TitleRow/SlotsLabel
@onready var _roster_list:     VBoxContainer = $OuterMargin/VBox/ContentRow/RosterColumn/RosterList
@onready var _candidates_list: VBoxContainer = $OuterMargin/VBox/ContentRow/CandidatesColumn/CandidatesList
@onready var _confirm_panel:   PanelContainer = $OuterMargin/VBox/ConfirmPanel
@onready var _confirm_lbl:     Label          = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmLabel
@onready var _confirm_btn_row: HBoxContainer  = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonRow
@onready var _cancel_btn:      Button         = $OuterMargin/VBox/ConfirmPanel/ConfirmMargin/ConfirmVBox/CancelConfirmBtn
@onready var _close_btn:       Button         = $OuterMargin/VBox/CloseBtn

var _game: GameManager = null
var _selected_candidate: Player = null


func open(game: GameManager) -> void:
	_game = game
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_close_btn.pressed.connect(_on_close_pressed)
	_game.open_market()
	_refresh()
	show()


func _refresh() -> void:
	_selected_candidate = null
	_confirm_panel.hide()
	_slots_lbl.text = "Slots: %s" % _game.market_slots_display()

	for child in _roster_list.get_children():
		child.queue_free()
	for i in _game.players.size():
		_make_roster_card(_game.players[i], i)

	for child in _candidates_list.get_children():
		child.queue_free()
	for candidate in _game.market.current_candidates:
		_make_candidate_card(candidate)


func _make_roster_card(player: Player, slot_index: int) -> void:
	var card: RosterCard = ROSTER_CARD.instantiate()
	# Add before setup so @onready refs resolve
	_roster_list.add_child(card)
	card.setup(player)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and _selected_candidate != null and _game.market_has_slots():
			_on_replace_confirmed(slot_index)
	)


func _make_candidate_card(candidate: Player) -> void:
	var card: CandidateCard = CANDIDATE_CARD.instantiate()
	_candidates_list.add_child(card)
	card.setup(candidate)
	if not _game.market_has_slots():
		card.modulate = Color(0.5, 0.5, 0.5)
		return
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_on_candidate_selected(candidate)
	)


func _on_candidate_selected(candidate: Player) -> void:
	_selected_candidate = candidate
	_confirm_lbl.text = "Replace who with %s?" % candidate.player_name
	for child in _confirm_btn_row.get_children():
		child.queue_free()
	for i in _game.players.size():
		var p: Player = _game.players[i]
		var btn := Button.new()
		btn.text = "%s (Lv.%d)" % [p.player_name, p.level]
		btn.custom_minimum_size = Vector2(120, 36)
		var captured_i := i
		btn.pressed.connect(func(): _on_replace_confirmed(captured_i))
		_confirm_btn_row.add_child(btn)
	_confirm_panel.show()


func _on_replace_confirmed(slot_index: int) -> void:
	if _selected_candidate == null:
		return
	if _game.hire_candidate(_selected_candidate, slot_index):
		_refresh()
	else:
		_confirm_panel.hide()
		_selected_candidate = null


func _on_cancel_pressed() -> void:
	_selected_candidate = null
	_confirm_panel.hide()


func _on_close_pressed() -> void:
	hide()
	market_closed.emit()
