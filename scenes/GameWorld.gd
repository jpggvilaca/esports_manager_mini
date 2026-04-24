# scenes/GameWorld.gd
# ============================================================
# TEAM ROOM — the default scene. Shows player sprites and the main action buttons.
# Receives data from management via signals (no reach-through into internals).
#
# Owns:
#   - The management overlay (Main.tscn) — instantiated on first open
#   - The market overlay (MarketOverlay.tscn) — instantiated on first open
#   - The team room header panel (week, next event, goals)
#
# TO ADD new header info → add a Label to GameWorld.tscn and wire it in _update_header()
# TO TWEAK market button visibility → see _update_market_btn()
# ============================================================
extends Node2D

const MANAGEMENT_SCENE := preload("res://scenes/Main.tscn")
const MARKET_SCENE     := preload("res://ui/components/MarketOverlay.tscn")

var _management: Control       = null
var _market_overlay: MarketOverlay = null

@onready var _ui:                CanvasLayer = $UI
@onready var _week_label:        Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/WeekLabel
@onready var _next_event_label:  Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/NextEventLabel
@onready var _season_goal_label: Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/SeasonGoalLabel
@onready var _market_btn:        Button      = $UI/MarketBtn


func _ready() -> void:
	$UI/ManageBtn.pressed.connect(_on_manage_pressed)
	_market_btn.pressed.connect(_on_market_pressed)
	_market_btn.hide()  # hidden until management sends availability info


# ---------------------------------------------------------------------------
# MANAGEMENT OVERLAY — opens on "Open Management" press.
# Lazily instantiated on first use.
# ---------------------------------------------------------------------------
func _on_manage_pressed() -> void:
	if _management == null:
		_management = MANAGEMENT_SCENE.instantiate()
		get_tree().root.add_child(_management)
		_management.tree_exiting.connect(func(): _management = null)
		_management.return_to_world.connect(_on_return_from_management)
		_management.season_goal_updated.connect(_on_season_goal_updated)

	_ui.hide()
	_management.show()


# Called when the player dismisses the result overlay in management.
func _on_return_from_management(week_in_season: int, season: int) -> void:
	var abs_week: int = (season - 1) * Calendar.WEEKS_PER_SEASON + week_in_season
	_update_header(abs_week, season)
	_ui.show()
	_management.hide()
	if _management != null:
		_management.prepare_new_week()
		# Update the market button after the week advances.
		_update_market_btn()


# ---------------------------------------------------------------------------
# MARKET OVERLAY — opens on "Player Market" press.
# Lazily instantiated on first use; reused across opens.
# ---------------------------------------------------------------------------
func _on_market_pressed() -> void:
	if _market_overlay == null:
		_market_overlay = MARKET_SCENE.instantiate()
		get_tree().root.add_child(_market_overlay)
		_market_overlay.market_closed.connect(_on_market_closed)

	_ui.hide()
	_market_overlay.open(_management._game)


# Called when the market overlay is closed.
func _on_market_closed() -> void:
	_ui.show()
	# After a hire, the management panels need to know the roster changed.
	# prepare_new_week() rebuilds player panels from the live players array.
	if _management != null:
		_management.prepare_new_week()
	_update_market_btn()


# Shows or hides the market button based on current game state.
# Called after every week advance and after the market closes.
func _update_market_btn() -> void:
	if _management == null:
		_market_btn.hide()
		return
	var available: bool = _management._game.is_market_available()
	var has_slots: bool = _management._game.market_has_slots()
	_market_btn.visible = available
	# Dim the button if no slots remain (market is open but hiring is disabled).
	_market_btn.modulate = Color(1, 1, 1, 1) if has_slots else Color(0.6, 0.6, 0.6, 1)
	if not has_slots:
		_market_btn.text = "📊  Market (no slots)"
	else:
		_market_btn.text = "📊  Player Market  %s" % _management._game.market_slots_display()


# ---------------------------------------------------------------------------
# HEADER UPDATES
# ---------------------------------------------------------------------------

# Refreshes the week/event labels in the top-right panel.
func _update_header(abs_week: int, season: int) -> void:
	var week_in_season: int = Calendar.get_week_in_season(abs_week)
	_week_label.text = "Season %d  ·  Week %d" % [season, week_in_season]

	var next: Dictionary = Calendar.get_next_event(abs_week)
	if next.is_empty():
		_next_event_label.text = "No more events this season"
	else:
		var type_str: String
		match next["type"]:
			Calendar.TYPE_TOURNAMENT: type_str = "Tournament"
			Calendar.TYPE_SOLO:       type_str = "Solo Match"
			_:                        type_str = "Important Match"
		var weeks: int = next["weeks_away"]
		_next_event_label.text = "%s in %d week%s" % [type_str, weeks, "s" if weeks > 1 else ""]


# Receives season + quarter goal state from Main.gd via signal.
# Displays them as two stacked lines in the header panel.
func _on_season_goal_updated(goals: Dictionary) -> void:
	var season_goal: Dictionary  = goals.get("season",  {})
	var quarter_goal: Dictionary = goals.get("quarter", {})

	var season_line: String = ""
	if not season_goal.is_empty():
		if season_goal.get("achieved", false):
			season_line = "✅ " + season_goal.get("description", "")
			_season_goal_label.add_theme_color_override("font_color", Color(0.30, 0.95, 0.50, 1.0))
		else:
			var desc: String = season_goal.get("description", "")
			if season_goal.get("type", "") == "wins":
				desc += "  (%d/%d)" % [season_goal.get("current", 0), season_goal.get("target", 0)]
			season_line = desc
			_season_goal_label.remove_theme_color_override("font_color")

	var quarter_line: String = ""
	if not quarter_goal.is_empty():
		if quarter_goal.get("achieved", false):
			quarter_line = "✅ " + quarter_goal.get("description", "")
		else:
			var desc: String = quarter_goal.get("description", "")
			if quarter_goal.get("type", "") == "quarter_wins":
				desc += "  (%d/%d)" % [quarter_goal.get("current", 0), quarter_goal.get("target", 0)]
			quarter_line = desc

	var lines: PackedStringArray = []
	if season_line  != "": lines.append(season_line)
	if quarter_line != "": lines.append(quarter_line)
	_season_goal_label.text = "\n".join(lines)
