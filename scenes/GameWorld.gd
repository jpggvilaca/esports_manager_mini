# scenes/GameWorld.gd
# Default scene. Isometric team room.
# Will hold 3 player slots with assets + PlayerStatBars overlaid on each.
extends Node2D

const MANAGEMENT_SCENE := preload("res://scenes/Main.tscn")

var _management: Control = null

@onready var _week_label: Label = $UI/WeekLabel


func _ready() -> void:
	$UI/ManageBtn.pressed.connect(_on_manage_pressed)


func set_week(week: int) -> void:
	_week_label.text = "Week %d" % week


func _on_manage_pressed() -> void:
	if _management == null:
		_management = MANAGEMENT_SCENE.instantiate()
		get_tree().root.add_child(_management)
		_management.tree_exiting.connect(func(): _management = null)
		if not _management.is_connected("return_to_world", _on_return_from_management):
			_management.return_to_world.connect(_on_return_from_management)
	_management.show()
	hide()


func _on_return_from_management(week: int) -> void:
	set_week(week)
	show()
	_management.hide()
