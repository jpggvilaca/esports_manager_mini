# scenes/RosterScreen.gd
# Squad selection overlay. Two columns: bench (left) ↔ active (right).
# Click any card to move the player between bench and squad.
# Bench cards also show the train/rest toggle from PlayerCard.
class_name RosterScreen
extends Control

const TraitMatchup := preload("res://scripts/systems/TraitMatchup.gd")
const PLAYER_CARD  := preload("res://ui/components/PlayerCard.tscn")

signal closed

const PORTRAITS: Array[String] = [
	"res://assets/portraits/portrait1.png",
	"res://assets/portraits/portrait2.png",
	"res://assets/portraits/portrait3.png",
	"res://assets/portraits/portrait4.png",
	"res://assets/portraits/portrait5.png",
]

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

	$Margin/VBox/SubLabel.text = (
		"Click a player to move between bench and squad  ·  %d / %d active" % [
			active_count, GameManager.SQUAD_SIZE
		]
	)
	$Margin/VBox/Columns/ActiveColumn/ActiveHeader.text = (
		"ACTIVE SQUAD  ·  %d / %d" % [active_count, GameManager.SQUAD_SIZE]
	)

	for i in _game.players.size():
		var player: Player   = _game.players[i]
		var portrait: String = PORTRAITS[i] if i < PORTRAITS.size() else PORTRAITS[0]
		var tex: Texture2D   = load(portrait)

		# PlayerCard handles display; we wrap it in a clickable overlay
		var card: PlayerCard = PLAYER_CARD.instantiate()
		card.bench_toggle_pressed.connect(func(name: String):
			_game.toggle_bench_action(name)
			_build()
		)

		# Add to tree FIRST so @onready vars resolve, THEN call setup()
		if player.is_active:
			active_list.add_child(card)
		else:
			bench_list.add_child(card)
		card.setup(player, player.is_active, "normal", tex, _game)

		# Invisible full-rect button on top for squad toggle click
		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.add_theme_color_override("font_color",         Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color",   Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var captured_name: String = player.player_name
		btn.pressed.connect(func(): _on_card_clicked(captured_name))
		card.add_child(btn)


func _on_card_clicked(player_name: String) -> void:
	var player: Player = _find_player(player_name)
	if player == null:
		return
	if player.is_active:
		player.is_active = false
	else:
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
