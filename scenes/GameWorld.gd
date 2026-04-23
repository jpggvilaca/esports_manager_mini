# scenes/GameWorld.gd
# Default scene. Team room with player sprites.
# Receives week/season back from management via return_to_world signal.
# Receives goal state via season_goal_updated signal — no reach-through into management internals.
extends Node2D

const MANAGEMENT_SCENE := preload("res://scenes/Main.tscn")

var _management: Control = null

@onready var _ui:                CanvasLayer = $UI
@onready var _week_label:        Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/WeekLabel
@onready var _next_event_label:  Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/NextEventLabel
@onready var _season_goal_label: Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/SeasonGoalLabel


func _ready() -> void:
	$UI/ManageBtn.pressed.connect(_on_manage_pressed)


func _on_manage_pressed() -> void:
	if _management == null:
		_management = MANAGEMENT_SCENE.instantiate()
		get_tree().root.add_child(_management)
		_management.tree_exiting.connect(func(): _management = null)
		_management.return_to_world.connect(_on_return_from_management)
		# Fix 4: listen to the signal rather than reaching into _management._game.
		_management.season_goal_updated.connect(_on_season_goal_updated)

	_ui.hide()
	_management.show()


func _on_return_from_management(week_in_season: int, season: int) -> void:
	var abs_week: int = (season - 1) * Calendar.WEEKS_PER_SEASON + week_in_season
	_update_header(abs_week, season)
	_ui.show()
	_management.hide()
	if _management != null:
		_management.prepare_new_week()


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


func _on_season_goal_updated(goals: Dictionary) -> void:
	var season_goal: Dictionary  = goals.get("season",  {})
	var quarter_goal: Dictionary = goals.get("quarter", {})

	# Season goal line
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

	# Quarter goal line
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
