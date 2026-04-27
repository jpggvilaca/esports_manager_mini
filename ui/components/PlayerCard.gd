# ui/components/PlayerCard.gd
# Data binding only. Structure + styles live in PlayerCard.tscn.
# Call setup() after add_child(). Signal bench_toggle_pressed when toggle btn is pressed.
class_name PlayerCard
extends PanelContainer

signal bench_toggle_pressed(player_name: String)

# Stamina bar color by condition — tweakable here, not scattered across callers.
const COLOR_STAMINA_OK:        Color = Color(0.30, 0.80, 0.40)
const COLOR_STAMINA_TIRED:     Color = Color(0.95, 0.55, 0.15)
const COLOR_STAMINA_EXHAUSTED: Color = Color(0.85, 0.22, 0.22)

# Extras label constants — all dynamic nodes use these
const FONT_VOICE:   int   = 11
const FONT_FORM:    int   = 11
const FONT_WARN:    int   = 10
const FONT_ACTION:  int   = 10
const FONT_TOGGLE:  int   = 10
const COLOR_VOICE:  Color = Color(0.68, 0.70, 0.80)
const COLOR_WARN:   Color = Color(1.0,  0.4,  0.2)
const COLOR_ACTION: Color = Color(0.45, 0.45, 0.52)
const BTN_MIN_H:    int   = 26

@onready var _portrait:      TextureRect   = $Margin/Row/Portrait
@onready var _name_label:    Label         = $Margin/Row/VBox/NameLabel
@onready var _trait_label:   Label         = $Margin/Row/VBox/TraitLabel
@onready var _stamina_bar:   ProgressBar   = $Margin/Row/VBox/StaminaRow/StaminaBar
@onready var _xp_label:      Label         = $Margin/Row/VBox/XpRow/XpLabel
@onready var _xp_bar:        ProgressBar   = $Margin/Row/VBox/XpRow/XpBar
@onready var _extras:        VBoxContainer = $Margin/Row/VBox/Extras

# Cached sub-resources from the .tscn — loaded once in _ready, swapped in setup().
var _style_active: StyleBoxFlat
var _style_bench:  StyleBoxFlat


func _ready() -> void:
	# Grab the two StyleBoxFlat sub-resources baked into the scene.
	# get_theme_stylebox returns the current one; we load both via the scene's resource list.
	_style_bench  = get_theme_stylebox("panel")  # scene default is bench
	_style_active = _style_bench.duplicate()
	_style_active.bg_color     = Color(0.10, 0.15, 0.10)
	_style_active.border_color = Color(0.25, 0.75, 0.38)


func setup(
	player:     Player,
	is_active:  bool,
	match_type: String,
	portrait:   Texture2D = null,
	_game:      GameManager = null
) -> void:
	# Panel style — swap between the two scene sub-resources
	add_theme_stylebox_override("panel", _style_active if is_active else _style_bench)

	# Portrait
	if portrait != null:
		_portrait.texture = portrait
	_portrait.modulate = Color(1, 1, 1) if is_active else Color(0.65, 0.65, 0.70)

	# Name — color reflects squad status; font size is static (scene sets 14)
	_name_label.text = player.player_name
	_name_label.add_theme_color_override("font_color",
		Color(1, 1, 1) if is_active else Color(0.60, 0.60, 0.65))

	# Trait — single unified trait label
	_trait_label.text = GameText.trait_label(player.primary_trait)

	# Stamina bar
	_stamina_bar.value    = player.stamina
	_stamina_bar.modulate = _stamina_color(player.stamina_key())

	# XP bar
	var xp_to_next: int = LevelSystem.xp_to_next_level(player)
	_xp_label.text = "Lv.%d  %s" % [
		player.level,
		"MAX" if xp_to_next == -1 else "%d/%d" % [player.xp, LevelSystem.LEVEL_THRESHOLDS[player.level]]
	]
	_xp_bar.value = int(LevelSystem.level_progress(player) * 100)

	# Extras — cleared and rebuilt per call
	for child in _extras.get_children():
		child.queue_free()
	if is_active:
		_add_active_extras(player, match_type)
	else:
		_add_bench_extras(player)


func _add_active_extras(player: Player, match_type: String) -> void:
	var voice: String = player.voice(match_type)
	if voice != "":
		_add_label(voice, COLOR_VOICE, FONT_VOICE, true)
	if player.form_label != "":
		_add_label(player.form_label, Color(1, 1, 1), FONT_FORM)
	if player.burnout >= Tuning.BURNOUT_WARNING_THRESHOLD:
		_add_label("🔥 Burnout warning", COLOR_WARN, FONT_WARN)


func _add_bench_extras(player: Player) -> void:
	if player.form_label != "":
		_add_label(player.form_label, Color(1, 1, 1), FONT_FORM)
	if player.burnout >= Tuning.BURNOUT_WARNING_THRESHOLD:
		_add_label("🔥 Burnout warning", COLOR_WARN, FONT_WARN)
	_add_label("📚 Training" if player.bench_action == "train" else "💤 Resting",
		COLOR_ACTION, FONT_ACTION)
	var toggle_btn := Button.new()
	toggle_btn.text = "Switch to 💤 Rest" if player.bench_action == "train" else "Switch to 📚 Train"
	toggle_btn.add_theme_font_size_override("font_size", FONT_TOGGLE)
	toggle_btn.custom_minimum_size = Vector2(0, BTN_MIN_H)
	var captured_name: String = player.player_name
	toggle_btn.pressed.connect(func(): bench_toggle_pressed.emit(captured_name))
	_extras.add_child(toggle_btn)


func _add_label(text: String, color: Color, font_size: int, wrap: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extras.add_child(lbl)


func _stamina_color(key: String) -> Color:
	match key:
		"exhausted": return COLOR_STAMINA_EXHAUSTED
		"tired":     return COLOR_STAMINA_TIRED
		_:           return COLOR_STAMINA_OK
