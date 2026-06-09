extends Control

@onready var back_button: Button = %BackButton
@onready var name_label: Label = %NameLabel
@onready var id_label: Label = %IdLabel
@onready var distance_label: Label = %DistanceLabel
@onready var position_label: Label = %PositionLabel
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	GameState.set_current_scene(Constants.SCENE_CAPTURE)
	back_button.pressed.connect(_on_back_pressed)
	_update_monster_details()


func _update_monster_details() -> void:
	var monster := GameState.get_selected_monster()
	if monster.is_empty():
		name_label.text = "未选择怪物"
		id_label.text = "ID: -"
		distance_label.text = "距离: -"
		position_label.text = "坐标: -"
		hint_label.text = "请从雷达界面点击一个怪物点进入。"
		return

	var world_position: Vector2 = monster.get("world_position", Vector2.ZERO)
	name_label.text = str(monster.get("name", "Unknown"))
	id_label.text = "ID: %s" % monster.get("id", "")
	distance_label.text = "距离: %.1f m" % float(monster.get("distance_meters", 0.0))
	position_label.text = "世界坐标: X %.0f m / Y %.0f m" % [world_position.x, world_position.y]
	hint_label.text = str(monster.get("hint", "捕捉玩法将在后续阶段实现。"))


func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(Constants.SCENE_RADAR)
	if error != OK:
		push_error("Failed to return to radar: %s" % error)
