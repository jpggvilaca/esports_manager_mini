# scenes/GameWorld.gd
# Default scene. Isometric team room.
# Will hold 3 player slots with assets + PlayerStatBars overlaid on each.
extends Node2D

const MANAGEMENT_SCENE := preload("res://scenes/Main.tscn")

var _management: Control = null

@onready var _ui:         CanvasLayer = $UI
@onready var _week_label: Label       = $UI/WeekLabel


func _ready() -> void:
	$UI/ManageBtn.pressed.connect(_on_manage_pressed)
	# Week label shows the tscn default ("Week 1") until management returns.
	# If save/load is added later, initialise the label here from saved state.


func set_week(week: int, season: int) -> void:
	_week_label.text = "S%d · W%d" % [season, week]


func _on_manage_pressed() -> void:
	if _management == null:
		_management = MANAGEMENT_SCENE.instantiate()
		get_tree().root.add_child(_management)
		_management.tree_exiting.connect(func(): _management = null)
		_management.return_to_world.connect(_on_return_from_management)

	# Hide the CanvasLayer so it doesn't render over the management screen.
	_ui.hide()
	_management.show()


func _on_return_from_management(week: int, season: int) -> void:
	set_week(week, season)
	_ui.show()
	_management.hide()
