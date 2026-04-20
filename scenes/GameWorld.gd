# scenes/GameWorld.gd
# Default scene. Team room with player sprites.
# Receives week/season back from management via return_to_world signal.
extends Node2D

const MANAGEMENT_SCENE := preload("res://scenes/Main.tscn")

var _management: Control  = null
var _current_week: int    = 1   # absolute week — kept in sync with GameManager
var _current_season: int  = 1

@onready var _ui:               CanvasLayer = $UI
@onready var _week_label:       Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/WeekLabel
@onready var _next_event_label: Label       = $UI/HeaderPanel/HeaderMargin/HeaderVBox/NextEventLabel


func _ready() -> void:
	$UI/ManageBtn.pressed.connect(_on_manage_pressed)
	# Labels show tscn defaults until management returns with real data.
	# Add initialisation here when save/load is implemented.


func _update_header(abs_week: int, season: int) -> void:
	_current_week   = abs_week
	_current_season = season
	var week_in_season: int = Calendar.get_week_in_season(abs_week)
	_week_label.text = "Season %d  ·  Week %d" % [season, week_in_season]

	var next: Dictionary = Calendar.get_next_event(abs_week)
	if next.is_empty():
		_next_event_label.text = "No more events this season"
	else:
		var type_str: String = "Tournament" if next["type"] == Calendar.TYPE_TOURNAMENT \
			else "Important Match"
		var weeks: int = next["weeks_away"]
		_next_event_label.text = "%s in %d week%s" % [type_str, weeks, "s" if weeks > 1 else ""]


func _on_manage_pressed() -> void:
	if _management == null:
		_management = MANAGEMENT_SCENE.instantiate()
		get_tree().root.add_child(_management)
		_management.tree_exiting.connect(func(): _management = null)
		_management.return_to_world.connect(_on_return_from_management)

	_ui.hide()
	_management.show()


func _on_return_from_management(week_in_season: int, season: int) -> void:
	# Reconstruct absolute week from season + week_in_season.
	var abs_week: int = (season - 1) * Calendar.WEEKS_PER_SEASON + week_in_season
	_update_header(abs_week, season)
	_ui.show()
	_management.hide()
