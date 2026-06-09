extends Control

@export var scene_path := ""

@onready var back_button: Button = get_node_or_null("%BackButton") as Button


func _ready() -> void:
	if not scene_path.is_empty():
		GameState.set_current_scene(scene_path)

	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(Constants.SCENE_MAIN_MENU)
	if error != OK:
		push_error("Failed to return to main menu: %s" % error)
