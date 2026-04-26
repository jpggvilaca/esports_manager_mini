# ui/components/PlayerPanel.gd
# Management screen player card.
class_name PlayerPanel
extends PanelContainer

signal action_changed(player_name: String, action: String)

# Button background tints — modulate colours the whole button node.
# Font colour comes from the project theme (ui/theme.tres) automatically.
const COLOR_SELECTED := Color(0.20, 0.70, 0.35, 1.0)
const COLOR_IDLE     := Color(0.30, 0.32, 0.40, 1.0)
const COLOR_INTENSE  := Color(0.85, 0.30, 0.15, 1.0)

var _player: Player = null

@onready var _name_label:     Label          = $Margin/VBox/HeaderRow/NameLabel
@onready var _trait_badge:    Label          = $Margin/VBox/HeaderRow/TraitBadge
@onready var _form_label:     Label          = $Margin/VBox/HeaderRow/FormLabel
@onready var _bio_label:      Label          = $Margin/VBox/BioLabel
@onready var _portrait:       TextureRect    = $Margin/VBox/ContentRow/PortraitColumn/Portrait
@onready var _level_label:    Label          = $Margin/VBox/ContentRow/PortraitColumn/LevelLabel
@onready var _stat_bars:      PlayerStatBars = $Margin/VBox/ContentRow/StatBars
@onready var _action_buttons: HBoxContainer  = $Margin/VBox/ActionButtons


func setup(player: Player, portrait_texture: Texture2D = null) -> void:
	_player = player
	if portrait_texture != null:
		_portrait.texture = portrait_texture
	_build_action_buttons()
	_refresh_display()


func refresh() -> void:
	_refresh_display()


func reset_action() -> void:
	_player.planned_action = ""
	_highlight_action("")
	action_changed.emit(_player.player_name, "")


func set_actions_enabled(enabled: bool) -> void:
	_action_buttons.visible = enabled


func _build_action_buttons() -> void:
	for action_id: String in ["train", "rest", "scrim", "intense"]:
		var btn := Button.new()
		btn.text                = GameText.ACTIONS[action_id]["label"]
		btn.tooltip_text        = GameText.ACTIONS[action_id]["description"]
		btn.custom_minimum_size = Vector2(76, 34)
		btn.focus_mode          = Control.FOCUS_NONE
		# Force white text — theme doesn't always cascade to runtime-instantiated buttons.
		btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_focus_color",   Color(1.0, 1.0, 1.0, 1.0))
		var captured := action_id
		btn.pressed.connect(func(): _on_action_pressed(captured))
		_action_buttons.add_child(btn)
	_highlight_action(_player.planned_action)


func _refresh_display() -> void:
	_name_label.text  = _player.player_name
	_trait_badge.text = GameText.TRAIT_DESCRIPTIONS.get(_player.primary_trait, _player.primary_trait)
	_level_label.text = "Lv.%d" % _player.level
	_form_label.text  = _player.form_label
	_bio_label.text   = _player.bio
	var warnings: Array = []
	if _player.burnout >= 3:
		warnings.append("🔥 On the edge")
	elif _player.burnout >= 2:
		warnings.append("⚠️ Pushing it")
	if _player.hunger <= 1:
		warnings.append("🧈 Lost the edge")
	if warnings.size() > 0:
		_bio_label.text += "  ·  " + "  ·  ".join(warnings)
	_stat_bars.refresh(_player)
	_highlight_action(_player.planned_action)


func _on_action_pressed(action: String) -> void:
	_player.planned_action = action
	action_changed.emit(_player.player_name, action)
	_highlight_action(action)


func _highlight_action(action: String) -> void:
	var action_ids := ["train", "rest", "scrim", "intense"]
	var buttons    := _action_buttons.get_children()
	for i in buttons.size():
		var btn: Button    = buttons[i]
		var selected: bool = action_ids[i] == action
		if selected:
			btn.modulate = COLOR_INTENSE if action == "intense" else COLOR_SELECTED
		else:
			btn.modulate = COLOR_IDLE
